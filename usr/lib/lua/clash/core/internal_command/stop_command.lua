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
-- A module that implements the stop command.
--
-- @module modules.command.stop_command
--
local ipairs, require, pairs = ipairs, require, pairs
local gsub, match = string.gsub, string.match

local cli_instance
local running_pattern = "Command.Session.@@.Running."
local running_op
local uuid

local proxy = require("datamodel-bck")

local function print(...)
  cli_instance.io_handler:println(...)
end

local function stop_function(args)
  if not args.pid and not args.list then
    -- stop all
    local tostop = {}
    local needtostop = 0
    local result, errmsg = proxy.get(uuid, running_op)
    if not result then
      print("ERROR: %s",errmsg)
    else
      for _, param in ipairs(result) do
        if param.param == "pid" then
          tostop[running_op.."@"..param.value..".stop"] = "1"
          needtostop = needtostop + 1
        end
      end
    end
    if needtostop > 0 then
      print("number of processes to stop: %d",needtostop)
      result, errmsg = proxy.set(uuid, tostop)
      if not result then
        print("ERROR: %s",errmsg)
      else
        print("All processes stopped!")
      end
    else
      print("No processes found to be stopped")
    end
  elseif args.list then
    -- list all running processes
    local process_list = {}
    local need_to_print = false
    local result, errmsg = proxy.get(uuid, running_op)
    if not result then
      print("ERROR: %s",errmsg)
    else
      for _, param in ipairs(result) do
        if param.param == "cmdline" then
          local pid = match(param.path, "@([%d]+)%.$")
          process_list[pid] = param.value
          need_to_print = true
        end
      end
    end
    if need_to_print then
      print("Running processes:")
      for pid, cmdline in pairs(process_list) do
        print("  %s [%d]", cmdline, pid)
      end
    else
      print("Currently there are no clash processes running.")
    end
  else
    -- stop a specific process
    local process_op = running_op.."@"..args.pid.."."
    local result, errmsg = proxy.get(uuid, process_op)
    if not result then
      print("No process running with the given pid: %d", args.pid)
    else
      process_op = process_op .. "stop"
      result, errmsg = proxy.set(uuid, process_op, "1")
      if not result then
        print("ERROR: %s",errmsg)
      else
        print("process %d stopped", args.pid)
      end
    end
  end
end

local usage_msg = [[
  Stop one or more running clash processes
    -l,--list   List all running clash processes.
    <pid> (optional number) The clash process to stop.
]]

-- Table representation of the stop command module
local command = {
  name = "stop",
  usage_msg = usage_msg,
  action = stop_function,
}

local M = {}

M.name = command.name

--- Function to initialize the stop command module.
-- This will register the stop command module with the CLI core.
M.init = function()
  cli_instance.store:register_module(command)
end

--- Function to destroy the stop command module.
-- This will unregister the stop command module from the CLI core.
M.destroy = function()
  cli_instance.store:unregister_module(command)
end

M.load_cli = function(cli)
  cli_instance = cli
  uuid = cli_instance.session:get_uuid()
  running_op = gsub(running_pattern, "@@", "@"..uuid)
end

return M
