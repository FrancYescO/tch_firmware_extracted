--[[
	Platform plugin for VANT-9 family
]]

local cursor = require("uci").cursor()
local helper = require("mobiled.scripthelpers")

local M = {}

local board_name = cursor:get("env", "var", "hardware_version") or "unknown"

local boards = {
	--[[
		VBNT-Z is a member of VANT-9 Family
		DNA0130VDF_NZ (VBNT-Z) LTE control GPIO description:

		GPIO_12 3.8V_ENABLE
		GPIO_14 LTE_RESET
		GPIO_22	VBUS_CTRL
		GPIO_23 SLEEP_STATUS
		GPIO_35 WAKEUP_IN_M
		GPIO_40 LTE_ON_OFF_M
		GPIO_41 W_DISABLE
	]]
	["VBNT-Z"] = {
		gpio_list = {
			{pin = 12, value = 1},
			{pin = 14, value = 1},
			{pin = 22, value = 1},
			{pin = 23, value = 1},
			{pin = 35, value = 1},
			{pin = 40, value = 1},
			{pin = 41, value = 1}
		},
		capabilities = {
			power_controls = {
				{
					linked_device = {
						dev_desc = "1-2"
					}
				}
			},
			sim_hotswap = {
				{
					linked_device = {
						dev_desc = "1-2"
					}
				}
			}
		}
	}
}

boards["VBNT-Z"].capabilities.power_controls[1].reset = function()
	if helper.write_file("/sys/class/gpio/gpio14/value", "0") then
		-- Assert the reset line for at least 100ms
		helper.sleep(0.2)
		helper.write_file("/sys/class/gpio/gpio14/value", "1")
	end
end

function M.init()
	local family_member = boards[board_name]
	local run_init = false
	if not family_member then
		return true
	end
	for _, gpio in pairs(family_member.gpio_list) do
		-- Only do the init of the GPIOs once
		if not helper.isDir("/sys/class/gpio/gpio" .. gpio.pin) then
			if helper.write_file("/sys/class/gpio/export", gpio.pin) then
				if helper.write_file("/sys/class/gpio/gpio" .. gpio.pin .. "/direction", "out") then
					helper.write_file("/sys/class/gpio/gpio" .. gpio.pin .. "/value", gpio.value)
					run_init = true
				end
			end
		end
	end
	-- Workaround for LTE module not getting reset on reboot
	if run_init and family_member.capabilities.power_controls[1].reset then
		family_member.capabilities.power_controls[1].reset()
	end

	return true
end

function M.get_platform_capabilities()
	local family_member = boards[board_name]
	if family_member then
		return family_member.capabilities
	end
	return {}
end

return M
