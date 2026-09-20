local string, tonumber, pairs = string, tonumber, pairs

local M = {}

function M.get_supported_pdp_types(device)
	local supported_types = {}
	local ret = device:send_multiline_command("AT+CGDCONT=?", "+CGDCONT:")
	if ret then
		for _, line in pairs(ret) do
			local type = string.match(line, '+CGDCONT: %(.-%),"([A-Z0-9]+)"')
			if type == "IP" then
				supported_types["ipv4"] = "IP"
			elseif type == "IPV6" then
				supported_types["ipv6"] = "IPV6"
			elseif type == "IPV4V6" then
				supported_types["ipv4v6"] = "IPV4V6"
			end
		end
	end
	return supported_types
end

function M.get_pdp_type(device, type)
	local supported_types = M.get_supported_pdp_types(device)
	if supported_types[type] then
		return supported_types[type]
	else
		-- Fall back to the most suitable one
		if supported_types["ipv4v6"] then
			return supported_types["ipv4v6"]
		elseif supported_types["ipv4"] then
			return supported_types["ipv4"]
		elseif supported_types["ipv6"] then
			return supported_types["ipv6"]
		else
			return nil, "Invalid PDP type"
		end
	end
end

function M.get_state(device, session_id)
	if device.sessions[session_id + 1] and device.sessions[session_id + 1].proto == "ppp" then
		return nil
	end

	session_id = session_id + 1
	local ret = device:send_multiline_command("AT+CGACT?", "+CGACT:", 10000)
	if ret then
		for _, line in pairs(ret) do
			local cid, state = string.match(line, "+CGACT:%s?(%d+),(%d+)$")
			if tonumber(cid) == session_id then
				if state == "1" then
					return "connected"
				end
			end
		end
	end
	return "disconnected"
end

function M.start(device, session_id, profile)
	if device.sessions[session_id + 1] and device.sessions[session_id + 1].proto == "ppp" then
		return true
	end

	local pdptype, errMsg = M.get_pdp_type(device, profile.pdptype)
	if not pdptype then
		return nil, errMsg
	end

	local command = string.format('AT+CGDCONT=%d,"%s","%s"', (session_id + 1), pdptype, profile.apn or "")
	local ret = device:send_command(command)
	if ret then
		command = string.format('AT+CGACT=1,%d', (session_id + 1))
		return device:start_command(command, 10000)
	end

	return nil, "Failed to start data session"
end

function M.stop(device, session_id)
	if device.sessions[session_id + 1] and device.sessions[session_id + 1].proto == "ppp" then
		return true
	end

	local command = string.format('AT+CGACT=0,%d', (session_id + 1))
	local ret = device:send_command(command, 10000)
	if ret then
		command = string.format('AT+CGDCONT=%d', (session_id + 1))
		ret = device:send_command(command, 10000)
		if ret then
			return true
		end
	end
	return nil, "Failed to stop data session"
end

function M.get_profiles(device)
	local profiles = {}
	local ret = device:send_multiline_command("AT+CGDCONT?", "+CGDCONT:")
	if ret then
		for _, line in pairs(ret) do
			local id, type, apn = string.match(line, '+CGDCONT:%s?(%d),"(.-)","(.-)"')
			local pdptype
			if type == "IP" then
				pdptype = "ipv4"
			elseif type == "IPV6" then
				pdptype = "ipv6"
			else
				pdptype = "ipv4v6"
			end
			local profile = {
				pdptype = pdptype,
				id = id,
				name = apn,
				apn = apn
			}
			table.insert(profiles, profile)
		end
	end
	return profiles
end

return M
