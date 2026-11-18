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
-- @module modules.command.iptables_command
--
local require = require

      -- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local cmd_assist = require("helper.command")

local cmd_name = "iptables"
local usage_msg = [[
  List iptables rules
    -L (optional iptables_chain) List the rules in a chain;
        to list all chains from a table:
           `iptables -L all`
        to list all rules  from a chain, e.g. `INPUT`:
           `iptables -L INPUT`
           `iptables -t nat -L INPUT`
    -Z (optional iptables_chain) Zero the packet and byte counters in a chain;
	to zero all chains from a table:
           `iptables -Z all`
        to zero all rules  from a chain, e.g. `INPUT`:
           `iptables -Z INPUT`
           `iptables -t nat -Z INPUT`
    -n  Numeric output of addresses and ports
    -t (optional string) Table to list (default: `filter`)
    -v  Verbose mode
]]

local function iptables_function(args)
  args = cmd_assist.rename_args(usage_msg, args)
  -- Possibility to further rename args here
  local ok, errmsg = cmd_assist.launch_command(cmd_name, args)
  if not ok then
    print(errmsg)
  end
end

-- Table representation of the iptables command module
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = iptables_function,
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
