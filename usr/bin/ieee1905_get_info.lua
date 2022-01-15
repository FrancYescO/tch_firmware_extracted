local ubus = require("libubus_map_tch")
local json = require ("dkjson")
local uci = require('uci')

local popen = io.popen
local type = type
local ubus_conn
local cursor

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
    end
end

function get_ieee1905_config(key)
    local value

    cursor = uci.cursor()
    value = cursor:get('multiap', 'al_entity', key)

    cursor:close()   
    return value
end

function get_if_from_mac(key)
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
                return if_name
            end
        end
    end

    return nil
end


function get_interface_info_all(if_name)  
    local interface_info={
        mac_address = "nil",
        manufacturer_name = "nil",
        model_name = "nil",
        model_number = "nil",
        serial_number = "nil",
        device_name = "nil",
        uuid = "nil",
        interface_type = "nil",

        interface_type_data={
            ieee80211={
                bssid = "nil",
                ssid = "nil",
                role = "nil",
                ap_channel_band = "nil",
                ap_channel_center_frequency_index_1 = "nil",
                ap_channel_center_frequency_index_2 = "nil",
                authentication_mode = "nil",
                encryption_mode = "nil",
                network_key = "nil",
            },

            ieee1901={
                network_identifier = "nil",
            },

            other = "nil",
        },

        is_secured = "nil",
        push_button_on_going = "nil",
        push_button_new_mac_address = "nil",
        power_state = "nil",

        neighbor_mac_address = {},

        ipv4_nr = "nil",
        ipv4={
            type = "nil",
            address = "nil",
            dhcp_server = "nil",
        },

        ipv6_nr = "nil",
        ipv6={
            type = "nil",
            address = "nil",
            origin = "nil",
        },

        vendor_specific_elements_nr = "nil",
        vendor_specific_elements={
            oui = "nil",
            vendor_data_len = "nil",
            vendor_data = "nil",
        },
    }

--[[    ubus_conn = ubus.connect()
    if not ubus_conn then
        log:error("Failed to connect to ubus")
        return nil
    end
]]--

    local table, radio, acspoint, config_file, value, neighbor_nr

    -- UBUS CALL WIRELESS.SSID

--    table = ubus_conn:call("wireless.ssid", "get", {name = if_name}) or {}

    local handle = popen("ubus call wireless.ssid get '{\"name\":\"" ..if_name .."\"}'")
    local ssid_data = handle:read("*a")
    table = json.decode(ssid_data)
    handle:close()

    if type(table) == "table" then
        radio = table[if_name]["radio"]

        interface_info["mac_address"] = table[if_name]["mac_address"]
        interface_info["interface_type_data"]["ieee80211"]["bssid"] = table[if_name]["bssid"]
        interface_info["interface_type_data"]["ieee80211"]["ssid"]  = table[if_name]["ssid"]
        if table[if_name]["admin_state"] == 1 and table[if_name]["oper_state"] == 1 then
            interface_info["power_state"] = table[if_name]["oper_state"]
        end
    end


    -- UBUS CALL WIRELESS.RADIO

--    table = ubus_conn:call("wireless.radio", "get", {name = radio}) or {}

    handle = popen("ubus call wireless.radio get '{\"name\":\"" ..radio .."\"}'")
    local radio_data = handle:read("*a")
    table = json.decode(radio_data)
    handle:close()

    if type(table) == "table" then
        interface_info["interface_type_data"]["ieee80211"]["ap_channel_band"] =tonumber((string.gsub( table[radio]["channel_width"],"MHz","")))
		interface_info["interface_type_data"]["ieee80211"]["ap_channel_center_frequency_index_1"]=tonumber(table[radio]['channel'])
        interface_info["interface_type"]               = table[radio]["supported_standards"]
    end

    -- UBUS CALL WIRELESS.ACCESSPOINT

--    table = ubus_conn:call("wireless.accesspoint", "get", {}) or {}

    handle = popen("ubus call wireless.accesspoint get")
    local ap_data = handle:read("*a")
    table = json.decode(ap_data)
    handle:close()

    if type(table) == "table" then
        for ap , params in pairs(table) do
            if params["ssid"] == if_name then
                acspoint = ap
                interface_info["uuid"] = params["uuid"]
            end
        end
    end


    -- UBUS CALL WIRELESS.ACCESSPOINT.SECURITY

