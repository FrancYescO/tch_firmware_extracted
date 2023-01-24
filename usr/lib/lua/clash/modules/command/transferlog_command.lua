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
-- @module modules.command.transferlog_command
--
local require = require

      -- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local cmd_assist = require("helper.command")

local cmd_name = "transferlog"
local usage_msg = [[
  List and pipe log files to host
    -l  List log file(s)
    -p (optional string) In non-interactive mode, pipe transferlog file to host.
        The argument is the transferlog file to pipe;
        it must be one of the files that is listed by using `-l`.
        Always use on host only, in conjuction with redirect to file.
        Example: `ssh user@192.168.1.1 transferlog -p messages.log > messages.log`
]]

local function transferlog_function(args)
  local ok, errmsg = cmd_assist.rename_args_and_launch_command(cmd_name, usage_msg, args)
  if not ok then
    print(errmsg)
  end
end

local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = transferlog_function,
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
