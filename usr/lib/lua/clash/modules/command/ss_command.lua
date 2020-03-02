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
-- @module modules.command.ss_command
--
local require = require

      -- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local cmd_assist = require("helper.command")

local cmd_name = "ss"
local usage_msg = [[
  Dump the socket statistics
       -a      All sockets

       -l      Listening sockets

               Else: connected sockets

       -t      TCP sockets

       -u      UDP sockets

       -w      Raw sockets

       -x      Unix sockets

               Else: all socket types

       -n      Don't resolve names

       -p      Show PID/program name for sockets
]]
local function ss_function(args)
  args = cmd_assist.rename_args(usage_msg, args)
  local ok, errmsg = cmd_assist.launch_command(cmd_name, args)
  if not ok then
    print(errmsg)
  end
end

-- Table representation of the ss command module
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = ss_function,
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
