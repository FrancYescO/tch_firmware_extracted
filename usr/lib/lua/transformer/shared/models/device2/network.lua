-- Copyright © 2015 Technicolor 

---
-- A comprehensive network model for Device:2
-- 
-- @module models.device2.network
-- 
-- @usage
-- local nwmodel = require "transformer.shared.models.device2.network"

local require = require
local type = type
local error = error
local ipairs = ipairs
local unpack = unpack
local concat = table.concat
local insert = table.insert

local setmetatable = setmetatable
local rawget = rawget

local uciconfig = require("transformer.shared.models.uciconfig").Loader()
local xdsl = require("transformer.shared.models.xdsl")

local M = {}

local function errorf(fmt, ...)
	error(fmt:format(...), 2)
end

-- This should be filled from the mappings using the register function
local dmPathMap = {
}

--- Valid type names.
-- 
-- This table is not exported but its fields are the
-- acceptable typeName values.
--
-- @table allTypes
local allTypes = {
	"IPInterface",  -- an IP interface
	"PPPInterface", -- a PPP interface
	"VLAN", -- a VLAN
	"EthLink", -- an Ethernet Link
	"Bridge", -- a bridge
	"BridgePort", -- a single port of a bridge
	"PTMLink", -- "a VDSL interface
	"ATMLink", -- an ADSL link
	"DSLChannel", -- a DSL channel
	"DSLLine", --a DSL line
	"EthInterface", -- a physical Ethernet interface
	"WifiRadio", -- a wireless radio
	"WiFiSSID", -- an SSID
	"WiFiAP", -- an AccessPoint 
}

--- register a datamodel path for resolve
-- 
-- This function is meant to be called from a mapping file
-- to link an internal type to a datamodel path. 
-- 
-- This makes the model agnostic to the actual datamodel path.
-- 
-- @param typeName an internal type name (from `allTypes`)
-- @param dmPath the datamodel path
-- @return the typeName if it exists (otherwise an exception is raised)
-- 
-- @usage
-- local nwmodel = require "transformer.shared.models.device2.network"
-- nwmodel.register("EthInterface", Mapping_.objectType.name)
-- 
function M.register(typeName, dmPath)
	if not dmPath[typeName] then
		dmPathMap[typeName] = dmPath
		return typeName
	else
		errorf("duplicate path mapping for %s->%s have %s", typeName, dmPath, dmPathMap[typeName])
	end
end

local load_model --forward declaration

--- Load the model
-- 
-- This call will create an in-memory representation of
-- the network config in uci.
-- 
-- This function will return the same object until the uci
-- config actually changes. So it is safe to call this multiple
-- times.
-- 
-- @return the model 
function M.load()
	return load_model()
end

--- A network config model
-- 
-- This is the class the exposes the loaded model.
-- 
-- The model is composed of objects that have a type
-- and a name. The type is one of the names from `allTypes`
-- plus a few internal types that have no representation in the
-- Device:2 datamodel.
-- 
-- All objects in the model have a unique name.
-- 
-- @type Model
local Model = {}
Model.__index = Model

local function newModel()
	local obj = {
		all = {},
		typed = {
			loopback = {},
		},
		networks = {},
		orderings = {},
		key_aliases = {},
		key_ignore = {}
	}
	for _, tp in ipairs(allTypes) do
		obj.typed[tp] = {}
	end
	return setmetatable(obj, Model)
end

