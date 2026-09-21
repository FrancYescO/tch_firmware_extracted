local tinsert = table.insert

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
		tinsert(interfaces, interface)
	end
	return interfaces
end

local function find_usb_tty(interface)
	local tty = nil
	local content = helper.split(helper.capture_cmd("find " .. interface.path .. " \\( -name 'ttyACM*' -o -name 'ttyUSB*' -o -name 'cdc-wdm*' \\) -exec basename {} \\;", "r"), "\n")
	if content and #content > 0 then
		tty = '/dev/' .. content[1]
	end
	return tty
end

function M.find_interfaces(desc, filter)
	local result = {}
	local interfaces = find_usb_interfaces(desc)
	for _, interface in pairs(interfaces) do
		local matched = true
		if filter then
			for k, v in pairs(filter) do
				if v ~= interface[k] then
					matched = false
					break
				end
			end
		end
		if matched then
			tinsert(result, interface)
		end
	end
	if #result > 0 then
		return result
	end
	return nil, "No matching interface"
end


function M.find_tty_interfaces(desc, filter)
	local ttys = {}
	local interfaces = M.find_interfaces(desc, filter) or {}
	for _, interface in pairs(interfaces) do
		tinsert(ttys, find_usb_tty(interface))
	end
	if #ttys > 0 then
		return ttys
	end
	return nil, "No matching interface"
end

return M
