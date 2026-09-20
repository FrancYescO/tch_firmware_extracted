local pairs, string, type = pairs, string, type

local ubus = require("ubus")
local socket = require("socket")
local atchannel = require("atchannel")
local network = require("libat.network")
local atinterface = require("libat.interface")
local helper = require("mobiled.scripthelpers")

local send_sms = atchannel.send_sms
local send_command = atchannel.send_command
local send_sms_command = atchannel.send_sms_command
local send_multiline_command = atchannel.send_multiline_command
local send_singleline_command = atchannel.send_singleline_command

local start_command = atchannel.start_command
local start_multiline_command = atchannel.start_multiline_command
local start_singleline_command = atchannel.start_singleline_command

local poll_command = atchannel.poll_command
local poll_multiline_command = atchannel.poll_multiline_command
local poll_singleline_command = atchannel.poll_singleline_command

local vid_mappings = {
	["12d1"] = "huawei",
	["1519"] = "intel",
	["8087"] = "intel",
	["19d2"] = "zte",
	["0f3d"] = "sierra",
	["1199"] = "sierra",
	["2001"] = "mediatek",
	["2020"] = "mediatek",
	["2c7c"] = "quectel"
}

local Device = {}
Device.__index = Device

local M = {}

function Device:get_interface(interface_type)
	interface_type = interface_type or self.default_interface_type
	for _, i in pairs(self.interfaces) do
		if i.type == interface_type and i.interface and type(i.interface.channel) == "userdata" then
			return i.interface
		end
	end
	return nil, "No AT channel available"
end

function Device:probe()
	local intf, errMsg = self:get_interface()
	if not intf then return nil, errMsg end
	return intf:probe()
end

local function command_blacklisted(device, command)
	for _, blacklisted_command in ipairs(device.command_blacklist) do
		if string.match(command, blacklisted_command) then
			return true
		end
	end
	return false
end

local function do_send(device, send_function, params, retry, interface_type)
	if command_blacklisted(device, params[1]) then
		return nil, "blacklisted"
	end

	local intf, errMsg = device:get_interface(interface_type)
	if not intf then return nil, errMsg end
	if not retry then retry = 1 end
	local ret, err, cme_err

	if not atchannel.running(intf.channel) then
		return nil, "channel closed"
	end

	for i=1, retry do
		local start = (socket.gettime()*1000)
		ret, err, cme_err = send_function(intf.channel, unpack(params))
		local duration = ((socket.gettime()*1000)-start)
		device.runtime.log:debug(string.format('Command "%s" took %.2fms', params[1], duration))
		if ret then break end
		if retry > 1 then
			helper.sleep(1)
		end
	end

	return ret, err, cme_err
end

function Device:is_busy(interface_type)
	local intf, errMsg = self:get_interface(interface_type)
	if not intf then return nil, errMsg end

	if not atchannel.running(intf.channel) then
		return nil, "channel closed"
	end

	return atchannel.is_busy(intf.channel)
end

function Device:send_command(command, timeout, retry, interface_type)
	return do_send(self, send_command, { command, timeout }, retry, interface_type)
end

function Device:send_command_with_source(command, timeout, data_source, interface_type)
	return do_send(self, send_command, { command, timeout, data_source }, nil, interface_type)
end

function Device:send_singleline_command(command, response_prefix, timeout, retry, interface_type)
	return do_send(self, send_singleline_command, { command, response_prefix, timeout }, retry, interface_type)
end

function Device:send_singleline_command_with_source(command, response_prefix, timeout, data_source, interface_type)
	return do_send(self, send_singleline_command, { command, response_prefix, timeout, data_source }, nil, interface_type)
end

function Device:send_multiline_command(command, response_prefix, timeout, retry, interface_type)
	return do_send(self, send_multiline_command, { command, response_prefix, timeout }, retry, interface_type)
end

function Device:send_multiline_command_with_source(command, response_prefix, timeout, data_source, interface_type)
	return do_send(self, send_multiline_command, { command, response_prefix, timeout, data_source }, nil, interface_type)
end

function Device:send_sms_command(command, response_prefix, timeout, retry, interface_type)
	return do_send(self, send_sms_command, { command, response_prefix, timeout }, retry, interface_type)
end

function Device:send_sms(command, pdu, response_prefix, timeout, retry, interface_type)
	return do_send(self, send_sms, { command, pdu, response_prefix, timeout }, retry, interface_type)
end

local function do_start(device, start_function, params, interface_type)
	local intf, errMsg = device:get_interface(interface_type)
	if not intf then return nil, errMsg end

	if not atchannel.running(intf.channel) then
		return nil, "channel closed"
	end

	local ret, err, cme_err = start_function(intf.channel, unpack(params))
	device.runtime.log:debug(string.format('Started "%s"', params[1]))
	return ret, err, cme_err
