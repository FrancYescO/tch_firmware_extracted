---
-- Module Worker.
-- Module Specifies actions triggered by events
-- @module modulename
local M = {}

-- Advanced Event Registration (availabe for version >= 1.0)
M.SenseEventSet = {
	['start'] = true,
   ['network_interface_wan_ifup'] = true,
}

local function dnsmasq(runtime)
	local uci = runtime.uci
	local conn = runtime.ubus
	local x = uci.cursor()
	local logger = runtime.logger

	x:set("dhcp", "dnsmasq", "rebind_protection", "0")
	x:commit("dhcp")
	logger:notice("Rebind protection disabled")

end

-- EnableDnsSet
-- @param runtime the runtime environment
-- @param intf the interface name
local function EnableDnsSet(runtime, intf)
    local changed = false
    local uci = runtime.uci
    local x = uci:cursor()
    local logger = runtime.logger

    logger:notice("Enabling DNS set for interface:")
    logger:notice(intf)

    x:foreach("dhcp", "dnsrule", function(s)
        if s["dnsset"] == intf and s["enable"] then
            changed=true
            x:delete("dhcp", s[".name"], "enable")
        end
    end
    )
    if changed then
        x:commit("dhcp")
        --run_command(runtime, "/etc/init.d/dnsmasq restart")
        runtime.logger:warning("Dns Rules enabled for intf: " .. intf)
    end
end
---
-- Main function called to indicate an event happened.
--
-- @function [parent=M]
-- @param #1 runtime table holding the wansensing context (async/ubus/uci/logger/scripthelper)
-- @param #2 specifies the event which triggered this check method call (eg. start, network_interface_voip_ifup, network_interface_voip_ifdown)
function M.check(runtime, event)

