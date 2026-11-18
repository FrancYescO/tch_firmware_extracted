local string, pairs = string, pairs

local ubus = require("ubus")
local socket = require("socket")
local interface = require("libqmi.interface")

local Device = {}
Device.__index = Device

local M = {}

local vid_mappings = {
	["19d2"] = "zte",
	["2c7c"] = "quectel"
}

function Device:get_control_interface()
	for _, i in pairs(self.interfaces) do
		if i.port then
			return i
		end
	end
	return nil, "No QMI control channel available"
end

function Device:send_command(command, timeout)
	local intf, errMsg = self:get_control_interface()
	if not intf then return nil, errMsg end

	local start = (socket.gettime()*1000)
	local ret = intf:send_command(command, timeout)
	local duration = ((socket.gettime()*1000)-start)
	self.runtime.log:debug(string.format('Command "%s" took %.2fms', command, duration))

	return ret
end

function Device:get_model()
	return self:send_command("--get-model")
end

function Device:get_manufacturer()
	return self:send_command("--get-manufacturer")
end

function Device:get_revision()
	return self:send_command("--get-revision")
end

function Device:get_hardware_revision()
	return nil
end

function Device:clear_session_cid(session_id)
	if self.session_state[session_id+1] and self.session_state[session_id+1].cid then
		if self:send_command("--set-client-id wds," .. self.session_state[session_id+1].cid .. " --release-client-id wds") then
			self.session_state[session_id+1].cid = nil
			return true
		end
	end
	return nil
end

function Device:set_session_data_handle(session_id, handle)
	if not self.session_state[session_id+1] then self.session_state[session_id+1] = {} end
	if self.session_state[session_id+1].data_handle and handle then
		return nil, "Data handle already set"
	end
	self.session_state[session_id+1].data_handle = handle
	return true
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
		interfaces = {},
		state = {
			initialized = false
		},
		sessions = {
			{ proto = "dhcp" }
		},
		buffer = {
			sim_info = {},
			device_info = {},
			session_info = {},
			device_capabilities = {}
		},
		session_state = {},
		reg_info = { nas_state = "not_registered" }
	}

	if not params.pid or not params.vid then return nil, "Failed to match vid/pid" end

	device.vid = params.vid
	device.pid = params.pid

	if vid_mappings[device.vid] then
		local status, m = pcall(require, "libqmi." .. vid_mappings[device.vid])
		if status and m then
			device.mapper = m.create(device.pid)
		else
			if type(m) == "string" then runtime.log:error(m) end
		end
	end

	local ports = interface.find_qmi_interfaces(device.desc)
	if #ports == 0 then return nil, "No control channel found" end

	for _, port in pairs(ports) do
		table.insert(device.interfaces, interface.create(runtime, port))
	end

	setmetatable(device, Device)
	return device
end

return M
