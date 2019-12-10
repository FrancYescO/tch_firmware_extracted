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
-- @module modules.command.tcpdump_command
--
local require = require

      -- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local cmd_assist = require("helper.command")

local cmd_name = "tcpdump"
local usage_msg = [[
  Dump traffic on a network
    -i (string) Listen on interface
    -s (string default 65535) Snarf snaplen bytes of data from each packet rather than the
        default of 65535 bytes
    -v  When parsing and printing, produce (slightly more) verbose output
    -n  Don't convert addresses to names
    -w  Write raw packets to standard output (wireshark)
    -S  Print absolute, rather than relative, TCP sequence numbers
    <expression> (string default "") Selects which packets will be dumped.  If no expression is given,
        all packets on the net will be dumped. Otherwise, only packets for which
        expression is `true' will be dumped. Expression must be quoted.
]]

local function tcpdump_function(args)
  if args["w"] then -- set '-' to indicate output has to go to stdout
    args["w"] = "-"
  else -- remove it from the option list
    args["w"] = nil
  end
  args = cmd_assist.rename_args(usage_msg, args)
  -- Possibility to further rename args here
  local ok, errmsg = cmd_assist.launch_command(cmd_name, args)
  if not ok then
    print(errmsg)
  end
end

-- Table representation of the tcpdump command module
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = tcpdump_function,
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
