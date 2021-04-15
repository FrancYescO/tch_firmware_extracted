--
-- This file is Confidential Information of Cujo LLC.
-- Copyright (c) 2019 CUJO LLC. All rights reserved.
--
local mnl = require'cujo.mnl'
local event = require "coutil.event"
local socketevent = require'coutil.socket.event'
local socketcore = require "socket.core"

local Wrapper = oo.class()

function Wrapper:readall(...)
	self.__object:trigger(...)
	event.await(self.__object)
end

function Wrapper:close()
	-- Don't actually close the mnl socket (self.__object) here, the GC will
	-- do that eventually. If we do it here then the GC will trigger an
	-- error because double-closing is not supported.
	event.emitall(self.__socket, true)
end

local luamnl = {}

function luamnl.create(t)
	local object = mnl.new(t.bus, t.bylines, t.groups)

	local socket = socketcore.tcp()
	socket:close()
	socket:setfd(object:getfd())
	socket:settimeout(0)

	cujo.jobs.spawn("mnl-reader", function ()
		while true do
			socketevent.create(socket)
			local die = event.await(socket)
			socketevent.cancel(socket)
			if die then
				cujo.log:traffic('mnl socket wrapper closed, stopping reader')
				break
			end
			local bybatch = t.bybatch or function() end
			while object:process() do
				bybatch()
			end
			event.emitall(object)
		end
	end)

	return Wrapper{__object = object, __socket = socket}
end

return luamnl
