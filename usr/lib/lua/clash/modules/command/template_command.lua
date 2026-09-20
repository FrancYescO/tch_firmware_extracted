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
-- A module that implements the template command.
--
-- @module modules.command.template_command
--
local require, ipairs, pairs = require, ipairs, pairs

-- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local proxy = require("helper.transformer")

--- Calls the template function of Transformer
-- @tparam table args A table representation of the arguments the user entered. This should at least have a 'path' field.
-- @return nil If everything went ok
-- @error Missing path
local function template_function(args)
  if not args.path then
    -- Path is missing
    return nil, "Missing path"
  end

  local strict
  if args.strict and (args.strict == "true" or args.strict == "1" or args.strict == "y") then
    strict = true
  else
    strict = false
  end

  local result_paths = {}

  -- Perform a get parameter values of the given path.
  local paths = proxy.get(args.path)
  if not paths then
    print("You can not generate a testsuite template if the get doesn't even work.")
  end
  -- Rearrange the returned paths, so the result can more easily be merged with
  -- the result of get parameter names.
  for _, full_path in ipairs(paths) do
    result_paths[full_path.path..full_path.param] = {type = full_path.type, value = full_path.value}
  end
  -- Perform a get parameter names of the path. We want all children, so pass level false.
  local gpns = proxy.getPN(args.path, false)
  if not gpns then
    print("You can not generate a testsuite template if the gpn doesn't even work.")
  end
  -- Merge the returned results with the info from the get parameter values.
  for _, full_path in ipairs(gpns) do
    if full_path.name then
      local pathinfo = result_paths[full_path.path..full_path.name]
      if pathinfo then
        pathinfo.writable = full_path.writable
      end
    end
  end
  for result_path, info in pairs(result_paths) do
    local println = result_path.." ["..info.type.."] = "
    if info.writable then
      println = println .. info.value .. " (set)"
    elseif strict then
      println = println .. info.value
    else
      println = println .. "*"
    end
    print(println)
  end
end

local usage_msg = [[
  Generate a testsuite template.
    <path> (datamodel_path) The data model path
    <strict> (bool default false) Boolean. If true print parameter values.
]]

-- Table representation of the template command module
local command = {
  name = "template",
  usage_msg = usage_msg,
  action = template_function, -- Function to be called when template command executes.
}

local M = {}

M.name = command.name

M.clash_datamodel_not_required = true

--- Function to initialize the template command module.
-- This will register the template command module with the CLI core.
M.init = function()
  register(command)
end

--- Function to destroy the template command module.
-- This will unregister the template command module from the CLI core.
M.destroy = function()
  unregister(command)
end

return M
