local M = {}

-- Update the list of wan interfaces
--   1. remove "eth4", "vlan_data" and "atm_wan" from the wan interface list
--   2. add a new wan interface into the list
--
--   currifname: current interface list
--   wanifname: the wan interface to be added inside the list
local function update_ifname(currifname, wanifname)
   local new_intf
   if currifname == nil then
      return wanifname
   end

   new_intf = currifname
   if type(new_intf) == "string" then
      -- remove "eth4", "vlan_data" and "atm_wan"
      new_intf = new_intf:gsub("eth4", "")
      new_intf = new_intf:gsub("vlan_data", "")
      new_intf = new_intf:gsub("atm_wan", "")
      new_intf = new_intf:gsub("^%s*(.-)%s*$", "%1")
      -- add new wan interface
      new_intf = (new_intf == "" and wanifname) or new_intf .. " " .. wanifname
   else
      for key,itr in pairs(new_intf) do
         if itr == "eth4" or itr == "vlan_data" or itr == "atm_wan"then
            new_intf[key] = nil
         end
      end
      table.insert(new_intf, wanifname)
      end
   return new_intf
end

function M.entry(runtime)
   -- DO nothing
   return true
end

local function dnsmasq(runtime)
   local uci = runtime.uci
   local conn = runtime.ubus
   local x = uci.cursor()
   local logger = runtime.logger

   if runtime.cur_deployment == "SWDefault" then
      x:set("dhcp", "dnsmasq", "rebind_protection", "1")
      x:commit("dhcp")
      logger:notice("Rebind protection enabled")
   else
      x:set("dhcp", "dnsmasq", "rebind_protection", "0")
      x:commit("dhcp")
      logger:notice("Rebind protection disabled")
   end

end

-- DisableDnsSet
-- @param runtime the runtime environment
-- @param intf the interface name
local function DisableDnsSet(runtime, intf)
    local changed = false
    local uci = runtime.uci
    local x = uci:cursor()
    local logger = runtime.logger

    logger:notice("Disabling DNS set for interface:")
    logger:notice(intf)

    x:foreach("dhcp", "dnsrule", function(s)
        if s["dnsset"] == intf and s["enable"] ~= "0" then
            changed=true
            x:set("dhcp", s[".name"], "enable", "0")
        end
    end
    )
    if changed then
        x:commit("dhcp")
        os.execute("/etc/init.d/dnsmasq restart")
        runtime.logger:warning("Dns Rules disabled for intf: " .. intf)
    end
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
        os.execute("/etc/init.d/dnsmasq restart")
        runtime.logger:warning("Dns Rules enabled for intf: " .. intf)
    end
end

local function EnableDnsRules(runtime)
   -- reconfig dhcp
   EnableDnsSet(runtime, "iptv")
   EnableDnsSet(runtime, "voip")
   EnableDnsSet(runtime, "mgmt")
end

--Run a command
local function run_command(runtime,s)
   runtime.logger:info(s)
   os.execute(s)
end

-- Dec2Hex 1byte and pad with leading zeros up to 2 characters
local function gethex_8(dec_input)
   local zero_padded_hex_string

   zero_padded_hex_string = string.format( "%02x", tonumber(dec_input) )
   return zero_padded_hex_string
end

-- Dec2Hex 4byte and pad with leading zeros up to 8 characters
local function gethex_32(dec_input)
   local zero_padded_hex_string

   zero_padded_hex_string = string.format( "%08x", tonumber(dec_input) )
   return zero_padded_hex_string
end

-- String2Hex
function gethex_string(str)
    local len = string.len( str )
    local hex = ""

    for i = 1, len do
        hex = hex .. string.format( "%02x", string.byte( str, i ) )
    end
    return hex
end

