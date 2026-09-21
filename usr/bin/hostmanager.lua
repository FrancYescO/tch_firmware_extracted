#!/usr/bin/env lua

-- ************* COPYRIGHT AND CONFIDENTIALITY INFORMATION **********************
-- **                                                                          **
-- ** Copyright (c) 2013 Technicolor                                           **
-- ** All Rights Reserved                                                      **
-- **                                                                          **
-- ** This program contains proprietary information which is a trade           **
-- ** secret of TECHNICOLOR and/or its affiliates and also is protected as     **
-- ** an unpublished work under applicable Copyright laws. Recipient is        **
-- ** to retain this program in confidence and is not permitted to use or      **
-- ** make copies thereof other than as permitted in a written agreement       **
-- ** with TECHNICOLOR, UNLESS OTHERWISE EXPRESSLY ALLOWED BY APPLICABLE LAWS. **
-- **                                                                          **
-- ******************************************************************************

local ubus = require("ubus")
local uloop = require("uloop")
local lfs = require("lfs")
local proxy = require("datamodel")
local logger = require 'transformer.logger'
logger.init(6, false)
local log = logger.new("hostmanager", 6)

local cursor = require("uci").cursor()

local popen = io.popen
local open = io.open
local match = string.match
local lower = string.lower
local dir = lfs.dir

local tonumber = tonumber
local next = next
local pairs = pairs
local ipairs = ipairs
local type = type
local error = error
local pcall = pcall

local sp, switchport = pcall(require,'switchport')

-- UBUS connection
local ubus_conn

-- Keeps history of all devices ever seen during runtime.  Table with key on MAC address
local alldevices = {};

-- Keeps cache of all local MAC addresses (i.e., the gateway itself)
local localmacs = {};

-- Identify whether current changing device ismanageable or not
local ismanageable = false

-- Keeps history of manageable device added instance number. Table with key on MAC address
local manageabledevices = {};

-- IP modes
local ip_modes = {"ipv4", "ipv6"};

-- Wrapper around brctl showmacs, filtered by mac address
--
-- Parameters:
-- - bridge_interface: [string] the bridge interface, usually this is br-lan
-- - macaddress: [string] the macaddress to be filtered on
--
-- Returns:
-- - [table] with
-- -- portno: [number] index of the the port in the bridge
-- -- islocal: [boolean] whether it concerns a local device (i.e., the gateway itself)
-- -- aging: [number] last time seen
-- -- mac: [string] the mac address
local function brctl_showmac(bridge_interface, macaddress)
	local result = {}
	local f = popen ("brctl showmacs ".. bridge_interface .. " | grep -i " .. macaddress)

	if f == nil then
		return result
	end

	-- parse line
	local brctl_output = f:read("*l")
	if (brctl_output == nil) then
		f:close()
		return {}
	end

	result.portno, result.mac, result.islocal, result.aging = match(brctl_output,"(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")

	-- process
	result.portno = tonumber(result.portno);
	result.islocal = (result.islocal == "yes");
	result.aging = tonumber(result.aging);

	f:close()
	return result
end

-- Converts the port index of a certain bridge interface to the actual interface number
--
-- Parameters:
-- - bridge_interface: [string] the bridge interface, usually this is br-lan
-- - port: [number] index of the interface to be queried
--
-- Returns
-- - [string] with the interface name
local function bridge_getport(bridge_interface, portid)
	local syspath = "/sys/class/net/" .. bridge_interface .. "/brif"
	local iter, dir_obj, success

	success, iter, dir_obj = pcall(dir, syspath)
	if (not success) then
		return ""
	end
	for interface in iter, dir_obj do
		if interface ~= "." and interface ~= ".." then
			local f = open(syspath .. "/" .. interface .. "/port_no")
			if (f ~= nil) then
				local port = f:read("*n")
				f:close()
				if (port == portid) then
					return interface
				end
			end
		end
	end
	return ""
end


-- Retrieves information for a certain MAC address, through a UBUS call to hostapd
--
-- Parameters:
-- - macaddress: [string] requested MAC address
--
-- Returns:
-- - nil if no information was found
-- - [table] with all parameters hostapd provides
local function hostapd_info(macaddress)
	local x,i,j,_

	x=ubus_conn:call("wireless.accesspoint.station", "get", {macaddr = macaddress});

	if (x==nil) then
		return nil
	end

	-- Obtain the first information table, two levels deep (expect a single item)
	_, i = next(x)
	if (i == nil) then
		return nil
	end
	_, j = next(i)
	return j
end


-- Determines whether a certain interface is currently configured as a wireless interface
--
-- Parameters:
-- - interface: [string] interface name (usually wl0)
--
-- Returns:
-- - [boolean]
local function is_wireless(interface)
	local x=ubus_conn:call("wireless.accesspoint", "get", {})
	if x then
		for _,v in pairs(x) do
			if (v.ssid == interface) then
				return true
			end
		end
	end
	return false
end

