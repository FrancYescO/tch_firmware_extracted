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

local require = require

-- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local cmd_assist = require("helper.command")

local cmd_name = "ebtables"

local usage_msg = [[
  List ebtables rules
    -L (optional ebtables_chain) List the rules in a chain;
        to list all chains from a table:
           `ebtables -L all`
        to list all rules  from a chain, e.g. `INPUT`:
           `ebtables -L INPUT`
           `ebtables -t nat -L INPUT`
    -Z (optional ebtables_chain) Zero the packet and byte counters in a chain;
        to zero all chains from a table:
           `ebtables -Z all`
        to zero all rules  from a chain, e.g. `INPUT`:
           `ebtables -Z INPUT`
           `ebtables -t nat -Z INPUT`
    -t (optional string) Table to list (default: `filter`)
]]

local function ebtables_function(args)
  -- return nil if no args are given, otherwise all options available in ebtables will be listed
  if not next(args) then
    return nil, "Invalid arguments"
  end
  args = cmd_assist.rename_args(usage_msg, args)
  -- Possibility to further rename args here
  local ok, errmsg = cmd_assist.launch_command(cmd_name, args)
  if not ok then
    print(errmsg)
  end
end

-- Table representation of the ebtables command module
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = ebtables_function,
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

