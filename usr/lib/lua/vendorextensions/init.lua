-- Copyright (c) 2018 Technicolor Delivery Technologies, SAS

---------------------------------
-- Initializes the Vendorextension daemon, vendor extension module is for communicating with the MAP Controller and its connected agents.
---------------------------------

---------------------------------
--! @file
--! @brief The entry point of vendorextensions module
---------------------------------

local require = require

local runtime = {}
runtime.uloop = require('uloop')
runtime.uci = require('uci')
runtime.config = require('vendorextensions.uciconfig')
runtime.ubus_handler = require('vendorextensions.ubusPlugin')
runtime.client = require('vendorextensions.client_main')
runtime.eventWatcher = require('vendorextensions.eventWatcher')
runtime.action_handler = require('vendorextensions.actionHandler')
runtime.cron_handler = require('vendorextensions.cron_handler')
runtime.msg = require('vendorextensions.msg')
runtime.msg_instance = runtime.msg.new()

runtime.CONTROLLER_ABS_PATH = "map_mgmt_ipc"
runtime.BROADCAST_MAC = "0180C2000013"
runtime.OUI_ID = "24F128"

local uds = require("tch.socket.unix")
runtime.max_seqpacket_size = runtime.msg_instance.softLimit(uds.MAX_DGRAM_SIZE)
runtime.agent_ipc_handler = require('vendorextensions.agent_ipc_handler')
local logger = require('tch.logger')
local M = {}

--- Starts vendorextension daemon by initializing all scripts
function M.start()
  runtime.uloop.init()

  -- loads the multiap controller config
  runtime.config.init(runtime)

  -- initialize logger and ubus
  logger.init("Multiap_vendorextensions", runtime.config.getTraceLevel())
  runtime.log = logger.new("vendorextensions")

  local ret, err = runtime.ubus_handler.init(runtime)
  if not ret then
    runtime.log:critical("Exiting vendor extension: Failed to initialize Ubus. Error: %s", err)
    return
  end

  -- initializes message module, socket IPC and action handler
  runtime.msg.init(runtime)
  local ok = runtime.client.init(runtime)
  if not ok then
    runtime.log:critical("Exiting vendor extension: Failed to initialize Socket IPC.")
    return
  end
  runtime.action_handler.init(runtime)
  runtime.agent_ipc_handler.init(runtime)
  runtime.cron_handler.init(runtime)
  runtime.eventWatcher.init(runtime)

  runtime.uloop.run()
  runtime.log:info("Exiting vendor extension daemon")
  runtime.client.usock_delete()
  runtime.cron_handler.remove_cron_jobs()
  runtime.ubus:close()
  runtime.uloop.cancel()
  return true
end

return M