--    table = ubus_conn:call("wireless.accesspoint.security", "get", {name = acspoint}) or {}

    handle = popen("ubus call wireless.accesspoint.security get '{\"name\":\"" ..acspoint .."\"}'")
    local sec_data = handle:read("*a")
    table = json.decode(sec_data)
    handle:close()

    if type(table) == "table" then
        interface_info["interface_type_data"]["ieee80211"]["authentication_mode"] = table[acspoint]["mode"]
        if (table[acspoint]["mode"] == "none") then
            interface_info["interface_type_data"]["ieee80211"]["encryption_mode"] = "NONE"
        else
            if table[acspoint]["mode"] == "wep" then
                interface_info["interface_type_data"]["ieee80211"]["network_key"] = table[acspoint]["wep_key"]
                interface_info["interface_type_data"]["ieee80211"]["encryption_mode"] = "TKIP"
            else
                interface_info["interface_type_data"]["ieee80211"]["network_key"] = table[acspoint]["wpa_psk_passphrase"]
                interface_info["interface_type_data"]["ieee80211"]["encryption_mode"] = "AES"
            end
        end
    end


    -- UBUS CALL WIRELESS.ACCESSPOINT.STATION

--    table = ubus_conn:call("wireless.accesspoint.station", "get", {name = acspoint}) or {}

    handle = popen("ubus call wireless.accesspoint.station get '{\"name\":\"" ..acspoint .."\"}'")
    local ap_sta_data = handle:read("*a")
    table = json.decode(ap_sta_data)
    handle:close()

    if type(table) == "table" then
        local neighbor = {}
        neighbor_nr  = 1
        for _,params in pairs(table) do
            for mac, values in pairs(params) do
                if values["state"] ~= "Disconnected" then
                    neighbor[neighbor_nr] = mac
                    neighbor_nr = neighbor_nr + 1
                end
            end
        end
        interface_info["neighbor_mac_address"] = neighbor
    end

--    ubus_conn:close()

    -- UCI SHOW WIRELESS

    cursor = uci.cursor()

    value = cursor:get('wireless', if_name, 'device')
    interface_info["device_name"]       = value

    value = cursor:get('wireless', if_name, 'mode')
    interface_info["interface_type_data"]["ieee80211"]["role"] = value

    value = cursor:get('env','var','prod_friendly_name')
    if (#value >= 36) then
        value = cursor:get('env','var','prod_name')
    end
    interface_info["model_name"] = value

    value = cursor:get('env','var','company_name')
    interface_info["manufacturer_name"] = value

    value = cursor:get('env','var','prod_number')
    interface_info["model_number"] = value

    value = cursor:get('env','var', 'serial')
    interface_info["serial_number"] = value

    cursor:close()

    return json.encode(interface_info)
end

function get_interface_state(if_name)

--[[    ubus_conn = ubus.connect()
    if not ubus_conn then
        log:error("Failed to connect to ubus")
        return nil
    end


    table = ubus_conn:call("hostmanager.device", "get", {}) or {}

    ubus_conn:close()
]]--

    if if_name == "lo" then
        return "up"
    end
    local handle = popen("ubus call network.link status") 

    local interface_data = handle:read("*a")
    ubus_table = json.decode(interface_data)
    handle:close()

    if type(ubus_table) == "table" then
        for _,data in pairs(ubus_table) do
            for _,value in pairs(data) do
                if (value["interface"] == if_name) then
                    return value["action"]
                end
            end
        end
    end

    return "down"
end

function get_bridge_conf()
    local br_json  = {}

    local cursor   = uci.cursor()

    --uci get all the interfaces under 1905 al_entity
    local ieee1905_ifaces = cursor:get('multiap', 'al_entity', 'interfaces')


    --Get the list of ifaces in br from network config
    local network_type = cursor:get('network', 'lan', 'type')
    local br_ifaces    = cursor:get('network', 'lan', 'ifname')
    local j = 1

    --As of now we focus on br-lan tuple
    if network_type == "bridge" then

        local        i = 1
        local br_tuple = {
                         br_name          = "nil",
                         iface_list       = {},
                         }

        local iface_list    = {}

        --In homeware the bridge ifaces will be under "br-lan"
        br_tuple["br_name"] = "br-lan";

       for iface in string.gmatch(br_ifaces, "%S+") do
           local m,n = string.find(ieee1905_ifaces, iface)
           if m == nil or n == nil then break end

           iface_list[i]    = iface
           i = i + 1
       end

        br_tuple["iface_list"] = iface_list
        br_json[j]             = br_tuple
        j = j + 1

    end

    --Add further more bridge configs here, if 1905 wants to take control

    cursor:close()
    return json.encode(br_json)
end

