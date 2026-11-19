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
-- A module that implements the del command.
--
-- @module modules.command.del_command
--
local require = require

-- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local proxy = require("helper.transformer")

--- Calls the del function of Transformer
-- @tparam table args A table representation of the arguments the user entered. This should at least have a 'path' field.
-- @return nil If everything went ok
-- @error Missing path
local function del_function(args)
  if not args.path then
    -- Path is missing
    return nil, "Missing path"
  end
  local result, errmsg = proxy.del(args.path)
  -- error handling for delete failure
  if not result then
    print("ERROR: %s",errmsg)
  else
    print("Deleted %s", args.path)
  end
end

local usage_msg = [[
  Delete an object from the data model.
    <path> (datamodel_path) The path to the data model object which needs to be deleted.
]]

-- Table representation of the del command module
local command = {
  name = "del",
  alias = "delete,DeleteObject", -- Comma-separated list.
  usage_msg = usage_msg,
  action = del_function, -- Function to be called when del command executes.
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
