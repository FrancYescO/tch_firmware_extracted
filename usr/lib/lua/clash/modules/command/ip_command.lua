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

-- If modifying usage_msg, make sure that variable objects is updated.
local usage_msg = [[
  Show routing, devices, policy routing and tunnels
    <object>  (string) Object to show/edit:
               { link | addr | addrlabel | route | rule | neigh | ntable |
                 tunnel | tuntap | maddr | mroute | mrule | monitor |
                 netns | tcp_metrics }
    Options for neigh:
      --flush  Flush neighbour/ARP cache entry
      --add    (optional string) Add neighbour/ARP cache entry
      --del    (optional string) Delete neighbour/ARP cache entry
      --dev    (optional string) Interface to which the entry is attached
      --lladdr (optional string) Link layer address of the entry
      Examples:
      ip neigh --add 192.168.1.99 --dev br-lan --lladdr 00:19:c6:99:99:99
      ip neigh --del 192.168.1.99 --dev br-lan
      ip neigh --flush --dev br-lan
]]

-- For each object, declare the available options and their translations. An
-- option and its translation can be identical. Each object MUST be defined
-- in this table and the usage_msg!
local objects = {
  ["link"] = {
  },
  ["addr"] = {
  },
  ["addrlabel"] = {
  },
  ["route"] = {
  },
  ["rule"] = {
  },
  ["neigh"] = {
    ["--add"] = "add",
    ["--del"] = "del",
    ["--dev"] = "dev",
    ["--lladdr"] = "lladdr",
    ["--flush"] = "flush",
  },
  ["ntable"] = {
  },
  ["tunnel"] = {
  },
  ["tuntap"] = {
  },
  ["maddr"] = {
  },
  ["mroute"] = {
  },
  ["mrule"] = {
  },
  ["monitor"] = {
  },
  ["netns"] = {
  },
  ["tcp_metrics"] = {
  },
}

-- Returns true when provided args are valid for ip, false otherwise
local function verify_args(args)
  if not args then
    return false
  end
  local object = args["object"]

  local options = objects[object]
  if not options then
    print("invalid object %s", object)
    return false
  end

  for k,v in pairs(args) do
    if k ~= "object" then
      -- Depending on how you specify the option on the clash commandline, its
      -- name will be either the key or the value.
      -- E.g.: (value) ip neigh add   => args = { [1] = add }
      --       (key)   ip neigh --add => args = { ["--add"] = true }
      if not options[k] and not options[v] then
        print("invalid option for object %s", object)
        return false
      end
    end
  end

  return true
end

local function fixup_object(args)
  -- <object> needs to be the first element of the shell command. <object>, as
  -- defined in usage_msg, is an operand according to clash/penlight. Operands
  -- are placed at the tail, after options without arguments and options with
  -- arguments, of the shell command by transformer. To avoid using a wrapper,
  -- in order to ensure correct ordering, the transformer command mapping
  -- defines these operands as options without argument. In here the operand
  -- <object> is replaced by the option <object> without argument.
  local object = args["object"]

  -- Remove the operand <object>
  args["object"] = nil

  -- Replace the operand <object> with an option without argument by adding a
  -- key with value 'true'.
  -- E.g. args = {object="neigh"} => args = {neigh=true}
  if objects[object] then
    args[object] = true
  end

  return args
end

local function fixup_options(object, args)
  -- Clash/penlight requires the options to be defined in the usage_msg. A
  -- short flag (one letter) must start with '-'. A long flag (multiple letters)
  -- must start with a '--'. These requirements do not always match the shell
  -- command and a translation is necessary.
  -- E.g. ip neigh --add ... => ip neigh add ...
  local options = objects[object]

  -- Translate options according to the 'options' table
  -- F.e. args = {["--add"]="192.168.1.1"} => args = {["add"]="192.168.1.1"}
  for k,v in pairs(options) do
    -- key exists?
    if args[k] then
        args[v] = args[k]
        args[k] = nil
    end
  end

  -- Remove flush in args table if flush is not set to true
  -- E.g. args = {["--flush"]=false}
  if not args["--flush"] then
    args["--flush"] = nil
  end

  return args
end

local function fixup_args(args)
  local object = args["object"]
  args = fixup_object(args)
  args = fixup_options(object, args)
  return args
end

local function ip_function(args)
  args = cmd_assist.rename_args(usage_msg, args)

  -- Verification of args
  if not verify_args(args) then
    return
  end

  -- Fixup clash arguments to match transformer arguments
  args = fixup_args(args)

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
