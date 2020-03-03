local helper = require('mobiled.scripthelpers')
local error_handler = require("mobiled.error")

local pdn_retry_timer_max = (2 * 24 * 60 * 60)

local valid_pdn_retry_causes = {
	[8] = true,
	[26] = true,
	[27] = true,
	[28] = true,
	[29] = true,
	[30] = true,
	[31] = true,
	[32] = true,
	[33] = true,
	[34] = true,
	[38] = true
}

local M = {}

M.SenseEventSet = {
	"network_scan_start",
	"network_deregistered",
	"session_disconnected",
	"session_connected",
	"session_teardown",
	"session_setup",
	"device_disconnected",
	"session_config_changed",
	"device_config_changed",
	"platform_config_changed",
	"firmware_upgrade_start",
	"qualtest_start",
	"antenna_change_detected",
	"pdn_retry_timer_expired",
	"sim_removed",
	"sim_acl_changed"
}

function M.check(runtime, event, dev_idx)
	local mobiled = runtime.mobiled
	local log = runtime.log

	local device, errMsg = mobiled.get_device(dev_idx)
	if not device then
		if errMsg then log:error(errMsg) end
		return "DeviceRemove"
	end

	if event.event == "network_deregistered" then
		return "RegisterNetwork"
	elseif event.event == "device_disconnected" then
		return "DeviceRemove"
	elseif event.event == "network_scan_start" then
		return "NetworkScan"
	elseif event.event == "device_config_changed" then
		return "DeviceConfigure"
	elseif event.event == "platform_config_changed" then
		return "PlatformConfigure"
	elseif event.event == "antenna_change_detected" then
		return "SelectAntenna"
	elseif event.event == "firmware_upgrade_start" then
		return "FirmwareUpgrade"
	elseif event.event == "qualtest_start" then
		return "QualTest"
	elseif event.event == "sim_removed" then
		return "SimInit"
	elseif helper.startswith(event.event, "session_") or event.event == "timeout" or event.event == "pdn_retry_timer_expired" or event.event == "sim_acl_changed" then
		local info = device:get_network_info()
		if info and info.nas_state ~= "registered" then
			log:warning("Not registered to network!")
			return "RegisterNetwork"
		end

		local retState = "Idle"
		for _, session in pairs(device:get_data_sessions()) do
			-- In case any session related config changed, cancel the PDN retry timer
			if event.event == "session_config_changed" and session.pdn_retry_timer.timer then
				session.pdn_retry_timer.timer:cancel()
				session.pdn_retry_timer.timer = nil
				session.pdn_retry_timer.value = nil
				log:info("Canceled PDN retry timer")
			end

			-- Check if we need to start a PDN retry timer for the current reject cause
			if event.reject_cause and session.session_id == event.session_id and not session.pdn_retry_timer.timer then
				local cause = tonumber(event.reject_cause)
				log:warning(string.format('Data session setup attempt for PDN %d failed with error "%s"', session.session_id, error_handler.get_error_cause(cause) or "Unknown"))
				if cause and valid_pdn_retry_causes[cause] then
					if not session.pdn_retry_timer.value then
						session.pdn_retry_timer.value = session.pdn_retry_timer.default_value
					else
						session.pdn_retry_timer.value = session.pdn_retry_timer.value * 2
						if session.pdn_retry_timer.value > pdn_retry_timer_max then
							log:error('Maximum PDN retry timer duration reached. Not retrying anymore.')
							mobiled.add_error(device, "fatal", "pdn_retry_timer_max_duration", "Maximum PDN retry timer duration reached")
							return "Error"
						end
					end
					log:info(string.format("Starting PDN retry timer of %d seconds for PDN %d", session.pdn_retry_timer.value, session.session_id))
					session.pdn_retry_timer.timer = runtime.uloop.timer(function()
						session.pdn_retry_timer.timer = nil
						log:info("PDN retry timer expired for session " .. session.session_id)
						runtime.events.send_event("mobiled", { event = "pdn_retry_timer_expired", dev_idx = device.sm.dev_idx })
					end, session.pdn_retry_timer.value * 1000)
					-- Bring down the PPP daemon
					mobiled.propagate_session_state(device, "teardown", "ipv4v6", { session })
				end
			end

			log:info("Checking state for session " .. session.session_id)
			info = device:get_session_info(session.session_id)
			if info then
				log:info("Current state for session " .. session.session_id .. ": " .. info.session_state)
				if session.session_id == 0 and session.changed then
					log:notice("Restart network registration")
					-- Bring down the PPP daemon
					mobiled.propagate_session_state(device, "teardown", "ipv4v6", { session })
					return "RegisterNetwork"
				end

				local profile = mobiled.get_profile(device, session.profile_id)
				if not profile then
					log:error("Failed to retrieve profile")
					return "DataSessionSetup"
				end

				if not mobiled.apn_is_allowed(device, profile.apn) then
					session.allowed = false
				else
					session.allowed = true
				end

				if info.session_state == "disconnected" then
					if session.activated and session.allowed then
						-- Check if we are allowed to try again
						if not session.pdn_retry_timer.timer then
							if not info.autoconnect and not session.autoconnect then
								log:notice("Starting data session %d", session.session_id)
								mobiled.start_data_session(device, session.session_id, profile)
							end
							session.changed = false
						end
						if not session.optional then
							retState = "DataSessionSetup"
						end
					else
						mobiled.propagate_session_state(device, info.session_state, "ipv4v6", { session })

						if session.session_id == 0 then
							local config = mobiled.get_device_config(device)
							if config.device.detach_mode == "detach" or config.device.detach_mode == "poweroff" then
								log:info("Need to detach from network")
								return "RegisterNetwork"
							end
						end
					end
				elseif info.session_state == "connected" then
					if not session.allowed or not session.activated or session.changed then
						log:notice("Deactivating session %d", session.session_id)
						mobiled.stop_data_session(device, session.session_id, session.interface)
						if not session.optional then
							retState = "DataSessionSetup"
						end
					else
						mobiled.propagate_session_state(device, info.session_state, "ipv4v6", { session })
					end
				elseif info.session_state == "connecting" or info.session_state == "disconnecting" then
					mobiled.propagate_session_state(device, info.session_state, "ipv4v6", { session })
					if not session.optional then
						retState = "DataSessionSetup"
					end
				end
			else
				retState = "DataSessionSetup"
			end
		end
		return retState
	end

	return "RegisterNetwork"
end

return M
