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
-- @module modules.command.top_command
--
local require = require

      -- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local cmd_assist = require("helper.command")

local cmd_name = "top"
local usage_msg = [[
  Display Linux tasks
]]

local function top_function(args)
  args = cmd_assist.rename_args(usage_msg, args)

  -- Output only one iteration
  args["-n"] = "1"
  -- In batch mode to avoid top clearing terminal; argument value '1' is a dummy
  args["-b"] = "1"

  local ok, errmsg = cmd_assist.launch_command(cmd_name, args)
  if not ok then
    print(errmsg)
  end
end

-- Table representation of the top command module
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = top_function,
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
