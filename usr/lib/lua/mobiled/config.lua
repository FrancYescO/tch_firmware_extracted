---------------------------------
--! @file
--! @brief The config module which parses UCI and sends out UBUS events on changes
---------------------------------

local tonumber, table, pairs, type, string, tostring = tonumber, table, pairs, type, string, tostring

local uci = require('uci')
local helper = require("mobiled.scripthelpers")

local runtime
local config = {}
local mobiled_config = "mobiled"

local M = {}

function M.get_tracelevel()
	if config and config.globals and config.globals.tracelevel then
		return config.globals.tracelevel
	end
	return 3
end

local function reload_sims(cursor)
	local c = cursor or uci.cursor()
	config.sims = {}
	c:foreach(mobiled_config, "sim", function(s)
		table.insert(config.sims, s)
	end)
end

function M.get_pin_from_config(pinType, iccid)
	local pin
	local migrated_sim
	for _, s in pairs(config.sims) do
		if s.pin_type == pinType then
			if s.iccid == iccid then
				pin = s.pin
			elseif s.iccid == "migrated" then
				migrated_sim = s
			end
		end
	end

	-- Check if there is a migrated SIM config for this PIN type.  The migrated
	-- SIM config will always be removed from the config (either by deleting it or
	-- by overwriting the ICCID) the first time a PIN is retrieved from the
	-- configuration regardless of whether the ICCID of the SIM is found or not.
	-- This allows migrating from mobiledongle to mobiled with the SIM that is
	-- currently in use and will not cause problems when using a different SIM at a
	-- later point in time.
	if migrated_sim then
		local c = uci.cursor()
		if pin then
			c:delete(mobiled_config, migrated_sim[".name"])
		else
			pin = migrated_sim.pin
			c:set(mobiled_config, migrated_sim[".name"], "iccid", iccid)
		end
		c:commit(mobiled_config)
		reload_sims(c)
	end

	return pin
end

function M.remove_all_pin_from_config()
	local c = uci.cursor()
	c:foreach(mobiled_config, "sim", function(s)
		c:delete(mobiled_config, s[".name"])
	end)
	c:commit(mobiled_config)
	reload_sims(c)
end

function M.remove_pin_from_config(pinType, iccid)
	local c = uci.cursor()
	c:foreach(mobiled_config, "sim", function(s) 
		if s.iccid == iccid then
			c:delete(mobiled_config, s[".name"])
			c:commit(mobiled_config)
			return false
		end
	end)
	reload_sims(c)
end

local function add_default_sim_config(defaults, cursor)
	local c = cursor or uci.cursor()
	local section = c:add(mobiled_config, "sim")
	for k, v in pairs(defaults) do
		c:set(mobiled_config, section, k, v)
	end
	c:commit(mobiled_config)
end

function M.store_pin_to_config(pinType, pin, iccid)
	local c = uci.cursor()
	local sim
	c:foreach(mobiled_config, "sim", function(s)
		if s.iccid == iccid and s.pin_type == pinType then
			sim = s[".name"]
			return false
		end
	end)
	if not sim then
		add_default_sim_config({ iccid = iccid, pin = pin, pin_type = pinType }, c)
	else
		c:set(mobiled_config, sim, "pin", pin)
		c:commit(mobiled_config)
	end
	reload_sims(c)
	return true
end

local function profile_equal(old, new)
	if old.apn ~= new.apn or old.pdptype ~= new.pdptype or old.username ~= new.username or old.password ~= new.password or old.authentication ~= new.authentication then
		return false
	end
	return true
end

local function profile_changed(oldconfig, newconfig)
	local changed_profiles = {}
	for _, newprofile in pairs(newconfig.profiles) do
		local oldprofile = M.get_profile(newprofile.id)
		if oldprofile then
			if not profile_equal(oldprofile, newprofile) then
				table.insert(changed_profiles, newprofile.id)
			end
		end
	end
	if #changed_profiles > 0 then
		return changed_profiles
	end
	return nil
