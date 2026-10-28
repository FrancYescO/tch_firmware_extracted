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
local uloop = require("uloop")
local json = require ("dkjson")
local uci = require('uci')

local type = type
local popen = io.popen
--local ubus_conn
local cursor

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

function parse_table_filldata(table,tbl_name,key,value)
        if ( type(table) == "table") then
        for k,v in pairs(table) do
                if ( type(v) == "table" and tbl_name ~= nil and k == tbl_name ) then
                        parse_table_filldata(v,nil,key,value)
                elseif ( type(v) == "table" and tbl_name ~= nil and k ~= tbl_name ) then
                        parse_table_filldata(v,tbl_name,key,value)
                else
                        if ( tbl_name == nil and  k == key) then
                                table[k] = value
                        end
                end
        end
        else
                print("i am here")
        end
end

function get_radio_Id(radio,ssid_table)
    local radioId,mac_addr,if_name

    if type(ssid_table) == "table" then
        if(radio == "radio_2G") then
            mac_addr = ssid_table["wl0"]["mac_address"]
            if_name = "wl0"
        elseif (radio == "radio_5G") then
            mac_addr = ssid_table["wl1"]["mac_address"]
            if_name = "wl1"
        elseif (radio == "radio2") then
            mac_addr = ssid_table["wl2"]["mac_address"]
            if_name = "wl2"
        end
        if (mac_addr ~= nil) then
            radioId = mac_addr:gsub(':','')
        end
        return radioId,mac_addr,if_name
    end
end


function get_ap_from_wl(val)
    local curs = uci.cursor()
    local ap_name
    curs:foreach("wireless", nil, function(s)
        for key, value in pairs(s) do
            if value == val and key == "iface" then
                ap_name = s[".name"]
                return ap_name
            end
        end
    end)
    return ap_name
end

function get_wifi_station(ap_name)
    local ubus_table
    local sta_array = {}
    local i = 1

    ubus_conn,txt = ubus.connecttch()
    if not ubus_conn then
    	ubus_conn = ubus.connect()
    	if not ubus_conn then
	    	return nil
		end
    end

    ubus_table = ubus_conn:call("wireless.accesspoint.station", "get", {}) or {}
    ubus_conn:close()

     for k,v in pairs(ubus_table) do
        if type(v) == "table" and k == ap_name then
           for key,value in pairs(v) do
               if value["state"] ~= "Disconnected" then
                   sta_array[i] = key
                   i = i + 1
               end
           end
        end
     end

    return sta_array
end

function is_multiap_owned_bss(bss_iface)

    cursor    = uci.cursor()
    bss_list  = cursor:get('multiap', 'agent', 'bss_list')
    cursor:close()


    local streams = split(bss_list, ",")

    for k,v in pairs(streams) do
        if v == bss_iface then
            return 1
        end 
    end
    return 0
end

