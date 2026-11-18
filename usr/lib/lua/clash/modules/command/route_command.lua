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
-- @module modules.command.route_command
--
local require = require

      -- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local match = string.match
local gmatch = string.gmatch

local cmd_assist = require("helper.command")

local cmd_name = "route"
local usage_msg = [[
  Show / manipulate the IP routing table
    <action>  (string default "") Add or delete a route. Default is show routes
               { add | del }
    --net     (optional string) The target is a network
    --host    (optional string) The target is a host
    --netmask (optional string) When adding a network route, the netmask to be used
    --gw      (optional string) Route packets via a gateway
    --metric  (optional string) Set the metric field in the routing table
    --dev     (optional string) Force the route to be associated with the specified device
]]

local actions = {}
local translations = {
  ["--net"] = "-net",
  ["--host"] = "-host",
  ["--netmask"] = "netmask",
  ["--gw"] = "gw",
  ["--metric"] = "metric",
  ["--dev"] = "dev",
}

do
  -- Extract actions string
  local actions_string = match(usage_msg, "<action>.-{(.-)}")
  for a in gmatch(actions_string, "%a+") do
    actions[a] = true
  end
  -- Add default action
  actions[""] = true
end

-- Returns true when provided `args` are valid for route, false otherwise
local function verify_args(args)
  if not args then
    return false
  end

  local action = args["action"]
  -- Only actions defined in usage_msg are valid
  if not actions[action] then
    print("invalid action: %s", action)
    return false
  end

  if action == "" then
    -- Default action
    -- Determine # keys
    local len = 0
    for _ in pairs(args) do
      len = len + 1
    end

    -- No further arguments are expected
    if len ~= 1 then
      print("add or del required")
      return false
    end
  else
    -- Non-default action
    -- Expect --net or --host
    if not args["--net"] and not args["--host"] then
      print("--net or --host required")
      return false
    end
  end

  return true
end

local function fixup_action(args)
  local action = args["action"]

  -- Transformer has no mapping for action
  args["action"] = nil

  -- Default action, no further fixup required
  if action == "" then
    return args
  end

  -- Non-default action, add the action as key with value 'true'
  -- F.e. args = {action="add"} => args = {action="add", add=true}
  if actions[action] then
    args[action] = true
  end

  return args
end

local function fixup_options(args)
  -- Translate options according to the 'translations' table
  -- F.e. args = {["--host"]="192.168.1.1"} => args = {["-host"]="192.168.1.1"}
  for k,v in pairs(translations) do
    -- key exists?
    if args[k] then
        args[v] = args[k]
        args[k] = nil
    end
  end

  return args
end

local function fixup_args(args)
  args = fixup_action(args)
  args = fixup_options(args)
  return args
end

local function route_function(args)
  args = cmd_assist.rename_args(usage_msg, args)

  -- Verification of args
  if not verify_args(args) then
    return
  end

  -- Fixup clash arguments to match transformer arguments
  args = fixup_args(args)

  -- Possibility to further rename args here
  local ok, errmsg = cmd_assist.launch_command(cmd_name, args)
  if not ok then
    print(errmsg)
  end
end

-- Table representation of the route command module
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = route_function,
}

local M = {}

M.name = command.name

M.init = function()
  register(command)
end

M.destroy = function()
  unregister(command)
end

return M
