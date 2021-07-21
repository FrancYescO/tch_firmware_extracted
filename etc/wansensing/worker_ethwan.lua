---
-- Module Worker.
-- Module Specifies actions triggered by events
-- @module modulename
local M = {}
-- Advanced Event Registration (availabe for version >= 1.0)
--
--   List of events can be changed during runtime
--   By default NOT registered for 'timeout' event
--   Support implemented for :
--       a) network interface updates coded as `network_interface_xxx_yyy` (xxx= OpenWRT interface name, yyy = ifup/ifdown)
--           network_interface_xxx_up:
--                   event is used to flag the logical OpenWRT interface changed state from down to up
--                   event is used to flag address/route/data updates on this OpenWRT interface
--           network interface_xxx_down:
--                   event is used to flag the logical OpenWRT interface changed state from up to down
--       b) dslevents
--                   xdsl_0(=AdslTrainingIdle, idle)
--                   xdsl_1(=AdslTrainingG994)
--                   xdsl_2(=AdslTrainingG992Started)
--                   xdsl_3(=AdslTrainingG992ChanAnalysis)
--                   xdsl_4(=AdslTrainingG992Exchange)
--                   xdsl_5(=AdslTrainingConnected, showtime)
--                   xdsl_6(=AdslTrainingG993Started)
--                   xdsl_7(=AdslTrainingG993ChanAnalysis)
--                   xdsl_8(=AdslTrainingG993Exchange)
--       c) network device state changes coded as 'network_device_xxx_yyy' (xxx = linux netdev, yyy = up/down)
--       d) add/delete events raised by the neighbour daemon
--            scripthelper function available to create the event strings,see 'scripthelpers.formatNetworkNeighborEventName(l2intf,add,neighbour)'
--       e) start event which is raised to indicate the worker needs to start.
--
-- @SenseEventSet [parent=#M] #table SenseEventSet
M.SenseEventSet = {
-- Worker only needed in case L2 ETH    ['start'] = true,
    ['network_interface_wan_ifup'] = true,
    ['network_interface_wan_ifdown'] = true,
    ['network_interface_voip_ifup'] = true,
    ['network_interface_voip_ifdown'] = true,
    ['check_network_ethwan'] = true,
--    ['network_device_eth4_up'] = true,
}
local timer_ppp

local check_tmrval
local LTE_Data_VID
local LTE_VoIP_VID
local Standard_Data_VID


local function Toggle_ACS(runtime,New_Scenario)
-- Setting ACS (cwmpd) part	TCOMITAGW-2537
    local conn = runtime.ubus
    local logger = runtime.logger
    local uci = runtime.uci
    local x = uci.cursor()

-- Setting ACS (cwmpd) part	TCOMITAGW-2537
-- get actual cwmp-config of 2Box Scenario
	local oper_acs_url = x:get("cwmpd", "cwmpd_config", "acs_url")
	local oper_acs_user = x:get("cwmpd", "cwmpd_config", "acs_user")
	local oper_acs_pass = x:get("cwmpd", "cwmpd_config", "acs_pass")
	local oper_connectionrequest_username = x:get("cwmpd", "cwmpd_config", "connectionrequest_username")
	local oper_acs_connectionrequest_password = x:get("cwmpd", "cwmpd_config", "connectionrequest_password")
	local oper_acs_periodicinform_enable = x:get("cwmpd", "cwmpd_config", "periodicinform_enable")
	local oper_acs_periodicinform_interval = x:get("cwmpd", "cwmpd_config", "periodicinform_interval")
	local oper_acs_ssl_certificate = x:get("cwmpd", "cwmpd_config", "ssl_certificate")
	local oper_acs_ssl_privatekey = x:get("cwmpd", "cwmpd_config", "ssl_privatekey")

	if New_Scenario == 0 then
-- store retreived operational cwmpd data to the storage parameters
		x:set("cwmpd", "operationalACS2", "acs_url", oper_acs_url)
		x:set("cwmpd", "operationalACS2", "acs_user", oper_acs_user)
		x:set("cwmpd", "operationalACS2", "acs_pass", oper_acs_pass)
		x:set("cwmpd", "operationalACS2", "connectionrequest_username", oper_connectionrequest_username)
		x:set("cwmpd", "operationalACS2", "connectionrequest_password", oper_acs_connectionrequest_password)
		x:set("cwmpd", "operationalACS2", "periodicinform_enable", oper_acs_periodicinform_enable)
		x:set("cwmpd", "operationalACS2", "periodicinform_interval", oper_acs_periodicinform_interval)
		x:set("cwmpd", "operationalACS2", "ssl_certificate", oper_acs_ssl_certificate)
		x:set("cwmpd", "operationalACS2", "ssl_privatekey", oper_acs_ssl_privatekey)

-- get the previous stored operational config
		oper_acs_url = x:get("cwmpd", "operationalACS1", "acs_url")
		oper_acs_user = x:get("cwmpd", "operationalACS1", "acs_user")
		oper_acs_pass = x:get("cwmpd", "operationalACS1", "acs_pass")
		oper_connectionrequest_username = x:get("cwmpd", "operationalACS1", "connectionrequest_username")
		oper_acs_connectionrequest_password = x:get("cwmpd", "operationalACS1", "connectionrequest_password")
		oper_acs_periodicinform_enable = x:get("cwmpd", "operationalACS1", "periodicinform_enable")
		oper_acs_periodicinform_interval = x:get("cwmpd", "operationalACS1", "periodicinform_interval")
		oper_acs_ssl_certificate = x:get("cwmpd", "operationalACS1", "ssl_certificate")
		oper_acs_ssl_privatekey = x:get("cwmpd", "operationalACS1", "ssl_privatekey")
	else
-- store retreived operational cwmpd data to the storage parameters
		x:set("cwmpd", "operationalACS1", "acs_url", oper_acs_url)
		x:set("cwmpd", "operationalACS1", "acs_user", oper_acs_user)
		x:set("cwmpd", "operationalACS1", "acs_pass", oper_acs_pass)
		x:set("cwmpd", "operationalACS1", "connectionrequest_username", oper_connectionrequest_username)
		x:set("cwmpd", "operationalACS1", "connectionrequest_password", oper_acs_connectionrequest_password)
		x:set("cwmpd", "operationalACS1", "periodicinform_enable", oper_acs_periodicinform_enable)
		x:set("cwmpd", "operationalACS1", "periodicinform_interval", oper_acs_periodicinform_interval)
		x:set("cwmpd", "operationalACS1", "ssl_certificate", oper_acs_ssl_certificate)
		x:set("cwmpd", "operationalACS1", "ssl_privatekey", oper_acs_ssl_privatekey)

-- get the previous stored operational config
		oper_acs_url = x:get("cwmpd", "operationalACS2", "acs_url")
		oper_acs_user = x:get("cwmpd", "operationalACS2", "acs_user")
		oper_acs_pass = x:get("cwmpd", "operationalACS2", "acs_pass")
		oper_connectionrequest_username = x:get("cwmpd", "operationalACS2", "connectionrequest_username")
		oper_acs_connectionrequest_password = x:get("cwmpd", "operationalACS2", "connectionrequest_password")
		oper_acs_periodicinform_enable = x:get("cwmpd", "operationalACS2", "periodicinform_enable")
		oper_acs_periodicinform_interval = x:get("cwmpd", "operationalACS2", "periodicinform_interval")
		oper_acs_ssl_certificate = x:get("cwmpd", "operationalACS2", "ssl_certificate")
		oper_acs_ssl_privatekey = x:get("cwmpd", "operationalACS2", "ssl_privatekey")
	end

	x:commit ("cwmpd")
	os.execute("/etc/init.d/cwmpd reload")
end

--Change ethwan based Network Scenario
local function Set_Standard_Scenario(runtime)
-- This function will only be called, in case the 2-Interface scenario is active, while the WAN AND the VoIP Interface is down down
    local conn = runtime.ubus
    local logger = runtime.logger
    local uci = runtime.uci
    local x = uci.cursor()
--Test
local proxy = require("datamodel")

-- In first Instance, the actual VID for LTE-Data and LTE-VoIP will be stored to the env-Variables to assue, that the latest values
-- are stored, which might have been changed via ACS etc during life time compared to factory Default values

	local LTE_Data_VID = x:get("network", "waneth4", "vid")
	local LTE_VoIP_VID = x:get("network", "voipeth4", "vid")
	x:set("env", "custovar_network", "LTE_Data", LTE_Data_VID)
	x:set("env", "custovar_network", "LTE_VoIP", LTE_VoIP_VID)

	x:set("env", "custovar_sensing", "Scenario", "0")

	x:set("network", "voipeth4", "enabled", "0")
	x:set("network", "voipeth4", "vid", "")
	x:set("network", "voip", "auto", "0")
	x:set("network", "voip", "ifname", "")
	x:set("mwan", "if1_mwan", "interface", "wan")
	x:set("mmpbxrvsipnet", "sip_net", "interface", "wan")
-- Setting Data-part
-- Saving the standard Data-Vid to the variable, to assure possible changes during lifetime compared to factory default
	local Standard_Data_VID = x:get("env", "custovar_network", "Standard_EthData")
	x:set("network", "waneth4", "vid", Standard_Data_VID)
	x:delete("network", "waneth4", "mtu")
	x:set("network", "wan", "proto", "pppoe")

	x:set("dhcp", "dnsmasq", "rebind_protection", "1")


-- Setting ACS (cwmpd) part	TCOMITAGW-2537

	Toggle_ACS(runtime,0)


-- Setting NTP-Server Part
--	x:delete("system", "ntp", "server")
--	x:add_list("system", "ntp", "server", "ntp-tr069-1.interbusiness.it")
--	x:add_list("system", "ntp", "server", "ntp-tr069-2.interbusiness.it")
--	x:add_list("system", "ntp", "server", "ntp1.inrim.it")

	proxy.del("uci.system.ntp.server.")


	proxy.add("uci.system.ntp.server.")
	proxy.set("uci.system.ntp.server.@1.value","ntp-tr069-1.interbusiness.it")
	proxy.add("uci.system.ntp.server.")
	proxy.set("uci.system.ntp.server.@2.value","ntp-tr069-2.interbusiness.it")
	proxy.add("uci.system.ntp.server.")
	proxy.set("uci.system.ntp.server.@3.value","ntp1.inrim.it")

    x:commit("env")
    x:commit("mmpbxrvsipnet")
    x:commit("mwan")
    x:commit("network")
	x:commit("dhcp")
--	x:commit ("cwmpd")
	x:commit ("system")

-- this reload + up of wan will reload mwan rules too
	conn:call("network", "reload", { })
-- the following reloads are not supported by ubus call, so os.execute used

	os.execute("/etc/init.d/mwan reload")
	os.execute("/etc/init.d/mmpbxd reload")
	os.execute("/etc/init.d/dnsmasq reload")
--	os.execute("/etc/init.d/cwmpd reload")
	os.execute("/etc/init.d/system reload")

end




--Change ethwan based Network Scenario
local function Network_toggle(runtime)
    local conn = runtime.ubus
    local logger = runtime.logger
    local uci = runtime.uci
    local x = uci.cursor()

--Test
local proxy = require("datamodel")

--	local LTE_Data_VID
--	local LTE_VoIP_VID
--	local Standard_Data_VID


-- # Scenario: 0 Standard; 1: LTE 2 Box
    local curr_Scenario = x:get("env", "custovar_sensing", "Scenario")
    if curr_Scenario == "0" then
		logger:warning("ETH WAN Scenario changing to LTE 2 Box")
		x:set("env", "custovar_sensing", "Scenario", "1")
-- Setting Voip - part
		local LTE_VoIP_VID = x:get("env", "custovar_network", "LTE_VoIP") or "UNKNOWN"

logger:warning("FRS --  LTE-VoIP-VID as stored in custo-var: " .. LTE_VoIP_VID)

		x:set("network", "voipeth4", "enabled", "1")
		x:set("network", "voipeth4", "vid", LTE_VoIP_VID)
		x:set("network", "voip", "auto", "1")
		x:set("network", "voip", "ifname", "voipeth4")
		x:set("mwan", "if1_mwan", "interface", "voip")
		x:set("mmpbxrvsipnet", "sip_net", "interface", "voip")
-- Setting Data-part
-- Saving the standard Data-Vid to the variable, to assure possible changes during lifetime compared to factory default
		local LTE_Data_VID = x:get("env", "custovar_network", "LTE_Data")
		local Standard_Data_VID = x:get("network", "waneth4", "vid")
		x:set("env", "custovar_network", "Standard_EthData", Standard_Data_VID)
		x:set("network", "waneth4", "vid", LTE_Data_VID)
		x:set("network", "waneth4", "mtu", '1400')
		x:set("network", "wan", "proto", "dhcp")

		x:set("dhcp", "dnsmasq", "rebind_protection", "0")


-- setting ACS (cwmpd) Part (only factory Default settings will be used)

-- Setting ACS (cwmpd) part	TCOMITAGW-2537

	Toggle_ACS(runtime,1)

-- setting NTP-Part
--		x:delete("system", "ntp", "server")
--		x:add_list("system", "ntp", "server", "time.fwa.tim.it")

--Test

		proxy.del("uci.system.ntp.server.")


		proxy.add("uci.system.ntp.server.")
		proxy.set("uci.system.ntp.server.@1.value","time.fwa.tim.it")

		x:commit("env")
		x:commit("mmpbxrvsipnet")
		x:commit("mwan")
		x:commit("network")
		x:commit("dhcp")
--		x:commit ("cwmpd")
		x:commit ("system")

-- this reload + up of wan will reload mwan rules too
		conn:call("network", "reload", { })
-- the following reloads are not supported by ubus call, so os.execute used
		os.execute("/etc/init.d/mwan reload")
		os.execute("/etc/init.d/mmpbxd reload")
		os.execute("/etc/init.d/dnsmasq reload")
--		os.execute("/etc/init.d/cwmpd reload")
		os.execute("/etc/init.d/system reload")

    else
		logger:warning("ETH WAN Scenario changing to Standard 1 Interface Scenario")
		Set_Standard_Scenario(runtime)
    end


end


---
-- Main function called to indicate an event happened.
--
-- @function [parent=M]
-- @param #1 runtime table holding the wansensing context (async/ubus/uci/logger/scripthelper)
-- @param #2 specifies the event which triggered this check method call (eg. start, network_interface_voip_ifup, network_interface_voip_ifdown)
function M.check(runtime, event)

   if runtime.timer_ppp_eth then
      timer_ppp_eth = runtime.timer_ppp_eth
   end
   local scripthelpers = runtime.scripth
   local conn = runtime.ubus
   local logger = runtime.logger
   local uci = runtime.uci
   local x = uci.cursor()

logger:warning("FRS -- Event : " .. event)

   local eth4phy = scripthelpers.l2HasCarrier("eth4")

-- In case env variable not esisting, it will take value "0", which repesents standard
   local Scenario = x:get("env", "custovar_sensing", "Scenario") or "UNKNOWN"

logger:warning("FRS Scenario : " .. Scenario)

   check_tmrval = tonumber(x:get("wansensing", "worker1", "toggle_time") or 30)

	local ifwanstatus = conn:call("network.interface.wan", "status", {})
	local ifwanup = ifwanstatus["up"] or "false"
	local ifvoipstatus = conn:call("network.interface.voip", "status", {})
	local ifvoipup = ifvoipstatus["up"] or "false"

	local current = x:get("wansensing", "global", "l2type")
logger:notice("FRS -- WORKER Current Mode " .. current)


--	if event == "start" then
-- Since Helper is constantly running, this start event represets the starting of Wansesning
-- Normally this should only assure that at beginning of WAN sesning the Helper is really started
--		logger:warning("FRS -- Actions in case of event start")

-- STill needs to be tested in whole Scenario, mainly now for testing, since ifwanup and ifdown not used at this stage
-- more functionality from th eentry/exit screeps need to be added here possibly
-- In reality, it must be fired already in the standard Sensing scripts, also there a Flapping for the ppp timer needs to be set asw well, pulling cable

--		local dummy = 123456789


	if event == "check_network_ethwan" and Scenario == "0" and eth4phy and ifwanup == "false"  then
		logger:warning("Checking on Standard Scenario if status of ethwan has changed")
		timer_ppp = nil
		local ppplast

--!!!!!! STILL NEEDS TO BE EXTENDED FOR SFP-Case !!!!!!!!!!!!
-- Since the WAN protocol is changed between the 2 ETH-WAN Scenarios, only if up is needed to be looked at to trigger the toggling

		Network_toggle(runtime)
-- this will call define the new event and will trigger the event after the defined timeout
		timer_ppp_eth = scripthelpers.fire_timed_event("check_network_ethwan", check_tmrval, 1)

	elseif event == "check_network_ethwan" and Scenario == "1" and eth4phy and ifwanup == "false" then
		logger:warning("Checking on 2 Box Scenario if status of ethwan has changed")
		timer_ppp = nil
		local ppplast

--!!!!!! STILL NEEDS TO BE EXTENDED FOR SFP-Case !!!!!!!!!!!!
--!!!!!!  STILL to be modified, that toggling shall only be done, if WAN and VoIP Interface down in case of Scenario 1 to take the situation into consideration,
--!!!!!   that due to 	whatever reason only the Data is down
-- since still in connecting mode, toggling will be initiated
		Network_toggle(runtime)
		timer_ppp_eth = scripthelpers.fire_timed_event("check_network_ethwan", check_tmrval, 1)

-- Needs to be checked with TIM Sensing
	elseif eth4phy and event == "network_interface_wan_ifup" or event == "network_interface_voip_ifup" then
-- if one of the 2 Interfaces is coming up in ethernetWAN mode, we know that we are in the correct Scenario and the fired timed event for triggering
-- the toggling can be stopped

logger:warning("FRS -- Actions in case one Interface is up in eth mode")

--!!!!!! STILL NEEDS TO BE EXTENDED FOR SFP-Case !!!!!!!!!!!!

		if runtime.timer_ppp_eth then
			timer_ppp_eth = runtime.timer_ppp_eth
			timer_ppp_eth:stop()
		end
		return
	elseif event == "network_interface_wan_ifdown" or event == "network_interface_voip_ifdown" then
-- in case the Wan Interface is going down it will be checked, if the VoIP Interface is also down in Scenario 1, then
-- the Standard 1 Scenario will be activated to assure that the Correct VLAN is set for the standard WAN and the rest as well
-- Check  for both will be done, to assure, that VoIP will not be disabled, if due to whatever reason only the Data is down

		if Scenario == "1" and ifwanup == "false" and ifvoipup == "false" then
logger:warning("FRS -- event wan_ifdown_Switching to 1 Interface Scenario ")
			Set_Standard_Scenario(runtime)
		end
		return
	end
	runtime.timer_ppp_eth = timer_ppp_eth
	return
end

return M