function get_cumulative_bss_stats()

    local ubus_bss_stats, ubus_conn, ubus_ch_stats, ubus_rad_stats
    local total_bss_info = {}
    local i = 1

    ubus_conn,txt = ubus.connecttch()
    if not ubus_conn then
        ubus_conn = ubus.connect()
        if not ubus_conn then
            return nil
        end
    end


    ubus_ch_stats = ubus_conn:call("wireless.radio.acs.channel_stats", "get", {}) or {}

    ubus_rad_stats = ubus_conn:call("wireless.radio", "get", {}) or {}

    ubus_bss_stats = ubus_conn:call("wireless.ssid", "get", {}) or {}

    ubus_conn:close()

    for key,value in pairs(ubus_bss_stats) do
        if value["admin_state"] == 1 and value["oper_state"] == 1 and is_multiap_owned_bss(key) == 1 then
            local ap_metrics_per_bss = {
                bssid                = "00:00:00:00:00:00",
                channel_util         = 0,   --wireless.radio.acs.channel_stats
  
                esp_BE = {
                       amsdu            =  0,
                       ampdu            =  0,
                       amsdu_in_ampdu   =  0,
                       BAwindow         =  0,
                       estATF           =  0,
                       txphyrate        =  0
                },
            }
            ap_metrics_per_bss["bssid"] = value["bssid"];
            local radio_name            = value["radio"];

             ap_metrics_per_bss["esp_BE"]["BAwindow"] = 0;
             for k,v in pairs(ubus_ch_stats) do
                 if k == radio_name then
                   if v["medium_available"] then
                       ap_metrics_per_bss["channel_util"] = math.floor((100 - v["medium_available"]) * 2.55)
                       break;
                   end
                 end
             end
   
             for k,v in pairs(ubus_rad_stats) do
               if k == radio_name then
                  if v["ampdu"] then
                    ap_metrics_per_bss["esp_BE"]["ampdu"] = v["ampdu"]
                  end
   
                  if v["amsdu"] then
                    ap_metrics_per_bss["esp_BE"]["amsdu"] = v["amsdu"]  
                  end
   
                  if v["amsdu_in_ampdu"] then
                    ap_metrics_per_bss["esp_BE"]["amsdu_in_ampdu"] = v["amsdu_in_ampdu"]  
                  end
   
                  if v["phy_rate"] then
                    ap_metrics_per_bss["esp_BE"]["txphyrate"] = v["phy_rate"] 
                  end

                  if v["max_ba_window_size"] then
                    ap_metrics_per_bss["esp_BE"]["BAwindow"] = v["max_ba_window_size"];
                  end
                  break;
               end  
             end
   
             ap_metrics_per_bss["esp_BE"]["estATF"] = 100 - ap_metrics_per_bss["channel_util"]; 

            total_bss_info[i] = ap_metrics_per_bss
            i = i + 1
        end
    end

    local encode = json.encode(total_bss_info)


    return encode
end

function get_cumulative_sta_stats()

    local ubus_bss_nodes, ubus_conn, ubus_sta_nodes
    local total_sta_info = {}
    local i = 1

    ubus_conn,txt = ubus.connecttch()
    if not ubus_conn then
        ubus_conn = ubus.connect()
        if not ubus_conn then
                return nil
                end
    end

    ubus_bss_nodes = ubus_conn:call("wireless.ssid", "get", {}) or {}
    ubus_sta_stats = ubus_conn:call("wireless.accesspoint.station", "get", { short = 1}) or {}
    ubus_conn:close()

    if type(ubus_bss_nodes) == "table" then
        for k,v in pairs(ubus_bss_nodes) do
            if v["admin_state"] == 1 and v["oper_state"] == 1 and is_multiap_owned_bss(k) == 1 then

               local ap = get_ap_from_wl(k)

               for key,val in pairs(ubus_sta_stats) do
                   if type(val) == "table" and key == ap then
                       for sta,value in pairs(val) do
                           if value["state"] ~= "Disconnected" then
                               local sta_traffic_stats = {
                                   mac                = nil,
                                   bssid              = nil,
                                   state              = "Disconnected",
                                   tx_bytes           = 0,   --wireless.radio.acs.channel_stats
                                   rx_bytes           = 0,   --get_wifi_station(get_ap_from_wl(k))
                                   tx_packets         = 0,
                                   rx_packets         = 0,
                                   tx_pkts_errors     = 0,
                                   rx_pkts_errors     = 0,
                                   uplink_data_rate   = 0,
                                   downlink_data_rate = 0,
                                   uplink_rssi        = 0,
                                   retransmission_cnt = 0,
                               }

                               sta_traffic_stats["mac"]                = sta
                               sta_traffic_stats["bssid"]              = v["bssid"]
                               sta_traffic_stats["state"]              = value["state"]
                               sta_traffic_stats["tx_packets"]         = value["tx_packets"]
                               sta_traffic_stats["rx_packets"]         = value["rx_packets"]
                               sta_traffic_stats["tx_bytes"]           = value["tx_bytes"]
                               sta_traffic_stats["rx_bytes"]           = value["rx_bytes"]
                               sta_traffic_stats["tx_pkts_errors"]     = 0
                               sta_traffic_stats["rx_pkts_errors"]     = 0
                               sta_traffic_stats["downlink_data_rate"] = value["tx_phy_rate"] / 1000
                               sta_traffic_stats["uplink_data_rate"]   = value["rx_phy_rate"] / 1000
                               local encoded_rssi
                               if (value["rssi"] < -109.5) then
                                   encoded_rssi = 0;
                               elseif (value["rssi"] >= 0) then
                                   encoded_rssi = 220;
                               else
                                   encoded_rssi = math.floor(2 * (value["rssi"] + 110))
                               end
                               sta_traffic_stats["uplink_rssi"]        = encoded_rssi 
                               sta_traffic_stats["retransmission_cnt"] = 0

                               total_sta_info[i] = sta_traffic_stats
                               i = i + 1
                           end
                       end
                   end
               end
            end
        end
    end
    local encode = json.encode(total_sta_info)
    return encode

