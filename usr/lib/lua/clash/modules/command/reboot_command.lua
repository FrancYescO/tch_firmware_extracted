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
-- @module modules.command.reboot_command
--
local require = require

      -- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local cmd_assist = require("helper.command")
local proxy = require("helper.transformer")

local cmd_name = "reboot"
local usage_msg = [[
  Reboot the gateway
]]

local function reboot_function(args)
  -- Reboot via transformer with reason `CLI`
  local ok = proxy.set({ ["rpc.system.reboot"] = "CLI" })
  if not ok then
    print("Could not trigger reboot")
  else
    proxy.apply()
    print("Rebooting...")
  end
end

-- Table representation of the reboot command module
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = reboot_function,
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
