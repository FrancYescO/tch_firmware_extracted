-- luacheck: read globals cujo

local event = require "coutil.event"
local socket = require "coutil.socket"
local socket_core = require "socket"
local socket_unix = require "socket.unix"
local socket_event = require "coutil.socket.event"
local time = require "coutil.time"

local module = {}

-- Like os.time(), but offers sub-second precision.
function module.gettime()
    return socket.gettime()
end

function module.yield(func)
    time.sleep(0)
    return func()
end

function module.create_timer(job_name, interval, func)
    cujo.jobs.spawn(job_name, function ()
        while true do
            func()
            time.sleep(interval)
        end
    end)
end

-- Returns a function that can be called to stop the timer.
--
-- The timer function should return the new interval to use each time it is
-- called. If it returns nil, the timer stops.
function module.create_stoppable_timer(job_name, interval, func)
    local stop_event = {}
    cujo.jobs.spawn(job_name, function ()
        while interval ~= nil do
            if time.sleep(interval, stop_event) == stop_event then
                break
            end
            interval = func()
        end
    end)
    return function() event.emitone(stop_event) end
end

-- Returns two functions.
--
-- The first can be called to stop the timer.
--
-- The second can be called to restart the timer, optionally setting a new
-- interval. It will also re-create the timer if it has been stopped.
function module.create_resettable_timer(job_name, interval, func)
    local stop_event = {}
    local reset_event = {}
    local running
    local function create()
        running = true
        cujo.jobs.spawn(job_name, function ()
            while running do
                local ev = time.sleep(interval, stop_event, reset_event)
                if ev == stop_event then
                    break
                elseif ev ~= reset_event then
                    func()
                end
            end
        end)
    end
    local function stop()
        running = false
        event.emitone(stop_event)
    end
    local function reset(new_interval)
        interval = new_interval or interval
        if running then
            event.emitone(reset_event)
        else
            create()
        end
    end
    return stop, reset
end

-- Returns a function that can be called to stop the timer.
--
-- The function will be called with a boolean, true iff the timer was stopped,
-- followed by any additional arguments passed to the stop function.
function module.create_oneshot_timer(job_name, delay, func)
    local stop_event = {}
    cujo.jobs.spawn(job_name, function ()
        local wakeup = table.pack(time.sleep(delay, stop_event))
        return func(wakeup[1] == stop_event, table.unpack(wakeup, 2))
    end)
    return function(...) event.emitone(stop_event, ...) end
end

-- ipv should be either the string "ip4" or "ip6".
function module.socket_create_udp(ipv)
    if ipv == "ip4" then
        return socket.udp()
    elseif ipv == "ip6" then
        return socket.udp6()
    else
        error("invalid ipv")
    end
end

function module.socket_create_netlink(family, port, callback)
    local sock = assert(socket.netlink(family))
    assert(sock:bind(port))
    return callback(sock)
end

-- Sets the socket's receive or send buffer size to the given size, unless it's
-- already bigger.
local function set_socket_buf(sock, min_size, opt, opt_force)
    local current, err = sock:getoption(opt)
    if not err and current < min_size then
        local _
        _, err = sock:setoption(opt_force, min_size)
    end
    return err
end

function module.socket_set_recv_buf(sock, min_size)
    return set_socket_buf(sock, min_size, 'rcvbuf', 'rcvbufforce')
end

function module.socket_set_send_buf(sock, min_size)
    return set_socket_buf(sock, min_size, 'sndbuf', 'sndbufforce')
end

-- Bind to the given IP and port.
function module.socket_setsockname(sock, ip, port)
    return sock:setsockname(ip, port)
end

-- Join the multicast group identified by the IPv4 address in ip_multi, using
-- the IPv4 address in ip_local to identify the interface that should join.
function module.socket_add_membership(sock, ip_multi, ip_local)
    return sock:setoption("ip-add-membership", {multiaddr = ip_multi, interface = ip_local})
end

