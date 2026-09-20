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
-- @module modules.command.mptcpkpi_command
--
local require = require

-- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local cmd_assist = require("helper.command")
local cmd_name = "mptcpkpi"
local usage_msg = [[
This command retrieves KPI information for the MPTCP connections.
  session count: number of MPTCP sessions currently established or closed.
  additional subflow count: total number of additional subflows.
  session with additional subflow: the number of MPTCP connections that have more than one subflow.
]]

-- Implementation of the function mptcpkpi command.
local function mptcpkpi_function()
  local ok, errmsg = cmd_assist.launch_command(cmd_name, {})
  if not ok then
    print(errmsg)
  end
end

-- Table representation of the mptcpkpi command module
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = mptcpkpi_function,
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
