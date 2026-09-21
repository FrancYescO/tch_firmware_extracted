local M = {}

function M.entry(runtime, l2type)
   local proxy = require("datamodel")
   local uci = runtime.uci
   local conn = runtime.ubus
   local logger = runtime.logger
   local x = uci.cursor()

   logger:notice("The L3PPPoA entry script is configuring PPP on wan interface on l2type interface " .. tostring(l2type))

   logger:notice("we dont delete them, as they are needed once we drop connection and return to L2Sense:")
   local user_ppp = x:get("network", "wan", "username")
   local pass_ppp = x:get("network", "wan", "password")
   x:set("network", "wanpppoa", "auto", "0")
   x:set("network", "wanpppoa", "username", user_ppp)
   x:set("network", "wanpppoa", "password", pass_ppp)
   x:set("network", "wanpppoe", "auto", "0")
   x:set("network", "wanpppoe", "username", user_ppp)
   x:set("network", "wanpppoe", "password", pass_ppp)



   logger:notice("commit and reload network for disabling dummy PPPoA")
   x:commit("network")
   conn:call("network", "reload", { })
 --  os.execute("ifdown wanpppoe")
--   os.execute("ifdown wanpppoa")
   
  logger:notice("PPPoA: Wait 5 seconds before WAN is UP)")
  os.execute("sleep 5")
	
   x:set("network", "wan", "proto", "pppoa")
   x:set("network", "wan", "vpi", "8")
   x:set("network", "wan", "vci", "35")
   x:set("network", "wan", "ifname", "atm_8_35")
   x:set("network", "wan", "auto", "1")
   x:commit("network")
   conn:call("network", "reload", { })
--   os.execute("ifup wan")
   
   return true
end

function M.exit(runtime,l2type, transition)
   local logger = runtime.logger
   
--   logger:notice("The L3PPPoA exit script is using transition " .. transition .. " using l2type " .. tostring(l2type))
   
   return true
end

return M
