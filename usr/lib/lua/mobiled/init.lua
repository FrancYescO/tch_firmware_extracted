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

local runtime = {
	uloop = require('uloop'),
	events = require('mobiled.events'),
	informer = require('mobiled.informer'),
	mobiled = require('mobiled.mobiled'),
	config = require('mobiled.config'),
	log = require('tch.logger')
}

local helper = require("mobiled.scripthelpers")

local M = {}

function M.start()
	helper.seed_random()

	runtime.config.init(runtime)
	local config = runtime.config.get_raw_config()
	if not config.globals or not config.globals.initmode then
		return nil, "Initial state missing from config"
	end

	-- Setup the log facilities
	runtime.log.init("mobiled", tonumber(config.globals.tracelevel))

	local threshold = tonumber(config.globals.gc_threshold) or 130
	runtime.log:debug("Setting garbage collection threshold to %d", threshold)
	collectgarbage("setpause", threshold)

	-- Initialize uloop
	runtime.uloop.init()

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
	runtime.mobiled.cleanup()
	runtime.log:info("Exit")
end

return M