-- Join the multicast group identified by the IPv6 address in ip_multi, using
-- the given interface index to identify the interface that should join.
function module.socket_add_membership6(sock, ip_multi, interface)
    return sock:setoption("ipv6-add-membership", {multiaddr = ip_multi, interface = interface})
end

function module.socket_send(sock, payload, addr, port, callback)
    local ok, err = sock:sendto(payload, addr, port)
    return callback(ok, err)
end

-- Send to nflua using NETLINK_GENERIC.
function module.socket_send_nflua_generic(sock, payload, dstpid, callback)
    local ok, err = sock:sendtogennflua(payload, dstpid)
    return callback(ok, err)
end

function module.on_nflua_payload(sock, handler)
    cujo.jobs.spawn("nflua-reader", function()
        while true do
            handler(sock:receivefrom())
        end
    end)
end

function module.on_nflua_generic_payload(sock, handler)
    cujo.jobs.spawn("nflua-reader", function()
        while true do
            handler(sock:receivefromgen())
        end
    end)
end

-- This is a pretty messy one, supporting the case of arbitrarily speed-limited
-- reading from a netlink socket by libmnl.
--
-- Given the netlink socket described by fd, set its receive buffer size as
-- given and then call the handler whenever the socket has some data available
-- to read. The handler should return either:
--
-- 1. Nothing or nil, indicating that the handler should be called again
--    immediately.
--
-- 2. 'done', indicating that the socket should be re-polled before calling the
--    handler again.
--
-- 3. 'delay' and a timestamp, indicating that the handler should be called
--    again after the timestamp.
--
-- This function returns two functions:
--
-- 1. Stops the socket polling. If we were waiting on the socket, the handler
--    will no longer be called. Otherwise, the handler will still be called
--    until it next returns 'done', but not thereafter.
--
-- 2. Takes a function as an argument, and sets it as a one-time callback to be
--    invoked after the handler next returns 'done'. The callback may use this
--    function to set a new callback for next time.
function module.on_mnl_readable(fd, recv_buf_size, handler)
    -- Wrap the underlying socket in a LuaSocket object.
    local sock = socket_core.tcp()
    sock:close()
    sock:setfd(fd)
    sock:settimeout(0)

    local err = module.socket_set_recv_buf(sock, recv_buf_size)
    if err then
        cujo.log:error("Failed to set ", sock, "recv buf: ", err)
    end

    local callback = nil

    cujo.jobs.spawn("mnl-reader", function()
        while true do
            -- Allow coutil to select() on this socket and wait for activity. We
            -- need to do this every time since if coutil sees activity on the
            -- socket while we're not waiting on it (i.e. if handler() causes this
            -- coroutine to get suspended), coutil will think we forgot about the
            -- socket and hence not select() on it any more.
            socket_event.create(sock)
            local die = event.await(sock)
            socket_event.cancel(sock)
            if die then
                break
            end

            while true do
                local status, delay_until = handler()
                if status == 'done' then
                    break
                elseif status == 'delay' then
                    time.waituntil(delay_until)
                else
                    assert(status == nil)
                end
            end

            if callback ~= nil then
                -- Unset the callback because it should be single-use, but the
                -- callback itself might be the one that sets it again, so make sure
                -- to unset it before calling it.
                local cb = callback
                callback = nil
                cb()
            end
        end
    end)

    local function stop()
        event.emitall(sock, true)
    end
    local function set_callback(cb)
        callback = cb
    end
    return stop, set_callback
end

