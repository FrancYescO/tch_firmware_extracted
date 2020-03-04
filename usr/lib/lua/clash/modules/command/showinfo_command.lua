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
-- @module modules.command.showinfo_command
--
local require = require

      -- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local cmd_assist = require("helper.command")

local cmd_name = "showinfo"
local usage_msg = [[
  -l        List available info
  <info>   (optional string) Info to show
  -i        When filter is active, match case-insensitive
  --filter (optional string) A Lua pattern filter;
            only lines that match the filter are printed.
]]

local function showinfo_function(args)
  args = cmd_assist.rename_args(usage_msg, args)

  local renamed = {}
  if args["-l"] then
    if args.info then
      print("-l cannot be used with info")
      return
    else
      renamed["--command"] = "list"
    end
  elseif args.info then
    renamed["--command"] = "show"
    renamed["--info"] = args.info
  end
  if args["--filter"] then
    renamed["--filter"] = args["--filter"]
    if args["-i"] then
      renamed["-i"] = true
    end
  end
  local ok, errmsg = cmd_assist.launch_command(cmd_name, renamed)
  if not ok then
    print(errmsg)
  end
end

-- Table representation of the showinfo command module
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = showinfo_function,
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
