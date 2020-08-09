#!/usr/bin/lua
package.path=""package.cpath="/usr/lib/lua/?.so;"require("ubus")local a=ubus.connect()if not a then
error("Failed to connect to ubus")end
local e=a:call("com.netdumasoftware.neighwatch","dhcp_event",{event=arg[1],mac=arg[2],ip=arg[3],hostname=arg[4]})a:close()