local proxy = require("datamodel")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local find, match, format, untaint, gsub = string.find, string.match, string.format, string.untaint, string.gsub


-------RADIO_2G--------------
local radio_2g = "radio_2G"
local iface_2g = "wl0"
local ap_2g = "ap4"
local auth_2g = "ap4_auth0"
local acct_2g = "ap4_acct0"

---------5G------------------
local radio_5g = "radio_5G"
local iface_5g = "wl1"
local ap_5g = "ap0"
local auth_5g = "ap0_auth0"
local acct_5g = "ap0_acct0"

--------hotspot mode --------
local iface_hotspot = "wl0_2"
local ap_hotspot = "ap6"

---------wps_status --------
local wps_status = {gui_enabled = "1"}
local pathtod_action = "uci.tod.action."
local pathtod_timer = "uci.tod.timer."
local pathtod_weekend_timer = "uci.tod.timer.@timer_wifidisable_weekend."
local pathtod_workend_timer = "uci.tod.timer.@timer_wifidisable_workend."
local pathradio_2g = string.format("rpc.wireless.radio.@%s.", radio_2g)
local pathiface_2g = string.format("rpc.wireless.ssid.@%s.", iface_2g)
local pathap_2g = string.format("rpc.wireless.ap.@%s.", ap_2g)
local pathradio_5g = string.format("rpc.wireless.radio.@%s.", radio_5g)
local pathiface_5g = string.format("rpc.wireless.ssid.@%s.", iface_5g)
local pathap_5g = string.format("rpc.wireless.ap.@%s.", ap_5g)
local pathradius_auth = "uci.wireless.wifi-radius-server.@ap0_auth0."
local pathradius_auth_2g = string.format("uci.wireless.wifi-radius-server.@%s.", auth_2g)
local pathradius_acc_2g = string.format("uci.wireless.wifi-radius-server.@%s.", acct_2g)
local pathradius_auth_5g = string.format("uci.wireless.wifi-radius-server.@%s.", auth_5g)
local pathradius_acc_5g = string.format("uci.wireless.wifi-radius-server.@%s.", acct_5g)

local mapParams_2g = {
  {
    param = "wl1_enabled",
    path = pathradio_2g .."admin_state",
  },
  {
    param = "",
    path = pathap_2g .. "admin_state",
  },
  {
    param = "wl1_ssid",
    path = pathiface_2g .. "ssid",
  },
  {
    param = "wl1_broadcast_ssid",
    path = pathap_2g .. "public",
  },
  {
    param = "wl1_security",
    path = pathap_2g .. "security.mode",
  },
  {
    param = "wl1_key",
    path = pathap_2g .. "security.wep_key",
  },
  {
    param = "wl1_wpa_psk",
    path = pathap_2g .. "security.wpa_psk_passphrase",
  },
  {
    param = "",
    path = pathap_2g .. "wps.admin_state",
  },
  {
    param = "wl1_radius_authentication_ipaddr",
    path = pathradius_auth_2g .. "ip",
  },
  {
    param = "wl1_radius_authentication_port",
    path = pathradius_auth_2g .. "port",
  },
  {
    param = "wl1_radius_authentication_key",
    path = pathradius_auth_2g .. "secret",
  },
  {
    param = "wl1_radius_accounting_ipaddr",
    path = pathradius_acc_2g .. "ip",
  },
  {
    param = "wl1_radius_accounting_port",
    path = pathradius_acc_2g .. "port",
  },
  {
    param = "wl1_radius_accounting_key",
    path = pathradius_acc_2g .. "secret",
  },
}

