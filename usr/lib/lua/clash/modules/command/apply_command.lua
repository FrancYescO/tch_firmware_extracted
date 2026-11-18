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
-- A module that implements the apply command.
--
-- @module modules.command.apply_command
--
local require = require

-- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local proxy = require("helper.transformer")

--- Calls the apply function of Transformer
-- @return nil If everything went ok
local function apply_function()
  local result, errmsg = proxy.apply()
  if not result then
    print("ERROR: %s",errmsg)
  else
    print("Apply command sent")
  end
end

local usage_msg = [[
  Apply previous changes done via the data model. Calling this command will perform the
  necessary start/stop/restart/reload/... actions on the daemons that were impacted by the data model changes.
]]

-- Table representation of the apply command module
local command = {
  name = "apply",
  usage_msg = usage_msg,
  action = apply_function, -- Function to be called when apply command executes.
}

local M = {}

M.name = command.name

M.clash_datamodel_not_required = true

--- Function to initialize the del command module.
-- This will register the del command module with the CLI core.
M.init = function()
  register(command)
end

--- Function to destroy the del command module.
-- This will unregister the del command module from the CLI core.
M.destroy = function()
  unregister(command)
end

return M
