--[[
	Platform plugin for VBNT-J family
]]

local cursor = require("uci").cursor()
local helper = require("mobiled.scripthelpers")

local M = {}

local board_name = cursor:get("env", "var", "hardware_version") or "unknown"

local boards = {
	--[[
		VBNT-J(DJN2130) LTE control GPIO description:
		#GPIO_72    LTE_ANT_CTRL1
		#GPIO_73    PERSTa
		#GPIO_100   LTE_PWR_ON_OFF
		#GPIO_101   W_DISABLE
		#GPIO_102   POWER_ON_OFF_OPTION2
		#GPIO_134   USB Interface enable
	]]
	["VBNT-J"] = {
		gpio_list = {
			{pin = 72, value = 0},
			{pin = 73, value = 0},
			{pin = 100, value = 0},
			{pin = 101, value = 0},
			{pin = 102, value = 0},
			{pin = 134, value = 1}
		},
		capabilities = {
			power_controls = {
				{
					linked_device = {
						dev_desc = "3-2"
					}
				}
			},
			rf_controls = {
				{
					linked_device = {
						dev_desc = "3-2"
					}
				}
			},
			sim_hotswap = {
				{
					linked_device = {
						dev_desc = "3-2"
					}
				}
			},
			antenna_controls = {
				{
					linked_device = {
						dev_desc = "3-2"
					},
					antenna = {
						{
							name = "main",
							detector_type = "none"
						}
					}
				}
			}
		}
	},
	--[[
		VBNT-V (DJN2231) LTE control GPIO description:
		GPIO_72		LTE_ANT_CRTL
		GPIO_73		LTE_RESET
		GPIO_74		LTE_VOLTE_STATE
		GPIO_96		LTE_WAKEUP
		GPIO_97		SLEEP_STATUS
		GPIO_98		VBUS_CRTL
		GPIO_100	POWER_ON_OFF
		GPIO_101	W_DISABLE
	--]]
	["VBNT-V"] = {
		gpio_list = {
			{pin = 72, value = 1},
			{pin = 73, value = 1},
			{pin = 74, value = 0},
			{pin = 96, value = 1},
			{pin = 97, value = 1},
			{pin = 98, value = 1},
			{pin = 100, value = 1},
			{pin = 101, value = 0}
		},
		capabilities = {
			voice = {
				{
					linked_device = {
						dev_desc = "3-2"
					},
					interfaces = {
						{
							type = "pcm",
							bus = 0,
							slot = 4,
							samplerate = 8000,
							format = "16-bit linear"
						}
					}
				}
			},
			power_controls = {
				{
					linked_device = {
						dev_desc = "3-2"
					}
				}
			},
			rf_controls = {
				{
					linked_device = {
						dev_desc = "3-2"
					}
				}
			},
			sim_hotswap = {
				{
					linked_device = {
						dev_desc = "3-2"
					}
				}
			},
			antenna_controls = {
				{
					linked_device = {
						dev_desc = "3-2"
					},
					antenna = {
						{
							name = "main",
							detector_type = "none"
						}
					}
				}
			}
		}
	},
	--[[
		VBNT-Y (JDA0231TLS) LTE control GPIO description:
		GPIO_00 	USB_ID_LTE(USB OTG)
		GPIO_08		LTE_WAKEUP
		GPIO_09		W_DISABLE
		GPIO_14 	LTE_ON_OFF
		GPIO_54		RESET_LTE
		GPIO_115	VBUS_CRTL
		GPIO_120	LTE_VOLTE_STATE
	--]]
	["VBNT-Y"] = {
		gpio_list = {
			{pin = 0, value = 1},
			{pin = 8, value = 1},
			{pin = 9, value = 0},
			{pin = 14, value = 1},
			{pin = 54, value = 1},
			{pin = 115, value = 1},
			{pin = 120, value = 0},
		},
		capabilities = {
			voice = {
				{
					linked_device = {
						dev_desc = "2-1"
					},
					interfaces = {
						{
							type = "pcm",
							bus = 0,
							slot = 4,
							samplerate = 8000,
							format = "16-bit linear"
						}
					}
				}
			},
			power_controls = {
				{
					linked_device = {
						dev_desc = "2-1"
					}
				}
			},
			rf_controls = {
				{
					linked_device = {
						dev_desc = "2-1"
					}
				}
			},
			sim_hotswap = {
				{
					linked_device = {
						dev_desc = "2-1"
					}
				}
			}
		}
	}
}

boards["VBNT-J"].capabilities.power_controls[1].power_off = function()
	helper.write_file("/sys/class/gpio/gpio102/value", "0")
	helper.sleep(0.2)
	helper.write_file("/sys/class/gpio/gpio73/value", "0")
	helper.sleep(0.2)
	helper.write_file("/sys/class/gpio/gpio100/value", "0")
	return true
end

