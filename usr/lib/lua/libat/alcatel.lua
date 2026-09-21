local tinsert = table.insert
local helper = require("mobiled.scripthelpers")

local attty = require("libat.tty")

local Mapper = {}
Mapper.__index = Mapper

local M = {}
local enable_usbmode = 1
local IP_ADDRESS = "172.16.34.253"
local SUBNET_MASK = "255.255.255.252"
local IP_ADDRESS_START = "172.16.34.254"
local IP_ADDRESS_END = "172.16.34.254"

function Mapper:init_device(device)

        local ip = device:send_multiline_command('AT+DHCPSETTING?', "")
        local dhcp_response
        if ip then
                for _, line in pairs(ip) do
                        local ip_add  =  line:match('^IP%saddress:%s*(.-)$')
                        if ip_add and ip_add ~= IP_ADDRESS then
				dhcp_response = device:send_command(string.format('AT+DHCPSETTING=%s,%s,%s,%s', IP_ADDRESS, SUBNET_MASK, IP_ADDRESS_START, IP_ADDRESS_END))
                                break
                        elseif ip_add == IP_ADDRESS then
                                dhcp_response = true
                                break
                        end
                end
        end

        if device.pid == "00b6" and enable_usbmode == 1 then
                if dhcp_response and device:send_singleline_command('AT+USBMODE?', '+USBMODE:') == '+USBMODE:0' then
                        helper.sleep(3)
                        if device:send_command('AT+USBMODE=1') then
                                helper.sleep(3)
                                device.runtime.log:notice("Switched to USBMODE 1")
                        else
                                return false
                        end
                else
                        return false
                end
        elseif enable_usbmode == 0 then
                if device:send_command('AT+USBMODE=0') then
                        device.runtime.log:notice("Switched to USBMODE 0")
                else
                        return false
                end
        end

        return true
end

function Mapper:get_device_capabilities(device, info)
        info.radio_interfaces = {
                { radio_interface = "gsm" },
                { radio_interface = "umts" },
                { radio_interface = "lte" },
                { radio_interface = "auto" }
        }
end

function M.create(runtime, device) --luacheck: no unused args
        local mapper = {
                mappings = {}
        }

        device.default_interface_type = "control"

        if device.pid == "01aa" then
                local ports = attty.find_tty_interfaces(device.desc)
                if ports and #ports >= 2 then
                        tinsert(device.interfaces, { port = ports[0], type = "modem" })
                        tinsert(device.interfaces, { port = ports[1], type = "control" })
                        device.sessions[1] = { proto = "dhcp" }
                end
        else
                local ports = attty.find_tty_interfaces(device.desc)
                if ports and #ports >= 2 then
                        tinsert(device.interfaces, { port = ports[1], type = "modem" })
                        tinsert(device.interfaces, { port = ports[3], type = "control" })
                        device.sessions[1] = { proto = "ppp" }
                end
        end

        setmetatable(mapper, Mapper)
        return mapper
end
return M
