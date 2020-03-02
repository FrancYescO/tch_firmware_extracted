local pairs, string, tonumber = pairs, string, tonumber

local helper = require("mobiled.scripthelpers")
local atchannel = require("atchannel")
local attty = require("libat.tty")

local Mapper = {}
Mapper.__index = Mapper

local M = {}

function Mapper:get_device_capabilities(device, info)
	if device.pid == "0031" or device.pid == "0117" then
		info.radio_interfaces = {
			{ radio_interface = "gsm" },
			{ radio_interface = "umts" },
			{ radio_interface = "auto" }
		}
	end
end

function Mapper:get_pin_info(device, info, type)
	if type == "pin1" then
		local ret = device:send_singleline_command('AT+ZPINPUK=?', '+ZPINPUK:')
		if ret then
			info.unlock_retries_left, info.unblock_retries_left = string.match(ret, '+ZPINPUK:%s*(%d+),(%d+)')
		end
	end
end

function Mapper:get_radio_signal_info(device, info)
	local ret = device:send_singleline_command('AT+ZRSSI', '+ZRSSI:')
	if ret then
		local rssi, ecio, rscp = string.match(ret, '+ZRSSI:%s*(%d+),(%d+),(%d+)')
		if rssi then info.rssi = (tonumber(rssi)*-1) end
		if ecio and ecio ~= "1000" then info.ecio = (tonumber(ecio)*-1)/2 end
		if rscp and rscp ~= "1000" then info.rscp = (tonumber(rscp)*-1)/2 end
	end
end

function Mapper:get_pin_info(device, info, type)
	if type == "pin1" then
		local ret = device:send_singleline_command('AT+ZPINPUK=?', '+ZPINPUK:')
		if ret then
			info.unlock_retries_left, info.unblock_retries_left = string.match(ret, '+ZPINPUK:%s*(%d+),(%d+)')
		end
	end
end

function Mapper:get_sim_info(device, info)
	info.iccid_before_unlock = false
end

function Mapper:get_network_info(device, info)
	info.roaming_state = device.buffer.network_info.roaming_state
end

function Mapper:register_network(device, network_config)
	-- ZTE workaround for the +ZUSIMR:2 messages
	for _, intf in pairs(device.interfaces) do
		if intf.interface and intf.interface.channel then
			for i=1,3 do
				local ret = atchannel.send_singleline_command(intf.interface.channel, 'AT+CPMS?', '+CPMS:')
				if ret then break end
				helper.sleep(2)
			end
		end
	end

	local selected_radio = {
		priority = 10,
		type = "auto"
	}

	for _, radio in pairs(network_config.radio_pref) do
		if radio.priority < selected_radio.priority then
			selected_radio = radio
		end
	end

	-- Set the network selection mode.
	local mode = "0,0,0"
	if selected_radio.type == "gsm" then
		mode = "1,0,0"
	elseif selected_radio.type == "umts" then
		mode = "2,0,0"
	elseif selected_radio.type == "lte" then
		mode = "6,0,0"
	end
	device:send_command(string.format("AT+ZSNT=%s", mode))
end

function Mapper:unsolicited(device, data, sms_data)
	if helper.startswith(data, "+ZDONR:") then
		local roaming_state = string.match(data, '+ZDONR:%s*".-",%d*,%d*,".-","(.-)"')
		if roaming_state then
			if roaming_state == "ROAM_OFF" then
				device.buffer.network_info.roaming_state = "home"
			else
				device.buffer.network_info.roaming_state = "roaming"
			end
		end
		return true
	end
	return nil
end

function Mapper:network_scan(device, start)
	if start then
		device:send_command('AT+CGATT=0', 15000)
		helper.sleep(2)
	end
end

function M.create(runtime, device)
	local mapper = {
		mappings = {
			network_scan = "runfirst"
		}
	}

	local control_ports = attty.find_tty_interfaces(device.desc, { number = 0x1 })
	control_ports = control_ports or attty.find_tty_interfaces(device.desc, { class = 0x2, subclass = 0x2, protocol = 0x1, number = 0x2 })

	local modem_ports = attty.find_tty_interfaces(device.desc, { number = 0x3 })
	modem_ports = modem_ports or attty.find_tty_interfaces(device.desc, { class = 0x2, subclass = 0x2, protocol = 0x1, number = 0x0 })
	modem_ports = modem_ports or attty.find_tty_interfaces(device.desc, { class = 0xff, subclass = 0xff, protocol = 0xff, number = 0x2 })
	modem_ports = modem_ports or attty.find_tty_interfaces(device.desc, { class = 0xff, subclass = 0xff, protocol = 0xff, number = 0x0 })

	device.default_interface_type = "control"

	if modem_ports then
		for _, port in pairs(modem_ports) do
			table.insert(device.interfaces, { port = port, type = "modem" })
		end
	end

	if control_ports then
		for _, port in pairs(control_ports) do
			table.insert(device.interfaces, { port = port, type = "control" })
		end
	end

	-- So far all ZTE dongles in libat seem to be PPP
	device.sessions[1] = { proto = "ppp" }

	setmetatable(mapper, Mapper)
	return mapper
end

return M
