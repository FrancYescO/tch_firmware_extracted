local atchannel = require("atchannel")
local helper = require("mobiled.scripthelpers")

local DEFAULT_TIMEOUT = 1

local Interface = {}
Interface.__index = Interface

local M = {}

local function ignore_urc(message)
	-- Do nothing...
end

local function ignore_error(message)
	-- Do nothing...
end

local function probe_channel(channel)
	for _=1,3 do
		if channel:run("AT\r\n", "", nil, DEFAULT_TIMEOUT) then
			return true
		end
		helper.sleep(1)
	end
	return nil
end

local function retry_open(port, handle_urc, handle_error)
	for _=1,3 do
		local channel = atchannel.open(port, handle_urc, handle_error)
		if channel then
			if probe_channel(channel) then
				return channel
			end
			channel:close()
		end
		helper.sleep(1)
	end
	return nil
end

function Interface:open()
	local port = self.port
	local log = self.runtime.log

	local function handle_urc(message)
		log:debug("Received URC '%s' on port %s", message, port)
		self.device:handle_unsolicited_message(self, message)
	end

	local function handle_error()
		log:debug("Error occurred on port %s", port)

		self.channel:close()
		self.channel = nil
	end

	log:notice("Opening " .. port)
	local channel = retry_open(port, handle_urc, handle_error)
	if channel then
		channel:enable_logging(self.logging_enabled)

		log:info("Using AT channel " .. self.port)

		self.channel = channel
		self.mode = "normal"

		-- Disable echo and enable verbose result codes
		self.channel:run("ATE0Q0V1\r\n", "", nil, DEFAULT_TIMEOUT)

		-- Disable auto-answer
		self.channel:run("ATS0=0\r\n", "", nil, DEFAULT_TIMEOUT)

		-- Enable extended errors
		self.channel:run("AT+CMEE=1\r\n", "", nil, DEFAULT_TIMEOUT)

		return true
	end
	return nil, "Failed to open " .. self.port
end

function Interface:enable_logging(logging_enabled)
	self.logging_enabled = logging_enabled
	if self.channel then
		self.channel:enable_logging(logging_enabled)
	end
end

function Interface:is_available()
	return not not self.channel
end

function Interface:is_busy()
	return not self:is_available() or self.busy
end

function Interface:close()
	if self.channel then
		self.runtime.log:notice("Closing " .. self.port)
		self.channel:close()
		self.channel = nil
	end
end

function Interface:probe()
	local available = nil
	local channel = self.channel or retry_open(self.port, ignore_urc, ignore_error)
	if channel then
		self.runtime.log:notice("Probing " .. self.port)
		if probe_channel(channel) then
			available = true
		end
		if not self.channel then channel:close() end
	end
	return available
end

function Interface:run(command, data, response_prefix, timeout)
	-- Verify that the channel is able to run a command.
	if not self.channel then
		return nil, "Channel is closed"
	end
	if self.busy then
		return nil, "Channel is busy"
	end

	return self.channel:run(command, data, response_prefix, timeout)
end

function Interface:start(command, data, response_prefix, timeout, handle_success, handle_failure)
	-- Verify that the channel is able to run a command.
	if not self.channel then
		return nil, "Channel is closed"
	end
	if self.busy then
		return nil, "Channel is busy"
	end

	local function propagate_success(result)
		self.busy = false
		handle_success(result)
	end

	local function propagate_failure(message)
		self.busy = false
		if handle_failure then
                        handle_failure(message)
                end
	end

	local result, err_msg = self.channel:start(
		command,
		data,
		response_prefix,
		timeout,
		propagate_success,
		propagate_failure
	)
	if result then
		self.busy = true
	end
	return result, err_msg
end

function M.create(runtime, port, device)
	local i = {
		port = port,
		runtime = runtime,
		device = device,
		busy = false,
		logging_enabled = false
	}
	setmetatable(i, Interface)
	return i
end

return M
