local atchannel = require("atchannel")
local helper = require("mobiled.scripthelpers")

local send_command = atchannel.send_command

local Interface = {}
Interface.__index = Interface

local M = {}

local function probe_channel(channel)
	for _=1,3 do
		if send_command(channel, "AT") then
			return true
		end
		helper.sleep(1)
	end
	return nil
end

local function retry_open(port)
	for _=1,3 do
		local channel = atchannel.open(port)
		if channel then
			if probe_channel(channel) then
				return channel
			end
			atchannel.close(channel)
		end
		helper.sleep(1)
	end
	return nil
end

function Interface:open(tracelevel)
	local port = self.port
	local log = self.runtime.log

	log:notice("Opening " .. port)
	local channel = retry_open(port)
	if channel then
		log:info("Using AT channel " .. self.port)

		self.channel = channel
		self.mode = "normal"

		log:info("Setting AT channel trace level to " .. tracelevel)
		atchannel.set_tracelevel(channel, tracelevel)

		-- Disable echo and enable verbose result codes
		send_command(self.channel, "ATE0Q0V1")

		-- Disable auto-answer
		send_command(self.channel, "ATS0=0")

		-- Enable extended errors
		send_command(self.channel, "AT+CMEE=1")

		return true
	end
	return nil, "Failed to open " .. self.port
end

function Interface:is_available()
	return atchannel.running(self.channel)
end

function Interface:is_busy()
	return not self:is_available() or atchannel.is_busy(self.channel)
end

function Interface:get_unsolicited_messages()
	local ret = atchannel.unsolicited(self.channel)
	return ret or {}
end

function Interface:close()
	if self.channel then
		self.runtime.log:notice("Closing " .. self.port)
		atchannel.close(self.channel)
		self.channel = nil
	end
end

function Interface:probe()
	local available = nil
	local channel = self.channel or retry_open(self.port)
	if channel then
		self.runtime.log:notice("Probing " .. self.port)
		if probe_channel(channel) then
			available = true
		end
		if not self.channel then atchannel.close(channel) end
	end
	return available
end

function Interface:set_tracelevel(level)
	if self.channel then
		atchannel.set_tracelevel(self.channel, level)
	end
end

function M.create(runtime, port)
	local i = {
		port = port,
		runtime = runtime
	}
	setmetatable(i, Interface)
	return i
end

return M
