local tonumber = tonumber
local M = {}

local snrMin = 0
local snrMax = 30

function M.get_led_info(device)
	local bars, percentage = 0, 0
	local signal_info = device:get_radio_signal_info()

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
			local snr = tonumber(signal_info.snr)
			if snr ~= nil then
				if snr > snrMax then
					snr = snrMax
				end
				if snr < snrMin then
					snr = snrMin
				end
				percentage = ((snr-snrMin)*(100/(snrMax-snrMin)))
				percentage = string.format("%d", math.ceil(percentage))
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
		return { bars = bars, percentage = percentage, radio = radio }
	end
	return { bars = 0, percentage = 0, radio = '' }
end

return M
