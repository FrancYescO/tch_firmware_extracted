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
local upper = string.upper
local find = string.find
local gsub = string.gsub
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
local LINKDOWN_TIMER_VALUE = 3 -- seconds
local MAX_LINKDOWN_RETRIES = 5 -- seconds
local WIRELESS_REPEATER_DISCOVERY_TIMEOUT = 30 -- seconds
local global_policy = { delete_delay = -1, max_devices_per_interface = -1 }
local interfaces_data = { }
local delete_timer = nil
local devices_linkdown_timer = nil
local devices_linkdown_trial = 0


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
local connected_wireless_repeaters = {}
local new_wireless_repeaters = {}
local wireless_repeater_discovery_timer = nil

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
      local _, _, value, unit = find(s["delete_delay"], "^(%d+)([smhdw]?)$")
      value = tonumber(value)
      if value then
	if value < 0 then
	  t["delete_delay"] = -1
	elseif unit == "w" then
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
	if t["delete_delay"] > 2147483 then
	  log:error("limit delete_delay to 2147483 seconds")
	  t["delete_delay"] = 2147483
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

  return bridge or ""
end

-- Probe a specific host address
--
-- Parameters:
-- - interface: [string] interface towards the host
-- - macaddress: [string] MAC address of the host
-- - iptype: [string] Type of the IP address (ipv4 or ipv6)
-- - ipaddress: [string] IP address of the host
local function probe_address(interface, macaddress, iptype, ipaddress)
  log:info("Probing device " .. macaddress .. " IP address " .. ipaddress .. " on interface " .. interface);
  ubus_conn:call("network.neigh", "probe", {
		      ["interface"]=interface,
		      ["mac-address"]=macaddress,
		      [iptype.."-address"]=ipaddress})
end

-- Probe all connected and stalled IP addresses of a device
--
-- Parameters:
-- - device: [table] the device entry
local function probe_device_addresses(device)
  local mac = device["mac-address"]
  local l3interface = device["l3interface"]
  for _, mode in ipairs(ip_modes) do
    for _, ip in pairs(device[mode]) do
      if ip.state == "connected" or ip.state == "stale" then
	probe_address(l3interface, mac, mode, ip.address)
      end
    end
  end
end

-- Retrieve wireless.accesspoint.station information
--
-- Parameters:
-- - interface: [string] interface name (e.g. wl0)
-- - macaddress: [string] the MAC address of the device
--
-- Returns:
-- - nil if no information was found
-- - otherwise [boolean] true, [string] radio name, [string] access point name, [string] ssid name, [table] wireless station information
local function get_wireless_station_data(interface, macaddress)
  local radio, accesspoint, ssid, stai

  for s, sv in pairs(active_wireless_ssids) do
    if sv.interface == interface then
      if sv.accesspoint then -- wireless interface is in ap mode
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
	      stai.parent = sv.bssid
	      stai.SSID = sv.ssid
	      return true, radio, accesspoint, ssid, stai
	    end
	  end
	end
      else -- wireless interface is in sta mode
	radio = sv.radio
	accesspoint = nil
	ssid = sv.interface
	stai = { state = "Associated", parent = sv.bssid, SSID = sv.ssid }
	return true, radio, accesspoint, ssid, stai
      end
    end
  end

  return nil
end

-- Checks if wireless station is active in  multiap.controller.station data model
-- and return its BSSID field (Multiap support)
--
-- Parameters:
-- - macaddress: [string] the MAC address of the device
--
-- Returns:
-- - BSSID value if station is present
-- - nil otherwise
local function get_map_agent_station_bssid(macaddress)
  local reply = ubus_conn:call("multiap.controller.station", "list", { macaddr = lower(macaddress) }) or {}
  for _, sv in pairs(reply) do
    if type(sv) == "table" and sv.associated_bssid_mac then
      return lower(sv.associated_bssid_mac)
    end
  end

  return nil
end

-- Scan multiap.controller.agent_info info (Multiap support)
--
-- Returns:  nil
local function scan_map_agent_data(macaddress)
  local repeater_id, repeater_connectiontype, repeater_parent, repeater_macaddr
  local bssids = {}

  -- Extract the repeater identifiers
  local reply = ubus_conn:call("multiap.controller.agent_info", "get", {}) or {}
  local has_repeaters
  for id, sv in pairs(reply) do
    bssids = {}
    if (type(sv) == "table" and type(sv.radio_count) == "number" and sv.radio_count > 0 and
      type(sv.backhaul_connection_type) == "string" and sv.backhaul_connection_type ~= "") then
      new_wireless_repeaters[id] = true
      has_repeaters = true
    end
  end
  if has_repeaters then
    wireless_repeater_discovery_timer:set(WIRELESS_REPEATER_DISCOVERY_TIMEOUT * 1000)
  end
