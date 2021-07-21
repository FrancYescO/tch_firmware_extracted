local _G = require "_G"
local setmetatable = _G.setmetatable
local tostring = _G.tostring
local type = _G.type

local math = require "math"
local inf = math.huge
local min = math.min

local table = require "loop.table"
local copy = table.copy
local memoize = table.memoize

local socketcore = require "socket.core"
local gettime = socketcore.gettime

local event = require "coutil.event"
local emitevent = event.emitall

local sockevt = require "coutil.socket.event"
local watchsocket = sockevt.create
local forgetsocket = sockevt.cancel

local timevt = require "coutil.time.event"
local setuptimer = timevt.create
local canceltimer = timevt.cancel

local module = {}

do
	local CoSock = {}

	function CoSock:setdeadline(timestamp)
		local old = self.deadline
		self.deadline = timestamp
		return true, old
	end

	function CoSock:settimeout(timeout)
		local oldtm = self.timeout
		if not timeout or timeout < 0 then
			self.timeout = nil
		else
			self.timeout = timeout
		end
		return 1, oldtm
	end

	function CoSock:close()
		local socket = self.__object
		local result, errmsg = socket:close()
		emitevent(socket) -- wake threads reading the socket
		emitevent(self) -- wake threads writing the socket
		return result, errmsg
	end

	function module.newclass()
		return copy(CoSock)
	end
end

do
	local methodwrap = memoize(function(method)
		return function(self, ...)
			return method(self.__object, ...)
		end
	end, "k")

	local socketwrap = {
		__index = function(self, key)
			local value = self.__object[key]
			if type(value) == "function"
				then return methodwrap[value]
				else return value
			end
		end,
		__tostring = function (self)
			return tostring(self.__object)
		end,
	}

	function module.wrapsocket(ops, socket, ...)
		if type(socket) == "userdata" then
			socket:settimeout(0)
			socket = setmetatable(copy(ops, { __object = socket }), socketwrap)
		end
		return socket, ...
	end
end

function module.setupevents(socket, write, self)
	local deadline = self.deadline
	local timeout = self.timeout
	if timeout ~= nil then
		deadline = min(gettime() + timeout, deadline or inf)
	end
	if deadline == nil or deadline > gettime() then
		if deadline ~= nil then
			setuptimer(deadline)
		end
		return watchsocket(socket, write), deadline -- return events
	end
end

function module.cancelevents(socket, write, deadline)
	if deadline ~= nil then
		canceltimer(deadline)
	end
	forgetsocket(socket, write)
end

return module
