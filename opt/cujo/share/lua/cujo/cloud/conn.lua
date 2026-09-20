--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2020 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo

-- Relatively low-level aspects of the connection to the Agent Service are
-- handled here. That includes WebSocket communication as well as the STOMP
-- protocol.
--
-- The very lowest levels are handled by external libraries, primarily
-- libwebsockets and libstomp. But note that much of even our "glue" code is
-- implemented in C, in the stompws library. In practice, this module and
-- luastompws are very tightly entwined and understanding one without the other
-- is difficult. In addition, due to our reliance on the coutil library for
-- managing sockets asynchronously, a significant part of the code is involved
-- with getting libwebsockets and coutil to work together.
--
-- Documentation links:
--     WebSocket protocol (RFC 6455):
--         https://tools.ietf.org/html/rfc6455
--     STOMP protocol version 1.1 (we use that specific version):
--         https://stomp.github.io/stomp-specification-1.1.html

local Queue = require'loop.collection.Queue'
local event = require 'coutil.event'
local json = require 'json'
local socket = require 'coutil.socket'
local sockev = require'coutil.socket.event'
local tabop = require 'loop.table'

local cloudauth = require'cujo.cloud.auth'
local shims = require 'cujo.shims'
local util = require 'cujo.util'
local stompws = require'stompws'

-- Our STOMP message channels are all under /user/queue/.
local local_dest_prefix = '/user/queue/'
local channel_pattern = '^' .. local_dest_prefix .. '([%w_%-]+)$'

-- We want to miss this many heartbeats from the server before considering it
-- lost and attempting to reconnect.
local max_broker_timeouts = 5

-- File descriptors currently in use for the connection. Typically there should
-- be only one since we only open one connection at a time, but supporting
-- multiple lets us cover libwebsockets's API properly. See also [fd-handling].
--
-- This is a mapping from file descriptors to entries with the following fields:
-- * sock: The underlying TCP socket.
-- * read: A coutil read event created on that socket.
-- * write: A coutil write event created on that socket.
-- * pending_read: A boolean indicating that a read event was raised for this
--                 socket, but we did not act on it yet because we were busy.
--                 See inputev.busy below.
local fds = {}

-- Closing the connection normally causes a reconnect attempt. But when this is
-- set to false, reconnecting is immediately aborted.
local keep_connection = false

-- Current maximum reconnection backoff, in seconds.
local backoff

-- Functions used to control the heartbeat timers, in the outgoing (client) and
-- incoming (broker) direction respectively.
--
-- Both we and the Agent Service only send heartbeats when necessary, i.e. when
-- no other messages have been sent in the specified interval. Thus resetting is
-- used to treat any kind of send/receive as equivalent to a heartbeat.
local client_timeout_stop, client_timeout_reset
local broker_timeout_stop, broker_timeout_reset

-- inputev.busy is a boolean used to prevent reading data from the socket buffer
-- while a message is being handled. This is a memory usage optimization for the
-- case when the Agent Service sends messages faster than we can process them,
-- preventing us from accumulating lots of decoded messages.
--
-- This causes us to also miss broker heartbeats, so we ignore such timeouts
-- while busy.
local inputev = {busy = false}

------------------------------------------------------------------------
-- [sending]
--
-- libwebsockets will trigger a callback when a socket is ready for data to be
-- sent over it. (Or rather, coutil will trigger us, and we trigger
-- libwebsockets, which triggers the callback.) That callback (stompcb.send)
-- needs to decide what message is to be sent next, if any. These variables
-- control that behaviour.
--
-- The flow around sending generally looks like the following:
--
-- 1. We set one or more of these to know what we want to send.
-- 2. We call connection:send() in order to tell libwebsockets that we're
--    interested in sending something.
-- 3. When the socket is ready for writing, coutil triggers
--    the cloud-conn-fd-awaiter coroutine, which calls connection:dispatch()
--    with the socket's file descriptor, which in turn calls into libwebsockets,
--    asking it to service the socket.
-- 4. libwebsockets notices that we're interested in sending something and calls
--    into stompws, which calls stompcb.send() to determine what to actually
--    send, and sends it.
-- 5. The callback returned by stompcb.send() is called when the send is
--    complete, or if it failed.

