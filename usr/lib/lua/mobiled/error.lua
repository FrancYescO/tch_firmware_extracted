---------------------------------
--! @file
--! @brief Provides Mobiled error handling functionality
---------------------------------

local helper = require("mobiled.scripthelpers")

local M = {}

function M.get_emm_error_cause(cause)
	cause = tonumber(cause)
	if not cause then
		return nil, "Invalid parameter"
	end

	local emm_causes = {
		[2] = "IMSI unknown in HSS",
		[3] = "Illegal UE",
		[5] = "IMEI not accepted",
		[6] = "Illegal ME",
		[7] = "EPS services not allowed",
		[8] = "EPS services and non-EPS services not allowed",
		[9] = "UE identity cannot be derived by the network",
		[10] = "Implicitly detached",
		[11] = "PLMN not allowed",
		[12] = "Tracking area not allowed",
		[13] = "Roaming not allowed in this tracking area",
		[14] = "EPS services not allowed in this PLMN",
		[15] = "No suitable cells in tracking area",
		[16] = "MSC temporarily not reachable",
		[25] = "Not authorized for this CSG",
		[40] = "No EPS bearer context activated"
	}
	return emm_causes[cause] or nil, "Unknown EMM cause"
end

function M.get_esm_error_cause(cause)
	cause = tonumber(cause)
	if not cause then
		return nil, "Invalid parameter"
	end
	local esm_causes = {
		[8] = "Operator determined barring",
		[26] = "Insufficient resources",
		[27] = "Missing or unknown APN",
		[28] = "Unknown PDP address or PDP type",
		[29] = "User authentication failed",
		[30] = "Activation rejected by Serving GW or PDN GW",
		[31] = "Activation rejected, unspecified",
		[32] = "Service option not supported",
		[33] = "Requested service option not subscribed",
		[34] = "Service option temporarily out of order",
		[35] = "NSAPI already used",
		[36] = "Regular deactivation",
		[37] = "SDF QoS not accepted",
		[38] = "Network failure",
		[41] = "Semantic error in the TFT operation",
		[42] = "Syntactical error in the TFT operation",
		[43] = "Unknown EPS bearer context",
		[44] = "Semantic error in packet filter(s)",
		[45] = "Syntactical error in packet filter(s)",
		[46] = "EPS bearer context without TFT already activated",
		[48] = "Activation rejected, bearer control mode violation",
		[50] = "PDN type IPv4 only allowed",
		[51] = "PDN type IPv6 only allowed",
		[52] = "Single address bearers only allowed",
		[53] = "ESM information not received",
		[54] = "PDN connection does not exist",
		[55] = "Multiple PDN connections for a given APN not allowed",
		[112] = "APN restriction value incompatible with active EPS bearer context"
	}
	return esm_causes[cause] or nil, "Unknown ESM cause"
end

function M.get_error_cause(cause)
	local error = M.get_esm_error_cause(cause)
	if error then return error end
	return M.get_emm_error_cause(cause)
end

function M.reject_cause_severity(cause)
	cause = tonumber(cause)
	-- Normal detach cause
	if cause == 36 then
		return "info"
	end
	return "error"
end

function M.add_error(device, severity, error_type, data)
	if not device.errors then device.errors = {} end

	-- Add the error string for the EMM/ESM reject cause
	if error_type == "reject_cause" then
		if data and data.reject_cause then
			data.reject_cause_message = M.get_error_cause(data.reject_cause)
		end
	end

	local uptime = helper.uptime()
	if #device.errors > 20 then
		table.remove(device.errors, 1)
	end
	local error = {
		severity = severity,
		type = error_type,
		data = data,
		uptime = uptime,
		state = device.sm.currentState
	}
	table.insert(device.errors, error)
end

return M
