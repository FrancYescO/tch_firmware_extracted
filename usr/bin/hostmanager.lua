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
local log = require ('tch.logger')
log.init("hostmanager", 6)

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
local extinfo_supported, extinfo_plugin = pcall(require, "hostmanager.extinfo")

-- Retention policy
local MIN_DELETE_TIMER_VALUE = 5 * 60 -- 5 minutes
local global_policy = { delete_delay = -1, max_devices_per_interface = -1 }
local interfaces_data = { }
local delete_timer = nil
local devices_linkdown_timer = nil

-- UBUS connection
local ubus_conn

-- Keeps history of all devices ever seen during runtime.  Table with key on MAC address
local alldevices = {}

-- Keeps cache of all local MAC addresses (i.e., the gateway itself)
local localmacs = {}

-- Keeps devices which get network.link down events and need update l2interface
local devices_linkdown = {}

-- Wireless cached status
local deferred_wireless_status_scan = true
local remote_radio_interfaces = {}
local active_wireless_ssids = {}

-- Identify whether current changing device ismanageable or not
local ismanageable = false

-- Keeps history of manageable device added instance number. Table with key on MAC address
local manageabledevices = {}

-- IP modes
local ip_modes = {"ipv4", "ipv6"};

-- Retrieve the L3 interface name correspondent to a logical interface name
--
-- Parameters:
-- - interface: [string] logical interface name (e.g. lan)
--
-- Returns:
-- - [string]
local function get_l3_interface_name(interface)
  local x=ubus_conn:call("network.interface." .. interface, "status", {})
  local r
  if type(x) == "table" then
    r = x["l3_device"] or x["device"]
  end
  return r
end

-- Retrieve delete delay time configured on L3 interface
--
-- Parameters:
-- - interface: [string] L3 interface name
--
-- Returns:
-- - [number]
local function get_interface_delete_delay(interface)
  local t = interfaces_data[interface]
  if t and t.delete_delay then
    return t.delete_delay
  end
  return global_policy.delete_delay
end

-- Retrieve the oldest disconnected device on specified L3 interface
--
-- Parameters:
-- - interface: [string] L3 interface name
--
-- Returns:
-- - [index],[device]
local function get_oldest_disconnected_device(interface)
  local oldidx, olddev, olddisconnect

  for idx, device in pairs(alldevices) do
    if device.l3interface == interface and type(device.disconnected_time) == "number" and
       (not olddisconnect or olddisconnect > device.disconnected_time) then
      oldidx = idx
      olddev = device
      olddisconnect = device.disconnected_time
    end
  end

  return oldidx, olddev
end

-- Retrieve the newest connected device on specified L3 interface
--
-- Parameters:
-- - interface: [string] L3 interface name
--
-- Returns:
-- - [index],[device]
local function get_newest_connected_device(interface)
  local newidx, newdev, newconnect

  for idx, device in pairs(alldevices) do
    if device.l3interface == interface and device.state == "connected" and
       (not newconnect or newconnect < device.connected_time) then
      newidx = idx
      newdev = device
      newconnect = device.connected_time
    end
  end

  return newidx, newdev
end

-- Read hostmanager configuration from UCI
local function load_configuration()
  local config = "hostmanager"

  -- Reset to default
  global_policy.delete_delay = -1
  global_policy.max_devices_per_interface = -1
  for _, intf in pairs(interfaces_data) do
    intf.delete_delay = nil
    intf.max_devices_per_interface = nil
  end

  local function read_config(s)
    local t
    if s[".type"] == "global" then
      t = global_policy
    elseif s[".type"] == "interface" and s[".name"] then
      local n = get_l3_interface_name(s[".name"])
      if not n then
	return
      end
      if not interfaces_data[n] then
	interfaces_data[n] = { connected_devices = 0, disconnected_devices = 0 }
      end
      t = interfaces_data[n]
    end

    if s["delete_delay"] then
      local _, _, value, unit = string.find(s["delete_delay"], "^(%d+)([smhdw]?)$")
      value = tonumber(value)
      if value then
	if unit == "w" then
	  t["delete_delay"] = value * 7 * 24 * 60 * 60
	elseif unit == "d" then
	  t["delete_delay"] = value * 24 * 60 * 60
	elseif unit == "h" then
	  t["delete_delay"] = value * 60 * 60
	elseif unit == "m" then
	  t["delete_delay"] = value * 60
	else
	  t["delete_delay"] = value
	end
      end
    end

    if tonumber(s["max_devices_per_interface"]) then
      t["max_devices_per_interface"] = tonumber(s["max_devices_per_interface"])
    end
  end

  cursor:load(config)
  cursor:foreach(config, "global", read_config)
  cursor:foreach(config, "interface", read_config)
  cursor:unload(config)
