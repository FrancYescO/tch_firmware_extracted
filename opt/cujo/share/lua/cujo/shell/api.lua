--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

local oo = require'loop.base'
local socket = require'socket.unix'
local json = require'json'

local Channel = oo.class{print = function () end}

function Channel:close()
	if self.sock == nil then return nil, "disconnected" end
	self.sock:close()
	self.sock = nil
	return true
end

function Channel:isclosed()
	return self.sock == nil
end

function Channel:execute(name, code, ...)
	if self.sock == nil then return false, 'request', 'not connected' end
	local msg = json.encode{name = name, code = code, args = {...}}
	local ok, err = self.sock:send(msg:len() .. '\n' .. msg)
	if not ok then return false, 'request', err end
	while true do
		local data, err = self.sock:receive'*l'
		if not data then return false, 'socket', err end

		local size = tonumber(data)
		if not size then return false, 'reply', 'invalid size: ' .. data end

		data, err = self.sock:receive(size)
		if not data then return false, 'socket', err end

		msg = json.decode(data)
		if msg.type ~= 'print' then
			break
		end
		self.print(msg.args)
	end
	if msg.type ~= 'ret' then return false, table.unpack(msg.args) end
	return true, msg.args
end

local module = {}

function module.connect(sockpath)
	local sock, err = socket.stream()
	if not sock then
		return nil, err
	end

	local res, err = sock:connect(sockpath)
	if not res then
		sock:close()
		return nil, err
	end

	return Channel{sock = sock}
end

return module