local mapParams_5g = {
  {
    param = "wl0_enabled",
    path = pathradio_5g .."admin_state",
  },
  {
    param = "",
    path = pathap_5g .. "admin_state",
  },
  {
    param = "wl0_ssid",
    path = pathiface_5g .. "ssid",
  },
  {
    param = "wl0_broadcast_ssid",
    path = pathap_5g .. "public",
  },
  {
    param = "wl0_security",
    path = pathap_5g .. "security.mode",
  },
  {
    param = "wl0_key",
    path = pathap_5g .. "security.wep_key",
  },
  {
    param = "wl0_wpa_psk",
    path = pathap_5g .. "security.wpa_psk_passphrase",
  },
  {
    param = "",
    path = pathap_5g .. "wps.admin_state",
  },
  {
    param = "wl0_radius_authentication_ipaddr",
    path = pathradius_auth_5g .. "ip",
  },
  {
    param = "wl0_radius_authentication_port",
    path = pathradius_auth_5g .. "port",
  },
  {
    param = "wl0_radius_authentication_key",
    path = pathradius_auth_5g .. "secret",
  },
  {
    param = "wl0_radius_accounting_ipaddr",
    path = pathradius_acc_5g .. "ip",
  },
  {
    param = "wl0_radius_accounting_port",
    path = pathradius_acc_5g .. "port",
  },
  {
    param = "wl0_radius_accounting_key",
    path = pathradius_acc_5g .. "secret",
  },
}

local function convert2Sec(value)
  if value == nil or value == "" then return -1 end
  local  hour, min = value:match("(%d+):(%d+)")
  local secs = hour*3600 + min*60
  return tonumber(secs)
end

local modf = math.modf
local function updateDuration (time)
  if time == 0 or time == nil then return "00:00" end
  local days = modf(time /86400)
  local hours = modf(time / 3600)-(days * 24)
  local minutes = modf(time /60) - (days * 1440) - (hours * 60)
  local seconds = time
  return string.format("%02d:%02d", hours, minutes)
end

local function removeElementByKey(tbl,key)
  local tmp ={}
  for i in pairs(tbl) do
    table.insert(tmp,i)
  end
  local newTbl = {}
  local i = 1
  while i <= #tmp do
    local val = tmp [i]
    if val == key then
      table.remove(tmp,i)
    else
      newTbl[val] = tbl[val]
      i = i + 1
    end
  end
  return newTbl
end

local secmodes_matched = {
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
}

local pathfw = "uci.fastweb.webui."
local wl_all_mapParams = {}
local fw_status ={
  fw_settings = "end",
}

for k,v in ipairs(mapParams_2g) do
  if v.param ~= "" then wl_all_mapParams[v.param] = v.path end
end

for k,v in ipairs(mapParams_5g) do
  if v.param ~= "" then wl_all_mapParams[v.param] = v.path end
end

