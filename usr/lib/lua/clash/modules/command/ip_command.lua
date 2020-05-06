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
-- @module modules.command.ip_command
--
local require = require

      -- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local match = string.match

local cmd_assist = require("helper.command")

local cmd_name = "ip"

-- When modifying usage_msg layout, make sure that var `objects`
-- is created with a matching pattern.
local usage_msg = [[
  Show routing, devices, policy routing and tunnels
    <object>  (string) Object to show:
               { link | addr | addrlabel | route | rule | neigh | ntable |
                 tunnel | tuntap | maddr | mroute | mrule | monitor |
                 netns | tcp_metrics }
]]

-- Parse supported object from usage message.
local objects = ""
do
  objects = match(usage_msg, "<object>.*{(.*)}")
end

-- Local verifier instead of providing verifier under clash verifiers,
-- since this is really specific to this command.
-- Returns true when provided `object` matches an object listed in usage message,
-- false otherwise
local function verify_object(object)
  if not object then
    return false
  end

  if match(objects, " (" .. object .. ") [|]?") then
    return true
  end

  return false
end

local function ip_function(args)
  args = cmd_assist.rename_args(usage_msg, args)

  -- Keep verification here as this is really specific to this command
  if not verify_object(args["object"]) then
    print("Please provide an object listed in `ip help`")
    return
  end

  local ok, errmsg = cmd_assist.launch_command(cmd_name, args)
  if not ok then
    print(errmsg)
  end
end

-- Table representation of the ip command module
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = ip_function,
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
