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
-- @module modules.command.readlogfile_command
--
local require = require

      -- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local cmd_assist = require("helper.command")
local lfs = require("lfs")

local cmd_name = "readlogfile"
local usage_msg = [[
  -f      Print data as file grows
  <file> (filesystem_path) File to read
]]

local function check_real_file(file)
  if lfs.symlinkattributes(file, "mode") == "file" then
    return true
  end
  return false
end

local function readlogfile_function(args)
  args = cmd_assist.rename_args(usage_msg, args)

  -- Using `-f`, the data is printed as the file grows.
  -- When this option is not set, always pass `+1` to dump the whole file.
  if not args["-f"] then
    args["+1"] = true
  end
  
  if not check_real_file(args["file"]) then
    print("The given file path does not point to a file")
  else
    local ok, errmsg = cmd_assist.launch_command(cmd_name, args)
    if not ok then
      print(errmsg)
    end
  end
end

-- Table representation of the readlogfile command module
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = readlogfile_function,
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