-- Booleans used to control whether these kinds of messages need to be sent.
local connect_msg_sent
local close
local heartbeat

-- A mapping from channels (strings) to booleans indicating whether we should
-- subscribe or unsubscribe from the channel. If the value is true, we
-- unsubscribe, otherwise we subscribe.
local pending_subscriptions = {} -- [channel] = boolean

-- Mark if message to be sent to /resync channel was queued. Agent Service expects
-- that /resync will be the first message received after it sends 'ACTIVE' status
-- message.
local resync_msg_sent = false

-- Queue of messages that need to be sent out.
--
-- Messages are tables with three fields, all strings:
--
-- * channel: The STOMP channel that the message is for.
--
-- * body_json: JSON encoding of the message body.
--
-- * body_str: tostring() of the message body. Typically the body was originally
--   a table so this is of the form "table: 0x1234" which is useless by itself,
--   but it's logged both when messages are enqueued and when they're actually
--   sent and connecting the timestamps of those separate events is sometimes
--   useful.
local outmsgs = Queue()

-- Queue of messages that cannot be sent yet because of hibernation or missing
-- 'ACTIVE' status message from Agent Service.
local inactive_outmsgs = Queue()

------------------------------------------------------------------------

-- A mapping from channels (strings) to the corresponding subscription
-- ids (integers), which are used when unsubscribing.
local subscriptions = {}

-- Publishers and message queue, primarily for the STOMP channels, but also for
-- some special messages like ondisconnect and onconnect.
--
-- Incoming messages are accumulated into a queue and handled in a separate
-- coroutine because we receive messages in a callback called from libwebsockets
-- and can't easily switch to another coroutine at that point.
local publishers = tabop.memoize(util.createpublisher)
local inmsgs = Queue()

-- A namespace for the various callbacks that are used to interact with stompws.
local stompcb = {}

-- Forward-declare function connect().
local connect

local function try_connect()
    shims.create_stoppable_timer('cloud-connector', 0, function()
        if not keep_connection then
            return nil
        end
        local ok, err = pcall(connect)
        if ok then
            return nil
        end
        cujo.log:error('Failed to connect to cloud: '..err)
        assert(cujo.config.backoff.range >= 0)
        assert(cujo.config.backoff.range <= 1)
        local min = math.ceil(backoff * cujo.config.backoff.range)
        local max = math.ceil(backoff)
        local duration = math.random(min, max)
        cujo.log:stomp('backoff duration: ', duration, ' range:[', min, ', ', max, ']')
        backoff = backoff * cujo.config.backoff.factor
        if backoff > cujo.config.backoff.max then
            backoff = cujo.config.backoff.max
        end
        return duration
    end)
end

function stompcb.failure(conn, err)
    cujo.log:error('STOMP failure: ', err)
end

function stompcb.error(conn, headers, body)
    cujo.log:error('STOMP error: headers=', headers, ' body=', body)
end

-- Client heartbeat timer: On timeout, we need to send a heartbeat.
local function client_timeout_handler(conn)
    heartbeat = true
    conn:send()
end

-- Broker heartbeat timer: On timeout, we need to reconnect.
local function broker_timeout_handler(conn)
    if inputev.busy then
        cujo.log:stomp'ignoring broker heartbeat timeout, busy handling message'
    else
        cujo.log:stomp'broker heartbeat timeout, disconnecting'
        close = true
        conn:send()
    end
end

-- Called when the WebSocket connection has been established.
function stompcb.established(conn)
    cujo.log:stomp'connection established'

    backoff = cujo.config.backoff.initial

    close = false
    heartbeat = false

    if broker_timeout_stop ~= nil then
        -- Not expected, but play it safe to make sure we don't end up
        -- with two timers.
        broker_timeout_stop()
    end
    broker_timeout_stop, broker_timeout_reset = shims.create_resettable_timer(
        'cloud-broker-timeout-handler',
        10 * max_broker_timeouts,
        function() return broker_timeout_handler(conn) end)
