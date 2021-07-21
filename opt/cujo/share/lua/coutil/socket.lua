local _G = require "_G"
local ipairs = _G.ipairs
local next = _G.next
local pcall = _G.pcall
local tostring = _G.tostring
local type = _G.type

local math = require "math"
local max = math.max

local array = require "table"
local concat = array.concat
local unpack = array.unpack

local table = require "loop.table"
local copy = table.copy

local socketcore = require "socket.core"
local selectsockets = socketcore.select
local createtcp = socketcore.tcp
local createudp = socketcore.udp
local createnetlink = socketcore.netlink
local suspendprocess = socketcore.sleep
local gettime = socketcore.gettime

local event = require "coutil.event"
local awaitany = event.awaitany

local sockevt = require "coutil.socket.event"
local watchsocket = sockevt.create
local forgetsocket = sockevt.cancel
local emitsockevents = sockevt.emitall

local timevt = require "coutil.time.event"
local setuptimer = timevt.create
local canceltimer = timevt.cancel

local time = require "coutil.time"
local setclock = time.setclock
local waketimers = time.run

local sockwrap = require "coutil.socket.wrap"
local newclass = sockwrap.newclass
local wrapsocket = sockwrap.wrapsocket
local setupevents = sockwrap.setupevents
local cancelevents = sockwrap.cancelevents

setclock(gettime)

local function idle(deadline)
	repeat
		local timeout = max(0, deadline() - gettime())
		if not emitsockevents(timeout) then
			suspendprocess(timeout)
		end
	until timeout == 0
end

local CoTCP = newclass()

function CoTCP:connect(...)
	-- connect the socket if possible
	local socket = self.__object
	local result, errmsg = socket:connect(...)
	
	-- check if the job has not yet been completed
	if not result and errmsg == "timeout" then
		local event, deadline = setupevents(socket, self, self)
		if event ~= nil then
			-- wait for a connection completion and finish establishment
			awaitany(event, deadline)
			-- cancel emission of events
			cancelevents(socket, self, deadline)
			-- try to connect again one last time before giving up
			result, errmsg = socket:connect(...)
			if not result and errmsg == "already connected" then
				result, errmsg = 1, nil -- connection was already established
			end
		end
	end
	return result, errmsg
end

function CoTCP:accept(...)
	-- accept any connection request pending in the socket
	local socket = self.__object
	local result, errmsg = socket:accept(...)
	
	-- check if the job has not yet been completed
	if result then
		result = wrapsocket(CoTCP, result)
	elseif errmsg == "timeout" then
		local event, deadline = setupevents(socket, nil, self)
		if event ~= nil then
			-- wait for a connection request signal
			awaitany(event, deadline)
			-- cancel emission of events
			cancelevents(socket, nil, deadline)
			-- accept any connection request pending in the socket
			result, errmsg = socket:accept(...)
			if result then result = wrapsocket(CoTCP, result) end
		end
	end
	return result, errmsg
end

function CoTCP:send(data, i, j)
	-- fill space already avaliable in the socket
	local socket = self.__object
	local result, errmsg, lastbyte = socket:send(data, i, j)

	-- check if the job has not yet been completed
	if not result and errmsg == "timeout" then
		local event, deadline = setupevents(socket, self, self)
		if event ~= nil then
			-- wait for more space on the socket or a timeout
			while awaitany(event, deadline) == event do
				-- fill any space free on the socket one last time
				result, errmsg, lastbyte = socket:send(data, lastbyte+1, j)
				if result or errmsg ~= "timeout" then
					break
				end
			end
			cancelevents(socket, self, deadline)
		end
	end
	
	return result, errmsg, lastbyte
end

