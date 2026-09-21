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

function M.unlock(device, pin)
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

function M.unblock(device, puk, newpin)
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

function M.change_pin(device, pin, newpin)
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

function M.disable_pin(device, pin)
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

function M.enable_pin(device, pin)
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
