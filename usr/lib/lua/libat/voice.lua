local M = {
	clcc_number_type = {
		["129"] = "normal",
		["145"] = "international"
	},
	clcc_direction = {
		["0"] = "outgoing",
		["1"] = "incoming"
	}
}

function M.dial(device, number)
	local ret = device:send_command(string.format("ATD%s;", number))
	if ret then
		device.calls[1] = {
			call_id = 1
		}
		return device.calls[1]
	end
	return nil, "Dialing failed"
end

function M.end_call(device, call_id)
	if device.calls then
		device.calls[1] = nil
	end
	return device:send_command("AT+CHUP")
end

function M.accept_call(device, call_id)
	return device:send_command("ATA")
end

function M.call_info(device, call_id)
	call_id = tonumber(call_id)

	local ret = device:send_multiline_command("AT+CLCC", "+CLCC:", 2000)
	if ret then
		for _, call in pairs(ret) do
			local id, direction, _, _, _, remote_party, number_type = string.match(call, '%+CLCC:%s*(%d+),(%d+),(%d+),(%d+),(%d+),"(.-)",(%d+)')
			id = tonumber(id)
			if id then
				if not device.calls[id] then
					device.calls[id] = {}
				end
				device.calls[id].remote_party = remote_party
				device.calls[id].direction = M.clcc_direction[direction]
				device.calls[id].number_format = M.clcc_number_type[number_type]
			end
		end
	end

	if call_id then
		return device.calls[call_id] or {}
	end
	return device.calls or {}
end

return M