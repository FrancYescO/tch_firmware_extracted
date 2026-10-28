--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2016 - 2016  -  Technicolor Delivery Technologies, SAS **
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
-- @module modules.command.xdslctl_command
--
local require = require
-- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister
local match = string.match
local gmatch = string.gmatch

local cmd_assist = require("helper.command")
local cmd_name = "xdslctl"
-- where define the other function
local usage_msg = [[
Gives informations and statistics of the DSL line
   <action>  (string) The allowed actions
                 { info | profile | version }
              The following option is allowed for 'profile' and 'info' actions:
                  --show   basic information of dsl line
              The following options are only allowed for the 'info' action:
                  --cfg    Display dsl driver bitmap setting
                  --state  DSL state info (Idle-Handshake-Training-Message Exchange-Showtime)
                  --stats  DSL statistics
                  --SNR    snr values (Signal-to-Noise ratio per carrier tone)
                  --QLN    information qln (Quiet Line Noise per carrier tone)
                  --Hlog   information hlog (DSL line Transfer function - logarithmic)
                  --Hlin   information hlin (DSL line Transfer function(frequency) - lineair)
                  --HlinS  information hlins (DSL line Transfer function(Laplace s) - lineair)
                  --Bits   Allocation of Bits/carrier for each of the carriers in a DMT symbol
                  --pbParams per bin parameters : sync info (SNR, ...) per carrier (tone)
                  --vendor when the DSL line is in sync, remote side vendor/chipset info
              The 'version' action retrieves PHY information and driver version
]]

local actions = {
  ["version"] = {},
  ["info"] = {
    ["--cfg"] = true,
    ["--show"] = true,
    ["--state"] = true,
    ["--stats"] = true,
    ["--SNR"] = true,
    ["--QLN"] = true,
    ["--Hlog"] = true,
    ["--Hlin"] = true,
    ["--HlinS"] = true,
    ["--Bits"] = true,
    ["--pbParams"] = true,
    ["--vendor"] = true,
  },
  ["profile"] = {
    ["--show"] = true,
  },
}

-- Returns true when provided `args` are valid for route, false otherwise
local function verify_args(args)
  if not args then
    return false
  end
  local action = args["action"]
  -- Only actions defined in usage_msg are valid
  if not actions[action] then
    print("Please provide an object listed in xdslctl help: %s", action)
    return false
  end
  return true
end
-- This function check if the given subaction is allowed for the given action
local function fixup_action(args)
  local action = args["action"]
  args["action"] = nil
  for subaction, set in pairs(args) do
    if set and not actions[action][subaction] then
      return false
    end
  end
  args[action] = true
  if args["version"] == true then
    args["--version"] = true
    args["version"] = nil
  end
  return args
end

local function xdslctl_function(args)
  args = cmd_assist.rename_args(usage_msg, args)
  -- Verification of args
  if not verify_args(args) then
    return nil, "invalid action"
  end
  -- Fixup actions and subactions of xdslctl
  args = fixup_action(args)
  if not args then
    return nil, "invalid"
  end
  local ok, errmsg = cmd_assist.launch_command(cmd_name, args)
  if not ok then
    print(errmsg)
  end
end
-- Table representation of the xDSLCTL command
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = xdslctl_function,
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