boards["VBNT-J"].capabilities.power_controls[1].power_on = function()
	helper.write_file("/sys/class/gpio/gpio100/value", "1")
	helper.sleep(0.2)
	helper.write_file("/sys/class/gpio/gpio73/value", "1")
	helper.sleep(0.2)
	helper.write_file("/sys/class/gpio/gpio102/value", "1")
	return true
end

boards["VBNT-J"].capabilities.power_controls[1].power_state = function()
	local content = helper.read_file("/sys/class/gpio/gpio102/value")
	if content and content:match("0") then
		return "off"
	end
	content = helper.read_file("/sys/class/gpio/gpio73/value")
	if content and content:match("0") then
		return "off"
	end
	content = helper.read_file("/sys/class/gpio/gpio100/value")
	if content and content:match("0") then
		return "off"
	end
	return "on"
end

boards["VBNT-J"].capabilities.antenna_controls[1].antenna[1].select_antenna = function(antenna)
	local file = "/sys/class/gpio/gpio72/value"
	if antenna == "external" then
		helper.write_file(file, "1")
	else
		helper.write_file(file, "0")
	end
	return true
end

boards["VBNT-J"].capabilities.antenna_controls[1].antenna[1].antenna_state = function()
	local content = helper.read_file("/sys/class/gpio/gpio72/value")
	if content and content:match("1") then
		return "external"
	end
	return "internal"
end

boards["VBNT-J"].capabilities.rf_controls[1].enable = function()
	return helper.write_file("/sys/class/gpio/gpio101/value", "1")
end

boards["VBNT-J"].capabilities.rf_controls[1].disable = function()
	return helper.write_file("/sys/class/gpio/gpio101/value", "0")
end

boards["VBNT-J"].capabilities.rf_controls[1].rf_state = function()
	local content = helper.read_file("/sys/class/gpio/gpio101/value")
	if content and content:match("1") then
		return "enabled"
	end
	return "disabled"
end

boards["VBNT-V"].capabilities.power_controls[1].reset = function()
	if helper.write_file("/sys/class/gpio/gpio73/value", "0") then
		-- Assert the reset line for at least 100ms
		helper.sleep(0.2)
		helper.write_file("/sys/class/gpio/gpio73/value", "1")
	end
end

boards["VBNT-V"].capabilities.antenna_controls[1].antenna[1].select_antenna = function(antenna)
	local file = "/sys/class/gpio/gpio72/value"
	if antenna == "external" then
		helper.write_file(file, "0")
	else
		helper.write_file(file, "1")
	end
	return true
end

boards["VBNT-V"].capabilities.antenna_controls[1].antenna[1].antenna_state = function()
	local content = helper.read_file("/sys/class/gpio/gpio72/value")
	if content and content:match("0") then
		return "external"
	end
	return "internal"
end

boards["VBNT-V"].capabilities.rf_controls[1].enable = function()
	return helper.write_file("/sys/class/gpio/gpio101/value", "0")
end

boards["VBNT-V"].capabilities.rf_controls[1].disable = function()
	return helper.write_file("/sys/class/gpio/gpio101/value", "1")
end

boards["VBNT-V"].capabilities.rf_controls[1].rf_state = function()
	local content = helper.read_file("/sys/class/gpio/gpio101/value")
	if content and content:match("1") then
		return "enabled"
	end
	return "disabled"
end

boards["VBNT-Y"].capabilities.power_controls[1].reset = function()
	if helper.write_file("/sys/class/gpio/gpio54/value", "0") then
		-- Assert the reset line for at least 100ms
		helper.sleep(0.2)
		helper.write_file("/sys/class/gpio/gpio54/value", "1")
	end
end

boards["VBNT-Y"].capabilities.rf_controls[1].enable = function()
	return helper.write_file("/sys/class/gpio/gpio9/value", "0")
end

boards["VBNT-Y"].capabilities.rf_controls[1].disable = function()
	return helper.write_file("/sys/class/gpio/gpio9/value", "1")
end

boards["VBNT-Y"].capabilities.rf_controls[1].rf_state = function()
	local content = helper.read_file("/sys/class/gpio/gpio9/value")
	if content and content:match("1") then
		return "enabled"
	end
	return "disabled"
end

function M.init()
	if board_name == "VCNT-A" then
		board_name = "VBNT-Y"
	end
	local family_member = boards[board_name]
	if not family_member then
		return true
	end
	for _, gpio in pairs(family_member.gpio_list) do
		-- Only do the init of the GPIOs once
		if not helper.isDir("/sys/class/gpio/gpio" .. gpio.pin) then
			if helper.write_file("/sys/class/gpio/export", gpio.pin) then
				if helper.write_file("/sys/class/gpio/gpio" .. gpio.pin .. "/direction", "out") then
					helper.write_file("/sys/class/gpio/gpio" .. gpio.pin .. "/value", gpio.value)
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