end

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

-- Retrieves the bridge which the interface belongs
--
-- Parameters:
-- - interface: [string] the given interface
--
-- Returns:
-- [string] the bridge or an empty string if not found
local function get_bridge_from_if(interface)
  local syspath = "/sys/class/net/" .. interface .. "/brport/bridge/uevent"
  local f = open (syspath)

  if f == nil then
    return ""
  end

  local line = f:read()
  local bridge
  while not bridge and line do
    bridge = line:match("INTERFACE=(.+)")
    line = f:read()
  end
  f:close()

  return bridge
end

-- Determines whether a certain MAC address belongs to a wireless device
--
-- Parameters:
-- - interface: [string] interface name (usually wl0)
-- - macaddress: [string] the MAC address of the device
--
-- Returns:
-- - nil if no information was found
-- - otherwise [boolean] true, [string] radio name, [string] access point name, [string] ssid name, [table] wireless station information
local function is_wireless(interface, macaddress)
  local radio, accesspoint, ssid, stai

  for s, sv in pairs(active_wireless_ssids) do
    if sv.interface == interface then
      local reply = ubus_conn:call("wireless.accesspoint.station", "get", { name = sv.accesspoint, macaddr = macaddress })
      if type(reply) == "table" then
	-- Obtain the information table, two levels deep
	local _, x = next(reply)
	if type(x) == "table" then
	  local _, y = next(x)
	  if type(y) == "table" then
	    radio = sv.radio
	    accesspoint = sv.accesspoint
	    ssid = s
	    stai = y
	    return true, radio, accesspoint, ssid, stai
	  end
	end
      end
    end
  end

  return nil
end

-- Populates the IPv4/IPv6 information for a certain device/IP address pair
--
-- Parameters:
-- - l3interface: [string] the Linux interface name
-- - mac: [string] the MAC address of the device
-- - address: [string] the IPv4 or IPv6 address
-- - mode: [string] either ipv4 or ipv6
-- - action: [string] either add or delete
-- - conflictingmac: [string] the MAC address of the device conflicting with this address
-- - dhcp: [table] containing DHCP information, nil if static config
-- Returs:
-- - [boolean] true if device state has changed
local function update_ip_state(l3interface, mac, address, mode, action, conflictingmac, dhcp)
  local changed = false
  local iplist = (alldevices[mac])[mode];
  if (iplist[address]==nil) then
    iplist[address]={ address=address, state="disconnected" }
    changed = true
  end
  local ipentry = iplist[address]

  if (action=="add") then
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
	   "product-class",
	   "requested-options"
	   }) do
	if dhcp[key] ~= ipentry.dhcp[key] and dhcp[key] ~= nil  then
	   ipentry.dhcp[key]= dhcp[key]
	   changed = true
	end
      end
      if ipentry.dhcp.state ~= "connected" then
	ipentry.dhcp.state = "connected"
	changed = true

	if ipentry.state ~= "connected" then
	  ubus_conn:call("network.neigh", "probe", {
			      ["interface"]=l3interface,
			      ["mac-address"]=mac,
			      [mode.."-address"]=address})
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
    elseif ipentry.state ~= "connected" then
      ipentry.state = "connected"
      changed = true

      if ipentry.configuration ~= "static" and (ipentry.configuration ~= "dynamic" or ipentry.dhcp == nil) then
	-- If entry was not configured as dynamic, set it as static
	ipentry.configuration = "static"
	ipentry.dhcp = nil
	changed = true
      end
    end
  else
    if dhcp then
      if ipentry.dhcp and ipentry.dhcp.state == "connected" then
	ipentry.dhcp.state = "disconnected"
	changed = true

	if ipentry.state ~= "disconnected" then
	  ubus_conn:call("network.neigh", "probe", {
			      ["interface"]=l3interface,
			      ["mac-address"]=mac,
			      [mode.."-address"]=address})
	end
      end
    elseif ipentry.state ~= "disconnected" then
      ipentry.state = "disconnected"
      changed = true
    end
  end

  if not dhcp and ipentry["conflicts-with"] ~= conflictingmac then
    ipentry["conflicts-with"] = conflictingmac
    changed = true
  end

  return changed
end

-- Returns true if ip state is connected
local function ip_state_connected(ipentry)
  return ipentry.state ~= "disconnected"
end

