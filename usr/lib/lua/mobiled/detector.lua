---------------------------------
--! @file
--! @brief The detector module which is responsible finding usable USB and ethernet devices
---------------------------------

local helper = require("mobiled.scripthelpers")
local pairs, ipairs, string, table, type = pairs, ipairs, string, table, type

local M = {}

local usb_descriptors = {
	{
		plugin = "libat",
		device_identifiers = {
			-- Quectel EC25 and EP06
			{
				vid = "2c7c"
			},
                        -- IK41 Alcatel dongle USBMODE 0
			{
                                vid = "1bbb",
                                pid = "00b6"
                        },
                        -- IK41 Alcatel dongle USBMODE 1
                        {
                                vid = "1bbb",
                                pid = "01aa"
                        }
		}
	},
	{
		plugin = "libwebapi",
		device_identifiers = {
			-- ZTE MF730E
			{
				vid = "19d2",
				pid = "1405"
			},
			-- ZTE MF823
			{
				vid = "19d2",
				pid = "1403"
			},
			-- ZTE MF710 / Vodafone K4201
			{
				vid = "19d2",
				pid = "1048"
			},
			-- Huawei E8372 (TA)
			{
				vid = "12d1",
				pid = "14db"
			},
			-- Alcatel
			{
				vid = "1bbb"
			}
		}
	},
	{
		plugin = "libsequans",
		device_identifiers = {
			{
				vid = "258d",
				pid = "2000"
			}
		}
	},
	{
		plugin = "libsierra",
		driver_combinations = {
			{
				"GobiSerial",
				"Sierra_GobiNet"
			},
			{
				"GobiSerial",
				"GobiNet"
			}
		}
	},
	{
		plugin = "libgct",
		driver_combinations = {
			{
				"gdm_mux",
				"gdm_lte"
			}
		}
	},
	{
		plugin = "libqmi",
		driver_combinations = {
			{
				"option",
				"qmi_wwan"
			}
		}
	},
	{
		plugin = "libat",
		driver_combinations = {
			{
				"cdc_acm"
			},
			{
				"option",
				"huawei_cdc_ncm"
			},
			{
				"option",
				"BroadMobi_GobiNet"
			},
			{
				"option",
				"Quectel_GobiNet"
			},
			{
				"option",
				"Sierra_GobiNet"
			},
			{
				"option",
				"GobiNet"
			},
			{
				"option"
			},
			{
				"sierra"
			}
		}
	}
}

-- Returns a table of all top-level USB device entries in sysfs (e.g. 1-1.5)
local function get_usb_devices()
	local devices = {}
	local devs = helper.split(helper.capture_cmd("ls /sys/bus/usb/devices", "r"), "\n")
	for _, l in pairs(devs) do
		if string.match(l, "^%d+-%d+.%d+.%d+$") or string.match(l, "^%d+-%d+.%d+$") or string.match(l, "^%d+-%d+$") then
			table.insert(devices, l)
		end
	end
	return devices
end

local function compare_interface_names(left, right)
	return left.name < right.name
end

-- Returns a list of drivers used by a certain USB device (e.g. 1-1.5) as well as the list of linked network interfaces, vid and pid
local function get_usb_info(desc)
	local info = {
		drivers = {}
	}

	local ret = helper.split(helper.capture_cmd("find /sys/bus/usb/drivers -name '" .. desc .. ":*' | cut -d '/' -f 6", "r"), "\n")
	for _, driver in pairs(ret) do
		if info.drivers[driver] then info.drivers[driver] = info.drivers[driver] + 1 else info.drivers[driver] = 1 end
	end

	info.network_interfaces = {}
	local networks = helper.split(helper.capture_cmd("find /sys/bus/usb/devices/" .. desc .. "/ -name net 2>/dev/null", "r"), "\n")
	for _, network in pairs(networks) do
		local intf = helper.split(helper.capture_cmd("ls " .. network, "r"), "\n")
		local usb_interface = network:match("^/sys/bus/usb/devices/.-/(.-)/net$")
		if intf and usb_interface then
			for _, i in pairs(intf) do
				i = string.match(i, "[A-Za-z0-9]+")
				table.insert(info.network_interfaces, {
					name = i,
					desc = "usb/" .. usb_interface
				})
			end
		end
	end
	table.sort(info.network_interfaces, compare_interface_names)

	ret = helper.read_file("/sys/bus/usb/devices/" .. desc .. "/idVendor")
	if ret then info.vid = string.match(ret, "([0-9a-f]+)") end
	ret = helper.read_file("/sys/bus/usb/devices/" .. desc .. "/idProduct")
	if ret then info.pid = string.match(ret, "([0-9a-f]+)") end
	ret = helper.read_file("/sys/bus/usb/devices/" .. desc .. "/product")
	if ret then info.product = string.gsub(ret, "\n", "") end
	info.port = desc

	return info
end

