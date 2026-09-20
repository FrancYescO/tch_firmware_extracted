local string = string
local helper = require("mobiled.scripthelpers")

local M = {}

function M.get_state(device)
	local ret, err, cme_err = device:send_singleline_command("AT+CPIN?", "+CPIN:")

	local sim_state = ""

	if err == "cme error" then
		if cme_err == "sim failure" or cme_err == "sim not inserted" then
			sim_state = "not_present"
		elseif cme_err == "sim busy" then
			sim_state = "busy"
		elseif cme_err == "sim failure" or cme_err == "sim wrong" then
			sim_state = "error"
		end
	end

	if type(ret) == "string" then
		if string.match(ret, "SIM PIN") then
			sim_state = "locked"
		elseif string.match(ret, "SIM PUK") then
			sim_state = "blocked"
		elseif string.match(ret, "READY") then
			sim_state = "ready"
		end
	end

	return sim_state
end

function M.get_operator_name(device, plmn)
	if not device.buffer.sim_info.operator_names then
		local ret = device:send_multiline_command("AT+COPN", "+COPN:", 10000)
		if type(ret) == "table" then
			device.buffer.sim_info.operator_names = {}
			for _, line in pairs(ret) do
				local num_plmn, name = string.match(line, '+COPN:%s?"(.-)","(.-)"')
				if num_plmn then
					device.buffer.sim_info.operator_names[num_plmn] = name
				end
			end
		end
	end
	if device.buffer.sim_info.operator_names then
		return device.buffer.sim_info.operator_names[plmn]
	end
	return nil, "No operators available"
end

function M.get_forbidden_plmn(device)
	local ret = device:send_singleline_command("AT+CRSM=176,28539,0,0,12", "+CRSM:")
	if ret then
		local output = string.match(ret, '+CRSM:%s?%d+,%d+,"(.-)"')
		if output then
			local forbidden_plmn = {}
			local parts = {}
			for i = 1, #output do
				local c = output:sub(i, i)
				table.insert(parts, c)
				if i%6 == 0 then
					local mcc = parts[2] .. parts[1] .. parts[4]
					local mnc
					if parts[3] ~= 'F' then
						mnc = parts[3] .. parts[6] .. parts[5]
					else
						mnc = parts[6] .. parts[5]
					end
					parts = {}
					table.insert(forbidden_plmn, { mcc = mcc, mnc = mnc, description = M.get_operator_name(device, mcc .. mnc) })
				end
			end
			return forbidden_plmn
		end
	end
	return {}
end

function M.get_preferred_plmn(device)
	local ret = device:send_multiline_command("AT+CPOL?", "+CPOL:")
	if type(ret) == "table" then
		local preferred_plmn = {}
		for _, line in pairs(ret) do
			local index, type, plmn = string.match(line, '+CPOL:%s?(%d+),(%d+),"(.-)"')
			if type == "2" then
				local mcc = string.sub(plmn, 1, 3)
				local mnc = string.sub(plmn, 4)
				table.insert(preferred_plmn, { mcc = mcc, mnc = mnc, description = M.get_operator_name(device, plmn), index = tonumber(index) })
			end
		end
		return preferred_plmn
	end
	return {}
end

function M.get_imsi(device)
	local ret = device:send_singleline_command("AT+CIMI", "")
	if ret and tonumber(ret) then return ret end
	return nil
end

local function check_iccid(iccid)
	if iccid then
		if tonumber(string.sub(iccid, 20, 20)) then
			iccid = string.sub(iccid, 1, 20)
		else
			iccid = string.sub(iccid, 1, 19)
		end
		if string.match(string.sub(iccid, 1, 2), "98") then
			iccid = helper.swap(iccid)
		end
		if helper.isnumeric(iccid) then
			return iccid
		end
	end
	return nil
end

function M.get_iccid(device)
	local ret = device:send_singleline_command("AT+CRSM=176,12258", "+CRSM:")
	if ret then
		return check_iccid(string.match(ret, '+CRSM:%s?%d+,%d+,"(.-)"'))
	end
	ret = device:send_singleline_command("AT+CCID", "+CCID:")
	if ret then
		return check_iccid(string.match(ret, '+CCID:%s?(%d+)'))
	end
	ret = device:send_singleline_command("AT+ICCID", "+ICCID:")
	if ret then
		return check_iccid(string.match(ret, '+ICCID:%s?(%d+)'))
	end
	return nil
end

function M.get_msisdn(device)
	local ret = device:send_multiline_command("AT+CNUM", "+CNUM:")
	if ret then
		for _, line in pairs(ret) do
			local match = string.match(line, '+CNUM:%s?"Voice Number","(%d-)",')
			if match and match ~= "" then return match end
			match = string.match(line, '+CNUM:%s?"GSM Number","(%d-)",')
			if match and match ~= "" then return match end
		end
	end
	return nil
end

function M.get_locking_facility(device, facility)
	local ret = device:send_singleline_command('AT+CLCK="' .. facility .. '",2', "+CLCK:")
	if ret then
		local enabled = string.match(ret, "[0-1]")
		if enabled then
			if enabled == '1' then return true end
			return false
		end
	end
	return nil
end

function M.unlock(device, pin_type, pin)
	local ret, err, cme_err = device:send_command('AT+CPIN="' .. pin .. '"', 2000)
	if not ret then
		if err == "cme error" then
			if cme_err == "password wrong" then
				return nil, "Wrong PIN code provided"
			end
		end
		return nil
	end
	return true
end

function M.unblock(device, pin_type, puk, newpin)
	local ret, err, cme_err = device:send_command('AT+CPIN="' .. puk .. '","' .. newpin .. '"', 2000)
	if not ret then
		if err == "cme error" then
			if cme_err == "password wrong" then
				return nil, "Wrong PUK code provided"
			end
		end
		return nil
	end
	return true
end

function M.change_pin(device, pin_type, pin, newpin)
	local ret, err, cme_err = device:send_command('AT+CPWD="SC","' .. pin .. '","' .. newpin .. '"', 2000)
	if not ret then
		if err == "cme error" then
			if cme_err == "password wrong" then
				return nil, "Wrong PIN code provided"
			end
		end
		return nil
	end
	return true
end

function M.disable_pin(device, pin_type, pin)
	local enabled = M.get_locking_facility(device, "SC")
	local ret, err, cme_err = device:send_command('AT+CLCK="SC",0,"' .. pin .. '"', 2000)
	if not ret then
		if err == "cme error" then
			if cme_err == "password wrong" then
				return nil, "Wrong PIN code provided"
			elseif not enabled then
				return true
			end
		end
		return nil
	end
	return true
end

function M.enable_pin(device, pin_type, pin)
	local enabled = M.get_locking_facility(device, "SC")
	local ret, err, cme_err = device:send_command('AT+CLCK="SC",1,"' .. pin .. '"', 2000)
	if not ret then
		if err == "cme error" then
			if cme_err == "password wrong" then
				return nil, "Wrong PIN code provided"
			elseif enabled then
				return true
			end
		end
		return nil
	end
	return true
end

return M
