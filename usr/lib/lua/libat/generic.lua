local attty = require("libat.tty")

local Mapper = {}
Mapper.__index = Mapper

local M = {}

function M.create(runtime, device)
	local mapper = {
		mappings = {}
	}

	device.default_interface_type = "control"

	local ports = attty.find_tty_interfaces(device.desc)
	if ports and #ports >= 2 then
		table.insert(device.interfaces, { port = ports[1], type = "modem" })
		table.insert(device.interfaces, { port = ports[2], type = "control" })
		device.sessions[1] = { proto = "ppp" }
		setmetatable(mapper, Mapper)
		return mapper
	end
end

return M