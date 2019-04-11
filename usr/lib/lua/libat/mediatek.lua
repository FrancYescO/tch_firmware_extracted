local match, tinsert = string.match, table.insert

local attty = require("libat.tty")
local helper = require("mobiled.scripthelpers")

local Mapper = {}
Mapper.__index = Mapper

local M = {}

function Mapper:get_device_info(device, info)
	if device.vid == "2001" then
		info.manufacturer = "D-Link"
		if device.pid == "7d0e" then
			info.model = "DWM-157"
		end
	elseif device.vid == "2020" then
		info.manufacturer = "Volacomm"
		if device.pid == "4000" then
			info.model = "303UB"
		end
	end
end

function Mapper:get_radio_signal_info(device, info)
	local ret = device:send_singleline_command('AT+ECSQ', "+ECSQ:", 100)
	if ret then
		local rscp, ecio = match(ret, '+ECSQ:%s?%d+,%s?%d+,%s?[-%d]+,%s?([-%d]+),%s?([-%d]+)')
		if tonumber(rscp) then
			info.rscp = tonumber(rscp) / 4
		end
		if tonumber(ecio) then
			info.ecio = tonumber(ecio) / 4
		end
	end
end

function Mapper:get_pin_info(device, info, type)
	local ret = device:send_singleline_command('AT+EPINC', "+EPINC:", 3000)
	if ret then
		local pin1_unlock_retries, pin2_unlock_retries, pin1_unblock_retries, pin2_unblock_retries = match(ret, "+EPINC:%s?(%d+),%s?(%d+),%s?(%d+),%s?(%d+)")
		if type == "pin1" then
			info.unlock_retries_left = pin1_unlock_retries
			info.unblock_retries_left = pin1_unblock_retries
		elseif type == "pin2" then
			info.unlock_retries_left = pin2_unlock_retries
			info.unblock_retries_left = pin2_unblock_retries
		end
	end
end

function Mapper:get_device_capabilities(device, info) --luacheck: no unused args
	info.radio_interfaces = {
		{ radio_interface = "auto" },
		{ radio_interface = "gsm" },
		{ radio_interface = "umts" }
	}
end

function Mapper:configure_device(device, config)
	-- TODO Implement the radio preference list
	local selected_radio = config.network.radio_pref[1]

	local mode = "2,2"
	if selected_radio.type == "umts" then
		mode = "1,0"
	elseif selected_radio.type == "gsm" then
		mode = "0,0"
	end

	device:send_command(string.format('AT+ERAT=%s', mode))
	return true
end

function Mapper:unsolicited(device, data, sms_data) --luacheck: no unused args
	if helper.startswith(data, "+PSBEARER:") then
		return true
	end
end

function M.create(runtime, device) --luacheck: no unused args
	local mapper = {
		mappings = {}
	}

	device.default_interface_type = "control"

	local modem_ports = attty.find_tty_interfaces(device.desc, { class = 0xff, subclass = 0x2, protocol = 0x1 })
	if modem_ports then
		for _, port in pairs(modem_ports) do
			tinsert(device.interfaces, { port = port, type = "modem" })
		end
	end

	local control_ports = attty.find_tty_interfaces(device.desc, { class = 0xff, number = 0x3 })
	if control_ports then
		for _, port in pairs(control_ports) do
			tinsert(device.interfaces, { port = port, type = "control" })
		end
	end

	device.sessions[1] = { proto = "ppp" }
	setmetatable(mapper, Mapper)
	return mapper
end

return M
