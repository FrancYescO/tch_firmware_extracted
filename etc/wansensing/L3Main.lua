local M = {}

M.SenseEventSet = {
    'xdsl_0',
    'network_device_eth4_down',
    'network_interface_wan6_ifup',
}

--runtime = runtime environment holding references to ubus, uci, logger
--L2Type = specifies the sensed layer2 medium (=return parameter of the layer2 main script)
--         e.g. ADSL,VDSL,ETH
function M.check(runtime, l2type, event)
   local scripthelpers = runtime.scripth
   local conn = runtime.ubus
   local uci = runtime.uci
   local x = uci.cursor()
   local logger = runtime.logger

   local opt125 = x:get("env", "var","opt125")

   --Enable IPv6 on the LAN if dual stack IPv6 is enabled and received an IP and there were no user interactions on the GUI.
   if event == "network_interface_wan6_ifup" then

      local nativeipv6 = conn:call("network.interface.wan6", "status", { })
      local useripv6 = x:get("env", "var","useripv6")
      local lanipv6 = x:get("network", "lan", "ipv6")

      if nativeipv6.up and useripv6 ~= "1" and lanipv6 == "0" then
         logger:notice("Enable IPv6 for the LAN Interface")
         x:set("network", "lan", "ip6assign", "64")
         x:set("network", "lan", "ipv6", "1")
         x:commit("network")
         os.execute("/etc/init.d/network reload")
      end
   end

   if  event == "timeout" then
   --check if the mark of cwmpd is correctly applied
         --First load the value of the mwan config into a variable
   local mwanmark
   local f = io.open("/var/etc/mwan.config", "r")
   for line in f:lines() do
      if line:match("cwmpd") then
         mwanmark = line:match(" (.*)$")
         break
      end
   end
   --Secondly load the uci parameter that stored the starting mark of cwmpd into another variable
   local startmark = x:get("env", "var","cwmpmark")
   --match both strings
   if string.match(mwanmark,startmark) ==  nil then
      logger:notice("cwmpd is NOT started with the correct mwan mark")
      logger:notice("startmark is %s",startmark)
      logger:notice("mwanmark is %s",mwanmark)
      os.execute("sed -i 'N;$!P;$!D;$d' /etc/config/watchdog")
      os.execute("/etc/init.d/watchdog-tch reload")
      os.execute("/etc/init.d/cwmpd restart")
      os.execute("cp /rom/etc/config/watchdog /etc/config/watchdog")
      os.execute("/etc/init.d/watchdog-tch reload")
   end
      -- Move devices from Multi VLAN to Single VLAN if opt125 is not received anymore.
      if opt125 == "2" then
         logger:notice("Option 125 not received anymore switching to single VLAN via L2Sense")
         return "L2Sense"
      end

      -- Check if wan is up for 24h with private IP and disable wan if so.
      local nwifwan = conn:call("network.interface.wan", "status", { })

      if nwifwan.up then

         local iptest = string.match(nwifwan["ipv4-address"][1]["address"], "%d%d%.")

         local f = io.open("/proc/uptime")
         local line = f:read("*line")
         f:close()

         local up_t = math.floor(string.match(line, "[%d]+"))

         if iptest == "10." and up_t > 86400 then
            conn:call("network.interface.wan","down", {})
         end

      end

      return "L3Sense"

   else

      if scripthelpers.checkIfCurrentL2WentDown(l2type, event, 'eth4') then
         return "L2Sense"
      end
   end

   return "L3Sense"
end

return M


