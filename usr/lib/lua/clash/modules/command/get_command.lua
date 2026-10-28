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
-- A module that implements the get command.
--
-- @module modules.command.get_command
--
local ipairs, require = ipairs, require

-- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local format = string.format

local proxy = require("helper.transformer")
local cf = require("helper.filter")

--- Calls the get function of Transformer
-- @tparam table args A table representation of the arguments the user entered. This should at least have a 'path' field.
-- @return nil If everything went ok
-- @error Missing path
local function get_function(args)
  if not args.path then
    -- Path is missing
    return nil, "Missing path"
  end
  -- use get functionality of the transformer to display results
  local results, errmsg = proxy.get(args.path, args.abort)
  -- error handling for get failure
  if not results then
    print("ERROR: %s",errmsg)
  else
    local fmt = "%s%s [%s] = %s"
    for _, param in ipairs(results) do
      if not args.filter or cf( format(fmt, param.path, param.param, param.type, param.value) , args.filter, args.i) then
        print(fmt, param.path, param.param, param.type, param.value)
      end
    end
    if errmsg then
      fmt = "ERROR: %s = %s"
      for _, param in ipairs(errmsg) do
        local path = param.param ~= "" and param.path .. param.param or param.path
        if not args.filter or cf( format(fmt, path,  param.errmsg) , args.filter, args.i) then
          print(fmt, path,  param.errmsg)
        end
      end
    end
  end
end

local usage_msg = [[
  Retrieve a value from the data model.
    <path...>   (datamodel_path) The data model path to retrieve
    -a,--abort   Abort the operation on any error.
    -i        When filter is active, match case-insensitive
    --filter (optional string) A Lua pattern filter;
              only lines that match the filter are printed.
]]

-- Table representation of the get command module
local command = {
  name = "get",
  alias = "GetParameterValues,gpv,GPV", -- Comma-separated list.
  usage_msg = usage_msg,
  action = get_function, -- Function to be called when get command executes.
}

local M = {}

M.name = command.name

M.clash_datamodel_not_required = true

--- Function to initialize the get command module.
-- This will register the get command module with the CLI core.
M.init = function()
  register(command)
end

--- Function to destroy the get command module.
-- This will unregister the get command module from the CLI core.
M.destroy = function()
  unregister(command)
end

return M
