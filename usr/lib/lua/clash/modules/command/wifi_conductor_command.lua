--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2016 - 2018  -  Technicolor Delivery Technologies, SAS **
** - All Rights Reserved                                                **
** Technicolor hereby informs you that certain portions                 **
** of this software module and/or Work are owned by Technicolor         **
** and/or its software providers.                                       **
** Distribution copying and modification of all such work are reserved  **
** to Technicolor and/or its affiliates, and are not permitted without  **
** express written authorization from Technicolor.                      **
** Technicolor is registered trademark and trade name of Technicolor,   **
** and shall not be used in any manner without express written          **
** authorization from Technicolor                                       **
*************************************************************************/
--]]

---
-- @module modules.command.wifi_conductor_command
--
local require = require

-- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local cmd_assist = require("helper.command")

local cmd_name = "wifi_conductor"
local usage_msg = [[
  Execute conductor command.
  <command>  (string)           Conductor command.
  <mac_addr> (optional string)  Mac address.

  Available commands are:
    version         Display wifi-conductor version
    config          Dump wifi-conductor configuration
    dump_infra      Dump controller infra
    dump_state      Dump controller state
    dump_bsss       Dump controller bss list
    dump_stas       Dump controller station list
    dump_sta mac    Dump statistics of one station
    trace_sta mac   Trace station
    history         Dump controller history
    dump_db         Dump station database
    clear_db mac    Clear station from database
    clear_db_all    Clear all stations from database
    roamer_history  Dump roamer history
]]

--Valid commands without mac
local valid_cmd = {
  ["version"] = true,
  ["config"] = true,
  ["dump_infra"] = true,
  ["dump_state"] = true,
  ["dump_bsss"] = true,
  ["dump_stas"] = true,
  ["history"] = true,
  ["dump_db"] = true,
  ["clear_db_all"] = true,
  ["roamer_history"] = true
}

--Valid commands with mac
local valid_mac_cmd = {
  ["dump_sta"] = true,
  ["trace_sta"] = true,
  ["clear_db"] = true,
}

-- Returns true when provided `args` are valid
local function verify_args(args)
  if not args then
    return false
  end

  -- Check if command is valid 
  local command = args["command"]
  if not valid_cmd[command] and not valid_mac_cmd[command] then
    return false
  end

  -- Check if command needs mac
  local mac = args["mac_addr"]
  if valid_mac_cmd[command] and nil == mac then
    return false
  end

  return true
end

local function wifi_conductor_function(args)
  args = cmd_assist.rename_args(usage_msg, args)

  -- Verification of args
  if not verify_args(args) then
    return nil, "invalid command"
  end

  -- Possibility to further rename args here
  local ok, errmsg = cmd_assist.launch_command(cmd_name, args)
  if not ok then
    print(errmsg)
  end
end

-- Table representation of the wifi_conductor command module
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = wifi_conductor_function,
}

local M = {}

M.name = command.name

M.init = function()
  register(command)
end

M.destroy = function()
  unregister(command)
end

return M
