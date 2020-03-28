
local require = require
local setmetatable = setmetatable
local ipairs = ipairs
local pairs = pairs
local concat = table.concat
local format = string.format
local open = io.open
local uci = require 'transformer.mapper.ucihelper'
local common = require 'transformer.mapper.nwcommon'

--[[
Network object hierarchy:

  Interface : the logical interface in uci, eg. wan or mgt
    |
    +--> vlandevice : the name specified in the ifname if the interface,
           |
           +--> physical device : the real physical device eg. eth4
                  |
                  +--> Layer 3
                  +--> Layer 2

  If the interface does not use vlans then the vlandevice is the physical
  device.
  Layer 2 and Layer 3 can be different if eg. ppp is used.

  In this module we take care to separate the information in the above
  hierarchy to make sure we can retrieve the relevant parameters in the correct
  level. This is important as we may retrieve info for interfaces that are not
  active.
--]]

local M = {}

--[[
wanconfig is a uci config file stating which connections should be considered
to be always present in the IGD.WANDevice. tree.

It is meant to be used in combination with wansensingg where an interface is
connected dynamically with its lower layer e.g. the interface 'wan' can be
connected to eth4 with IPoE or to ptm0 with PPPoE or to ptm0 with IPoE

The wanconfig config file consists of wanconfig sections with the following
options:
  interface : the name of the interface section in network (e.g. 'wan')
  ifname: the ifname it will be connected to (e.g. 'ptm0')
  proto: the protocal ip fo IPoE or ppp for PPPoE/PPPoA
  sdev: the name of the wansensing device. This is used to update properties
        (like username and password) even if the interface is not active

An additional option 'alias' will be created if the 'Name' parameter in the
WANPPPConnection or WANIPConnection is changed.

Any interface in wanconfig will show up permanently in IGD.WANDevice.
Any other will show up and disappear as usual. So if a wansensing interface is
in active use it will show up, even if not in wanconfig.
Its index number will only stay constant if it is in wanconfig.
--]]

