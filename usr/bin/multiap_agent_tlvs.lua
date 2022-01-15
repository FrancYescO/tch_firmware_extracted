local ubus = require("libubus_map_tch")
local uloop = require("uloop")
local json = require ("dkjson")
local uci = require('uci')

local type = type
local ubus_conn
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

function get_wps_state(ap_name)
    local ubus_table

    ubus_conn,txt = ubus.connecttch()
    if not ubus_conn then
    	ubus_conn = ubus.connect()
    	if not ubus_conn then
        	log:error("Failed to connect to ubus")	    	
		return nil
	end
    end

    ubus_table = ubus_conn:call("wireless.accesspoint.wps", "get", {}) or {}
    ubus_conn:close()

     for k,v in pairs(ubus_table) do
        if type(v) == "table" and k == ap_name then
            if v["admin_state"] == 1 and v["oper_state"] == 1 then
                   return 1;
            end
        end
     end

    return 0;
end

function get_wifi_station(ap_name)
    local ubus_table
    local sta_array = {}
    local i = 1

    ubus_conn,txt = ubus.connecttch()
    if not ubus_conn then
    	ubus_conn = ubus.connect()
    	if not ubus_conn then
        	log:error("Failed to connect to ubus")
	    	return nil
	end
    end

    ubus_table = ubus_conn:call("wireless.accesspoint.station", "get", {}) or {}
    ubus_conn:close()

     for k,v in pairs(ubus_table) do
        if type(v) == "table" and k == ap_name then
           for key,value in pairs(v) do
               if value["state"] ~= "Disconnected" then
                   local sta_info = {
                                        sta_mac    = "nil",
                                        assoc_time = "nil"
                                    }
                   sta_info["sta_mac"]    = key
                   sta_info["assoc_time"] = value["last_assoc_timestamp"]
                   sta_array[i] = sta_info
                   i = i + 1
               end
           end
        end
     end

    return sta_array
end


function get_AP_Autoconfig()
    local ap_autoconfig = {
        AP_Autoconfig_config = { }
    }

    local radio_table, ssid_table
    ubus_conn,txt = ubus.connecttch()
    if not ubus_conn then
        ubus_conn = ubus.connect()
        if not ubus_conn then
                log:error("Failed to connect to ubus")
                return nil
        end
    end
    radio_table = ubus_conn:call("wireless.radio", "get", {}) or {}
    ssid_table = ubus_conn:call("wireless.ssid", "get", {}) or {}
	
    if type(radio_table) == "table" then
        for radio , params in pairs(radio_table) do

            local autoconfig = {
                if_name                 = "nil",
                mac	                = "nil",
                Radio_ID                = "nil",
                radio	                = "nil",
                MAX_BSSID    	        = "nil",
                supported_bandwidth	= "nil",
                supported_standard      = "nil",
                bandwidth_capability    = "nil",
                max_tx_streams          = "nil",
                max_rx_streams          = "nil",
                sgi_support             = "nil",
                su_beamformer_capable   = "nil",
                mu_beamformer_capable   = "nil",
                regulatory_domain	= "nil",
                channel_list            = "nil",
		state			= "nil",
                bss_info                = {},
                channel                 = "nil"
            }
            local  bss_count            = 1

            autoconfig["radio"]                   = params["band"]
            autoconfig["regulatory_domain"]       = params["country"]
            autoconfig["channel_list"]            = params["allowed_channels"]
            autoconfig["MAX_BSSID"]               = "8"
            
	    if (params["oper_state"] == 1 and params["admin_state"] == 1) then
                autoconfig["state"]               = 1
            else
                autoconfig["state"]               = 0
            end

	    radio_id, mac, if_name = get_radio_Id(radio,ssid_table)

            autoconfig["Radio_ID"]                = radio_id
            autoconfig["mac"]                     = mac
            autoconfig["if_name"]                 = if_name
	    autoconfig["channel"]                 = tonumber(params["channel"])
              
             local bandwidth = params["channel_width"]
             if bandwidth ~= nil then
                 bandwidth = string.gsub(bandwidth,"MHz","")
             end

             autoconfig["supported_bandwidth"] = tonumber(bandwidth)
             autoconfig["sgi_support"]         = params["sgi"]

             if(params["txbf"] == "on" or params["txbf"] == "auto") then
                autoconfig["su_beamformer_capable"] = 1
             elseif (params["txbf"] == "off") then
                autoconfig["su_beamformer_capable"] = 0
             end

             if(params["mumimo"] == "on" or params["mumimo"] == "auto") then
                 autoconfig["mu_beamformer_capable"] = 1
             elseif (params["txbf"] == "off") then
                 autoconfig["mu_beamformer_capable"] = 0
             end

             capabilities = params["capabilities"]
             if (params["capabilities"] ~= nil) then
                 local i,j,value,rx,tx
                 i,j = string.find(capabilities,"802.11(%a+)")

                 if (i ~= nil and j ~= nil) then
                     value = string.sub(capabilities,i,j)
                     autoconfig["supported_standard"] = value
                 end

                 i,j = string.find(capabilities,"%dx%d")

                 if (i ~= nil and j ~= nil) then
                     value = string.sub(capabilities,i,j)
                     if(value ~= nil) then
                         streams = split(value,"x")
                         autoconfig["max_rx_streams"] = tonumber(streams[1])
                         autoconfig["max_tx_streams"] = tonumber(streams[2])
                     end
                 end

                 i,j = string.find(capabilities,"(%d+)MHz")

                 if (i ~= nil and j ~= nil) then
                     bandwidth = string.gsub(string.sub(capabilities,i,j), "MHz","")
                 end

                 autoconfig["bandwidth_capability"] = tonumber(bandwidth)
             end

             for k,v in pairs(ssid_table) do
                 if type(v) == "table" then
                     for key,value in pairs(v) do
                         if key == "radio" and  value == radio then
                            local bss_entry = {
                                 name           = nil,
                                 ssid           = "nil",
                                 bssid          = "nil",
                                 admin_state    = "nil",
                                 oper_state     = "nil",
                                 wps_enabled    = nil,
				 station        = {}
                            }

                            bss_entry["name"]         = k
                            bss_entry["ssid"]         = v["ssid"]
                            bss_entry["bssid"]        = v["bssid"]
                            bss_entry["admin_state"]  = v["admin_state"]
                            bss_entry["oper_state"]   = v["oper_state"]
                            local ap                  = get_ap_from_wl(k)
                            bss_entry["station"]      = get_wifi_station(ap)
	                    bss_entry["wps_enabled"]  = get_wps_state(ap)
			    autoconfig.bss_info[bss_count]    = bss_entry
                            bss_count = bss_count + 1
                         end
                     end
                 end
             end  

             table.insert(ap_autoconfig.AP_Autoconfig_config, autoconfig)
        end
    end
   
    local encode = json.encode(ap_autoconfig)
    ubus_conn:close()
    return encode
