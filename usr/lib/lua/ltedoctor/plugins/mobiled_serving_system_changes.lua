local M = {}

local last_params = {}

local monitor_params = { "ecgi", "cgi", "tracking_area_code", "location_area_code" }

function M.process(runtime, data, dev_idx)
	if data and data.mobiled_network_serving_system then
		if not last_params[dev_idx] then
			last_params[dev_idx] = {}
		end
		for _, param in pairs(monitor_params) do
			if data.mobiled_network_serving_system then
				if last_params[dev_idx][param] and data.mobiled_network_serving_system[param] and data.mobiled_network_serving_system[param] ~= last_params[dev_idx][param] then
					local event_data = {
						dev_idx = dev_idx,
						event = param .. "_changed",
						["old_" .. param] = last_params[dev_idx][param],
						["new_" .. param] = data.mobiled_network_serving_system[param]
					}
					runtime.send_event("mobiled", event_data)
				end
				last_params[dev_idx][param] = data.mobiled_network_serving_system[param]
			end
		end
	end
	return true
end

return M