end

-- Called when the STOMP "CONNECTED" frame has been received from the server.
function stompcb.connected(conn)
    cujo.log:stomp'connected'
    conn:send()

    local client_heartbeat, broker_heartbeat = conn:get_heartbeat()

    if client_timeout_stop ~= nil then
        -- Not expected, but play it safe to make sure we don't end up
        -- with two timers.
        client_timeout_stop()
    end
    client_timeout_stop, client_timeout_reset = shims.create_resettable_timer(
        'cloud-client-timeout-handler',
        client_heartbeat / 1000,
        function() return client_timeout_handler(conn) end)

    broker_timeout_reset(broker_heartbeat / 1000 * max_broker_timeouts)
end

-- Called when the WebSocket connection has been closed.
function stompcb.closed(conn, err)
    if err then cujo.log:error('STOMP connection failure: ', err) end
    if connect_msg_sent then
        shims.concurrency_limited_do(inmsgs, {cujo.cloud.ondisconnect})
        connect_msg_sent = false
    end
    cujo.log:stomp('connection closed')
    if client_timeout_stop ~= nil then
        client_timeout_stop()
        client_timeout_stop = nil
    end
    if broker_timeout_stop ~= nil then
        broker_timeout_stop()
        broker_timeout_stop = nil
    end
    cujo.cloud.forbid_sending_to_cloud()

    for channel in pairs(subscriptions) do
        pending_subscriptions[channel] = false
        subscriptions[channel] = nil
    end

    try_connect()
end

-- Called when we have received a complete STOMP message ("MESSAGE" frame).
function stompcb.message(conn, headers, body)
    local destination = headers.destination
    local channel = string.match(destination, channel_pattern)
    if not channel then
        return cujo.log:error('illegal STOMP destination: ', destination)
    end

    cujo.log:stomp("got message to channel '", channel, "': ", body)

    local publisher = publishers[channel]
    if publisher:empty() then
        publishers[channel] = nil
        return cujo.log:error('no handler for STOMP channel ', channel)
    end
    local ok, body = pcall(json.decode, body, 'nil')
    if not ok then return cujo.log:error('invalid STOMP json to ', channel) end

    shims.concurrency_limited_do(inmsgs, {channel, body})
end

-- Called after any kind of send has finished successfully.
local function finish_send(conn)
    client_timeout_reset()
    heartbeat = false

    -- If there's still something that we want to send, ask for a send to be
    -- triggered again.
    if not outmsgs:empty() or next(pending_subscriptions) ~= nil or
        not connect_msg_sent then
        conn:send()
    end
end

local function send_close()
    return 'close', function (res)
        if res < 0 then
            return cujo.log:error('failed to send disconnection message res: ', res)
        end
        cujo.log:stomp("disconnecting")
    end
end

local function send_connect(conn)
    return 'send', '/connect', json.encode{
        -- device parameters
        hwrev = cujo.config.hardware_revision,
        mode = 'EMBEDDED',
        -- build parameters
        version = cujo.config.build_version,
        build_number = cujo.config.build_number,
        build_time = cujo.config.build_time,
        kernel = cujo.config.build_kernel,
        build_arch = cujo.config.build_arch,
        -- network parameters
        gateway = cujo.config.gateway_mac,
        gateway_ip = cujo.config.gateway_ip,
        gateway_ipv6 = cujo.config.wan_ipv6addr,
    }, function (res)
        if res < 0 then
            return cujo.log:error('STOMP sending connect message res: ', res)
        end
        shims.concurrency_limited_do(inmsgs, {cujo.cloud.onconnect})
        connect_msg_sent = true
        finish_send(conn)
    end
end

local function send_msg(conn, msg)
    cujo.log:stomp('sending message to ', msg.channel, ", ", msg.body_str)

    return 'send', '/' .. msg.channel, msg.body_json, function (res)
        if res < 0 then
            return cujo.log:error('STOMP failed to send message to ', msg.channel,
                             ' res: ', res)
        end
        outmsgs:dequeue()
        finish_send(conn)
    end
