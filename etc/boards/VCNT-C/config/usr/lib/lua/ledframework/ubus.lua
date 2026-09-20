local ubus, uloop, uci = require('ubus'), require('uloop'), require('uci')
local netlink = require("tch.netlink")
local format = string.format

local M = {}
local cursor = uci.cursor()

function M.start(cb)
    uloop.init()
    local conn = ubus.connect()
    if not conn then
        error("Failed to connect to ubusd")
    end

    local events = {}
    events['network.interface'] = function(msg)
        if msg ~= nil and msg.interface ~= nil and msg.action ~= nil then
            cb('network_interface_' .. msg.interface:gsub('[^%a%d_]','_') .. '_' .. msg.action:gsub('[^%a%d_]','_'))
             if msg.action == "ifup" and msg.interface == "wan" then
                cursor:load("network")
                local bigpond = cursor:get("network", "wan", "username")
                if bigpond ~= nil and bigpond == "newdsluser@bigpond.com" then
                     cb('network_interface_connected_with_bigpond')
                else
                     cb('network_interface_connected_without_bigpond')
                end
            end
            local InfoWAN = {}
            local InfoWAN6 = {}
            local stateWAN
            local stateWAN6
            if msg.action == "ifdown" then
               if msg.interface == "wan" then
                  InfoWAN6 = conn:call("network.interface.wan6", "status", {})
                  stateWAN6 = InfoWAN6.up
               end
               if msg.interface == "wan6" then
                  InfoWAN = conn:call("network.interface.wan", "status", {})
                  stateWAN = InfoWAN.up
               end
            end
            if stateWAN == false or stateWAN6 == false then
               cb('network_interface_wan_off_wan6_off')
            end
        end
        if msg ~= nil and msg.interface ~= nil and msg.pppinfo ~= nil  and msg.pppinfo.pppstate ~= nil then
            cb('network_interface_' .. msg.interface:gsub('[^%a%d_]','_') .. '_ppp_' .. msg.pppinfo.pppstate:gsub('[^%a%d_]','_'))
        end
    end

    events['power'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
            cb('power_' .. msg.state)
        end
    end

    events['xdsl'] = function(msg)
        if msg ~= nil then
            cb('xdsl_' .. msg.statuscode)
        end
    end

    events['mmpbxbrcmdect.registered'] = function(msg)
        if msg ~= nil then
            cb('dect_registered_' .. tostring(msg.present))
        end
    end

    events['mmpbxbrcmdect.paging'] = function(msg)
        if msg ~= nil then
            if msg.alerting == true then
                cb('paging_alerting_true')
            else
                cb('paging_alerting_false')
            end
        end
    end

    events['wireless.wps_led'] = function(msg)
        if msg ~= nil and msg.wps_state ~= nil then
            cb('wifi_wps_' .. msg.wps_state)
        end
    end

    events['wireless.wlan_led'] = function(msg)
        if msg ~= nil then
            if msg.radio_oper_state == 1 and msg.bss_oper_state == 1 then
                if msg.acl_state ~= 1 then
                   cb("wifi_security_" .. msg.security .. "_" .. msg.ifname)
                end
            else
                cb("wifi_state_off_" .. msg.ifname)
            end
        end
    end

    events['infobutton'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
            cb("infobutton_state_" .. msg.state)
        end
    end

    events['statusled'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
            cb("status_" .. msg.state)
        end
    end

    events['fwupgrade'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
            cb("fwupgrade_state_" .. msg.state)
        end
    end

    events['event'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
            cb(msg.state)
        end
    end

    events['mmpbx.callstate'] = function(msg)
        if msg ~= nil and msg.profileType == "MMNETWORK_TYPE_SIP" then
            cb("callstate_" .. msg.reason .. "_" .. msg.device)
        end
    end

    events['mmbrcmfxs.callstate'] = function(msg)
        if msg ~= nil then
            if msg.fxs_dev_0 then
               if (msg.fxs_dev_0.activeLinesNumber > 0 )  then
                   cb('fxs_line1_active')
               else
                   cb('fxs_line1_inactive')
               end
            end
            if msg.fxs_dev_1 then
               if (msg.fxs_dev_1.activeLinesNumber > 0)  then
                   cb('fxs_line2_active')
               else
                   cb('fxs_line2_inactive')
               end
            end
        end
    end

        events['mmpbx.voiceled.status'] = function(msg)
        if msg ~= nil then
            if msg.fxs_dev_0 == "NOK" then
                cb('fxs_line1_error')
            elseif  msg.fxs_dev_0 == "OK-OFF" then
                cb('fxs_line1_off')
            elseif  msg.fxs_dev_0 == "IDLE" then
                cb('fxs_line1_idle')
            else
                cb('fxs_line1_usable')
            end
            if msg.fxs_dev_1 == "NOK" then
                cb('fxs_line2_error')
            elseif  msg.fxs_dev_1 == "OK-OFF" then
                cb('fxs_line2_off')
            elseif  msg.fxs_dev_1 == "IDLE" then
                cb('fxs_line2_idle')
            else
                cb('fxs_line2_usable')
            end
        end
    end

    events['mmpbx.dectled.status'] = function(msg)
        if msg ~= nil then
            if msg.dect_dev ~= nil then
                cb('dect_' .. msg.dect_dev)
            end
        end
    end

    events['mmpbx.ongoingcalls'] = function(msg)
        if msg ~= nil then
            for i=1, #msg  do
                if msg[i]["networkType"] == "MMNETWORK_TYPE_SIP" then
                    if msg[i]["number"]==0 then
                        cb('all_calls_ended')
                    else
                        cb('new_call_started')
                    end
                    break
                 end
            end
        end
    end

    events['mmpbx.profilestate'] = function(msg)
        if msg ~= nil and msg.voice == "NA@init_stop" then
            cb('profile_state_stop')
        end
    end

    conn:listen(events)

    --register for netlink events
    local nl,err = netlink.listen(function(dev, status)
        if status then
            cb('network_device_' .. dev .. '_up')
        else
            cb('network_device_' .. dev .. '_down')
        end
    end)
    if not nl then
        error("Failed to register with netlink" .. err)
    end

    uloop.run()
end

return M