--Craft DHCP TX Option 125 as specified in RFC3925 with following by Telia requirements:
--Enterprise:2234 (Telia)
--Sub Option 1: ID
--Sub Option 2: CPE HW
--Sub Option 3: CPE SW
--Sub Option 4: CPE Serial
--Sub Option 5: CPE Access
--Sub Option 6: CPE L3 Interface
--Sub Option 7: CPE L2 Interface
local function get_vendor_option_data(enterprise, id, hw, sw, serial, l2type, l3intf, l2intf)
   local vopt_subopts = gethex_8(1) .. gethex_8(string.len(id)) .. gethex_string(id) ..
                        gethex_8(2) .. gethex_8(string.len(hw)) .. gethex_string(hw) ..
                        gethex_8(3) .. gethex_8(string.len(sw)) .. gethex_string(sw) ..
                        gethex_8(4) .. gethex_8(string.len(serial)) .. gethex_string(serial) ..
                        gethex_8(5) .. gethex_8(string.len(l2type)) .. gethex_string(l2type) ..
                        gethex_8(6) .. gethex_8(string.len(l3intf)) .. gethex_string(l3intf) ..
                        gethex_8(7) .. gethex_8(string.len(l2intf)) .. gethex_string(l2intf)
   local vopt = gethex_32(enterprise) .. gethex_8(string.len(vopt_subopts)/2) .. vopt_subopts
   local output = "0x" .. gethex_8(124) ..":" .. vopt
   return output
end

function get_core_version(full_version)
   local core_version=nil
   --digits punctuation(.) digits punctuation(.) digits/dev - digits
   core_version=string.match(full_version, "^%d+%p%d+%p[%d%a]+%-%d+")
   if core_version==nil then
      core_version="Undefined"
   end
   return core_version
end

local function ntp(runtime)
   local uci = runtime.uci
   local conn = runtime.ubus
   local x = uci.cursor()
   local logger = runtime.logger

   x:delete("system", "ntp", "server")

   if runtime.cur_deployment == "SWDefault" then
      x:set("system", "ntp", "server", {"ntp-cust1.telia.com","ntp-cust2.telia.com"})
      x:commit("system")
      logger:notice("NTP configured for SVLAN config")
   else
      x:set("system", "ntp", "server", {"ntp1.rgw.telia.se","ntp2.rgw.telia.se"})
      x:commit("system")
      logger:notice("NTP configured for MVLAN config")
   end
   os.execute("/etc/init.d/sysntpd restart")
end

function M.exit(runtime, l2type)
   local uci = runtime.uci
   local conn = runtime.ubus
   local x = uci.cursor()
   local opt125 = x:get("wansensing", "deployment", "opt125")
   if not uci or not conn then
      return false
   end


   local prevL2 = x:get("wansensing", "global", "l2type")
   local confg_dsl = x:get("wansensing", "deployment", "configured_DSL_Network")
   local logger = runtime.logger

   -- do nothing if sensed l2type is not changed
   if l2type == "ETH" then
       if prevL2 == l2type and opt125 ~= "2" then
           logger:notice("No reconfig required for "..l2type)
       return true
       else
           logger:notice("Reconfig required for "..l2type)
       end
   elseif l2type == "ADSL" or  l2type == "VDSL" then
       if prevL2 == l2type and confg_dsl == "1" then
           logger:notice("No reconfig required for "..l2type)
       return true
       else
           logger:notice("Reconfig required for "..l2type)
       end
    end

   local current_wanifs = x:get("network", "wan", "ifname")
   if l2type == "ETH" then

        x:commit("wansensing")
		logger:notice("L2type ETH selected")
		if opt125 == "1" then
			logger:notice("ETH L2 reconfig will be skipped because option 125 was already received and configured")
			return true
		end

		runtime.cur_deployment = "SWDefault"


		x:set("cwmpd", "cwmpd_config", "interface", "wan")
		x:set("cwmpd", "cwmpd_config", "acs_url", "https://rgw.teliacompany.com:7575/ACS-server/ACS")
		x:commit("cwmpd")

		local ledfw = x:get("ledfw", "iptv", "itf")
		if ledfw ~= "wan" then
		x:set("ledfw", "iptv", "itf" , "wan")
		x:commit("ledfw")