local function wl_total_set(args)
  local params = {}
  if args.wl0_ssid ~= nil or args.wl1_ssid ~= nil then
    for key,val in pairs(args) do
      for k,v in pairs(wl_all_mapParams) do
        if key == k and val ~= nil then
          params[untaint(v)] = untaint(val)
          if key == "wl1_security" then
            params[untaint(v)] = secmodes_matched[untaint(val)]
          end
          if key == "wl0_security" then
            params[untaint(v)] = secmodes_matched[untaint(val)]
          end
        end
      end
    end

    if  args.wl1_security ~= nil and args.wl1_security ~= "WEP" then
      local key = pathap_2g .. "security.wep_key"
      params = removeElementByKey(params, key)
      params[untaint(pathap_2g .. "security.wpa_psk_passphrase")] = args.wl1_key
    end
    if args.wl0_security ~= nil and  args.wl0_security ~= "WEP" then
      local key = pathap_5g .. "security.wep_key"
      params = removeElementByKey(params, key)
      params[untaint(pathap_5g .. "security.wpa_psk_passphrase")] = args.wl0_key
    end
    if args.wl1_enabled == "0" then
      params["uci.wireless.wifi-iface.@" .. (iface_hotspot) .. ".state"] = args.wl1_enabled
    end
    if args.wl1_ssid ~= "" and args.wl1_ssid ~= nil then
      params["uci.wireless.wifi-iface.@" .. iface_hotspot .. ".ssid"] = "GUEST-" .. args.wl1_ssid
    end
    --below is for wps auto off/on according to wifi radio off/on
    local wl_2g_status = proxy.get(pathradio_2g .."admin_state")[1].value
    local wl_5g_status = proxy.get(pathradio_5g .."admin_state")[1].value
    if args.wl1_enabled == "0" and wl_5g_status == "0" and wps_status.enabled == "1" then
       wps_status.gui_enabled = "0"
    elseif args.wl0_enabled == "0" and wl_2g_status == "0" and wps_status.enabled == "1" then
       wps_status.gui_enabled = "0"
    else
       wps_status.gui_enabled = "1"
    end
    local eco_status = {
      enabled = "uci.tod.action.@action_wifidisable.enabled",
      workend_start = "uci.tod.timer.@timer_wifidisable_workend.start_time",
      weekend_start = "uci.tod.timer.@timer_wifidisable_weekend.start_time",
      start = "uci.tod.timer.@timer_wifidisable.start_time",
      stop = "uci.tod.timer.@timer_wifidisable.stop_time",
    }
    content_helper.getExactContent(eco_status)
    local switchoff = 0
    if eco_status.enabled == "1" and eco_status.start ~= "" and eco_status.stop ~= "" then
      local weekstr = string.sub(eco_status.start, 0, find(eco_status.start, ":") - 1)
      local len = string.len(weekstr)
      local current_weekday = os.date("%a", os.time() + 1)
      local current_time = os.date("%H:%M:%S", os.time())
      local cts = convert2Sec(current_time)
      local start_s = convert2Sec(match(eco_status.start, "%d%d:%d%d"))
      local stop_s = convert2Sec(match(eco_status.stop, "%d%d:%d%d"))

      if eco_status.workend_start ~= "" then
        weekstr = weekstr .. ",Fri"
      elseif eco_status.weekend_start ~= "" then
        weekstr = weekstr .. ",Sun"
      elseif len > 0 and len < 4 and eco_status.weekend_start == "" then
        local weekstr_n = string.sub(eco_status.stop, 0, find(eco_status.stop, ":") - 1)
        weekstr = (weekstr_n == weekstr) and weekstr or (weekstr .. "," ..  weekstr_n)
      elseif string.len(weekdays) > 8 and eco_status.weekend_start == "" and eco_status.workend_start== "" then
        weekstr = "All"
      end
      if weekstr == "All" or find(weekstr, current_weekday) then
        if start_s < stop_s and cts >= start_s and cts <= stop_s then
          switchoff = 1
        elseif start_s > stop_s and (cts >= start_s or cts <= stop_s) then
          switchoff = 1
        end
      end
    end
    if switchoff == 1 then
       params[pathradio_2g .."admin_state"] = "0"
       params[pathradio_5g .."admin_state"] = "0"
    end
    proxy.set(params)
    proxy.apply()
    os.execute("sleep 3")
    return true
  end
  return true
end

local service_fw_settings = {
  name = "fw_settings"
}

service_fw_settings.get = function()
  local fw_keys = proxy.get(pathfw)
  for i,v in pairs(fw_keys) do
    if v.param then
      fw_status[v.param] = v.value
    end
  end
  return fw_status
end

service_fw_settings.set = function(args)
  local value = {}
  for i,v in pairs(args) do
    value[untaint(pathfw .. i)] = v
  end
  proxy.set(value)
  proxy.apply()
  return true
end

local service_wl5g = {
  name = "wl5g_sec"
}

local function web_get_wl5g_params()
  local web_mapParams = {}
  for k,v in ipairs(mapParams_5g) do
    if v.param ~= "" then
      if proxy.get(v.path) then
        web_mapParams[v.param] = proxy.get(v.path)[1].value
      else
        web_mapParams[v.param] = ""
      end
    end
  end
  web_mapParams["wl0_radius_authentication_ipaddr"] = (web_mapParams["wl0_radius_authentication_ipaddr"] == "") and "0.0.0.0" or web_mapParams["wl0_radius_authentication_ipaddr"]
  web_mapParams["wl0_radius_accounting_ipaddr"] = (web_mapParams["wl0_radius_accounting_ipaddr"] == "") and "0.0.0.0" or web_mapParams["wl0_radius_accounting_ipaddr"]
  web_mapParams["wl0_radius_accounting_key"] = (web_mapParams["wl0_radius_accounting_key"] == "") and "SI7U2QNDIK" or web_mapParams["wl0_radius_accounting_key"]

  web_mapParams["wl0_security"] = secmodes_matched[untaint(web_mapParams.wl0_security)]
  if web_mapParams["wl0_security"] == nil then
    web_mapParams["wl0_security"] = "NONE"
  end
  if web_mapParams["wl0_security"] ~= "WEP" then
     web_mapParams["wl0_key"] = web_mapParams["wl0_wpa_psk"]
  end
  local state = {
    admin_state = pathiface_5g .. "admin_state",
    oper_state = pathiface_5g .. "oper_state",
  }
  content_helper.getExactContent(state)
  web_mapParams["wl0_enabled"] = state.admin_state and state.oper_state

  web_mapParams.wl5g_sec = "end"
  return web_mapParams
