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
-- @module modules.command.ubuscall_command
--
local require = require

      -- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local cmd_assist = require("helper.command")
local ubus_acc = require("helper.ubus_acc")

local cmd_name = "ubuscall"
local usage_msg = [[
  Call a method on a UBUS object
    -S         Use simplified output
    -v         More verbose output
    -l,--list  List the available ubuscall commands
    <object>  (optional ubus_object) Object on which to call the method
    <method>  (optional ubus_method) The method to be called. Not all possible methods are supported
    <message> (optional string) The message to send with the call
]]

-- Verifies if access for given UBUS object is granted
local function verify_object(object)
  local obj = ubus_acc[object]
  if type(obj) == "table" and #obj > 0 then
    return true
  end
end

-- Verifies if for given UBUS object, method is allowed
local function verify_method(object, method)
  local methods = method and ubus_acc[object]
  if type(methods) == "table" then
    for _, method_acc in pairs(methods) do
      if method_acc == method then
        return true
      end
    end
  end
end

-- Display the available ubuscall commands from the "allowed" table
local function ubus_list()
  for list in pairs(ubus_acc) do
    print(list)
  end
end

local function ubuscall_function(args)
  args = cmd_assist.rename_args(usage_msg, args)

  -- ubus list is added as an option
  -- hence option -l or --list cannot be used with object or method
  if (args.object or args.method) and args["--list"] == true then
    return nil, "-l or --list option cannot be used with object or method"
  end

  if args.object and args.method then
    -- Only command `call` is supported; pass it fixed
    args.command = "call"
    -- list option is not required when object and method is specified
    args["--list"] = nil
    if not verify_object(args.object) then
      return nil, "No access to this UBUS object"
    elseif not verify_method(args.object, args.method) then
      return nil, "Not allowed to call method on this UBUS object"
    else
      local ok, errmsg = cmd_assist.launch_command(cmd_name, args)
      if not ok then
        return nil, errmsg
      end
    end
  elseif args["--list"] == true then
    ubus_list()
  else
    return nil, "Command is incomplete"
  end
end

-- Table representation of the ubuscall command module
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = ubuscall_function,
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
