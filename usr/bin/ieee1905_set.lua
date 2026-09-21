-------------- COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE -------------
-- Copyright (c) [2019] – [Technicolor Delivery Technologies, SAS]          -
-- All Rights Reserved                                                      -
-- The source code form of this Open Source Project components              -
-- is subject to the terms of the BSD-2-Clause-Patent.                      -
-- You can redistribute it and/or modify it under the terms of              -
-- the BSD-2-Clause-Patent. (https://opensource.org/licenses/BSDplusPatent) -
-- See COPYING file/LICENSE file for more details.                          -
-----------------------------------------------------------------------------

local ubus = require("libubus_map_tch")
local proxy = require("datamodel")
local json = require ("dkjson")
local uci = require("uci")
local format = string.format

function get_ap_from_if(if_name)
    local ap
    cursor = uci.cursor()
    cursor:foreach("wireless", "wifi-ap", function(s)
         for key, value in pairs(s) do
                 if value == if_name then
                     ap = s[".name"]
                 end
         end
    end)
    cursor:close()
    return ap
end

function set_controller_link_name (if_name)
    local cursor = uci.cursor()

    if if_name ~= nil then
        local config, section = "multiap", "agent"
        cursor:set(config,section,"backhaul_link",if_name)
        cursor:commit(config)
    end

    cursor:close()
    return nil
end

function set_wifi_params(data_str)

    local ssid, passwd, if_name, ssid_path, passwd_path, ap, old_ssid, old_password, flag, auth_type, old_auth, auth_type_path
    local fronthaul_path, backhaul_path, old_fronthaul, old_backhaul, fronthaul, backhaul

    fronthaul = nil 
    backhaul  = nil

    flag = 0

    if (data_str == nil) then
        print("Input Data is NULL")
        return nil
    end

    local data = json.decode(data_str)

    if (type(data) == "table") then
        ssid = data["ssid"]
        passwd = data["passwd"]
        if_name = data["interface"]
	auth_type = data["auth_type"]
        fronthaul = data["fronthaul_bit"]
        backhaul = data["backhaul_bit"]

    end

    if ((if_name ~= nil) and (passwd ~= nil) and (if_name ~= nil)) then
        if_name = if_name:gsub(" ","")
        ssid_path = format ('rpc.wireless.ssid.@%s.ssid', if_name)
        old_ssid = proxy.get(ssid_path)[1].value

        if (old_ssid ~= ssid) then
            print("Changing ssid...")
            proxy.set(ssid_path,ssid)
            flag = 1
        end

        ap = get_ap_from_if(if_name)
        passwd_path = format ('rpc.wireless.ap.@%s.security.wpa_psk_passphrase',ap)
        old_passwd = proxy.get(passwd_path)[1].value
        if( old_passwd ~= passwd) then
            print("Changing password...")
            proxy.set(passwd_path,passwd)
            flag = 1
        end


	auth_type_path = format ('rpc.wireless.ap.@%s.security.mode',ap)
        old_auth = proxy.get(auth_type_path)[1].value
        if(auth_type ~= old_auth)then
            proxy.set(auth_type_path,auth_type)
            flag = 1
        end

        if fronthaul ~= nil then
            fronthaul_path = format ('uci.wireless.wifi-iface.@%s.fronthaul', if_name)
            old_fronthaul = proxy.get(fronthaul_path)[1].value
         
            if (old_fronthaul ~= fronthaul) then
                print("Changing fronthaul...")
                proxy.set(fronthaul_path,tostring(fronthaul))
                flag = 1
            end
        end

        if backhaul ~= nil then
            backhaul_path = format ('uci.wireless.wifi-iface.@%s.backhaul', if_name)
            old_backhaul = proxy.get(backhaul_path)[1].value
           
            if (old_backhaul ~= backhaul) then
                print("Changing backhaul...")
                proxy.set(backhaul_path,tostring(backhaul))
                flag = 1
            end      
        end 

        if flag == 1 then
            proxy.apply()
        end
    end

    return nil
end

function get_ap_from_bssid(bssid)

    if (bssid == nil) then
        return nil
    end

    ubus_conn,txt = ubus.connecttch()
    if not ubus_conn then
        ubus_conn = ubus.connect()
        if not ubus_conn then
            log:error("Failed to connect to ubus")
            return nil
        end
    end

    ssid_table = ubus_conn:call("wireless.ssid","get",{}) or {}
    ap_table = ubus_conn:call("wireless.accesspoint","get",{}) or {}
    ubus_conn:close()

    if (type(ssid_table) == "table") then
        for if_nam, params in pairs(ssid_table) do
            if (params["bssid"] == bssid) then
                 ifname = if_nam
                 break
            end
        end
    end

    if (type(ap_table) == "table") then
        for ap_name, ap_data in pairs(ap_table) do
            if (ap_data["ssid"] == ifname) then
                return ap_name
            end
        end
    end

    return nil
end

function map_apply_acl(acl_data)

    if (acl_data == nil) then
        print("Acl data is NULL")
        return nil
    end

    local data = json.decode(acl_data)

    if (type(data) == "table") then
        ap = get_ap_from_bssid(data["bssid"])

        if (ap == nil) then
            return nil
        end

        ubus_conn,txt = ubus.connecttch()
        if not ubus_conn then
            ubus_conn = ubus.connect()
            if not ubus_conn then
                log:error("Failed to connect to ubus")
                return nil
            end
        end

        if (data["block"] == 1) then
            action = "deny"
        elseif(data["block"] == 0) then
            action = "delete"
        else
            return nil
        end

        for _, value in pairs(data["stations"]) do
            if (type(value) == "table") then
                for _,mac in pairs(value) do
                    local acl_req = {}
                    acl_req["name"] = ap
                    acl_req["macaddr"] = mac

                    ubus_conn:call("wireless.accesspoint.acl",action,acl_req)
                end
            end
        end
        ubus_conn:close()
    end

    return nil
end


function get_radio_from_if(interface_name)
    ubus_conn,txt = ubus.connecttch()
    if not ubus_conn then
        ubus_conn = ubus.connect()
        if not ubus_conn then
            log:error("Failed to connect to ubus")
            return nil
        end
    end
    local data  = ubus_conn:call("wireless.ssid", "get", {}) 
    if (type(data) == "table") then
        if_data = data[interface_name]
	radio_name = if_data["radio"]
    end
    ubus_conn:close()
    return radio_name
end

function switch_off_bss(data_str)
    if (data_str == nil) then
        print("Input Data is NULL")
        return nil
    end
    local data = json.decode(data_str)
    local if_name,path
    if (type(data) == "table") then
        if_name = data["interface"]
    --    fronthaul = data["fronthaul_bit"]
    --    backhaul = data["backhaul_bit"]
    end
    if(if_name ~= nil) then
        path = format("uci.wireless.wifi-iface.@%s.state",if_name)
	proxy.set(path,"0")
        proxy.apply()
    end
end

function switch_off_radio(data_str)
    if (data_str == nil) then
        print("Input Data is NULL")
        return nil
    end
    local if_name,radio,path
    local data = json.decode(data_str)
    if (type(data) == "table") then
        if_name = data["interface"]
    end
    radio = get_radio_from_if(if_name)
    path = format ("uci.wireless.wifi-device.@%s.state", radio)
    proxy.set(path,"0")
    proxy.apply()
end


