--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2015 - 2016  -  Technicolor Delivery Technologies, SAS **
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
-- A module that implements the set command.
--
-- @module modules.command.set_command
--

local ipairs, require = ipairs, require

-- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local proxy = require("helper.transformer")


--- Calls the set function of Transformer.
-- @tparam table args A table representation of the arguments the user entered. This should at least have a 'path' and 'value' fields.
-- @return nil If everything went ok
-- @error Missing path
-- @error Missing value
local function do_set(args)
  if not args.path then
    return nil, "Missing path"
  end
  if not args.value then
    return nil, "Missing value"
  end
  -- Calls the set functionality of the transformer
  local result, errors = proxy.set(args.path, args.value)
  -- error handling for set failure
  if not result then
    for _, err in ipairs(errors) do
      -- Show the error message to the user
      print("%s: %d fault [%s]", err.path, err.errcode, err.errmsg)
    end
  end
end

local usage_msg = [[
  Change the value of a datamodel path.
    <path> (datamodel_path) The datamodel path to change
    <value> (string) The new value for the datamodel path
]]

-- Table representation of the set command module
local command = {
  name = "set",
  alias = "SetParameterValues,spv,SPV", -- Comma-separated list.
  usage_msg = usage_msg,
  action = do_set, -- Function to be called when set command executes.
}

local M = {}

M.name = command.name

--- Function to initialize the set command module.
-- This will register the set command module with the CLI core.
M.init = function()
  register(command)
end

--- Function to destroy the set command module.
-- This will unregister the set command module from the CLI core.
M.destroy = function()
  unregister(command)
end

return M
