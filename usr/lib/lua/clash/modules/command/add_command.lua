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
-- A module that implements the add command.
--
-- @module modules.command.add_command
--
local require = require

-- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local proxy = require("helper.transformer")

--- Calls the add function of Transformer
-- @tparam table args A table representation of the arguments the user entered. This should at least have a 'path' field.
-- @return nil If everything went ok
-- @error Missing path
local function add_function(args)
  if not args.path then
    -- Path is missing
    return nil, "Missing path"
  end
  -- use add functionality of the transformer to display results
  local result, errmsg = proxy.add(args.path, args.name)
  -- error handling for add failure
  if not result then
    print("ERROR: %s",errmsg)
  else
    print("Created %s%s", args.path, result)
  end
end

local usage_msg = [[
  Add a new object to the datamodel.
    <path> (datamodel_path) The datamodel path to which an object needs to be added
    <name> (optional string) The name of the new object.
]]

-- Table representation of the add command module
local command = {
  name = "add",
  alias = "AddObject", -- Comma-separated list.
  usage_msg = usage_msg,
  action = add_function, -- Function to be called when add command executes.
}

local M = {}

M.name = command.name

--- Function to initialize the add command module.
-- This will register the add command module with the CLI core.
M.init = function()
  register(command)
end

--- Function to destroy the add command module.
-- This will unregister the add command module from the CLI core.
M.destroy = function()
  unregister(command)
end

return M