-- Populates the IPv4/IPv6 information for a certain device/IP address pair
--
-- Parameters:
-- - mac: [string] the MAC address of the device
-- - address: [string] the IPv4 or IPv6 address
-- - mode: [string] either ipv4 or ipv6
-- - action: [string] either add or delete
-- - dhcp: [table] containing DHCP information, nil if static config
local function update_ip_state(mac, address, mode, action, dhcp)
	local iplist = (alldevices[mac])[mode];
	if (iplist[address]==nil) then
		iplist[address]={}
	end
	local ipentry = iplist[address];

	ipentry.address = address;

	if (ipentry.configuration~='dynamic') then
		if (dhcp) then
			ipentry.configuration='dynamic';
			ipentry.dhcp={
				["vendor-class"] = dhcp["vendor-class"],
				["tags"] = dhcp["tags"],
				["manufacturer-oui"] = dhcp["manufacturer-oui"],
				["serial-number"] = dhcp["serial-number"],
				["product-class"] = dhcp["product-class"],
			};
		else
			ipentry.configuration='static';
		end
	end

	local ipdhcp = dhcp
	if (action=='add') then
		ipentry.state='connected';
	else
		ipdhcp = ipentry.dhcp
		ipentry.state='disconnected';
	end
	if ipdhcp and ipdhcp.tags and ipdhcp.tags:match("cpewan%-id") then
		ismanageable = true
		if (action=='add') then
			-- Record the device information for InternetGatewayDevice.ManagementServer.ManageableDevice.{i} adding
			local config, section = "env", "var"
			cursor:set(config, section, "manageable_mac", mac)
			cursor:set(config, section, "manageable_oui", ipdhcp["manufacturer-oui"])
			cursor:set(config, section, "manageable_serial", ipdhcp["serial-number"])
			cursor:set(config, section, "manageable_prod", ipdhcp["product-class"] or "")
			cursor:commit(config)
		end
	end
end

-- Transforms a device data structure to a ubus message; currently only the lists of IP addresses
-- are changed into numbered lists
--
-- Parameters:
-- - device: [table] the device data structure
--
-- Returns:
-- - [table] the ubus message
local function transform_device_to_ubus_message(device)
	local result = {}

	if (device == nil) then
		return nil
	end
	for key, value in pairs(device) do
		if ((key == 'ipv4') or (key == 'ipv6')) then
			local iplist = {}
			local counter = 0
			for _, ip in pairs(value) do
				iplist["ip" .. counter] = ip
				counter = counter + 1
			end
			result[key]=iplist
		else
			result[key]=value
		end
	end
	return result
end

-- Handles a special case for manageable device change event
--
-- Parameters:
-- - mac: [string] the MAC address of the device
-- - action: [string] either add or delete
local function handle_manageable_device(mac, action)
	local basepath, path = "InternetGatewayDevice.ManagementServer.ManageableDevice.", ""
	local result, errmsg
	if action == "add" then
		result, errmsg = proxy.add(basepath)
		if not result then
			log:error("ERROR " .. errmsg)
		else
			manageabledevices[mac] = result
		end
	elseif action == "delete" then
		if manageabledevices[mac] then
			path = basepath .. manageabledevices[mac] .. "."
			result, errmsg = proxy.del(path)
			if not result then
				log:error("ERROR " .. errmsg)
			else
				manageabledevices[mac] = nil
			end
		end
	end
end

-- Handles an neighbour update event on UBUS
--
-- Parameters:
-- - msg: [table] the UBUS message
local function handle_device_update(msg)

	-- Reject bad events
	if (type(msg['mac-address'])~="string" or
	  (not match(msg['mac-address'], "%x%x:%x%x:%x%x:%x%x:%x%x:%x%x")) or
	  (msg['action']~='add' and msg['action']~='delete') or
	  (msg['action']=='add' and type(msg['interface'])~="string") or
	  (not (((type(msg['ipv4-address'])=="table") and type(msg['ipv4-address'].address)=="string" and match(msg['ipv4-address'].address, "%d+\.%d+\.%d+\.%d+"))
	   or ((type(msg['ipv6-address'])=="table") and type(msg['ipv6-address'].address)=="string" and match(msg['ipv6-address'].address, "[%x:]+")) ))
	  ) then
		log:info("Ignoring improper event");
		return
	end

	local mac = lower(msg['mac-address']);

	-- Filter out already known local devices
	if (localmacs[mac]) then
		return
	end

	-- First time this MAC address seen? Populate it
	if (alldevices[mac]==nil) then
		alldevices[mac]={ipv4={}, ipv6={}};
	end

	-- Keep reference to our device in the table
	local device=alldevices[mac];
	device['mac-address']=mac;

	-- Process and store the IP address(es)
	ismanageable = false
	for _, mode in ipairs(ip_modes) do
		local ipaddr = msg[mode .. '-address'];
		if (ipaddr~=nil and type(ipaddr.address)=="string") then
			update_ip_state(mac, lower(ipaddr.address), mode, msg.action, msg.dhcp);
		end
	end

	-- Device is connected if at least 1 IP address is connected
	device.state="disconnected";
	for _, mode in ipairs(ip_modes) do
		for _, j in pairs(device[mode]) do
			if (j.state=='connected') then
				device.state="connected";
				break;
			end
		end
	end

	-- Update host name if available
	if (msg.hostname~=nil) then
		device['hostname']=msg['hostname'];
	end

	if (device.state=='connected') then
		-- Set l3 interface
		device['l3interface']=msg['interface'];

		-- Retrieve l3 port based on brctl commands
		local brctl_info = brctl_showmac(msg['interface'], mac);
		if (brctl_info.islocal) then
			-- Local devices are filtered-out
			localmacs[mac]=true
			alldevices[mac]=nil
			return
		end
		device['l2interface']=bridge_getport(msg.interface, brctl_info.portno)

		if (is_wireless(device['l2interface'])) then
			local hai=hostapd_info(mac);

			if (hai ~= nil) then
				device['wireless']={encryption=hai.encryption, authentication=hai.authentication, tx_phy_rate=hai.tx_phy_rate, rx_phy_rate=hai.rx_phy_rate,} ;
			else
				device['wireless']={};
			end
			device['technology']='wireless';
		else
			device['technology']='ethernet';
			device['wireless']={};
		end
		cursor:foreach('user_friendly_name', 'name', function(s)
			if(s['mac'] == mac) then
				device['user-friendly-name']=s['name']
				return false
			end
		end)

	end

	-- Some non-Broadcom platforms (mainly LTE team) do not have a switch driver that maps switch ports to Linux network interfaces
	-- Let's give them an extra UBUS parameter for now. switchport is provided by the conf-hostmanager-switchport package
	if sp then device['switchport'] = switchport.get(mac) end

	-- Publish our enriched device object over UBUS
	ubus_conn:send('hostmanager.devicechanged', transform_device_to_ubus_message(device))

	-- To trigger TR-069 active notification by add/delete IGD.ManagementServer.ManageableDevice.
	if ismanageable then
		handle_manageable_device(mac, msg.action)
	end
