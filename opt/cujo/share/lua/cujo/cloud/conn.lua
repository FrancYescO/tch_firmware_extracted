--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

local stompws = require'stompws'
local Queue = require'loop.collection.Queue'
local sockev = require'coutil.socket.event'
local cloudauth = require'cujo.cloud.auth'

local local_dest_prefix = '/user/queue/'
local channel_pattern = '^' .. local_dest_prefix .. '([%w_%-]+)$'

local max_broker_timeouts = 5

local fds = {}

local keep_connection = false
local backoff = cujo.config.backoff.initial

local reset_client = {}
local reset_broker = {}
local terminate = {}

local inputev = {busy = false}
local connect_msg_sent
local heartbeat
local pending_subscriptions = {} -- [channel] = boolean
local close
local subscriptions = {} -- [channel] = integer

local connect

local publishers = tabop.memoize(cujo.util.createpublisher)
local inmsgs = cujo.jobs.createqueue()
local stompcb = {}

local function try_reconnect()
	if not keep_connection then return end
	cujo.jobs.spawn('cloud-reconnector', function ()
		assert(cujo.config.backoff.range >= 0)
		assert(cujo.config.backoff.range <= 1)
		local min = math.ceil(backoff * cujo.config.backoff.range)
		local max = math.ceil(backoff)
		local duration = math.random(min, max)
		cujo.log:stomp('backoff duration: ', duration,
			' range:[', min, ', ', max, ']')
		backoff = backoff * cujo.config.backoff.factor
		if backoff > cujo.config.backoff.max then
			backoff = cujo.config.backoff.max
		end
		time.sleep(duration)
		connect()
	end)
end

function stompcb.failure(conn, err)
	cujo.log:error('STOMP failure: ', err)
end

function stompcb.error(conn, headers, body)
	cujo.log:error('STOMP error: headers=', headers, ' body=', body)
end

local function client_timeout_handler(conn)
	local timeout, t
	while true do
		local ev, par = cujo.jobs.wait(t, terminate, reset_client)
		if ev == reset_client then
			if par ~= nil then timeout = par end
			t = timeout
			heartbeat = false
		elseif ev == terminate then
			return
		else
			heartbeat = true
			conn:send()
			t = nil
		end
	end
end

local function broker_timeout_handler(conn)
	local timeout, t
	while true do
		local ev, par = cujo.jobs.wait(t, terminate, reset_broker)
		if ev == reset_broker then
			if par ~= nil then timeout = par end
			t = timeout * max_broker_timeouts
		elseif ev == terminate then
			return
		elseif inputev.busy then
			cujo.log:stomp'ignoring broker heartbeat timeout, busy handling message'
		else
			cujo.log:stomp'broker heartbeat timeout, disconnecting'
			close = true
			conn:send()
			t = nil
		end
	end
end

function stompcb.established(conn)
	cujo.log:stomp'connection established'

	backoff = cujo.config.backoff.initial

	close = false
	heartbeat = false

	cujo.jobs.spawn('cloud-broker-timeout-handler', broker_timeout_handler, conn)
	event.emitone(reset_broker, 10)
end

function stompcb.connected(conn)
	cujo.log:stomp'connected'
	conn:send()
	cujo.jobs.spawn('cloud-client-timeout-handler', client_timeout_handler, conn)

	local client_heartbeat, broker_heartbeat = conn:get_heartbeat()
	event.emitone(reset_client, client_heartbeat / 1000)
	event.emitone(reset_broker, broker_heartbeat / 1000)
end

function stompcb.closed(conn, err)
	if err then cujo.log:error('STOMP connection failure: ', err) end
	if connect_msg_sent then
		inmsgs:enqueue{cujo.cloud.ondisconnect}
		connect_msg_sent = false
	end
	cujo.log:stomp('connection closed')
	event.emitall(terminate)

	for channel in pairs(subscriptions) do
		pending_subscriptions[channel] = false
		subscriptions[channel] = nil
	end

	try_reconnect()
end

local outmsgs = Queue()

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

	inmsgs:enqueue{channel, body}
end

local function finish_send(conn)
	event.emitone(reset_client)
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
		inmsgs:enqueue{cujo.cloud.onconnect}
		connect_msg_sent = true
		finish_send(conn)
	end
end

local function send_msg(conn, msg)
	cujo.log:stomp('sending message to ', msg.channel)

	return 'send', '/' .. msg.channel, json.encode(msg.body), function (res)
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

function stompcb.send(conn)
	if close then return send_close() end

	local channel = next(pending_subscriptions)
	if channel then return send_subscribe(conn, channel) end

	if not connect_msg_sent then return send_connect(conn) end

	local message = outmsgs:head()
	if message then return send_msg(conn, message) end

	if heartbeat then return send_heartbeat(conn) end
