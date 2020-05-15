---------------------------------
--! @file
--! @brief The config module which parses UCI and sends out UBUS events on changes
---------------------------------

local uci = require('uci')
local helper = require("mobiled.scripthelpers")

local runtime
local __config = {}
local mobiled_config_file = "mobiled"

local M = {}

local function get_boolean(config_item, default)
	if not config_item then return default end
	return config_item ~= '0' and config_item ~= 'false' and config_item ~= false
end

local function reload_sims(cursor)
	__config.sims = {}
	cursor:foreach(mobiled_config_file, "sim", function(s)
		table.insert(__config.sims, s)
	end)
end

local function filter_uci_section(s)
	if s then
		s['.name'] = nil
		s['.type'] = nil
		s['.index'] = nil
		s['.anonymous'] = nil
	end
	return s
end

function M.get_pin_from_config(pinType, iccid)
	local pin, migrated_sim
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
		c:close()
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
	c:close()
end

function M.remove_pin_from_config(pinType, iccid)
	local c = uci.cursor()
	c:foreach(mobiled_config_file, "sim", function(s)
		if s.iccid == iccid and s.pin_type == pinType then
			c:delete(mobiled_config_file, s[".name"])
			c:commit(mobiled_config_file)
			return false
		end
	end)
	reload_sims(c)
	c:close()
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
	local c, sim = uci.cursor()
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
	c:close()
	return true
end

function M.get_radio_preferences()
	return __config.radio_preferences
end

function M.profile_equal(old, new)
	local profile_params = {
		"apn",
		"pdptype",
		"username",
		"password",
		"authentication",
		"dial_string"
	}
	for _, param in pairs(profile_params) do
		if old[param] ~= new[param] then
			return false
		end
	end
	return true
end

local function profile_changed(newconfig)
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

local function get_device_idx_by_param(stateMachines, param, value)
	for _, sm in pairs(stateMachines) do
		if sm.device and sm.device.info[param] == value then
			return sm.dev_idx
		end
	end
end

local function device_config_has_changes(oldconfig, newconfig, filter, stateMachines)
	local devices = {}
	for _, device_old in pairs(oldconfig.devices) do
		local oldparams = extract_params(device_old, filter)
		local newparams, device_config_param
		local supported_config_params = { "imei", "model" }
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
		if newparams and not helper.table_eq(oldparams, newparams) then
			local dev_idx = get_device_idx_by_param(stateMachines, device_config_param, device_old[device_config_param])
			if dev_idx then
				devices[dev_idx] = true
			end
		end
	end
	for _, device_old in pairs(oldconfig.device_specific) do
		local key = device_old.key
		if key then
			local val = device_old[key]
			if val then
				local dev_idx = get_device_idx_by_param(stateMachines, key, val)
				if dev_idx then
					for _, device_new in pairs(newconfig.device_specific) do
						if device_new.key == key and device_new[key] == device_old[key] and not helper.table_eq(device_old, device_new) then
							devices[dev_idx] = true
						end
					end
				end
			end
		end
	end
	return devices
end

local function device_config_changed(oldconfig, newconfig, stateMachines)
	local filter = {
		enabled = true,
		username = true,
		password = true,
		earfcn = true,
		lte_bands = true,
		radio_pref = true,
		mcc = true,
		mnc = true,
		network_selection = true,
		roaming = true,
		detach_mode = true,
		disable_mode = true,
		volte_enabled = true
	}
	for k in pairs(__config.device_customer_defaults) do
		filter[k] = true
	end
	return device_config_has_changes(oldconfig, newconfig, filter, stateMachines)
end

local function platform_config_changed(oldconfig, newconfig)
	local filter = {
		platform = {
			antenna = true,
			power_on = true
		}
	}
	local oldparams = extract_params(oldconfig, filter)
	local newparams = extract_params(newconfig, filter)
	return not helper.table_eq(oldparams, newparams)
end

function M.reloadconfig(stateMachines, plugins, force)
	local session_changed = {}

	local events = runtime.events
	local newconfig = M.loadconfig()
	local changed_profiles = profile_changed(newconfig)
	if changed_profiles then
		for _, sm in pairs(stateMachines) do
			if sm.device then
				local sessions = sm.device:get_data_sessions()
				for _, profile_id in pairs(changed_profiles) do
					runtime.log:notice("Profile " .. profile_id .. " changed")
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
	local device_config_devices = device_config_changed(__config, newconfig, stateMachines)

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
		runtime.log:notice("Clearing PIN storage")
		M.remove_all_pin_from_config()
	end

	if platform_changed or force then
		runtime.log:notice("Platform config changed")
		events.send_event("mobiled", { event = "platform_config_changed" })
	end

	for dev_idx in pairs(device_config_devices) do
		runtime.log:notice("Device config changed")
		events.send_event("mobiled", { event = "device_config_changed", dev_idx = dev_idx })
	end

	for _, session in pairs(session_changed) do
		runtime.log:notice("Session config changed")
		events.send_event("mobiled", { event = "session_config_changed", session_id = session.session_id, dev_idx = session.dev_idx })
	end