-- Matches a USB device to a set of drivers
local function match_drivers(plugin_driver_combinations, usb_info)
	if type(plugin_driver_combinations) == "table" and type(usb_info.drivers) == "table" then
		for _, drivers in ipairs(plugin_driver_combinations) do
			local drivers_present = true
			for _, driver in ipairs(drivers) do
				if not usb_info.drivers[driver] then drivers_present = false; break end
			end
			if drivers_present then return true end
		end
	end
end

-- Matches a USB device to a a vid/pid
local function match_identifiers(plugin_device_identifiers, usb_info)
	if type(plugin_device_identifiers) == "table" then
		for _, identifier in ipairs(plugin_device_identifiers) do
			if usb_info.vid == identifier.vid and (not identifier.pid or usb_info.pid == identifier.pid) then
				return true
			end
		end
	end
end

local function check_usb_detector_allowed(detector, usb_info)
	local allowed = true
	if type(detector.allowed_vidpid) == "table" then
		local match = false
		for _, vidpid in pairs(detector.allowed_vidpid) do
			local vid, pid = string.match(vidpid, "([A-Fa-f%d]+):([A-Fa-f%d]+)")
			if vid == usb_info.vid and pid == usb_info.pid then
				match = true
			end
		end
		if not match then
			allowed = false
		end
	end
	if type(detector.allowed_ports) == "table" then
		local match = false
		for _, port in pairs(detector.allowed_ports) do
			if usb_info.port == port then
				match = true
			end
		end
		if not match then
			allowed = false
		end
	end
	return allowed
end

local function detect_usb_devices(runtime, detector)
	local devices = get_usb_devices()
	for _, desc in pairs(devices) do
		local usb_info = get_usb_info(desc)
		local allowed = check_usb_detector_allowed(detector, usb_info)
		if allowed then
			for _, descriptor in ipairs(usb_descriptors) do
				local found = match_identifiers(descriptor.device_identifiers, usb_info)
				if not found then
					found = match_drivers(descriptor.driver_combinations, usb_info)
				end
				if found and not runtime.mobiled.device_exists(desc) then
					return {
						dev_desc = desc,
						dev_type = "usb",
						plugin_name = descriptor.plugin,
						network_interfaces = usb_info.network_interfaces,
						pid = usb_info.pid,
						vid = usb_info.vid,
						product = usb_info.product
					}
				end
			end
		end
	end
	return nil
end

local function detect_eth_devices()
	return nil
end

local function detect_misc_devices(runtime)
	local descriptions = { "MDM9628" , "MDM9207" }
	local match
	for _, desc in pairs(descriptions) do
		local ret = helper.capture_cmd("grep " .. desc .. " /proc/cpuinfo")
		if ret and string.match(ret, desc) and not runtime.mobiled.device_exists(desc) then
			match = desc
			break
		end
	end
	if match then
		local network_interfaces = {}
		for _, interface_name in pairs(helper.split(helper.capture_cmd("find /sys/class/net -name 'rmnet_data*' -exec basename {} \\;", "r"), "\n")) do
			table.insert(network_interfaces, {
				name = interface_name,
				desc = "rmnet"
			})
		end
		table.sort(network_interfaces, compare_interface_names)
		return {
			dev_desc = match,
			device_type = "ontarget",
			plugin_name = "libqmiqti",
			network_interfaces = network_interfaces
		}
	end
	return nil
end

local function detect_debug_devices(runtime)
	local config = runtime.mobiled.get_config()
	if type(config.debug_devices) == "table" then
		for _, device in pairs(config.debug_devices) do
			local plugin = device.library
			local dev_desc = device.dev_desc
			local network_interfaces = {}
			if device.network_interfaces then
				for i in string.gmatch(device.network_interfaces, "%S+") do
					table.insert(network_interfaces, {
						name = i,
						desc = "dummy"
					})
				end
			end
			if not runtime.mobiled.device_exists(dev_desc) then
				return {
					dev_desc = dev_desc,
					dev_type = "debug",
					plugin_name = plugin,
					network_interfaces = network_interfaces,
					debug_device = device
				}
			end
		end
	end
	return nil
end

local function get_detector(detectors, t)
	for _, detector in pairs(detectors) do
		if detector.type == t then
			return detector
		end
	end
	return nil
end

function M.scan(runtime)
	local config = runtime.mobiled.get_config()
	local dev, errMsg = detect_debug_devices(runtime)
	if dev then return dev end
	if errMsg then runtime.log:info(errMsg) end
	local detector = get_detector(config.detectors, "eth")
	if detector then
		dev, errMsg = detect_eth_devices(runtime)
		if dev then return dev end
		if errMsg then runtime.log:error(errMsg) end
	end
	detector = get_detector(config.detectors, "usb")
	if detector then
		dev, errMsg = detect_usb_devices(runtime, detector)
		if dev then return dev end
		if errMsg then runtime.log:error(errMsg) end
	end
	detector = get_detector(config.detectors, "misc")
	if detector then
		dev, errMsg = detect_misc_devices(runtime)
		if dev then return dev end
		if errMsg then runtime.log:error(errMsg) end
	end
	return nil
end

function M.info(device)
	if device and device.type == "usb" then
		return get_usb_info(device.desc)
	end
	return nil
end

return M