-- Run the shell server, which communicates with the shell client (see below).
--
-- Communication should take place over a Unix domain socket in 'sockpath',
-- which this function should create. The exact protocol can be anything, as
-- long as run_shell_server and run_shell_client can co-operate.
--
-- The handler function receives three arguments:
-- 1. The data received on the connection (opaque from our point of view).
-- 2. A boolean indicating whether async execution was desired.
-- 3. A "write" function that can be used to send data over the connection. Note
--    that writes may complete asynchronously.
function module.run_shell_server(sockpath, timeout, on_err, handler)
    cujo.jobs.spawn('shell-server', function ()
        local sock = assert(socket.stream())
        assert(sock:bind(sockpath))
        assert(sock:listen())
        while true do
            local channel, err = sock:accept()
            if not channel then
                if err == 'closed' then
                    break
                end
                on_err('rabidctl failed to accept connection: ', err)
                goto continue
            end
            channel:settimeout(timeout)
            cujo.jobs.spawn('shell-reader', function()
                while true do
                    local data

                    data, err = channel:receive('*l')
                    if not data then
                        if err ~= 'closed' then
                            on_err('rabidctl failed to receive message size: ', err)
                        end
                        break
                    end

                    local async
                    async, err = channel:receive'*l'
                    if not async then
                        on_err('rabidctl failed to receive asynchronicity: ', err)
                        break
                    end
                    local is_async = async == "async"

                    local msgsize = tonumber(data)
                    if not msgsize then
                        on_err('rabidctl received illegal message size: ', data)
                        break
                    end

                    data, err = channel:receive(msgsize)
                    if not data then
                        on_err('rabidctl failed to receive message body: ', err)
                        break
                    end

                    if not handler(data, is_async, function(msg) return channel:send(msg:len() .. '\n' .. msg) end) then
                        break
                    end
                end
                channel:close()
            end)
            ::continue::
        end
    end)
end

-- Run the shell client, which communicates with the shell server (see above).
--
-- Communication should take place over a Unix domain socket in 'sockpath',
-- which this function should connect to. The exact protocol can be anything, as
-- long as run_shell_client and run_shell_server can co-operate.
--
-- The handler function receives just one argument: The data received in
-- response to a message (opaque from our point of view).
function module.run_shell_client(sockpath, is_async, messages, on_no_connect, on_err, handler)
    local sock, err = socket_unix.stream()
    if not sock then
        return on_no_connect(err)
    end

    local ok
    ok, err = sock:connect(sockpath)
    if not ok then
        sock:close()
        return on_no_connect(err)
    end

    local async
    if is_async then
        async = "async\n"
    else
        async = "\n"
    end

    for _, msg in ipairs(messages) do
        ok, err = sock:send(msg:len() .. '\n' .. async .. msg)
        if not ok then
            on_err('request error\t' .. err)
            goto continue
        end
        while true do
            local data
            data, err = sock:receive('*l')
            if not data then
                on_err('socket error\t' .. err)
                break
            end

            local size = tonumber(data)
            if not size then
                on_err('reply error\t' .. 'invalid size: ' .. data)
                break
            end

            data, err = sock:receive(size)
            if not data then
                on_err('socket error\t' .. err)
                break
            end

            if not handler(data) then
                break
            end
        end
        ::continue::
    end

    sock:close()
end

-- Initialize a concurrency-limited message handler on the given queue. The
-- given handler will be called on any message put into the queue, with a
-- restriction on the number of handlers that can be running simultaneously.
--
-- The queue can be any object that supports :dequeue and :enqueue operations.
-- :dequeue should return nil if the queue is empty.
--
-- The handler will be called with two parameters: The message, and a callback
-- for what to do on completion.
function module.concurrency_limited_setup(queue, limit, job_namer, handler)
    for i = 1, limit do
        cujo.jobs.spawn(job_namer(i), function()
            while true do
                local msg = queue:dequeue()
                if msg == nil then
                    event.await(queue)
                else
                    handler(msg, function() end)
                end
            end
        end)
    end
end

-- Enqueue a message into the given queue, and inform the handler that was setup
-- with concurrency_limited_setup that there is new work to be done. The handler
-- should get called as soon as there is leeway (i.e. the concurrency limit is
-- not exceeded).
--
-- Must be called only after concurrency_limited_setup.
function module.concurrency_limited_do(queue, msg)
    queue:enqueue(msg)
    event.emitone(queue)
end

return module