end

function M.loadconfig()
	local c = {
		sims = {},
		states = {},
		devices = {},
		profiles = {},
		detectors = {},
		operators = {},
		debug_devices = {},
		device_specific = {},
		radio_preferences = {},
		sessions = {}
	}

	local cursor = uci.cursor()
	cursor:foreach("network", "interface", function(s)
		if s.proto == "mobiled" and s.session_id and s.profile then
			s.interface = s['.name']
			table.insert(c.sessions, filter_uci_section(s))
		end
	end)

	cursor:foreach("mobiled_sessions", "session", function(s)
		if s.session_id and s.profile then
			table.insert(c.sessions, filter_uci_section(s))
		end
	end)

	c.globals = filter_uci_section(cursor:get_all(mobiled_config_file, "globals")) or {}
	c.platform = filter_uci_section(cursor:get_all(mobiled_config_file, "platform")) or {}
	c.device_defaults = filter_uci_section(cursor:get_all(mobiled_config_file, "device_defaults")) or {}
	c.device_customer_defaults = filter_uci_section(cursor:get_all(mobiled_config_file, "device_customer_defaults")) or {}

	cursor:foreach(mobiled_config_file, "sim", function(s) table.insert(c.sims, s) end)
	cursor:foreach(mobiled_config_file, "device", function(s) table.insert(c.devices, s) end)
	cursor:foreach(mobiled_config_file, "mobiled_state", function(s) c.states[s.name] = filter_uci_section(s) end)
	cursor:foreach(mobiled_config_file, "profile", function(s) table.insert(c.profiles, s) end)
	cursor:foreach(mobiled_config_file, "detector", function(s) table.insert(c.detectors, filter_uci_section(s)) end)
	cursor:foreach(mobiled_config_file, "operator", function(s)
		if s.mcc and s.mnc then
			table.insert(c.operators, filter_uci_section(s))
		end
	end)
	cursor:foreach(mobiled_config_file, "debug_device", function(s) table.insert(c.debug_devices, s) end)
	cursor:foreach(mobiled_config_file, "radio_preference", function(s) table.insert(c.radio_preferences, filter_uci_section(s)) end)

	cursor:foreach("mobiled_device_specific", "device", function(s)
		table.insert(c.device_specific, filter_uci_section(s))
	end)

	cursor:close()

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
	c.attach_retry_timer_value = tonumber(__config.globals.attach_retry_timer) or 300
	c.attach_retry_count = tonumber(__config.globals.attach_retry_count) or 2

	c.led_update_interval = tonumber(__config.globals.led_update_interval)
	c.detectors = __config.detectors

	c.sms_database_path = __config.globals.sms_database_path or '/etc/sms.db'
	c.sms_max_messages = tonumber(__config.globals.sms_max_messages) or 255

	return c
end

function M.get_raw_config()
	return __config
end

local function add_default_device_config(defaults, cursor)
	local section = cursor:add(mobiled_config_file, "device")
	for k, v in pairs(defaults) do
		cursor:set(mobiled_config_file, section, k, tostring(v))
	end
	cursor:commit(mobiled_config_file)
end

local function get_default_device_config()
	if not __config.device_defaults.enabled then __config.device_defaults.enabled = "1" end
	if not __config.device_defaults.volte_enabled then __config.device_defaults.volte_enabled = "1" end
	if not __config.device_defaults.radio_pref then __config.device_defaults.radio_pref = "auto" end
	if not __config.device_defaults.roaming then __config.device_defaults.roaming = "none" end
	if not __config.device_defaults.network_selection then __config.device_defaults.network_selection = "auto" end
	for k, v in pairs(__config.device_customer_defaults) do
		runtime.log:info("Adding customer specific parameter: %s", k)
		__config.device_defaults[k] = v
	end
	return __config.device_defaults
end

local function get_validated_detach_mode(mode)
	if mode == "none" or mode == "detach" or mode == "poweroff" then
		return mode
	end
	return "detach"
end