end

service_wl5g.get = function()
  return web_get_wl5g_params()
end

service_wl5g.set = function(args)
  return wl_total_set(args)
end

local service_wl2g = {
  name = "wl2g_sec"
}

local function web_get_wl2g_params()
  local web_mapParams = {
    wl2g_sec = "end",
  }
  for k,v in ipairs(mapParams_2g) do
    if v.param ~= "" then
      if proxy.get(v.path) then
        web_mapParams[v.param] = proxy.get(v.path)[1].value
      else
        web_mapParams[v.param] = ""
      end
    end
  end
  web_mapParams["wl1_radius_authentication_ipaddr"] = (web_mapParams["wl1_radius_authentication_ipaddr"] == "") and "0.0.0.0" or web_mapParams["wl1_radius_authentication_ipaddr"]
  web_mapParams["wl1_radius_accounting_ipaddr"] = (web_mapParams["wl1_radius_accounting_ipaddr"] == "") and "0.0.0.0" or web_mapParams["wl1_radius_accounting_ipaddr"]
  web_mapParams["wl1_radius_accounting_key"] = (web_mapParams["wl1_radius_accounting_key"] == "") and "TS8U3RMDTN" or web_mapParams["wl1_radius_accounting_key"]

  web_mapParams["wl1_security"] = secmodes_matched[untaint(web_mapParams.wl1_security)]
  if web_mapParams["wl1_security"] == nil then
    web_mapParams["wl1_security"] = "NONE"
  end
  if web_mapParams["wl1_security"] ~= "WEP" then
    web_mapParams["wl1_key"] = web_mapParams["wl1_wpa_psk"]
  end
  local state = {
    admin_state = pathiface_2g .. "admin_state",
    oper_state = pathiface_2g .. "oper_state",
  }
  content_helper.getExactContent(state)
  web_mapParams["wl1_enabled"] = state.admin_state and state.oper_state
  return web_mapParams
end

service_wl2g.get = function()
   return web_get_wl2g_params()
end

service_wl2g.set = function(args)
  return wl_total_set(args)
end

local service_eco = {
  name = "wl_eco"
}

