--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2019 - 2019  -  Technicolor Delivery Technologies, SAS **
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
-- @module modules.command.ethswctl_command
--
local require = require

      -- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local cmd_assist = require("helper.command")

local cmd_name = "ethswctl"

local usage_msg = [[
       -c option to check the interface
       <interface> (string) the allowed interfaces
	           { wan }
        Example:
	   ethswctl -c wan
]]

local intfs = {
      ["wan"] = "-c",
}

-- Returns true when provided `args` are valid , false otherwise
local function verify_args(args)
  if not args then
    return false
  end
  local intf = args["interface"]
  -- Only actions defined in usage_msg are valid
  if not intfs[intf] then
    return false
  end
  return true
end

-- This function check if the given subaction is allowed for the given interface
local function fixup_action(args)
  local intf = args["interface"]
  if not args[intfs[intf]] then
    return nil
  else
    args[intfs[intf]] = intf
    args["interface"] = nil
  end
  return args
end

local function ethswctl_function(args)
  args = cmd_assist.rename_args(usage_msg, args)
  -- Verification of args
  if not verify_args(args) then
    return nil, "Invalid arguments"
  end
  -- Fixup actions and subactions of ethswctl
  args = fixup_action(args)
  if not args then
    return nil, "Invalid arguments"
  end
  local ok, errmsg = cmd_assist.launch_command(cmd_name, args)
  if not ok then
    print(errmsg)
  end
end

-- Table representation of the ethswctl command module
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = ethswctl_function,
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