local function get_validated_apn_mode(mode)
	if mode == "network" or mode == "autoconf" then
		return mode
	end
	return "network"
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
				autoconnect = get_boolean(session_config.autoconnect, false),
				activated = get_boolean(session_config.activated, false),
				optional = get_boolean(session_config.optional, false),
				internal = get_boolean(session_config.internal, false),
				session_id = tonumber(session_config.session_id),
				profile_id = session_config.profile,
				interface = session_config['.name'],
				name = session_config.name
			}
			table.insert(sessions, session)
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
		add_default_device_config(device_config, cursor)
		__config.devices = {}
		cursor:foreach(mobiled_config_file, "device", function(s) table.insert(__config.devices, s) end)
		cursor:close()
	end

	local c = {
		device = {
			enabled = true,
			volte_enabled = true,
			apn_mode = get_validated_apn_mode(device_config.apn_mode),
			detach_mode = get_validated_detach_mode(device_config.detach_mode),
			disable_mode = get_validated_disable_mode(device_config.disable_mode),
			firmware_upgrade_timeout = tonumber(device_config.firmware_upgrade_timeout) or 300
		},
		network = {
			radio_pref = {},
			roaming = "none"
		}
	}

	if device_config.enabled == '0' or device_config.enabled == 'false' then
		c.device.enabled = false
	end

	if device_config.volte_enabled == '0' or device_config.volte_enabled == 'false' then
		c.device.volte_enabled = false
	end

	c.device.username = device_config.username
	c.device.password = device_config.password

	local supported_modes = {}
	local device_capabilities = device:get_device_capabilities()
	if device_capabilities and device_capabilities.radio_interfaces then
		for _, radio in pairs(device_capabilities.radio_interfaces) do
			supported_modes[radio.radio_interface] = true
		end
	end
	for radio in string.gmatch(device_config.radio_pref or "auto", "([^%s?]+)%??") do
		if supported_modes[radio] then
			local radio_pref = { type = radio }
			if radio == "lte" then
				if device_config.lte_bands then
					radio_pref.bands = {}
					for band in string.gmatch(device_config.lte_bands, "[^%s]+") do
						table.insert(radio_pref.bands, tonumber(band))
					end
				end
				if type(device_config.earfcn) == "table" then
					radio_pref.arfcn = {}
					for _, earfcn in ipairs(device_config.earfcn) do
						local arfcn, pci = string.match(earfcn, "^(%d+),(%d+)$")
						if not arfcn then
							arfcn = string.match(earfcn, "^(%d+)$")
						end
						if arfcn then
							local entry = {
								pci = pci,
								arfcn = tonumber(arfcn)
							}
							table.insert(radio_pref.arfcn, entry)
						end
					end
				end
			end
			table.insert(c.network.radio_pref, radio_pref)
		end
	end
	if #c.network.radio_pref == 0 then
		table.insert(c.network.radio_pref, { type = "auto" })
	end

	c.reuse_profiles = device_config.reuse_profiles
	c.network.selection_pref = device_config.network_selection
	c.network.strongest_cell_selection = device_config.strongest_cell_selection
	if device_config.network_selection == "manual" then
		c.network.mcc = device_config.mcc
		c.network.mnc = device_config.mnc
	end

	if device_config.roaming == "international" or device_config.roaming == "true" or tonumber(device_config.roaming) == 1 then
		c.network.roaming = "international"
	elseif device_config.roaming == "national" then
		c.network.roaming = "national"
	else
		c.network.roaming = "none"
	end

	local keys = { "model", "software_version", "hardware_version", "manufacturer" }
	for _, section in pairs(__config.device_specific) do
		local matched = true
		for _, key in pairs(keys) do
			local key_values = section[key]
			local found = true
			if type(key_values) == "table" then
				found = false
				for _, val in pairs(key_values) do
					if device.info[key] == val then
						found = true
						break
					end
				end
			end
			if not found then
				matched = false
				break
			end
		end
		if matched then
			for k, v in pairs(section) do
				c.device[k] = v
			end
		end
	end

	for k in pairs(__config.device_customer_defaults) do
		c.device[k] = device_config[k]
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
		add_default_device_config(device_config, c)
	else
		c:set(mobiled_config_file, device_config, "enabled", enable)
		c:commit(mobiled_config_file)
	end

	__config.devices = {}
	c:foreach(mobiled_config_file, "device", function(s) table.insert(__config.devices, s) end)
	c:close()
end

function M.init(rt)
	runtime = rt
	__config = M.loadconfig()
end

return M
