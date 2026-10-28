local table, pairs, string, popen = table, pairs, string, io.popen
local helper = require("mobiled.scripthelpers")
local json = require ("dkjson")

local Interface = {}
Interface.__index = Interface

local M = {}

local function retry_open(port)
	for i=1,10 do
		if helper.file_exists(port) then return true end
		helper.sleep(5)
	end
	return nil
end

function Interface:close()
	self.port = nil
end

function Interface:send_command(command, timeout)
	if not timeout then timeout = 2 end

	command = string.format("timeout -t %d uqmi -s -d %s %s 2>&1 || echo FAILED", timeout, self.port, command)
	self.runtime.log:debug("Sending command: " .. command)
	local f = popen(command)
	if not f then return nil, "Failed to execute command" end

	local ret = f:read("*a")
	if not ret then
		f:close()
		return nil, "Failed to read command output"
	end

	f:close()
	ret = helper.split(ret, "\n")
	if #ret > 0 then
		local error
		self.runtime.log:debug("Result:")
		for _, line in pairs(ret) do
			if string.match(line, "UIM uninitialized") then
				error = "uim_uninitialized"
			elseif string.match(line, "Not provisioned") then
				error = "not_provisioned"
			elseif string.match(line, "Call failed") then
				error = "call_failed"
			end
			self.runtime.log:debug(line)
		end
		if error then return { error = error } end
		if ret[#ret] == "FAILED" then return nil, "Command failed" end
	else
		return {}
	end

	local obj = json.decode(ret[1])
	if not obj then return nil, "Failed to decode output" end
	return obj
end

function M.find_qmi_interfaces(desc)
	local ports = {}
	local content = helper.split(helper.capture_cmd("find /sys/bus/usb/devices/" .. desc .. "/ \\( -name 'qmi*' -o -name 'qcqmi*' -o -name 'cdc-wdm*' \\) -exec basename {} \\;", "r"), "\n")
	for _, port in pairs(content) do
		table.insert(ports, '/dev/' .. port)
	end
	local results = {}
	local flags = {}
	for i=1,#ports do
		if not flags[ports[i]] then
			flags[ports[i]] = true
			table.insert(results, ports[i])
		end
	end
	return results
end

function M.create(runtime, port)
	local i = {
		runtime = runtime
	}

	if retry_open(port) then
		i.port = port
	end

	setmetatable(i, Interface)
	return i
end

return M
