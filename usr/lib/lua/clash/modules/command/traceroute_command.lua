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
-- @module modules.command.traceroute_command
--
local require = require

      -- Functions made available from the CLI environment
local print, register, unregister =
      print, register, unregister

local cmd_assist = require("helper.command")

local cmd_name = "traceroute"
local usage_msg = [[
  Traces path to a network host
    -F  Set the don't fragment bit
    -I  Use ICMP ECHO instead of UDP datagrams
    -l  Display the TTL value of the returned packet
    -d  Set SO_DEBUG options to socket
    -n  Print numeric addresses
    -r  Bypass routing tables, send directly to HOST
    -v  Verbose
    -m (string default 30) Max time-to-live (max number of hops)
    -p (string default 33434) Base UDP port number used in probes
    -q (string default 3) Number of probes per TTL
    -s (string default 0.0.0.0) IP address to use as the source address
    -t (string default 0) Type-of-service in probe packets
    -w (string default 3) Time in seconds to wait for a response
    <host>  (string) Host to trace packets to
    <bytes> (string default 60) Total size of probing packet
]]

local function traceroute_function(args)
  args = cmd_assist.rename_args(usage_msg, args)
  -- Possibility to further rename args here
  local ok, errmsg = cmd_assist.launch_command(cmd_name, args)
  if not ok then
    print(errmsg)
  end
end

-- Table representation of the traceroute command module
local command = {
  name = cmd_name,
  usage_msg = usage_msg,
  action = traceroute_function,
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
