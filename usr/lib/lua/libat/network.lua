local match, sub = string.match, string.sub

local M = {}

function M.parse_creg_state(data)
	-- +CREG: <n>, <stat>, <lac>, <cid>, <Act>
	local stat, lac, cid, act = match(data, '+CG?REG:%s?%d,(%d),"(%x*)","(%x*)",(%d)')
	if stat then return tonumber(stat), tonumber(lac, 16), tonumber(cid, 16), tonumber(act) end
	-- +CREG: <n>, <stat>, <lac>, <cid>
	stat, lac, cid = match(data, '+CG?REG:%s*%d,(%d),"(%x*)","(%x*)"')
	if stat then return tonumber(stat), tonumber(lac, 16), tonumber(cid, 16) end
	-- +CREG: <stat>, <lac>, <cid>, <radio type>
	stat, lac, cid, act = match(data, '+CG?REG:%s*(%d),"(%x*)","(%x*)",(%d)')
	if stat then return tonumber(stat), tonumber(lac, 16), tonumber(cid, 16), tonumber(act) end
	-- +CREG: <n>, <stat>, <lac>, <cid>
	stat, lac, cid = match(data, '+CG?REG:%s*%d,%s?(%d),%s?(%x*),%s?(%x*)')
	if stat then return tonumber(stat), tonumber(lac, 16), tonumber(cid, 16) end
	-- +CREG: <stat>, <lac>, <cid>
	stat, lac, cid = match(data, "+CG?REG:%s*(%d),%s?(%x*),%s?(%x*)")
	if stat then return tonumber(stat), tonumber(lac, 16), tonumber(cid, 16) end
	-- +CREG: <n>, <stat>
	stat = match(data, "+CG?REG:%s*%d,%s?(%d)")
	if stat then return tonumber(stat) end
	-- +CREG: <stat>
	stat = match(data, "+CG?REG:%s?(%d)")
	if stat then return tonumber(stat) end

	return nil
end

--[[
	CREG_NOT_REGISTERED = 0,
	CREG_REGISTERED = 1,
	CREG_SEARCHING = 2,
	CREG_REGISTRATION_DENIED = 3,
	CREG_UNKNOWN = 4,
	CREG_REGISTERED_ROAMING = 5,
	CREG_REGISTERED_SMS = 6,
	CREG_REGISTERED_ROAMING_SMS = 7,
	CREG_EMERGENCY_SERVICE = 8,
	CREG_REGISTERED_NO_CSFB = 9,
	CREG_REGISTERED_ROAMING_NO_CSFB = 10
]]--
function M.get_state(device)
	local ret = device:send_singleline_command("AT+CGREG?", "+CGREG:")
	local state, lac, cid, act
	if ret then
		state, lac, cid, act = M.parse_creg_state(ret)
	end
	-- 0000, and FFFE are reserved to indicate there is no valid LAC
	if lac == 65534 or lac == 0 then
		lac = nil
	end
	return M.creg_state_to_string(state), lac, cid, M.creg_radio_type_to_string(act)
end

function M.get_roaming_state(device)
	local ret = device:send_singleline_command("AT+CGREG?", "+CGREG:")
	if ret then
		local state = M.parse_creg_state(ret)
		if state == 1 then
			return "home"
		elseif state == 5 or state == 10 then
			return "roaming"
		end
	end
end

function M.creg_state_to_string(state)
	if state then
		if state == 1 or state == 5 or state == 6 or state == 7 or state == 9 or state == 10 then
			return "registered"
		elseif state == 2 then
			return "not_registered_searching"
		elseif state == 3 then
			return "registration_denied"
		end
	end
	return "not_registered"
end

function M.creg_radio_type_to_string(radio_interface)
	if tonumber(radio_interface) then
		if radio_interface >= 0 and radio_interface <= 3 and radio_interface ~= 2 then
			return "gsm"
		elseif radio_interface == 2 or (radio_interface >= 4 and radio_interface <= 6) then
			return "umts"
		elseif radio_interface == 7 then
			return "lte"
		end
	end
	return nil
end

function M.get_plmn(device)
	local mcc, mnc, description
	device:send_command('AT+COPS=3,2')
	local ret = device:send_singleline_command("AT+COPS?", "+COPS:")
	if ret then
		local oper = match(ret, '+COPS:%s?%d,%d,"(.+)"')
		if tonumber(oper) then
			mcc = sub(oper, 1, 3)
			mnc = sub(oper, 4)
		end
	end
	device:send_command('AT+COPS=3,0')
	ret = device:send_singleline_command("AT+COPS?", "+COPS:")
	if ret then
		description = match(ret, '+COPS:%s?%d,%d,"(.+)"')
	end
	if not mcc and not mnc and not description then return nil end
	return { mcc = mcc, mnc = mnc, description = description }
end

function M.get_radio_interface(device)
	device:send_command('AT+COPS=3,2')
	local ret = device:send_singleline_command("AT+COPS?", "+COPS:")
	if ret then
		local radio_interface = tonumber(match(ret, '+COPS:%s?%d,%d,".-",(%d)'))
		if radio_interface then
			if radio_interface >= 0 and radio_interface <= 3 and radio_interface ~= 2 then
				return "gsm"
			elseif radio_interface == 2 or (radio_interface >= 4 and radio_interface <= 6) then
				return "umts"
			elseif radio_interface == 7 then
				return "lte"
			end
		else
			local _,_,_, act = M.get_state(device)
			if act then return act end
		end
	end
	return "no_service"
end

function M.get_ps_state(device)
	local ret = device:send_singleline_command("AT+CGREG?", "+CGREG:")
	if ret then
		local state = match(ret, '^+CGREG:%s?%d,(%d+)')
		if state == "1" or state == "5" or state == "10" then
			return "attached"
		end
	end
	return "detached"
end

function M.get_cs_state(device)
	local ret = device:send_singleline_command("AT+CREG?", "+CREG:")
	if ret then
		local state = match(ret, '^+CREG:%s?%d,(%d+)')
		if state == "1" or state == "5" then
			return "attached"
		end
	end
	return "detached"
end

return M
