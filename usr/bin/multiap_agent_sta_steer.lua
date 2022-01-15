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
               
function get_ap_from_mac(key)
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
            mac = string.lower(params["mac_address"])
            if (mac == key) then
                return get_ap_from_if(if_name)
            end
        end
    end

    return nil
end



function set_sta_steer(data_str)
    local current_bssid, target_bssid, target_ch, sta_mac

    flag = 0

    local btm_req={
          name="ap1",
          macaddr="09:08:09:06:05:07",
          validity_interval=20,
          abridged=1,
          disassoc_timer=10,
          target_bss_list={ { bssid="01:02:03:04:05:06", channel=1 }},
    }

    local bss_list

    local data = json.decode(data_str)

    if (type(data) == "table") then
        current_bssid = data["current_bssid"]
        target_bssid = data["target_bssid"]
        target_ch = data["target_channel"]
        sta_mac = data["sta_mac"]
    end

    ubus_conn,txt = ubus.connecttch()
    if not ubus_conn then
        ubus_conn = ubus.connect()
        if not ubus_conn then
                log:error("Failed to connect to ubus")
                return nil
        end
    end

    btm_req["macaddr"]=sta_mac

    btm_req["name"]=get_ap_from_mac(current_bssid);

    print("ap_name " .. btm_req["name"])
    print("ap_name " .. get_ap_from_mac(current_bssid))

    btm_req["target_bss_list"][1]["bssid"]=target_bssid;
    btm_req["target_bss_list"][1]["channel"]=tonumber(target_ch);

    local json_st = json.encode(btm_req)

    ubus_cmd = "ubus call wireless.accesspoint.station send_bss_transition_request '" ..json_st .."'"
    print(ubus_cmd)

    table = ubus_conn:call("wireless.accesspoint.station", "send_beacon_report_request", btm_req) or {}
    ubus_conn:close()
    return nil
end
