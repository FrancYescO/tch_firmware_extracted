--[[
	Platform plugin for VANT-F family
]]

local cursor = require("uci").cursor()
local helper = require("mobiled.scripthelpers")

local M = {}

local board_name = cursor:get("env", "var", "hardware_version") or "unknown"

local boards = {
	--[[
		VBNT-R is a member of VANT-F Family
		VHA0120 (VBNT-R) LTE control GPIO description:

		GPIO_12 WAKE_UP
		GPIO_18 VBUS_CRTL
		GPIO_20 W_DISABLE
		GPIO_22 LTE_ON_OFF
		GPIO_33 SLEEP_STATUS
		GPIO_38 LTE_RESET
	]]
	["VBNT-R"] = {
		gpio_list = {20, 33, 38, 22, 12, 18},
		capabilities = {
			power_controls = {
				-- Add power control
				{
					id = 1,
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

boards["VBNT-R"].capabilities.power_controls[1].reset = function()
	local function write_reset(value)
		local file = io.open("/sys/class/gpio/gpio38/value", "w")
		if not file then return nil, "Failed to open gpio38 (LTE_RESET)" end
		file:write(value)
		file:close()
		return true
	end
	if write_reset("0") then
		-- Assert the reset line for at least 100ms
		helper.sleep(0.2)
		write_reset("1")
	end
end

function M.init()
	local family_member = boards[board_name]
	if not family_member then
		return true
	end

	local file
	for _, gpio in ipairs(family_member.gpio_list) do
		-- Only do the init of the GPIOs once
		if not helper.isDir("/sys/class/gpio/gpio" .. gpio) then
			-- Export GPIO
			file = io.open("/sys/class/gpio/export", "w")
			if file then
				file:write(gpio)
				file:close()
				-- Set GPIO to output
				file = io.open("/sys/class/gpio/gpio" .. gpio .. "/direction", "w")
				if file then
					file:write("out")
					file:close()
					-- Set GPIO default value to 1
					file = io.open("/sys/class/gpio/gpio" .. gpio .. "/value", "w")
					if file then
						file:write("1")
						file:close()
					end
				end
			end
		end
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
