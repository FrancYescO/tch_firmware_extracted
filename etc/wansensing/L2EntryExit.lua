local M = {}

function M.entry(runtime)

   -- workaround for NG-21968, before root cause issue fixed
   os.execute("/etc/init.d/xtm restart")

   return true
end

function M.exit(runtime, l2type)
   local uci = runtime.uci
   local conn = runtime.ubus
   local logger = runtime.logger

   local x = uci.cursor()
   local origL2 = x:get("wansensing", "global", "l2type")

   -- do nothing if sensed l2type is not changed
   if origL2 == l2type then
      return true
   end

   -- reconfigure if sensed l2type changed
   logger:notice("Configuring the lower layer interfaces of the network stack using l2type " .. l2type)

   if l2type == "ETH" then
      -- 1 interface to route all services
      x:set("network", "wan", "ifname", "eth4")
      x:commit("network")

   elseif l2type == "VDSL" then
      -- 3 interface to rout all services (services are interface specific)
      x:set("network", "wan", "ifname", "vlan698")
      x:set("network", "iptv", "ifname", "vlan695")
      x:set("network", "voip", "ifname", "vlan697")
      x:commit("network")
	  
      x:set("mwan", "voip_only", "interface", "voip")
      x:set("mwan", "mgmt_only", "interface", "wan")
      x:commit("mwan")
	  
   elseif l2type == "ADSL" then
      x:set("network", "wan", "ifname", "atm_wan")
      x:set("network", "voip", "ifname", "atm_voip")
      x:set("network", "iptv", "ifname", "atm_iptv")
      x:commit("network")

      x:set("mwan", "voip_only", "interface", "voip")
      x:set("mwan", "mgmt_only", "interface", "wan")
      x:commit("mwan")

      -- this reload + up of wan will reload mwan rules too
      conn:call("network", "reload", { })
      conn:call("network.interface.wan", "up", { })
      conn:call("network.interface.voip", "up", { })
   end

   return true
end

return M