-- Returns true if ip entry is static and its state is disconnected static
local function ip_static_state_disconnected(ipentry)
  return ipentry.configuration == "static" and ipentry.state ~= "connected"
end

-- Probe all bridge devices connected through a certain L2 interface
--
-- Parameters:
-- - bridge: L3 interface
-- - interface: L2 interface
-- - ip_modes: [table] address types to be probed (e.g. { "ipv4", "ipv6" })
-- - ipentry_selector: function that receives an ip entry and returns true if entry needs to be probed
local function probe_selected_bridge_devices(bridge, interface, ip_modes, ipentry_selector)
  for mac, _ in pairs(alldevices) do
    device = alldevices[mac]
    if (device["l2interface"] == interface) then
      -- Device's l2interface needs update, mark it
      devices_linkdown[mac] = bridge
      for _, mode in ipairs(ip_modes) do
	for _, ip in pairs(device[mode]) do
	  if ipentry_selector(ip) then
	    log:info("Probing device " .. mac .. " IP address " .. ip.address .. " on interface " .. bridge);
	    ubus_conn:call("network.neigh", "probe", {
				["interface"]=bridge,
				["mac-address"]=mac,
				[mode.."-address"]=ip.address})
	  end
	end
      end
    end
  end
end

-- Probe all devices connected through a certain L3 interface
--
-- Parameters:
-- - interface: L3 interface
-- - ipentry_selector: function that receives an ip entry and returns true if entry needs to be probed
local function probe_selected_interface_devices(interface, ip_modes, ipentry_selector)
  for mac, _ in pairs(alldevices) do
    device = alldevices[mac]
    if (device['l3interface'] == interface) then
      for _, mode in ipairs(ip_modes) do
	for _, ip in pairs(device[mode]) do
	  if ipentry_selector(ip) then
	    log:info("Probing device " .. mac .. " IP address " .. ip.address .. " on interface " .. interface);
	    ubus_conn:call("network.neigh", "probe", {
				["interface"]=interface,
				["mac-address"]=mac,
				[mode.."-address"]=ip.address})
	  end
	end
      end
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

-- To identify given 'interface' is bridge or l2interface
--
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

-- Verify if interface is attached to a bridge
--
-- Parameters:
-- - interface: [string] interface name
-- - bridge: [string] bridge name
local function is_interface_bridge_port(interface, bridge)
  local syspath = "/sys/class/net/" .. bridge .. "/brif/" .. interface .. "/port_id"
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
  if type(x) == "table" then
    for _,v in pairs(x) do
      for _,vv in pairs(v) do
	if (vv.l3_device == interface) then
	  return vv.interface
	end
      end
    end
  end
end

-- Checks if hostmanager is allowed to keep track on more devices reachable through
-- the specified L3 interface
--
-- Parameters:
-- - interface: [string] L3 interface name
--
-- Returns:
-- - [boolean]
local function can_allocate_device_on_interface(interface)
  local t = interfaces_data[interface]
  local max
  if t and t.max_devices_per_interface then
    max = t.max_devices_per_interface
  else
    max = global_policy.max_devices_per_interface
  end

  if max < 0 or t.connected_devices + t.disconnected_devices < max then
    return true
  elseif max == 0 then
    -- Delete all devices on this interface
    if t.connected_devices + t.disconnected_devices > 0 then
      for idx, device in pairs(alldevices) do
	if device.l3interface == interface then
	  log:info("Delete device " .. idx);
	  ubus_conn:send('hostmanager.devicedeleted', transform_device_to_ubus_message(device))
	  alldevices[idx] = nil
	  -- Update interface stats
	  if device.state == "connected" then
	    t.connected_devices = t.connected_devices - 1
	  else
	    t.disconnected_devices = t.disconnected_devices - 1
	  end
	end
      end
    end
  else
    -- Try to make room by deleting disconnected devices
    while t.disconnected_devices > 0 do
      local idx, device = get_oldest_disconnected_device(interface)

      if not device then
	-- shouldn't happen, it is added here only as a safeguard
	t.disconnected_devices = 0
	break
      end

      log:info("Delete device " .. idx);
      ubus_conn:send('hostmanager.devicedeleted', transform_device_to_ubus_message(device))
      alldevices[idx] = nil
      -- Update interface stats
      t.disconnected_devices = t.disconnected_devices - 1
      if t.connected_devices + t.disconnected_devices < max then
	return true
      end
    end

    -- Free connected devices allocated above allowed limit
    while t.connected_devices > max do
      local idx, device = get_newest_connected_device(interface)

      if not device then
	-- shouldn't happen, it is added here only as a safeguard
	t.connected_devices = 0
	break
      end

      log:info("Delete device " .. idx);
      ubus_conn:send('hostmanager.devicedeleted', transform_device_to_ubus_message(device))
      alldevices[idx] = nil
      -- Update interface stats
      t.connected_devices = t.connected_devices - 1
    end
  end

  return false
