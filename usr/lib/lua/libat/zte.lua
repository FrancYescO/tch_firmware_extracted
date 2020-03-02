local match, tinsert = string.match, table.insert

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
	elseif device.pid == "1282" then
		info.radio_interfaces = {
			{ radio_interface = "gsm" },
			{ radio_interface = "umts" },
			{ radio_interface = "lte" },
			{ radio_interface = "auto" }
		}
	end
end

function Mapper:get_radio_signal_info(device, info)
	local ret = device:send_singleline_command('AT+ZRSSI', '+ZRSSI:')
	if ret then
		local rssi, ecio, rscp = match(ret, '+ZRSSI:%s*(%d+),(%d+),(%d+)')
		if rssi then info.rssi = (tonumber(rssi)*-1) end
		if ecio and ecio ~= "1000" then info.ecio = (tonumber(ecio)*-1)/2 end
		if rscp and rscp ~= "1000" then info.rscp = (tonumber(rscp)*-1)/2 end
	end
end

function Mapper:get_pin_info(device, info, type)
	if type == "pin1" then
		local ret = device:send_singleline_command('AT+ZPINPUK=?', '+ZPINPUK:')
		if ret then
			info.unlock_retries_left, info.unblock_retries_left = match(ret, '+ZPINPUK:%s*(%d+),(%d+)')
		end
	end
end

function Mapper:get_network_info(device, info)
	info.roaming_state = device.buffer.network_info.roaming_state
end

function Mapper:configure_device(device, config)
	-- ZTE workaround for the +ZUSIMR:2 messages
	for _, intf in pairs(device.interfaces) do
		if intf.interface and intf.interface.channel then
			for _=1,3 do
				local ret = atchannel.send_singleline_command(intf.interface.channel, 'AT+CPMS?', '+CPMS:')
				if ret then break end
				helper.sleep(2)
			end
		end
	end

	-- TODO Implement the radio preference list
	local selected_radio = config.network.radio_pref[1]

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
	return true
end

function Mapper:unsolicited(device, data)
	if helper.startswith(data, "+ZDONR:") then
		local roaming_state = match(data, '+ZDONR:%s*".-",%d*,%d*,".-","(.-)"')
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

-- TODO check if this is still needed
function Mapper:network_scan(device, start) --luacheck: no unused args
	if start then
		helper.sleep(2)
	end
end

function M.create(runtime, device) --luacheck: no unused args
	local mapper = {
		mappings = {
			network_scan = "runfirst"
		}
	}

	local control_ports, modem_ports
	if device.pid == "1282" then
		control_ports = attty.find_tty_interfaces(device.desc, { number = 0x2 })
		modem_ports = attty.find_tty_interfaces(device.desc, { number = 0x1 })
	else
		control_ports = attty.find_tty_interfaces(device.desc, { number = 0x1 })
		control_ports = control_ports or attty.find_tty_interfaces(device.desc, { class = 0x2, subclass = 0x2, protocol = 0x1, number = 0x2 })

		modem_ports = attty.find_tty_interfaces(device.desc, { number = 0x3 })
		modem_ports = modem_ports or attty.find_tty_interfaces(device.desc, { class = 0x2, subclass = 0x2, protocol = 0x1, number = 0x0 })
		modem_ports = modem_ports or attty.find_tty_interfaces(device.desc, { class = 0xff, subclass = 0xff, protocol = 0xff, number = 0x2 })
		modem_ports = modem_ports or attty.find_tty_interfaces(device.desc, { class = 0xff, subclass = 0xff, protocol = 0xff, number = 0x0 })
	end

	device.default_interface_type = "control"

	if modem_ports then
		for _, port in pairs(modem_ports) do
			tinsert(device.interfaces, { port = port, type = "modem" })
		end
	end

	if control_ports then
		for _, port in pairs(control_ports) do
			tinsert(device.interfaces, { port = port, type = "control" })
		end
	end

	-- So far all ZTE dongles in libat seem to be PPP
	device.sessions[1] = { proto = "ppp" }

	setmetatable(mapper, Mapper)
	return mapper
end

return M
