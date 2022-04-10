-------------- COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE -------------
-- Copyright (c) [2019] – [Technicolor Delivery Technologies, SAS]          -
-- All Rights Reserved                                                      -
-- The source code form of this Open Source Project components              -
-- is subject to the terms of the BSD-2-Clause-Patent.                      -
-- You can redistribute it and/or modify it under the terms of              -
-- the BSD-2-Clause-Patent. (https://opensource.org/licenses/BSDplusPatent) -
-- See COPYING file/LICENSE file for more details.                          -
-----------------------------------------------------------------------------

local proxy = require("datamodel")
local ubus = require("libubus_map_tch")
local format = string.format
local json = require ("dkjson")
local ubus_conn


function get_ap_from_if(if_name)

    ubus_conn,txt = ubus.connecttch()
    if not ubus_conn then
        ubus_conn = ubus.connect()
        if not ubus_conn then
                log:error("Failed to connect to ubus")
                return nil
        end
    end
    
    local ap_table = ubus_conn:call("wireless.accesspoint", "get", {}) or {}
    ubus_conn:close()

    if type(ap_table) == "table" then
        for ap, params in pairs(ap_table) do
            if(params["ssid"] == if_name) then
                return ap
            end
        end
    end
end        
               
function get_ap_from_bssid(key)
    local value, table, mac
    key = string.lower(key)

    ubus_conn,txt = ubus.connecttch()
    if not ubus_conn then
        ubus_conn = ubus.connect()
        if not ubus_conn then
                log:error("Failed to connect to ubus")
                return nil
        end
    end

    -- UBUS CALL WIRELESS.SSID

    table = ubus_conn:call("wireless.ssid", "get", {}) or {}
    ubus_conn:close()

    if type(table) == "table" then
        for if_name , params in pairs(table) do
            bssid = string.lower(params["bssid"])
            if (bssid == key) then
                return get_ap_from_if(if_name)
            end
        end
    end

    return nil
end


function map_btm_sta_steer(data_str)

    local btm_req = {
          name          =nil,
          macaddr       =nil,
          abridged      =1,
          disassoc_timer=nil,
          target_bss_list={ { bssid=nil, channel=0 }},
    }

    local data = json.decode(data_str)

    if type(data) ~= "table" or data == nil then
        return nil
    end

    local ubus_conn,txt = ubus.connecttch()
    if not ubus_conn then
        ubus_conn = ubus.connect()
        if not ubus_conn then
                log:error("Failed to connect to ubus")
                return nil
        end
    end

    btm_req["name"]           = data["name"]
    btm_req["macaddr"]        = data["sta_mac"]
    btm_req["disassoc_timer"] = data["disassoc_timer"]
    btm_req["abridged"]       = data["abridged"]

    btm_req["target_bss_list"][1]["bssid"]   = data["target_bssid"];
    btm_req["target_bss_list"][1]["channel"] = tonumber(data["target_channel"]);

    local table = ubus_conn:call("wireless.accesspoint.station", "send_bss_transition_request", btm_req) or {}
    ubus_conn:close()
    return nil
end


function map_legacy_sta_steer(sta_array)

    local sta_table = json.decode(sta_array)

    local ubus_conn,txt = ubus.connecttch()
    if not ubus_conn then
        ubus_conn = ubus.connect()
        if not ubus_conn then
                log:error("Failed to connect to ubus")
                return nil
        end
    end

    local i = 1

    --1 st element will be bssid 
    local ap_name = get_ap_from_bssid(sta_table[i]);
    i = i + 1

    local ubus_sta_stats = ubus_conn:call("wireless.accesspoint.station", "get", {}) or {}

    while i>0 do
        if sta_table[i] == nil then
            break;
        end

        local deauth_req = {
          name    =  nil,
          macaddr =  nil,
          reason  =  2,
        }    

        deauth_req["macaddr"] = sta_table[i]

        deauth_req["name"]    = ap_name

        local table = ubus_conn:call("wireless.accesspoint.station", "deauth", deauth_req)
        i = i + 1
    end

    ubus_conn:close()
    return nil
end

