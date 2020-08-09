local ubus, uloop, uci = require('ubus'), require('uloop'), require('uci')
local netlink = require("tch.netlink")
local format = string.format

local M = {}
local cursor = uci.cursor()

local wpsPairing = "off"
local dectPairing = "off"
local function processDectAndWpsPairing(cb, conn, pairingEvent)
    if pairingEvent == "dect_registering_unusable" or pairingEvent == "dect_registering_usable" then
        dectPairing = "inprogress"
        cb('pairing_inprogress')
    end
    if pairingEvent == "dect_unregistered_unusable" or pairingEvent == "dect_unregistered_usable" then
        dectPairing = "off"
        if wpsPairing == "off" then
            cb('pairing_off')
        end
    end
    if pairingEvent == "dect_registered_unusable" or pairingEvent == "dect_registered_usable" then
        if dectPairing == "inprogress" then
            local stop = wpsPairing
            wpsPairing = "off"
            dectPairing = "success"
            cb('pairing_success')
            if stop ~= "off" then
                conn:call("wireless.accesspoint.wps", "enrollee_pbc", { event = "stop" })
            end
        elseif wpsPairing == "off" then
            dectPairing = "success"
            cb('pairing_success')
        else
            dectPairing = "success"
        end
    end
    if pairingEvent == "wifi_wps_inprogress" then
        wpsPairing = "inprogress"
        cb('pairing_inprogress')
    end
    if pairingEvent == "wifi_wps_error" then
        if wpsPairing ~= "off" then
            wpsPairing = "error"
            cb('pairing_error')
        end
    end
    if pairingEvent == "wifi_wps_session_overlap" then
        if wpsPairing ~= "off" then
           wpsPairing = "overlap"
           cb('pairing_overlap')
        end
    end
    if pairingEvent == "wifi_wps_success" then
        if wpsPairing ~= "off" then
           local stop = dectPairing
           wpsPairing= "success"
           dectPairing = "off"
           cb('pairing_success')
           if stop ~= "off" then
               conn:call("mmpbxbrcmdect.registration", "close", {})
           end
        end
    end
    if pairingEvent == "wifi_wps_off" then
        wpsPairing= "off"
        if dectPairing == "off" then
           cb('pairing_off')
        elseif dectPairing == "success" then
           cb('pairing_success')
        end
    end

    return 0
end

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
                local InfoWWAN = conn:call("network.interface.wwan", "status", {})
                local stateWWAN = InfoWWAN and InfoWWAN.up
                if stateWWAN == true then
                    cb('network_interface_wwan_ifup')
                else
                    cb('network_interface_wan_off_wan6_off')
                end
            end
        end
        if msg ~= nil and msg.interface ~= nil and msg.pppinfo ~= nil  and msg.pppinfo.pppstate ~= nil then
            cb('network_interface_' .. msg.interface:gsub('[^%a%d_]','_') .. '_ppp_' .. msg.pppinfo.pppstate:gsub('[^%a%d_]','_'))
        end
    end

    events['network.link'] = function(msg)
        if msg ~=nil and msg.interface == "eth4" and msg.action == "down" then
            local device = conn:call("network.device", "status", { name = "eth4" })
            if device and device.carrier == false then
                cb('network_device_eth4_linkdown')
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

