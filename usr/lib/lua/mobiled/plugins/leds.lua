local tonumber = tonumber
local M = {}

function M.get_led_info(device)
	local bars = 0
	local signal_info = device:get_radio_signal_info()
	local sim_info = device:get_sim_info() or {}
	local pin_info = device:get_pin_info("pin1") or {}

	local sim_state = sim_info.sim_state or "not_present"
	local pin_state = pin_info.pin_state or "unknown"

	if type(signal_info) == "table" then
		local radio = signal_info.radio_interface
		if radio == 'lte' then
			local rsrp = tonumber(signal_info.rsrp)
			if rsrp ~= nil then
				if rsrp > -85 then
					bars = 5
				elseif rsrp > -95 then
					bars = 4
				elseif rsrp > -105 then
					bars = 3
				elseif rsrp > -115 then
					bars = 2
				else
					bars = 1
				end
			end
		elseif radio == 'umts' or radio == 'gsm' then
			local rssi = tonumber(signal_info.rssi)
			if rssi ~= nil then
				if rssi >= -77 then
					bars = 5
				elseif rssi >= -86 then
					bars = 4
				elseif rssi >= -92 then
					bars = 3
				elseif rssi >= -101 then
					bars = 2
				else
					bars = 1
				end
			end
		end
		return {
			bars = bars,
			radio = radio,
			pin_state = pin_state,
			sim_state = sim_state
		}
	end
	return {
		bars = 0,
		radio = '',
		pin_state = pin_state,
		sim_state = sim_state
	}
end

return M
