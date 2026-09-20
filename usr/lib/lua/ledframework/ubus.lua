local ubus, uloop = require('ubus'), require('uloop')
local netlink = require("tch.netlink")
local format = string.format
local match = string.match
local posix = require("tch.posix")
local openlog = posix.openlog
local syslog = posix.syslog

local M = {}

openlog("ledfw", posix.LOG_PID, posix.LOG_DAEMON)

function M.start(cb)
    uloop.init()
    local conn = ubus.connect()
    if not conn then
        error("Failed to connect to ubusd")
    end

    local events = {}
    events['network.interface'] = function(msg)
        if msg ~= nil and msg.interface ~= nil then
            if msg.action ~= nil then
--             syslog(posix.LOG_DEBUG,'callback -> ' .. 'network_interface_' .. msg.interface:gsub('[^%a%d_]','_') .. '_' .. msg.action:gsub('[^%a%d_]','_'))
               cb('network_interface_' .. msg.interface:gsub('[^%a%d_]','_') .. '_' .. msg.action:gsub('[^%a%d_]','_'))
            end
            if msg.interface:match('^wan6?$') ~= nil then
               if (msg['ipv4-address'] ~= nil or msg['ipv6-address'] ~= nil) then
                  if (msg['ipv4-address'] == nil or msg['ipv4-address'][1] == nil) and (msg['ipv6-address'] == nil or msg['ipv6-address'][1]== nil) then
--                   syslog(posix.LOG_DEBUG,'callback -> ' .. 'network_interface_' .. msg.interface .. '_no_ip')
                     cb('network_interface_' .. msg.interface .. '_no_ip')
                  end
               end
            end
            if msg.pppinfo ~= nil  and msg.pppinfo.pppstate ~= nil then
--	       syslog(posix.LOG_DEBUG,'callback -> ' .. 'network_interface_' .. msg.interface:gsub('[^%a%d_]','_') .. '_ppp_' .. msg.pppinfo.pppstate:gsub('[^%a%d_]','_'))
               cb('network_interface_' .. msg.interface:gsub('[^%a%d_]','_') .. '_ppp_' .. msg.pppinfo.pppstate:gsub('[^%a%d_]','_'))
            end
        end
    end

    events['network.mproxy'] = function(msg)
        if msg ~=nil and msg.state ~=nil then
            if msg.state == "started" then
               cb('mptcp_on')
            elseif msg.state == "stopped" then
               cb('mptcp_off')
            end
        end
    end

    events['network.lte_backup'] = function(msg)
        if msg ~=nil and msg.state ~=nil then
            if msg.state == "enabled" then
               cb('backup_on')
            elseif msg.state == "disabled" then
               cb('backup_off')
            end
        end
    end

--Prepare for later use (PXM and MPTCP)
    events['network.neigh'] = function(msg)
        if msg ~=nil and msg.interface ~=nil and msg.interface == "eth4" then
            if msg.action == "add" then
--               cb('net_neigh_dummy')
            end
        end
    end

    events['hostmanager.devicechanged'] = function(msg)
        if msg ~=nil and msg.l3interface ~=nil and msg.l3interface == "vlan_voip_mgmt" then
            if msg.state == "disconnected" then