--Prepare for later use (Thermal_Overheated)
    events['thermalProtection'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
            cb('thermalProtection_' .. msg.state)
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
        if msg ~= nil and msg.wps_state ~= nil then
            local pairingEvent = 'wifi_wps_' .. msg.wps_state
            processDectAndWpsPairing(cb, conn, pairingEvent)
        end
    end

    events['qeo.power_led'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
            cb('qeo_reg_' .. msg.state)
        end
    end

    events['wireless.wlan_led'] = function(msg)
        if msg ~= nil then
            if msg.radio_admin_state == 1 and msg.radio_oper_state == 1 and msg.bss_admin_state == 1 and msg.bss_oper_state == 1 then
                if msg.acl_state == 1 then
                   cb("wifi_acl_on_" .. msg.ifname)
                else
                   cb("wifi_acl_off_" .. msg.ifname)
                   cb("wifi_security_" .. msg.security .. "_" .. msg.ifname)
                   cb("wifi_state_on_" .. msg.ifname)
                   if msg.sta_connected == 0 then
                      cb("wifi_no_sta_con_" .. msg.ifname)
                   else
                      cb("wifi_sta_con_" .. msg.ifname)
                   end
                end
            else
                cb("wifi_state_off_" .. msg.ifname)
                local wls = {}
                cursor:foreach("wireless", "wifi-iface", function(s)
                    local name = s['.name']
                    if string.match(name, "wl%d$") and (s.device == "radio_5G" or s.device == "radio_2G") then
                       wls[s.device] = name
                    end
                end)

                local aps = {}
                cursor:foreach("wireless", "wifi-ap", function(s)
                    local name = s['.name']
                    if string.match(name, "ap%d") and string.match(s.iface,"wl%d$")then
                       aps[s.iface]=name
                    end
                end)
                local radio_state, ap_state
                local ap_data1 = {}
                local radio_data1 = {}
                if msg.ifname == wls.radio_2G and wls.radio_5G and aps[wls.radio_5G] then
                   local ap_5G = aps[wls.radio_5G]
                   local ap_data = conn:call("wireless.accesspoint", "get", { name = ap_5G})
                   local radio_data = conn:call("wireless.radio", "get", { name = "radio_5G" })
                   radio_data1 = radio_data and radio_data.radio_5G
                   ap_data1 = ap_data and ap_data[ap_5G]
                elseif msg.ifname == wls.radio_5G and wls.radio_2G and aps[wls.radio_2G] then
                   local ap_2G = aps[wls.radio_2G]
                   local ap_data = conn:call("wireless.accesspoint", "get", { name = ap_2G })
                   local radio_data = conn:call("wireless.radio", "get", { name = "radio_2G" })
                   ap_data1 = ap_data and ap_data[ap_2G]
                   radio_data1 = radio_data and radio_data.radio_2G
                end
                ap_state = ap_data1 and ap_data1.oper_state
                radio_state = radio_data1 and radio_data1.oper_state
                if ap_state == 0 or radio_state == 0 then
                   cb("wifi_state_wl0_off_wl1_off")
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
            cb("callstate_" .. msg.reason .. "_" .. msg.device)
        end
    end

    events['mmpbx.mediastate'] = function(msg)
        if msg and (msg.mediaState == "MMPBX_MEDIASTATE_NORMAL") then
            cb(format("mediastate_%s_%s", msg.mediaState, msg.device))
	end
    end

    events['mmpbx.profile.status'] = function(msg)
        if msg ~= nil and msg.enabled == "1" then
              if (msg.sip.newest.registered == "Unregistered") then
                 cb('profile_register_unregistered')
              elseif (msg.sip.newest.registered == "Registered") then
                 cb('profile_register_registered')
              elseif (msg.sip.newest.registered == "Registering") then
                 cb('profile_register_registering')
              end
           end
        end

    events['mmpbx.voiceled.status'] = function(msg)
        if msg ~= nil then
            local sip_profile_usable = false
            local mmpbx_profiles = conn:call("mmpbx.profile", "get", {})
            cursor:load("mmpbxrvsipnet")
            cursor:foreach("mmpbxrvsipnet", "profile", function(s)
                if s['enabled'] == "1" then
                    sip_profile_usable = (mmpbx_profiles and mmpbx_profiles[s['.name']] and mmpbx_profiles[s['.name']].usable == "true") or false
                    if sip_profile_usable then
                        return false -- break
                end
            end
            end)
            if sip_profile_usable == false then
				cursor:load("mmpbxmobilenet")
				cursor:foreach("mmpbxmobilenet", "profile", function(s)
					if s['enabled'] == "1" then
						if (msg.fxs_dev_0 == "OK-ON" or msg.fxs_dev_1 == "OK-ON") then
							cb('profile_register_registered')
						elseif (msg.fxs_dev_0 == "OK-EMERGENCY" or msg.fxs_dev_1 == "OK-EMERGENCY") then
							cb('profile_register_emergency')
						elseif (msg.fxs_dev_0 == "IDLE" or msg.fxs_dev_1 == "IDLE") then
							cb('profile_register_registering')
						else
							cb('profile_register_unregistered')
						end
					end
				end)
        	end
    	end
    end

    events['mmpbx.dectled.status'] = function(msg)
        if msg ~= nil then
            if msg.dect_dev ~= nil then
                local pairingEvent = 'dect_' .. msg.dect_dev
                processDectAndWpsPairing(cb, conn, pairingEvent)
            end
        end
    end

    events['mmpbx.ongoingcalls'] = function(msg)
        if msg ~= nil then
            local flag = 0
            for i=1, #msg  do
                if msg[i]["networkType"] == "MMNETWORK_TYPE_SIP" or msg[i]["networkType"] == "MMNETWORK_TYPE_MOBILE" then
                    if msg[i]["number"] ~= 0 then
                        flag = 1
                        break
                    end
                end
            end
            if flag == 0 then
                cb('all_calls_ended')
            else
                cb('new_call_started')
            end
        end
    end

    events['mmpbx.profilestate'] = function(msg)
        if msg ~= nil and msg.voice == "NA@init_stop" then
            cb('profile_state_stop')
        end
    end

    events['mobiled.leds'] = function(msg)
        if msg and msg.radio ~= '' and msg.bars then
            cb("mobile_bars" .. msg.bars)
        else
        cb("mobile_off")
    end
    end

    events['mobiled'] = function(msg)
        if type(msg) == "table" then
            if msg.event == "firmware_upgrade_started" then
                cb("mobile_firmware_upgrade_started")
            elseif msg.event == "firmware_upgrade_done" then
                cb("mobile_firmware_upgrade_done")
            elseif msg.event == "device_removed" then
                cb("mobile_off")
            elseif msg.event == "sim_removed" then
                cb("network_interface_wwan_ifdown")
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