--		os.execute("/etc/init.d/ledfw reload")
		end

		x:set("mmpbxrvsipnet", "sip_net", "interface", "wan")
		x:commit("mmpbxrvsipnet")

		x:set("dropbear", "wan", "enable", "1" )
		x:commit("dropbear")

		x:set("web", "remote", "interface", "wan")
		x:commit("web")

		x:delete("igmpproxy", "iptv")
		x:set("igmpproxy", "wan", "interface")
		x:set("igmpproxy", "wan", "state", "upstream")
		x:commit("igmpproxy")

		dnsmasq(runtime)

		DisableDnsSet(runtime, "iptv")
		DisableDnsSet(runtime, "voip")
		DisableDnsSet(runtime, "mgmt")

		ntp(runtime)

		x:set("mwan","verimatrixse", "policy", "main_only")
		x:set("mwan","tobenamed1", "policy", "main_only")
		x:set("mwan","tobenamed2", "policy", "main_only")
		x:set("mwan","igloo1", "policy", "main_only")
		x:set("mwan","igloo2", "policy", "main_only")
		x:set("mwan","igloo3", "policy", "main_only")
		x:set("mwan","igloo4", "policy", "main_only")
		x:set("mwan","igloo5", "policy", "main_only")
		x:set("mwan","igloo6", "policy", "main_only")
		x:set("mwan","iptvprodlog", "policy", "main_only")
		x:set("mwan","iptvstats", "policy", "main_only")
		x:set("mwan","tobenamed3", "policy", "main_only")
		x:set("mwan","tobenamed4", "policy", "main_only")
		x:set("mwan","tobenamed5", "policy", "main_only")
		x:set("mwan","tobenamed6", "policy", "main_only")
		x:set("mwan","iptvsearchprod", "policy", "main_only")
		x:set("mwan","iptvsearchpilot", "policy", "main_only")
		x:set("mwan","iptvloginpilot", "policy", "main_only")
		x:set("mwan","iptvloginprod", "policy", "main_only")
		x:set("mwan","iptvapipilot", "policy", "main_only")
		x:set("mwan","iptvapiprod", "policy", "main_only")
		x:set("mwan","acsreffileserv", "policy", "main_only")
		x:set("mwan","acsrefloadb", "policy", "main_only")
		x:set("mwan","acsprodloadb", "policy", "mgmt_only")
		x:set("mwan","tobenamed7", "policy", "main_only")
		x:set("mwan","teliainternal1", "policy", "main_only")
		x:set("mwan","teliainternal2", "policy", "main_only")
		x:set("mwan","remoteassist", "policy", "main_only")
		x:set("mwan","cwmpdhost", "policy", "main_only")
		x:set("mwan","dropbearhost", "policy", "main_only")
		x:commit("mwan")

		x:set("network", "wan", "ifname", update_ifname(current_wanifs, "eth4"))
		x:delete("network", "vlan_data", "type")
		x:delete("network", "vlan_data", "vid")
		x:delete("network", "vlan_data", "ifname")
		x:set("network", "vlan_data", "name","phy_eth4")

      local mnemonic = x:get("env", "rip", "board_mnemonic")
      local version = x:get("env", "var", "friendly_sw_version_activebank")
      local core_version = get_core_version(version)
      local serial = x:get("env", "var", "serial")
      local l2intf = x:get("network", "wan", "ifname")

      x:set("network", "wan", "sendopts", get_vendor_option_data("2234", "RGW-wan-config", mnemonic, core_version, serial, l2type, "wan", "eth4"))

		x:set("network", "wan", "auto", "1")
		x:set("network", "iptv", "auto", "0")
		x:set("network", "voip", "auto", "0")
		x:set("network", "mgmt", "auto", "0")
		x:commit("network")
		x:set("wansensing", "deployment", "configured_DSL_Network" ,"0" )
		x:set("wansensing", "deployment", "opt125", "0")
		x:set("wansensing", "deployment", "mode" , "SingleWAN" )
		x:set("wansensing", "deployment", "mgmtService" , "wan" )
		x:set("wansensing", "deployment", "iptvService" , "wan" )
		x:set("wansensing", "deployment", "voipService" , "wan" )
		x:commit("wansensing")

	elseif l2type == "VDSL" then
        runtime.cur_deployment = "VDSL"
        -- Start the network config of VDSL set configured_DSL_Network to 0 which means not configured
        x:set("wansensing", "deployment", "configured_DSL_Network" ,"0" )
        x:set("wansensing", "deployment", "opt125", "0")
        x:commit("wansensing")
        logger:notice("Start the network config of "..l2type.." and set configured_DSL_Network to 0 = not configured")

		x:set("cwmpd", "cwmpd_config", "interface", "mgmt")
		x:set("cwmpd", "cwmpd_config", "acs_url", "https://acs.telia.com:7575/ACS-server/ACS")
		x:commit("cwmpd")

		x:set("ledfw", "iptv", "itf" , "iptv")
		x:commit("ledfw")
