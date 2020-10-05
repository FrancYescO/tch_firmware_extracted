local dm = require("datamodel")
local content_helper = require("web.content_helper")
local match, format, gsub, untaint  = string.match, string.format, string.gsub, string.untaint
local tostring = tostring
local pathwl_ssid_2g = "rpc.wireless.radio.@radio_2G.bsslist."
local pathwl_ssid_5g = "rpc.wireless.radio.@radio_5G.bsslist."
local timeout = 10
local process = require("tch.process")
local execute = process.execute


local function reload_wait(timeout, sleep_time, valid_path)
  for i=1, timeout do
    local valid_value =  dm.get(valid_path)
    if valid_value then
      break;
    else
      execute("sleep", {sleep_time})
    end
  end
end

local service_wl2g_adv = {
  name = "wl2g_adv"
}

local wl2g_adv_path = {
  wl1_auto_channel =  "rpc.wireless.radio.@radio_2G.requested_channel",
  wl1_bandwidth = "rpc.wireless.radio.@radio_2G.requested_channel_width",
  wl1_channel = "rpc.wireless.radio.@radio_2G.channel",
}
local wl1_requested_channel_width = "rpc.wireless.radio.@radio_2G.requested_channel_width"
service_wl2g_adv.get  = function()
  local wl2g_adv_mapParams = {}
  for k,v in pairs(wl2g_adv_path) do
    wl2g_adv_mapParams[k] = v
  end
  content_helper.getExactContent(wl2g_adv_mapParams)
  wl2g_adv_mapParams.wl1_auto_channel = wl2g_adv_mapParams.wl1_auto_channel == "auto" and "Auto" or "0"
  if wl2g_adv_mapParams.wl1_bandwidth == "auto" then
    wl2g_adv_mapParams.wl1_bandwidth = "40MHz"
  end
  return wl2g_adv_mapParams
end

service_wl2g_adv.set = function(args)
  local wl2g_adv_mapParams = {}
  wl2g_adv_mapParams[wl2g_adv_path.wl1_auto_channel] = args.wl1_auto_channel == "Auto" and  "auto" or args.wl1_channel
  if args.wl1_bandwidth == "20MHz" then
    wl2g_adv_mapParams[wl1_requested_channel_width] = "20"
  elseif args.wl1_bandwidth =="40MHz" then
    wl2g_adv_mapParams[wl1_requested_channel_width] = "20/40"
  else
    wl2g_adv_mapParams[wl1_requested_channel_width] = "auto"
  end
  -- Check validation to avoid wifi reload
  reload_wait(timeout, 1, wl2g_adv_path["wl1_channel"])
  dm.set(wl2g_adv_mapParams)
  dm.apply()
  return true
end

local service_wl5g_adv = {
  name = "wl5g_adv"
}

local wl5g_adv_path = {
  wl0_auto_channel =  "rpc.wireless.radio.@radio_5G.requested_channel",
  wl0_bandwidth = "rpc.wireless.radio.@radio_5G.requested_channel_width",
  wl0_channel = "rpc.wireless.radio.@radio_5G.channel",
}
local wl0_request_bandwidth = "rpc.wireless.radio.@radio_5G.requested_channel_width"

service_wl5g_adv.get  = function()
  local wl5g_adv_mapParams = {}
  for k,v in pairs(wl5g_adv_path) do
    wl5g_adv_mapParams[k] = v
  end
  content_helper.getExactContent(wl5g_adv_mapParams)
  wl5g_adv_mapParams.wl0_auto_channel = wl5g_adv_mapParams.wl0_auto_channel == "auto" and "Auto" or "0"
  if wl5g_adv_mapParams.wl0_bandwidth == "auto" then
    wl5g_adv_mapParams.wl0_bandwidth = "80MHz"
  elseif wl5g_adv_mapParams.wl0_bandwidth == "20/40MHz" then
    wl5g_adv_mapParams.wl0_bandwidth = "40MHz"
  end

  return wl5g_adv_mapParams
end

service_wl5g_adv.set = function(args)
  local wl5g_adv_mapParams = {}
  wl5g_adv_mapParams[untaint(wl5g_adv_path.wl0_auto_channel)] = args.wl0_auto_channel == "Auto" and  "auto" or args.wl0_channel
  if args.wl0_bandwidth == "20MHz" then
    wl5g_adv_mapParams[wl0_request_bandwidth] = "20"
  elseif args.wl0_bandwidth == "40MHz" then
    wl5g_adv_mapParams[wl0_request_bandwidth] = "20/40"
  elseif args.wl0_bandwidth == "80MHz" then
    wl5g_adv_mapParams[wl0_request_bandwidth] = "20/40/80"
  else
    wl5g_adv_mapParams[wl0_request_bandwidth] = "auto"
  end
  -- Check validation to avoid wifi reload
  reload_wait(timeout, 1, wl5g_adv_path["wl0_channel"])
  dm.set(wl5g_adv_mapParams)

  local auto_wl5g_channel = nil
  if args.wl0_auto_channel == "Auto" then
    local old_channel =  dm.get(wl5g_adv_path["wl0_auto_channel"])[1].value
    if old_channel ~= "auto" then
      auto_wl5g_channel = true
    end
  end

  dm.apply()

  if auto_wl5g_channel then
    execute("sleep", {"1"})
    reload_wait(timeout, 1, wl5g_adv_path["wl0_channel"])
  end
  return true
