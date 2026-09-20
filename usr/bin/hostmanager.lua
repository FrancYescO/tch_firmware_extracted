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

local cursor = require("uci").cursor("/etc/config", "/var/state")

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
local extinfo_supported, extinfo_plugin = pcall(require, "hostmanager.extinfo")

-- UBUS connection
local ubus_conn

-- Keeps history of all devices ever seen during runtime.  Table with key on MAC address
local alldevices = {};

-- Keeps track on IP address used in firewall MAC-based redirects for any given device.
-- Table with key on "MAC adress,IP mode"
local redirectips = {};

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


-- Retrieves information for a certain MAC address and Accesspoint, through a UBUS call to hostapd
--
-- Parameters:
-- - ap_x      : [string] requested Accesspoint name
-- - macaddress: [string] requested MAC address
--
-- Returns:
-- - nil if no information was found
-- - [table] with all parameters hostapd provides
local function hostapd_info(ap_x, macaddress)
  local x,i,j,_

  x=ubus_conn:call("wireless.accesspoint.station", "get", {name = ap_x, macaddr = macaddress});

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
    for k,v in pairs(x) do
      if (v.ssid == interface) then
        return true, k
      end
    end
  end
  return false, nil
end

-- Update MAC-based firewall redirects with the current IP address selected for device
--
-- Parameters:
-- - mac: [string] the MAC address of the device
-- - address: [string] the IPv4 or IPv6 address
-- - mode: [string] either ipv4 or ipv6
-- Returns:
--   [boolean] TRUE if redirects were successfully updated
local function update_device_redirects(mac, address, mode)
  local config, redirgroup = "firewall", "redirectsgroup"
  local redirtypes = { ["redirect"] = true }
  local redirect
  local sections = { }

  cursor:load(config)

  cursor:foreach(config, redirgroup, function(s)
    redirtypes[s.type] = true
  end)

  for redirect in pairs(redirtypes) do
    cursor:foreach(config, redirect, function(s)
      if s.target ~= "SNAT" and s.family == mode and s.dest_ip ~= address and s.dest_mac == mac then
        table.insert(sections, s[".name"])
      end
    end)
  end

  if #sections == 0 then
    cursor:unload(config)
    return true
  end

  for _,s in ipairs(sections) do
    cursor:revert(config, s, "dest_ip")
    if address ~= nil then
      cursor:set(config, s, "dest_ip", address)
    end
  end

  cursor:save(config)
  cursor:unload(config)

  return os.execute("fw3 -q reload") == 0
end

