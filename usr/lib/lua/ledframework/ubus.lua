local ubus, uloop = require('ubus'), require('uloop')
local netlink = require("tch.netlink")

local M = {}

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

    events['gpon.ploam'] = function(msg)
        if msg ~= nil and msg.statuscode ~= nil then
			if msg.statuscode ~= 5 then
            	cb('gpon_ploam_' .. msg.statuscode)
			else
            	cb('gpon_ploam_50')
        	end

        end
    end

    events['gpon.omciport'] = function(msg)
        if msg ~= nil and msg.statuscode ~= nil then
            cb('gpon_ploam_' .. 5 .. msg.statuscode)
        end
    end


    events['gpon.rfo'] = function(msg)
        if msg ~= nil and msg.statuscode ~= nil then
            cb('gpon_rfo_' .. msg.statuscode)
        end
    end

    events['voice'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
            cb('voice_' .. msg.state)
        end
    end

    events['mmpbx.devicelight'] = function(msg)
        if msg ~= nil and msg.fxs_dev_0 ~= nil then
            cb('voice1_' .. msg.fxs_dev_0)
        end
        if msg ~= nil and msg.fxs_dev_1 ~= nil then
            cb('voice2_' .. msg.fxs_dev_1)
        end
    end

    events['mmpbxbrcmdect.registration'] = function(msg)
        if msg ~= nil then
            cb('dect_registration_' .. tostring(msg.open))
        end
    end

    events['mmpbxbrcmdect.registered'] = function(msg)
        if msg ~= nil then
            cb('dect_registered_' .. tostring(msg.present))
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
                cb("wifi_security_" .. msg.security .. "_" .. msg.ifname)
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
        if msg ~= nil and msg.profileType == "MMNETWORK_TYPE_SIP" and msg.profileUsable == true then
            cb("callstate_" .. msg.reason .. "_" .. msg.device)
        end
    end

    events['mmpbx.profilestate'] = function(msg)
        if msg ~= nil then
            if msg.fxs_dev_0 == "true" then
                cb('profile_line1_usable_true')
            else
                cb('profile_line1_usable_false')
            end
            if msg.fxs_dev_1 == "true" then
                cb('profile_line2_usable_true')
            else
                cb('profile_line2_usable_false')
            end

            if (msg.fxs_dev_0 ~= "" and msg.fxs_dev_1 ~= "") then
               if (msg.fxs_dev_0 == "true" and msg.fxs_dev_1 == "true") then
                   cb('fxs_profiles_usable_true')
               else
                   cb('fxs_profiles_usable_false')
               end
            elseif (msg.fxs_dev_0 == "" and msg.fxs_dev_1 ~= "") then
                if (msg.fxs_dev_1 == "true") then
                    cb('fxs_profiles_usable_true')
                else
                    cb('fxs_profiles_usable_false')
                end
            elseif (msg.fxs_dev_1 == "" and msg.fxs_dev_0 ~= "") then
                if (msg.fxs_dev_0 == "true") then
                    cb('fxs_profiles_usable_true')
                else
                    cb('fxs_profiles_usable_false')
                end
            else
                cb('fxs_profiles_usable_false')
            end
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
