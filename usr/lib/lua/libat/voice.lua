local M = {
	clcc_number_type = {
		["129"] = "normal",
		["145"] = "international",
		["161"] = "national"
	},
	clcc_direction = {
		["0"] = "outgoing",
		["1"] = "incoming"
	},
	clcc_mode = {
		["0"] = "voice",
		["1"] = "data",
		["2"] = "fax"
	},
	clcc_call_states = {
		-- active
		["0"] = {
			call_state = "connected",
			media_state = "normal"
		},
		-- held
		["1"] = {
			call_state = "connected",
			media_state = "held"
		},
		-- dialing
		["2"] = {
			call_state = "dialing",
			media_state = "normal"
		},
		-- alerting
		["3"] = {
			call_state = "delivered",
			media_state = "normal"
		},
		-- incoming
		["4"] = {
			call_state = "alerting",
			media_state = "no_media"
		},
		-- waiting
		["5"] = {
			call_state = "alerting",
			media_state = "no_media"
		}
	}
}

function M.dial(device, number)
	local ret = device:send_command(string.format("ATD%s;", number))
	if ret then
		ret = device:send_multiline_command("AT+CLCC", "+CLCC:")
		if ret then
			for _, call in pairs(ret) do
				local id, _, call_state, mode, _, _, _ = string.match(call, '%+CLCC:%s*(%d+),(%d+),(%d+),(%d+),(%d+),"(.-)",(%d+)')
				id = tonumber(id)
				if M.clcc_mode[mode] == "voice" then
					if M.clcc_call_states[call_state].call_state == "dialing" or M.clcc_call_states[call_state].call_state == "delivered" then
						local call_id_info = {call_id = id}
						return call_id_info
					end
				end
			end
		end
	end
	return nil, "Dialing failed"
end

function M.end_call(device, call_id) --luacheck: no unused args
	if device.calls then
		device.calls[1] = nil
	end
	return device:send_command("AT+CHUP")
end

function M.accept_call(device, call_id) --luacheck: no unused args
	return device:send_command("ATA")
end

function M.call_info(device, call_id)
	call_id = tonumber(call_id)
	local count = 1
	local indexed_table = {}

	local ret = device:send_multiline_command("AT+CLCC", "+CLCC:", 2000)
	if ret then
		for _, call in pairs(ret) do
			local id, direction, _, mode, _, remote_party, number_type = string.match(call, '%+CLCC:%s*(%d+),(%d+),(%d+),(%d+),(%d+),"(.-)",(%d+)')
			id = tonumber(id)
			if id then
				if M.clcc_mode[mode] == "voice" then
					if not device.calls[id] then
						device.calls[id] = {}
					end
					device.calls[id].remote_party = remote_party
					device.calls[id].direction = M.clcc_direction[direction]
					device.calls[id].number_format = M.clcc_number_type[number_type]
					table.insert(indexed_table,count,device.calls[id])
					count = count + 1
				end
			end
		end
	end

	if call_id then
		return device.calls[call_id] or {}
	end
	return indexed_table or {}
end

function M.send_dtmf(device, tones, interval, duration)
	if not device:send_command(string.format('AT+VTD=%d,%d', duration or 3, interval or 0)) then
		return nil, "Failed to configure DTMF"
	end
	return device:send_command(string.format('AT+VTS="%s"', tones), 30 * 1000)
end

function M.network_capabilities(device, info)
	if not info.cs then
		info.cs = {}
	end
	if not info.volte then
		info.volte = {}
	end
	local ret = device:send_singleline_command("AT+CNEM?", "+CNEM:")
	if ret then
		local emergency_cs, emergency_volte = ret:match("^+CNEM:%s?%d,(%d),(%d)$")
		if emergency_cs == '1' then
			info.cs.emergency = true
		else
			info.cs.emergency = false
		end
		if emergency_volte == '1' then
			info.volte.emergency = true
		else
			info.volte.emergency = false
		end
		return true
	end
end

return M