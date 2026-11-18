local ubus = require("ubus")
local socket = require("socket")
local network = require("libat.network")
local atinterface = require("libat.interface")
local helper = require("mobiled.scripthelpers")

local DEFAULT_TIMEOUT = 1000 -- ms

local function split_pdu(message)
	local response, pdu = message:match("^(.-)\n(.*)$")
	return response or message, pdu
end

local function send_command(interface, command, timeout, data)
	local result, err_msg = interface:run(command .. "\r\n", data or "", nil, (timeout or DEFAULT_TIMEOUT) / 1000)
	return not not result, err_msg
end

local function send_singleline_command(interface, command, response_prefix, timeout, data)
	local result, err_msg = interface:run(command .. "\r\n", data or "", response_prefix, (timeout or DEFAULT_TIMEOUT) / 1000)
	if not result then
		return nil, err_msg
	end

	local first_line = result[1]
	if not first_line then
		return nil, "invalid response"
	end

	return first_line
end

local function send_multiline_command(interface, command, response_prefix, timeout, data)
	return interface:run(command .. "\r\n", data or "", response_prefix, (timeout or DEFAULT_TIMEOUT) / 1000)
end

local function send_sms_command(interface, command, response_prefix, timeout)
	local result, err_msg = send_multiline_command(interface, command, response_prefix, timeout)
	if not result then
		return result, err_msg
	end

	-- Replace all entries in the table with struct containing a response field and
	-- an optional PDU field. Messages with PDU fields are returned as a single
	-- string where the PDU is separated from the rest of the message by a single line feed.
	for index, line in ipairs(result) do
		local response, pdu = split_pdu(line)
		result[index] = {
			response = response,
			pdu = pdu
		}
	end

	return result
end

local function send_sms(interface, command, pdu, response_prefix, timeout)
	return send_singleline_command(interface, command, response_prefix, timeout, pdu .. "\26")
end

local function start_command(interface, command, timeout, data, handle_success, handle_failure)
	local function propagate_success(result)
		if handle_success then
                        handle_success(not not result)
                end
	end

	return interface:start(command .. "\r\n", data or "", nil, (timeout or DEFAULT_TIMEOUT) / 1000, propagate_success, handle_failure)
end

local function start_singleline_command(interface, command, response_prefix, timeout, data, handle_success, handle_failure)
	local function propagate_success(result)
		local first_line = result[1]
		if first_line then
			handle_success(first_line)
		else
			handle_failure("invalid response")
		end
	end

	return interface:start(command .. "\r\n", data or "", response_prefix, (timeout or DEFAULT_TIMEOUT) / 1000, propagate_success, handle_failure)
end

local function start_multiline_command(interface, command, response_prefix, timeout, data, handle_success, handle_failure)
	return interface:start(command .. "\r\n", data or "", response_prefix, (timeout or DEFAULT_TIMEOUT) / 1000, handle_success, handle_failure)
end

local vid_mappings = {
	["12d1"] = "huawei",
	["1519"] = "intel",
	["8087"] = "intel",
	["19d2"] = "zte",
	["0f3d"] = "sierra",
	["1199"] = "sierra",
	["1bbb"] = "alcatel",
	["2001"] = { -- D-Link
		["7e35"] = "broadmobi",
		["7e3d"] = "broadmobi",
		default  = "mediatek"
	},
	["2020"] = "mediatek",
	["2c7c"] = { -- Quectel
		["0500"] = "quectel_essential",
		["0800"] = "quectel_essential",
		default  = "quectel"
	}
}

local Device = {}
Device.__index = Device

local M = {}

function Device:get_interface(interface_type)
	interface_type = interface_type or self.default_interface_type
	for _, i in pairs(self.interfaces) do
		if i.type == interface_type and i.interface and i.interface.channel then
			return i.interface
		end
	end
	return nil, "No AT channel available"
end

function Device:get_mode()
	local intf, errMsg = self:get_interface()
	if not intf then
		return nil, errMsg
	end
	return intf.mode