end

local function extract_params(cfg, filter)
	local params = {}
	for k in pairs(filter) do
		if cfg[k] then
			if type(filter[k]) == "table" then
				params[k] = extract_params(cfg[k], filter[k])
			else
				params[k] = cfg[k]
			end
		end
	end
	return params
end

local supported_config_params = { "imei", "model" }
local function device_config_has_changes(oldconfig, newconfig, filter)
	local devices = {}
	for _, device_old in pairs(oldconfig.devices) do
		local oldparams = extract_params(device_old, filter)
		local newparams
		local device_config_param
		for _, param in pairs(supported_config_params) do
			for _, device_new in pairs(newconfig.devices) do
				if device_new[param] == device_old[param] then
					device_config_param = param
					newparams = extract_params(device_new, filter)
					break
				end
			end
			if newparams then
				break
			end
		end
		if newparams then
			if not helper.table_eq(oldparams, newparams) then
				table.insert(devices, { param = device_config_param, value = device_old[device_config_param] })
			end
		end
	end
	return devices
end

local function network_config_changed(oldconfig, newconfig)
	local filter = {
		lte_bands = "",
		radio_pref = "",
		strongest_cell_selection = "",
		mcc = "",
		mnc = "",
		roaming = "",
		network_selection = "",
		earfcn = ""
	}
	return device_config_has_changes(oldconfig, newconfig, filter)
end

local function device_config_changed(oldconfig, newconfig)
	local filter = {
		enabled = "",
		username = "",
		password = ""
	}
	return device_config_has_changes(oldconfig, newconfig, filter)
end

local function platform_config_changed(oldconfig, newconfig)
	local filter = {
		platform = {
			antenna = "",
			power_on = ""
		}
	}
	local oldparams = extract_params(oldconfig, filter)
	local newparams = extract_params(newconfig, filter)
	if helper.table_eq(oldparams, newparams) then return false end
	return true
end

local function get_device_idx_by_param(stateMachines, param, value)
	for _, sm in pairs(stateMachines) do
		if sm.device and sm.device.info[param] == value then
			return sm.dev_idx
		end
	end
end

function M.reloadconfig(stateMachines, plugins)
	local session_changed = {}

	local events = runtime.events
	local newconfig = M.loadconfig()
	local changed_profiles = profile_changed(config, newconfig)
	if changed_profiles then
		for k, sm in pairs(stateMachines) do
			if sm.device then
				local sessions = sm.device:get_data_sessions()
				for _, profile_id in pairs(changed_profiles) do
					runtime.log:info("Profile " .. profile_id .. " changed")
					for _, map in pairs(sessions) do
						if tonumber(map.profile_id) == tonumber(profile_id) then
							table.insert(session_changed, {session_id = map.session_id, dev_idx = sm.dev_idx})
						end
					end
				end
			end
		end
	end

	local platform_changed = platform_config_changed(config, newconfig)
	local network_config_devices = network_config_changed(config, newconfig)
	local device_config_devices = device_config_changed(config, newconfig)

	local reconfigure_plugin = false
	if config.globals.tracelevel ~= newconfig.globals.tracelevel then
		reconfigure_plugin = true
	end
	config = newconfig
	if reconfigure_plugin then
		local c = M.get_config()
		runtime.log:set_log_level(c.tracelevel)
		for _, p in pairs(plugins) do
			p:reconfigure({ tracelevel = c.tracelevel })
		end
	end

	if tonumber(config.globals.store_pin) == 0 then
		runtime.log:info("Clearing PIN storage")
		M.remove_all_pin_from_config()
	end

	if platform_changed then
		runtime.log:info("Platform config changed")
		events.send_event("mobiled", { event = "platform_config_changed" })
	end

	for _, dev in pairs(device_config_devices) do
		local dev_idx = get_device_idx_by_param(stateMachines, dev.param, dev.value)
		if dev_idx then
			runtime.log:info("Device config changed")
			events.send_event("mobiled", { event = "device_config_changed", dev_idx = dev_idx })
		end
	end

	for _, dev in pairs(network_config_devices) do
		local dev_idx = get_device_idx_by_param(stateMachines, dev.param, dev.value)
		if dev_idx then
			runtime.log:info("Network config changed")
			events.send_event("mobiled", { event = "network_config_changed", dev_idx = dev_idx })
		end
	end

	for _, session in pairs(session_changed) do
		runtime.log:info("Session config changed")
		events.send_event("mobiled", { event = "session_config_changed", session_id = session.session_id, dev_idx = session.dev_idx })
	end
