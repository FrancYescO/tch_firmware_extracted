local pairs, string, table, type = pairs, string, table, type

local ubus = require("ubus")
local socket = require("socket")
local attty = require("libat.tty")
local atchannel = require("atchannel")
local network = require("libat.network")
local atinterface = require("libat.interface")
local helper = require("mobiled.scripthelpers")

local send_command = atchannel.send_command
local send_multiline_command = atchannel.send_multiline_command
local send_singleline_command = atchannel.send_singleline_command

local vid_mappings = {
	["12d1"] = "huawei",
	["1519"] = "intel",
	["8087"] = "intel",
	["19d2"] = "zte",
	["0f3d"] = "sierra",
	["1199"] = "sierra"
}

local Device = {}
Device.__index = Device

local M = {}

function Device:get_control_interface()
	for _, i in pairs(self.control_interfaces) do
		if type(i.channel) == "userdata" then
			return i
		end
	end
	return nil, "No AT control channel available"
end

function Device:get_data_interface()
	for _, i in pairs(self.data_interfaces) do
		if type(i.channel) == "userdata" then
			return i
		end
	end
	return nil, "No AT data channel available"
end

function Device:probe()
	local intf, errMsg = self:get_control_interface()
	if not intf then return nil, errMsg end
	return intf:probe()
end

function Device:send_command(command, timeout, retry, use_data_channel)
	local intf, errMsg
	if use_data_channel then
		intf, errMsg = self:get_data_interface()
	else
		intf, errMsg = self:get_control_interface()
	end
	if not intf then return nil, errMsg end
	if not retry then retry = 1 end
	local ret, err, cme_err

	for i=1,retry do
		local start = (socket.gettime()*1000)
		ret, err, cme_err = send_command(intf.channel, command, timeout)
		local duration = ((socket.gettime()*1000)-start)
		self.runtime.log:debug(string.format('Command "%s" took %.2fms', command, duration))
		if ret then break end
	end

	return ret, err, cme_err
end

function Device:send_singleline_command(command, response_prefix, timeout, retry, use_data_channel)
	local intf, errMsg
	if use_data_channel then
		intf, errMsg = self:get_data_interface()
	else
		intf, errMsg = self:get_control_interface()
	end
	if not intf then return nil, errMsg end
	if not retry then retry = 1 end
	local ret, err, cme_err

	for i=1,retry do
		local start = (socket.gettime()*1000)
		ret, err, cme_err = send_singleline_command(intf.channel, command, response_prefix, timeout)
		local duration = ((socket.gettime()*1000)-start)
		self.runtime.log:debug(string.format('Command "%s" took %.2fms', command, duration))
		if ret then break end
	end
	
	return ret, err, cme_err
end

function Device:send_multiline_command(command, response_prefix, timeout, retry, use_data_channel)
	local intf, errMsg
	if use_data_channel then
		intf, errMsg = self:get_data_interface()
	else
		intf, errMsg = self:get_control_interface()
	end
	if not intf then return nil, errMsg end
	if not retry then retry = 1 end
	local ret, err, cme_err

	for i=1,retry do
		local start = (socket.gettime()*1000)
		ret, err, cme_err = send_multiline_command(intf.channel, command, response_prefix, timeout)
		local duration = ((socket.gettime()*1000)-start)
		self.runtime.log:debug(string.format('Command "%s" took %.2fms', command, duration))
		if ret then break end
	end

	return ret, err, cme_err
end

local function mpairs(t, ...)
	local i, a, k, v = 1, {...}
	return
	function()
		repeat
			k, v = next(t, k)
			if k == nil then
				i, t = i + 1, a[i]
			end
		until k ~= nil or not t
		return k, v
	end
end

function Device:get_unsolicited_messages()
	for _, interface in mpairs(self.control_interfaces, self.data_interfaces) do
		if interface.channel then
			local ret = interface:get_unsolicited_messages()
			for _, entry in pairs(ret) do
				if entry.type == "at" then
					local line = entry.data
					local handled = false
					if self.mapper and self.mapper["unsolicited"] then
						if self.mapper["unsolicited"](self.mapper, self, line) then
							handled = true
						end
					end
					if not handled then
						if helper.startswith(line, "+CREG:") then
							local stat = network.parse_creg_state(line)
							local state = network.creg_state_to_string(stat)
							if state then
								self.runtime.log:info("Network registration state changed to: " .. state)
								if state == "registered" then
									self:send_event("mobiled", { event = "network_registered", dev_idx = self.dev_idx })
								elseif state == "not_registered" then
									self:send_event("mobiled", { event = "network_deregistered", dev_idx = self.dev_idx })
								end
							end
							handled = true
						elseif helper.startswith(line, "RING") then
							self:send_event("mobiled", { event = "ring", dev_idx = self.dev_idx })
						end
					end
					if not handled then
						self.runtime.log:debug("Received unsolicited data: " .. line .. " on port " .. interface.port)
					end
				end
			end
		end
	end
end