-- Populates the IPv4/IPv6 information for a certain device/IP address pair
--
-- Parameters:
-- - mac: [string] the MAC address of the device
-- - address: [string] the IPv4 or IPv6 address
-- - mode: [string] either ipv4 or ipv6
-- - action: [string] either add or delete
-- - dhcp: [table] containing DHCP information, nil if static config
-- Returs:
-- - [boolean] true if device state has changed
local function update_ip_state(mac, address, mode, action, dhcp)
  local iplist = (alldevices[mac])[mode];
  if (iplist[address]==nil) then
    iplist[address]={address=address}
  end
  local ipentry = iplist[address]
  local redirkey = mac .. "," .. mode
  local changed = false

  if (action=="add") then
    if ipentry.state ~= "connected" then
      ipentry.state = "connected"
      changed = true
    end

    if dhcp then
      if ipentry.configuration ~= "dynamic" then
	ipentry.configuration = "dynamic"
	changed=true
      end
      if type(ipentry.dhcp) ~= "table" then
	ipentry.dhcp={}
	changed=true
      end
      -- only update our table with new elements (do not delete them again).
      -- because: dnsmasq sends via dhcp-event.sh, which handles 'add'
      -- and 'old' similarly. Restarting dnsmasq causes 'old' events,
      -- which are less complete than their original 'add' events,
      -- because dhcp.leases file does not save these elements.
      for _,key in ipairs({
	   "vendor-class" ,
	   "tags" ,
	   "manufacturer-oui" ,
	   "serial-number" ,
	   "product-class"
	   }) do
	if dhcp[key] ~= ipentry.dhcp[key] and dhcp[key] ~= nil  then
	   ipentry.dhcp[key]= dhcp[key]
	   changed = true
	end
      end


      if dhcp.tags and dhcp.tags:match("cpewan%-id") then
	ismanageable = true

	-- Record the device information for InternetGatewayDevice.ManagementServer.ManageableDevice.{i} adding
	local config, section = "env", "var"
	cursor:set(config, section, "manageable_mac", mac)
	cursor:set(config, section, "manageable_oui", dhcp["manufacturer-oui"] or "")
	cursor:set(config, section, "manageable_serial", dhcp["serial-number"] or "")
	cursor:set(config, section, "manageable_prod", dhcp["product-class"] or "")
	cursor:commit(config)
      end
    elseif ipentry.configuration ~= "dynamic" or ipentry.dhcp == nil then
      -- If entry was not configured as dynamic, set it as static
      ipentry.configuration = "static"
      ipentry.dhcp = nil
      changed = true
    end

    if redirectips[redirkey] == nil or (redirectips[redirkey] ~= address and
      ipentry.configuration == "dynamic" and iplist[redirectips[redirkey]].configuration ~= "dynamic") then
      -- Update redirect IP address of this device
      if redirectips[redirkey] then
	local olddest = iplist[redirectips[redirkey]]
	if olddest then
	  olddest["redirect-dest"] = nil
	end
      end
      ipentry["redirect-dest"] = true

      redirectips[redirkey] = address
      update_device_redirects(mac, redirectips[redirkey], mode)
    end
  else
    if ipentry.state ~= "disconnected" then
      ipentry.state = "disconnected"
      changed = true
    end

    if redirectips[redirkey] == address then
      -- Remove redirect-dest attribute from disconnected address
      ipentry["redirect-dest"] = nil

      -- Elect another redirect IP address for this device
      local v
      ipentry = nil
      for _,v in pairs(iplist) do
	if v.state == "connected" then
	  if v.configuration == "dynamic" then
	    ipentry = v
	    break
	  elseif ipentry == nil then
	    ipentry = v
	  end
	end
      end

      if ipentry then
	redirectips[redirkey] = ipentry.address
	ipentry["redirect-dest"] = true
      else
	redirectips[redirkey] = nil
      end
      update_device_redirects(mac, redirectips[redirkey], mode)
    end
  end

  return changed
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
  if action == "add" then
    if not manageabledevices[mac] then
      local data = {}
      data["mac"] = mac

      ubus_conn:send('hostmanager.manageableDeviceChanged', data)
      manageabledevices[mac] = mac
    end
  elseif action == "delete" then
    if manageabledevices[mac] then
      local data = {}
      data["mac"] = mac

      ubus_conn:send('hostmanager.manageableDeviceChanged', data)
      manageabledevices[mac] = nil
    end
  end
end

local function handle_connected_time_update(msg)
    local device
    for mac, _ in pairs (alldevices) do
	device = alldevices[mac]
	if device.state == 'connected' then
	    -- if the connected time is before 2015-01-01 00:00:00,UTC time 1419120000,
	    -- it means the time was set before CPE synchronized with the NTP server.
	    if not device['connected_time']
	       or device['connected_time'] == 0
	       or device['connected_time'] < 1419120000 then
		device['connected_time'] = os.time()
	    end
	end
    end
end
-- To identify given 'interface' is bridge or l2interface

-- Parameters:
-- - interface: [string] interface name

local function is_bridge(interface)
  local syspath = "/sys/class/net/" .. interface .. "/bridge/bridge_id"
  local f = open(syspath)
  local ret = false
  if (f ~= nil) then
	  f:close()
	  ret = true
  end
  return ret
end

