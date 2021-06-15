-- Copyright (c) 2018 Technicolor Delivery Technologies, SAS

---
-- Initializes the client, connects to controller and communicates to and fro whenever necessary.
---

local M = {}
local runtime = {}

local require, pcall, tostring = require, pcall, tostring

local uds = require("tch.socket.unix")
local os = require("os")
local process = require("tch.process")
local flags = uds.SOCK_CLOEXEC
local agent_ipc_handler = require("vendorextensions.agent_ipc_handler")
local sk
local usock

local CONTROLLER_ABS_PATH = "map_mgmt_ipc"

local events_to_be_registered = {
  ["2"] = "0",
  ["3"] = "0",
  ["4"] = "0",
  ["5"] = "0",
  ["6"] = "0",
  ["7"] = "0x0424F128",
  ["8"] = "0",
  ["9"] = "0",
  ["11"] = "0"
}

--- Send message to controller
-- @tparam #number tag The tag to be sent
function M.send_msg(tag, ...)
  runtime.msg_instance:init_encode(tag, runtime.max_seqpacket_size)
  runtime.msg_instance:encode(...)
  local ok, errmsg = sk:send(runtime.msg_instance:retrieve_data())
  if not ok then
    runtime.log:critical("Send failed: Dropping packet due to %s", errmsg)
  else
    runtime.log:info("%s message sent to Controller", tag)
  end
end

local function handle_unknown()
  return nil, "Received unknown message"
end

-- all supported messages and their handling function
local handlers = {
  [2] = agent_ipc_handler.handleAgentOnboardData,
  [3] = agent_ipc_handler.handleAgentOffboardData,
  [4] = agent_ipc_handler.handleAgentUpdateData,
  [5] = agent_ipc_handler.handleStationConnectData,
  [6] = agent_ipc_handler.handleStationDisconnectData,
  [7] = agent_ipc_handler.handleReceived1905Data,
  [8] = agent_ipc_handler.handleStationMetrics,
  [9] = agent_ipc_handler.handleAPMetrics,
  [11] = agent_ipc_handler.handleMulticastStatus,
  __index = function()
    return handle_unknown
  end
}
setmetatable(handlers, handlers)

local function open_connect_socket()
  local sk_connected = false
  for _ = 1, 20 do
    sk = uds.seqpacket()
    local ok, err = sk:connect(CONTROLLER_ABS_PATH)
    if not ok then
      runtime.log:critical("Cannot connect to controller. Retrying due to %s", err)
      sk:close()
      sk = nil
      process.execute("sleep", {3})
    else
      sk_connected = true
      break
    end
  end
  if not sk_connected then
    return nil, "Exiting vendorextension since controller is not able to accept connections"
  end
  runtime.log:info("Connected to controller successfully")
  return true
end

local function read_cb()
  runtime.log:info("Read call back triggered")
  local data = sk:recv()
  if not data then
    runtime.log:error("Received failed")
    return nil, "Receive failed"
  elseif #data == 0 then
    runtime.log:error("***************************************Server socket disconnected***************************************")
    runtime.log:error("Terminating from VE as socket connection got closed")
    runtime.uloop.cancel()
    return nil, "Exiting VE as server socket disconnected"
  end

  local tag = runtime.msg_instance:init_decode(data)
  runtime.log:info("Decoded tag is %d", tag)
  local decodedData = runtime.msg_instance:decode()
  local ok, err = handlers[tag](decodedData)
  if not ok then
    runtime.log:error("Handling decoded data failed as %s", err)
    return nil, "Handling decoded data failed"
  end
  return true
end

local function sk_callback()
  -- To make sure VE doesn't exit if there is any error while decoding the message, we have added a safety call.
  -- VE will continue to run, even if the message sent from controller is improper.
  local rc, err = pcall(read_cb)
  if not rc then
    runtime.log:error("Error while retrieving data %s, %s", err, debug.traceback())
  end
end

local function set_controller_power_on_time()
  local cursor = runtime.uci.cursor(nil, "/var/state")
  local date = os.date("%Y-%m-%d %H:%M:%S", os.time())
  cursor:revert("multiap", "controller", "poweron_time")
  cursor:set("multiap", "controller", "poweron_time", date)
  cursor:save("multiap")
  runtime.ubus:send("mapVendorExtensions.controller", { Action = "powerOnTimeUpdated" })
end

local function main()
  local ok, err_msg = open_connect_socket(flags)
  if not ok then
    error(err_msg)
  end
  M.send_msg("EVENT_REGISTRATION", events_to_be_registered)
  set_controller_power_on_time()
  -- save the return value of fd_add. If it gets garbage collected the socket
  -- is removed from uloop
  usock = runtime.uloop.fd_add(sk:fd(), sk_callback, runtime.uloop.ULOOP_READ)
end

--- Remove socket from uloop and close the socket
function M.usock_delete()
  -- when done, remove the socket from uloop and close the socket
  runtime.log:info("Clean up socket")
  if usock then
    runtime.log:info("usock delete")
    usock:delete()
  end
  if sk then
    runtime.log:info("socket close")
    sk:close()
    sk = nil
  end
end

--- Initializes the client socket
-- @tparam #table rt Runtime table containing ubus and action handlers
function M.init(rt)
  runtime = rt
  local rc, err = pcall(main)
  if not rc then
    if sk then
      sk:close()
      sk = nil
    end
    local errmsg = tostring(err)
    runtime.log:critical("Critical error occurred: err=%s", errmsg or "<no error msg>")
    return
  end
  return true
end

return M
