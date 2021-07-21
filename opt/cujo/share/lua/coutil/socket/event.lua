local _G = require "_G"
local ipairs = _G.ipairs

local event = require "coutil.event"
local emitevent = event.emitall
local pendingevent = event.pending

local socketcore = require "socket.core"
local selectsockets = socketcore.select

local function addsocket(list, socket)
	if list[socket] == nil then
		local index = 1 + (list.n or 0)
		list[index] = socket
		list[socket] = index
		list.n = index
		return socket
	end
end

local function removesocket(list, socket)
	local index = list[socket]
	if index ~= nil then
		local size = list.n
		if index ~= size then
			local last = list[size]
			list[index] = last
			list[last] = index
		end
		list[size] = nil
		list[socket] = nil
		list.n = size - 1
		return socket
	end
end

local reading = {}
local writing = {}
local writeof = {}

local module = {}

function module.create(socket, write)
	local list, event = reading, socket
	if write ~= nil then
		writeof[socket] = write
		list, event = writing, write
	end
	addsocket(list, socket)
	return event
end

function module.cancel(socket, write)
	local list, event = reading, socket
	if write ~= nil then
		list, event = writing, write
	end
	if not pendingevent(event) and removesocket(list, socket) then
		if event == write then
			writeof[socket] = nil
		end
		return true
	end
	return false
end

function module.emitall(timeout)
	if #reading > 0 or #writing > 0 then
		local recvok, sendok = selectsockets(reading, writing, timeout)
		for _, socket in ipairs(recvok) do
			if not emitevent(socket) then
				removesocket(reading, socket)
			end
		end
		for _, socket in ipairs(sendok) do
			if not emitevent(writeof[socket]) then
				removesocket(writing, socket)
				writeof[socket] = nil
			end
		end
		return true
	end
	return false
end

return module
