local M = {}

function M.get_led_info(device)
	local sim_info = device:get_sim_info() or {}
	local pin_info = device:get_pin_info("pin1") or {}
	local sim_state = sim_info.sim_state or "not_present"
	local pin_state = pin_info.pin_state or "unknown"

	local response = { bars = 0, radio = '' }

	if sim_state == "ready" and (pin_state == "enabled_verified" or pin_state == "disabled") then
		local signal_info = device:get_radio_signal_info(10)
		if type(signal_info) == "table" then
			local radio = signal_info.radio_interface
			response.radio = radio or ''
			response.bars = signal_info.bars or 0
			if radio == 'lte' then
				local rsrp = tonumber(signal_info.rsrp)
				if rsrp ~= nil then
					if rsrp > -85 then
						response.bars = 5
					elseif rsrp > -95 then
						response.bars = 4
					elseif rsrp > -105 then
						response.bars = 3
					elseif rsrp > -115 then
						response.bars = 2
					else
						response.bars = 1
					end
				end
			elseif radio == 'umts' or radio == 'gsm' then
				local rssi = tonumber(signal_info.rssi)
				if rssi ~= nil then
					if rssi >= -77 then
						response.bars = 5
					elseif rssi >= -86 then
						response.bars = 4
					elseif rssi >= -92 then
						response.bars = 3
					elseif rssi >= -101 then
						response.bars = 2
					else
						response.bars = 1
					end
				end
			end
		end
	end

	return response
end

return M
