local ubus, uloop, uci = require('ubus'), require('uloop'), require('uci')
local netlink = require("tch.netlink")
local format = string.format
--local dbg = io.open("/tmp/sle.txt", "w") -- "a" for full logging

local M = {}
local cursor = uci.cursor()
local voipcall = { 
    callnum = 0,
    call0 = {key = 0, fxs0 = false, fxs1 = false},
    call1 = {key = 0, fxs0 = false, fxs1 = false},
    call2 = {key = 0, fxs0 = false, fxs1 = false},
    call3 = {key = 0, fxs0 = false, fxs1 = false},
    call4 = {key = 0, fxs0 = false, fxs1 = false},
    call5 = {key = 0, fxs0 = false, fxs1 = false},
}
local fxs0PfEn = false
local fxs1PfEn = false

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
               cursor:load("network")
               local mgmtifn = cursor:get("network", "mgmt", "ifname")
               if mgmtifn ~= nil then -- ignore wan interface event when mgmt is configured
                   if msg.interface:match("wan") == nil then
                       cb('network_interface_' .. msg.interface:gsub('[^%a%d_]','_') .. '_' .. msg.action:gsub('[^%a%d_]','_'))
                   end
               else
                   cb('network_interface_' .. msg.interface:gsub('[^%a%d_]','_') .. '_' .. msg.action:gsub('[^%a%d_]','_'))
               end
            end
            if msg.interface:match('^wan6?$') ~= nil then
               if (msg['ipv4-address'] ~= nil or msg['ipv6-address'] ~= nil) then 
                  if (msg['ipv4-address'] == nil or msg['ipv4-address'][1] == nil) and (msg['ipv6-address'] == nil or msg['ipv6-address'][1]== nil) then
                     cb('network_interface_' .. msg.interface .. '_no_ip')
                  end
               end
            end
            if msg.pppinfo ~= nil  and msg.pppinfo.pppstate ~= nil then
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
            if ((msg.DECT1.activeLinesNumber == 1) or
                (msg.DECT2.activeLinesNumber == 1) or
                (msg.DECT3.activeLinesNumber == 1) or
                (msg.DECT4.activeLinesNumber == 1) or
                (msg.DECT5.activeLinesNumber == 1) or
                (msg.DECT6.activeLinesNumber == 1)) then
                cb('dect_active')
            else
                cb('dect_inactive')
            end
        end
    end

    events['wireless.wps_led'] = function(msg)
        if msg ~= nil and msg.wps_state ~= nil then
            cb('wifi_wps_' .. msg.wps_state)
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
                if msg.acl_state == 1 then
                   cb("wifi_acl_on_" .. msg.ifname)
                else
                   cb("wifi_acl_off_" .. msg.ifname)
                   cb("wifi_security_" .. msg.security .. "_" .. msg.ifname)
                   if msg.sta_connected == 0 then
                      cb("wifi_no_sta_con_" .. msg.ifname)
                   else
                      cb("wifi_sta_con_" .. msg.ifname)
                   end
                end
            else
                if msg.radio_oper_state == 0 and msg.bss_oper_state == 0 then
                   cb("wifi_state_off_" .. msg.ifname)
                end
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
        if msg ~= nil and msg.profileType == "MMNETWORK_TYPE_SIP" and msg.profileUsable == true then
            local newcall = true
            if (msg.reason == 'MMPBX_CALLSTATE_ALERTING_REASON_INCOMINGCALL') or (msg.reason == 'MMPBX_CALLSTATE_CALL_DELIVERED_REASON_OUTGOINGCALL') or (msg.reason == 'MMPBX_CALLSTATE_CONNECTED_REASON_LOCALCONNECT') or (msg.reason == 'MMPBX_CALLSTATE_CONNECTED_REASON_REMOTECONNECT') then
                for k, v in pairs(voipcall) do
                    if type(v) == "table" and msg.key == v.key then
                        if msg.device == "fxs_dev_0" and v.fxs0 == false then
                            v.fxs0 = true
                        elseif msg.device == "fxs_dev_1" and v.fxs1 == false then
                            v.fxs1 = true
                        end
                        newcall = false
                        break
                    end
                end

                if newcall == true then
                    for k, v in pairs(voipcall) do
                        if type(v) == "table" and v.key == 0 then
                            v.key = msg.key
                            if msg.device == "fxs_dev_0" and v.fxs0 == false then
                                v.fxs0 = true
                            elseif msg.device == "fxs_dev_1" and v.fxs1 == false then
                                v.fxs1 = true
                            end

                            voipcall.callnum = voipcall.callnum + 1
                            cb("callstate_" .. "MMPBX_CALLSTATE_HAS_CALL")
                            break
                        end
                    end
                end
            elseif (msg.reason == 'MMPBX_CALLSTATE_IDLE_REASON_CALL_ENDED') then
                for k, v in pairs(voipcall) do
                    if type(v) == "table" and msg.key == v.key then
                        if msg.device == "fxs_dev_0" and v.fxs0 == true then
                            v.fxs0 = false
                        elseif msg.device == "fxs_dev_1" and v.fxs1 == true then
                            v.fxs1 = false
                        end
                        if v.fxs0 == false and v.fxs1 == false then
                            v.key = 0
                            voipcall.callnum = voipcall.callnum - 1
                            if voipcall.callnum == 0 then
                                cb("callstate_" .. "MMPBX_CALLSTATE_NO_CALL")
                            end
                        end
                        break
                    end
                end
            end --elseif
        end --msg~=nil
    end

    events['mmpbx.mediastate'] = function(msg)
        if msg and (msg.mediaState == "MMPBX_MEDIASTATE_NORMAL") then
            cb(format("mediastate_%s_%s", msg.mediaState, msg.device))
	end
    end

    events['mmbrcmfxs.profile.status'] = function(msg)
        if msg~=nil then
            if (msg.fxs_dev_0.profileEnabled == "true") then
                fxs0PfEn = true
            else
                fxs0PfEn = false
            end
            if (msg.fxs_dev_1.profileEnabled == "true") then
                fxs1PfEn = true
            else
                fxs1PfEn = false
            end
        end
    end

    events['mmpbx.profile.status'] = function(msg)
        if msg~=nil then
           if msg.enabled=="1" then
              if (msg.name == "sip_profile_1") and (msg.sip.newest.registered == "Unregistered") then
                 cb('profile_line1_unusable_true')
              end
              if (msg.name == "sip_profile_2") and (msg.sip.newest.registered == "Unregistered") then
                 cb('profile_line2_unusable_true')
              end
              if (msg.name == "sip_profile_1") and (msg.sip.newest.registered == "Registered") then
                 cb('profile_line1_unusable_false')
              end
              if (msg.name == "sip_profile_2") and (msg.sip.newest.registered == "Registered") then
                 cb('profile_line2_unusable_false')
              end
           end
        end
    end
    events['mmpbx.voiceled.status'] = function(msg)
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
               if ((msg.fxs_dev_0 == "true" and msg.fxs_dev_1 == "true") or (fxs0PfEn == false and msg.fxs_dev_1 == "true") or (fxs1PfEn == false and msg.fxs_dev_0 == "true")) then
                   cb('fxs_profiles_usable_true')
               else
                   cb('fxs_profiles_usable_false')
               end
            elseif ((msg.fxs_dev_0 == "" and msg.fxs_dev_1 == "true") or (msg.fxs_dev_0 == "true" and msg.fxs_dev_1 == "")) then
                cb('fxs_profiles_usable_true')
            elseif ((msg.fxs_dev_0 == "true" and msg.fxs_dev_1 == nil) or (msg.fxs_dev_0 == nil and msg.fxs_dev_1 == "true")) then
                cb('fxs_profiles_usable_true')
            else
                cb('fxs_profiles_usable_false')
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
