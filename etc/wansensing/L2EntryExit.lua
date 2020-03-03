--NG-102545 GUI broadband is showing SFP Broadband GUI page when Ethernet 4 is connected
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
   local scripthelpers = runtime.scripth   
   local x = uci.cursor()
   local isSFP = x:get("env","rip","sfp")
   local origL2 = x:get("wansensing", "global", "l2type")
   local check_tmrval = tonumber(x:get("wansensing", "worker1", "toggle_time") or 30)
   
   -- For Worker: now the runtime function shall be stopped, and the Worker should not be in action
   if runtime.timer_ppp_eth then
      timer_ppp_eth = runtime.timer_ppp_eth
      timer_ppp_eth:stop()
   end

 
   -- do nothing if sensed l2type is not changed
   if isSFP == "1" and (l2type == "SFP" or l2type == "VDSL" or l2type == "ADSL") then
      local lanwanmode = x:get("ethernet", "globals", "eth4lanwanmode")
      if lanwanmode ~= "1" then
        logger:notice("State of SFP value "..l2type..isSFP)
        x:set("ethernet", "globals", "eth4lanwanmode", "1")
        x:commit("ethernet")
        x:set("qos", "eth3", "classgroup", "TO_LAN")
        x:commit("qos")
        os.execute("/etc/init.d/qos reload")
        os.execute("/etc/init.d/ethernet reload")
      end
   end
   if origL2 == l2type then
-- this will be hit, if L2 sensing is hit and we are again on the same one as befor   
logger:notice("FRS OrigL2=L2: now activating the runtime function and the event for the worker") 
logger:notice("FRS Timer-Interval: " .. check_tmrval)  

      -- Workaround for NG-xxxx (NG-52864)
      os.execute("/etc/init.d/pppoe-relay-tch reload")
-- Calling the ethernet Worker, it shall only be called, in case we are on ETH-Mode and NOT on SFP-Mode
		if l2type == "ETH" then
logger:notice("FRS L2EntyExit -- starting Worker since in ETH Mode as before : ")	
			timer_ppp_eth = scripthelpers.fire_timed_event("check_network_ethwan", check_tmrval, 1)
-- since the called function (fire_timed_event) is doing at "timer:start()"	the worker will be activated
 			runtime.timer_ppp_eth = timer_ppp_eth
		end
      return true
   end

   -- reconfigure if sensed l2type changed
   logger:notice("Configuring the lower layer interfaces of the network stack using l2type " .. l2type)

   local devname

   if l2type == "ETH" or l2type == "SFP" then
      -- 1 interface to route all services
      devname = x:get("network", "waneth4", "ifname") and "waneth4" or "eth4"
      x:set("network", "wan", "ifname", devname)

      if isSFP == "1" then
        x:delete("network", "lan", "pppoerelay")
        x:set("network", "lan", "pppoerelay", { devname })
      end
      x:commit("network")

      x:set("xtm","ptm0", "ptmdevice")
      x:set("xtm","ptm0", "path","fast")
      x:set("xtm","ptm0", "priority","low")
      x:commit("xtm")
      if isSFP == "1" and l2type == "SFP" then
	 os.execute("/usr/bin/xdslctl stop")
      end
      os.execute("ifdown wan; /etc/init.d/xtm reload")

	  -- Calling the ethernet Worker,  it shall only be called, in case we are on ETH-Mode and NOT on SFP-Mode

		if l2type == "ETH" then
			timer_ppp_eth = scripthelpers.fire_timed_event("check_network_ethwan", check_tmrval, 1)
logger:notice("FRS -- : now activating the runtime function and the event for the worker since change to ETH mpde has been done")
-- since the called function (fire_timed_event) is doing at "timer:start()"	the worker will be activated
			runtime.timer_ppp_eth = timer_ppp_eth
		end
   elseif l2type == "VDSL" then
      -- 1 interface to route all services (services are NOT interface specific)
      devname = x:get("network", "wanptm0", "ifname") and "wanptm0" or "ptm0"
      x:set("network", "wan", "ifname", devname)

      if isSFP == "1" then
        x:delete("network", "lan", "pppoerelay")
        x:set("network", "lan", "pppoerelay", { devname })
      end
      x:commit("network")

      x:set("xtm","ptm0", "ptmdevice")
      x:set("xtm","ptm0", "path","fast")
      x:set("xtm","ptm0", "priority","low")
      x:commit("xtm")
      os.execute("ifdown wan; /etc/init.d/xtm reload")

   elseif l2type == "ADSL" then
      x:set("network", "wan", "ifname", "atmwan")

      if isSFP == "1" then
        x:delete("network", "lan", "pppoerelay")
        x:set("network", "lan", "pppoerelay", { "atmwan" })
      end
      x:commit("network")

      x:delete("xtm","ptm0")
      x:commit("xtm")
      os.execute("ifdown wan; /etc/init.d/xtm reload")

    end

    -- this reload + up of wan will reload mwan rules too
    conn:call("network", "reload", { })
    os.execute("/etc/init.d/pppoe-relay-tch reload")
    --conn:call("network.interface.wan", "up", { })

    os.execute("ifup wan")

    return true
end

return M

