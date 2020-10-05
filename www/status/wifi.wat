local match, format, gsub, find = string.match, string.format, string.gsub, string.find
local untaint = string.untaint
local dm = require("datamodel")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local api = require("fwapihelper")

-- wps status
local wps_status = {gui_enabled = "1"}

-- "0" is configured for 5G
-- "1" is configured for 2G
local WLConfig = {
  ["0"] = {
    ["radio_#G"] = "radio_5G",
    ["wl#"] = "wl1",
    ["ap#"] = "ap0",
    ["acct_key"] = "SI7U2QNDIK",
  },
  ["1"] = {
    ["radio_#G"] = "radio_2G",
    ["wl#"] = "wl0",
    ["ap#"] = "ap4",
    ["acct_key"] = "TS8U3RMDTN",
  },
}
local WLDefault = {
  ["0"] = {
    ["wl#_radius_authentication_ipaddr"] = "0.0.0.0",
    ["wl#_radius_accounting_ipaddr"] = "0.0.0.0",
    ["wl#_radius_accounting_key"] = "SI7U2QNDIK",
  },
  ["1"] = {
    ["wl#_radius_authentication_ipaddr"] = "0.0.0.0",
    ["wl#_radius_accounting_ipaddr"] = "0.0.0.0",
    ["wl#_radius_accounting_key"] = "TS8U3RMDTN",
  },
}

local Securities = setmetatable({
  ["NONE"] = "none",
  ["WEP"] = "wep",
  ["WPA2PSK"] = "wpa2-psk",
  ["WPAWPA2PSK"] =  "wpa-wpa2-psk",
  ["WPA2ENT"] =  "wpa2",
  ["WPAWPA2ENT"] =  "wpa-wpa2",
  ["none"] = "NONE",
  ["wep"] = "WEP",
  ["wpa2-psk"] = "WPA2PSK",
  ["wpa-wpa2-psk"] =  "WPAWPA2PSK",
  ["wpa2"] =  "WPA2ENT",
  ["wpa-wpa2"] =  "WPAWPA2ENT",
}, {__index = function() return "NONE" end})

local sec_map = {
  ["wl#_enabled"]        = "rpc.wireless.radio.@radio_#G.admin_state",
  ["wl#_ssid"]           = "rpc.wireless.ssid.@wl#.ssid",
  ["wl#_broadcast_ssid"] = "rpc.wireless.ap.@ap#.public",
  ["wl#_security"]       = "rpc.wireless.ap.@ap#.security.mode",
  ["wl#_key"]            = "rpc.wireless.ap.@ap#.security.wep_key",
  ["wl#_radius_authentication_ipaddr"] = "uci.wireless.wifi-radius-server.@ap#_auth0.ip",
  ["wl#_radius_authentication_port"]   ="uci.wireless.wifi-radius-server.@ap#_auth0.port",
  ["wl#_radius_authentication_key"]    = "uci.wireless.wifi-radius-server.@ap#_auth0.secret",
  ["wl#_radius_accounting_ipaddr"]     = "uci.wireless.wifi-radius-server.@ap#_acct0.ip",
  ["wl#_radius_accounting_port"]       = "uci.wireless.wifi-radius-server.@ap#_acct0.port",
  ["wl#_radius_accounting_key"]        = "uci.wireless.wifi-radius-server.@ap#_acct0.secret",
  ["admin_state"] = "rpc.wireless.ssid.@wl#.admin_state",
  ["oper_state"]  = "rpc.wireless.ssid.@wl#.oper_state",
  ["wpa_psk"]     = "rpc.wireless.ap.@ap#.security.wpa_psk_passphrase",
}

-- Hotspot mode
-- Interface is "wl0_2" and AP is "ap6"
local wlguest_map = {
  hotspot_enable         = "uci.wireless.wifi-iface.@wl0_2.state",
  hotspot_ssid           = "uci.wireless.wifi-iface.@wl0_2.ssid",
  hotspot_security       = "uci.wireless.wifi-ap.@ap6.security_mode",
  hotspot_broadcast_ssid = "uci.wireless.wifi-ap.@ap6.public",
  hotspot_password       = "uci.wireless.wifi-ap.@ap6.wpa_psk_key",
}

