#!/usr/bin/lua
package.path=""package.cpath="/usr/lib/lua/?.so;"require"ubus"local a=ubus.connect()if not a then
error("Failed to connect to ubus")end
local e=a:call("com.netdumasoftware.devicemanager","dhcp_event",{event=arg[1],mac=arg[2],optdata=arg[3]})a:close()