-- To find the L3 interface name in case of non-bridge device
-- This will look up the network.interface and get the information
-- Parameter:
-- - interface: [string] interface name
local function get_logical_interface_name(interface)
  local x=ubus_conn:call("network.interface", "dump", {})
  if x then
    for _,v in pairs(x) do
      for _,vv in pairs(v) do
	if (vv.l3_device == interface) then
	  return vv.interface
	end
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
  if (type(msg)~="table" or
    type(msg['mac-address'])~="string" or
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
  local changed = false

  -- Filter out already known local devices
  if (localmacs[mac]) then
    return
  end

  -- First time this MAC address seen? Populate it
  if (alldevices[mac]==nil) then
    alldevices[mac]={["mac-address"]=mac, ipv4={}, ipv6={}}
    changed = true
  end

  -- Keep reference to our device in the table
  local device = alldevices[mac];

  local is_bridge_device
  if msg['interface'] then
    is_bridge_device = is_bridge(msg['interface'])
  end

  -- Process and store the IP address(es)
  ismanageable = false
  for _, mode in ipairs(ip_modes) do
    local ipaddr = msg[mode .. '-address'];
    if (ipaddr~=nil and type(ipaddr.address)=="string") then
      changed = update_ip_state(mac, lower(ipaddr.address), mode, msg.action, msg.dhcp) or changed;
    end
  end

  -- Retrieve l3 port based on brctl commands
  local brctl_info = { }
  if (is_bridge_device == true) then
    brctl_info = brctl_showmac(msg['interface'], mac);
  end

  local state
  local l2_is_wireless = false
  local ap_x = nil
  local hai = nil

  state = "disconnected"
  if not is_bridge_device or brctl_info.islocal ~= nil then
    -- Device is connected if at least 1 IP address is connected
    for _, mode in ipairs(ip_modes) do
      for _, j in pairs(device[mode]) do
	if (j.state=='connected') then
	  state = "connected"
	  break
	end
      end
    end
  end

  -- Retrieve l2 interface based on brctl info
  if (state == "connected") then
    local l2interface
    if is_bridge_device then
      l2interface = bridge_getport(msg.interface, brctl_info.portno)
    else
      l2interface = msg['interface']
    end
    if device.l2interface ~= l2interface then
      device.l2interface = l2interface
      changed = true
    end
  end

  if device.l2interface ~= nil then
    l2_is_wireless, ap_x = is_wireless(device.l2interface)
    if (l2_is_wireless and ap_x) then
      hai = hostapd_info(ap_x, mac)
      if (hai ~= nil) then
	-- Received untrusted events but wireless device is ageing in 'brctl macshow' which makes device always be 'connected'.
	if (hai.state == "Disconnected") then
	  state = "disconnected"
	elseif ((hai.state == "Authenticated Associated Authorized") and (hai.flags ~= nil) and string.match(hai.flags,"Powersave")) then
	  state = "connected"
	end
      end
    end
  end

  if device.state ~= state then
    device.state = state
    changed = true
  end

  -- Update host name if available
  if msg.hostname ~= nil and device.hostname ~= msg.hostname then
    device.hostname = msg.hostname
    changed = true
  end

  if (device.state == 'disconnected' or msg['action'] == 'delete') and device['connected_time'] ~= 0 then
    device['connected_time'] = 0
    changed = true
	end

  if (device.state == 'connected') then
	  if not device['connected_time'] or device['connected_time'] == 0  then
      ---- in case of dhcp renew
      device['connected_time'] = os.time()
      changed = true
		end

		-- Set the logical netifd interface name into 'interface'
    local interface = get_logical_interface_name(msg['interface'])
    local l3interface = msg['interface']
    if device.interface ~= interface or device.l3interface ~= l3interface then
      device.interface = interface
      device.l3interface = l3interface
      changed = true
		end

    if (brctl_info.islocal) then
      -- Local devices are filtered-out
      localmacs[mac]=true
      alldevices[mac]=nil
      return
    end

    local technology
    local wireless = {}
    if (l2_is_wireless) then
      technology = 'wireless'
      if (hai ~= nil) then
	wireless = {
	  encryption = hai.encryption,
	  authentication = hai.authentication,
	  tx_phy_rate = hai.tx_phy_rate,
	  rx_phy_rate = hai.rx_phy_rate,
	}
      end
    else
      technology = 'ethernet'
    end
    if device.technology ~= technology or
       device.wireless.encryption ~= wireless.encryption or
       device.wireless.authentication ~= wireless.authentication or
       device.wireless.tx_phy_rate ~= wireless.tx_phy_rate or
       device.wireless.rx_phy_rate ~= wireless.rx_phy_rate then
      device.technology = technology
      device.wireless = wireless
      changed = true
    end

    cursor:foreach('user_friendly_name', 'name', function(s)
      if(s['mac'] == mac) then
	if device['user-friendly-name'] ~= s['name'] then
	  device['user-friendly-name'] = s['name']
	  device['device-type'] = s['type']
	  changed = true
	end
	return false
      end
    end)

  end

  -- Some non-Broadcom platforms (mainly LTE team) do not have a switch driver that maps switch ports to Linux network interfaces
  -- Let's give them an extra UBUS parameter for now. switchport is provided by the conf-hostmanager-switchport package
  if sp and device['technology'] ~= 'wireless' then
    local switchport = switchport.get(mac)
    if device.switchport ~= switchport then
      device.switchport = switchport
      changed = true
    end
  end

  -- Publish our enriched device object over UBUS
  if changed then
    ubus_conn:send('hostmanager.devicechanged', transform_device_to_ubus_message(device))
  end

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
  local reqextinfo=msg['ext-info'];
  local extinfo, extinfo_rv = {};
  local response = {};
  local transformed_response = {};
  local counter = 0

  if ((reqextinfo == true) and extinfo_supported) then
    extinfo_rv, extinfo = pcall(extinfo_plugin.get_extinfo);
  end

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
    if extinfo_rv then
      transformed_response["dev" .. counter]['ext-info'] = extinfo[dev['mac-address']] or {}
    end
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
  local devicetype=msg['device-type']
  local response
  local section
  local found=false
  if (type(mac) == "string") then
    mac=lower(mac)
    if alldevices[mac] ~= nil then
      response = alldevices[mac]
      if name and alldevices[mac]['user-friendly-name'] ~= name then
	alldevices[mac]['user-friendly-name']=name
	ubus_conn:send('hostmanager.devicechanged', transform_device_to_ubus_message(alldevices[mac]))
      end
      if devicetype and alldevices[mac]['device-type'] ~= devicetype then
	alldevices[mac]['device-type']=devicetype
	ubus_conn:send('hostmanager.devicechanged', transform_device_to_ubus_message(alldevices[mac]))
      end
    end
    cursor:foreach('user_friendly_name', 'name', function(s)
      if(s['mac'] == mac) then
	if name then
	  cursor:set('user_friendly_name', s['.name'], 'name',name)
	end
	if devicetype then
	  cursor:set('user_friendly_name', s['.name'], 'type',devicetype)
	end
	found=true
	return false
      end
    end)
    if found == false then
      section = cursor:add('user_friendly_name', 'name')
      if section ~= nil then
	if name then
	  cursor:set('user_friendly_name',section,'name',name)
	end
	cursor:set('user_friendly_name',section,'mac',mac)
	if devicetype then
	  cursor:set('user_friendly_name',section,'type',devicetype)
	end
      end
    end
    cursor:commit('user_friendly_name')
  end
  ubus_conn:reply(req,response)
end

local function handle_rpc_delete(req, msg)
  local mac = msg['mac-address']

  if (type(mac) == "string") then
    mac = lower(mac)
    if alldevices[mac] ~= nil and alldevices[mac].state == "disconnected" then
      alldevices[mac] = nil
    end
  end
  ubus_conn:reply(req,{})
end

local function errhandler(err)
  log:critical(err)
  for line in string.gmatch(debug.traceback(), "([^\n]*)\n") do
    log:critical(line)
  end
end

-- some hosts, no "keep-alive" network.neigh events.
-- if lost (e.g. restart hostmanager), scan them from "network.neigh", "status"
local function scan_network_neigh_status()
  local x=ubus_conn:call("network.neigh", "status", {})
  if x and x.neigh then
    for _,v in ipairs(x.neigh) do
      if (type(v["mac-address"]) == "string" and alldevices[v["mac-address"]] == nil and v["action"] == "add") then
	handle_device_update(v)
      end
    end
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
					    set = { handle_rpc_set, {["mac-address"] = ubus.STRING, ["user-friendly-name"] = ubus.STRING, ["device-type"] = ubus.STRING } },
					    delete = { handle_rpc_delete, {["mac-address"] = ubus.STRING } }, } } );


-- Register event listener
ubus_conn:listen({ ['network.neigh'] = handle_device_update} );
ubus_conn:listen({ ['ntp.connected'] = handle_connected_time_update} );

scan_network_neigh_status();

-- Idle loop
xpcall(uloop.run,errhandler)
