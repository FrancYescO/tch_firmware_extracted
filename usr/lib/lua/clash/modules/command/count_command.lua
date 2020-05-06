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
-- A module that implements the count command.
--
-- @module modules.command.count_command
--
local require = require

-- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local proxy = require("helper.transformer")

--- Calls the count function of Transformer
-- @tparam table args A table representation of the arguments the user entered. This should at least have a 'path' field.
-- @return nil If everything went ok
-- @error Missing path
local function count_function(args)
  if not args.path then
    -- Path is missing
    return nil, "Missing path"
  end
  -- use count functionality of the transformer to display results
  local count, errmsg = proxy.getPC(args.path)
  -- error handling for count failure
  if not count then
    print("ERROR: %s",errmsg)
  else
    print("Number of parameters: %d", count)
  end
end

local usage_msg = [[
  count the number of parameters
    <path> (datamodel_path) The data model path for which to count the number of parameters
]]

-- Table representation of the count command module
local command = {
  name = "count",  
  usage_msg = usage_msg,
  action = count_function, -- Function to be called when count command executes.
}

local M = {}

M.name = command.name

--- Function to initialize the count command module.
-- This will register the count command module with the CLI core.
M.init = function()
  register(command)
end

--- Function to destroy the count command module.
-- This will unregister the count command module from the CLI core.
M.destroy = function()
  unregister(command)
end

return M