end

function Device:start_command(command, timeout, interface_type)
	return do_start(self, start_command, { command, timeout }, interface_type)
end

function Device:start_singleline_command(command, response_prefix, timeout, interface_type)
	return do_start(self, start_singleline_command, { command, response_prefix, timeout }, interface_type)
end

function Device:start_multiline_command(command, response_prefix, timeout, interface_type)
	return do_start(self, start_multiline_command, { command, response_prefix, timeout }, interface_type)
end

local function do_poll(device, poll_function, interface_type)
	local intf, errMsg = device:get_interface(interface_type)
	if not intf then return nil, errMsg end

	if not atchannel.running(intf.channel) then
		return nil, "channel closed"
	end

	local ret, err, cme_err = poll_function(intf.channel)
	return ret, err, cme_err
end

function Device:poll_command(interface_type)
	return do_poll(self, poll_command, interface_type)
end

function Device:poll_singleline_command(interface_type)
	return do_poll(self, poll_singleline_command, interface_type)
end

function Device:poll_multiline_command(interface_type)
	return do_poll(self, poll_multiline_command, interface_type)
end

function Device:get_unsolicited_messages()
	for _, interface in pairs(self.interfaces) do
		if interface.interface and interface.interface.channel then
			local ret = interface.interface:get_unsolicited_messages()
			for _, entry in pairs(ret) do
				if entry.at then
					local line = entry.at
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
							self:send_event("mobiled.voice", { event = "ring", dev_idx = self.dev_idx })
						elseif helper.startswith(line, "+CMT:") then
							self:send_event("mobiled", { event = "sms_received", dev_idx = self.dev_idx })
						elseif helper.startswith(line, "+CMTI:") then
							local id = tonumber(string.match(line, '+CMTI:%s?".-",(%d+)'))
							self:send_event("mobiled", { event = "sms_received", dev_idx = self.dev_idx, message_id = id })
						end
					end
					if not handled then
						self.runtime.log:debug("Received unsolicited data: " .. line .. " on port " .. interface.port)
					end
				end
				if entry.sms_pdu then
					self.runtime.log:debug("SMS PDU received")
				end
			end
		end
	end
end

function Device:get_model()
	local ret = self:send_singleline_command('AT+CGMM', '+CGMM:')
	if ret then
		return string.match(ret, '+CGMM:%s?"?(.-)"?$')
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
		return string.match(ret, '+CGMI:%s?"?(.-)"?$')
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
		return string.match(ret, '+CGMR:%s?"?(.-)"?$')
	else
		-- Some modules respond without a prefix
		ret = self:send_multiline_command('AT+CGMR', '')
		if ret then
			for _, line in pairs(ret) do
				-- Sometimes we get an unsolicited message in between. Let's try to skip them
				if not string.match(line, "^%^") and not string.match(line, "^%+") and not string.match(line, "^!") then
					return line
				end
			end
		end
	end
	return nil
end

function Device:send_event(id, data)
	local conn = ubus.connect()
	if not conn then
		return nil, "Failed to connect to UBUS"
	end
	conn:send(id, data)
end

function M.create(runtime, params, tracelevel)
	local device = {
		runtime = runtime,
		desc = params.dev_desc,
		dev_idx = params.dev_idx,
		state = {
			initialized = false
		},
		sessions = {
			{ proto = "dhcp" }
		},
		calls = {},
		command_blacklist = {},
		buffer = {
			sim_info = {},
			time_info = {},
			device_info = {},
			session_info = {},
			network_info = {},
			radio_signal_info = {},
			device_capabilities = {},
			firmware_upgrade_info = {}
		},
		interfaces = {},
		network_interfaces = params.network_interfaces,
		cache = {}
	}
	setmetatable(device, Device)

	if not params.pid or not params.vid then return nil, "Failed to match vid/pid" end

	device.vid = params.vid
	device.pid = params.pid
	device.product = params.product

	if vid_mappings[device.vid] then
		local status, m = pcall(require, "libat." .. vid_mappings[device.vid])
		if status and m then
			device.mapper = m.create(runtime, device)
		end
	else
		local m = require("libat.generic")
		device.mapper = m.create(runtime, device)
	end

	for _, port in pairs(device.interfaces) do
		if port.type == device.default_interface_type then
			local interface = atinterface.create(runtime, port.port)
			local ret, errMsg = interface:open(tracelevel)
			if not ret then
				if errMsg then runtime.log:warning(errMsg) end
			else
				port.interface = interface
			end
		end
	end

	setmetatable(device, Device)
	return device
end

return M