end

function M.loadconfig()
	local c = {
		detectors = {},
		globals = {},
		debug_devices = {},
		states = {},
		profiles = {},
		devices = {},
		sims = {},
		modulespecific = {},
		device_defaults = {},
		operators = {}
	}

	local cursor = uci.cursor()

	cursor:foreach(mobiled_config, "debug_device", function(s) table.insert(c.debug_devices, s) end)
	cursor:foreach(mobiled_config, "detector", function(s) table.insert(c.detectors, s) end)
	cursor:foreach(mobiled_config, "mobiled", function(s) c.globals = s end)
	cursor:foreach(mobiled_config, "device_defaults", function(s) c.device_defaults = s end)
	cursor:foreach(mobiled_config, "device", function(s) table.insert(c.devices, s) end)
	cursor:foreach(mobiled_config, "sim", function(s) table.insert(c.sims, s) end)
	cursor:foreach(mobiled_config, "platform", function(s) c.platform = s end)
	cursor:foreach(mobiled_config, "modulespecific", function(s) c.modulespecific = s end)
	cursor:foreach(mobiled_config, "mobiled_state", function(s) c.states[s.name] = s end)
	cursor:foreach(mobiled_config, "profile", function(s) table.insert(c.profiles, s) end)
	cursor:foreach(mobiled_config, "operator", function(s) table.insert(c.operators, s) end)

	return c
end

function M.get_config()
	local c = {
		max_devices = 2,
		tracelevel = 3,
		store_pin = true
	}

	if config.platform then
		if not c.platform then c.platform = {} end
		c.platform.antenna = config.platform.antenna or "internal"
		c.platform.power_on = true
		if tonumber(config.platform.power_on) == 0 then
			c.platform.power_on = false
		end
	end

	if config.globals.tracelevel then
		c.tracelevel = tonumber(config.globals.tracelevel)
		if (c.tracelevel < 1 or c.tracelevel > 6) then
			c.tracelevel = 3
		end
	end

	if type(config.globals.allowed_imsi_ranges) == "table" then
		c.allowed_imsi_ranges = config.globals.allowed_imsi_ranges
	end

	if config.globals.detectors then c.detectors = config.globals.detectors end
	if config.globals.max_devices then c.max_devices = tonumber(config.globals.max_devices) end

	if config.debug_devices then
		c.debug_devices = config.debug_devices
	end

	if config.operators then
		c.operators = config.operators
	end

	if tonumber(config.globals.store_pin) == 0 then
		c.store_pin = false
	end

	c.pdn_retry_timer_value = tonumber(config.globals.pdn_retry_timer) or 60
	c.led_update_interval = tonumber(config.globals.led_update_interval)
	c.detectors = config.detectors

	return c
end

function M.get_raw_config()
	return config
end

local function is_radio_supported(device, pref)
	local device_capabilities = device:get_device_capabilities()
	if device_capabilities and device_capabilities.radio_interfaces then
		for _, radio in pairs(device_capabilities.radio_interfaces) do
			if radio.radio_interface == pref then return true end
		end
	end
	return nil
end

