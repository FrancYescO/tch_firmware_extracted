---------------------------------
--! \mainpage Mobile Daemon
--!
--! \section intro_sec Introduction
--!
--! Mobiled is a daemon capable of managing any type of LTE interface.
--! It has support for AT and QMI dongles as well as a number of other proprietarty
--! interfaces through a plugin mechanism.
---------------------------------

---------------------------------
--! @file
--! @brief The entry point of the Mobiled module
---------------------------------

local require, tonumber = require, tonumber

local runtime = {}
runtime.uloop = require('uloop')
runtime.events = require('mobiled.events')
runtime.informer = require('mobiled.informer')
runtime.mobiled = require('mobiled.mobiled')
runtime.config = require('mobiled.config')

local ubus = require('ubus')
local logger = require('transformer.logger')

local M = {}

function M.start()
	runtime.config.init(runtime)
	local config = runtime.config.get_raw_config()
	if not config.globals or not config.globals.initmode then
	   return nil, "Initial state missing from config"
	end

	-- Setup the log facilities
	logger.init()
	runtime.log = logger.new("mobiled", tonumber(config.globals.tracelevel))

	-- Initialize uloop
	runtime.uloop.init()

	-- Make the connection with UBUS
	runtime.ubus = ubus.connect()
	if not runtime.ubus then
		return nil, "Failed to connect to UBUS"
	end

	runtime.events.init(runtime.mobiled.handle_event, runtime)
	runtime.informer.init(runtime)
	local ret, errMsg = runtime.mobiled.init(runtime)
	if not ret then
		return nil, errMsg
	end

	-- Create a new statemachine
	runtime.mobiled.start_new_statemachine()

	runtime.events.start()
	runtime.informer.start()
	runtime.uloop.run()
end

return M