local nw = require("transformer.mapper.nwcommon")
local conn = runtime.ubus
local uci = runtime.uci
local x = uci.cursor()
local logger = runtime.logger

	-- Check if L2type is ETH and event is start
	local L2type = runtime.scripth.l2HasCarrier("eth4")
	if event == "start" and L2type then
		if runtime.scripth.checkIfInterfaceIsUp("wan") then
			M.check(runtime, "network_interface_wan_ifup")
		end
		return
	-- Handle opt125 if L2type is ETH and wan ifup
	elseif event == "network_interface_wan_ifup" and L2type then
		-- copy the wan interface status into a table.
		logger:notice("Network interface wan ifup detected and checking option 125")

		-- obtain the DHCP option passthru string from the data entry from the status table
		local wan_status = conn:call("network.interface.wan", "status", { })
		local ubusReqOpt = wan_status and wan_status["data"]
		ubusReqOpt = ubusReqOpt and ubusReqOpt["passthru"]

		local mgmtvid = ""
		local iptvvid = ""
		local voipvid = ""

		-- Check if all conditions for reconfiguration are met and obtain the VID's of the interfaces which have to be configured.
		if ubusReqOpt and wan_status.up and wan_status.proto=="dhcp" then
			ubusReqOpt = ubusReqOpt and nw.get_dhcp_tag_value(ubusReqOpt)
			ubusReqOpt = ubusReqOpt and ubusReqOpt["125"]
			-- Check if the DHCP option 125 is sent and obtain the interface VLANs if so.

			local opt125 = x:get("env", "var","opt125")

			if ubusReqOpt == nil and opt125 == "1" then
				logger:notice("Option 125 not received anymore switching to single VLAN")
				x:set("env", "var", "opt125", "2")
				x:commit("env")
				return
			elseif ubusReqOpt == nil and opt125 ~= "1" then
				logger:notice("Option 125 not received")
				x:set("env", "var", "opt125", "0")
				x:commit("env")
				return
			elseif opt125 == "1" then
				logger:notice("No Configuration needed - opt125 was already configured")
				return
			else
				logger:notice("Option 125 received")
				x:set("env", "var", "opt125", "1")
				x:commit("env")
				ubusReqOpt = string.sub(ubusReqOpt, 11)
				ubusReqOpt = ubusReqOpt and nw.get_dhcp_tag_value(ubusReqOpt)
				mgmtvid = ubusReqOpt and ubusReqOpt["21"]
				mgmtvid = mgmtvid and nw.hex2String(mgmtvid)
				iptvvid = ubusReqOpt and ubusReqOpt["22"]
				iptvvid = iptvvid and nw.hex2String(iptvvid)
				voipvid = ubusReqOpt and ubusReqOpt["23"]
				voipvid = voipvid and nw.hex2String(voipvid)
			end

			--local curmgmtvid = x:get("network", "vlan_mgmt", "vid")
			--local curiptvvid = x:get("network", "vlan_iptv", "vid")
			--local curvoipvid = x:get("network", "vlan_voip", "vid")

			-- Don't reconfigure if the gateway is already configured according to option125
			--if curmgmtvid == mgmtvid and curiptvvid == iptvvid and curvoipvid == voipvid then
				--return
			--end

			-- Setup the mgmt interface and all required routing and dns rules if a mgmt vlan are provided
			if mgmtvid ~= "" and mgmtvid ~= nil then

				x:delete("system", "ntp", "server")
				x:set("system", "ntp", "server", {"ntp1.rgw.telia.se","ntp2.rgw.telia.se"})
				x:commit("system")
				logger:notice("NTP configured for MVLAN config")
				os.execute("/etc/init.d/sysntpd restart")

				x:set("cwmpd", "cwmpd_config", "interface", "mgmt")
				x:set("cwmpd", "cwmpd_config", "acs_url", "https://acs.telia.com:7575/ACS-server/ACS")
				x:commit("cwmpd")

				x:set("dropbear", "wan", "enable", "0" )
				x:commit("dropbear")

				x:set("web", "remote", "interface", "mgmt")
				x:commit("web")

				dnsmasq(runtime)

				EnableDnsSet(runtime, "mgmt")

				x:set("mwan","acsreffileserv", "policy", "mgmt_only")
				x:set("mwan","acsrefloadb", "policy", "mgmt_only")
				x:set("mwan","acsprodloadb", "policy", "mgmt_only")
				x:set("mwan","tobenamed7", "policy", "mgmt_only")
				x:set("mwan","teliainternal1", "policy", "mgmt_only")
				x:set("mwan","teliainternal2", "policy", "mgmt_only")
				x:set("mwan","remoteassist", "policy", "mgmt_only")
				x:set("mwan","cwmpdhost", "policy", "mgmt_only")
				x:set("mwan","dropbearhost", "policy", "mgmt_only")
				x:commit("mwan")

				x:set("network", "mgmt", "ifname", "vlan_mgmt")
				x:set("network", "vlan_mgmt", "type", "8021q")
				x:set("network", "vlan_mgmt", "ifname", "eth4")
				x:set("network", "vlan_mgmt", "name", "vlan_mgmt")
				x:set("network", "vlan_mgmt", "vid", mgmtvid)
				x:set("network", "mgmt", "auto", "1")
				x:commit("network")

				os.execute("/etc/init.d/network reload")
				os.execute("/etc/init.d/mwan reload")
				os.execute("sleep 15")
				os.execute("/etc/init.d/dnsmasq reload")
				os.execute("/etc/init.d/nginx restart")
				os.execute("/etc/init.d/dropbear reload")
				os.execute("sed -i 'N;$!P;$!D;$d' /etc/config/watchdog")
				os.execute("/etc/init.d/watchdog-tch reload")
				os.execute("/etc/init.d/cwmpd restart")
				os.execute("cp /rom/etc/config/watchdog /etc/config/watchdog")
				os.execute("/etc/init.d/watchdog-tch reload")



			end

			-- Setup the iptv interface and all required routing and dns rules if a iptv vlan are provided
			if iptvvid ~= "" and iptvvid ~= nil then

				x:set("ledfw", "iptv", "itf" , "iptv")
				x:commit("ledfw")

				x:delete("igmpproxy", "wan")
				x:set("igmpproxy", "iptv", "interface")
				x:set("igmpproxy", "iptv", "state", "upstream")
				x:commit("igmpproxy")

				EnableDnsSet(runtime, "iptv")

				x:set("mwan","verimatrixse", "policy", "iptv_only")
				x:set("mwan","tobenamed1", "policy", "iptv_only")
				x:set("mwan","tobenamed2", "policy", "iptv_only")
				x:set("mwan","igloo1", "policy", "iptv_only")
				x:set("mwan","igloo2", "policy", "iptv_only")
				x:set("mwan","igloo3", "policy", "iptv_only")
				x:set("mwan","igloo4", "policy", "iptv_only")
				x:set("mwan","igloo5", "policy", "iptv_only")
				x:set("mwan","igloo6", "policy", "iptv_only")
				x:set("mwan","iptvprodlog", "policy", "iptv_only")
				x:set("mwan","iptvstats", "policy", "iptv_only")
				x:set("mwan","tobenamed3", "policy", "iptv_only")
				x:set("mwan","tobenamed4", "policy", "iptv_only")
				x:set("mwan","tobenamed5", "policy", "iptv_only")
				x:set("mwan","tobenamed6", "policy", "iptv_only")
				x:set("mwan","iptvsearchprod", "policy", "iptv_only")
				x:set("mwan","iptvsearchpilot", "policy", "iptv_only")
				x:set("mwan","iptvloginpilot", "policy", "iptv_only")
				x:set("mwan","iptvloginprod", "policy", "iptv_only")
				x:commit("mwan")

				x:set("network", "iptv", "ifname", "vlan_iptv")
				x:set("network", "vlan_iptv", "type", "8021q")
				x:set("network", "vlan_iptv", "ifname", "eth4")
				x:set("network", "vlan_iptv", "name", "vlan_iptv")
				x:set("network", "vlan_iptv", "vid", iptvvid)
				x:set("network", "iptv", "auto", "1")

				if iptvvid == "untagged" then
				x:set("network", "vlan_iptv", "type", "macvlan")

				x:delete("system", "ntp", "server")
				x:set("system", "ntp", "server", {"ntp-cust1.telia.com","ntp-cust2.telia.com"})
				x:commit("system")
				logger:notice("NTP configured for SVLAN config")
				os.execute("/etc/init.d/sysntpd restart")

				end

				x:commit("network")

				os.execute("/etc/init.d/igmpproxy restart")

			end

			-- Setup the voip interface and all required routing and dns rules if a voip vlan are provided
			if voipvid ~= "" and voipvid ~= nil then

				x:set("mmpbxrvsipnet", "sip_net", "interface", "voip")
				x:commit("mmpbxrvsipnet")

				dnsmasq(runtime)

				EnableDnsSet(runtime, "voip")

				x:set("mwan","mmpbxdhost", "policy", "voip_only")
				x:commit("mwan")

				x:set("network", "voip", "ifname", "vlan_voip")
				x:set("network", "vlan_voip", "type", "8021q")
				x:set("network", "vlan_voip", "ifname", "eth4")
				x:set("network", "vlan_voip", "name", "vlan_voip")
				x:set("network", "vlan_voip", "vid", voipvid)
				x:set("network", "voip", "auto", "1")
				x:commit("network")

				os.execute("/etc/init.d/mmpbxd restart")

			end

				os.execute("/etc/init.d/network reload")
				os.execute("/etc/init.d/mwan reload")
				os.execute("/etc/init.d/dnsmasq reload")

		end
      return
   end
   return
end

return M