end

function stompcb.receive(conn) event.emitone(reset_broker) end

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
	--TODO: avoid this hack to use STOMP underlying socket in LuaSocket
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

local connection = stompws.new(
	function (kind, ...) return stompcb[kind](...) end,
	cujo.config.tls and cujo.config.tls.cafile)

cujo.cloud = {
	onconnect = cujo.util.createpublisher(),
	ondisconnect = cujo.util.createpublisher(),
	onauth = cujo.util.createpublisher(),
	ongetroute = cloudauth.ongetroute,
	onhibernate = cujo.util.createpublisher(),
	onwakeup = cujo.util.createpublisher(),
}

publishers[cujo.cloud.onconnect]:subscribe(cujo.cloud.onconnect)
publishers[cujo.cloud.ondisconnect]:subscribe(cujo.cloud.ondisconnect)

local function setsubscribed(channel, enabled)
	pending_subscriptions[channel] = nil
	local current = (subscriptions[channel] ~= nil)
	if enabled ~= current then
		pending_subscriptions[channel] = not enabled
		if connection:is_connected() then connection:send() end
	end
end

function cujo.cloud.subscribe(channel, handler)
	publishers[channel]:subscribe(handler)
	setsubscribed(channel, true)
end

function cujo.cloud.unsubscribe(channel, handler)
	local publisher = publishers[channel]
	publisher:unsubscribe(handler)
	if publisher:empty() then
		publishers[channel] = nil
		setsubscribed(channel, false)
	end
end

function connect()
	local url, err = cloudauth.auth()
	if not url then
		cujo.cloud.onauth(false, err)
		cujo.log:error('STOMP failed to get authentication url (', err, ')')
		return try_reconnect()
	end
	cujo.log:stomp('Connecting to URL ', url)
	local url, err = cujo.https.parse(url)
	if not url then
		cujo.cloud.onauth(false, err)
		return nil, err
	end
	cujo.cloud.onauth(true, url)
	local usessl = (url.scheme ~= 'https' and 0) or
		((cujo.config.tls and cujo.config.tls.cafile) and 1 or 2)
	local host_ip = socket.dns.toip(url.host) or url.host

	cujo.log:stomp("Connecting to '", host_ip, ':', url.port, "'")
	local function handler(err)
		if err == 'already connected' then return nil end
		return err
	end
	local _, err = xpcall(connection.connect, handler, connection,
		usessl, host_ip, tonumber(url.port),
		url.path .. '?' .. url.query, url.host, 'agent',
		cujo.config.cloud_iface)
	if err ~= nil then
		error(err)
	end
end

function cujo.cloud.connect()
	keep_connection = true
	if not connection:is_connected() then connect() end
end

function cujo.cloud.disconnect()
	cujo.log:stomp'terminating connection'
	keep_connection = false
	if connection:is_connected() then
		close = true
		connection:send()
	end
end

local dropped_messages = 0

function cujo.cloud.send(channel, body)
	if #outmsgs >= cujo.config.maxcloudmessages then
		outmsgs:dequeue()
		dropped_messages = dropped_messages + 1
		if dropped_messages == 1 then
			cujo.log:warn('start dropping messages')
		end
	elseif dropped_messages ~= 0 then
		cujo.log:warn('stop dropping messages (', dropped_messages, ' dropped)')
		dropped_messages = 0
	end
	outmsgs:enqueue{channel = channel, body = body}
	if connection:is_connected() then connection:send() end
end

cujo.jobs.spawn('cloud-conn-dispatcher', function ()
	while true do
		time.sleep(1)
		connection:dispatch()
	end
end)

cujo.jobs.spawn('cloud-msg-receiver', function ()
	while true do
		local channel, body = table.unpack(inmsgs:dequeue())
		assert(not inputev.busy)
		inputev.busy = true
		local ok, err = xpcall(publishers[channel], debug.traceback, channel, body)

		if not ok then
			cujo.log:error("error on '", channel, "' message: ", body,
				' error: ', err)
		end
		inputev.busy = false

		-- Prevent race condition: If there's a broker heartbeat timeout
		-- scheduled right now, the time.sleep(0) will yield to
		-- broker_timeout_handler and cause a disconnect, even though we
		-- may have a new message that'll reset the timeout as soon as
		-- we dispatch.
		event.emitone(reset_broker)

		time.sleep(0)
		for fd, entry in pairs(fds) do
			if entry.pending_read then
				entry.pending_read = nil
				connection:dispatch(fd, true, false)
			end
		end
	end
end)

for k, v in pairs(require'cujo.cloud.proto') do cujo.cloud.subscribe(k, v) end
