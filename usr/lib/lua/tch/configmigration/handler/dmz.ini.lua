--Pedro Mejía - CTS Mexico
--11/07/2017
--Migration script for DMZ values from Legacy to Homeware
--Last changes 15/11/2017
--Firewall dmzredirect config

local match = string.match
local gmatch = string.gmatch
local tp = require("tch.tableprint")

local M = {}

local append_commit_list = require("tch.configmigration.core").append_commit_list
local touci = require("tch.configmigration.touci")
local logger = require("transformer.logger")
local log = logger.new("configmigration:dmz.ini", config.log_level)
local format = string.format
local num2ipv4 = require("tch.configmigration.convert_helper").num2ipv4
local bit = require("bit")

function M.convert(g_user_ini)
   local section_string = g_user_ini["env.ini"]
   if not section_string then return end
   
   local section_mac_string = g_user_ini["dhcs.ini"]
   if not section_mac_string then return end

	-- Find the device's ip with DMZ on env.ini
	local dmz_ip
	dmz_ip = match(section_string, "set var=DMZ_IP value=([%d%.]+)")
	
local function add_user_dmz(clientid, pool, addr, lifetime, macaddr, allocation)
	if dmz_ip == addr then
		local ucicmd = {}
			--Firewall config section fwconfig
			ucicmd.uci_config = "firewall"
			ucicmd.uci_secname = "fwconfig"
			ucicmd.uci_option = "dmz"
			ucicmd.action = "set"
			ucicmd.value = "1"
			
			touci.touci (ucicmd)
			touci.commit ("firewall")
			
			--Firewall config section dmzredirects
			ucicmd.uci_config = "firewall"
			ucicmd.uci_secname = "dmzredirects"
			ucicmd.uci_option = "enabled"
			ucicmd.action = "set"
			ucicmd.value = "1"
			
			touci.touci (ucicmd)
			touci.commit ("firewall")
			
			--Firewall config section dmzredirect destination ip
			ucicmd.uci_config = "firewall"
			ucicmd.uci_secname = "dmzredirect"
			ucicmd.uci_option = "dest_ip"
			ucicmd.action = "set"
			ucicmd.value = "0.0.0.0"
			
			touci.touci (ucicmd)
			touci.commit ("firewall")
			
			--Firewall config section dmzredirect destination mac
			ucicmd.uci_config = "firewall"
			ucicmd.uci_secname = "dmzredirect"
			ucicmd.uci_option = "dest_mac"
			ucicmd.action = "set"
			ucicmd.value = macaddr
			
			touci.touci (ucicmd)
			touci.commit ("firewall")
			
			--Firewall config section dmzredirect enabled
			ucicmd.uci_config = "firewall"
			ucicmd.uci_secname = "dmzredirect"
			ucicmd.uci_option = "enabled"
			ucicmd.action = "set"
			ucicmd.value = "1"
			
			touci.touci (ucicmd)
			touci.commit ("firewall")
						
			append_commit_list(ucicmd.uci_config)
	end
end
	-- Find the device's ip on dhcs.ini

	for clients in gmatch(section_mac_string, "lease add %C+") do
		local clientid, pool, addr, lifetime, macaddr, allocation = match (clients, "clientid=(%S+) pool=(%S+) addr=(%S+) lifetime=(%S+) macaddr=(%S+) allocation=(%S+)")
		
		add_user_dmz(clientid, pool, addr, lifetime, macaddr, allocation)
	end
	

end

return M