end

function Device:probe()
	local intf, errMsg = self:get_interface()
	if not intf then return nil, errMsg end
	return intf:probe()
end

local function command_blacklisted(device, command)
	for _, blacklisted_command in pairs(device.command_blacklist) do
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

	if not intf:is_available() then
		return nil, "channel not available"
	end

	local ret, err
	for _=1, retry do
		local start = (socket.gettime()*1000)
		ret, err = send_function(intf, unpack(params))
		local duration = ((socket.gettime()*1000)-start)
		if not ret then
			device.runtime.log:info(string.format('Command "%s" failed after %.2fms', params[1], duration))
		else
			device.runtime.log:debug(string.format('Command "%s" took %.2fms', params[1], duration))
		end
		if ret then break end
		if retry > 1 then
			helper.sleep(1)
		end
	end

	return ret, err
end

function Device:is_busy(interface_type)
	local intf, errMsg = self:get_interface(interface_type)
	if not intf then return nil, errMsg end
	return intf:is_busy()
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
	if command_blacklisted(device, params[1]) then
		return nil, "blacklisted"
	end

	local intf, errMsg = device:get_interface(interface_type)
	if not intf then return nil, errMsg end

	if not intf:is_available() then
		return nil, "channel not available"
	end

	local ret, err = start_function(intf, unpack(params))
	device.runtime.log:debug(string.format('Started "%s"', params[1]))
	return ret, err
end

function Device:start_command(command, timeout, handle_success, handle_failure, interface_type)
	return do_start(self, start_command, { command, timeout, nil, handle_success, handle_failure }, interface_type)
end

function Device:start_command_with_source(command, timeout, data_source, handle_success, handle_failure, interface_type)
	return do_start(self, start_command, { command, timeout, data_source, handle_success, handle_failure }, interface_type)
end

function Device:start_singleline_command(command, response_prefix, timeout, handle_success, handle_failure, interface_type)
	return do_start(self, start_singleline_command, { command, response_prefix, timeout, nil, handle_success, handle_failure }, interface_type)
end

function Device:start_singleline_command_with_source(command, response_prefix, timeout, data_source, handle_success, handle_failure, interface_type)
	return do_start(self, start_singleline_command, { command, response_prefix, timeout, data_source, handle_success, handle_failure }, interface_type)
end

function Device:start_multiline_command(command, response_prefix, timeout, handle_success, handle_failure, interface_type)
	return do_start(self, start_multiline_command, { command, response_prefix, timeout, nil, handle_success, handle_failure }, interface_type)
end

function Device:start_multiline_command_with_source(command, response_prefix, timeout, data_source, handle_success, handle_failure, interface_type)
	return do_start(self, start_multiline_command, { command, response_prefix, timeout, data_source, handle_success, handle_failure }, interface_type)
end