local function add_default_device_config(device, defaults, cursor)
	local c = cursor or uci.cursor()
	local section = c:add(mobiled_config, "device")
	for k, v in pairs(defaults) do
		if k == "radio_pref" then
			if not is_radio_supported(device, v) then
				v = "auto"
			end
		end
		c:set(mobiled_config, section, k, tostring(v))
	end
	c:commit(mobiled_config)
	table.insert(config.devices, defaults)
end

local function get_default_device_config()
	if not config.device_defaults.enabled then config.device_defaults.enabled = "1" end
	if not config.device_defaults.radio_pref then config.device_defaults.radio_pref = "lte" end
	if not config.device_defaults.roaming then config.device_defaults.roaming = "1" end
	if not config.device_defaults.network_selection then config.device_defaults.network_selection = "auto" end
	return config.device_defaults
end

function M.get_device_config(device)
	local device_config
	for _, d in pairs(config.devices) do
		if d[device.info.device_config_parameter] == device.info[device.info.device_config_parameter] then
			device_config = d
			break
		end
	end

	if not device_config then
		device_config = get_default_device_config()
		device_config[device.info.device_config_parameter] = device.info[device.info.device_config_parameter]
		device_config.model = device.info.model
		add_default_device_config(device, device_config)
	end

	local c = {
		device = { enabled = true },
		network = {
			radio_pref = {},
			roaming = true
		}
	}

	if tonumber(device_config.enabled) == 0 then
		c.device.enabled = false
	end

	c.device.username = device_config.username
	c.device.password = device_config.password

	for radio in string.gmatch(device_config.radio_pref, "[^%s]+") do
		local radio_pref = { type = radio }
		if radio == "lte" then
			if device_config.lte_bands then
				radio_pref.bands = {}
				for band in string.gmatch(device_config.lte_bands, "[^%s]+") do
					table.insert(radio_pref.bands, tonumber(band))
				end
			end
			if device_config.earfcn then
				radio_pref.arfcn = {}
				for earfcn in string.gmatch(device_config.earfcn, "[^%s]+") do
					table.insert(radio_pref.arfcn, tonumber(earfcn))
				end
			end
		end
		radio_pref.priority = #c.network.radio_pref+1
		table.insert(c.network.radio_pref, radio_pref)
	end

	c.reuse_profiles = device_config.reuse_profiles
	c.network.selection_pref = device_config.network_selection
	c.network.strongest_cell_selection = device_config.strongest_cell_selection
	if device_config.network_selection == "manual" then
		c.network.mcc = device_config.mcc
		c.network.mnc = device_config.mnc
	end
	if device_config.roaming == "false" or tonumber(device_config.roaming) == 0 then
		c.network.roaming = false
	end

	return c
end

function M.get_profile(id)
	if id and config.profiles then
		for _, p in pairs(config.profiles) do
			if tonumber(p.id) == tonumber(id) then
				return p
			end
		end
	end
	return nil, "Profile " .. tostring(id) .. " not found"
end

function M.set_device_enable(device, enable)
	if not device.info.device_config_parameter then
		return nil, "Device config parameter not set for device"
	end

	local device_config
	local c = uci.cursor()
	c:foreach(mobiled_config, "device", function(s)
		if s[device.info.device_config_parameter] == device.info[device.info.device_config_parameter] then
			device_config = s[".name"]
			return false
		end
	end)

	if not device_config then
		device_config = get_default_device_config()
		device_config[device.info.device_config_parameter] = device.info[device.info.device_config_parameter]
		device_config.model = device.info.model
		device_config.enabled = enable
		add_default_device_config(device, device_config, c)
	else
		c:set(mobiled_config, device_config, "enabled", enable)
		c:commit(mobiled_config)
	end

	config.devices = {}
	c:foreach(mobiled_config, "device", function(s) table.insert(config.devices, s) end)
end

function M.init(rt)
	runtime = rt
	config = M.loadconfig()
end

return M