--- get all wanconfig entries for the given proto
-- @param proto [string] either ip, ppp or nil
--     if nil all entries are returned, regardless of protocol
-- @return a list with all found uci sections
local wanconfig={config='wanconfig', sectionname='wanconfig'}
local function get_wanconfig(proto)
	local interfaces = {}
	uci.foreach_on_uci(wanconfig, function(s)
		if not proto or s.proto==proto then
			interfaces[#interfaces+1] = s
		end
	end)
	return interfaces
end
M.get_wanconfig = get_wanconfig

local vlan_type={config="network", sectionname="globals", option="vlanmode", default="linux"}
local vlan_device={config="network", sectionname="device"}
local vlan_vopi={config="network", sectionname="bcmvopi"}

--- retrieve all vlan devices, depending on the global vlanmode
-- @return vlans, vlanmode
--     with vlans a table of vlan defs keyed on their name and the following
--     fields:
--         name: the name of the vlan device
--         device: the physical device name
--         vid: the vlan id
--         sectionname: the uci section name
--         vlanmode: the global vlan mode, linux or bcmvopi
--     and vlanmode the global vlanmode
local function get_vlans()
	local vlans = {}
	local vlanmode=uci.get_from_uci(vlan_type)
	if vlanmode=="linux" then
		uci.foreach_on_uci(vlan_device, function(s)
			local name = s.name or s[".name"]
			local physicdevice = nil

			if s.type == "macvlan" then
				physicdevice = s.name
				vlanmode = "macvlan"
			end

			vlans[name] = {
				name = name,
				device = s.ifname or name,
				vid = s.vid or "-1",
				sectionname = s['.name'],
				vlanmode = vlanmode,
				physicdevice = physicdevice,
			}
		end)
	elseif vlanmode=="bcmvopi" then
		uci.foreach_on_uci(vlan_vopi, function(s)
			local name = s[".name"]
			vlans[name] = {
				name = name,
				device = s['if'],
				vid = s.vid or '1',
				sectionname = name,
				vlanmode = vlanmode,
			}
		end)
	end
	return vlans, vlanmode
end
M.get_vlans = get_vlans

local ConnectionList = {}
ConnectionList.__index = ConnectionList

--- get the vlan info for the given (logical) device
-- @param conn [Connection] the connection object to use
-- @param device [string] the logical device name (the ifname of a uci interface)
-- @returns the vlaninfo table with the following fields:
--   vlandevice [string] the unaltered device
--   devname [string] the physical device, without vlan info
--   vlanid [string] the vlan id, if present (not set if no vlan)
--   vlantype [string] :
--       linux-inline,  specified as eg eth4.113
--       linux,         separate vlan device defined
--       bcmvopi,       broadcom vopi vlan
--       veip,          GPON veip vlan interface
--     If no vlan info is present the vlantype is set to the global vlanmode
--     (either linux or bcmvopi)
local function make_vlan_info(conn, device)
	-- strip of any spaces in device
	device = device:match("^%s*(.*)%s*$")

	local devname  --the derived name of the physical device
	local vlanid   --the derived vlan id, nil if no vlan
	local vlantype --the type if the vlan
	local physicdevice --the physicaldevice name

	local vlan = conn.vlans[device]
	if vlan then
		-- the given device refers to a vlan device, take info from there
		devname = vlan.device
		vlanid = vlan.vid
		vlantype = vlan.vlanmode
		physicdevice = vlan.physicdevice
	else
		-- the device name may contain an embedded vlan id
		-- pattern to separate the physical device from the vlan id
		vlantype = "linux-inline"
		local vlp = "^([^.]*)%.(%d+)$"
		if device:match("^veip") then
			-- device is a GPON veip, pattern is different (_ iso .)
			vlp = "^([^_]*)_(%d+)$"
			vlantype = "veip"
		end
		local phys, vid = device:match(vlp)
		if phys then
			-- device contains an embedded vlan
			devname = phys
			vlanid = vid
		else
			-- device is (or should be) the physical device
			devname = device
			vlantype = conn.vlanmode
		end
	end
	return {
		vlandevice = device,
		devname = devname,
		vlanid = vlanid,
		vlantype = vlantype,
		physicdevice = physicdevice,
	}
end

-- iterate over all uci interfaces calling a function for each
-- @param f [function] the function to call
local uci_interfaces = { config="network", sectionname="interface"}
local function foreach_interface(f)
	return uci.foreach_on_uci(uci_interfaces, f)
end

--- add the given key and vlaninfo to the connection
-- @param conn [Connection] the connection
-- @param key [string] the key to add
-- @param info [table] the info to attach (defaults to {})
-- @returns the info attached
-- If the key was already present, the info is not overwritten, but the info
-- already present is returned
local function add_entry(conn, key, info)
	local entries = conn.entries
	local entry = entries[key]
	if not entry then
		local keys = conn.keys
		keys[#keys+1] = key
		entry = info or {}
		entries[key] = entry
	end
	return entry
end

local proto_list = {
  ip = {"static", "dhcp", "dhcpv6", "mobiled"},
  ppp = {"pppoe", "pppoa"}
}

-- check if the given proto matches the connection
local function match_proto(conn, proto)
	local protos = proto_list[conn.connType]
	if protos then
		for _, p in ipairs(protos) do
			if p==proto then
				return true
			end
		end
	end
end

-- create a key for transformer
-- @param interface [string] the logical interface (eg. wan or mgmt)
-- @param physical [string] the physical interface (eg eth4 or ptm0)
local function make_key(interface, physical)
	return format("%s|%s", interface, physical)
end

--- retrieve the correct key for the given wan interface connection
-- @param interface [string] the logical name of the interface
-- @return key, status, vlaninfo
-- this function is meant to be used by other mapping that need to retrieve
-- a key for a given wan connection. This function will properly handle
-- the different vlan scenarios.
local function get_connection_key(interface)
	local key, vlaninfo
	local conn = {}
	conn.vlans, conn.vlanmode = get_vlans()
	local ll_intfs, status = common.get_lower_layers_with_status(interface)
	if #ll_intfs>1 then
		-- ignore bridged devices
		return
	end
	local lower_intf = ll_intfs[1]
	if lower_intf then
		vlaninfo = make_vlan_info(conn, lower_intf)
		key = make_key(interface, vlaninfo.devname)
	end
	return key, status, vlaninfo
end
M.get_connection_key = get_connection_key

local function make_lookup(list)
  for i, value in ipairs(list) do
    list[value] = true
    list[i] = nil
  end
end

local function remove_entries(list, to_remove)
  if to_remove and #to_remove>0 then
    make_lookup(to_remove)
    local newlist = {}
    for _, value in ipairs(list) do
      if not to_remove[value] then
        newlist[#newlist+1] = value
      end
    end
    list = newlist
  end
  return list
end

--- retrieve keys for all connection on given physical device
-- @param parentkey [string] the key of the parent instance in type|name form.
-- @returns a list (table) of keys to pass to transformer
function ConnectionList:getKeys(parentkey)
	local devtype, devname = common.split_key(parentkey)
	self.devType = devtype
	self.keys = {}
	self.entries = {}
	self.interfaces_dhcp6 = {}

	self.vlans, self.vlanmode = get_vlans()

	-- add the fixed IP devices
	local wan_intf = get_wanconfig(self.connType)
	for _, s in ipairs(wan_intf) do
		local vlaninfo = make_vlan_info(self, s.ifname)
		if vlaninfo.devname==devname then
			vlaninfo.wanconfig = s
			vlaninfo.interface = s.interface
			add_entry(self, make_key(s.interface, devname), vlaninfo)
		end
	end

	foreach_interface(function(s)
		if match_proto(self, s.proto) then
			local interface = s["ifname"] and s["ifname"]:match("^@(.*)") or s["device"] and s["device"]:match("^@(.*)")
			if interface and s["proto"] == "dhcpv6" then
				self.interfaces_dhcp6[interface] = s[".name"]
			else
				local interface = s['.name']
				local ll_intfs, status = common.get_lower_layers_with_status(interface)
				-- the pppoerelay feature can add wan interface on a lan interface.
				-- This does not make the lan interface a wan interface so we have
				-- to ignore them.
				ll_intfs = remove_entries(ll_intfs, s.pppoerelay)
				local vlanid
				for _, v in ipairs(ll_intfs) do
					local vlaninfo = make_vlan_info(self, v)
					if vlaninfo.devname == devname then
						-- include the interface/loweLayer combo if there is either
						-- a single lowerLayer or the current lowerLayer is then
						-- active one (eg in an ATM bridge interface)
						local entry = add_entry(self, make_key(interface, devname), vlaninfo)
						entry.active = true
						entry.status = status
						if not entry.interface then
							entry.interface = interface
						end
					end
				end
			end
		end
	end)

	return self.keys
end

--- get a physical interface parameter (from /sys/class/net)
-- @param key [string] the key for the entry
-- @param req_value [string] the name of the info item (eg 'operstate')
-- @param layer [string] "L2" for layer2 or "L3" for layer3, L2 is the default
--    interface
function ConnectionList:getPhysicalInfo(key, req_value, layer)
	layer = layer or "L2"
	local entry = self.entries[key]
	local devname
	if layer == "L2" then
		devname = entry.physicdevice or entry.devname
	elseif layer == "L3" and entry.status then
		devname = entry.status.l3_device or entry.vlandevice
	end
	if devname then
		return common.getIntfInfo(devname, req_value)
	end
	return ""
end

--- is the logical interface active
-- @param key [string] the transformer key
-- @returns true is interface is active, false if not.
-- Interface is not active if not connected to its physical innterface, as can
-- happen in the case of wansensing
function ConnectionList:isActive(key)
	return self.entries[key].active
end

--- get status info for the (vlan)device
-- @param key [string] the transformer key
-- @returns the ubus status of the (vlan)device
function ConnectionList:getDeviceStatus(key)
	return common.get_ubus_device_status(self.entries[key].vlandevice)
end

--- get status for the logical interface
-- @param key [string] the transformer key
-- @returns the ubus status of the logical interface if it is active
-- (otherwise it makes no sense)
-- The status returned is the one cached during the entries call, so no extra
-- ubus action will be performed.
function ConnectionList:getInterfaceStatus(key)
	local entry = self.entries[key]
	if entry.active then
		return entry.status
	end
end

--- get the given option of the interface
-- @param key [string] the transformer key
-- @param option [string] the option name
-- @param default [] the default value
-- @return the request option (if present) else the default value
-- If the device is not active and the interface has a wanconfig with sdev set
-- the value will be retrieved from the interface in sdev.
local intf_option = {config="network", sectionname="interface", option="dontknow", default="notset"}
function ConnectionList:getInterfaceOption(key, option, default)
	local entry = self.entries[key]
	local interface
	if entry.active then
		interface = entry.interface
	else
		interface = entry.wanconfig and entry.wanconfig.sdev
	end
	if interface then
		intf_option.sectionname = interface
		intf_option.option = option
		intf_option.default = default
		return uci.get_from_uci(intf_option)
	end
	return default
end

--- set the given option on the interface
-- @param key [string] the transformer key
-- @param option [string] the uci option to set
-- @param value [string] the new value
-- @return the config name if update, nil otherwise
-- Note that updated means set on the interface if it is active and on the
-- wansensing device if that defined.
function ConnectionList:setInterfaceOption(key, option, value)
	local entry = self.entries[key]
	local updated
	if entry.active then
		-- can set on the actual interface
		intf_option.sectionname = entry.interface
		intf_option.option = option
		uci.set_on_uci(intf_option, value, self.commitapply)
		updated = true
	end
	-- set on wansensing device, if defined
	local sdev = entry.wanconfig and entry.wanconfig.sdev
	if sdev then
		intf_option.sectionname = sdev
		intf_option.option = option
		uci.set_on_uci(intf_option, value, self.commitapply)
		updated = true
	end
	if updated then
		self.transactions[intf_option.config] = true
		return intf_option.config
	end
end

--- get the pppoe status info
-- @param key [string] the transformer key
-- @return a table with the fields ID, Address or nil if connection is not pppoe
function ConnectionList:getPPPoEInfo(key)
	if (self.connType ~= 'ppp') then
		return
	end
	local proto = self:getInterfaceOption(key, "proto")
	if proto=="pppoe" then
		local fd = open('/proc/net/pppoe')
		if fd then
			local vlandevice = self.entries[key].vlandevice
			local id, address, device
			repeat
				local ln = fd:read("*l") or ""
				id, address, device = ln:match("(%S*)%s*(%S*)%s*(%S*)")
			until (device==vlandevice) or (id=="")
			fd:close()
			if device==vlandevice then
				return {ID=id, Address=address}
			end
		end
	end
end

--- get the external name for the interface
-- @param key [string] the transformer key
-- @return the external name, defaults to the interface name if not set yet
function ConnectionList:getName(key)
	local entry = self.entries[key]
	if not entry.wanconfig then
		return uci.get_from_uci{
			config = "network",
			sectionname = entry.interface,
			option = "alias",
			default = entry.interface
		}
	else
		return uci.get_from_uci{
			config='wanconfig',
			sectionname = entry.wanconfig['.name'],
			option = 'alias',
			default = entry.interface
		}
	end
end

--- set the external name for the interface
-- @param key [string] the transformer key
-- @param value [string] the value to set
-- @return the name of the updated config
function ConnectionList:setName(key, value)
	local binding
	local entry = self.entries[key]
	if not entry.wanconfig then
		binding = {
			config = "network",
			sectionname = entry.interface,
			option = "alias",
		}
	else
		binding = {
			config='wanconfig',
			sectionname = entry.wanconfig['.name'],
			option = 'alias'
		}
	end
	uci.set_on_uci(binding, value, self.commitapply)
	self.transactions[binding.config] = true
	return binding.config
end

--- Delete a vlan device if it is no longer referenced
-- @param conn the connection list
-- @param vlandevice [string] the name of the vlan device
-- The vlan device is removed unless an interface section still refers to it.
local function remove_vlan(conn, vlandevice)
	local vlan = conn.vlans[vlandevice]
	if not vlan then
		-- it does not exist
		return
	end
	local referenced = false
	foreach_interface(function(s)
		if s.ifname == vlan.name then
			referenced = true
			return false
		end
	end)


	if not referenced then
		-- no longer in use, can be safely removed
		-- do not trust the sectionname (it could change if it was generated)
		local sectionname
		uci.foreach_on_uci({config="network", sectionname="device"}, function(s)
			if s.name == vlandevice then
				sectionname = s['.name']
				return false
			end
		end)
		if sectionname then
			uci.delete_on_uci(
				{
					config = "network";
					sectionname = sectionname
				},
				conn.commitapply
			)
			conn.vlans[vlandevice] = nil
		end
	end
end

--- Create a linux vlan device in uci
-- @param conn the connecton list
-- @param interface [string] the name of the interface the new vlan will be
--    attached to. This is used to create a unique name for the vlan device.
-- @param devname [string] the name of the physical device, something like 'eth4'
-- @return the table with the data on the newly ceated uci section
-- Note that the VLAN id (uci vid option) is not set.
local function create_vlan(conn, interface, devname)
	-- first generate a name
	-- first try the interface name prefixed with vlan_
	local vlandevice = format("vlan_%s", interface)
	if conn.vlans[vlandevice] then
		-- this already exists
		-- append a number to the first guess and increment it until it is not
		-- an existing vlan.
		local cnt = 1
		while conn.vlans[vlandevice] do
			vlandevice = format("vlan_%s_%d", interface, cnt)
			cnt = cnt + 1
		end
	end
	local binding = {
		config = "network",
		sectionname = "device"
	}
	-- the name of the section is irrelevant (use auto generated one)
	binding.sectionname = uci.add_on_uci(binding, conn.commitapply)
	binding.option = "type"
	uci.set_on_uci(binding, "8021q", conn.commitapply)
	binding.option = "name"
	uci.set_on_uci(binding, vlandevice, conn.commitapply)
	binding.option = "ifname"
	uci.set_on_uci(binding, devname, conn.commitapply)

	local vlan = {
		name = vlandevice,
		sectionname = binding.sectionname,
		device = devname,
		vlanmode = 'linux',
	}
	conn.vlans[vlandevice] = vlan
	return vlan
end

--- update the VLAN id of the interface
-- @param key [string] the transformer key
-- @param newVlanID [string] the new vlan id
-- @returns the name of the updated config file (if updated)
--   or nil, errmsg in case an error occurs
-- This function can only update the VLAN id of linux vlan devices.
-- bcmvopi's are not supported.
-- A new vlandevice is create only if there was previously no vlan set.
-- If the vlan is set to -1 the vlandevice is removed (unless still referenced)
function ConnectionList:setVlan(key, newVlanID)
	local entry = self.entries[key]
	local vlanid = entry.vlanid or "-1"
	if newVlanID==vlanid then
		-- the value does not change, always ok.
		return
	end
	if self.devType ~= "ETH" then
		return nil, "Only supported for ETH devices"
	end
	if entry.wanconfig then
		return nil, "not supported on wansensing devices"
	end
	if entry.vlantype ~= "linux" then
		return nil, format("not supported for vlan type %s", entry.vlanmode)
	end
	if newVlanID=="-1" then
		-- remove the vlan
		local r = self:setInterfaceOption(key, "ifname", entry.devname)
		remove_vlan(self, entry.vlandevice)
		return r
	else
		local vlan = self.vlans[entry.vlandevice]
		if not vlan then
			vlan = create_vlan(self, entry.interface, entry.devname)
			self:setInterfaceOption(key, "ifname", vlan.name)
		end
		local binding = {
			config = "network",
			sectionname = vlan.sectionname,
			option = "vid"
		}
		uci.set_on_uci(binding, newVlanID, self.commitapply)
		vlan.vid = newVlanID
		self.transactions[binding.config] = true
		return binding.config
	end
end

--- get the dhcp6 alias interface for the interface
-- @param key [string] the transformer key
-- @return the section name of the dhcp6 alias interface if available, otherwise return nil
function ConnectionList:getInterfaceDhcp6(key)
	local interface = self.entries[key].interface
	return self.interfaces_dhcp6[interface]
end

--- perform given action on all outstanding transaction
-- @param conn [] a connection object
-- @param action [function] the function to call for each transaction
local function finalize_transactions(conn, action)
  local binding = {}
  for config in pairs(conn.transactions) do
    binding.config = config
    action(binding)
  end
  conn.transactions = {}
end

--- commit the pending transactions
-- @param mapping [] the mapping
function M.commit(mapping)
  finalize_transactions(mapping._conn, uci.commit)
end

--- revert the pending transactions
-- @param mapping [] the mapping
function M.revert(mapping)
  finalize_transactions(mapping._conn, uci.revert)
end

--- create a new connection list for the given mapping
-- @param mapping [table] a mapping
-- @param connType [string] the connection type, either ip or ppp
-- @param commitapply [] a commit and apply context
function M.SetConnectionList(mapping, connType, commitapply)
  local conn = {
    connType = connType,
    commitapply = commitapply,
    transactions = {}
  }

  mapping._conn = setmetatable(conn, ConnectionList)
  return conn
end


return M