function Device:handle_unsolicited_message(interface, message)
	local line, sms_pdu = split_pdu(message)
	local handled = false
	if self.mapper and self.mapper["unsolicited"] then
		if self.mapper["unsolicited"](self.mapper, self, line) then
			handled = true
		end
	end
	if not handled then
		if helper.startswith(line, "+CGREG:") then
			local stat = network.parse_creg_state(line)
			local state = network.creg_state_to_string(stat)
			if state then
				self.runtime.log:notice("Network registration state changed to: " .. state)
				if state == "registered" then
					self:send_event("mobiled", { event = "network_registered", dev_idx = self.dev_idx })
				elseif state == "not_registered" or state == "not_registered_searching" then
					self.runtime.log:debug("Flushing cache")
					if self.cache['get_session_info'] then
						self.cache['get_session_info'].info = {}
					end
					if self.cache['get_network_info'] then
						self.cache['get_network_info'].info = {}
					end
					self:send_event("mobiled", { event = "network_deregistered", dev_idx = self.dev_idx })
				end
			end
			handled = true
		elseif helper.startswith(line, "RING") then
			self:send_event("mobiled.voice", { event = "ring", dev_idx = self.dev_idx })
			handled = true
		elseif helper.startswith(line, "+CMT:") then
			self:send_event("mobiled", { event = "sms_received", dev_idx = self.dev_idx })
			handled = true
		elseif helper.startswith(line, "+CMTI:") then
			local id = tonumber(string.match(line, '+CMTI:%s?".-",(%d+)'))
			self:send_event("mobiled", { event = "sms_received", dev_idx = self.dev_idx, message_id = id })
			handled = true
		elseif helper.startswith(line, "+CPIN:") then
			local status = string.match(line, '^+CPIN:%s?(.-)$')
			if status == "NOT READY" then
				self.buffer.sim_info = {}
				self:send_event("mobiled", { event = "sim_removed", dev_idx = self.dev_idx })
			elseif status == "READY" then
				self.buffer.sim_info = {}
				self:send_event("mobiled", { event = "sim_initialized", dev_idx = self.dev_idx })
			end
			handled = true
		elseif helper.startswith(line, "+CNEMIU:") then
			local supported = string.match(line, '^+CNEMIU:%s?([01])$')
			self:send_event("mobiled.voice", { dev_idx = self.dev_idx, event = "cs_emergency", supported = supported == '1' })
			handled = true
		elseif helper.startswith(line, "+CNEMS1:") then
			local supported = string.match(line, '^+CNEMS1:%s?([01])$')
			self:send_event("mobiled.voice", { dev_idx = self.dev_idx, event = "volte_emergency", supported = supported == '1' })
			handled = true
		end
	end
	if not handled then
		self.runtime.log:info("Received unsolicited data: " .. line .. " on port " .. interface.port)
	end
	if sms_pdu then
		self.runtime.log:info("SMS PDU received")
	end
end

function Device:get_model()
	local ret = self:send_singleline_command('AT+CGMM', '+CGMM:')
	if ret then
		return string.match(ret, '+CGMM:%s?"?(.-)"?$')
	end

	-- Some modules respond without a prefix. In this case do not return lines that look like unsolicted messages.
	for _ = 1, 5 do
		ret = self:send_singleline_command('AT+CGMM', '')
		if ret and not ret:match('^%p%u+:') then
			return ret
		end
	end

	return nil
end

function Device:get_manufacturer()
	local ret = self:send_singleline_command('AT+CGMI', '+CGMI:')
	if ret then
		return string.match(ret, '+CGMI:%s?"?(.-)"?$')
	end

	-- Some modules respond without a prefix. In this case do not return lines that look like unsolicted messages.
	for _ = 1, 5 do
		ret = self:send_singleline_command('AT+CGMI', '')
		if ret and not ret:match('^%p%u+:') then
			return ret
		end
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
		mmpbx_call_id_counter = 1,
		command_blacklist = {},
		buffer = {
			sim_info = {},
			time_info = {},
			device_info = {},
			session_info = {},
			network_info = {},
			radio_signal_info = {},
			device_capabilities = {},
			firmware_upgrade_info = {},
			voice_info = {}
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

	local create_interface = atinterface.create

	-- Determine which vendor's flavour of AT commands to use.
	local vendor = "generic"
	local vid_mapping = vid_mappings[device.vid]
	if vid_mapping then
		local vid_type = type(vid_mapping)
		if vid_type == "string" then
			vendor = vid_mapping
		elseif vid_type == "table" then
			vendor = vid_mapping[device.pid] or vid_mapping.default or vendor
		else
			runtime.log:error("VID mapping is neither a string nor a table but a %s", vid_type)
		end
	end

	local status, m = pcall(require, "libat." .. vendor)
	if status and m then
		device.mapper = m.create(runtime, device)
		create_interface = m.create_interface or create_interface
	elseif m then
		runtime.log:error(m)
	end

	for _, port in pairs(device.interfaces) do
		if port.type == device.default_interface_type then
			local interface = create_interface(runtime, port.port, device)
			interface:enable_logging(tracelevel >= 6)
			local ret, errMsg = interface:open()
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
