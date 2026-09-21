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
-- @module modules.command.rtfd_command
--
local require = require

      -- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local proxy = require("helper.transformer")

local cmd_name = "rtfd"
local usage_msg = [[
  Perform return-to-factory-defaults of gateway
]]

local function rtfd_function()
  -- Reset to factory defaults via transformer
  local ok = proxy.set({ ["rpc.system.reset"] = "1" })
  if not ok then
    print("Could not trigger RTFD")
  else
    print("Rebooting...")
    proxy.apply()
  end
end

-- Table representation of the rtfd command module
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = rtfd_function,
}

local M = {}

M.name = command.name

M.clash_datamodel_not_required = true

M.init = function()
  register(command)
end

M.destroy = function()
  unregister(command)
end

return M
