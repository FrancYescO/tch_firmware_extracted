local M = {}

function M.entry(runtime, l2type)
   local uci = runtime.uci
   local conn = runtime.ubus
   local logger = runtime.logger
   local x = uci.cursor()

   logger:notice("Create a Single Wan Mode network stack")

   -- no need to reload the voice implema if the previous l3type was me
   local origL3 = x:get("wansensing", "global", "l3type")
   if origL3 == "L3SingleWan" then
      return true
   end

   x:set("igmpproxy", "iptv", "state", "inactive")
   x:set("igmpproxy", "wan", "state", "upstream")
   x:commit("igmpproxy")
   os.execute("/etc/init.d/igmpproxy reload")

   x:set("network", "wan", "auto", '1')
   x:set("network", "voip", "auto", '0')
   x:set("network", "iptv", "auto", '0')
   x:commit("network")

   x:set("mwan", "iptv_only", "interface", "wan")
   x:set("mwan", "voip_only", "interface", "wan")
   x:set("mwan", "mgmt_only", "interface", "wan")
   x:commit("mwan")
   -- added for GHG-3677
   os.execute("/etc/init.d/mwan reload") 

   -- delete the dnsset in case of Single WAN interface
   
   x:delete("dhcp", "voiprule1")
   x:delete("dhcp", "voiprule2")
   x:delete("dhcp", "iptvrule1")   
   x:commit("dhcp")
   os.execute("/etc/init.d/dnsmasq reload")
      
   
   -- this reload + up of wan will reload mwan rules too
   conn:call("network", "reload", { })
   conn:call("network.interface.wan", "up", { })
   
   x:set("mmpbxrvsipnet", "sip_net", "interface", "wan")
   x:commit("mmpbxrvsipnet")
   --os.execute("/etc/init.d/mmpbxd reload")

   return true

end

function M.exit(runtime, l2type)
   -- nothing to do
   return true
end

return M