end

-- Timeout function for delayed deletes
function timeout_delete()
  local now = os.time()
  local timeout = nil

  -- Remove entries that were disconnected for too long
  for idx, device in pairs(alldevices) do
    if type(device.disconnected_time) == "number" then
      local delete_delay = get_interface_delete_delay(device.l3interface)
      if delete_delay >= 0 then
	local t = device.disconnected_time + delete_delay - now
	if t <= 0 then
	  log:info("Delete device " .. idx);
	  ubus_conn:send('hostmanager.devicedeleted', transform_device_to_ubus_message(device))
	  alldevices[idx] = nil
	  -- Update interface stats
	  local interface_stats = interfaces_data[device.l3interface]
	  interface_stats.disconnected_devices = interface_stats.disconnected_devices - 1
	elseif not timeout or timeout > t then
	  timeout = t
	end
      end
    end
  end

  -- Reset delete timer
  if timeout and timeout > 0 then
    if timeout < MIN_DELETE_TIMER_VALUE then
      timeout = MIN_DELETE_TIMER_VALUE
    end
    delete_timer:set(timeout * 1000)
  end
end

-- Sets global device status
--
-- Parameters:
-- - device: [table] the device entry
-- - state: [string] "connected" or "disconnected"
local function set_device_state(device, state)
  local interface_stats = interfaces_data[device.l3interface]

  if device.state == "connected" then
    interface_stats.connected_devices = interface_stats.connected_devices - 1
  elseif device.state == "disconnected" then
    interface_stats.disconnected_devices = interface_stats.disconnected_devices - 1
  end

  local now = os.time()
  device.state = state
  if state == "connected" then
    device.connected_time = now
    device.disconnected_time = nil
    interface_stats.connected_devices = interface_stats.connected_devices + 1
  else
    device.disconnected_time = now
    interface_stats.disconnected_devices = interface_stats.disconnected_devices + 1

    -- Start delete timer if necessary
    local remaining = math.floor(delete_timer:remaining() / 1000)
    if remaining < 0 or remaining > MIN_DELETE_TIMER_VALUE * 1000 then
      local delete_delay = get_interface_delete_delay(device.l3interface)
      if delete_delay >= 0 and (remaining < 0 or delete_delay < remaining) then
	if delete_delay > 0 and delete_delay < MIN_DELETE_TIMER_VALUE then
	  delete_delay = MIN_DELETE_TIMER_VALUE
	end
	delete_timer:set(delete_delay * 1000)
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
    type(msg['interface'])~="string" or
    (not (((type(msg['ipv4-address'])=="table") and type(msg['ipv4-address'].address)=="string" and match(msg['ipv4-address'].address, "%d+\.%d+\.%d+\.%d+"))
     or ((type(msg['ipv6-address'])=="table") and type(msg['ipv6-address'].address)=="string" and match(msg['ipv6-address'].address, "[%x:]+")) ))
    ) then
    log:info("Ignoring improper neigh event");
    return
  end

  local mac = lower(msg['mac-address']);
  local changed = false

  -- Filter out already known local devices
  if (localmacs[mac]) then
    return
  end

  -- Reset devices_linkdown as neighbour event can update l2interface
  if (msg.action ~= "add" and devices_linkdown[mac] ~= nil) then
    devices_linkdown[mac] = nil
  end

  -- Initialize L3 interface statistics if needed
  local l3interface = msg['interface']
  if not interfaces_data[l3interface] then
    interfaces_data[l3interface] = { connected_devices = 0, disconnected_devices = 0 }
  end

  -- Retrieve l3 port based on brctl commands
  local is_bridge_device = is_bridge(l3interface)
  local brctl_info = {}
  if (is_bridge_device == true) then
    brctl_info = brctl_showmac(l3interface, mac);
  end
  if brctl_info.islocal then
    -- Local devices are filtered-out
    localmacs[mac] = true
    if alldevices[mac] then
      local device = alldevices[mac]
      alldevices[mac] = nil
      if device.state == "connected" then
	interfaces_data[device.l3interface].connected_devices = interfaces_data[device.l3interface].connected_devices - 1
      else
	interfaces_data[device.l3interface].disconnected_devices = interfaces_data[device.l3interface].disconnected_devices - 1
      end
    end
    return
  end

  -- First time this device is seen? Add it
  if not alldevices[mac] then
    if msg.action ~= "add" or not can_allocate_device_on_interface(l3interface) then
      -- ignore :
      --   1) delete events for devices that were not tracked here
      --   2) add events for interfaces already at their max_devices_per_interface limit
      return
    end
    alldevices[mac]={["mac-address"]=mac, l3interface=l3interface, ipv4={}, ipv6={}}
    changed = true
  end

  -- Keep reference to our device in the table
  local device = alldevices[mac];

  -- Process and store l3 and logical interface names
  if device.l3interface ~= l3interface then
    if msg.action ~= "add" or not can_allocate_device_on_interface(l3interface) then
      -- ignore :
      --   1) delete events coming from other interfaces that the one currently used
      --   2) add events for interfaces already at their max_devices_per_interface limit
      return
    end
    -- l3interface changed, clean out previous IP address state,
    -- update previous l3interface stats and change the l3interface
    if device.state == "connected" then
      interfaces_data[device.l3interface].connected_devices = interfaces_data[device.l3interface].connected_devices - 1
    else
      interfaces_data[device.l3interface].disconnected_devices = interfaces_data[device.l3interface].disconnected_devices - 1
    end
    device.state = nil
    device.ipv4={}
    device.ipv6={}
    device.l3interface = l3interface
    changed = true
  end
  local logicalinterface = get_logical_interface_name(l3interface)
  if logicalinterface and device.interface ~= logicalinterface then
    device.interface = logicalinterface
    changed = true
  end

  -- Process and store the IP address(es)
  ismanageable = false
  for _, mode in ipairs(ip_modes) do
    local ipaddr = msg[mode .. '-address'];
    if (ipaddr~=nil and type(ipaddr.address)=="string") then
      changed = update_ip_state(l3interface, mac, lower(ipaddr.address), mode, msg.action, msg["conflicts-with"], msg.dhcp) or changed;
    end
  end

  local state
  local wireless_dev = false
  local radio = nil
  local ap_x = nil
  local ssid = nil
  local stai = nil

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
      l2interface = bridge_getport(l3interface, brctl_info.portno)
    else
      l2interface = l3interface
    end
    if device.l2interface ~= l2interface then
      device.l2interface = l2interface
      changed = true
    end
  end

  if device.l2interface ~= nil then
    wireless_dev, radio, ap_x, ssid, stai = is_wireless(device.l2interface, mac)
    if wireless_dev and stai.state then
      -- Received untrusted events but wireless device is ageing in 'brctl macshow' which makes device always be 'connected'.
      if stai.state == "Disconnected" then
	state = "disconnected"
      elseif string.match(stai.state, "Associated") then -- not all chipsets provide other states (authenticated, authorized ...)
	state = "connected"
      end
    end
  end

  if device.state ~= state then
    set_device_state(device, state)
    changed = true
  end

  -- Update host name if available
  if msg.hostname ~= nil and device.hostname ~= msg.hostname then
    device.hostname = msg.hostname
    changed = true
  end

  if (device.state == 'connected') then
    local technology
    local wireless
    if wireless_dev then
      technology = 'wireless'
      wireless = {
	radio = radio,
	accesspoint = ap_x,
	ssid = ssid,
	encryption = stai.encryption,
	authentication = stai.authentication,
	tx_phy_rate = stai.tx_phy_rate,
	rx_phy_rate = stai.rx_phy_rate,
      }
    else
      technology = 'ethernet'
    end
    if device.technology ~= technology or
       type(device.wireless) ~= type(wireless) or
       (wireless and
	(device.wireless.accesspoint ~= wireless.accesspoint or
	 device.wireless.ssid ~= wireless.ssid or
	 device.wireless.encryption ~= wireless.encryption or
	 device.wireless.authentication ~= wireless.authentication or
	 device.wireless.tx_phy_rate ~= wireless.tx_phy_rate or
	 device.wireless.rx_phy_rate ~= wireless.rx_phy_rate)) then
      device.technology = technology
      device.wireless = wireless
      changed = true
    end

    cursor:foreach('user_friendly_name', 'name', function(s)
      if(s['mac'] == mac) then
	if device['user-friendly-name'] ~= s['name'] or device['device-type'] ~= s['type'] then
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

-- Retrieve wireless ssid access point
--
-- Parameters:
-- - name: [string] ssid name
-- - aps: [number] ubus call wireless.accesspoint get {} reply
--
-- Returns:
-- - [string]
local function get_wireless_ssid_access_point(name, aps)
  for ap, attributes in pairs(aps) do
    if type(attributes) == "table" and attributes.ssid == name and attributes.oper_state == 1 then
      return ap
    end
  end

  return nil
end

-- Retrieve wireless ssid device name
--
-- Parameters:
-- - name: [string] ssid name
-- - attributes: [number] ssid attributes
--
-- Returns:
-- - [string]
local function get_wireless_ssid_interface(name, attributes)
  local interface = remote_radio_interfaces[attributes.radio]

  if interface then
    -- Remote radio case
    local vid = tonumber(attributes.vlan_id)
    if vid and vid > 0 then
      local section = "network"
      local vlan_interface

      local function read_config(s)
        local t = s["type"]
	if s[".type"] == "device" and s["type"] and
	   s["ifname"] == interface and tonumber(s["vid"]) == vid and
	  (t:lower() == "8021q" or t:lower() == "8021ad") then
	  vlan_interface = s[".name"]
	end
      end

      cursor:load(section)
      cursor:foreach(section, "device", read_config)
      cursor:unload(section)

      if vlan_interface then
	interface = vlan_interface
      else
	interface = interface .. "." .. tostring(vid)
      end
    end
  else
    -- Usual case, in which interface name matches ssid name
    interface = name
  end

  return interface
end

-- Do full wireless status scan
local function scan_full_wireless_status()
  -- Retrieve the wireless status
  local remote_radios = ubus_conn:call("wireless.radio.remote", "get", {}) or {}
  local ssids = ubus_conn:call("wireless.ssid", "get", {})
  local aps = ubus_conn:call("wireless.accesspoint", "get", {})
  if type(remote_radios) ~= "table" or type(ssids) ~= "table" or type(aps) ~= "table" then
    return nil
  end

  -- Cache interfaces of remote radios
  remote_radio_interfaces = {}
  for r, rv in pairs(remote_radios) do
    if type(rv) == "table" then
      remote_radio_interfaces[r] = rv.ifname
    end
  end

  -- Cache information about operational ssids
  active_wireless_ssids = {}
  for s, sv in pairs(ssids) do
    if type(sv) == "table" and sv.oper_state == 1 then
      local accesspoint = get_wireless_ssid_access_point(s, aps)
      if accesspoint then
	active_wireless_ssids[s] = {
	  radio = sv.radio,
	  accesspoint = accesspoint,
	  interface = get_wireless_ssid_interface(s, sv),
	}
      end
    end
  end

  deferred_wireless_status_scan = nil
  return true
end

-- some hosts, no "keep-alive" network.neigh events.
-- if lost (e.g. restart hostmanager), scan them from "network.neigh cachedstatus"
local function scan_network_neigh_cachedstatus()
  local x=ubus_conn:call("network.neigh", "cachedstatus", {})
  if type(x)== "table" and type(x.neigh) == "table" then
    for _,v in ipairs(x.neigh) do
      if (v["action"] == "add" and type(v["mac-address"]) == "string" and match(v["mac-address"], "%x%x:%x%x:%x%x:%x%x:%x%x:%x%x")) then
	handle_device_update(v)
      end
    end
  end
end

-- Handles a wireless.radio event on UBUS
--
-- Parameters:
-- - msg: [table] the UBUS message
local function handle_wireless_radio_update(msg)
  -- Reject bad events
  if type(msg)~="table" or
    type(msg["name"])~="string" then
    log:info("Ignoring improper wireless radio event");
    return
  end

  if msg["event"] == "added" then
    scan_full_wireless_status()
  end
end

-- Handles a wireless.ssid event on UBUS
--
-- Parameters:
-- - msg: [table] the UBUS message
local function handle_wireless_ssid_update(msg)
  -- Reject bad events
  if type(msg)~="table" or
    type(msg["name"])~="string" or
    not msg["oper_state"] then
    log:info("Ignoring improper wireless ssid event");
    return
  end

  -- Do full status scan at startup
  if deferred_wireless_status_scan then
    scan_full_wireless_status()
    return
  end

  local name = msg["name"]
  local oper_state = msg["oper_state"]

  -- Do the incremental status update
  active_wireless_ssids[name] = nil
  if oper_state ~= 1 then
    return
  end

  local ssids = ubus_conn:call("wireless.ssid", "get", { name = name })
  local aps = ubus_conn:call("wireless.accesspoint", "get", {})
  if type(ssids) ~= "table" or type(aps) ~= "table" then
    log:info("Ignoring wireless ssid event due to invalid wireless ubus call result");
    return
  end

  for s, sv in pairs(ssids) do
    if s == name and type(sv) == "table" and sv.oper_state == 1 then
      local accesspoint = get_wireless_ssid_access_point(s, aps)
      if accesspoint then
	active_wireless_ssids[s] = {
	  radio = sv.radio,
	  accesspoint = accesspoint,
	  interface = get_wireless_ssid_interface(s, sv),
	}
      end
      return
    end
  end
end

-- Handles a wireless.accesspoint.station event on UBUS
--
-- Parameters:
-- - msg: [table] the UBUS message
local function handle_wireless_station_update(msg)
  -- Reject bad events
  if type(msg)~="table" or
    type(msg["ap_name"])~="string" or
    type(msg["macaddr"])~="string" or
    type(msg["state"])~="string" then
    log:info("Ignoring improper wireless station event")
    return
  end

  local changed = false
  local mac = lower(msg["macaddr"])
  local device = alldevices[mac]

  -- Filter out wireless events for unknown devices
  if device == nil then
    log:info("Ignoring wireless station event for unknown device")
    return
  end

  -- Handle station disconnects coming from access point
  if msg["state"] == "Disconnected" and device.wireless then
    if device.wireless.accesspoint == msg["ap_name"] then
      if device.state == "connected" then
        set_device_state(device, "disconnected")
        -- Publish our enriched device object over UBUS
        ubus_conn:send('hostmanager.devicechanged', transform_device_to_ubus_message(device))
      end
    else
      log:info("Ignoring wireless station disconnected event received from different access point")
    end
    return
  end

  -- Find l2interface coresponding to this access point
  local l2interface
  for s, sv in pairs(active_wireless_ssids) do
    if sv.accesspoint == msg["ap_name"] then
      l2interface = sv.interface
      break
    end
  end
  if not l2interface then
    log:info("Ignoring wireless station event received from untracked access point")
    return
  end

  local wireless_dev, radio, ap_x, ssid, stai = is_wireless(l2interface, mac)
  if not wireless_dev then
    log:info("Ignoring wireless station event for non-wireless device")
    return
  end

  local state = device.state
  if stai.state then
    if stai.state == "Disconnected" then
      state = "disconnected"
    elseif string.match(stai.state, "Associated") then -- not all chipsets provide other states (authenticated, authorized ...)
      state = "connected"
    end
  end

  if device.l2interface ~= l2interface then
    if device.l2interface == device.l3interface then
      log:info("Ignoring wireless station event due to interface change in a non-bridge context")
      return
    end
    if not is_interface_bridge_port(l2interface, device.l3interface) then
      log:info("Ignoring wireless station event due to " .. tostring(l2interface) .. " not being attached to " .. tostring(device.l3interface) .. " bridge")
      return
    end
    device.l2interface = l2interface
    changed = true
  end

  if device.technology ~= "wireless" then
    device.technology = "wireless"
    changed = true
  end

  local wireless = {
    radio = radio,
    accesspoint = ap_x,
    ssid = ssid,
    encryption = stai.encryption,
    authentication = stai.authentication,
    tx_phy_rate = stai.tx_phy_rate,
    rx_phy_rate = stai.rx_phy_rate,
  }
  if not device.wireless or
     device.wireless.radio ~= wireless.radio or
     device.wireless.accesspoint ~= wireless.accesspoint or
     device.wireless.ssid ~= wireless.ssid or
     device.wireless.encryption ~= wireless.encryption or
     device.wireless.authentication ~= wireless.authentication or
     device.wireless.tx_phy_rate ~= wireless.tx_phy_rate or
     device.wireless.rx_phy_rate ~= wireless.rx_phy_rate then
    device.wireless = wireless
    changed = true
  end

  if device.state ~= state then
    set_device_state(device, state)
    changed = true
  end

  -- Publish our enriched device object over UBUS
  if changed then
    ubus_conn:send('hostmanager.devicechanged', transform_device_to_ubus_message(device))
  end
end

-- Update l2interface by brctl_info
local function update_l2interface()
  for mac, l3interface in pairs(devices_linkdown) do
    local brctl_info = brctl_showmac(l3interface, mac)
    local l2interface = brctl_info.portno and bridge_getport(l3interface, brctl_info.portno) or ""
    if l2interface ~= "" then
      devices_linkdown[mac] = nil
      if l2interface ~= alldevices[mac]["l2interface"] then
        alldevices[mac]["l2interface"] = l2interface
        -- Publish device change over UBUS
        ubus_conn:send('hostmanager.devicechanged', transform_device_to_ubus_message(alldevices[mac]))
      end
    end
  end
end

-- Callback function when 'hostmanager.device reload' is called
local function handle_rpc_reload(req)
  log:info("Reloading configuration");
  load_configuration()

  -- Line up alldevices entries with the new max_devices_per_interface policies
  for l3interface, _ in pairs(interfaces_data) do
    can_allocate_device_on_interface(l3interface)
  end
  scan_network_neigh_cachedstatus()

  -- Reset delete timer
  delete_timer:set(0)

  ubus_conn:reply(req, {})
end

-- Callback function when 'hostmanager.device status' is called
--
-- Parameters:
-- - req: parameter to be passed to the UBUS reply
-- - response: [table] the response to be formatted using JSON
local function handle_rpc_status(req)
  local transformed_response = {
    global = global_policy,
    interfaces = interfaces_data,
    delete_timer_remaining = math.floor(delete_timer:remaining() / 1000),
    deferred_wireless_status_scan = deferred_wireless_status_scan,
    remote_radio_interfaces = remote_radio_interfaces,
    active_wireless_ssids = active_wireless_ssids,
  }

  ubus_conn:reply(req, transformed_response);
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
  if response then
    ubus_conn:reply(req,response)
  else
    log:error("set is allowed only for the already connected devices")
  end
end

local function handle_rpc_delete(req, msg)
  local mac = msg['mac-address']

  if (type(mac) == "string") then
    mac = lower(mac)
    local device = alldevices[mac]
    if device and device.state == "disconnected" then
      log:info("Delete device " .. mac)
      ubus_conn:send('hostmanager.devicedeleted', transform_device_to_ubus_message(device))
      alldevices[mac] = nil
      -- Update interface stats
      local interface_stats = interfaces_data[device.l3interface]
      interface_stats.disconnected_devices = interface_stats.disconnected_devices - 1
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

-- Handles a link event on UBUS
--
-- Parameters:
-- - msg: [table] the UBUS message
local function handle_device_link(msg)
  local interface, action, bridge

  -- Reject bad events
  if (type(msg)~="table" or
       type(msg['interface'])~="string" or
       type(msg['action'])~="string") then
    log:info("Ignoring improper event");
    return
  end

  interface = msg['interface']
  action = msg['action']
  bridge = get_bridge_from_if(interface)

  if action ~= "down" then
    local ipv4_mode = { "ipv4" }
    if bridge == "" then
      -- Probe all devices disconnected from this L3 interface that have a static IPv4 address
      probe_selected_interface_devices(interface, ipv4_mode, ip_static_state_disconnected)
    else
      -- Probe all devices disconnected from this L2 interface that have a static IPv4 address
      probe_selected_bridge_devices(bridge, interface, ipv4_mode, ip_static_state_disconnected)

      -- Bridge may need a few seconds to learn the mac, such as 3 seconds
      -- After that, do update_l2interface()
      devices_linkdown_timer:set(3000)
    end
    return
  end

  if bridge ~= "" then
    -- Probe all devices connected on this L2 interface
    probe_selected_bridge_devices(bridge, interface, ip_modes, ip_state_connected)
  end
end

-- Main code
uloop.init();
ubus_conn = ubus.connect()
if not ubus_conn then
  log:error("Failed to connect to ubus")
end
delete_timer = uloop.timer(timeout_delete)
devices_linkdown_timer = uloop.timer(update_l2interface)

-- Read configuration
load_configuration()

-- Register RPC callback
ubus_conn:add( { ['hostmanager'] = { reload = { handle_rpc_reload, { } },
				     status = { handle_rpc_status, { } } },
		 ['hostmanager.device'] = { get = { handle_rpc_get , {["mac-address"] = ubus.STRING, ["ipv4-address"] = ubus.STRING, ["ipv6-address"] = ubus.STRING } },
					    set = { handle_rpc_set, {["mac-address"] = ubus.STRING, ["user-friendly-name"] = ubus.STRING, ["device-type"] = ubus.STRING } },
					    delete = { handle_rpc_delete, {["mac-address"] = ubus.STRING } }, } } )


-- Register event listener
ubus_conn:listen({ ['network.neigh'] = handle_device_update,
                   ['network.link'] = handle_device_link,
                   ['wireless.radio'] = handle_wireless_radio_update,
                   ['wireless.ssid'] = handle_wireless_ssid_update,
                   ['wireless.accesspoint.station'] = handle_wireless_station_update, } )

scan_full_wireless_status()
scan_network_neigh_cachedstatus()

-- Idle loop
xpcall(uloop.run,errhandler)