--               cb('hostman_voip_down')
            end
        end
    end

    events['power'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
            cb('power_' .. msg.state)
        end
    end

    events['xdsl'] = function(msg)
        if msg ~= nil then
--	    syslog(posix.LOG_DEBUG,'callback -> ' .. 'xdsl_' .. msg.statuscode)
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

    events['usb.usb_led'] = function(msg)
        if msg ~= nil and msg.status ~= nil then
            cb('usb_led_' .. msg.status)
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

    events['mmpbxbrcmdect.paging'] = function(msg)
        if msg ~= nil then
            if msg.alerting == true then
                cb('paging_alerting_true')
            else
                cb('paging_alerting_false')
            end
        end
    end

    events['mmpbxbrcmdect.callstate'] = function(msg)
        if msg ~= nil then
            if ((msg.dect_dev_0.activeLinesNumber == 1) or
                (msg.dect_dev_1.activeLinesNumber == 1) or
                (msg.dect_dev_2.activeLinesNumber == 1) or
                (msg.dect_dev_3.activeLinesNumber == 1) or
                (msg.dect_dev_4.activeLinesNumber == 1) or
                (msg.dect_dev_5.activeLinesNumber == 1)) then
                cb('dect_active')
            else
                cb('dect_inactive')
            end
        end
    end

    events['wireless.wps_led'] = function(msg)
        if msg ~= nil and msg.wps_state ~= nil and msg.ifname then
            local ifname=msg.ifname:match('^wl[01]')
            if ifname then
--	           syslog(posix.LOG_DEBUG,'callback -> ' .. 'wifi_wps_' .. ifname .. '_' .. msg.wps_state)
               cb('wifi_wps_' .. ifname .. '_' .. msg.wps_state)
            end
        end
    end

    events['qeo.power_led'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
            cb('qeo_reg_' .. msg.state)
        end
    end

    events['wireless.wlan_led'] = function(msg)
        if msg ~= nil then
            if msg.radio_oper_state == 1 and msg.bss_oper_state == 1 then
--             syslog(posix.LOG_DEBUG,'callback -> ' .. 'wifi_on_' .. msg.ifname)
               cb("wifi_on_" .. msg.ifname)
            elseif msg.radio_oper_state == 0 and msg.bss_oper_state == 0 then
--             syslog(posix.LOG_DEBUG,'callback -> ' .. 'wifi_off_' .. msg.ifname)
               cb("wifi_off_" .. msg.ifname)
            end
        end
    end

    events['wifitod'] = function(msg)
        if msg ~= nil then
            syslog(posix.LOG_DEBUG,'callback -> ' .. msg.event)
            cb(msg.event)
        end
    end

    events['infobutton'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
            cb("infobutton_state_" .. msg.state)
        end
    end

    events['statusled'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
--	    syslog(posix.LOG_DEBUG,'callback -> ' .. 'status_' .. msg.state)
            cb("status_" .. msg.state)
        end
    end

    events['fwupgrade'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
            if msg.state == "failed" then
                syslog(posix.LOG_DEBUG,'event: fwupgrade_state_' .. msg.state .. ' callback -> fwupgrade_state_done')
                cb("fwupgrade_state_done")
            else
                syslog(posix.LOG_DEBUG,'callback -> ' .. 'fwupgrade_state_' .. msg.state)
                cb("fwupgrade_state_" .. msg.state)
            end
        end
    end

    events['resetbutton'] = function(msg)
	if msg ~= nil and msg.state ~= nil then
--	    syslog(posix.LOG_DEBUG,'callback -> ' .. 'reset_button_' .. msg.state)
	    cb("reset_button_" .. msg.state)
	end
    end

    events['mobiled'] = function(msg)
        if msg ~= nil then
            local radio = {}
            if msg.event == "device_connected" then
                -- syslog(posix.LOG_DEBUG,'Mobile LED callback -> ' .. 'mobile_on')
                device_plugged = 1
                -- cb("mobile_on")
            elseif msg.event == "device_added" then
                -- syslog(posix.LOG_DEBUG,'Mobile LED callback -> ' .. 'mobile_on')
                cb("mobile_on")
            elseif msg.event == "device_removed" then
                -- syslog(posix.LOG_DEBUG,'Mobile LED callback -> ' .. 'mobile_device_disconnected' .. msg.event)
                cb("mobile_device_disconnected")
            elseif msg.event == "session_state_changed" then
                if msg.session_state ~= nil then
                    if msg.session_state == "disconnected" then
                        -- syslog(posix.LOG_DEBUG,'Mobile LED callback -> ' .. 'mobile_session_' .. msg.session_state)
                        cb("mobile_session_" .. msg.session_state)
                    else
                        -- Use the UBUS Mobiled radio interface parameter to find the network(3g/4g/gprs)
                        radio = conn:call("mobiled.radio", "signal_quality", {})
                        if radio ~= nil and radio.radio_interface ~= nil then
                            -- syslog(posix.LOG_DEBUG,'Mobile LED callback -> ' .. 'mobile_session_' .. msg.session_state .. "_" .. radio.radio_interface)
                            cb("mobile_session_" .. msg.session_state .. "_" .. radio.radio_interface)
                        end
                    end
                end
            elseif msg.event == "call_state_changed" then
                if msg.call_state ~= nil then
                    -- Use the UBUS Mobiled radio interface parameter to find the network(3g/4g/gprs)
                    radio = conn:call("mobiled.radio", "signal_quality", {})
                    if radio ~= nil and radio.radio_interface ~= nil then
                        -- syslog(posix.LOG_DEBUG,'Mobile LED callback -> ' .. 'mobile_voice_' .. msg.call_state .. "_" .. radio.radio_interface)
                        cb('mobile_voice_' .. msg.call_state .. '_' .. radio.radio_interface)
                    end
                end
            end
        end
    end

    events['mobiled.leds'] = function(msg)
        if msg ~= nil then
            if type(msg) == "table" then
                if msg.sim_state ~= nil then
                    -- syslog(posix.LOG_DEBUG,'Mobile LED callback -> ' .. 'mobile_sim_' .. msg.sim_state)
                    cb('mobile_sim_' .. msg.sim_state)
                end
            end
        end
    end

    events['event'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
            cb(msg.state)
        end
    end

    events['mmpbx.profile.status'] = function(msg)
        if msg ~= nil then
            if (msg.sip.newest.registered == "Registering") then
                cb("registration_ongoing")
            end
        end
    end

    events['mmpbx.callstate'] = function(msg)
        if msg ~= nil then
         if (msg.callState == 5) then
             if (msg.device == "fxs_dev_0") then
                  cb("ongoing_call_line_1")
             elseif (msg.device == "fxs_dev_1") then
                  cb("ongoing_call_line_2")
             end
             if (match(msg.device, "fxs_dev_")) then
                  cb("ongoing_call")
             end
         end
        end
    end

    events['mmpbx.outgoingcallstart'] = function(data)
        if data ~= nil then
            if (data.device == "fxs_dev_0") then
                cb("outgoing_call_line_1")
            elseif (data.device == "fxs_dev_1") then
                cb("outgoing_call_line_2")
            end
            if (match(data.device, "fxs_dev_")) then
                cb("outgoing_call")
            end
        end
    end

    events['mmpbx.incomingcallstart'] = function(data)
        if data ~= nil then
            if (data.device == "fxs_dev_0") then
                cb("incoming_call_line_1")
            elseif (data.device == "fxs_dev_1") then
                cb("incoming_call_line_2")
            end
            if (match(data.device, "fxs_dev_")) then
               cb("incoming_call")
            end
        end
    end

    events['mmpbx.mediastate'] = function(msg)
        if msg and (msg.mediaState == "MMPBX_MEDIASTATE_NORMAL") then
            cb(format("mediastate_%s_%s", msg.mediaState, msg.device))
	end
    end

    events['mmbrcmfxs.callstate'] = function(msg)
        if msg ~= nil then
            if (msg.fxs_dev_0 and msg.fxs_dev_0.activeLinesNumber > 0 )  then
                cb('fxs_line1_active')
            else
                cb('fxs_line1_inactive')
            end
            if (msg.fxs_dev_1 and msg.fxs_dev_1.activeLinesNumber > 0)  then
                cb('fxs_line2_active')
            else
                cb('fxs_line2_inactive')
            end
            if ((msg.fxs_dev_0 and msg.fxs_dev_0.activeLinesNumber > 0) or
                (msg.fxs_dev_1 and msg.fxs_dev_1.activeLinesNumber > 0)) then
                    cb('fxs_active')
            else
                cb('fxs_inactive')
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
            if ((msg.fxs_dev_0 == "NOK") or (msg.fxs_dev_1 == "NOK")) then
                 cb('fxs_lines_error')
             elseif ((msg.fxs_dev_0 == "OK-OFF" and msg.fxs_dev_1 == "OK-OFF") or (msg.fxs_dev_0 == "OK-OFF" and msg.fxs_dev_1 == nil) or (msg.fxs_dev_1 == "OK-OFF" and msg.fxs_dev_0 == nil)) then
               cb('fxs_lines_usable_off')
             elseif msg.fxs_dev_0 == "IDLE" then
               cb('fxs_lines_usable_idle')
            else
               cb('fxs_lines_usable')
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