function Model:add(objType, name, position)
	local list = self.typed[objType]
	local all = self.all
	if not list then
		errorf("Programming Error: Adding unknown type %s is not possible", objType)
	end
	if all[name] then
		errorf("Programming Error: Adding duplicate name %s (%s) is not possible", name, objType)
	end
	local obj = {
		type = objType,
		name = name,
		lower = {},
	}
	if position then
		insert(list, position, obj)
	else
		list[#list+1] = obj
	end
	list[name] = obj
	all[#all+1] = obj
	all[name] = obj
	
	return obj
end

local function addWithPlaceholder(model, typeName, name, placeholder)
	local placeholder_ignored = false
	local obj = model:get(typeName, name)
	if placeholder then
		-- request to create a placeholder object
		if not obj then
			obj = model:add(typeName, name)
			obj.placeholder = true
		else
			-- otherwise ignore the request, the object already exists
			placeholder_ignored = true
		end
	else
		-- request to create a real object
		if obj then
			-- but it exists already
			if obj.placeholder then
				-- but it was a placeholder, recycle it for the real thing
				obj.placeholder = nil
			else
				errorf("Adding duplicate %s object %s is not possible", typeName, name)
			end
		else
			obj = model:add(typeName, name)
		end
	end
	return obj, placeholder_ignored
end

local function raw_model_get(model, objType, name)
	local list
	if objType then
		list = model.typed[objType]
	else
		list = model.all
	end
	if list then
		return list[name]
	end
end

--- get a named object from the model
-- 
-- @param[opt] objType the typeName (from `allTypes`)
-- @param name the name of the object
-- 
-- @return the object or nil if not found
-- 
-- If the type is given the name must refer to an object
-- of the given type.
function Model:get(objType, name)
	if not name then
		name = objType
		objType = nil
	end
	local alias = self.key_aliases[name]
	if alias and (alias.master==name)then
		return raw_model_get(self, objType, alias.slave) or raw_model_get(self, objType, name)
	else
		return raw_model_get(self, objType, name)
	end
end

local keygetters = {
	__index = function(table)
		return rawget(table, "__default")
	end
}
setmetatable(keygetters, keygetters)

function keygetters.__default(model, typeName)
	local keys = {}
	for _, obj in ipairs(model.typed[typeName] or {}) do
		if (obj.internal~=true) and (not model.key_ignore[obj.name]) then --it might be nil
			keys[#keys+1] = obj.name
		end
	end
	return keys
end

function keygetters.BridgePort(model, _, parentKey)
	local keys = {}
	local bridge = model:get("Bridge", parentKey)
	if bridge then
		for _, mbr in ipairs(bridge.members) do
			keys[#keys+1] = mbr
		end
	end
	return keys
end

local function sortKeys(keys, sorting)
	local result = {}
	local all = {}
	for _, key in ipairs(keys) do
		all[key] = true
	end
	-- add the ones in sorting in order
	for _, name in ipairs(sorting) do
		if all[name] then
			result[#result+1] = name
			all[name] = false
		end
	end
	-- add the order in the original order
	for _, name in ipairs(keys) do
		if all[name] then
			result[#result+1] = name
		end
	end
	return result
end

--- get the object names for a given type
-- 
-- This is named `getKeys` as it is intended to be used
-- in the entries function of a mapping to return the transformer
-- keys.
-- 
-- @param typeName the type (from `allTypes`)
-- @param[opt] parentKey the name of the parent object. Needed for bridge ports.
-- @return a table that can be returned directly to transformer
-- 
-- @usage
-- local model -- cached for reuse in get/set/getall functions
-- function Mapping_.entries()
--   model = nwmodel.load()
--   return model:getKeys("IPInterface")
-- end
-- 
function Model:getKeys(typeName, parentKey)
	local keys = keygetters[typeName](self, typeName, parentKey)
	local ordering = self.orderings[typeName]
	if ordering then
		keys = sortKeys(keys, ordering)
	end
	return keys
end

--- get the keys for InterfaceStack.
-- 
-- This will a list of keys that can be used for
-- the InterfaceStack entries. Each key represents
-- a connection between two network objects in the
-- the model.
-- 
-- It will ensure the Higher and Lower layer objects
-- will actually resolve to something as empty values
-- are not allowed in the InterfaceStack.
-- 
-- @usage
-- Mapping_.entries = function()
--   model = nwmodel.load()
--   return model:getStackEntries()
-- end
-- 
-- @return a new table with the keys
function Model:getStackEntries()
	local stack = {}
	for _, typeName in ipairs(allTypes) do
		for _, obj in ipairs(self.typed[typeName]) do
			if dmPathMap[obj.type] then
				-- the HigherLayer of the entry may not be empty
				local allLower = obj.lower
				if allLower and (#allLower>0) then
					local upper = obj.name
					for _, lower in ipairs(allLower) do
						local lo = self:get(lower)
						if lo and dmPathMap[lo.type] then
							-- the LowerLayer of the entry may not be empty
							stack[#stack+1] = upper..'('..lower..')'
						end
					end
				end
			end
		end
	end
	return stack
end


--- Get the uci key from the transformer key.
-- 
-- The keys returned from `getKeys` do not reflect the
-- section name to use on uci. Use this function to find 
-- out the correct uci section name.
-- 
-- @param key the key of the object as returned by `getKeys`
-- @return the uci section name
function Model:getUciKey(key)
	local obj = self.all[key]
	if obj then
		local ucikey = obj.ucikey
		if not ucikey then
			ucikey = obj.name:match(":(.+)") or obj.name
			obj.ucikey = ucikey
		end
		return ucikey
	end
end

-- retrieve the Name property of the object
local function objGetName(obj)
	local name = obj._Name
	if not name then
		-- use the name property stripped off of its type prefix
		name = obj.name:match("[^:]*:(.*)") or obj.name
		obj._Name = name
	end
	return name
end

-- retrieve the device property of the given object
local function objGetDevice(obj)
	return obj.device or objGetName(obj)
end

--- Get the device name.
-- 
-- Most of the object in the model refer to a Linux 
-- networking device. Use this function to find out the
-- name of this device.
-- 
-- In some cases the object does not refer to a device,
-- but this function will still return a bogus name.
-- 
-- @param key the key as returned by `getKeys`
-- @return the Linux device (which might not exists!)
function Model:getDevice(key)
	local obj = self.all[key]
	if obj then
		return objGetDevice(obj)
	end
end

--- Get the name of the associated interface.
-- 
-- @param key the key as returned by `getKeys`
-- @return the interface name
function Model:getInterface(key)
	local obj = self.all[key]
	if obj then
		return obj.interface or self:getUciKey(key)
	end
end

--- get the name of the object.
-- 
-- This will return the logical name of the object
-- that can be used as the value for a Device:2 Name parameter.
-- 
-- @param key the key as returned by `getKeys`
-- @return the logical name
function Model:getName(key)
	local obj = self.all[key]
	if obj then
		return objGetName(obj)
	end
end

--- Determine if the object is present.
-- 
-- If an object is not present there is no way
-- to retrieve run-time information from it.
-- 
-- @param key the key as returned by `getKeys`
-- @return true if the object is present, false if not.
function Model:getPresent(key)
	local obj = self:get(key)
	if obj then
		local present = obj.present
		if present==nil then --explicit check needed, no fn call if set to false!
			if obj._present then
				present = obj:_present()
			end
		end
		return (present==nil) and true or present, obj
	end
end

-- remove all non existing lower references
function Model:checkLower()
	for _, obj in ipairs(self.all) do
		if obj.lower then
			local realLower = {}
			for _, lower in ipairs(obj.lower) do
				if self.all[lower] then
					-- the object exists
					realLower[#realLower+1] = lower
				end
			end
			obj.lower = realLower
		end
	end
end

function Model.setLower(obj, lowerName, ...)
	local lowerLayers = {}
	for _, name in ipairs{lowerName, ...} do
		lowerLayers[#lowerLayers+1] = name
	end
	obj.lower = lowerLayers
end

function Model:getLowerLayers(key)
	local lowerLayers = {}
	local present, obj = self:getPresent(key)
	if present and obj then
		for _, lowerName in ipairs(obj.lower) do
			local lower = self:get(lowerName)
			if lower then
				local dmPath = dmPathMap[lower.type]
				if dmPath then
					lowerLayers[#lowerLayers+1] = {dmPath, lowerName}
				end
			end
		end
	end
	return lowerLayers
end

--- get the lowerLayers
-- 
-- This will implement the LowerLayers Device:2 property
-- @usage
--  LowerLayers = function(mapping, param, key)
--    return model:getLowersLayerResolved(key, resolve)
--  end
--  
-- @param key the key as returned by `getKeys`
-- @param resolve the transformer resolve function
-- @param[opt] separator the separator to use, defaults to a comma.
-- @return a string with the LowerLayers
function Model:getLowerLayersResolved(key, resolve, separator)
	if resolve then
		local lower = {}
		for _, layer in ipairs(self:getLowerLayers(key)) do
			-- if the lower name is the slave part of a key alias
			-- translate back to the key returned by getKeys.
			local lowerName = layer[2]
			local alias = self.key_aliases[lowerName]
			if alias and (alias.slave==lowerName) then
				lowerName = alias.master
			end
			lower[#lower+1] = resolve(layer[1], lowerName)
		end
		return concat(lower, separator or ",")
	end
	return ""
end

local function getStackRef(model, stackKey, getUpper, resolve)
	local upper, lower = stackKey:match("^(.*)%((.*)%)$")
	if not upper then
		--  this only happens if called with the wrong key
		return ""
	end
	local key = getUpper and upper or lower
	local obj = model:get(key)
	if not obj then
		-- wrong key provided
		return ""
	end
	local dmPath = dmPathMap[obj.type]
	if dmPath then
		return resolve(dmPath, key) or ""
	else
		return ""
	end
end

--- get the HigherLayer for an InterfaceStack entry.
--
-- @usage
-- Mapping_.get = {
--   HigherLayer = function(mapping, key)
--     return model:getStackHigherResolved(key, resolve)
--   end
-- }
-- 
-- @param stackKey a key value returned by `getStackEntries`
-- @param resolve the function to resolve the entry.
-- @return the resolved path of the Higher layer
function Model:getStackHigherResolved(stackKey, resolve)
	return getStackRef(self, stackKey, true, resolve)
end

--- get the LowerLayer for an InterfaceStack entry.
-- 
-- @usage
-- Mapping_.get = {
--   HigherLayer = function(mapping, key)
--     return model:getStackLowerResolved(key, resolve)
--   end
-- }
-- 
-- @param stackKey a key value returned by `getStackEntries`
-- @param resolve the function to resolve the entry.
-- @return the resolved path of the Lower layer
function Model:getStackLowerResolved(stackKey, resolve)
	return getStackRef(self, stackKey, false, resolve)
end

local function loadEthernet(model)
	local cfg = uciconfig:load("ethernet")
	local ports = cfg.port or {}
	for _, eth in ipairs(ports) do
		model:add("EthInterface", eth['.name'])
	end
	local mapping = cfg.mapping or {}
	for _, map in ipairs(mapping) do
		local port = map.port
		local eth = port and model:get("EthInterface", port)
		if eth and (map.wlan_remote=="1") then
			eth.internal = true
			eth.wlan_remote = true
		end
	end
end

local function loadDsl(model)
	local cfg = uciconfig:load("xdsl")
	for _, dsl in ipairs(cfg.xdsl or {}) do
		local name = dsl[".name"]
		local line = model:add("DSLLine", "dsl:"..name)
		line.device = name
		local channel = model:add("DSLChannel", name)
		channel.device = name
		model.setLower(channel, line.name)
	end
end

local function xtmObjectPresent(obj)
	if obj.type == 'ATMLink' then
		return xdsl.isADSL()
	elseif obj.type == 'PTMLink' then
		return xdsl.isVDSL()
	end
end

local function loadXtm(model)
	local cfg = uciconfig:load("xtm")
	for _, atm in ipairs(cfg.atmdevice or {}) do
		local dev = model:add("ATMLink", atm[".name"])
		model.setLower(dev, "dsl0")
		dev._present = xtmObjectPresent
	end
	for _, ptm in ipairs(cfg.ptmdevice or {}) do
		local name = ptm['.name']
		local placeholder = ptm['.placeholder']
		if placeholder then
			name = ptm.uciname or name
		end
		local dev = addWithPlaceholder(model, "PTMLink", name, placeholder)
		model.setLower(dev, "dsl0")
		if placeholder then
			dev.ucikey = ptm['.name']
			dev.present = false
		else
			-- presence is dynamic (not dependent on the actual config)
			dev.present = nil
			dev._present = xtmObjectPresent
		end
	end
end

local function getBridgeDevice(model, member)
	return model:get(member)
	       or model:get("vlan:"..member)
	       or model:get("link:"..member)
end

local function create_bridge(model, name, members, placeholder)
	local bridge, placeholder_ignored = addWithPlaceholder(model, "Bridge", name, placeholder)
	if placeholder_ignored then
		-- the real brigde object already existed, nothing left to do
		local mgmt = model:get("BridgePort", name..':mgmt')
		return mgmt, bridge
	end
	local memberlist = {}
	bridge.members = memberlist

	-- a bridge can be created without members!!
	members = members or ""

	-- create management port
	local mgmt = addWithPlaceholder(model, "BridgePort", name..":mgmt", placeholder)
	mgmt.management = true
	mgmt.device = name
	memberlist[#memberlist+1] = mgmt.name
	local mgmtLower = {}

	-- create members
	for member in members:gmatch("%S+") do
		local dev = getBridgeDevice(model, member)
		if dev and not dev.wlan_remote then
			local portname=name..":"..member
			local m = addWithPlaceholder(model, "BridgePort", portname, placeholder)
			if placeholder then
				m.present = false
			else
				m.present = nil
			end
			model.setLower(m, dev.name)
			m.device = m.lower[1]
			memberlist[#memberlist+1] = m.name
			mgmtLower[#mgmtLower+1] = m.name
		end
	end

	model.setLower(mgmt, unpack(mgmtLower))
	return mgmt.name, bridge
end

local function create_device(model, s)
	-- add the link first
	if not s['.placeholder'] then
		local dev = model:add("EthLink", "link:"..s['.name'])
		if (not s.type) and (not s.ifname) then
			--ADSL
			model.setLower(dev, s.name)
		elseif s.ifname then
			model.setLower(dev, s.ifname)
		end
		dev.device = s.name
	end

	local devtype = s.type or "8021q"
	if (devtype=="8021q") or (devtype=="8021ad") then
		-- create VLAN
		local vlan = model:add("VLAN", "vlan:"..s['.name'])
		vlan._Name = s['.name']
		if s.type then
			vlan.device = s.name
		end
		if s.ifname then
			model.setLower(vlan, "link:"..s['.name'])
		elseif s.type then
			local lower = model:get("link:"..s['.name'])
			if lower then
				model.setLower(vlan, lower.name)
			end
		end
	elseif devtype == 'bridge' then
		create_bridge(model, s.name, s.ifname, s['.placeholder'])
	end
end

local function table_index(array, value)
	if array then
		for idx, entry in ipairs(array) do
			if entry==value then
				return idx
			end
		end
	end
	return 0
end

-- find the object with the given type that has the
-- the device property equal to devName
-- return the name and the object if found
-- otherwise return nil
local function findDevice(model, typeName, devName)
	for _, obj in ipairs(model.typed[typeName]) do
		if objGetDevice(obj)==devName then
			return obj.name, obj
		end
	end
end

local function getIPLowerLayer(model, lower_intf)
	if not lower_intf then
		return
	end
	local lower = findDevice(model, "VLAN", lower_intf)
	if not model:get("VLAN", lower) then
		lower = findDevice(model, "EthLink", lower_intf)
		if not lower then
			--find EthIntf base on lower layer
			for _, dev in ipairs(model.typed.EthLink or {}) do
				if table_index(dev.lower, lower_intf)>0 then
					lower = dev.name
					break
				end
			end
		end
		lower = lower or lower_intf
	end
	return lower
end

local function addTableEntry(tbl, entry)
	for _, v in ipairs(tbl) do
		if v==entry then
			-- already in
			return
		end
	end
	tbl[#tbl+1] = entry
end

local function connectsToDevice(model, obj, device)
	if not obj then return end
	if objGetDevice(obj)==device then
		return true
	else
		for _, name in ipairs(obj.lower) do
			local lower = model:get(name)
			if lower and connectsToDevice(model, lower, device) then
				return true
			end
		end
	end
end

local function addBridgePort(model, bridge, lower)
	local lower_dev = objGetDevice(lower)
	for _, mbr in ipairs(bridge.members) do
		if connectsToDevice(model, model:get(mbr), lower_dev) then
			-- already in (directly or indirectly)
			return
		end
	end
	local portname = bridge.name..':'..lower_dev
	local port = model:get(portname)
	if not port then
		port = model:add("BridgePort", portname)
		addTableEntry(bridge.members, portname)
	end
	if lower.device then
		port.device = lower.device
	end
	model.setLower(port, lower.name)
	local mgmt = model:get("BridgePort", bridge.name..':mgmt')
	if mgmt then
		addTableEntry(mgmt.lower, portname)
	end
end

local function createPPPInterface(model, name, placeholder)
	return addWithPlaceholder(model, "PPPInterface", name, placeholder)
end

local function create_interface(model, s, cfg)
	local name = s['.name']
	local ifname = s.ifname
	local lower = ifname
	local device = ifname
	local proto = s.proto or ""
	
	local isRef, referend
	if ifname then 
		isRef, referend = ifname:match("^(@)(.*)")
	end
	if isRef then
		local intf = cfg.interface[referend]
		if intf then
			if intf.type=='bridge' then
				device = "br-"..intf['.name']
				lower = "link:"..intf['.name']
			else
				device = intf.ifname
				lower = device
			end
		else
			device = nil
			lower = nil
		end
	end
	if proto:match("^ppp") then
		local ppp = createPPPInterface(model, "ppp-"..name)
		ppp.proto = proto
		ppp.ucikey = name
		ppp.device = ifname
		model.setLower(ppp, getIPLowerLayer(model, ifname))
		lower = ppp.name
		device = ppp.name
	elseif s.type == "bridge" then
		local bridge
		lower, bridge = create_bridge(model, "br-"..name, ifname)
		bridge.ucikey = name
		device = bridge.name
		local link = model:add("EthLink", "link:"..name, 1)
		link.device = bridge.name
		model.setLower(link, lower)
		lower = link.name
	end
	local intf = model:add("IPInterface", name)
	intf.device = device
	model.setLower(intf, getIPLowerLayer(model, lower))
end

local function findNetworkBridge(model, network)
	local intf = model:get("IPInterface", network)
	while intf and (intf.type ~= "Bridge") do
		intf = model:get(intf.device)
	end
	return intf
end

local function loadNetwork(model)
	local cfg = uciconfig:load("network")
	
	for _, dev in ipairs(cfg.device or {}) do
		create_device(model, dev)
	end
	for _, intf in ipairs(cfg.interface or {}) do
		create_interface(model, intf, cfg)
	end
	
	for _, pppcfg in ipairs(cfg.ppp or {}) do
		local name = pppcfg.uciname or pppcfg['.name']
		local ppp = createPPPInterface(model, name, pppcfg['.placeholder'])
		ppp.ucikey = pppcfg['.name']
	end
end

local function findRemoteWLanInterface(model)
	for _, eth in ipairs(model.typed.EthInterface) do
		if eth.wlan_remote then
			return eth.name
		end
	end
end

local function addSSID(model, radio, name)
	local ssid = model:add('WiFiSSID', name)
	if radio.remote then
		ssid.device = radio.device
	else
		ssid.device = ssid.name
	end
	model.setLower(ssid, radio.name)
	return ssid
end

local function load_wifi_devices(model, cfg)
	for _, radioCfg in ipairs(cfg['wifi-device'] or {}) do
		local radio = model:add("WifiRadio", radioCfg['.name'])
		if radioCfg.type=='quantenna' then
			radio.remote = true
			radio.device = findRemoteWLanInterface(model)
		end
	end
end

local function load_wifi_ifaces(model, cfg)
	for _, ssidCfg in ipairs(cfg['wifi-iface'] or {}) do
		local bridge = findNetworkBridge(model, ssidCfg.network or 'lan')
		local intf = ssidCfg.network and model:get("IPInterface", ssidCfg.network)
		local radio = model:get('WifiRadio', ssidCfg.device)
		if radio and bridge then
			local ssid = addSSID(model, radio, ssidCfg['.name'])
			addBridgePort(model, bridge, ssid)
		elseif radio and intf then
			addSSID(model, radio, ssidCfg['.name'])
		elseif ssidCfg['.placeholder'] then
			local ssid = model:add("WiFiSSID", ssidCfg['.name'])
			ssid.present = false
		end
	end
end

local function load_wifi_aps(model, cfg)
	for _, apCfg in ipairs(cfg['wifi-ap'] or {}) do
		local name = apCfg['.name']
		local placeholder = apCfg['.placeholder']
		if placeholder then
			name = apCfg.uciname or name
		end
		local ap = addWithPlaceholder(model, "WiFiAP", name, placeholder)
		ap.ucikey = apCfg['.name']
		local iface = apCfg.iface
		if iface then
			model.setLower(ap, iface)
		end
	end
end
 
local function load_wireless(model)
	local cfg = uciconfig:load("wireless")

	load_wifi_devices(model, cfg)
	load_wifi_ifaces(model, cfg)
	load_wifi_aps(model, cfg)
end

local function loadOrderings(model)
	local cfg = uciconfig:load("dmordering")
	local orderings = cfg.ordering or {}

	for _, typeName in ipairs(allTypes) do
		local section = orderings[typeName]
		if section then
			local order = section.order
			if type(order)=='string' then
				order = {order}
			end
			model.orderings[typeName] = order
		end
	end

	local aliases = {}
	local ignore = {}
	for _, alias in ipairs(cfg.alias or {}) do
		local master = alias.master
		local slave = alias.slave
		if master and slave then
			aliases[master] = alias
			aliases[slave] = alias
			ignore[slave] = true
		end
	end
	model.key_aliases = aliases
	model.key_ignore = ignore
end

local current_model

load_model = function()
	if not current_model or uciconfig:config_changed() then
		local model = newModel()
		model:add("loopback", "lo")
		loadEthernet(model)
		loadDsl(model)
		loadXtm(model)
		loadNetwork(model)
		load_wireless(model)
		model:checkLower()
		loadOrderings(model)
		current_model = model
	end
	return current_model
end

return M