end

local function send_subscribe(conn, channel)
    local unsub = pending_subscriptions[channel]
    local id = subscriptions[channel]
    if unsub then
        assert(id ~= nil)
        return 'unsubscribe', id, local_dest_prefix .. channel, function (res)
            if res < 0 then
                return cujo.log:error('failed to unsubscribe from STOMP channel: ',
                    channel, ' res: ', res)
            end
            cujo.log:stomp("unsubscribed from channel '", channel, "' (id=", id, ')')
            subscriptions[channel] = nil
            pending_subscriptions[channel] = nil
            finish_send(conn)
        end
    else
        assert(id == nil)
        return 'subscribe', local_dest_prefix .. channel, function (res)
            if res < 0 then
                return cujo.log:error('failed to subscribe to STOMP channel: ', channel,
                                 ' res: ', res)
            end
            cujo.log:stomp("subscribed to channel '", channel, "' (id=", res, ')')
            subscriptions[channel] = res
            pending_subscriptions[channel] = nil
            finish_send(conn)
        end
    end
end

local function send_heartbeat(conn)
    cujo.log:stomp('sending heartbeat')
    return 'heartbeat', function (res)
        if res < 0 then
            return cujo.log:error('STOMP failed sending heartbeat res: ', res)
        end
        finish_send(conn)
    end
end

-- Called when we're ready to send something. See [sending] for the whole flow
-- around this.
function stompcb.send(conn)
    if close then return send_close() end

    local channel = next(pending_subscriptions)
    if channel then return send_subscribe(conn, channel) end

    if not connect_msg_sent then return send_connect(conn) end

    local message = outmsgs:head()
    if message then return send_msg(conn, message) end

    if heartbeat then return send_heartbeat(conn) end
end

-- Called when we receive any data over the WebSocket connection.
--
-- stompcb.message may or may not get called immediately after, depending on
-- whether this data is part of a STOMP "MESSAGE" frame and whether we need more
-- data to complete the frame.
function stompcb.receive(conn) broker_timeout_reset() end

------------------------------------------------------------------------
-- [fd-handling]
--
-- To integrate with third-party event handling systems like coutil,
-- libwebsockets provides an API in which it informs us about fds (file
-- descriptors) coming and going, or changing from being interested in read
-- events to being interested in write events and vice versa.
--
-- Much of this is overkill for our needs since we maintain only one WebSocket
-- connection and hence should have only one fd.
--
-- However, change_mode_fd is critical, since it is used to indicate whether we
-- are waiting on the socket to become readable or writable. We adjust coutil's
-- socket events as appropriate.

function stompcb.change_mode_fd(conn, fd, read, write, prev_read, prev_write)
    local entry = fds[fd]
    if entry.read ~= entry then sockev.cancel(entry.read) end
    if entry.write ~= entry then sockev.cancel(entry.sock, entry.write) end
    entry.read = entry
    entry.write = entry
    if read then entry.read = sockev.create(entry.sock) end
    if write then entry.write = sockev.create(entry.sock, {}) end
    event.emitone(entry)
end

function stompcb.add_fd(conn, fd, read, write)
    -- HACK: Create a TCP socket object wrapping the fd, just for the sake
    -- of coutil being able to select() on it.
    local sock = socket.tcp()
    sock:close()
    sock:setfd(fd)
    local entry = {sock = sock}
    entry.read = entry
    entry.write = entry
    fds[fd] = entry

    if read then entry.read = sockev.create(entry.sock) end
    if write then entry.write = sockev.create(entry.sock, {}) end
    event.emitone(entry)

    -- Await socket events on the fd, and ask libwebsockets to service the
    -- fd appropriately.
    --
    -- Receiving the entry itself as an event indicates that we should
    -- re-check the fd for what kind of events we are interested in
    -- (read/write) or for whether the fd has been closed entirely.
    cujo.jobs.spawn('cloud-conn-fd-awaiter', function ()
        while true do
            local entry = fds[fd]
            if entry == nil then break end
            local ev = event.awaitany(entry, entry.read, entry.write)
            if ev == entry.read and inputev.busy then
                entry.pending_read = true
            elseif ev ~= entry then
                conn:dispatch(fd, ev == entry.read, ev == entry.write)
            end
        end
    end)
