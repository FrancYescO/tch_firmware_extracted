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

    -- Make the connection with ubus
    runtime.ubus = ubus.connect()

    runtime.events.init(runtime.mobiled.handle_event, runtime)
    runtime.informer.init(runtime)
    runtime.mobiled.init(runtime)

    -- Create a new statemachine
    runtime.mobiled.start_new_statemachine()

    runtime.events.start()
    runtime.informer.start()
    runtime.uloop.run()
end

return M