function CoTCP:receive(pattern, ...)
	-- get data already avaliable in the socket
	local socket = self.__object
	local result, errmsg, partial = socket:receive(pattern, ...)
	
	-- check if the job has not yet been completed
	if not result and errmsg == "timeout" then
		local event, deadline = setupevents(socket, nil, self)
		if event ~= nil then
			-- initialize data read buffer with data already read
			local buffer = { partial }
			
			-- register socket for network event watch
			while awaitany(event, deadline) == event do -- otherwise it was a timeout
				-- reduce the number of required bytes
				if type(pattern) == "number" then
					pattern = pattern - #partial
				end
				-- read any data left on the socket one last time
				result, errmsg, partial = socket:receive(pattern)
				if result then
					buffer[#buffer+1] = result
					break
				else
					buffer[#buffer+1] = partial
					if errmsg ~= "timeout" then
						break
					end
				end
			end
		
			-- concat buffered data
			if result then
				result = concat(buffer)
			else
				partial = concat(buffer)
			end
		
			cancelevents(socket, nil, deadline)
		end
	end
	
	return result, errmsg, partial
end

local function getdatagram(opname, self, ...)
	-- get data already avaliable in the socket
	local socket = self.__object
	local result, errmsg, port = socket[opname](socket, ...)
	-- check if the job has not yet been completed
	if not result and errmsg == "timeout" then
		local event, deadline = setupevents(socket, nil, self)
		if event ~= nil then
			if awaitany(event, deadline) == event then
				result, errmsg, port = socket[opname](socket, ...)
			end
			cancelevents(socket, nil, deadline)
		end
	end
	
	return result, errmsg, port
end

local CoUDP = newclass()

for _, opname in ipairs{ "receive", "receivefrom", "receivefromgen" } do
	CoUDP[opname] = function (...)
		return getdatagram(opname, ...)
	end
end

--------------------------------------------------------------------------------
-- Wrapped Lua Socket API ------------------------------------------------------
--------------------------------------------------------------------------------

local module = copy(socketcore)

function module.tcp()
	return wrapsocket(CoTCP, createtcp())
end

function module.udp()
	return wrapsocket(CoUDP, createudp())
end

if createnetlink ~= nil then
	function module.netlink(...)
		return wrapsocket(CoUDP, createnetlink(...))
	end
end

local hasusock, socketunix = pcall(require, "socket.unix")
if hasusock then
	local createustrm = socketunix.stream
	local createudgrm = socketunix.dgram

	function module.stream()
		return wrapsocket(CoTCP, createustrm())
	end

	function module.dgram()
		return wrapsocket(CoUDP, createudgrm())
	end
end

function module.select(recvt, sendt, timeout)
	-- collect sockets so we don't rely on provided tables be left unchanged
	local wrapof = {}
	local recv, send
	if recvt and #recvt > 0 then
		recv = {}
		for index, wrap in ipairs(recvt) do
			local socket = wrap.__object
			wrapof[socket] = wrap
			recv[index] = socket
		end
	end
	if sendt and #sendt > 0 then
		send = {}
		for index, wrap in ipairs(sendt) do
			local socket = wrap.__object
			wrapof[socket] = wrap
			send[index] = socket
		end
	end
	
	-- if no socket is given then return
	if recv == nil and send == nil then
		return wrapof, wrapof, "timeout"
	end
	
	-- collect any ready socket
	local readok, writeok, errmsg = selectsockets(recv, send, 0)
	
	-- check if job has completed
	if
		timeout ~= 0 and
		errmsg == "timeout" and
		next(readok) == nil and
		next(writeok) == nil
	then
		-- setup events to wait
		local events = {}
		local deadline
		if timeout ~= nil and timeout > 0 then
			deadline = gettime() + timeout
			setuptimer(deadline)
			events[#events+1] = deadline
		end
		if recv ~= nil then
			for _, socket in ipairs(recv) do
				events[#events+1] = watchsocket(socket)
			end
		end
		if send ~= nil then
			for _, socket in ipairs(send) do
				events[#events+1] = watchsocket(socket, wrapof[socket])
			end
		end
		-- block until some socket event is signal or timeout
		if awaitany(unpack(events)) ~= deadline then
			if deadline ~= nil then canceltimer(deadline) end
			-- collect all ready sockets
			readok, writeok, errmsg = selectsockets(recv, send, 0)
		end
		-- unregister events to wait
		if recv ~= nil then
			for _, socket in ipairs(recv) do
				forgetsocket(socket)
			end
		end
		if send ~= nil then
			for _, socket in ipairs(send) do
				forgetsocket(socket, wrapof[socket])
			end
		end
	end
	
	-- replace sockets for the corresponding cosocket wrap
	for index, socket in ipairs(readok) do
		local wrap = wrapof[socket]
		readok[index] = wrap
		readok[wrap] = true
		readok[socket] = nil
	end
	for index, socket in ipairs(writeok) do
		local wrap = wrapof[socket]
		writeok[index] = wrap
		writeok[wrap] = true
		writeok[socket] = nil
	end
	
	return readok, writeok, errmsg
end

function module.run(timeout)
	repeat
		local nextwake = waketimers(idle, timeout)
		if nextwake ~= nil then return nextwake end
		if not emitsockevents(timeout and max(0, timeout - gettime())) then
			break
		end
	until timeout ~= nil and timeout >= gettime()
end

return module
