local pairs, string, tonumber = pairs, string, tonumber

local helper = require("mobiled.scripthelpers")
local atchannel = require("atchannel")

local Mapper = {}
Mapper.__index = Mapper

local M = {}

function Mapper:get_device_capabilities(device, info)
    if device.pid == "0031" then
        info.radio_interfaces = {
            { radio_interface = "gsm" },
            { radio_interface = "umts" },
            { radio_interface = "auto" }
        }
    end
end

function Mapper:get_pin_info(device, info, type)
    if type == "pin1" then
        local ret = device:send_singleline_command('AT+ZPINPUK=?', '+ZPINPUK:')
        if ret then
            info.unlock_retries_left, info.unblock_retries_left = string.match(ret, '+ZPINPUK:%s*(%d+),(%d+)')
        end
    end
end

function Mapper:get_radio_signal_info(device, info)
    local ret = device:send_singleline_command('AT+ZRSSI', '+ZRSSI:')
    if ret then
        local rssi, ecio, rscp = string.match(ret, '+ZRSSI:%s*(%d+),(%d+),(%d+)')
        if rssi then info.rssi = (tonumber(rssi)*-1) end
        if ecio and ecio ~= "1000" then info.ecio = (tonumber(ecio)*-1)/2 end
        if rscp and rscp ~= "1000" then info.rscp = (tonumber(rscp)*-1)/2 end
    end
end

function Mapper:get_pin_info(device, info, type)
    if type == "pin1" then
        local ret = device:send_singleline_command('AT+ZPINPUK=?', '+ZPINPUK:')
        if ret then
            info.unlock_retries_left, info.unblock_retries_left = string.match(ret, '+ZPINPUK:%s*(%d+),(%d+)')
        end
    end
end

function Mapper:get_sim_info(device, info)
    if device.buffer.device_info.model == "MF627" then
        info.iccid_before_unlock = false
    end
end

function Mapper:get_network_info(device, info)
    info.roaming_state = device.buffer.network_info.roaming_state
end

function Mapper:register_network(device, network_config)
    -- ZTE workaround for the +ZUSIMR:2 messages
    for _, intf in pairs(device.control_interfaces) do
        if intf.channel then
            for i=1,3 do
                local ret = atchannel.send_singleline_command(intf.channel, 'AT+CPMS?', '+CPMS:')
                if ret then break end
                helper.sleep(2)
            end
        end
    end
end

function Mapper:unsolicited(device, data, sms_data)
    if helper.startswith(data, "+ZDONR:") then
        local roaming_state = string.match(data, '+ZDONR:%s*".-",%d*,%d*,".-","(.-)"')
        if roaming_state then
            if roaming_state == "ROAM_OFF" then
                device.buffer.network_info.roaming_state = "home"
            else
                device.buffer.network_info.roaming_state = "roaming"
            end
        end
        return true
    end
    -- In case of PPP local echo is enabled again so all commands will end up in unsolicited
    if device.ppp then return true end
    return nil
end

function M.create(pid)
    local mapper = {
        mappings = {
            get_ip_info = "override"
        }
    }

    setmetatable(mapper, Mapper)
    return mapper
end

return M
