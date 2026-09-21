local M = {}

function M.entry(runtime, l2type)
   local uci = runtime.uci
   local conn = runtime.ubus
   local logger = runtime.logger
   local x = uci.cursor()

   -- no need to build the Multiwan configuration if the previous l3type was me
   local origL3 = x:get("wansensing", "global", "l3type")
   if origL3 == "L3MultiWan" then
      return true
   end

   logger:notice("Reconfigure the network stack in Multiwan mode")

--   x:set("dhcp", "dnsrule", "domain", "sip.bredband.net", "dnsset", "voip", )

--   config dnsrule-
--	option domain 'sip.bredband.net'
--	option dnsset 'voip'
--	option outpolicy 'voip_only'
	
--config dnsrule
--	option domain 'sip.glocalnet.se'
--	option dnsset 'voip'
--	option outpolicy 'voip_only'

   
   
   x:set("network", "wan", "auto", '1')
   x:set("network", "voip", "auto", '1')
   x:set("network", "iptv", "auto", '1')
   x:commit("network")
   
   x:set("mwan", "iptv_only", "interface", "iptv")
   x:set("mwan", "voip_only", "interface", "voip")
   x:set("mwan", "mgmt_only", "interface", "wan")
   x:commit("mwan")

   x:set("igmpproxy", "iptv", "state", "upstream")
   x:set("igmpproxy", "wan", "state", "inactive")
   x:commit("igmpproxy")
   os.execute("/etc/init.d/igmpproxy reload")

-- set ledfw to monitor iptv interface also: 
   x:set("ledfw", "iptv", "check", "1")  
   x:commit("ledfw")
   os.execute("/etc/init.d/ledfw reload")
 
   -- this reload + up of wan will reload mwan rules too
   conn:call("network", "reload", { })
   conn:call("network.interface.wan", "up", { })
   conn:call("network.interface.itpv", "up", { })
   conn:call("network.interface.voip", "up", { })
   
   x:set("mmpbxrvsipnet", "sip_net", "interface", "voip")
   x:commit("mmpbxrvsipnet")
   --os.execute("/etc/init.d/mmpbxd reload")
   return true

end

function M.exit(runtime, l2type)
   -- nothing to do
   return true
end

return M