end

-- Checks if MAC address is listed multiap.controller.agent_info data model
-- and return the repeater MAC address along with all its BSSIDs (Multiap support)
--
-- Parameters:
-- - macaddress: [string] the MAC address of the device
--
-- Returns:
-- - repeater ID, connection type, parent, MAC address, bssids_array
local function get_map_agent_data(macaddress)
  local repeater_id, repeater_connectiontype, repeater_parent, repeater_macaddr
  local bssids = {}
  local mac_list = {}

  -- Extract the repeater MAC address that identify its wireless station
  -- along with all its BSSIDs
  local reply = ubus_conn:call("multiap.controller.agent_info", "get", {}) or {}
  local station_list = ubus_conn:call("multiap.controller.station", "list", {}) or {}
  for id, sv in pairs(reply) do
    bssids = {}
    if type(sv) == "table" and type(id) == "string" then
      local rv = sv.radio_info or {}
      for idx, av in pairs(rv) do
        if lower(idx) == macaddress then
          mac_list = sv.local_interfaces
        end
        if not next(mac_list) and type(av) == "table" then
          for index in pairs(av.bss_info or {}) do
            local bssid = index and lower(index)
            bssids[bssid] = true
            if bssid == macaddress then
              mac_list = sv.local_interfaces
              break
            end
          end
        end
        if next(mac_list) then
          break
        end
      end
    end
    for _, mac in pairs(mac_list) do
      for station_mac in pairs(station_list) do
         if mac == station_mac then
           repeater_macaddr = mac
           break
         end
      end
      if repeater_macaddr then
        break
      end
    end
    if repeater_macaddr then
      repeater_id = id
      repeater_connectiontype = lower(sv.backhaul_connection_type)
      repeater_parent = lower(sv.parent)
      break
    end
  end

  local repeater_bssids = {}
  for bssid, _ in pairs(bssids) do
    repeater_bssids[#repeater_bssids + 1] = bssid
  end

  return repeater_id, repeater_connectiontype, repeater_parent, repeater_macaddr, repeater_bssids
end

-- Removes wireless repeater cached state (Multiap support)
--
-- Parameters:
-- - macaddress: [string] the MAC address of the repeater
--
-- Returns:
-- - nil
local function flush_repeater_state(macaddress)
  local repeater = connected_wireless_repeaters[macaddress]
  if type(repeater) == "table" then
    connected_wireless_repeaters[macaddress] = nil
    connected_wireless_repeaters[repeater.station] = nil
    connected_wireless_repeaters[repeater.mapid] = nil
    for _, bssid in ipairs(repeater.bssid) do
      connected_wireless_repeaters[bssid] = nil
    end
    if connected_wireless_repeaters[repeater.interface] == macaddress then
      -- Promote other repeater as interface owner
      local intf_repeater
      for other_mac, other_entry in pairs(connected_wireless_repeaters) do
	if type(other_entry) == "table" and other_entry.interface == repeater.interface then
	  intf_repeater = other_mac
	  break
	end
      end
      connected_wireless_repeaters[repeater.interface] = intf_repeater
    end

    -- Probe all connected & stalled IPs of the disconnecting repeater
    local device = alldevices[macaddress]
    if device then
      probe_device_addresses(device)
    end

    -- This might be temporary, re-add the repeater to the list of repeaters to be discovered
    new_wireless_repeaters[repeater.mapid] = true
    wireless_repeater_discovery_timer:set(WIRELESS_REPEATER_DISCOVERY_TIMEOUT * 1000)
  end
end

-- Retrieve multiap.controller.agent_info information (Multiap support)
--
-- Parameters:
-- - interface: [string] interface name (e.g. wl0)
-- - macaddress: [string] the MAC address of the device
--
-- Returns:
-- - nil if no information was found
-- - otherwise [boolean] true, [string] radio name, [string] access point name, [string] ssid name, [table] wireless station information
local function get_map_agent_station_data(interface, macaddress)
  -- Reset macaddress extender cached state if interface changed
  if type(connected_wireless_repeaters[macaddress]) == "table" and connected_wireless_repeaters[macaddress].interface ~= interface then
    flush_repeater_state(macaddress)
  end

  -- WDS repeaters use interface names "wdsX_Y" where X s the part  from ssid interface wlX
  -- and Y represents the repeater numeric ID
  local _, _, id = find(interface, "^wds([_%d]+)_%d+$")
  if id == nil then
    if connected_wireless_repeaters[macaddress] == nil and next(new_wireless_repeaters) then
      -- Learn extenders connected via Ethernet
      local repeater_id, repeater_conntype, repeater_parent, repeater_macaddr, repeater_bssids = get_map_agent_data(macaddress)
      if repeater_macaddr then
	-- Cache repeaters state
	local repeater = {
	  interface = interface,
	  mapid = repeater_id,
	  conntype = repeater_conntype,
	  parent = repeater_parent,
	  station = repeater_macaddr,
	  bssid = repeater_bssids,
	}
	connected_wireless_repeaters[repeater_macaddr] = macaddress
	connected_wireless_repeaters[repeater_id] = macaddress
	for _, bssid in ipairs(repeater_bssids) do
	  connected_wireless_repeaters[bssid] = macaddress
	end
	connected_wireless_repeaters[macaddress] = repeater
	new_wireless_repeaters[repeater_id] = nil

	-- Repeater is connected to this interface
	if connected_wireless_repeaters[interface] == nil then
	  connected_wireless_repeaters[interface] = macaddress
	end
      end
    end

    -- Verify if device is an extender connected on this Ethernet interface
    if type(connected_wireless_repeaters[macaddress]) == "table" then
      local repeater = connected_wireless_repeaters[macaddress]
      local result, radio, accesspoint, ssid
      local stai = {}
      if repeater.interface == interface and repeater.conntype ~= "ethernet" then
	result = true
	stai.parent = repeater.parent
	stai.station = repeater.station
      end
      return result, radio, accesspoint, ssid, stai
    end

    -- Verify if device is connected through an extender connected on this Ethernet interface
    if (type(connected_wireless_repeaters[interface]) == "string" and
        type(connected_wireless_repeaters[connected_wireless_repeaters[interface]]) == "table") then
      local result, radio, accesspoint, ssid
      local stai = {}
      stai.parent = get_map_agent_station_bssid(macaddress)
      if stai.parent then
	result = true
	return result, radio, accesspoint, ssid, stai
      end
    end

    return nil
  end

  local wlinterface = "wl" .. gsub(id, "_0$", "") -- special case wdsX_0_Y corresponds to wlX, not wlX_0
  local ssid_entry = active_wireless_ssids[wlinterface]
  if ssid_entry == nil then
    return nil
  end

  local repeater_macaddr = connected_wireless_repeaters[interface]
  if (macaddress ~= repeater_macaddr and type(repeater_macaddr) == "string" and
      type(connected_wireless_repeaters[repeater_macaddr]) == "table") then
    -- Use local cache first
    local repeater = connected_wireless_repeaters[repeater_macaddr]
    local result, radio, accesspoint, ssid, stai = get_wireless_station_data(repeater.wlinterface, repeater.station)
    if result and
      stai.state and match(stai.state, "Associated") and
      stai.flags and match(stai.flags, "Repeater") then
      stai.station = repeater.station
      if repeater_macaddr ~= macaddress then
	stai.parent = nil
	if type(connected_wireless_repeaters[macaddress]) == "table" then
	  -- This is an extender daisy chained to another extender
	  stai.parent = connected_wireless_repeaters[macaddress].parent
	elseif connected_wireless_repeaters[macaddress] == nil and next(new_wireless_repeaters) then
	  -- Learn daisy chained extenders
	  local repeater_id, repeater_conntype, repeater_parent, repeater_macaddr, repeater_bssids = get_map_agent_data(macaddress)

	  if repeater_macaddr then
	    -- Cache repeaters state
	    repeater = {
	      radio = ssid_entry.radio,
	      accesspoint = ssid_entry.accesspoint,
	      ssid = ssid_entry.ssid,
	      interface = interface,
	      wlinterface = wlinterface,
	      mapid = repeater_id,
	      conntype = repeater_conntype,
	      parent = repeater_parent,
	      station = repeater_macaddr,
	      bssid = repeater_bssids,
	    }
	    connected_wireless_repeaters[repeater_macaddr] = macaddress
	    connected_wireless_repeaters[repeater_id] = macaddress
	    for _, bssid in ipairs(repeater_bssids) do
	      connected_wireless_repeaters[bssid] = macaddress
	    end
	    connected_wireless_repeaters[macaddress] = repeater
	    new_wireless_repeaters[repeater_id] = nil

	    stai.parent = repeater_parent
	  end
	end
	if not stai.parent then
	  stai.parent = get_map_agent_station_bssid(macaddress)
	end
	if not stai.parent then
	  stai.state = "Disconnected"
	end
      end
      return result, radio, accesspoint, ssid, stai
    else
      -- Remove cache entry no longer in line with wireless state
      flush_repeater_state(repeater_macaddr)
    end
  else
    -- macaddress belong to the extender that owns the wds interface
    local repeater = connected_wireless_repeaters[macaddress]
    if repeater == nil and next(new_wireless_repeaters) then
      -- Learn extenders connected via wireless
      local repeater_id, repeater_conntype, repeater_parent, repeater_macaddr, repeater_bssids = get_map_agent_data(macaddress)

      if repeater_macaddr then
	-- Cache repeaters state
	repeater = {
	  radio = ssid_entry.radio,
	  accesspoint = ssid_entry.accesspoint,
	  ssid = ssid_entry.ssid,
	  interface = interface,
	  wlinterface = wlinterface,
	  mapid = repeater_id,
	  conntype = repeater_conntype,
	  parent = repeater_parent,
	  station = repeater_macaddr,
	  bssid = repeater_bssids,
	}
	connected_wireless_repeaters[repeater_macaddr] = macaddress
	connected_wireless_repeaters[repeater_id] = macaddress
	for _, bssid in ipairs(repeater_bssids) do
	  connected_wireless_repeaters[bssid] = macaddress
	end
	connected_wireless_repeaters[macaddress] = repeater
	new_wireless_repeaters[repeater_id] = nil
      end
    end
    if type(repeater) == "table" then
      local result, radio, accesspoint, ssid, stai = get_wireless_station_data(wlinterface, repeater.station)
      if result and
	stai.state and match(stai.state, "Associated") and
	stai.flags and match(stai.flags, "Repeater") then

	connected_wireless_repeaters[interface] = macaddress

	stai.station = repeater.station
	return result, radio, accesspoint, ssid, stai
      else
	local reason
	if not result then
	  reason = repeater.station .. " not a wireless station on interface " .. wlinterface
	elseif not stai.state or not match(stai.state, "Associated") then
	  reason = "Associated state not set"
	else
	  reason = "Repeater flag not set"
	end
	log:error("Failed to set " .. macaddress .. " as " .. interface .. " repeater: " .. reason)
      end
    else -- Multiap is disabled or not installed, return the limited bit of information deduced from wds interface name
      local result, radio, accesspoint, ssid, stai = true, ssid_entry.radio, ssid_entry.accesspoint, wlinterface,
						     { parent = ssid_entry.bssid, SSID = ssid_entry.ssid }
      return result, radio, accesspoint, ssid, stai
    end
  end

  return nil
end

-- Determines whether a certain MAC address belongs to a wireless device
--
-- Parameters:
-- - interface: [string] interface name (e.g. wl0)
-- - macaddress: [string] the MAC address of the device
--
-- Returns:
-- - nil if no information was found
-- - otherwise [boolean] true, [string] radio name, [string] access point name, [string] ssid name, [table] wireless station information
local function is_wireless(interface, macaddress)
  local result, radio, accesspoint, ssid, stai = get_wireless_station_data(interface, macaddress)
  if result then
    return result, radio, accesspoint, ssid, stai
  end

  result, radio, accesspoint, ssid, stai = get_map_agent_station_data(interface, macaddress)
  if result then
    return result, radio, accesspoint, ssid, stai
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
-- - action: [string] add, stale or delete
-- - conflictingmac: [string] the MAC address of the device conflicting with this address
-- - dhcp: [table] containing DHCP information, nil if static config
-- Returs:
-- - [boolean] true if device state has changed
local function update_ip_state(l3interface, mac, address, mode, action, conflictingmac, dhcp)
  local changed = false
  local device = alldevices[mac]
  local iplist = device[mode];
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
      for _,key in ipairs({
	   "vendor-class" ,
	   "tags" ,
	   "manufacturer-oui" ,
	   "serial-number" ,
	   "product-class",
	   "requested-options"
	   }) do
	if dhcp[key] ~= ipentry.dhcp[key] then
	   ipentry.dhcp[key]= dhcp[key]
	   changed = true
	end
      end
      if type(dhcp["time-remaining"]) == "number" then
	local expiration = os.time() + tonumber(dhcp["time-remaining"])
	if expiration ~= ipentry.dhcp["expiration-time"] then
	  ipentry.dhcp["expiration-time"] = expiration
	  changed = true
	end
      elseif ipentry.dhcp["expiration-time"] ~= nil then
	ipentry.dhcp["expiration-time"] = nil
	changed = true
      end
      if ipentry.dhcp.state ~= "connected" then
	ipentry.dhcp.state = "connected"
	changed = true

	-- This is a good indication that the device is online again, possibly connected with a different address
	-- Probe all its connected & stalled addresses
	probe_device_addresses(device)

	if ipentry.state == "disconnected" then
	  probe_address(l3interface, mac, mode, address)
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
  elseif action == "delete" then
    if dhcp then
      if ipentry.dhcp and ipentry.dhcp.state == "connected" then
	ipentry.dhcp.state = "disconnected"
	ipentry.dhcp["expiration-time"] = nil
	changed = true

	if mode == "ipv4" then
	  -- This is a good indication that the device went offline
	  -- Probe all its connected & stalled addresses
	  probe_device_addresses(device)
	elseif ipentry.state ~= "disconnected" then
	  probe_address(l3interface, mac, mode, address)
	end
      end
    elseif ipentry.state ~= "disconnected" then
      ipentry.state = "disconnected"
      changed = true
    end
  elseif action == "stale" and ipentry.state ~= action then
    ipentry.state = "stale"
    changed = true
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
  local reset_linkdown_timer

  for mac, device in pairs(alldevices) do
    if (device.l2interface == interface) then
      -- Device's l2interface needs update, mark it
      devices_linkdown[mac] = bridge
      reset_linkdown_timer = true
      for _, mode in ipairs(ip_modes) do
	for _, ip in pairs(device[mode]) do
	  if ipentry_selector(ip) then
	    probe_address(bridge, mac, mode, ip.address)
	  end
	end
      end
    end
  end

  if reset_linkdown_timer then
    -- Bridge may need a few seconds to learn the mac
    -- After that, do update_l2interface()
    device_linkdown_trial = 0
    devices_linkdown_timer:set(LINKDOWN_TIMER_VALUE * 1000)
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
	    probe_address(interface, mac, mode, ip.address)
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

    -- Probe all connected & stalled IPs of the disconnecting device
    probe_device_addresses(device)

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
    (msg['action']~='add' and msg['action']~='delete' and msg['action']~='stale') or
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
	if j.state == "connected" or j.state == "stale" then
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
      if l2interface == "" then
	-- Bridge may need a few seconds to learn the mac
	-- After that, do update_l2interface()
	devices_linkdown[mac] = l3interface
	device_linkdown_trial = 0
	devices_linkdown_timer:set(LINKDOWN_TIMER_VALUE * 1000)
      end
    else
      l2interface = l3interface
    end
    if device.l2interface ~= l2interface then
      device.l2interface = l2interface
      changed = true
    end
  end

  if device.l2interface ~= nil and device.l2interface ~= "" then
    wireless_dev, radio, ap_x, ssid, stai = is_wireless(device.l2interface, mac)
    if wireless_dev and stai.state then
      -- Received untrusted events but wireless device is ageing in 'brctl macshow' which makes device always be 'connected'.
      if stai.state == "Disconnected" then
	state = "disconnected"
      elseif stai.state and match(stai.state, "Associated") then -- not all chipsets provide other states (authenticated, authorized ...)
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
	parent = stai.parent,
	SSID = stai.SSID,
	station = stai.station,
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
	(device.wireless.radio ~= wireless.radio or
	 device.wireless.accesspoint ~= wireless.accesspoint or
	 device.wireless.ssid ~= wireless.ssid or
	 device.wireless.parent ~= wireless.parent or
	 device.wireless.SSID ~= wireless.SSID or
	 device.wireless.station ~= wireless.station or
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

-- Retrieve wireless ssid access point (for mode=ap ssids)
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

-- Retrieve wireless ssid end point (for mode=sta ssids)
--
-- Parameters:
-- - name: [string] ssid name
-- - endpoints: [number] ubus call wireless.endpoint get {} reply
--
-- Returns:
-- - [string]
local function get_wireless_ssid_end_point(name, endpoints)
  for ep, attributes in pairs(endpoints) do
    if type(attributes) == "table" and attributes.ssid == name and attributes.connected_state == 1 then
      return ep
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
  local endpoints = ubus_conn:call("wireless.endpoint", "get", {}) or {}
  if type(remote_radios) ~= "table" or type(ssids) ~= "table" or type(aps) ~= "table" or type(endpoints) ~= "table" then
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
    if type(sv) == "table" and (sv.oper_state == 1 or sv.mode == "sta") then
      local accesspoint = (sv.mode ~= "sta" and get_wireless_ssid_access_point(s, aps) or nil)
      local endpoint = (sv.mode == "sta" and get_wireless_ssid_end_point(s, endpoints) or nil)
      if accesspoint or endpoint then
	active_wireless_ssids[s] = {
	  radio = sv.radio,
	  bssid = sv.bssid,
	  ssid = sv.ssid,
	  mode = sv.mode,
	  accesspoint = accesspoint,
	  endpoint = endpoint,
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

-- Timeout function for wireless repeater discovery (Multiap support)
local function timeout_wireless_repeater_discovery()
  -- Force a complete network rescan to cache info about all extenders that were not yet
  if next(new_wireless_repeaters) then
    log:info("Repeater discovery timeout, rescan all network neighbors")
    scan_network_neigh_cachedstatus()
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
  local endpoints = ubus_conn:call("wireless.endpoint", "get", {}) or {}
  if type(ssids) ~= "table" or type(aps) ~= "table" or type(endpoints) ~= "table" then
    log:info("Ignoring wireless ssid event due to invalid wireless ubus call result");
    return
  end

  for s, sv in pairs(ssids) do
    if s == name and type(sv) == "table" and (sv.oper_state == 1 or sv.mode == "sta") then
      local accesspoint = (sv.mode ~= "sta" and get_wireless_ssid_access_point(s, aps) or nil)
      local endpoint = (sv.mode == "sta" and get_wireless_ssid_end_point(s, endpoints) or nil)
      if accesspoint or endpoint then
	active_wireless_ssids[s] = {
	  radio = sv.radio,
	  bssid = sv.bssid,
	  ssid = sv.ssid,
	  mode = sv.mode,
	  accesspoint = accesspoint,
	  endpoint = endpoint,
	  interface = get_wireless_ssid_interface(s, sv),
	}
      end
      return
    end
  end
end

-- Handles a wireless.endpoint event on UBUS
--
-- Parameters:
-- - msg: [table] the UBUS message
local function handle_wireless_endpoint_update(msg)
  -- Reject bad events
  if type(msg)~="table" or
    type(msg["ep_name"])~="string" or
    not msg["state"] then
    log:info("Ignoring improper wireless endpoint event");
    return
  end

  -- Do full status scan at startup
  if deferred_wireless_status_scan then
    scan_full_wireless_status()
    return
  end

  local name = msg["ep_name"]
  local state = msg["state"]

  -- Do the incremental status update
  active_wireless_ssids[name] = nil

  local ssids = ubus_conn:call("wireless.ssid", "get", { name = name })
  local endpoints = ubus_conn:call("wireless.endpoint", "get", {}) or {}
  if type(ssids) ~= "table" or type(endpoints) ~= "table" then
    log:info("Ignoring wireless endpoint event due to invalid wireless ubus call result");
    return
  end

  for s, sv in pairs(ssids) do
    if s == name and type(sv) == "table" and sv.mode == "sta" then
      local endpoint = get_wireless_ssid_end_point(s, endpoints)
      if endpoint then
	active_wireless_ssids[s] = {
	  radio = sv.radio,
	  bssid = sv.bssid,
	  ssid = sv.ssid,
	  mode = sv.mode,
	  endpoint = endpoint,
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
  local accesspoint = msg["ap_name"]
  local mac = lower(msg["macaddr"])
  local l2interface
  local device = alldevices[mac]

  -- If there is no such station, look up for it in the repeater cache
  if device == nil then
    local repeater_macaddr = connected_wireless_repeaters[mac]
    if type(repeater_macaddr) == "string" then
      local repeater = connected_wireless_repeaters[repeater_macaddr]
      if type(repeater) == "table" and repeater.accesspoint == accesspoint and repeater.station == mac then
	-- Translate mac and l2interface to values used in IP stack
	mac = repeater_macaddr
	device = alldevices[mac]
	l2interface = repeater.interface
	-- Remove repeater state on disconnect
	if msg["state"] == "Disconnected" then
	  flush_repeater_state(repeater_macaddr)
	end
      end
    end
  end

  -- Filter out wireless events for unknown devices
  if device == nil then
    log:info("Ignoring wireless station event for unknown device")
    return
  end

  -- Handle station disconnects coming from access point
  if msg["state"] == "Disconnected" and device.wireless then
    if device.wireless.accesspoint == accesspoint then
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
  if not l2interface then
    for s, sv in pairs(active_wireless_ssids) do
      if sv.accesspoint == accesspoint then
	l2interface = sv.interface
	break
      end
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
    elseif stai.state and match(stai.state, "Associated") then -- not all chipsets provide other states (authenticated, authorized ...)
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
    parent = stai.parent,
    SSID = stai.SSID,
    station = stai.station,
    encryption = stai.encryption,
    authentication = stai.authentication,
    tx_phy_rate = stai.tx_phy_rate,
    rx_phy_rate = stai.rx_phy_rate,
  }
  if not device.wireless or
     device.wireless.radio ~= wireless.radio or
     device.wireless.accesspoint ~= wireless.accesspoint or
     device.wireless.ssid ~= wireless.ssid or
     device.wireless.parent ~= wireless.parent or
     device.wireless.SSID ~= wireless.SSID or
     device.wireless.station ~= wireless.station or
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

-- Handles a map_controller.ess_station event on UBUS
--
-- Parameters:
-- - msg: [table] the UBUS message
local function handle_map_controller_ess_station_update(msg)
  -- Reject bad events
  if type(msg)~="table" or
    type(msg["state"])~="string" or
    type(msg["station"])~="string" or
    type(msg["bssid"])~="string" then
    log:info("Ignoring improper map_controller.ess_station event")
    return
  end

  local changed = false
  local event = msg["state"]
  local mac = lower(msg["station"])
  local parent = lower(msg["bssid"])
  local l2interface
  local device = alldevices[mac]

  -- Ignore events other than connect or disconnect
  if event ~= "Connect" and event ~= "Disconnect" then
    return
  end

  -- If there is no such station, look up for it in the repeater cache
  if device == nil then
    local repeater_macaddr = connected_wireless_repeaters[mac]
    if type(repeater_macaddr) == "string" then
      local repeater = connected_wireless_repeaters[repeater_macaddr]
      if type(repeater) == "table" and repeater.parent == parent and repeater.station == mac then
	-- Translate mac and l2interface to values used in IP stack
	mac = repeater_macaddr
	device = alldevices[mac]
	l2interface = repeater.interface
	-- Remove repeater state on disconnect
	if event ~= "Connect" then
	  flush_repeater_state(repeater_macaddr)
	end
      end
    end
  end

  -- Filter out map_controller.ess_station events for unknown devices
  if device == nil then
    log:info("Ignoring map_controller.ess_station event for unknown device")
    return
  end

  -- Handle station disconnects
  if event ~= "Connect" and device.wireless then
    if device.state == "connected" and device.wireless.parent == parent then
      set_device_state(device, "disconnected")
      -- Publish our enriched device object over UBUS
      ubus_conn:send('hostmanager.devicechanged', transform_device_to_ubus_message(device))
    end
    return
  end

  -- Find l2interface coresponding to this bssid
  if not l2interface then
    local repeater_macaddr = connected_wireless_repeaters[parent]
    if type(repeater_macaddr) == "string" then
      local repeater = connected_wireless_repeaters[repeater_macaddr]
      if type(repeater) == "table" then
	l2interface = repeater.interface
      end
    else
      for s, sv in pairs(active_wireless_ssids) do
	if sv.bssid == parent then
	  l2interface = sv.interface
	  break
	end
      end
    end
  end
  if not l2interface then
    log:info("Ignoring map_controller.ess_station event received from untracked bssid")
    return
  end

  local wireless_dev, radio, ap_x, ssid, stai = is_wireless(l2interface, mac)
  if not wireless_dev then
    log:info("Ignoring map_controller.ess_station event for non-wireless device")
    return
  end

  local state = device.state
  if stai.state then
    if stai.state == "Disconnected" then
      state = "disconnected"
    elseif stai.state and match(stai.state, "Associated") then -- not all chipsets provide other states (authenticated, authorized ...)
      state = "connected"
    end
  end

  if device.l2interface ~= l2interface then
    if device.l2interface == device.l3interface then
      log:info("Ignoring map_controller.ess_station event due to interface change in a non-bridge context")
      return
    end
    if not is_interface_bridge_port(l2interface, device.l3interface) then
      log:info("Ignoring map_controller.ess_station event due to " .. tostring(l2interface) .. " not being attached to " .. tostring(device.l3interface) .. " bridge")
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
    parent = stai.parent,
    SSID = stai.SSID,
    station = stai.station,
    encryption = stai.encryption,
    authentication = stai.authentication,
    tx_phy_rate = stai.tx_phy_rate,
    rx_phy_rate = stai.rx_phy_rate,
  }
  if not device.wireless or
     device.wireless.radio ~= wireless.radio or
     device.wireless.accesspoint ~= wireless.accesspoint or
     device.wireless.ssid ~= wireless.ssid or
     device.wireless.parent ~= wireless.parent or
     device.wireless.SSID ~= wireless.SSID or
     device.wireless.station ~= wireless.station or
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

-- Handles a map_controller.agent event on UBUS
--
-- Parameters:
-- - msg: [table] the UBUS message
local function handle_map_controller_agent_update(msg)
  -- Reject bad events
  if type(msg)~="table" or
    type(msg["state"])~="string" or
    type(msg["ExtenderMAC"])~="string" then
    log:info("Ignoring improper map_controller.agent event")
    return
  end

  local event = msg["state"]
  local mapid = msg["ExtenderMAC"]

  if event == "Disconnect" then
    -- Remove repeater state on disconnect
    flush_repeater_state(connected_wireless_repeaters[mapid])
    new_wireless_repeaters[mapid] = nil
  elseif event == "Connect" then
    new_wireless_repeaters[mapid] = true
    wireless_repeater_discovery_timer:set(WIRELESS_REPEATER_DISCOVERY_TIMEOUT * 1000)
  elseif event == "Update" then
    -- Update parent related info of this repeater
    local macaddress = connected_wireless_repeaters[mapid]
    if type(macaddress) == "string" and type(connected_wireless_repeaters[macaddress]) == "table" then
      local repeater = connected_wireless_repeaters[macaddress]
      local repeater_id, repeater_conntype, repeater_parent, repeater_macaddr, repeater_bssids = get_map_agent_data(macaddress)

      if repeater_macaddr then
	local changed
	if repeater_id ~= repeater.mapid or
	  repeater_conntype ~= repeater.conntype or
	  repeater_parent ~= repeater.parent or
	  repeater_macaddr ~= repeater.station or
          #repeater_bssids ~= #(repeater.bssid) then
	  changed = true
	else
	  for i in ipairs(repeater_bssids) do
	    if repeater_bssids[i] ~= repeater.bssid[i] then
	      changed = true
	      break
	    end
	  end
	end
	if changed then
	  log:error("Repeater " .. macaddress .. " state changed, flush its cached state")
	  flush_repeater_state(macaddress)
	end
      end
    end
  end
end

-- Update l2interface by brctl_info
local function update_l2interface()
  for mac, l3interface in pairs(devices_linkdown) do
    local device = alldevices[mac]

    if device.state == "disconnected" then
      devices_linkdown[mac] = nil
    else
      local brctl_info = brctl_showmac(l3interface, mac)
      local l2interface = brctl_info.portno and bridge_getport(l3interface, brctl_info.portno) or ""
      if l2interface ~= "" then
	devices_linkdown[mac] = nil
	if device.l2interface ~= l2interface then
	  device.l2interface = l2interface

	  local wireless_dev, radio, ap_x, ssid, stai = is_wireless(l2interface, mac)
	  if wireless_dev then
	    device.technology = 'wireless'
	    device.wireless = {
	      radio = radio,
	      accesspoint = ap_x,
	      ssid = ssid,
	      parent = stai.parent,
	      SSID = stai.SSID,
	      station = stai.station,
	      encryption = stai.encryption,
	      authentication = stai.authentication,
	      tx_phy_rate = stai.tx_phy_rate,
	      rx_phy_rate = stai.rx_phy_rate,
	    }
	  else
	    device.technology = 'ethernet'
	    device.wireless = nil
	  end

	  -- Publish device change over UBUS
	  ubus_conn:send('hostmanager.devicechanged', transform_device_to_ubus_message(device))
	end
      end
    end
  end

  device_linkdown_trial = device_linkdown_trial + 1
  if next(devices_linkdown) then
    -- Try a couple of times to update the l2interface
    if device_linkdown_trial <= MAX_LINKDOWN_RETRIES then
      devices_linkdown_timer:set(LINKDOWN_TIMER_VALUE * 1000)
    else
      devices_linkdown = {}
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
    connected_wireless_repeaters = connected_wireless_repeaters,
  }

  if next(new_wireless_repeaters) then
    local wireless_repeaters_to_discover = {}
    for mapid, _ in pairs(new_wireless_repeaters) do
      wireless_repeaters_to_discover[#wireless_repeaters_to_discover + 1] = mapid
    end
    transformed_response.wireless_repeaters_to_discover = wireless_repeaters_to_discover
  end

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
    end
    return
  end

  if type(connected_wireless_repeaters[interface]) == "string" then
    -- Disconnect and remove repeater state when wds interface gets disconnected
    local repeater_macaddr = connected_wireless_repeaters[interface]
    local device = alldevices[repeater_macaddr]
    if type(device) == "table" and device.state == "connected" then
      set_device_state(device, "disconnected")
      -- Publish our enriched device object over UBUS
      ubus_conn:send('hostmanager.devicechanged', transform_device_to_ubus_message(device))
    end
    flush_repeater_state(repeater_macaddr)
  end

  if bridge ~= "" then
    -- Probe all devices connected on this L2 interface
    probe_selected_bridge_devices(bridge, interface, ip_modes, ip_state_connected)
  end
end

--to align connected/disconnected time of the LAN host when the NTP server is synced
--to make sure only the first timechanged event is used to align the connected time.
local time_changed
local function handle_connected_time_update(msg)
  local uci_cursor = require('uci').cursor(nil, "/var/state")
  uci_cursor:load("system")
  local synced = uci_cursor:get("system", "ntp", "synced")
  uci_cursor:unload("system")
  if synced == "1" and  not time_changed then
    time_changed = true
    local newTime = msg.newtime or "0"
    local oldTime = msg.oldtime or "0"
    --to calculate the time gap between ths non-synced and synced time
    local time_diff = tonumber(newTime) - tonumber(oldTime)
    for _, device in pairs(alldevices) do
      device.connected_time = device.connected_time and (device.connected_time + time_diff)
      device.disconnected_time = device.disconnected_time and (device.disconnected_time + time_diff)
    end
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
wireless_repeater_discovery_timer = uloop.timer(timeout_wireless_repeater_discovery)

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
                   ['wireless.endpoint'] = handle_wireless_endpoint_update,
                   ['wireless.accesspoint.station'] = handle_wireless_station_update,
                   ['time.changed'] = handle_connected_time_update,
                   ['map_controller.ess_station'] = handle_map_controller_ess_station_update,
                   ['map_controller.agent'] = handle_map_controller_agent_update,
                 })

scan_map_agent_data()
scan_full_wireless_status()
scan_network_neigh_cachedstatus()

-- Idle loop
xpcall(uloop.run,errhandler)
