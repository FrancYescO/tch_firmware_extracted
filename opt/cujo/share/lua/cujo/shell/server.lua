--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

local function sendmsg(channel, kind, ...)
	local msg = json.encode{type = kind, args = {...}}
	local ok, err = channel:send(msg:len() .. '\n' .. msg)
	if not ok then
		cujo.log:error('rabidctl failed send reply: ', err)
	end
end

local function sendresult(channel, ok, ...)
	if ok then
		sendmsg(channel, 'ret', vararg.map(tostring, ...))
	else
		sendmsg(channel, 'err', 'exec', ...)
	end
end

local function reader(channel)
	channel:settimeout(cujo.config.rabidctl.timeout)
	while true do
		local data, err = channel:receive'*l'
		if not data then
			if err ~= 'closed' then
				cujo.log:error('rabidctl failed to receive message size: ', err)
			end
			break
		end

		local msgsize = tonumber(data)
		if not msgsize then
			cujo.log:error('rabidctl received illegal message size: ', data)
			break
		end

		local data, err = channel:receive(msgsize)
		if not data then
			cujo.log:error('rabidctl failed to receive message body: ', err)
			break
		end

		local ok, msg = pcall(json.decode, data)
		if not ok then
			cujo.log:error('rabidctl failed to decode message: ', msg)
			break
		end

		local env = {}
		local f, err = load(msg.code, msg.name, 't', env)
		if not f then
			sendmsg(channel, 'err', 'load', err)
		else
			function env.print(...)
				if channel then
					sendmsg(channel, 'print', vararg.map(tostring, ...))
				else
					cujo.log:warn('rabidctl unable to print to disconnected client: ', ...)
				end
			end
			setmetatable(env, {__index = _G})
			sendresult(channel, xpcall(f, debug.traceback, table.unpack(msg.args)))
		end
	end
	channel:close()
	channel = nil
end

local sockpath = cujo.config.rabidctl.sockpath
os.remove(sockpath)
local sock = assert(socket.stream())
assert(sock:bind(sockpath))
assert(sock:listen())

cujo.jobs.spawn('shell-server', function ()
	while true do
		local channel, err = sock:accept()
		if not channel then
			if err == 'closed' then break end
			cujo.log:error('rabidctl failed to accept connection: ', err)
		else
			cujo.jobs.spawn('shell-reader', reader, channel)
		end
	end
end)
