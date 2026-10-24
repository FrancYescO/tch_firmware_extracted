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
-- @module modules.command.wireless_autochannel_command
--
local require = require

-- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local cmd_assist = require("helper.command")

local cmd_name = "wireless_autochannel"
local usage_msg = [[
  Show the statistics of wireless channel.
    -r (optional string) Radio interface, this can be radio_2G or radio_5G
    --bsslist      Dump the bss list, this is a list indicating the existing networks (SSID/BSSID) on all channels that the AP can scan
    --detail       Dump the detailed ACS configuration
    --scanhistory  Dump the historical overview of channel changes
    --scanreport   Dump the result of the most recent scan
    Examples:
     wireless_autochannel -r radio_2G --bsslist
     wireless_autochannel -r radio_5G --bsslist
]]

local function wireless_autochannel_function(args)
  args = cmd_assist.rename_args(usage_msg, args)
  -- Possibility to further rename args here
  local ok, errmsg = cmd_assist.launch_command(cmd_name, args)
  if not ok then
    print(errmsg)
  end
end

-- Table representation of the wireless_autochannel command module
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = wireless_autochannel_function,
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
