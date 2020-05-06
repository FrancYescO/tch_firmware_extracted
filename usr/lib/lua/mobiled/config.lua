---------------------------------
--! @file
--! @brief The config module which parses UCI and sends out UBUS events on changes
---------------------------------

local tonumber, table, pairs, type, string, tostring = tonumber, table, pairs, type, string, tostring

local uci = require('uci')
local helper = require("mobiled.scripthelpers")

local runtime
local __config = {}
local mobiled_config_file = "mobiled"

local M = {}

local function reload_sims(cursor)
	local c = cursor or uci.cursor()
	__config.sims = {}
	c:foreach(mobiled_config_file, "sim", function(s)
		table.insert(__config.sims, s)
	end)
end

function M.get_pin_from_config(pinType, iccid)
	local pin
	local migrated_sim
	for _, s in pairs(__config.sims) do
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
			c:delete(mobiled_config_file, migrated_sim[".name"])
		else
			pin = migrated_sim.pin
			c:set(mobiled_config_file, migrated_sim[".name"], "iccid", iccid)
		end
		c:commit(mobiled_config_file)
		reload_sims(c)
	end

	return pin
end

function M.remove_all_pin_from_config()
	local c = uci.cursor()
	c:foreach(mobiled_config_file, "sim", function(s)
		c:delete(mobiled_config_file, s[".name"])
	end)
	c:commit(mobiled_config_file)
	reload_sims(c)
end

function M.remove_pin_from_config(pinType, iccid)
	local c = uci.cursor()
	c:foreach(mobiled_config_file, "sim", function(s)
		if s.iccid == iccid then
			c:delete(mobiled_config_file, s[".name"])
			c:commit(mobiled_config_file)
			return false
		end
	end)
	reload_sims(c)
end

local function add_default_sim_config(defaults, cursor)
	local c = cursor or uci.cursor()
	local section = c:add(mobiled_config_file, "sim")
	for k, v in pairs(defaults) do
		c:set(mobiled_config_file, section, k, v)
	end
	c:commit(mobiled_config_file)
end

function M.store_pin_to_config(pinType, pin, iccid)
	local c = uci.cursor()
	local sim
	c:foreach(mobiled_config_file, "sim", function(s)
		if s.iccid == iccid and s.pin_type == pinType then
			sim = s[".name"]
			return false
		end
	end)
	if not sim then
		add_default_sim_config({ iccid = iccid, pin = pin, pin_type = pinType }, c)
	else
		c:set(mobiled_config_file, sim, "pin", pin)
		c:commit(mobiled_config_file)
	end
	reload_sims(c)
	return true
end

function M.get_radio_preferences()
	return __config.radio_preferences
end

function M.profile_equal(old, new)
	return old.apn == new.apn and old.pdptype == new.pdptype and old.username == new.username and old.password == new.password and old.authentication == new.authentication
end

local function profile_changed(oldconfig, newconfig)
	local changed_profiles = {}
	for _, newprofile in pairs(newconfig.profiles) do
		local oldprofile = M.get_profile(newprofile.id)
		if oldprofile then
			if not M.profile_equal(oldprofile, newprofile) then
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

