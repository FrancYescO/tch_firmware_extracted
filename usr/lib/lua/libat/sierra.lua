local string, pairs, table = string, pairs, table
local helper = require("mobiled.scripthelpers")

local Mapper = {}
Mapper.__index = Mapper

local M = {}

function Mapper:create_default_context(device, profile)
	local session_id = 0
	local apn = profile.apn or ""
	local command = string.format('AT+CGDCONT=%d,"IP","%s"', (session_id+1), apn)
	device:send_command(command)

	if profile.authentication and profile.password and profile.username then
		local auth_type = "2" -- default  CHAP
		if profile.authentication == "pap" then
			auth_type = "1"
		end
		command = string.format('AT$QCPDPP=%d,%s,"%s","%s"', (session_id+1), auth_type, profile.password, profile.username)
		device:send_command(command)
	else
		device:send_command(string.format('AT$QCPDPP=%d,0', (session_id+1)))
	end

	device:send_command(string.format('AT!SCDFTPROF=%d', (session_id+1)))

	-- Disable default profile
	device:send_command(string.format('AT!SCPROF=%d," ",0,0,0,0', (session_id+1)))
end

function Mapper:start_data_session(device, session_id, profile)
	if device.sessions[session_id + 1].proto == "ppp" then
		return true
	end
	device:send_command(string.format('AT!SCACT=1,%d', (session_id + 1)), 5000)
end

function Mapper:stop_data_session(device, session_id)
	if device.sessions[session_id + 1].proto == "ppp" then
		return true
	end
	device:send_command(string.format('AT!SCACT=0,%d', (session_id + 1)), 2000)
end

function Mapper:get_pin_info(device, info, type)
	local ret = device:send_singleline_command('AT+CPINC?', "+CPINC:", 3000)
	if ret then
		local pin1_unlock_retries, pin2_unlock_retries, pin1_unblock_retries, pin2_unblock_retries = string.match(ret, "+CPINC:%s*(%d+),(%d+),(%d+),(%d+)")
		if type == "pin1" then
			info.unlock_retries_left = pin1_unlock_retries
			info.unblock_retries_left = pin1_unblock_retries
		elseif type == "pin2" then
			info.unlock_retries_left = pin2_unlock_retries
			info.unblock_retries_left = pin2_unblock_retries
		end
	end
end

function M.get_unlock_unblock_retries(device)
	local ret = device:send_singleline_command('AT+CPINC?', "+CPINC:", 3000)
	if ret then
		local pin1_unlock_retries, pin2_unlock_retries, pin1_unblock_retries, pin2_unblock_retries = string.match(ret, "+CPINC:%s*(%d+),(%d+),(%d+),(%d+)")
		return {
			["pin1"] = {
				unlock_retries_left = pin1_unlock_retries,
				unblock_retries_left = pin1_unblock_retries
			},
			["pin2"] = {
				unlock_retries_left = pin2_unlock_retries,
				unblock_retries_left = pin2_unblock_retries
			}
		}
	end
	return nil
end

function Mapper:get_session_info(device, info, session_id)
	if device.sessions[session_id + 1].proto == "ppp" then
		return true
	end
	local ret = device:send_multiline_command('AT!SCACT?', '!SCACT:')
	if ret then
		for _, line in pairs(ret) do
			local state, cid = string.match(line, "!SCACT:%s*(%d+),(%d+)")
			if tonumber(cid) == (session_id + 1) then
				if state == "1" then
					info.session_state = "connected"
				end
			end
		end
	end
end

function Mapper:get_sim_info(device, info, session_id)
	local ret = device:send_singleline_command('AT!ICCID?', '!ICCID:')
	if ret then
		local iccid = string.match(ret, '!ICCID:%s?(.+)')
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
				device.buffer.sim_info.iccid = iccid
			end
		end
	end
end

function Mapper:get_radio_signal_info(device, info)
	local ret = device:send_multiline_command('AT!GSTATUS?', "")
	if ret then
		local match
		for _, line in pairs(ret) do
			match = string.match(line, "RSRQ%s+%(dB%):%s+([%d-]+)")
			if match then info.rsrq = match end
			match = string.match(line, "RSRP%s+%(dBm%):%s+([%d-]+)")
			if match then info.rsrp = match end
			match = string.match(line, "SINR%s+%(dB%):%s+([%d-%.]+)")
			if match then info.snr = match end
			match = string.match(line, "LTE band:%s+B(%d+)")
			if match then info.lte_band = match end
			match = string.match(line, "LTE bw:%s+(%d+)")
			if match then info.lte_dl_bandwidth = match end
			match = string.match(line, "LTE Rx chan:%s+(%d+)")
			if match then info.dl_earfcn = match end
			match = string.match(line, "LTE Tx chan:%s+(%d+)")
			if match then info.ul_earfcn = match end
			match = string.match(line, "TAC:%s+(%d+)")
			if match then device.buffer.network_info.tracking_area_code = match end
		end
	end
end

function Mapper:get_network_info(device, info)
	helper.merge_tables(info, device.buffer.network_info)
end

function Mapper:init_device(device, network_config)
	device:send_command("AT!BAND=0")
	return true
end

function Mapper:unsolicited(device, data, sms_data)
	return nil
end

function Mapper:debug(device)
	table.insert(device.debug.device_state, 'AT!BAND=?')
	local ret = device:send_multiline_command('AT!BAND=?', '')
	if ret then
		for _, line in pairs(ret) do
			table.insert(device.debug.device_state, line)
		end
	end
	table.insert(device.debug.device_state, 'AT!BAND?')
	ret = device:send_multiline_command('AT!BAND?', '')
	if ret then
		for _, line in pairs(ret) do
			table.insert(device.debug.device_state, line)
		end
	end
end

function M.create(pid)
	local mapper = {
		buffer = {
			ip_info = {},
			network_info = {}
		},
		mappings = {
			start_data_session = "override",
			stop_data_session = "override"
		}
	}

	setmetatable(mapper, Mapper)
	return mapper
end

return M
