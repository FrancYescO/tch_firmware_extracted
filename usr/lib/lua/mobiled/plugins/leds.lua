local M = {}

--[[
	In LTE mode:
	Devices that support 5 bar signal strength indication should display the bars as follow:
	5 bar RSRP > -90
	4 bar -90 ≥ RSRP > -100
	3 bar -100 ≥ RSRP > -105
	2 bar -105 ≥ RSRP > -115
	1 bar -115 ≥ RSRP > -120
	0 bar RSRP ≤ -120
	In UMTS mode:
	Devices that support 5 bar signal strength indication should display the bars as follow:
	5 bar RSCP > -78 
	4 bar -78 >= RSCP > -87
	3 bar -87 >= RSCP > -93
	2 bar -93 >= RSCP > -102
	1 bar -102 >= RSCP < -109
	0 bar -109 >= RSCP
]]--

function M.get_led_info(device)
	local sim_info = device:get_sim_info() or {}
	local pin_info = device:get_pin_info("pin1") or {}
	local sim_state = sim_info.sim_state or "not_present"
	local pin_state = pin_info.pin_state or "unknown"

	local response = { bars = 0, radio = '' }

	if sim_state == "ready" and (pin_state == "enabled_verified" or pin_state == "disabled") then
		local signal_info = device:get_radio_signal_info()
		if type(signal_info) == "table" then
			local radio = signal_info.radio_interface
			response.radio = radio or ''
			if radio == 'lte' then
				local rsrp = tonumber(signal_info.rsrp)
				if rsrp ~= nil then
					if rsrp > -90 then
						response.bars = 5
					elseif rsrp > -100 then
						response.bars = 4
					elseif rsrp > -105 then
						response.bars = 3
					elseif rsrp > -115 then
						response.bars = 2
					elseif rsrp > -120 then
						response.bars = 1
					end
				end
			elseif radio == 'umts' then
				local rscp = tonumber(signal_info.rscp)
				if rscp ~= nil then
					if rscp > -78 then
						response.bars = 5
					elseif rscp > -87 then
						response.bars = 4
					elseif rscp > -93 then
						response.bars = 3
					elseif rscp > -102 then
						response.bars = 2
					elseif rscp > -109 then
						response.bars = 1
					end
				end
			end
		end
	end

	return response
end

return M