end


local function data_format(tab)
  local web_wlssid_list = {}

  local channels_2g = {}
  local channels_5g = {}
  local count0 = 0
  local count1 = 0

  for i,v in ipairs(tab) do
    if v.radio == "radio_2G" and channels_2g[untaint(v.channel)] == nil then
      channels_2g[untaint(v.channel)] = {
        channel = v.channel,
        count = 0
      }
    end
    if v.radio == "radio_5G" and channels_5g[untaint(v.channel)] == nil then
      channels_5g[untaint(v.channel)] = {
        channel = v.channel,
        count = 0
      }
    end
  end
  local t = {
    wl_2g_channel = "rpc.wireless.radio.@radio_2G.channel",
    wl_5g_channel = "rpc.wireless.radio.@radio_5G.channel",
    wl_2g_allowed_channels = "rpc.wireless.radio.@radio_2G.allowed_channels",
    wl_5g_allowed_channels = "rpc.wireless.radio.@radio_5G.allowed_channels"
  }
  content_helper.getExactContent(t)
  web_wlssid_list["2g_channel_in_use"] = t.wl_2g_channel
  web_wlssid_list["5g_channel_in_use"] = t.wl_5g_channel
  web_wlssid_list["wl1_possible_channel_list"] = gsub(t.wl_2g_allowed_channels, " ", ",")
  web_wlssid_list["wl0_possible_channel_list"] = gsub(t.wl_5g_allowed_channels, " ", ",")
  for i,v in ipairs(tab) do
    if not tab[v.paramindex] then
      local bssid = v.index:match("%x%x:%x%x:%x%x:%x%x:%x%x:%x%x")
      if v.radio == "radio_2G" then
        for index, value in pairs(channels_2g) do
          if v.channel == value.channel then
            web_wlssid_list["2g_channel_"..(value.channel).."_bssid_"..(value.count)] = bssid
            web_wlssid_list["2g_channel_"..(value.channel).."_rssi_"..(value.count)] = v.rssi
            web_wlssid_list["2g_channel_"..(value.channel).."_ssid_"..(value.count)] = v.ssid
            value.count = value.count + 1
          end
        end
      end
      if v.radio == "radio_5G" then
        for index,value in pairs(channels_5g) do
          if v.channel == value.channel then
            web_wlssid_list["5g_channel_"..(value.channel).."_bssid_"..(value.count)] = bssid
            web_wlssid_list["5g_channel_"..(value.channel).."_rssi_"..(value.count)] = v.rssi
            web_wlssid_list["5g_channel_"..(value.channel).."_ssid_"..(value.count)] = v.ssid
            value.count = value.count + 1
          end
        end
      end
    end
  end
  return web_wlssid_list
end

local function get_bsslist_columns(type, bsslistData_2G, bsslistData_5G)
  local bsslist_columns ={}
  local bl_2g = content_helper.convertResultToObject(pathwl_ssid_2g, bsslistData_2G or dm.get(pathwl_ssid_2g))
  local bl_5g = content_helper.convertResultToObject(pathwl_ssid_5g, bsslistData_5G or dm.get(pathwl_ssid_5g))
  if type == "radio_2G" or type == "total" then
    for i,v in ipairs(bl_2g) do
      if not bl_2g[v.paramindex] then
        bsslist_columns[#bsslist_columns+1] = {
          radio = "radio_2G",
          index = v.paramindex,
          ssid = v.ssid,
          channel = v.channel,
          rssi = v.rssi,
        }
      end
    end
  end
  if type == "radio_5G" or type == "total" then
    for i,v in ipairs(bl_5g) do
      if not bl_5g[v.paramindex] then
        bsslist_columns[#bsslist_columns+1] = {
          radio = "radio_5G",
          index = v.paramindex,
          ssid = v.ssid,
          channel = v.channel,
          rssi = v.rssi,
        }
      end
    end
  end
  return data_format(bsslist_columns)
end

local service_wlssid_list = {
  name = "wlssid_list"
}

--Added for ui display normally.
service_wlssid_list.set  = function(args)
  return true
end

service_wlssid_list.get  = function(args)
  local rescan = {}
  local bsslistData_2G, bsslistData_5G
  if args.do_scan == "1" then
    rescan["rpc.wireless.radio.@radio_2G.acs.rescan"] = "1"
    rescan["rpc.wireless.radio.@radio_5G.acs.rescan"] = "1"
    dm.set(rescan)
    dm.apply()
    execute("sleep", {"3"})

    --at most 15 times try is introduced to get values from bsslistData
    local step = 0
    while step <= 15 do
      bsslistData_2G = dm.get(pathwl_ssid_2g) or {}
      if next(bsslistData_2G) then
        bsslistData_5G = dm.get(pathwl_ssid_5g) or {}
        if next(bsslistData_5G) then
          break
        end
      end
      execute("sleep", {"2"})
      step = step + 1
    end

    execute("/etc/init.d/hostapd", {"reload"})
  end
  return get_bsslist_columns("total", bsslistData_2G, bsslistData_5G)
end

register(service_wlssid_list)
register(service_wl2g_adv)
register(service_wl5g_adv)
