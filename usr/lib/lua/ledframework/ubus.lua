local ubus, uloop = require('ubus'), require('uloop')
local netlink = require("tch.netlink")
local format = string.format

local M = {}
local syslog = require("syslog")
syslog.openlog("ledfw", syslog.options.LOG_PID, syslog.facilities.LOG_DAEMON)

dect_led_support={
     ["dect_dev_0"] = 0,
     ["dect_dev_1"] = 0,
     ["dect_dev_2"] = 0,
     ["dect_dev_3"] = 0,
     ["dect_dev_4"] = 0,
     ["dect_dev_5"] = 0,

     line1 = {
          status = 0,
          key = 0,
          ["dect_dev_0"] = {msg_key = 0, msg_dev = 0},
          ["dect_dev_1"] = {msg_key = 0, msg_dev = 0},
          ["dect_dev_2"] = {msg_key = 0, msg_dev = 0},
          ["dect_dev_3"] = {msg_key = 0, msg_dev = 0},
          ["dect_dev_4"] = {msg_key = 0, msg_dev = 0},
          ["dect_dev_5"] = {msg_key = 0, msg_dev = 0},
     },
     line2 = {
          status = 0,
          key = 0,
          ["dect_dev_0"] = {msg_key = 0, msg_dev = 0},
          ["dect_dev_1"] = {msg_key = 0, msg_dev = 0},
          ["dect_dev_2"] = {msg_key = 0, msg_dev = 0},
          ["dect_dev_3"] = {msg_key = 0, msg_dev = 0},
          ["dect_dev_4"] = {msg_key = 0, msg_dev = 0},
          ["dect_dev_5"] = {msg_key = 0, msg_dev = 0},
     },
}

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

    events['qeo.power_led'] = function(msg)
        if msg ~= nil and msg.state ~= nil then
            cb('qeo_reg_' .. msg.state)
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

        if msg ~= nil and (msg.profileType == "MMNETWORK_TYPE_FXO" or msg.profileType == "MMNETWORK_TYPE_SIP") then

            if string.find(msg.device, "dect_dev") then
                local dev
                for k,v in pairs(dect_led_support) do
                    if type(k) ~= "tale" then
                        if msg.device == k then
                            dev = k
                            break
                        end
                    end
                end

                if nil == dev then return end

                if (msg.reason == 'MMPBX_CALLSTATE_ALERTING_REASON_INCOMINGCALL') or (msg.reason == 'MMPBX_CALLSTATE_CALL_DELIVERED_REASON_OUTGOINGCALL') then
                  --first check if the line exist.
                  local line = 0
                  for k,v in pairs(dect_led_support) do
                      if type(v) == "table" then
                           if msg.key == v.key then
                               line = v
                               break
                           end
                      end
                  end

                  if type(line) ~= "table" then
                      for k,v in pairs(dect_led_support) do
                          if type(v) == "table" then
                              if v.key == 0 then
                                  line = v
                                  v.key = msg.key
                              break
                              end
                          end
                      end
                  end

                  if type(line) == "table" then
                      for k,v in pairs(line) do
                          if type(v) == "table" then
                              if msg.device == k then
                                  v.msg_key = msg.key
                                  v.msg_dev = dev
                                  dect_led_support[dev] = dect_led_support[dev] + 1
                                  cb("callstate_" .. "MMPBX_CALLSTATE_ALERTING" .. "_" .. dev)
                              break
                              end
                          end
                      end
                  else
                     syslog.debug('should not be here. TODO clear and reset all of dect_led_support ' .. msg.key)
                  end
                end


                if(msg.reason == 'MMPBX_CALLSTATE_IDLE_REASON_CALL_ENDED') then
                    if msg.device == nil then
                        return
                    end
                    local msg_key = msg.key
                    --first find the line
                    local line = 0
                    for k,v in pairs(dect_led_support) do
                        if type(v) == "table" then
                            if msg_key == v.key then
                                line = v
                                break
                            end
                        end
                    end
                    if type(line) == "table" then
                        for k,v in pairs(line) do
                            if type(v) == "table" then
                                if (v.msg_dev == dev) and (v.msg_key == msg_key) then
                                    v.msg_key = 0
                                    v.msg_dev = 0
                                    dect_led_support[dev] = dect_led_support[dev] - 1
                                    if dect_led_support[dev] == 0 then
                                        cb("callstate_" .. "MMPBX_CALLSTATE_DISCONNECTED" .. "_" .. dev)
                                    end
                                    --if all of msg_key is 0, remark this line.key as 0
                                    for k,v in pairs(line) do
                                        if type(v) == "table" then
                                            if v.msg_key ~= 0 then
                                                return
                                            end
                                        end
                                    end
                                    -- set the line.key = 0 to remark this line is free.
                                    line.key = 0
                                    return
                                end
                            end
                        end

                        for k,v in pairs(line) do
                            --find the transfer device
                            local dev_transfer = 0
                            if type(v) == "table" then
                                if v.msg_key == msg_key then
                                    v.msg_key = 0
                                    v.msg_device = 0
                                    dect_led_support[k] = dect_led_support[k] - 1
                                    if dect_led_support[k] == 0 then
                                        cb("callstate_" .. "MMPBX_CALLSTATE_DISCONNECTED" .. "_" .. k)
                                    end
                                    --if all of msg_key is 0, remark this line.key as 0
                                    for k,v in pairs(line) do
                                        if type(v) == "table" then
                                            if v.msg_key ~= 0 then
                                                return
                                            end
                                        end
                                    end
                                    -- set the line.key = 0 to remark this line is free.
                                    line.key = 0
                                    return
                                end
                            end
                        end
                  else
                      syslog.debug('Should not be here,TODO  clear and reset all of dect_led_support!' .. msg.device)
                  end
               end
           end
        end
    end

    events['mmpbx.mediastate'] = function(msg)
        if msg and (msg.mediaState == "MMPBX_MEDIASTATE_NORMAL") then
            cb(format("mediastate_%s_%s", msg.mediaState, msg.device))
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