local function web_get_eco()
  local web_eco_status = {
    wl_eco = "end",
  }
  local eco_tag, eco_start, eco_stop = "", "", ""
  local actions = content_helper.convertResultToObject(pathtod_action, proxy.get(pathtod_action))
  local timers = content_helper.convertResultToObject(pathtod_timer, proxy.get(pathtod_timer))

  for k,v in ipairs(actions) do
    if v.paramindex == "@action_wifidisable" then
      web_eco_status.eco_dis = v.enabled
    end
  end

  for k,v in ipairs(timers) do
    if v.paramindex == "@timer_wifidisable" then
      eco_start = v.start_time
      eco_stop = v.stop_time
    end
    if v.paramindex == "@timer_wifidisable_workend" and v.start_time ~= "" then
      eco_tag = "workend"
    end
    if v.paramindex == "@timer_wifidisable_weekend" and v.start_time ~= "" then
      eco_tag = "weekend"
    end
  end
  if web_eco_status.eco_dis then
    local weekdays = string.sub(eco_start,0, find(eco_start, ":") - 1)
    local len = string.len(weekdays)
    if find(eco_start,"All") then
      web_eco_status.eco_mon = "1"
      web_eco_status.eco_tue = "1"
      web_eco_status.eco_wed = "1"
      web_eco_status.eco_thu = "1"
      web_eco_status.eco_fri = "1"
      web_eco_status.eco_sat = "1"
      web_eco_status.eco_sun = "1"
    elseif len < 4 and eco_tag ~= "weekend" then
      web_eco_status.eco_mon = "0"
      web_eco_status.eco_tue = "0"
      web_eco_status.eco_wed = "0"
      web_eco_status.eco_thu = "0"
      web_eco_status.eco_fri = "0"
      web_eco_status.eco_sat = "0"
      web_eco_status.eco_sun = "0"
    else
      web_eco_status.eco_mon =  find(eco_start,"Mon") and "1" or "0"
      web_eco_status.eco_tue =  find(eco_start,"Tue") and "1" or "0"
      web_eco_status.eco_wed =  find(eco_start,"Wed") and "1" or "0"
      web_eco_status.eco_thu =  find(eco_start,"Thu") and "1" or "0"
      web_eco_status.eco_fri =  (eco_tag == "workend") and "1" or "0"
      web_eco_status.eco_sat =  find(eco_start,"Sat") and "1" or "0"
      web_eco_status.eco_sun =  (eco_tag == "weekend") and "1" or "0"
    end
  else
    web_eco_status.eco_mon = "0"
    web_eco_status.eco_tue = "0"
    web_eco_status.eco_wed = "0"
    web_eco_status.eco_thu = "0"
    web_eco_status.eco_fri = "0"
    web_eco_status.eco_sat = "0"
    web_eco_status.eco_sun = "0"
  end
  web_eco_status.eco_start_time = match(eco_start, "%d%d:%d%d")
  web_eco_status.eco_end_time =  match(eco_stop, "%d%d:%d%d")
  return web_eco_status
end

service_eco.get = function()
  return web_get_eco()
end