--		os.execute("/etc/init.d/ledfw reload")

		x:set("mmpbxrvsipnet", "sip_net", "interface", "voip")
		x:commit("mmpbxrvsipnet")

		x:set("dropbear", "wan", "enable", "0" )
		x:commit("dropbear")

		x:set("web", "remote", "interface", "mgmt")
		x:commit("web")

		x:delete("igmpproxy", "wan")
		x:set("igmpproxy", "iptv", "interface")
		x:set("igmpproxy", "iptv", "state", "upstream")
		x:commit("igmpproxy")

		dnsmasq(runtime)

		EnableDnsRules(runtime)

		ntp(runtime)

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
		x:set("mwan","iptvapipilot", "policy", "iptv_only")
		x:set("mwan","iptvapiprod", "policy", "iptv_only")
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

		x:set("network", "wan", "ifname", update_ifname(current_wanifs, "vlan_data"))

		x:set("network", "vlan_data", "type", "8021q")
		x:set("network", "vlan_data", "vid", "835")
		x:set("network", "vlan_data", "ifname", "ptm0")
		x:set("network", "vlan_data", "name","vlan_data")

		x:set("network", "iptv", "ifname", "vlan_iptv")
		x:set("network", "vlan_iptv", "type", "8021q")
		x:set("network", "vlan_iptv", "ifname", "ptm0")
		x:set("network", "vlan_iptv", "name", "vlan_iptv")
		x:set("network", "vlan_iptv", "vid", "845")

		x:set("network", "voip", "ifname", "vlan_voip")
		x:set("network", "vlan_voip", "type", "8021q")
		x:set("network", "vlan_voip", "ifname", "ptm0")
		x:set("network", "vlan_voip", "name", "vlan_voip")
		x:set("network", "vlan_voip", "vid", "855")

		x:set("network", "mgmt", "ifname", "vlan_mgmt")
		x:set("network", "vlan_mgmt", "type", "8021q")
		x:set("network", "vlan_mgmt", "ifname", "ptm0")
		x:set("network", "vlan_mgmt", "name", "vlan_mgmt")
		x:set("network", "vlan_mgmt", "vid", "834")

		x:set("xtm","ptm0", "ptmdevice")
		x:set("xtm","ptm0", "path","fast")
		x:set("xtm","ptm0", "priority","low")
		x:commit("xtm")
		os.execute("/etc/init.d/xtm reload")

		x:set("network", "wan", "auto", "1")
		x:set("network", "iptv", "auto", "1")
		x:set("network", "voip", "auto", "1")
		x:set("network", "mgmt", "auto", "1")
		x:commit("network")
	    x:set("wansensing", "deployment", "mode" , "MultiWAN" )
		x:set("wansensing", "deployment", "mgmtService" , "mgmt" )
		x:set("wansensing", "deployment", "iptvService" , "iptv" )
		x:set("wansensing", "deployment", "voipService" , "voip" )
		x:set("wansensing", "deployment", "configured_DSL_Network" ,"1" )
        x:commit("wansensing")
        -- Finished the network config of VDSL set configured_DSL_Network to 1 which means comepleted
        logger:notice("Finished the network config of "..l2type.." and set configured_DSL_Network to 1 = Configured")
		
   elseif l2type == "ADSL" then

		runtime.cur_deployment = "ADSL"
        -- Start the network config of ADSL set ADSL-config to 0 which means not configured
		x:set("wansensing", "deployment", "configured_DSL_Network" ,"0" )
		x:set("wansensing", "deployment", "opt125" ,"0" )
        x:commit("wansensing")
        logger:notice("Start the network config of "..l2type.." and set configured_DSL_Network to 0 = not configured")

		x:set("cwmpd", "cwmpd_config", "interface", "mgmt")
		x:set("cwmpd", "cwmpd_config", "acs_url", "https://acs.telia.com:7575/ACS-server/ACS")
		x:commit("cwmpd")

		x:set("ledfw", "iptv", "itf" , "iptv")
		x:commit("ledfw")
