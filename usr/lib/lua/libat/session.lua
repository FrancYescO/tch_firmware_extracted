local string, tonumber, pairs = string, tonumber, pairs

local M = {}

function M.get_state(device, session_id)
	if device.sessions[session_id + 1].proto == "ppp" then
		return nil
	end

	session_id = session_id + 1
	local ret = device:send_multiline_command("AT+CGACT?", "+CGACT:")
	if ret then
		for _, line in pairs(ret) do
			local cid, state = string.match(line, "+CGACT: ([0-9]+),([0-9])$")
			if tonumber(cid) == (session_id + 1) then
				if state == "1" then
					return "connected"
				end
			end
		end
	end
	return "disconnected"
end

function M.start(device, session_id, profile)
	if device.sessions[session_id + 1].proto == "ppp" then
		return true
	end

	local supported_types = {}
	local ret = device:send_multiline_command("AT+CGDCONT=?", "+CGDCONT:")
	if ret then
		for _, line in pairs(ret) do
			local type = string.match(line, '+CGDCONT: %([0-9-]+%),"([A-Z0-9]+)"')
			table.insert(supported_types, type)
		end
	end

	local pdptype
	if profile.pdptype == "ipv4" then
		pdptype = "IP"
	elseif profile.pdptype == "ipv6" then
		pdptype = "IPV6"
	else
		pdptype = "IPV4V6"
	end

	-- Check which pdptypes are actually supported by the module
	local supported = false
	for _, type in pairs(supported_types) do
		if type == pdptype then
			supported = true
			break
		end
	end

	-- Fall back to IPv4 if the check failed
	if not supported then
		pdptype = "IP"
	end

	local command = string.format('AT+CGDCONT=%d,"%s","%s"', (session_id + 1), pdptype, profile.apn or "")
	ret = device:send_command(command)
	if ret then
		command = string.format('AT+CGACT=1,%d', (session_id + 1))
		return device:send_command(command, 10000)
	end

	return nil, "Failed to start data session"
end

function M.stop(device, session_id)
	if device.sessions[session_id + 1].proto == "ppp" then
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
