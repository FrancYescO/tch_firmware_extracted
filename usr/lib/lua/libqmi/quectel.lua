local Mapper = {}
Mapper.__index = Mapper

local M = {}

function Mapper:get_sim_info(device, info)
	local ret = device:send_command("--uim-get-card-status")
	if ret then
		if ret.card_state == "absent" then
			info.sim_state = "not_present"
		else
			if ret.pin1_state == "disabled" or ret.pin1_state == "enabled_verified" then
				info.sim_state = "ready"
			elseif ret.pin1_state == "enabled_not_verified" then
				info.sim_state = "locked"
			elseif ret.pin1_state == "blocked" or ret.pin1_state == "permanently_blocked" then
				info.sim_state = "blocked"
			else
				info.sim_state = "not_present"
			end
		end
	end
	info.iccid_before_unlock = false
end

function Mapper:get_pin_info(device, info, pin_type)
	local ret = device:send_command("--uim-get-card-status")
	if ret then
		local t = "1"
		if pin_type == "pin2" then t = "2" end
		info.pin_state = ret["pin" .. t .. "_state"]
		info.unlock_retries_left = ret["pin" .. t .. "_retries"]
		info.unblock_retries_left = ret["puk" .. t .. "_retries"]
	end
end

function Mapper:unlock_pin(device, pin_type, pin)
	local t = "1"
	if pin_type == "pin2" then t = "2" end
	if device:send_command("--uim-verify-pin" .. t .. " " .. pin) then return true end
	return nil
end

function Mapper:unblock_pin(device, pin_type, puk, newpin)
        local t = "1"
        if pin_type == "pin2" then t = "2" end

        if device:send_command("--uim-unblock-pin" .. t .. " --upuk " .. puk .. " --upin " .. newpin) then return true end
        return nil
end

function Mapper:enable_pin(device, pin_type, pin)
	local t = "1"
	if pin_type == "pin2" then t = "2" end
	if device:send_command("--uim-set-pin" .. t .. "-protection enabled --upin " .. pin) then return true end
	return nil
end

function Mapper:disable_pin(device, pin_type, pin)
	local t = "1"
	if pin_type == "pin2" then t = "2" end
	if device:send_command("--uim-set-pin" .. t .. "-protection disabled --upin " .. pin) then return true end
	return nil
end

function Mapper:change_pin(device, pin_type, pin, newpin)
	local t = "1"
	if pin_type == "pin2" then t = "2" end
	if device:send_command("--uim-change-pin" .. t .. " --upin " .. pin .. " --new-upin " .. newpin) then return true end
	return nil
end

function M.create(pid)
    local mapper = {
        mappings = {
            get_sim_info = "override",
            get_pin_info = "override",
            unlock_pin = "override",
            unblock_pin = "override",
            enable_pin = "override",
            disable_pin = "override",
            change_pin = "override"
        }
    }

    setmetatable(mapper, Mapper)
    return mapper
end

return M