end

-- Callback function when 'hostmanager.device get' is called
--
-- Parameters:
-- - req: parameter to be passed to the UBUS reply
-- - response: [table] the response to be formatted using JSON
local function handle_rpc_get(req, msg)
	local mac=msg['mac-address'];
	local response = {};
	local transformed_response = {};
	local counter = 0

	-- Filter on MAC address
	if (type(mac) == "string") then
		mac=lower(mac);
		response[mac]=alldevices[mac];
	else
		response = alldevices;
	end


	-- Filter on IPv4/IPv6 address
	for _, mode in ipairs(ip_modes) do
		local ipaddr=msg[mode .. '-address'];
		if (type(ipaddr) == "string") then
			ipaddr=lower(ipaddr);
			local filtered_response = {};
			for j, dev in pairs(response) do
				for devaddr, k in pairs(dev[mode]) do
					if (devaddr==ipaddr) then
						filtered_response[dev['mac-address']]=dev;
						break;
					end
				end
			end
			response = filtered_response
		end
	end

	for _, dev in pairs(response) do
		transformed_response["dev" .. counter] = transform_device_to_ubus_message(dev);
		counter = counter + 1
	end

	ubus_conn:reply(req, transformed_response);
end
-- Callback function when 'hostmanager.device set' is called
--
-- Parameters:
-- - req: parameter to be passed to the UBUS reply
-- - response: [table] the response to be formatted using JSON
local function handle_rpc_set(req, msg)
	local mac=msg['mac-address']
	local name=msg['user-friendly-name']
	local response
	local section
	local found=false
	if (type(mac) == "string") then
		mac=lower(mac)
		if alldevices[mac] ~= nil then
			alldevices[mac]['user-friendly-name']=name
			response =	alldevices[mac]
			ubus_conn:send('hostmanager.devicechanged', transform_device_to_ubus_message(alldevices[mac]))
		end
		cursor:foreach('user_friendly_name', 'name', function(s)
			if(s['mac'] == mac) then
				cursor:set('user_friendly_name', s['.name'], 'name',name)
				found=true
				return false
			end
		end)
		if found == false then
			section = cursor:add('user_friendly_name', 'name')
			if section ~= nil then
				cursor:set('user_friendly_name',section,'name',name)
				cursor:set('user_friendly_name',section,'mac',mac)
			end
		end
		cursor:commit('user_friendly_name')
	end
	ubus_conn:reply(req,response)
end

local function errhandler(err)
	log:critical(err)
	for line in string.gmatch(debug.traceback(), "([^\n]*)\n") do
		log:critical(line)
	end
end

-- Main code
uloop.init();
ubus_conn = ubus.connect()
if not ubus_conn then
	log:error("Failed to connect to ubus")
end


-- Register RPC callback
ubus_conn:add( { ['hostmanager.device'] = { get = { handle_rpc_get , {["mac-address"] = ubus.STRING, ["ipv4-address"] = ubus.STRING, ["ipv6-address"] = ubus.STRING } },
                                            set = { handle_rpc_set, {["mac-address"] = ubus.STRING, ["user-friendly-name"] = ubus.STRING } } } } );


-- Register event listener
ubus_conn:listen({ ['network.neigh'] = handle_device_update} );

-- Idle loop
xpcall(uloop.run,errhandler)