local function device_config_changed(oldconfig, newconfig)
	local filter = {
		enabled = "",
		username = "",
		password = "",
		earfcn = "",
		lte_bands = "",
		radio_pref = "",
		mcc = "",
		mnc = "",
		network_selection = "",
		roaming = "",
		detach_mode = "",
		disable_mode = "",
		-- These options were added to support the random attach delay for Telstra:
		minimum_attach_delay = "",
		maximum_attach_delay = ""
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
	local changed_profiles = profile_changed(__config, newconfig)
	if changed_profiles then
		for _, sm in pairs(stateMachines) do
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

	local platform_changed = platform_config_changed(__config, newconfig)
	local device_config_devices = device_config_changed(__config, newconfig)

	local reconfigure_plugin = false
	if __config.globals.tracelevel ~= newconfig.globals.tracelevel then
		reconfigure_plugin = true
	end
	__config = newconfig
	if reconfigure_plugin then
		local c = M.get_config()
		runtime.log:set_log_level(c.tracelevel)
		for _, p in pairs(plugins) do
			p:reconfigure({ tracelevel = c.tracelevel })
		end
	end

	if tonumber(__config.globals.store_pin) == 0 then
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
		operators = {},
		radio_preferences = {},
		sessions = {}
	}

	local cursor = uci.cursor()

	cursor:foreach("network", "interface", function(s)
		if s.proto == "mobiled" and s.session_id and s.profile then
			table.insert(c.sessions, s)
		end
	end)

	cursor:foreach(mobiled_config_file, "debug_device", function(s) table.insert(c.debug_devices, s) end)
	cursor:foreach(mobiled_config_file, "detector", function(s) table.insert(c.detectors, s) end)
	cursor:foreach(mobiled_config_file, "mobiled", function(s) c.globals = s end)
	cursor:foreach(mobiled_config_file, "device_defaults", function(s) c.device_defaults = s end)
	cursor:foreach(mobiled_config_file, "device", function(s) table.insert(c.devices, s) end)
	cursor:foreach(mobiled_config_file, "sim", function(s) table.insert(c.sims, s) end)
	cursor:foreach(mobiled_config_file, "platform", function(s) c.platform = s end)
	cursor:foreach(mobiled_config_file, "modulespecific", function(s) c.modulespecific = s end)
	cursor:foreach(mobiled_config_file, "mobiled_state", function(s) c.states[s.name] = s end)
	cursor:foreach(mobiled_config_file, "profile", function(s) table.insert(c.profiles, s) end)
	cursor:foreach(mobiled_config_file, "operator", function(s) table.insert(c.operators, s) end)
	cursor:foreach(mobiled_config_file, "radio_preference", function(s) table.insert(c.radio_preferences, s) end)

	return c
end

function M.get_config()
	local c = {
		max_devices = 2,
		tracelevel = 3,
		store_pin = true
	}

	if __config.platform then
		if not c.platform then c.platform = {} end
		c.platform.antenna = __config.platform.antenna or "internal"
		c.platform.power_on = true
		if tonumber(__config.platform.power_on) == 0 then
			c.platform.power_on = false
		end
	end

	if __config.globals.tracelevel then
		c.tracelevel = tonumber(__config.globals.tracelevel)
		if (c.tracelevel < 1 or c.tracelevel > 6) then
			c.tracelevel = 3
		end
	end

	if type(__config.globals.allowed_imsi_ranges) == "table" then
		c.allowed_imsi_ranges = __config.globals.allowed_imsi_ranges
	end

	if __config.globals.detectors then c.detectors = __config.globals.detectors end
	if __config.globals.max_devices then c.max_devices = tonumber(__config.globals.max_devices) end

	if __config.debug_devices then
		c.debug_devices = __config.debug_devices
	end

	if #__config.operators >= 1 then
		c.operators = __config.operators
	end

	if tonumber(__config.globals.store_pin) == 0 then
		c.store_pin = false
	end

	c.pdn_retry_timer_value = tonumber(__config.globals.pdn_retry_timer) or 60
	c.led_update_interval = tonumber(__config.globals.led_update_interval)
	c.detectors = __config.detectors

	return c
end

function M.get_raw_config()
	return __config
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
	local section = cursor:add(mobiled_config_file, "device")
	for k, v in pairs(defaults) do
		if k == "radio_pref" then
			if not is_radio_supported(device, v) then
				v = "auto"
			end
		end
		cursor:set(mobiled_config_file, section, k, tostring(v))
	end
	cursor:commit(mobiled_config_file)
end

local function get_default_device_config()
	if not __config.device_defaults.enabled then __config.device_defaults.enabled = "1" end
	if not __config.device_defaults.radio_pref then __config.device_defaults.radio_pref = "lte" end
	if not __config.device_defaults.roaming then __config.device_defaults.roaming = "international" end
	if not __config.device_defaults.network_selection then __config.device_defaults.network_selection = "auto" end
	return __config.device_defaults
end

local function get_validated_detach_mode(mode)
	if mode == "none" or mode == "detach" or mode == "poweroff" then
		return mode
	end
	return "detach"
end

