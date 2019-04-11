local format, match = string.format, string.match

local M = {}

function M.get_supported_pdp_types(device)
	local supported_types = {}
	local ret = device:send_multiline_command("AT+CGDCONT=?", "+CGDCONT:")
	if ret then
		for _, line in pairs(ret) do
			local type = match(line, '+CGDCONT: %(.-%),"([A-Z0-9]+)"')
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
	local cid = session_id + 1
	if device.sessions[cid] and device.sessions[cid].proto == "ppp" then
		return
	end

	local ret = device:send_multiline_command("AT+CGACT?", "+CGACT:", 10000)
	if ret then
		for _, line in pairs(ret) do
			local context, state = line:match("+CGACT:%s?(%d+),(%d+)$")
			if tonumber(context) == cid then
				if state == "1" then
					return "connected"
				end
			end
		end
	end
	return "disconnected"
end

function M.start(device, session_id, profile)
	local cid = session_id + 1
	if device.sessions[cid] and device.sessions[cid].proto == "ppp" then
		return true
	end

	local pdptype, errMsg = M.get_pdp_type(device, profile.pdptype)
	if not pdptype then
		return nil, errMsg
	end

	local command = format('AT+CGDCONT=%d,"%s","%s"', cid, pdptype, profile.apn or "")
	local ret = device:send_command(command)
	if ret then
		command = format('AT+CGACT=1,%d', cid)
		return device:start_command(command, 10000)
	end

	return nil, "Failed to start data session"
end

function M.stop(device, session_id)
	local cid = session_id + 1
	if device.sessions[cid] and device.sessions[cid].proto == "ppp" then
		return true
	end

	local command = format('AT+CGACT=0,%d', cid)
	local ret = device:send_command(command, 10000)
	if ret then
		command = format('AT+CGDCONT=%d', cid)
		ret = device:send_command(command, 10000)
		if ret then
			return true
		end
	end
	return nil, "Failed to stop data session"
end

function M.get_ip_info(device, info, session_id)
	local cid = session_id + 1
	local ret = device:send_multiline_command("AT+CGPADDR", "+CGPADDR:")
	if ret then
		for _, line in pairs(ret) do
			local context, addresses = line:match('+CGPADDR:%s?(%d+),"?(.-)"?$')
			if tonumber(context) == cid then
				for address in addresses:gmatch("[^,]+") do
					if address:match("^%d+%.%d+%.%d+%.%d+$") then
						if address ~= "0.0.0.0" then
							info.ipv4_addr = address
						end
					else
						local network = address:match("^(%d+%.%d+%.%d+%.%d+%.%d+%.%d+%.%d+%.%d+%.)%d+%.%d+%.%d+%.%d+%.%d+%.%d+%.%d+%.%d+$")
						if network then
							local ipv6_addr = ""
							local all_zeroes = true
							for msb, lsb in network:gmatch("(%d+)%.(%d+)%.") do
								local value = tonumber(msb) * 256 + tonumber(lsb)
								ipv6_addr = ipv6_addr .. format("%x:", value)
								all_zeroes = all_zeroes and value == 0
							end
							if not all_zeroes then
								info.ipv6_addr = ipv6_addr .. ":"
							end
						end
					end
				end
				return true
			end
		end
	end
end

function M.get_session_info(device, info, session_id)
	local cid = session_id + 1
	local ret = device:send_multiline_command("AT+CGDCONT?", "+CGDCONT:")
	if ret then
		for _, line in pairs(ret) do
			local context, apn, flags = line:match('+CGDCONT:%s?(%d+),.-,"(.-)",".-",(.*)')
			if not context then
				context, apn = line:match('+CGDCONT:%s?(%d+),.-,"(.-)"')
			end
			if tonumber(context) == cid then
				info.apn = apn
				local emergency = flags:match("%d,%d,%d,(%d)")
				if emergency then
					info.emergency = emergency == '1'
				end
				return true
			end
		end
	end
end

function M.get_profiles(device)
	local profiles = {}
	local ret = device:send_multiline_command("AT+CGDCONT?", "+CGDCONT:")
	if ret then
		for _, line in pairs(ret) do
			local id, type, apn = match(line, '+CGDCONT:%s?(%d),"(.-)","(.-)"')
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