end


function map_query_beacon_metrics(data_str)

    local data = json.decode(data_str)

    if type(data) ~= "table" and data == nil then
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


    local table
    local i = 1

    local beacon_req = {
        name         = "ap0",
        macaddr      = "09:08:09:06:05:07",
        max_duration =  20,
        mode         = "active",
        timeout      = 1000,
        ssid         = "",
        target_bss_list={ }
    }

    for key,val in pairs(data) do
        if key == "macaddr" then
            beacon_req["macaddr"] = val
        end

        if key == "ssid" then
            beacon_req["ssid"] = val
        end
        
        if key == "target_bss_list" then
             while i>0 do
                 if val[i] == nil then
                     break;
                 end

                 beacon_req["target_bss_list"][i] = val[i]
                 i = i + 1
             end
        end
    end


    ubus_sta_stats = ubus_conn:call("wireless.accesspoint.station", "get", {}) or {}
    for key,val in pairs(ubus_sta_stats) do
        for sta,value in pairs(val) do
            if sta == beacon_req["macaddr"] and value["state"] ~= "Disconnected" then
                beacon_req["name"] = key
            end
        end
    end
 

    table = ubus_conn:call("wireless.accesspoint.station", "send_beacon_report_request", beacon_req) or {}
    ubus_conn:close()
    return nil
end


function map_beacon_metrics_response(json_input)
    
    local ubus_conn,txt = ubus.connecttch()
    if not ubus_conn then
        ubus_conn = ubus.connect()
        if not ubus_conn then
                log:error("Failed to connect to ubus")
                return nil
        end
    end

    local beacon_query = {
        name           =  "ap0",
        macaddr        =  "64:a2:f9:3b:5f:56",
        short          =  100,
        beacon_report  =  1,
    }

    local data = json.decode(json_input)

    if type(data) ~= "table" and data == nil then
        return nil
    end


   local target_bssid = nil
   for key,val in pairs(data) do
       if key == "sta_mac" then
          beacon_query["macaddr"] = val
       end
       if key == "bssid" then
          target_bssid = val
       end
   end


    ubus_sta_stats = ubus_conn:call("wireless.accesspoint.station", "get", {}) or {}
    for key,val in pairs(ubus_sta_stats) do
        for sta,value in pairs(val) do
            if sta == beacon_query["macaddr"] and value["state"] ~= "Disconnected" then
                beacon_query["name"] = key
            end
        end
    end

    local beacon_metrics_table = {}

    ubus_sta_stats = ubus_conn:call("wireless.accesspoint.station", "get", beacon_query) or {}

    for key,val  in pairs(ubus_sta_stats) do
        for sta,value in pairs(val) do
            if target_bssid ~= "ff:ff:ff:ff:ff:ff" then
               for k,v in pairs(value["beacon_report"]) do
                  if k == target_bssid then
                      beacon_metrics_table = v
                      break;
                  end
               end 

            else
               beacon_metrics_table = value["beacon_report"]
               break;
            end
        end
    end

    --FRV: Until NG-178572 is done - filter out too old entries.
    --     Request timeout is set to 1 second. Older entries are not from this request
    for k,v in pairs(beacon_metrics_table) do
        if v["age"] > 2 then
            beacon_metrics_table[k]=nil
        end
    end

    ubus_conn:close()
    return json.encode(beacon_metrics_table)
end

