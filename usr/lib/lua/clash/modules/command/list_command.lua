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
-- A module that implements the list command.
--
-- @module modules.command.list_command
--
local ipairs, require, next = ipairs, require, next

-- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local proxy = require("helper.transformer")

--- Calls the list function of Transformer
-- @tparam table args A table representation of the arguments the user entered. This should at least have a 'path' field.
-- @return nil If everything went ok
-- @error Missing path
local function list_function(args)
  if not args.path then
    -- Path is missing
    return nil, "Missing path"
  end

  -- use list functionality of the transformer to display results
  local results, errmsg = proxy.getPL(args.path)
  -- error handling for list failure
  if not results then
    print("ERROR: %s", errmsg)
  elseif next(results) == nil then
    print("path doesn't contain any parameters")
  else
    for _, param in ipairs(results) do
      print("%s%s", param.path, param.param)
    end
  end
end

local usage_msg = [[
  Retrieve parameter list
    <path> (datamodel_path) The datamodel path for which to retrieve the parameters
]]

-- Table representation of the list command module
local command = {
  name = "list",
  usage_msg = usage_msg,
  action = list_function, -- Function to be called when list command executes.
}

local M = {}

M.name = command.name

--- Function to initialize the list command module.
-- This will register the list command module with the CLI core.
M.init = function()
  register(command)
end

--- Function to destroy the list command module.
-- This will unregister the list command module from the CLI core.
M.destroy = function()
  unregister(command)
end

return M
