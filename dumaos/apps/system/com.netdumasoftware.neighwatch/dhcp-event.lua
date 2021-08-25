#!/usr/bin/lua
--[[
  (C) 2016 NETDUMA Software <iainf@netduma.com>
  In /etc/dnsmasq.conf make sure to add the following line
  dhcp-script=/path/to/script/dhcp-event.lua
--]]

package.path=""
package.cpath="/usr/lib/lua/?.so;"
require("ubus")

local conn = ubus.connect()
if not conn then
  -- TODO(syslog): log the major error
  error("Failed to connect to ubus")
end

local status = conn:call("com.netdumasoftware.neighwatch","dhcp_event",{ event=arg[1], mac=arg[2], ip=arg[3], hostname=arg[4] })

-- TODO(syslog): log error if status invalid

conn:close()
