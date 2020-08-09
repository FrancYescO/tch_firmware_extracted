local popen = io.popen
local find = string.find
local ubus, uloop, uci = require('ubus'), require('uloop'), require('uci')
local format = string.format
local match  = string.match
local M = {}
local cursor = uci.cursor()

local cycle_counter = 0
local MAX_NUM_COLOR = 5
local cycle_led_colors= {"red", "blue", "green", "white", "orange" }
local cycle_led_conn = ubus.connect()
if not cycle_led_conn then
    error("Failed to connect to ubusd")
end

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

local function rtfd_cycle_led()
    local color = math.fmod(cycle_counter, MAX_NUM_COLOR)
    cycle_counter = cycle_counter + 1

    cycle_led_conn:send("cycle_led", {color = cycle_led_colors[color + 1]})

    local timer = uloop.timer(rtfd_cycle_led)
    timer:set(500)
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
            local InfoWWAN = {}
            local stateWAN
            local stateWAN6
            local stateWWAN
            if msg.action == "ifdown" then
                  InfoWAN6 = conn:call("network.interface.wan6", "status", {})
                  stateWAN6 = InfoWAN6.up
                  InfoWAN = conn:call("network.interface.wan", "status", {})
                  stateWAN = InfoWAN.up
                  InfoWWAN = conn:call("network.interface.wwan", "status", {})
                  stateWWAN = InfoWWAN.up
            end
            if stateWAN == false and stateWAN6 == false  and stateWWAN == false then
                cb('network_interface_wan_off_wan6_off_wwan_off')
            end
            if stateWAN == false and stateWAN6 == false then
                cb('network_interface_wan_off_wan6_off')
            end
        end
        if msg ~= nil and msg.interface ~= nil and msg.pppinfo ~= nil  and msg.pppinfo.pppstate ~= nil then
            if msg.pppinfo.pppstate:gsub('[^%a%d_]','_') == "disconnecting" then
                cb('network_interface_' .. msg.interface:gsub('[^%a%d_]','_') .. '_' .. 'authfailed')
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

    events['network.link'] = function(msg)
        cursor:load("network")
        local lanIntfList = cursor:get("network", "lan", "ifname")
        if type(lanIntfList) == "table" then
           lanIntfList = table.concat(lanIntfList)
        end
        cursor:unload("network")
        if find(lanIntfList,"eth4") ~= nil then
           if msg ~=nil and msg.interface ~=nil and (msg.interface == "eth4" or msg.interface == "ptm0" or msg.interface == "atm_8_35") then
              if msg.action == "up" then
                 cb('bridge_wan_connected')
              else
                 cb('bridge_wan_disconnected')
              end
           end
        end
    end

--Prepare for later use (Thermal_Overheated)
    events['thermalProtection'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
            cb('thermalProtection_' .. msg.state)
            local InfoWAN = {}
            local InfoWAN6 = {}
            local InfoWWAN = {}
            local stateWAN
            local stateWAN6
            local stateWWAN
            cursor:load("network")
            local lanIntfList = cursor:get("network", "lan", "ifname")
            if type(lanIntfList) == "table" then
               lanIntfList = table.concat(lanIntfList)
            end
            cursor:unload("network")
            if find(lanIntfList,"eth4") == nil and msg.state == "operational" then
                InfoWAN6 = conn:call("network.interface.wan6", "status", {})
                stateWAN6 = InfoWAN6.up
                InfoWAN = conn:call("network.interface.wan", "status", {})
                stateWAN = InfoWAN.up
                InfoWWAN = conn:call("network.interface.wwan", "status", {})
                stateWWAN = InfoWWAN.up
                if stateWAN6 == true or stateWAN == true then
                   cb('thermalProtection_operational_fixed_online')
                elseif stateWWAN == true then
                   cb('thermalProtection_operational_mobiled_online')
                elseif stateWAN6 == false and stateWAN == false and stateWWAN == false then
                   cb('thermalProtection_operational_connection_failed')
                end
            elseif find(lanIntfList,"eth4") ~= nil and msg.state == "operational" then
                local tmpfile1 = popen("cat /sys/class/net/ptm0/operstate")
                local ptm0State = tmpfile1:read("*l")
                tmpfile1:close()
                local tmpfile2 = popen("cat /sys/class/net/eth4/operstate")
                local eth4State = tmpfile2:read("*l")
                tmpfile2:close()
                local tmpfile3 = popen("cat /sys/class/net/atm_8_35/operstate")
                local atmState = tmpfile3:read("*l")
                tmpfile3:close()
                if ptm0State == "up" or eth4State == "up" or atmState == "up" then
                   cb('bridge_wan_connected')
                else
                   cb('bridge_wan_disconnected')
                end
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

    events['mmpbx.outgoingcallstart'] = function(msg)
        if msg ~= nil and msg.device ~= nil then
            cb('new_call_started')
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

    events['led.brightness'] = function(msg)
        if msg and msg.updated == "1" then
            cb("led_brightness_changed")
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
                if msg[i]["networkType"] == "MMNETWORK_TYPE_SIP" or msg[i]["networkType"] == "MMNETWORK_TYPE_MOBILE" or msg[i]["networkType"] == "MMNETWORK_TYPE_FXO" then
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
    events['mmpbxbrcmfxo.usable'] = function(msg)
        if msg ~= nil and msg.usable == "true" then
            cb('pstnline_linked')
        elseif msg ~= nil and msg.usable == "false" then
            cb('pstnline_nolink')
        end
    end

    events['mobiled.leds'] = function(msg)
        if msg and msg.radio and msg.bars then
            cb("mobile_bars" .. msg.bars)
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

    events['wwan.state'] = function(msg)
        if msg ~= nil and msg.status == "unavailable" then
            cb("network_interface_wwan_unavailable")
        end
    end
    events['Layer2.wansensing'] = function(msg)
        if msg ~= nil and msg.status == "starting" then
            cb("Layer2_wansensing_starting")
        end
    end
    events['sys.rtfd'] = function(msg)
        if msg ~= nil then
            rtfd_cycle_led()
        end
    end
    events['cycle_led'] = function(msg)
        if msg ~= nil and msg.color ~= '' then
            cb("rtfd_cycle_led_" .. msg.color)
        end
    end
    conn:listen(events)
    uloop.run()
end

return M

