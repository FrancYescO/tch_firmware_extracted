local json = require ("dkjson")
local uci = require('uci')
--local json = require "json"
local singlequote_str="'(.*)'"
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
else
	print("i am here")
end
end


function tprint (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      print(formatting)
      tprint(v, indent+1)
    else
      print(formatting .. v)
    end
  end
end

function getarray_fromvalue(val)
    local arr={}
    print(val)
    for word in val:gmatch("%S+") do table.insert(arr, word) end
        if #arr > 1 then
            for i=1,#arr,1 do
                print(arr[i])
            end
            return arr
         else
            for i=1,#arr,1 do
                print(arr[i])
            end
             return arr
         end
end

function get_map_mac()
    local mac = {
        Agent_mac = "nil",
        Controller_mac = "nil",
        Al_mac = "nil"
    }

    cursor = uci.cursor()

    local agent,controller,agent_mac,controller_mac

    agent          = cursor:get('multiap', 'multiap_agent',      'enabled')
    controller     = cursor:get('multiap', 'multiap_controller', 'enabled')
    agent_mac      = cursor:get('multiap', 'multiap_agent',      'macaddress')
    controller_mac = cursor:get('multiap', 'multiap_controller', 'macaddress')

    mac["Agent_mac"]      = agent_mac
    mac["Controller_mac"] = controller_mac

    if (agent == "1" and controller ~= "1") then
        mac["Al_mac"]     = agent_mac
    elseif (agent ~= "1" and controller ~= "1") then
        local value = cursor:get('multiap','al_entity','al_mac')
        mac["Al_mac"]     = value
    else
        mac["Al_mac"]     = controller_mac
    end

    cursor:close()

    return json.encode(mac)
end

function get_multiap_config(key)
    local value,subkey1,subkey2

    cursor = uci.cursor()
    subkey1,subkey2 = key:match"([^.]*).(.*)"

    if(subkey2 == '') then
        value = cursor:get('multiap', key)
    else
        value = cursor:get('multiap', subkey1, subkey2)
    end

    cursor:close()
    return value
end

function get_agentconfig_all()
    local map_config={
    init={
        enabled   = "nil",
    },
    mac_address={
        al_mac    = "nil",
    },
    agent_interfaces={
        iface     = {},
    },
    agent_ap={
        wifi_ap   = {},
    },
    }

    cursor = uci.cursor()
    local value

    value = cursor:get('multiap', 'multiap_agent', 'enabled')
    map_config["init"]["enabled"]  = tonumber(value)


    local array={}
    value = cursor:get('multiap','agent_ap','wifi_ap')
    array = getarray_fromvalue(value[1])

    map_config["agent_ap"]["wifi_ap"] = array

    array={}
    value = cursor:get('multiap','agent_interfaces','iface')
    array = getarray_fromvalue(value[1])
    map_config["agent_interfaces"]["iface"] = array

    value = cursor:get('multiap', 'al_entity', 'al_mac')
    map_config["mac_address"]["al_mac"] = value

    cursor:close()

    return json.encode(map_config)
end

function get_controllerconfig_all()
    local map_config={
        init={
            enabled = "nil",
        },
        mac_address={
            al_mac = "nil",
        },
        fronthaul={
            ssid = "nil",
            wpa_psk_key = "nil",
        },
        backhaul={
            ssid = "nil",
            wpa_psk_key = "nil",
            prefered_bh_iface = "nil",
        },
        capabilities={
            freq_2_4g = "nil",
            freq_5g = "nil",
            freq_60g = "nil",
        },
    }

    local value
    cursor = uci.cursor()

    value = cursor:get('multiap', 'multiap_controller', 'enabled')
    map_config["init"]["enabled"] = tonumber(value)
	
    value = get_ssid("fronthaul")
    map_config["fronthaul"]["ssid"] = value

    value = get_psk("fronthaul")
    map_config["fronthaul"]["wpa_psk_key"] = value

    value = get_ssid("backhaul")
    map_config["backhaul"]["ssid"] = value

    value = get_psk("backhaul")
    map_config["backhaul"]["wpa_psk_key"] = value

    value = cursor:get('multiap','backhaul', 'prefered_bh_iface')
    map_config["backhaul"]["prefered_bh_iface"] = value

    value = cursor:get('multiap', 'al_entity', 'al_mac')
    map_config["mac_address"]["al_mac"] = value

    value = cursor:get('multiap', 'controller_capabilities', 'freq_2_4g')
    map_config["capabilities"]["freq_2_4g"] = tonumber(value)

    value = cursor:get('multiap', 'controller_capabilities', 'freq_5g')
    map_config["capabilities"]["freq_5g"] = tonumber(value)

    value = cursor:get('multiap', 'controller_capabilities', 'freq_60g')
    map_config["capabilities"]["freq_60g"] = tonumber(value)

    cursor:close()

    return json.encode(map_config)
end

function get_if(map_bss)
    local if_name

    if(map_bss == "fronthaul") then
        ifname = cursor:get('multiap','fronthaul', 'interface')
    elseif(map_bss == "backhaul") then
        ifname = cursor:get('multiap','backhaul', 'interface')
    else
        return nil
    end
    return ifname
end

function get_ssid(map_bss)
    local ssid, ifname
    cursor = uci.cursor()

    ifname = get_if(map_bss)
    if (ifname ~= nil) then
        print(ifname)
        ssid = cursor:get('wireless',ifname,'ssid')
        print(ssid)
        return ssid
    end
    return nil
end

function get_psk(map_bss)
    local ap, value, ifname
    cursor = uci.cursor()

    ifname = get_if(map_bss)
    if(ifname ~= nil) then
        cursor:foreach("wireless", nil, function(s)
    	    for key, value in pairs(s) do
        	    if value == ifname then
                	ap = s[".name"]
           	 end
            end
        end)
        value = cursor:get('wireless', ap, 'wpa_psk_key')
        return value
    end
    return nil
end

function get_freqband_from_if(interface)
    local value
    cursor = uci.cursor()

    value = cursor:get('wireless', interface, 'device')
    return value
end

function get_valid_interface(interface)
    local fh,bh
    cursor = uci.cursor()

    fh = cursor:get('multiap', 'fronthaul', 'interface')
    bh = cursor:get('multiap', 'backhaul', 'interface')
    if (fh == interface) then
        return "fronthaul"
    elseif (bh == interface) then
        return "backhaul"
    end
    return nil
end

function get_controller_policy_config()
local policy_config={
        metrics_report_interval = "nil",
        sta_metrics_rssi_threshold_dbm = "nil",
        sta_metrics_rssi_hysteresis_margin = "nil",
        ap_metrics_channel_utilization_threshold_dbm = "nil",
        sta_link_sta_traffic_stats = "nil"
      }

local value
cursor = uci.cursor()

value = cursor:get('multiap', 'policy_config', 'metrics_report_interval')
policy_config["metrics_report_interval"] = tonumber(value)

value = cursor:get('multiap', 'policy_config', 'sta_metrics_rssi_threshold_dbm')
policy_config["sta_metrics_rssi_threshold_dbm"] = tonumber(value)

value = cursor:get('multiap', 'policy_config', 'sta_metrics_rssi_hysteresis_margin')
policy_config["sta_metrics_rssi_hysteresis_margin"] = tonumber(value)

value = cursor:get('multiap', 'policy_config', 'ap_metrics_channel_utilization_threshold_dbm')
policy_config["ap_metrics_channel_utilization_threshold_dbm"] = tonumber(value)

value = cursor:get('multiap', 'policy_config', 'sta_link_sta_traffic_stats')
policy_config["sta_link_sta_traffic_stats"] = tonumber(value)

cursor:close()

local encode = json.encode(policy_config)
return encode
end

