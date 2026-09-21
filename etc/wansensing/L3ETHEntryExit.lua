local M = {}

function M.entry(runtime, l2type)
   local proxy = require("datamodel")
   local uci = runtime.uci
   local conn = runtime.ubus
   local logger = runtime.logger

--   logger:notice("L3ETHEntry: configuring PPPoEoETH on wan interface on l2type interface " .. tostring(l2type))

   local x = uci.cursor()

   -- the wan interface exists from defaults, 
   -- we now just need to map it to the right
   -- vlan interface , likewise for Voip

   -- we dont delete them, as they are needed once we drop connection and return to L2Sense:
   local user_ppp = x:get("network", "wan", "username")
   local pass_ppp = x:get("network", "wan", "password")
   x:set("network", "wanpppoa", "auto", "0")
   x:set("network", "wanpppoa", "username", user_ppp)
   x:set("network", "wanpppoa", "password", pass_ppp)
   x:set("network", "wanpppoe", "auto", "0")
   x:set("network", "wanpppoe", "username", user_ppp)
   x:set("network", "wanpppoe", "password", pass_ppp)
   
   x:set("network", "wan", "proto", "pppoe")
   x:set("network", "wan", "ifname", "waneth4")
   x:set("network", "wan", "auto", "1")
   
  
   x:commit("network")
   conn:call("network", "reload", { })
--   os.execute("ifup wan")
   
   return true
end

function M.exit(runtime,l2type, transition)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger

    if not uci or not conn or not logger then
        return false
    end

--    logger:notice("The L3ETH exit script is using transition " .. transition .. " using l2type " .. tostring(l2type))

    -- remove ppp sense interface
    local x = uci.cursor()

    return true
end

return M