end    

function get_bssid_from_ap(key)
    local ifname

    ubus_conn,txt = ubus.connecttch()
    if not ubus_conn then
    	ubus_conn = ubus.connect()
    	if not ubus_conn then
        	log:error("Failed to connect to ubus")	
	    	return nil
	end
    end

    -- UBUS CALL WIRELESS.SSID

    local ap_table, ssid_table
    
    ap_table = ubus_conn:call("wireless.accesspoint", "get", {}) or {}
    ssid_table = ubus_conn:call("wireless.ssid", "get", {}) or {}
    ubus_conn:close()

    if (type(ap_table) == "table" and type(ssid_table) == 'table') then
        for ap_name , params1 in pairs(ap_table) do
            if (ap_name == key) then
            	ifname = params1["ssid"]
            	for if_name , params2 in pairs(ssid_table) do
            	    if (ifname == if_name) then
                        return params2["bssid"]
                    end
            	end          	            
            end
        end
    end

    return nil
end

function get_radioinfo(rad_name)
    local radio_info = {
        radio_mac    = nil,
        channel      = nil,
    }

    ubus_conn,txt = ubus.connecttch()
    if not ubus_conn then
        ubus_conn = ubus.connect()
        if not ubus_conn then
                return nil
                end
    end

    local radio_table, ssid_table

    radio_table = ubus_conn:call("wireless.radio", "get", {name = rad_name}) or {}
    ssid_table  = ubus_conn:call("wireless.ssid", "get", {}) or {}
    ubus_conn:close()

    if (type(radio_table) == "table" and type(ssid_table) == 'table') then
        for radio_name , params in pairs(radio_table) do
            if (radio_name == rad_name) then
                radio_id, radio_info.radio_mac,if_name = get_radio_Id(radio_name,ssid_table)
                radio_info.channel = params["channel"]
            end
        end
    end

    local encode = json.encode(radio_info)
    return encode
end


function get_radio_and_bss_state(interface_name)
    local state_info = {
        radio_oper_state    = nil,
        radio_admin_state   = nil,
        bss_oper_state      = nil,
        bss_admin_state     = nil,
    }

    ubus_conn,txt = ubus.connecttch()
    if not ubus_conn then
        ubus_conn = ubus.connect()
        if not ubus_conn then
                return nil
                end
    end

    local radio_table, ssid_table

    ssid_table  = ubus_conn:call("wireless.ssid", "get", {name = interface_name}) or {}
    
    if (type(ssid_table) == 'table') then
        for intf_name , ssid_params in pairs(ssid_table) do
            if (intf_name == interface_name) then
                state_info.bss_oper_state = ssid_params["oper_state"]
                state_info.bss_admin_state = ssid_params["admin_state"]
                radio_table = ubus_conn:call("wireless.radio", "get", {name = ssid_params["radio"]}) or {}
                if (type(radio_table) == 'table') then
                    for radio_name , radio_params in pairs(radio_table) do
                        if (radio_name == ssid_params["radio"]) then
                            state_info.radio_oper_state = radio_params["oper_state"]
                            state_info.radio_admin_state = radio_params["admin_state"]
                        end
                    end
                end
            end
        end
    end
    
    ubus_conn:close()

    local encode = json.encode(state_info)
    return encode
end

function get_channel_pref(opclass_str)
    local opclass
    opclass = tonumber(opclass_str)
    return
end