local function get_validated_disable_mode(mode)
	if mode == "airplane" or mode == "lowpower" then
		return mode
	end
	return "lowpower"
end

function M.get_session_config(device)
	local sessions = {}
	for _, session_config in pairs(__config.sessions) do
		if not session_config.dev_idx or tonumber(session_config.dev_idx) == device.sm.dev_idx then
			local session = {
				session_id = tonumber(session_config.session_id),
				profile_id = session_config.profile,
				optional = session_config.optional == '1' or session_config.optional == 'true',
				interface = session_config['.name']
			}
			sessions[session.session_id] = session
		end
	end
	return sessions
end

function M.get_device_config(device)
	if not device.info.device_config_parameter or not device.info[device.info.device_config_parameter] then
		return nil, "Invalid device config parameter"
	end

	local device_config
	for _, d in pairs(__config.devices) do
		if d[device.info.device_config_parameter] == device.info[device.info.device_config_parameter] then
			device_config = d
			break
		end
	end

	if not device_config then
		device_config = get_default_device_config()
		runtime.log:info("Adding device config %s:%s", device.info.device_config_parameter, device.info[device.info.device_config_parameter])
		device_config[device.info.device_config_parameter] = device.info[device.info.device_config_parameter]
		device_config.model = device.info.model
		local cursor = uci.cursor()
		add_default_device_config(device, device_config, cursor)
		__config.devices = {}
		cursor:foreach(mobiled_config_file, "device", function(s) table.insert(__config.devices, s) end)
	end

	local c = {
		device = {
			enabled = true,
			detach_mode = get_validated_detach_mode(device_config.detach_mode),
			disable_mode = get_validated_disable_mode(device_config.disable_mode)
		},
		network = {
			radio_pref = {},
			roaming = "international",
		}
	}

	if tonumber(device_config.enabled) == 0 then
		c.device.enabled = false
	end

	c.device.username = device_config.username
	c.device.password = device_config.password

	-- These options were added to support the random attach delay for Telstra:
	c.device.minimum_attach_delay = device_config.minimum_attach_delay
	c.device.maximum_attach_delay = device_config.maximum_attach_delay

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
		c.network.radio_pref[#c.network.radio_pref+1] = radio_pref
	end

	c.reuse_profiles = device_config.reuse_profiles
	c.network.selection_pref = device_config.network_selection
	c.network.strongest_cell_selection = device_config.strongest_cell_selection
	if device_config.network_selection == "manual" then
		c.network.mcc = device_config.mcc
		c.network.mnc = device_config.mnc
	end

	if device_config.roaming == "false" or tonumber(device_config.roaming) == 0 or device_config.roaming == "none" then
		c.network.roaming = "none"
	elseif device_config.roaming == "national" then
		c.network.roaming = "national"
	end

	return c
end

function M.get_profile(id)
	if id and __config.profiles then
		for _, p in pairs(__config.profiles) do
			if tonumber(p.id) == tonumber(id) then
				return p
			end
		end
	end
	return nil, "Profile " .. tostring(id) .. " not found"
end

function M.set_device_enable(device, enable)
	if not device.info.device_config_parameter or not device.info[device.info.device_config_parameter] then
		return nil, "Invalid device config parameter"
	end

	local device_config
	local c = uci.cursor()
	c:foreach(mobiled_config_file, "device", function(s)
		if s[device.info.device_config_parameter] == device.info[device.info.device_config_parameter] then
			device_config = s[".name"]
			return false
		end
	end)

	if not device_config then
		device_config = get_default_device_config()
		runtime.log:info("Adding device config %s:%s", device.info.device_config_parameter, device.info[device.info.device_config_parameter])
		device_config[device.info.device_config_parameter] = device.info[device.info.device_config_parameter]
		device_config.model = device.info.model
		device_config.enabled = enable
		add_default_device_config(device, device_config, c)
	else
		c:set(mobiled_config_file, device_config, "enabled", enable)
		c:commit(mobiled_config_file)
	end

	__config.devices = {}
	c:foreach(mobiled_config_file, "device", function(s) table.insert(__config.devices, s) end)
end

function M.init(rt)
	runtime = rt
	__config = M.loadconfig()
end

return M
