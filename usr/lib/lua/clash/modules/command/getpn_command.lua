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
-- A module that implements the getpn command.
--
-- @module modules.command.getpn_command
--
local ipairs, require = ipairs, require

-- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local proxy = require("helper.transformer")

--- Calls the getpn function of Transformer
-- @tparam table args A table representation of the arguments the user entered. This should at least have a 'path' field.
-- @return nil If everything went ok
-- @error Missing path
local function getpn_function(args)
  if not args.path then
    -- Path is missing
    return nil, "Missing path"
  end
  local nextLevel
  if (args.nextLevel == "true" or args.nextLevel == "1" or args.nextLevel == "y") then
    nextLevel = true
  elseif (args.nextLevel == "false" or args.nextLevel == "0" or args.nextLevel == "n") then
    nextLevel = false
  else
    print("ERROR: nextLevel should be boolean (false|true)")
    return
  end
  -- use getpn functionality of the transformer to display results
  local results, errmsg = proxy.getPN(args.path, nextLevel)
  -- error handling for getpn failure
  if not results then
    print("ERROR: %s",errmsg)
  else
    for _, param in ipairs(results) do
        local writable
        if param.writable then
            writable = "[w] "
        else
            writable = "[ ] "
        end
        print(writable..param.path..param.name)
    end
  end
end

local usage_msg = [[
  Retrieve available parameters in the data model.
    <path> (datamodel_path) The data model path for which to retrieve the parameters
    <nextLevel> (bool default false)
                If false, the response contains the parameter or object whose name exactly
                          matches the path argument, plus all parameters and objects that are
                          descendents of the object given by the path argument, if any.
                If true, the response contains all parameters and objects that are next-level
                         children of the object given by the path argument, if any.
]]

-- Table representation of the getpn command module
local command = {
  name = "getpn",
  alias = "GetParameterNames,gpn,GPN", -- Comma-separated list.
  usage_msg = usage_msg,
  action = getpn_function, -- Function to be called when getpn command executes.
}

local M = {}

M.name = command.name

--- Function to initialize the getpn command module.
-- This will register the getpn command module with the CLI core.
M.init = function()
  register(command)
end

--- Function to destroy the getpn command module.
-- This will unregister the getpn command module from the CLI core.
M.destroy = function()
  unregister(command)
end

return M
