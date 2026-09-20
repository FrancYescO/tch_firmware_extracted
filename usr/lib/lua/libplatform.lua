--[[

	Platform plugin for VANT-F family

	VBNT-R is a member of VANT-F Family
	VHA0120(VBNT-R) LTE control GPIO description:

	GPIO_12 WAKE_UP
	GPIO_18 VBUS_CRTL
	GPIO_20 W_DISABLE
	GPIO_22 LTE_ON_OFF
	GPIO_33 SLEEP_STATUS
	GPIO_38 LTE_RESET
#
--]]

local io = io
local helper = require('mobiled.scripthelpers')
local uci = require("uci")
local cursor = uci.cursor()
local board_name = cursor:get("env","var","hardware_version")

local M = {}
local power_status = "off"

local function vbnt_r_power_off_internal_module()
	local file = io.open("/sys/class/gpio/gpio22/value", "w")
	if not file then return nil, "Failed to open GPIO_22,LTE_ON_OFF" end
	file:write("0")
	file:close()

	file = io.open("/sys/class/gpio/gpio18/value", "w")
	if not file then return nil, "Failed to open GPIO_18,VBUS_CRTL" end
	file:write("0")
	file:close()

	file = io.open("/sys/class/gpio/gpio12/value", "w")
	if not file then return nil, "Failed to open GPIO_12,WAKEUP_IN_LTE" end
	file:write("0")
	file:close()

	power_status="off"
	return true
end

local function vbnt_r_power_on_internal_module()
	local file = io.open("/sys/class/gpio/gpio22/value", "w")
	if not file then return nil, "Failed to open GPIO_22,LTE_ON_OFF" end
	file:write("1")
	file:close()

	helper.sleep(1)

	file = io.open("/sys/class/gpio/gpio18/value", "w")
	if not file then return nil, "Failed to open GPIO_28,VBUS_CRTL" end
	file:write("1")
	file:close()

	helper.sleep(1)

	-- Keep WAKEUP_IN_LTE at low level before module starts up successfully.
	file = io.open("/sys/class/gpio/gpio12/value", "w")
	if not file then return nil, "Failed to open GPIO_12,WAKEUP_IN_LTE" end
	file:write("1")
	file:close()

	power_status="on"
	return true
end

local function get_current_power_state()
	return power_status
end

function M.init()
	local gpio_list
	if board_name == "VBNT-R" then
		gpio_list = {20,33,38,22,12,18}
	else
		return true
	end

	local file
	-- Export gpio
	for _, gpio in ipairs(gpio_list) do
		file = io.open("/sys/class/gpio/export","w")
		if not file then return nil, "Failed to open GPIO export node" end
		file:write(gpio)
		file:close()
	end

	-- Setup direction
	for _, gpio in ipairs(gpio_list) do
		file = io.open("/sys/class/gpio/gpio" .. gpio .. "/direction","w")
		if not file then return nil,"Failed to open GPIO" .. gpio .."direction" end
		file:write("out")
		file:close()
	end

	-- Setup GPIO default, reserved GPIO_22,GPIO_18 and GPIO_12 for power on/off function
	for i=1,(#gpio_list - 3) do
		file = io.open("/sys/class/gpio/gpio" .. gpio_list[i] .. "/value","w")
		if not file then return nil,"Failed to open GPIO" .. gpio_list[i] .."value" end
		file:write("1")
		file:close()
	end

	return true

end

function M.get_platform_capabilities()
	local capabilities = {}

	if board_name == "VBNT-R" then
		capabilities.power_controls = {
			-- Add power control
			{
				id = 1,
				linked_device = {
					dev_desc = "1-2"
				},
				power_on = vbnt_r_power_on_internal_module,
				power_off = vbnt_r_power_off_internal_module,
				power_state = get_current_power_state
			}
		}
	end

	return capabilities
end

return M