end

function stompcb.del_fd(conn, fd)
    local entry = fds[fd]
    entry.sock:setfd(-1)
    fds[fd] = nil
    event.emitone(entry)
    if entry.read ~= entry then sockev.cancel(entry.read) end
    if entry.write ~= entry then sockev.cancel(entry.sock, entry.write) end
    entry.read = entry
    entry.write = entry
end

------------------------------------------------------------------------

local connection

local module = {
    -- Called when a routing-service request is made, whether successful or
    -- not.
    --
    -- Parameters:
    -- 1. True iff the request was successful
    -- 2. True iff the endpoint used was not the default_route
    -- 3. The endpoint used (from routes or default_route)
    -- 4. An error message in case the request failed, otherwise nil
    ongetroute = cloudauth.ongetroute,

    -- Called after authenticating to agent-service, whether successful or
    -- not. Note that depending on the authentication mechanism, this can be
    -- redundant with ongetroute since e.g. the "ident" method succeeds iff
    -- getting a route succeeds.
    --
    -- Parameters:
    -- 1. True iff authenticating succeeded
    -- 2. An error message in case the request failed, otherwise nil
    onauth = util.createpublisher(),

    -- Called after successfully establishing a WebSocket connection to
    -- agent-service.
    onconnect = util.createpublisher(),

    -- Called after the WebSocket connection to agent-service is
    -- disconnected.
    ondisconnect = util.createpublisher(),

    -- Called after the agent enters hibernation. These calls happen as part
    -- of a subset of ondisconnect calls, in which the disconnect was
    -- intended and caused by hibernation.
    onhibernate = util.createpublisher(),

    -- Called after the agent wakes up from hibernation. These calls happen
    -- as part of a subset of onconnect calls, in which the agent was
    -- hibernating prior to connecting.
    onwakeup = util.createpublisher(),
}

publishers[module.onconnect]:subscribe(module.onconnect)
publishers[module.ondisconnect]:subscribe(module.ondisconnect)

local function setsubscribed(channel, enabled)
    local current = (subscriptions[channel] ~= nil)
    if enabled ~= current then
        pending_subscriptions[channel] = not enabled
        if connection:is_connected() then connection:send() end
    else
        pending_subscriptions[channel] = nil
    end
end

function module.subscribe(channel, handler)
    publishers[channel]:subscribe(handler)
    setsubscribed(channel, true)
end

-- This is helper function to get a status of cloud connection
function module.is_connected()
    return connection:is_connected()
end

function module.unsubscribe(channel, handler)
    local publisher = publishers[channel]
    publisher:unsubscribe(handler)
    if publisher:empty() then
        publishers[channel] = nil
        setsubscribed(channel, false)
    end
end

function connect()
    -- Fetch the Agent Service endpoint to connect to from the Routing
    -- Service, authenticating as needed.
    cloudauth.auth(function(url, err)
        if not url then
            cujo.cloud.onauth(false, err)
            error('STOMP failed to get authentication url ('..err..')')
        end
        cujo.log:stomp('Connecting to URL ', url)
        local url, err = cujo.https.parse(url)
        if not url then
            cujo.cloud.onauth(false, err)
            return nil, err
        end
        cujo.cloud.onauth(true, url)

        -- Open the WebSocket connection.

        local usessl = (url.scheme ~= 'https' and 0) or
            ((cujo.config.tls and cujo.config.tls.cafile) and 1 or 2)

        cujo.log:stomp("Connecting to '", url.host, ':', url.port, "'")
        local function handler(err)
            if err == 'already connected' then return nil end
            return err
        end
        local _, err = xpcall(connection.connect, handler, connection,
            usessl, url.host, tonumber(url.port),
            url.path .. '?' .. url.query, url.host, 'agent',
            cujo.config.cloud_iface)
        if err ~= nil then
            error(err)
        end
    end)