function Device:get_model()
	local ret = self:send_singleline_command('AT+CGMM', '+CGMM:')
	if ret then
		return string.match(ret, '+CGMM: "(.-)"')
	else
		-- Some modules respond without a prefix
		ret = self:send_singleline_command('AT+CGMM', '')
		if ret then return ret end
	end
	return nil
end

function Device:get_manufacturer()
	local ret = self:send_singleline_command('AT+CGMI', '+CGMI:')
	if ret then
		return string.match(ret, '+CGMI: "(.-)"')
	else
		-- Some modules respond without a prefix
		ret = self:send_singleline_command('AT+CGMI', '')
		if ret then return ret end
	end
	return nil
end

function Device:get_revision()
	local ret = self:send_singleline_command('AT+CGMR', '+CGMR:')
	if ret then
		return string.match(ret, '+CGMR: "(.-)"')
	else
		-- Some modules respond without a prefix
		ret = self:send_singleline_command('AT+CGMR', '')
		if ret then return ret end
	end
	return nil
end

function Device:send_event(id, data)
	local conn = ubus.connect()
	if not conn then
		return nil, "Failed to connect to ubusd"
	end
	conn:send(id, data)
end

function M.create(runtime, params, tracelevel)
	local device = {
		runtime = runtime,
		desc = params.dev_desc,
		dev_idx = params.dev_idx,
		control_interfaces = {},
		data_interfaces = {},
		state = {
			initialized = false
		},
		sessions = {
			{ proto = "dhcp" }
		},
		calls = {},
		buffer = {
			sim_info = {},
			device_info = {},
			session_info = {},
			network_info = {},
			radio_signal_info = {},
			device_capabilities = {},
			firmware_upgrade_info = {}
		}
	}

	if not params.pid or not params.vid then return nil, "Failed to match vid/pid" end

	device.vid = params.vid
	device.pid = params.pid

	if vid_mappings[device.vid] then
		local status, m = pcall(require, "libat." .. vid_mappings[device.vid])
		if status and m then
			device.mapper = m.create(device.pid)
		end
	end

	local ctrl_ports = {}
	local data_ports = {}
	-- Huawei devices
	if device.vid == "12d1" then
		-- Device in download/firmware upgrade mode. Nothing to do here
		if device.pid == "1568" then return nil, "Device in download mode" end

		ctrl_ports = attty.find_tty_interfaces(device.desc, { protocol = 0x12 })
		if #ctrl_ports == 0 then
			-- Huawei E3131
			ctrl_ports = attty.find_tty_interfaces(device.desc, { protocol = 0x2 })
			data_ports = attty.find_tty_interfaces(device.desc, { protocol = 0x1 })
			if #ctrl_ports == 0 then
				local ports = attty.find_tty_interfaces(device.desc)
				table.sort(ports)
				-- In case of E8372 and E3372s v22 we need the last interface
				data_ports = { ports[#ports] }
				ctrl_ports = { ports[1] }
				if device.pid == "1001" then
					device.sessions[1] = { proto = "ppp" }
					data_ports = { ports[1] }
					ctrl_ports = { ports[#ports] }
				end
			end
		end
	-- ZTE MF627
	elseif device.vid == "19d2" and device.pid == "0031" then
		ctrl_ports = attty.find_tty_interfaces(device.desc, { number = 0x1 })
		data_ports = attty.find_tty_interfaces(device.desc, { number = 0x3 })
		device.sessions[1] = { proto = "ppp" }
	elseif device.vid == "1519" then
		ctrl_ports = attty.find_tty_interfaces(device.desc, { number = 0x0 })
		local ports = attty.find_tty_interfaces(device.desc, { number = 0x4 })
		for _, port in pairs(ports) do
			table.insert(ctrl_ports, port)
		end
	end

	if #ctrl_ports == 0 then
		ctrl_ports = attty.find_tty_interfaces(device.desc)
	end

	for _, port in pairs(ctrl_ports) do
		local interface = atinterface.create(runtime, port)
		local ret, errMsg = interface:open(tracelevel)
		if not ret then
			if errMsg then runtime.log:warning(errMsg) end
		else
			table.insert(device.control_interfaces, interface)
		end
	end

	for _, port in pairs(data_ports) do
		local interface = atinterface.create(runtime, port)
		local ret, errMsg
		-- In case of PPP, we don't need to open the port because it will be used by the PPP daemon later on
		if device.sessions[1].proto == "ppp" then
			ret, errMsg = interface:probe()
		else
			ret, errMsg = interface:open(tracelevel)
		end
		if not ret then
			if errMsg then runtime.log:warning(errMsg) end
		else
			table.insert(device.data_interfaces, interface)
		end
	end

	if #data_ports == 0 then
		device.data_interfaces = device.control_interfaces
	end

	for _, interface in pairs(device.control_interfaces) do
		runtime.log:info("Using " .. interface.port .. " for control")
	end
	for _, interface in pairs(device.data_interfaces) do
		runtime.log:info("Using " .. interface.port .. " for data")
	end

	setmetatable(device, Device)
	return device
end

return M