service_eco.set = function(args)
  local eco_status = {}
  local weekdays_start_time = ""
  local weekdays_end_time = ""
  local weekdays = {}
  if args["eco_mon"] == "1" then weekdays[#weekdays+1] = "Mon" end
  if args["eco_tue"] == "1" then weekdays[#weekdays+1] = "Tue" end
  if args["eco_wed"] == "1" then weekdays[#weekdays+1] = "Wed" end
  if args["eco_thu"] == "1" then weekdays[#weekdays+1] = "Thu" end
  if args["eco_fri"] == "1" then weekdays[#weekdays+1] = "Fri" end
  if args["eco_sat"] == "1" then weekdays[#weekdays+1] = "Sat" end
  if args["eco_sun"] == "1" then weekdays[#weekdays+1] = "Sun" end

  local weekstr = ""
  local days =  #weekdays
  local overflow = (convert2Sec(args.eco_start_time) > convert2Sec(args.eco_end_time)) and "1" or "0"
  if days == 0 then
      weekstr = os.date("%a", os.time()) .. ":"
  elseif days == 7 then
    weekstr = "All:"
  elseif days > 0 then
    weekstr = table.concat(weekdays, ",") .. ":"
  end
  if days == 2 then
    eco_status[pathtod_weekend_timer .. "start_time"] = "Sun:" .. args.eco_start_time
    eco_status[pathtod_weekend_timer .. "stop_time"] =  ((overflow == "1") and "Sun:24:00" or ("Sun:" .. args.eco_end_time))
    eco_status[pathtod_weekend_timer .. "enabled"] = "1"
    eco_status[pathtod_workend_timer .. "enabled"] = "0"
    eco_status[pathtod_workend_timer .. "start_time"] = ""
    eco_status[pathtod_workend_timer .. "stop_time"] = ""
    weekdays_start_time = gsub(weekstr, ",Sun", "")  .. args.eco_start_time
    weekdays_end_time = ((overflow == "1") and "Sun:" or "Sat:") .. args.eco_end_time
  elseif days == 5 then
    eco_status[pathtod_workend_timer .. "start_time"] = "Fri:" .. args.eco_start_time
    eco_status[pathtod_workend_timer .. "stop_time"] = "Fri:" .. ((overflow == "1") and "24:00" or args.eco_end_time)
    eco_status[pathtod_weekend_timer .. "enabled"] = "0"
    eco_status[pathtod_workend_timer .. "enabled"] = "1"
    eco_status[pathtod_weekend_timer .. "start_time"] = ""
    eco_status[pathtod_weekend_timer .. "stop_time"] = ""
    weekdays_start_time = gsub(weekstr, ",Fri", "")  .. args.eco_start_time
    weekdays_end_time = gsub(weekstr, ",Fri", "")  .. args.eco_end_time
  else
    eco_status[pathtod_weekend_timer .. "start_time"] = ""
    eco_status[pathtod_weekend_timer .. "stop_time"] = ""
    eco_status[pathtod_workend_timer .. "start_time"] = ""
    eco_status[pathtod_workend_timer .. "stop_time"] = ""
    eco_status[pathtod_weekend_timer .. "enabled"] = "0"
    eco_status[pathtod_workend_timer .. "enabled"] = "0"
    local beyond = (days == 0 and overflow == "1") and (os.date("%a", os.time() + 24*3600) .. ":") or (os.date("%a", os.time()) .. ":")
    weekdays_start_time = weekstr .. args.eco_start_time
    weekdays_end_time = (days == 0) and (beyond ..  args.eco_end_time) or (weekstr .. args.eco_end_time)
  end
  eco_status[pathtod_action .. "@action_wifidisable.enabled"] = args.eco_dis
  eco_status[pathtod_timer .. "@timer_wifidisable.enabled"] = args.eco_dis
  eco_status[pathtod_timer .. "@timer_wifidisable.start_time"] = weekdays_start_time
  eco_status[pathtod_timer .. "@timer_wifidisable.stop_time"]= weekdays_end_time
  eco_status[pathtod_timer .. "@timer_wifidisable.periodic"] = (days == 0) and "0" or "1"

  if args.eco_dis == "1" then
    local current_weekday = os.date("%a", os.time())
    if weekstr == "All:" or find(weekstr, current_weekday) then
      local current_time = os.date("%H:%M:%S", os.time())
      local cts = convert2Sec(current_time)
      local start_s = convert2Sec(args.eco_start_time)
      local stop_s = convert2Sec(args.eco_end_time)
      if (start_s < stop_s and cts >= start_s and cts <= stop_s) or (start_s > stop_s and cts >= start_s) then
        eco_status[pathradio_2g .."admin_state"] = "0"
        eco_status[pathradio_5g .."admin_state"] = "0"
      end
    end
  end
  proxy.set(eco_status)
  proxy.apply()
  return true
end

local function random(len, modl)
  local RDModle = {
    RSM_Capital = 1,
    RSM_Letter = 2,
    RSM_Cap_Let = 3,
    RSM_Number = 4,
    RSM_Cap_Num = 5,
    RSM_Let_Num = 6,
    RSM_ALL = 7
  }
  local BC = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  local SC = "abcdefghijklmnopqrstuvwxyz"
  local NO = "0123456789"
  local maxLen = 0
  local templete = ""
  if modl ==  RDModle.RSM_Number then
    maxLen = 10
    templete  = NO
  elseif modl ==  RDModle.RSM_ALL then
    maxLen = 62
    templete = BC .. SC .. NO
  else
    maxLen = 26
    templete  = SC
  end
  local srt = {}
  for i=1, len, 1 do
    local index = math.random(1, maxLen)
    srt[i] = string.sub(templete, index, index)
  end
  return table.concat(srt, "")
end

local wl_guest_mapParams_path = {
  hotspot_enable =  "uci.wireless.wifi-iface.@" .. iface_hotspot .. ".state",
  hotspot_ssid = "uci.wireless.wifi-iface.@" .. iface_hotspot .. ".ssid",
  hotspot_security = "uci.wireless.wifi-ap.@" .. ap_hotspot .. ".security_mode",
  hotspot_broadcast_ssid = "uci.wireless.wifi-ap.@" .. ap_hotspot .. ".state",
  hotspot_password  =  "uci.wireless.wifi-ap.@" .. ap_hotspot .. ".wpa_psk_key",
}

local function get_wl_guestaccess()
  local wl_guest_mapParams = {}
  local start_time, stop_time = "", ""
  local timer_enable = ""
  local timers = content_helper.convertResultToObject(pathtod_timer, proxy.get(pathtod_timer))
  local actions = content_helper.convertResultToObject(pathtod_action, proxy.get(pathtod_action))
  for k,v in pairs(wl_guest_mapParams_path) do
    wl_guest_mapParams[k] = v
  end
  content_helper.getExactContent(wl_guest_mapParams)
  local security = secmodes_matched[untaint(wl_guest_mapParams.hotspot_security)]
  wl_guest_mapParams.hotspot_security = wl_guest_mapParams.hotspot_security == "" and "WEP" or secmodes_matched[untaint(wl_guest_mapParams.hotspot_security)]

  for k,v in ipairs(timers) do
    if v.paramindex == "@timer_guest_restriction" then
      stop_time = match(v.start_time, "%w+:(%d+:%d+)")
      timer_enable = v.enabled
    end
  end
  for k,v in ipairs(actions) do
    if v.paramindex == "@action_guest_restriction" then
      wl_guest_mapParams.hotspot_filtering = find(v.object,"all") and "all" or "web"
      if find(v.object, "0|") or timer_enable == "0" then
        wl_guest_mapParams.hotspot_timeout = "-1"
      else
        local current_time_secs = convert2Sec(os.date("%H:%M", os.time()))
        local stop_time_secs = convert2Sec(stop_time)
        if stop_time_secs >= current_time_secs then
          wl_guest_mapParams.hotspot_timeout = stop_time_secs - current_time_secs
        elseif stop_time_secs + 20 *3600 > current_time_secs then
          wl_guest_mapParams.hotspot_timeout = "0"
        else
          wl_guest_mapParams.hotspot_timeout = stop_time_secs + 24 * 3600 - current_time_secs
        end
      end
    end
  end

  wl_guest_mapParams.wl_guestaccess = "end"
  return wl_guest_mapParams
end

local service_wl_guestaccess = {
  name = "wl_guestaccess"
}

service_wl_guestaccess.get  = function()
  return get_wl_guestaccess()
end

local function setFirewall(allowType)
  local action_fwd = "ACCEPT"
  if allowType == "web" then
    action_fwd = "DROP"
  end
  proxy.set("uci.firewall.zone.@Guest.forward", action_fwd)
  proxy.set("uci.firewall.defaultrule.@defaultoutgoing_Guest.target", action_fwd)
end

service_wl_guestaccess.set = function(args)
  local wl_guest_mapParams ={}
  if args.hotspot_enable == "1" then
    local passwd = random(10,7)
    proxy.set("uci.wireless.wifi-ap.@" .. ap_hotspot .. ".wpa_psk_key", passwd)
    proxy.apply()
  end
  wl_guest_mapParams["uci.wireless.wifi-iface.@" .. (iface_hotspot) .. ".state"] = args.hotspot_enable
  local stop_weekday_time = ""
  local filter = args.hotspot_filtering
  local duration = args.hotspot_timeout

  if args.hotspot_enable == "1" then
    if filter then
      setFirewall(filter)
    end
  else
    setFirewall("all")
  end

  if args.hotspot_enable == "1" then
    if duration and duration ~= "-1" then
      local current_time = os.date("%H:%M:%S", os.time())
      local current_time_secs = convert2Sec(current_time)
      local stop_time_secs = convert2Sec(current_time) + args.hotspot_timeout
      if stop_time_secs >= 24 * 3600 then
        stop_weekday_time = os.date("%a:", os.time() + 24*3600) .. updateDuration(stop_time_secs - 24*3600)
      else
        stop_weekday_time = os.date("%a:", os.time()) .. updateDuration(stop_time_secs)
      end
      if filter then
        filter = "1|" .. filter
      end

      wl_guest_mapParams["uci.tod.timer.@timer_guest_restriction.enabled"] = "1"
      wl_guest_mapParams["uci.tod.timer.@timer_guest_restriction.start_time"] = stop_weekday_time
    elseif duration then
      if filter then
        filter = "0|" .. filter
      end
      wl_guest_mapParams["uci.tod.timer.@timer_guest_restriction.enabled"] = "0"
    end

    if args.hotspot_ssid then
      wl_guest_mapParams["uci.wireless.wifi-iface.@" .. (iface_hotspot) .. ".ssid"] = args.hotspot_ssid
    end
    if args.hotspot_security then
      wl_guest_mapParams[ "uci.wireless.wifi-ap.@" .. (ap_hotspot) .. ".security_mode"] = secmodes_matched[untaint(args.hotspot_security)]
    end
    if args.hotspot_broadcast_ssid then
      wl_guest_mapParams["uci.wireless.wifi-ap.@" .. (ap_hotspot) .. ".state"] = args.hotspot_broadcast_ssid
    end
    if filter then
      wl_guest_mapParams["uci.tod.action.@action_guest_restriction.object"] = filter
    end
  else
    wl_guest_mapParams["uci.tod.action.@action_guest_restriction.object"] = "0|all"
    wl_guest_mapParams["uci.tod.timer.@timer_guest_restriction.enabled"] = "0"
  end
  proxy.set(wl_guest_mapParams)
  proxy.apply()
  os.execute("sleep 5")
  return true
end

local service_wl_WPS_status = {
  name = "wl_WPS_status"
}

local function wps_get_status()
  --local wps_status = {}
  local wl_wps_2g_status = proxy.get(pathap_2g .. "wps.admin_state")[1].value
  local wl_wps_5g_status = proxy.get(pathap_5g .. "wps.admin_state")[1].value
  if wl_wps_2g_status =="1" or wl_wps_5g_status == "1" then
    wps_status.enabled = "1"
  else
    wps_status.enabled = "0"
  end
  return wps_status
end

service_wl_WPS_status.get = function()
  return wps_get_status()
end

local service_wl_trigger_wps = {
  name = "wl_triggerWPS"
}

service_wl_trigger_wps.set = function(args)
  local wl_wps_status = {}
  if args.trigger == nil then
      wl_wps_status[pathap_5g .. "wps.admin_state"] = args.activate
      wl_wps_status[pathap_2g .. "wps.admin_state"] = args.activate
    proxy.set(wl_wps_status)
    proxy.apply()
  else
    local wl_2g_status = proxy.get("uci.wireless.wifi-iface.@wl0.state")[1].value
    local wl_5g_status = proxy.get("uci.wireless.wifi-iface.@wl1.state")[1].value
    if wl_5g_status == "1" then
      proxy.set("rpc.wireless.ap.@ap0.wps.enrollee_pbc", args.trigger)
    end
    if wl_2g_status == "1" then
      proxy.set("rpc.wireless.ap.@ap4.wps.enrollee_pbc", args.trigger)
    end
  end
  return true
end

local service_wps_proc_status = {
  name = "wps_proc_status"
}

service_wps_proc_status.get = function()
  local proc_status = {}
  local wps_proc_2g_status = proxy.get("rpc.wireless.ap.@ap4.wps.last_session_state")[1].value
  local wps_proc_5g_status = proxy.get("rpc.wireless.ap.@ap0.wps.last_session_state")[1].value

  if wps_proc_2g_status == "idle" and wps_proc_5g_status == "idle" then
    proc_status.status = 0
  elseif wps_proc_2g_status == "inprogress" or wps_proc_5g_status == "inprogress" then
    proc_status.status = 1
  elseif wps_proc_2g_status == "success" or wps_proc_5g_status == "success" then
    proc_status.status = 2
  end
  proc_status.wps_proc_status = "end"
  return proc_status
end

register(service_wl2g)
register(service_wl5g)
register(service_eco)
register(service_wl_guestaccess)
register(service_wl_WPS_status)
register(service_wl_trigger_wps)
register(service_fw_settings)
register(service_wps_proc_status)
