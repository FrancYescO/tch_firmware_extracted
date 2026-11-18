--NG-102545 GUI broadband is showing SFP Broadband GUI page when Ethernet 4 is connected
--NG-103827 Wansensing, modify to new requirements
--NG-105062 Wansensing, modify to new requirements with COC Version1
local M = {}

function M.entry(runtime)
	local uci = runtime.uci
	local x = uci.cursor()
	local origL2 = x:get("wansensing", "global", "l2type")
	if origL2 == "SFP" then
		os.execute("/usr/bin/xdslctl start")
		os.execute("/usr/bin/xdslctl connection --up")
	end
   -- workaround for NG-21968, before root cause issue fixed
   -- os.execute("/etc/init.d/xtm restart")

   return true
end

function M.exit(runtime, l2type)
   local uci = runtime.uci
   local conn = runtime.ubus
   local logger = runtime.logger

   local x = uci.cursor()
   local isSFP = x:get("env","rip","sfp")
   local origL2 = x:get("wansensing", "global", "l2type")
	
	logger:notice("State of SFP value"..isSFP)
   -- do nothing if sensed l2type is not changed
   if isSFP == "1" and (l2type == "SFP" or l2type == "VDSL" or l2type == "ADSL") then
		local lanwanmode = x:get("ethernet", "globals", "eth4lanwanmode")
		if lanwanmode ~= "1" then
		logger:notice("State of SFP value "..l2type..isSFP)
			x:set("ethernet", "globals", "eth4lanwanmode", "1")
			x:commit("ethernet")
			os.execute("/etc/init.d/ethernet reload")
		end
	end
   if origL2 == l2type then
		-- Workaround for NG-xxxx (NG-52864)
		
		 os.execute("/etc/init.d/pppoe-relay-tch reload")

      return true
   end

   -- reconfigure if sensed l2type changed
   logger:notice("Configuring the lower layer interfaces of the network stack using l2type " .. l2type)

   if l2type == "ETH" or l2type == "SFP" then
      -- 1 interface to route all services
      x:set("network", "wan", "ifname", "waneth4")
      
      x:delete("network", "lan", "pppoerelay")
      x:set("network", "lan", "pppoerelay", { "waneth4" })
      
      x:commit("network")
      
      x:set("xtm","ptm0", "ptmdevice")
      x:set("xtm","ptm0", "path","fast")
      x:set("xtm","ptm0", "priority","low")
      x:commit("xtm")
	  
	  if isSFP == "1" and l2type == "SFP" then
		os.execute("/usr/bin/xdslctl stop")
	  end
      os.execute("ifdown wan; /etc/init.d/xtm reload")
      
   elseif l2type == "VDSL" then
      -- 1 interface to route all services (services are NOT interface specific)
      x:set("network", "wan", "ifname", "wanptm0")
      
      x:delete("network", "lan", "pppoerelay")
      x:set("network", "lan", "pppoerelay", { "wanptm0" })
      
      x:commit("network")
      
      x:set("xtm","ptm0", "ptmdevice")
      x:set("xtm","ptm0", "path","fast")
      x:set("xtm","ptm0", "priority","low")
      x:commit("xtm")
		
      os.execute("ifdown wan; /etc/init.d/xtm reload")
       
   elseif l2type == "ADSL" then
      x:set("network", "wan", "ifname", "atmwan")
      
      x:delete("network", "lan", "pppoerelay")
      x:set("network", "lan", "pppoerelay", { "atmwan" })
      
      x:commit("network")
      
      x:delete("xtm","ptm0")
      x:commit("xtm")
		
      os.execute("ifdown wan; /etc/init.d/xtm reload")
      
    end
    
    -- this reload + up of wan will reload mwan rules too
    conn:call("network", "reload", { })
	--conn:call("ethernet", "reload", { })
    os.execute("/etc/init.d/pppoe-relay-tch reload")
    --conn:call("network.interface.wan", "up", { })
    
    os.execute("ifup wan")

    return true
end

return M