local function get_sec_info(servicename, id)
  local data = {}
  local key

  for k,v in pairs(sec_map) do
    key = k:gsub("#", id)
    for p, value in pairs(WLConfig[id]) do
      if v:match(p) then
        data[key] = v:gsub(p, value)
        break
      end
    end
  end
  content_helper.getExactContent(data)

  for k, v in pairs(WLDefault[id]) do
    key = k:gsub("#", id)
    if data[key] == "" then
      data[key] = v
    end
  end

  key = format("wl%s_security", id)
  data[key] = Securities[untaint(data[key])]
  if data[key] ~= "WEP" then
    key = format("wl%s_key", id)
    data[key] = data["wpa_psk"]
    data["wpa_psk"] = nil
  end

  key = format("wl%s_enabled", id)
  data[key] = data["admin_state"] and data["oper_state"]
  data["admin_state"] = nil
  data["oper_state"] = nil
  data[servicename] = "end"
  return data
end

local function set_sec_info(args, id)
  local paths = {}
  local key = format("wl%s_ssid", id)
  local wl_status_path, wl_security, wl_key, wl_key_path
  if args[key] then
    for k,v in pairs(sec_map) do
      key = k:gsub("#", id)
      for p, value in pairs(WLConfig[id]) do
        if v:match(p) then
          local path = v:gsub(p, value)
          if k == "wl#_security" then
            wl_security = untaint(args[key])
            paths[path] = Securities[wl_security]
          else
            if k == "wl#_enabled" then
              wl_status_path = path
            elseif k == "wl#_key" then
                wl_key = args[key]
                wl_key_path = path
            end
            paths[path] = args[key]
            break
          end
        end
      end
    end
  end
  if wl_security and wl_security ~= "WEP" then
    paths[wl_key_path] = nil
    paths[wl_key_path:gsub("wep_key", "wpa_psk_passphrase")] = wl_key
  end

  -- Set Hotspot Mode
  if args.wl1_enabled == "0" then
    paths[wlguest_map.hotspot_enable] = args.wl1_enabled
  end
  if args.wl1_ssid and args.wl1_ssid ~= "" then
    paths[wlguest_map.hotspot_ssid] = format("GUEST-%s", args.wl1_ssid)
  end

  --below is for wps auto off/on according to wifi radio off/on
  local wl_status = dm.get(wl_status_path)[1].value
  local key = format("wl%s_enabled", id)
  if (args[key] == "0" and wl_status == "0" and wps_status.enabled == "1") then
    wps_status.gui_enabled = "0"
  else
    wps_status.gui_enabled = "1"
  end

  if api.mgr:CheckEcoTimeSlot() then
    paths[wl_status_path] = "0"
  end
  dm.set(paths)
  dm.apply()
  api.Sleep("3")
  return true
end

local service_wl2g = {
  name = "wl2g_sec",
  get = function()
    return get_sec_info("wl2g_sec", "1")
  end,
  set = function(args)
    return set_sec_info(args, "1")
  end
}

local service_wl5g = {
  name = "wl5g_sec",
  get = function()
    return get_sec_info("wl5g_sec", "0")
  end,
  set = function(args)
    return set_sec_info(args, "0")
  end
}

local Eco = {
  enabled = {"eco_dis", "0"},
  start   = {"eco_start_time", "22:00"},
  stop    = {"eco_end_time",   "07:00"} ,
}

local service_eco = {
  name = "wl_eco",
  get = function()
    local data = {
      wl_eco = "end",
    }
    local info = api.mgr:GetEcoInfo()
    api.SetItemValues(data, info, Eco)
    api.GetWeekdays(info.frequency, data, "eco")
    return data
  end,
  set = function(args)
    local frequency = api.GetFrequency(args, "eco")
    api.mgr:SetEcoTimer(untaint(args.eco_dis), untaint(args.eco_start_time), untaint(args.eco_end_time), frequency)
    api.mgr:SetEcoAction(untaint(args.eco_dis))
    api.Apply()
    return true
  end,
}

