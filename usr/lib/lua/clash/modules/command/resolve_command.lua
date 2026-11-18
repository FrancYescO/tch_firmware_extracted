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
-- A module that implements the resolve command.
--
-- @module modules.command.resolve_command
--
local require = require

-- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local proxy = require("helper.transformer")

--- Calls the resolve function of Transformer
-- @tparam table args A table representation of the arguments the user entered. This should at least have a 'path' and 'key' fields.
-- @return nil If everything went ok
-- @error Missing path or key
local function resolve_function(args)
  if not args.path then
    -- Path is missing
    return nil, "Missing path"
  end
  if not args.key then
    -- Key is missing
    return nil, "Missing key"
  end

  local result, errmsg = proxy.resolve(args.path, args.key)
  -- error handling for resolve failure
  if not result then
    print("ERROR: %s",errmsg)
  else
    print("%s", result)
  end
end

local usage_msg = [[
  Resolve an objecttype path and a key to the corresponding data model path.
    <path> (string) The objecttype path
    <key> (string) The key
]]

-- Table representation of the resolve command module
local command = {
  name = "resolve",
  usage_msg = usage_msg,
  action = resolve_function, -- Function to be called when resolve command executes.
}

local M = {}

M.name = command.name

M.clash_datamodel_not_required = true

--- Function to initialize the resolve command module.
-- This will register the resolve command module with the CLI core.
M.init = function()
  register(command)
end

--- Function to destroy the resolve command module.
-- This will unregister the resolve command module from the CLI core.
M.destroy = function()
  unregister(command)
end

return M
