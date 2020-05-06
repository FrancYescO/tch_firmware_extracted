--[[
	VBNT-J(DJN2130) LTE control GPIO description:
	#GPIO_72	LTE_ANT_CTRL1
	#GPIO_73 	PERSTa
	#GPIO_100	LTE_PWR_ON_OFF
	#GPIO_102	POWER_ON_OFF_OPTION2
	#GPIO_134	USB Interface enable
--]]

local io = io
local helper = require('mobiled.scripthelpers')

local M = {}

local function power_off_internal_module()
	local file = io.open("/sys/class/gpio/gpio102/value", "w")
	if not file then return nil, "Failed to open perst" end

	file:write("0")
	file:close()

	helper.sleep(1)

	file = io.open("/sys/class/gpio/gpio73/value", "w")
	if not file then return nil, "Failed to open lte_pwr_on_off" end

	file:write("0")
	file:close()

	helper.sleep(1)

	file = io.open("/sys/class/gpio/gpio100/value", "w")
	if not file then return nil, "Failed to open lte_pwr_on_off" end

	file:write("0")
	file:close()

	return true
end

local function power_on_internal_module()
	local file = io.open("/sys/class/gpio/gpio100/value", "w")
	if not file then return nil, "Failed to open lte_pwr_on_off" end

	file:write("1")
	file:close()

	helper.sleep(1)

	file = io.open("/sys/class/gpio/gpio73/value", "w")
	if not file then return nil, "Failed to open lte_pwr_on_off" end

	file:write("1")
	file:close()

	helper.sleep(1)

	file = io.open("/sys/class/gpio/gpio102/value", "w")
	if not file then return nil, "Failed to open perst" end

	file:write("1")
	file:close()

	return true
end

local function get_current_power_state()
	local file = io.open("/sys/class/gpio/gpio102/value", "r")
	if not file then return nil, "Failed to open lte_pwr_on_off" end
	local content = file:read("*a")
	file:close()
	if string.match(content, "0") then
		return "off"
	end

	file = io.open("/sys/class/gpio/gpio73/value", "r")
	if not file then return nil, "Failed to open perst" end
	content = file:read("*a")
	file:close()
	if string.match(content, "0") then
		return "off"
	end

	file = io.open("/sys/class/gpio/gpio100/value", "r")
	if not file then return nil, "Failed to open perst" end
	content = file:read("*a")
	file:close()
	if string.match(content, "0") then
		return "off"
	end

	return "on"
end

local function select_antenna(antenna)
	local file = io.open("/sys/class/gpio/gpio72/value", "w")
	if not file then return nil, "Failed to open lte_ant_ctrl" end

	if antenna == "external" then
		file:write("1")
	else
		file:write("0")
	end
	file:close()

	return true
end

local function get_current_antenna()
	local file = io.open("/sys/class/gpio/gpio72/value", "r")
	if not file then return nil, "Failed to open lte_ant_ctrl" end
	local content = file:read("*a")
	file:close()
	if string.match(content, "1") then
		return "external"
	end
	return "internal"
end

function M.get_platform_capabilities()
	local power_controls = {
		-- Add power control
		{
			id = 1,
			linked_device = {
				dev_desc = "1-2"
			},
			power_on = power_on_internal_module,
			power_off = power_off_internal_module,
			power_state = get_current_power_state
		}
	}
	local antenna_controls = {
		-- Add antenna control
		{
			id = 1,
			name = "main",
			detector_type = "none",
			linked_device = {
				dev_desc = "1-2"
			},
			select_antenna = select_antenna,
			antenna_state = get_current_antenna
		}
	}
	local capabilities = {
		power_controls = power_controls,
		antenna_controls = antenna_controls
	}
	return capabilities
end

return M