end

function module.connect()
    keep_connection = true
    if not connection:is_connected() then try_connect() end
end

function module.disconnect()
    cujo.log:stomp'terminating connection'
    keep_connection = false
    if connection:is_connected() then
        close = true
        connection:send()
    end
end

function module.allow_sending_to_cloud()
    outmsgs:enqueue{channel = 'resync', body_json = "{}"}
    cujo.log:stomp('requeuing ', #inactive_outmsgs, ' output messages from inactive queue')
    for _, msg in pairs(inactive_outmsgs) do
        outmsgs:enqueue(msg)
    end
    inactive_outmsgs = Queue()
    if connection:is_connected() then
        connection:send()
    end
    resync_msg_sent = true
end

function module.forbid_sending_to_cloud()
    cujo.log:stomp('requeuing ', #outmsgs, ' output messages to inactive queue')
    for _, msg in pairs(outmsgs) do
        inactive_outmsgs:enqueue(msg)
    end
    outmsgs = Queue()
    resync_msg_sent = false
end

local dropped_messages = 0

-- Queue the JSON-encoded form of the given object for sending.
--
-- The encoding happens immediately i.e. this does not retain any part of the
-- object, so its contents can be overwritten by the caller at any time.
function module.send(channel, body)
    local msg_queue = outmsgs

    if not resync_msg_sent then
        msg_queue = inactive_outmsgs
    end

    if #msg_queue >= cujo.config.maxcloudmessages then
        msg_queue:dequeue()
        dropped_messages = dropped_messages + 1
        if dropped_messages == 1 then
            cujo.log:warn('start dropping messages')
        end
    elseif dropped_messages ~= 0 then
        cujo.log:warn('stop dropping messages (', dropped_messages, ' dropped)')
        dropped_messages = 0
    end
    local body_str = tostring(body)
    local body_json = json.encode(body)
    cujo.log:stomp("queueing message to ", channel, ", ", body_str)
    msg_queue:enqueue{channel = channel, body_str = body_str, body_json = body_json}
    if connection:is_connected() and resync_msg_sent then
        connection:send()
    end

end

function module.initialize()
    cloudauth.initialize()

    backoff = cujo.config.backoff.initial

    connection = stompws.new(
        function (kind, ...) return stompcb[kind](...) end,
        cujo.config.tls and cujo.config.tls.cafile)

    -- Allocate some time for libwebsockets to handle its own internal
    -- timers and the like.
    shims.create_timer('cloud-conn-dispatcher', 1, function ()
        connection:dispatch()
    end)

    -- Awaits messages and calls the corresponding message handlers.
    shims.concurrency_limited_setup(inmsgs, 1, function() return 'cloud-msg-receiver' end, function(msg, callback)
        local channel, body = table.unpack(msg)
        assert(not inputev.busy)
        inputev.busy = true
        local ok, err = xpcall(publishers[channel], debug.traceback, channel, body)

        if not ok then
            cujo.log:error("error on '", channel, "' message: ", body,
                ' error: ', err)
        end
        inputev.busy = false

        -- Prevent race condition: If there's a broker heartbeat
        -- timeout scheduled right now, the yield will trigger
        -- broker_timeout_handler and cause a disconnect, even
        -- though we may have a new message that'll reset the
        -- timeout as soon as we dispatch.
        broker_timeout_reset()

        shims.yield(function()
            -- If there's data available in any socket buffer that
            -- we weren't willing to read while we were busy, tell
            -- libwebsockets to read it out.
            for fd, entry in pairs(fds) do
                if entry.pending_read then
                    entry.pending_read = nil
                    connection:dispatch(fd, true, false)
                end
            end
            return callback()
        end)
    end)

    for k, v in pairs(require'cujo.cloud.proto') do cujo.cloud.subscribe(k, v) end
end

return module