local service_wl_guestaccess = {
  name = "wl_guestaccess",
  get  = function()
    local data = {}
    for k,v in pairs(wlguest_map) do
      data[k] = v
    end
    content_helper.getExactContent(data)

    data.hotspot_security = data.hotspot_security == "" and "WEP" or Securities[untaint(data.hotspot_security)]

    local object = api.mgr:GetWlGuestObject()
    data.hotspot_filtering = find(object,"all") and "all" or "web"
    data.hotspot_timeout = api.GetWlGuestTimeout()
    data.wl_guestaccess = "end"
    return data
  end,
  set = function(args)
    local paths ={}
    if args.hotspot_enable == "1" then
      local passwd = post_helper.getRandomKey():sub(1,10)
      paths[wlguest_map.hotspot_password] = passwd
    end

    for k,v in pairs(wlguest_map) do
      if args[k] then
        if k == "hotspot_security" then
          paths[v] = Securities[untaint(args[k])]
        else
          paths[v] = args[k]
        end
      end
    end
    dm.set(paths)

    local enable = untaint(args.hotspot_enable)
    local duration = untaint(args.hotspot_timeout)
    local filter = untaint(args.hotspot_filtering)
    if duration and filter then
      api.mgr:SetWlGuestTimer(enable, duration)
      api.mgr:SetWlGuestAction(filter)
    end
    api.Apply()
    api.Sleep("3")
    return true
  end,
}

local service_wl_wps_status = {
  name = "wl_WPS_status",
  get = function()
    local wl_wps_5g_status = dm.get("rpc.wireless.ap.@ap0.wps.admin_state")[1].value
    local wl_wps_2g_status = dm.get("rpc.wireless.ap.@ap4.wps.admin_state")[1].value
    if wl_wps_2g_status =="1" or wl_wps_5g_status == "1" then
      wps_status.enabled = "1"
    else
      wps_status.enabled = "0"
    end
    return wps_status
  end
}

local service_wl_trigger_wps = {
  name = "wl_triggerWPS",
  set = function(args)
    local paths = {}
    if not args.trigger then
      paths["rpc.wireless.ap.@ap0.wps.admin_state"] = args.activate
      paths["rpc.wireless.ap.@ap4.wps.admin_state"] = args.activate
      dm.set(paths)
      dm.apply()
    else
      local wl_2g_status = dm.get("uci.wireless.wifi-iface.@wl0.state")[1].value
      local wl_5g_status = dm.get("uci.wireless.wifi-iface.@wl1.state")[1].value
      if wl_5g_status == "1" then
        dm.set("rpc.wireless.ap.@ap0.wps.enrollee_pbc", args.trigger)
      end
      if wl_2g_status == "1" then
        dm.set("rpc.wireless.ap.@ap4.wps.enrollee_pbc", args.trigger)
      end
    end
    return true
  end
}

local service_wps_proc_status = {
  name = "wps_proc_status",
  get = function()
    local data = {}
    local wps_2g = dm.get("rpc.wireless.ap.@ap4.wps.last_session_state")[1].value
    local wps_5g = dm.get("rpc.wireless.ap.@ap0.wps.last_session_state")[1].value
    if wps_2g == "idle" and wps_5g == "idle" then
      data.status = 0
    elseif wps_2g == "inprogress" or wps_5g == "inprogress" then
      data.status = 1
    elseif wps_2g == "success" or wps_5g == "success" then
      data.status = 2
    end
    data.wps_data = "end"
    return data
  end,
}

local service_fw_settings = {
  name = "fw_settings",
  get = function()
    local data = {
      fw_settings = "end",
    }
    local setting = api.mgr:GetFWWebUI("fw_setting")
    for k,v in ipairs(setting) do
      local key,value = v:match("(.*)|(.*)")
      data[key] = value
    end
    return data
  end,
  set = function(args)
    local value = {}
    for k,v in pairs(args) do
      value[#value+1] = format("%s|%s", k, untaint(v))
    end
    api.mgr:SetFWWebUI("fw_setting", value)
    api.Apply()
    return true
  end
}

register(service_wl2g)
register(service_wl5g)
register(service_eco)
register(service_wl_guestaccess)
register(service_wl_wps_status)
register(service_wl_trigger_wps)
register(service_wps_proc_status)
register(service_fw_settings)
