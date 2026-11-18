local table, pairs, tonumber = table, pairs, tonumber
local helper = require("mobiled.scripthelpers")
local M = {}

local function find_usb_interfaces(desc)
	local interfaces = {}
	local ret = helper.split(helper.capture_cmd("find /sys/bus/usb/devices/" .. desc .. "/ -type d -name '*:*' -maxdepth 1", "r"), "\n")
	for _, i in pairs(ret) do
		local interface = {}
		interface.class = tonumber(helper.read_file(i .. "/bInterfaceClass"), 16)
		interface.subclass = tonumber(helper.read_file(i .. "/bInterfaceSubClass"), 16)
		interface.protocol = tonumber(helper.read_file(i .. "/bInterfaceProtocol"), 16)
		interface.number = tonumber(helper.read_file(i .. "/bInterfaceNumber"), 16)
		interface.path = i
		table.insert(interfaces, interface)
	end
	return interfaces
end

local function find_usb_tty(interface)
	local tty = nil
	local content = helper.split(helper.capture_cmd("find " .. interface.path .. " \\( -name 'ttyACM*' -o -name 'ttyUSB*' \\) -exec basename {} \\;", "r"), "\n")
	if content and #content > 0 then
		tty = '/dev/' .. content[1]
	end
	return tty
end

function M.find_tty_interfaces(desc, filter)
	local ttys = {}
	local interfaces = find_usb_interfaces(desc)
	for _, interface in pairs(interfaces) do
		local matched = true
		if filter then
			if filter.class and filter.class ~= interface.class then matched = false end
			if filter.subclas and filter.subclass ~= interface.subclass then matched = false end
			if filter.protocol and filter.protocol ~= interface.protocol then matched = false end
			if filter.number and filter.number ~= interface.number then matched = false end
		end
		if matched then
			local tty = find_usb_tty(interface)
			if tty then table.insert(ttys, tty) end
		end
	end
	return ttys
end

return M