--		os.execute("/etc/init.d/ledfw reload")

		x:set("mmpbxrvsipnet", "sip_net", "interface", "voip")
		x:commit("mmpbxrvsipnet")

		x:set("dropbear", "wan", "enable", "0" )
		x:commit("dropbear")

		x:set("web", "remote", "interface", "mgmt")
		x:commit("web")

		x:delete("igmpproxy", "wan")
		x:set("igmpproxy", "iptv", "interface")
		x:set("igmpproxy", "iptv", "state", "upstream")
		x:commit("igmpproxy")

		dnsmasq(runtime)

		EnableDnsRules(runtime)

		ntp(runtime)

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
		x:set("mwan","iptvapipilot", "policy", "iptv_only")
		x:set("mwan","iptvapiprod", "policy", "iptv_only")
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

		x:set("network", "wan", "ifname", update_ifname(current_wanifs, "atm_wan"))
		x:set("network", "vlan_data", "name","atm_wan")
		x:delete("network", "vlan_data", "type")
		x:delete("network", "vlan_data", "ifname")

		x:set("network", "iptv", "ifname", "atm_iptv")
		x:set("network", "vlan_iptv", "name","atm_iptv")
		x:delete("network", "vlan_iptv", "type")
		x:delete("network", "vlan_iptv", "ifname")

		x:set("network", "voip", "ifname", "atm_voip")
		x:set("network", "vlan_voip", "name","atm_voip")
		x:delete("network", "vlan_voip", "type")
		x:delete("network", "vlan_voip", "ifname")

		x:set("network", "mgmt", "ifname", "atm_mgmt")
		x:set("network", "vlan_mgmt", "name","atm_mgmt")
		x:delete("network", "vlan_mgmt", "type")
		x:delete("network", "vlan_mgmt", "ifname")

		x:delete("xtm", "ptm0")
		x:commit("xtm")
		os.execute("/etc/init.d/xtm reload")

		x:set("network", "wan", "auto", "1")
		x:set("network", "iptv", "auto", "1")
		x:set("network", "voip", "auto", "1")
		x:set("network", "mgmt", "auto", "1")
		x:commit("network")
		x:set("wansensing", "deployment", "mode" , "MultiWAN" )
		x:set("wansensing", "deployment", "mgmtService" , "mgmt" )
		x:set("wansensing", "deployment", "iptvService" , "iptv" )
		x:set("wansensing", "deployment", "voipService" , "voip" )
		x:set("wansensing", "deployment", "configured_DSL_Network" , "1" )
		x:commit("wansensing")
        -- Finished the network config of ADSL set configured_DSL_Network to 1 which means comepleted
        logger:notice("Finished the network config of "..l2type.." and set configured_DSL_Network to 1 = Configured")

	end
	logger:notice("OS execute to reload daemons")
	os.execute("/etc/init.d/network reload")
	os.execute("/etc/init.d/mwan reload")
	os.execute("sleep 15")
	os.execute("/etc/init.d/dnsmasq reload")
	os.execute("/etc/init.d/mmpbxd restart")
	os.execute("/etc/init.d/nginx restart")
	os.execute("/etc/init.d/igmpproxy restart")
	os.execute("/etc/init.d/dropbear reload")
	os.execute("sed -i 'N;$!P;$!D;$d' /etc/config/watchdog")
	os.execute("/etc/init.d/watchdog-tch reload")
	os.execute("/etc/init.d/cwmpd restart")
	os.execute("cp /rom/etc/config/watchdog /etc/config/watchdog")
	os.execute("/etc/init.d/watchdog-tch reload")

	return true
end

return M

