--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2017 - 2017  -  Technicolor Delivery Technologies, SAS **
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

--
-- @module modules.command.unlock_command
--
local require = require

-- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local cmd_assist = require("helper.command")

local cmd_name = "unlock"
local usage_msg = [[
  command to unlock the GW with either a permanent or temporal tag
  -p,--permanent option to unlock the GW with a permanent tag
  -t,--temporary option to unlock the GW with a temporal tag
  <tag> (string) unlock tag to unlock the Gateway
]]

local function unlock_function(args)
  -- If both the options are set, throw an error
  if args["temporary"] and args["permanent"] then
    print("Both options cannot be used at the same time")
    return
  end
  -- If no option is specified, use -t as the default tag
  if not args["temporary"] and not args["permanent"] then
    args["temporary"] = true
  end

  args = cmd_assist.rename_args(usage_msg, args)
  local ok, errmsg = cmd_assist.launch_command(cmd_name, args)
  if not ok then
    print(errmsg)
  end
end

-- Table representation of the unlock command module
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = unlock_function,
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
