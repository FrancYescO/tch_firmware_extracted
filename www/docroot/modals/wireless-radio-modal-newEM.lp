--pretranslated: do not change this file
 
local untaint = string.untaint
local session = ngx.ctx.session

-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local ajax_helper = require("web.ajax_helper")
local pairs = pairs
local match, format, next = string.match, string.format, next
local json = require("dkjson")
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "Wireless", "wireless")
local role = session:getrole()

-- Shortcuts to validation helpers to make lines shorter
local getValidateInEnumSelect = post_helper.getValidateInEnumSelect
local validateBoolean = post_helper.validateBoolean
local getOptionalValidation = post_helper.getOptionalValidation
local isTableLoaded = false
local smartWifi = proxy.get("rpc.wireless.SmartWiFi.Active")
smartWifi = smartWifi and untaint(smartWifi[1].value) or ""

-- Take the input options for a listbox, the value and return the associated text
local listboxToText = function(options, value)
  for _, listVal in ipairs(options) do
    if listVal[1] == value then
      return listVal[2]
    end
  end
  return value
end

local getargs = ngx.req.get_uri_args()
local getradio = getargs.radio
local getiface = getargs.iface
local getWifiAnalyzer = getargs.isWifiAnalyzer
local qtnValue = {}

if post_helper.getVariantValue(variantHelper, "qtnMacCheck") then
  qtnValue.qtnMac = "uci.env.var.qtn_eth_mac"
  content_helper.getExactContent(qtnValue)
end

local curradio = "radio_2G"
local curiface = "wl0"
local isExtRemman = "0" -- AP remotely managed, like a TG233 DANT-5 board in AP mode.
local isIntRemman = "0" -- Quantenna
local stbLimit = false
local radio2iface = {}
local is11nStdSelected, is11nStdSelected_5G = false

local standard = {
  radio2G = "uci.wireless.wifi-device.@radio_2G.standard",
  radio5G = "uci.wireless.wifi-device.@radio_5G.standard"
}
content_helper.getExactContent(standard)

if string.match(standard.radio2G, "n") then
  is11nStdSelected = true
elseif string.match(standard.radio5G, "n") then
  is11nStdSelected_5G = true
end
local ssid_details = proxy.get("rpc.wireless.ssid.")
local device_details = content_helper.convertResultToObject("rpc.wireless.ssid.", ssid_details)

-- Returns the ssid name,macaddress, channel, Signal Strength for the selected radio to generate Analyzer graph
local function getDeviceDetails(cradio)
  local ap_details = proxy.get("rpc.wireless.ap.")
  ap_details = content_helper.convertResultToObject("rpc.wireless.ap.", ap_details)
  local ssid_details = {}
  local count = 0
  local ssid, ap, channel_width
  local path = "rpc.wireless.ap."
  for _, intf in ipairs(device_details) do
    if intf["radio"] == cradio and intf["network"] ~= "hotspot" then
      ssid = match(intf.paramindex, "@([^%.]+)")
      count = count + 1
      ssid_details[count] = {}
      ssid_details[count]["ssid"] = intf.ssid
      ssid_details[count]["mac_address"] = intf.mac_address
      ssid_details[count]["channel"] = proxy.get("rpc.wireless.radio.@" ..cradio.. ".channel")[1].value
      channel_width = match(proxy.get("rpc.wireless.radio.@" ..cradio.. ".channel_width")[1].value, "([^%.]+)MHz")
      ssid_details[count]["chan_descr"] = cradio == "radio_2G" and channel_width or ((proxy.get("rpc.wireless.radio.@" ..cradio.. ".channel")[1].value).."/"..channel_width)
      for _, pathVal in ipairs(ap_details) do
         if ssid == pathVal.ssid then
           ap = match(pathVal.paramindex, "@([^%.]+)")
          ssid_details[count]["ap_state"] =  pathVal.admin_state
          ssid_details[count]["ap_isolation"] =  pathVal.ap_isolation
           mac_address_path = path.."@"..ap..".station."
           mac_address_value = content_helper.convertResultToObject(mac_address_path, proxy.get(mac_address_path))
           for _, macAddr in ipairs(mac_address_value) do
             if macAddr.rssi and macAddr.authentication then
               ssid_details[count]["rssi"] = macAddr.rssi or ""
               ssid_details[count]["sec"] = macAddr.authentication or ""
             end
           end
        end
      end
    end
  end
  return ssid_details
end

-- Return the acs data for selected radio to generate Analyzer graph
local function getAcsData(cradio, delay)
  local bsslistData = proxy.get("rpc.wireless.bssid.@" .. cradio .. ".bsslist.") or {}
  --Timeout of 30 secs Delay is introduced to get values from bsslistData when the rescan button is clicked
  if delay then
    local step = 0
    while step <= 10 do
      bsslistData = proxy.get("rpc.wireless.bssid.@" .. cradio .. ".bsslist.") or {}
      if next(bsslistData) then
        break
      end
      ngx.sleep(3)
      step = step + 1
    end
  end
  local ssid_details = getDeviceDetails(cradio)
  bsslistData = content_helper.convertResultToObject("rpc.wireless.bssid.@" .. cradio .. ".bsslist.",bsslistData)
  if post_helper.getVariantValue(variantHelper, "showOwnSSID") then
    for _, ssidVal in ipairs(ssid_details) do
      if ssidVal["ap_state"] == "1" and ssidVal["ap_isolation"] ~= "1" then
        bsslistData[#bsslistData+1] = ssidVal
      end
    end
  end
  local buffer = {}
  local success = json.encode (bsslistData, { indent = false, buffer = buffer})
  if success then
    ngx.header.content_type = "application/json"
    ngx.print(buffer)
    ngx.exit(ngx.HTTP_OK)
  end
end

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "rescan" then
  local cradio = ngx.req.get_post_args().curradio
  local rescan_val = format ('rpc.wireless.radio.@%s.acs.rescan', cradio)
  proxy.set(rescan_val, "1")
  proxy.apply()
  getAcsData(cradio, true)
elseif getWifiAnalyzer and getargs.getAcsData then
  getAcsData(getradio)
end

if post_helper.getVariantValue(variantHelper, "delaySaveOperation") then
  -- "rpc.wireless.radio." returns empty during hostapd restart is in progress,
  -- so introduce delay to hold the save operation until gets valid data from datamodel and also introduce timeout (1 minute)
  -- to break this loop
  local step = 2
  for i = 0, 60, step do
    ngx.sleep(step)
    local radio = proxy.get("rpc.wireless.radio.")
    if (radio and #radio > 0) then
      break
    end
  end
end

local radios = {}
for _, radioVal in ipairs(proxy.getPN("rpc.wireless.radio.", true)) do
  local radio = match(radioVal.path, "rpc%.wireless%.radio%.@([^%.]+)%.")
  if radio then
    radios[#radios + 1] = radio
    local radio_val = getradio and string.match(getradio, radio) or getradio
    if radio == radio_val then
      curradio = radio
    end
  end
end
table.sort(radios)

ajax_helper.handleAjaxQuery({
  phy_rate = "rpc.wireless.radio.@" .. curradio .. ".phy_rate",
  channel = "rpc.wireless.radio.@" .. curradio .. ".channel"
  }, function(content)
  content["phy_rate"] = (content["phy_rate"] and content["phy_rate"] ~= "") and tonumber(content["phy_rate"]) / 1000 .. "Mbps" or ""
end)

local ap_paths = {}
for index, apVal in ipairs(proxy.getPN("rpc.wireless.ap.", true)) do
  ap_paths[index] = apVal.path.."ssid"
end

local wl_list = proxy.get(unpack(ap_paths)) or {}
local wls = {}
local values = ""
for _, apVal in ipairs(wl_list) do
  for _, ssid in ipairs(device_details) do
    if ssid.paramindex == "@".. apVal.value then
     values = ssid.radio
    end
  end
  if values then
    wls[#wls + 1] = {
      radio = values,
      iface = apVal.value
    }
    if (apVal.value == getiface) or (not getiface and apVal.value == curiface) then
      curiface = apVal.value
    end
  end
end
table.sort(wls, function(a, b)
  if ( #radios == 3 ) then
    return a.iface < b.iface
  end
  if a.radio == b.radio then
    return a.iface < b.iface
  else
    return a.radio < b.radio
  end
end)

local radioData ={}
for _, pathVal in ipairs(radios) do
  local path = "rpc.wireless.radio.@" .. pathVal
  local rdata = proxy.get(path..".supported_frequency_bands" ,
  path .. ".remotely_managed",
  path .. ".supported_standards",
  path .. ".integrated_ap",
  path .. ".phy_rate",
  path .. ".country",
  path .. ".channel",
  path .. ".standard",
  path .. ".requested_channel",
  path .. ".requested_channel_width",
  path .. ".capabilities")
  if rdata then
    radioData[pathVal] = {
      supported_frequency_bands = rdata[1].value,
      remotely_managed = rdata[2].value,
      supported_standards = rdata[3].value,
      integrated_ap = rdata[4].value,
      phy_rate = rdata[5].value,
      country = rdata[6].value,
      channel = rdata[7].value,
      standard = rdata[8].value,
      requested_channel = rdata[9].value,
      requested_channel_width = rdata[10].value,
      capabilites = rdata[11].value
    }
  end
end

if radioData[curradio] and radioData[curradio].remotely_managed == "1"  then
  if radioData[curradio].integrated_ap ~= "1" then
    isExtRemman = "1"
  elseif radioData[curradio].integrated_ap == "1" and post_helper.getVariantValue(variantHelper, "quantenna") then
    isIntRemman = "1"
  end
end
local antenna = "2x2"
if radioData[curradio] and radioData[curradio].capabilites ~= "" then
  antenna = string.match(radioData[curradio].capabilites, "%dx%d")
end

local wifi_standard_24GHz = {}
local wifi_standard_5GHz = {}
local supported_standards = radioData[curradio] and radioData[curradio].supported_standards or ""

if radioData[curradio] and radioData[curradio].supported_frequency_bands == "2.4GHz" then
  wifi_standard_24GHz = {
    { "bg", T'802.11b/g'},
    { "bgn", T'802.11b/g/n'}
  }
  if supported_standards == "bgnax" then
    table.remove(wifi_standard_24GHz, 1)
    if post_helper.getVariantValue(variantHelper, "showAdditionalStandards") then
      wifi_standard_24GHz[#wifi_standard_24GHz + 1] = { "gnax", T'802.11g/n/ax'}
      wifi_standard_24GHz[#wifi_standard_24GHz + 1] = { "nax", T'802.11n/ax'}
    end
    wifi_standard_24GHz[#wifi_standard_24GHz + 1] = { "bgnax", T'802.11b/g/n/ax'}
  end
else
  wifi_standard_5GHz = {
    { "an", T'802.11a/n'},
    { "anac", T'802.11a/n/ac'}
  }

  if supported_standards == "anacax" then
    table.remove(wifi_standard_5GHz, 1)
    if post_helper.getVariantValue(variantHelper, "showAdditionalStandards") then
      wifi_standard_5GHz[#wifi_standard_5GHz + 1] = { "nac", T'802.11n/ac'}
      wifi_standard_5GHz[#wifi_standard_5GHz + 1] = { "nacax", T'802.11n/ac/ax'}
      wifi_standard_5GHz[#wifi_standard_5GHz + 1] = { "acax", T'802.11ac/ax'}
    end
    wifi_standard_5GHz[#wifi_standard_5GHz + 1] = { "anacax", T'802.11a/n/ac/ax'}
  end
end

local wifiStandard = {
  standard = "uci.wireless.wifi-device.@radio_5G.standard"
}

local wifi_standard={}
if radioData[curradio] and radioData[curradio].supported_frequency_bands == "5GHz" then
  content_helper.getExactContent(wifiStandard)
  wifi_standard = wifi_standard_5GHz
else
  wifi_standard = wifi_standard_24GHz
end

local cw_40 = {
  {"20", T"20MHz"},
  {"auto", T"Auto (20/40MHz)"}
}

local channelWithNo160MHz = post_helper.getVariantValue(variantHelper, "channelWithNo160MHz")
local cw_160 = {}
local cw_80 = {}

if channelWithNo160MHz then
  cw_80 = {
    {"20",  T"20MHz"},
    {"20/40", T"20/40MHz"},
    {"20/40/80", T"Auto (20/40/80MHz)"}
  }
  cw_160 = {
    {"20",  T"20MHz"},
    {"20/40", T"20/40MHz"},
    {"20/40/80", T"Auto (20/40/80MHz)"}
  }
else
  cw_80 = {
    {"20",  T"20MHz"},
    {"20/40", T"20/40MHz"},
    {"auto", T"Auto (20/40/80MHz)"}
  }
  cw_160 = {
    {"20",  T"20MHz"},
    {"20/40", T"20/40MHz"},
    {"20/40/80", T"20/40/80MHz"},
    {"auto", T"Auto (20/40/80/160MHz)"}
  }
end

local radio5gHighNo160MHz = post_helper.getVariantValue(variantHelper, "radio5gHighNo160MHz")
if radio5gHighNo160MHz and curradio == "radio2" then
  cw_160 = {
    {"20",  T"20MHz"},
    {"20/40", T"20/40MHz"},
    {"20/40/80", T"Auto (20/40/80MHz)"}
  }
end

local cw = {
  ["bg"] = "channelwidth20",
  ["bgn"] = "channelwidth40",
  ["bgnax"] = "channelwidth40",
  ["gnax"] = "channelwidth40",
  ["nax"] = "channelwidth40",
  ["an"] = "channelwidth40",
  ["anac"] = "channelwidth80",
  ["anacax"] = "channelwidth160",
  ["nac"] = "channelwidth80",
  ["nacax"] = "channelwidth160",
  ["acax"] = "channelwidth160"
}

local cwmaps = {
  ["channelwidth20"] = cw_40,
  ["channelwidth40"] = cw_40,
  ["channelwidth80"] = cw_80,
  ["channelwidth160"] = cw_160
}

local cddList = {
  {"1",  T"Auto"},
  {"on", T"On"},
  {"off", T"Off"}
}

local channelwidth = cwmaps[cw[untaint(supported_standards)]]

local function getValidateChannelWidth(channelWidth)
  return function(value, postdata, key)
    local success, msg = getValidateInEnumSelect(channelWidth)
    if success then
      postdata["requested_channel_width"] = postdata[cw[untaint(postdata["standard"])]]
      return true
    else
      return nil, msg
    end
  end
end

-- if the post request is from the small card,
-- we need to set the admin state of the radios other than the current radio
local function getInterfaceEnabled2(value, object, key)
  if not object["fromModal"] then
    object[key] = object["admin_state"]
  else
    object[key] = nil
  end
  return true
end

local pathradio = format("rpc.wireless.radio.@%s.", curradio)
local pathiface = format("rpc.wireless.ssid.@%s.", curiface)

local param = {
  allowed_channels = pathradio .. "allowed_channels"
}

if post_helper.getVariantValue(variantHelper, "platformfield") then
  param.platform =  "uci.wireless.wifi-device.@"..curradio..".type"
end

content_helper.getExactContent(param)
local allowed_channels = { {"auto", T"Auto"} }
for channelVal in string.gmatch(param["allowed_channels"], "%S+") do
  allowed_channels[#allowed_channels + 1] = {channelVal, channelVal}
end

-- If this AP connects to STB, "engineer" role has full access, other roles only have simple stats
if proxy.get(pathiface .. "stb") and proxy.get(pathiface .. "stb")[1].value then
  if proxy.get(pathiface .. "stb")[1].value == "1" then
    if ngx.ctx.session:getrole() ~= "engineer" then
      stbLimit = true
    end
  end
end

local mapParams = {
  admin_state = pathradio .. "admin_state",
  standard = pathradio .. "standard",
  requested_channel = pathradio .. "requested_channel",
  requested_channel_width = pathradio .. "requested_channel_width",
  sgi = pathradio .. "sgi",
  cdd = pathradio .. "cdd",
  stbc = pathradio .. "stbc"
}

local mapValid = {
  admin_state = validateBoolean,
  standard = getValidateInEnumSelect(wifi_standard),
  requested_channel = getValidateInEnumSelect(allowed_channels),
  channelwidth20 = getValidateChannelWidth(cw_40),
  channelwidth40 = getValidateChannelWidth(cw_40),
  channelwidth80 = getValidateChannelWidth(cw_80),
  channelwidth160 = getValidateChannelWidth(cw_160),
  sgi = getOptionalValidation(validateBoolean),
  cdd = function(val, object)
    if object.cdd == "auto" then
      object.cdd = "1"
    end
    return getValidateInEnumSelect(cddList)
  end,
  stbc = getOptionalValidation(validateBoolean)
}

if post_helper.getVariantValue(variantHelper, "frameBursting") then
  mapParams.frame_bursting = pathradio .. "frame_bursting"
  mapValid.frame_bursting = validateBoolean
end

for _, radioVal in pairs(radios) do
  if radioVal ~= curradio then
    mapParams["admin_state_" .. radioVal] = "rpc.wireless.radio.@" .. radioVal .. ".admin_state"
    mapValid["admin_state_" .. radioVal] = getInterfaceEnabled2
  end
end
local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

-- Mac - read only
-- "rpc.wireless.ssid.@wl0." and "rpc.wireless.ssid.@wl1." returns empty during hostapd reload is in progress,
-- so introduce delay to hold the save operation until gets valid data from datamodel and also introduce timeout (1 minute max)
-- to break this loop
local content_ssid = {
  pathiface .. "mac_address",
  pathiface .. "stb"
}
local step = 2
for i = 0, 60, step do
  ngx.sleep(step)
  local content_val = proxy.get(unpack(content_ssid))
  if (content_val and #content_val > 0) then
    content["macaddress"] = content_val[1].value
    content["stb"] = content_val[2].value
    break
  end
end

param = {
  allowed_channels = pathradio .. "allowed_channels"
}
if not post_helper.getVariantValue(variantHelper, "platformfield") then
  param.platform = "uci.wireless.wifi-device.@radio_5G.type"
end
content_helper.getExactContent(param)
allowed_channels = { {"auto", T"Auto"} }
for channelVal in string.gmatch(param["allowed_channels"], "%S+") do
  allowed_channels[#allowed_channels + 1] = {channelVal, channelVal}
end
local UNII3 = allowed_channels[#allowed_channels][1]
if radioData[curradio] then
  for paramIndex, paramVal in pairs(radioData[curradio]) do
    -- Not replace the value that already exists
    if not content[paramIndex] then
      content[paramIndex] = paramVal
    end
  end
end

local function loadInterface()
  local html = {}
  local advanced = {
    group = {
      class = "advanced hide"
    }
  }

  local labelstate = T"Off"
  -- Switch that shows if the Wifi interface is enabled or not
  if not stbLimit then
    html[#html + 1] = ui_helper.createSwitch(T"Enabled", "admin_state", content["admin_state"])
  end
  html[#html + 1] = ui_helper.createLabel(T"Frequency band", content["supported_frequency_bands"] or "")
  -- Show Antenna Setup
  html[#html + 1] = ui_helper.createLabel(T"Antenna", antenna, advanced)
  -- Label that shows the MAC address of the Wifi interface
  html[#html + 1] = ui_helper.createLabel(T"MAC address", content["macaddress"])
  -- Select the standard to use
  local stdattributes = {
    group = {
      class = "advanced hide"
    },
    select = {
      class = "monitor-changes"
    }
  }

  if radioData[curradio] and radioData[curradio].supported_frequency_bands == "5GHz" and radioData[curradio].integrated_ap == "1" and post_helper.getVariantValue(variantHelper, "quantenna") then
    html[#html + 1] = ui_helper.createLabel(T"Standard", listboxToText(wifi_standard, wifiStandard.standard), stdattributes)
  elseif radioData[curradio] and radioData[curradio].supported_frequency_bands == "5GHz" then
    html[#html + 1] = ui_helper.createInputSelect(T"Standard", "standard", wifi_standard, content["standard"], stdattributes)
  elseif not stbLimit then
    html[#html + 1] = ui_helper.createInputSelect(T"Standard", "standard", wifi_standard, content["standard"], stdattributes)
  else
    html[#html + 1] = ui_helper.createLabel(T"Standard", listboxToText(wifi_standard, content["standard"]), stdattributes)
  end

  -- Current speed of the Wifi interface
  html[#html + 1] = ui_helper.createLabel(T"Speed", (content["phy_rate"] and content["phy_rate"] ~= "") and tonumber(content["phy_rate"])/1000 .. "Mbps" or "", { span = {
    id = "phy_rate",
    ["data-ajaxrefresh"] = "5"
  }})

  -- Choose which channel to use
  if not stbLimit and (smartWifi ~= "1") then
    html[#html + 1] = ui_helper.createInputSelect(T"Channel", "requested_channel", allowed_channels, content["requested_channel"])
  end

  -- Show which region is being used
  html[#html + 1] = ui_helper.createLabel(T"Region", content["country"] or "", advanced)
  html[#html + 1] = ui_helper.createLabel(T"Current channel", content["channel"] or "", { span = {
    id = "channel",
    ["data-ajaxrefresh"] = "5"
  }})
  if not stbLimit then
    html[#html + 1] ='<div class ="advanced hide">'
    local cw20attributes  = {
      group = {
        class ="hide monitor-standard monitor-b monitor-bg"
      }
    }
    if (smartWifi == "0" or smartWifi == "") then
      html[#html + 1] = ui_helper.createInputSelect(T"Channel width", "channelwidth20", cw_40, content["requested_channel_width"], cw20attributes)
      local cw40attributes  = {
        group = {
          class ="hide monitor-standard monitor-bgn monitor-bgnax monitor-an monitor-gnax monitor-nax"
        }
      }

      html[#html + 1] = ui_helper.createInputSelect(T"Channel width", "channelwidth40", cw_40, content["requested_channel_width"], cw40attributes)
      local cw80attributes  = {
        group = {
          class ="hide monitor-standard monitor-anac monitor-nac"
        }
      }

      html[#html + 1] = ui_helper.createInputSelect(T"Channel width", "channelwidth80", cw_80, content["requested_channel_width"], cw80attributes)
      local cw160attributes  = {
        group = {
          class ="hide monitor-standard monitor-anacax monitor-nacax monitor-acax"
        }
      }
      local cw160alert = {
        alert = {
          class = "alert alert-warning hide",
          id = "channel160alert"
        }
      }

      html[#html + 1] = ui_helper.createInputSelect(T"Channel width", "channelwidth160", cw_160, content["requested_channel_width"], cw160attributes)
      html[#html + 1] = ui_helper.createAlertBlock(T"Auto (20/40/80/160 MHz): In this mode all channels of your region can be used including the weather channels and this can cause longer scan time of up to 10 mins", cw160alert)
      html[#html + 1] = '</div>'

      if isExtRemman ~= "1" and isIntRemman ~= "1" then
        local stdNSupportedParamAttr = {
          group = {
            class = "advanced hide"
          },
          switch = {
            class = "stdNSupportedParam"
          },
          select = {
            class = "stdNSupportedParam"
          }
        }

        if post_helper.getVariantValue(variantHelper, "qtnMacCheck") then
          if radioData[curradio] and radioData[curradio].supported_frequency_bands == "2.4GHz" or qtnValue.qtnMac == "" then
            html[#html + 1] = ui_helper.createSwitch(T"Short Guard Interval", "sgi", content["sgi"], stdNSupportedParamAttr)
          end
        else
          html[#html + 1] = ui_helper.createSwitch(T"Short Guard Interval", "sgi", content["sgi"], stdNSupportedParamAttr)
        end
        html[#html + 1] = ui_helper.createInputSelect(T"Cyclic-Delay Diversity", "cdd", cddList, content["cdd"])
        html[#html + 1] = ui_helper.createSwitch(T"Space Time Block Code", "stbc", content["stbc"], stdNSupportedParamAttr)
        if (radioData[curradio] and (radioData[curradio].supported_frequency_bands == "2.4GHz" or radioData[curradio].supported_frequency_bands == "5GHz") or "" and param.platform == "broadcom") and post_helper.getVariantValue(variantHelper, "frameBursting") then
          html[#html + 1] = ui_helper.createSwitch(T"Frame Bursting", "frame_bursting", content["frame_bursting"] or "", stdNSupportedParamAttr)
        end
      end
    end
  end
  return html
end

local function loadAnalyzer()
  html = {}
  local freq = "2"
  if radio == "radio_5G" then freq = "5" or "2" end
  html[#html + 1] = format([[
  <div id = "ReScan_%s" style = "width:650px;text-align:right;margin-right:20px;"><div id = "rescanbtn" class = "btn btn-primary btn-large">%s</div></div>]], freq, T"Re-scan")
  html[#html + 1] = format([[
  <div id = confirming-msg_%s class = "alert hide"> %s </div> ]],
  freq, T"If you use this tool, devices connected will be disconnected and will be able to connect after 1 minute.")
  html[#html + 1] = format([[
  <div id = "rescan-changes_%s" class = "hide">
  <div id = "rescan-cancel_%s" class = "btn">%s</div>
  <div id = "rescan-confirm_%s" class = "btn btn-primary" data-dimiss = "modal">%s</div></div>]],
  freq, freq, T"Cancel", freq, T"Accept")
  return html
end

local wifi_analyzer_disable = proxy.get("uci.wireless.wifi.@global.wifi_analyzer_disable")
ngx.print(ui_helper.createHeader(T"Wireless", true, false))   ngx.print('\
\
<div class="modal-body update">\
  ');  local lp = require("web.lp")
  if post_helper.getVariantValue(variantHelper, "navTab") then
    lp.setpath("/www/snippets/")
    lp.include("tabs-wireless.lp")
  end  ngx.print('\
  <form class="form-horizontal" method="post" action="');  ngx.print( ngx.var.request_uri ); ngx.print('">\
  ');  
    -- Do not display the navlist on the list if no SSID
    local navlist = 0
    if post_helper.getVariantValue(variantHelper, "navlistCheck") then
      navlist = 1
    end

    if #wls > navlist then  ngx.print('\
      <div class="span2">\
        <ul class="nav nav-list">\
          ');  local html = {}
          local prevradio = ""
          html[#html + 1] = format('<li class="nav-header">%s</li>', T"RADIO'S")
          local count_2, count_5, count = 0, 0, 0
          for index, radioVal in ipairs(wls) do
            prevradio = radioVal.radio
            local active = ""
            if radioVal.radio == curradio and not getWifiAnalyzer then
              active = "active"
            end
            local url = "modals/wireless-radio-modal-newEM.lp?radio=" .. radioVal.radio.."&iface=" .. radioVal.iface
            if radioVal.radio == "radio_2G" and count ~= 1 then
              html[#html + 1] = format('<li class = "%s"><a  id = "Wireless_Tab_%s" href = "#" data-remote = "%s">%s</a></li>', active, index, url, "2.4 GHz")
              count = 1
            elseif radioVal.radio == "radio_5G" and count_5 ~= 1 then
              local radiotype = (#radios) == 3 and "5 GHz Low" or "5 GHz"
              html[#html+1] = format('<li class = "%s"><a id = "Wireless_Tab_%s" href = "#" data-remote = "%s">%s</a></li>', active, index, url, radiotype)
              count_5 = 1
            elseif (#radios) == 3 and radioVal.radio == "radio2" and count_2 ~= 1 then
              html[#html+1] = format('<li class = "%s"><a id = "Wireless_Tab_%s" href = "#" data-remote = "%s">%s</a></li>', active, index, url, "5 GHz High")
              count_2 = 1
            end
          end

          -- If wifi analyzer enabled, draw it
          if wifi_analyzer_disable and wifi_analyzer_disable[1].value ~= "1" and post_helper.getVariantValue(variantHelper, "wifiAnalyzer") then
            if smartWifi ~= "1" then
              html[#html+1] = format('<li class="nav-header">%s</li>', T"Wireless Data")
            end
            local freq = ""
            local suffix = ""
            local link_id = ""
            local isDuplicate = {}
            for index, radioVal in ipairs(wls) do
              if not isDuplicate[radioVal.radio] and (radioVal.radio == "radio_5G" or radioVal.radio == "radio_2G" or radioVal.radio == "radio2") then
                if radioVal.radio == "radio_2G" then
                  freq = "2.4"
                  link_id = "2"
                else
                  freq = "5"
                  link_id = "5"
                end
                if #radios == 3 then
                  if radioVal.radio == "radio_5G" then
                    suffix = T"Low"
                  elseif radioVal.radio == "radio2" then
                    suffix = T"High"
                  end
                end
                local active = ""
                if getWifiAnalyzer == radioVal.iface then
                  active = "active"
                  radio = radioVal.radio
                end
                local url = "modals/wireless-radio-modal-newEM.lp?radio=" .. radioVal.radio .. "&isWifiAnalyzer=" .. radioVal.iface
                if smartWifi ~= "1" then
                  html[#html+1] = format('<li class = "%s"><a href = "#" data-remote = "%s" id = "wifianalyzer_%s%s">%s %s GHz %s</a></li>', active, url, freq, suffix, T"Analyzer", freq, suffix )
                end
                link_id = link_id .. suffix
                html[#html + 1] = format([[
                  <div><div id = linkconfirming-msg_%s class = "alert hide"> %s </div> ]],
                  link_id, T"If you use this tool, devices connected will be disconnected and will be able to connect after 1 minute.")
                html[#html + 1] = format([[
                  <div id = "linkrescan-changes_%s" class = "hide">
                    <div id = "linkrescan-cancel_%s" class = "btn">%s</div>
                    <a id = "linkrescan-confirm_%s" class = "btn btn-primary" href="#" data-remote = "%s">%s</a>
                  </div></div>
                ]],
                link_id, link_id, T"Cancel", link_id, url, T"Accept")
              end
              isDuplicate[radioVal.radio] = true
            end
          end
          ngx.print(html)   ngx.print('\
        </ul>\
      </div>\
    ');  end   ngx.print('\
    <div class = "span6">\
      ');  if not getWifiAnalyzer then
        ngx.print(ui_helper.createMessages(message_helper.popMessages()))   ngx.print('\
        <fieldset>\
          ');  ngx.print(loadInterface())   ngx.print('\
        </fieldset>\
      ');  else
        --wifi analyzer handler
        local uri = ngx.var.uri
        if ngx.var.args and string.len(ngx.var.args) > 0 then
          uri = uri .. "?" .. ngx.var.args
        end   ngx.print('\
        <form id = "wifiForm" class = "form-horizontal" method = "post" action = "');  ngx.print(uri); ngx.print('">\
          ');  if radio == "radio_2G" then   ngx.print('\
            <div class = "span6">\
          ');  else   ngx.print('\
            <div class = "span6" style = "margin-left:0;">\
          ');  end   ngx.print('\
          <fieldset>\
            <legend>');  ngx.print( T"Wifi Analyzer" ); ngx.print('</legend>\
            <div style = "display:block;" class = "alert-info hide">');  ngx.print(T"Please press Rescan button to view the updated wifi list"); ngx.print('</div></br>\
            <div id = "analyzerloader" style = "height:100px"><img src = "/img/loading.gif"></img></div>\
            <div id = "analyzerGraph" class = "hide">\
              ');  ngx.print( T"The below chart shows the results of the latest scan of your local area from your gateway." ); ngx.print('\
              ');  if radio == "radio_2G" then   ngx.print('\
                <canvas id = "wrapper" width = "720px" height = "400px" style = "border:1px solid #c3c3c3;">\
              ');  else   ngx.print('\
                ');  if (tonumber(UNII3) > 144) then   ngx.print('\
                  <canvas id = "wrapper" width = "890px" height = "400px" style = "border:1px solid #c3c3c3;">\
                ');  else   ngx.print('\
                  <canvas id = "wrapper" width = "740px" height = "400px" style = "border:1px solid #c3c3c3;">\
                ');  end   ngx.print('\
              ');  end   ngx.print('\
              ');  ngx.print( T"Please update your browser to use this page." ); ngx.print('\
              </canvas>\
              ');  ngx.print(loadAnalyzer())   ngx.print('\
            </div>\
            <div id = "key" style = "width: 700px;"></div>\
            <div id = "analyzerloader1" style = "height:100px"><img src = "/img/loading.gif"></img></div>\
          </fieldset>\
          </div>\
        </form>\
        <div id = "ssid_info" class = "smallcard span4" style = "left: 32%; margin: 0px; border-radius: 13px;display:none;height:254px;top:480px">\
          <div class = "header" style = "margin-bottom: 0px;">\
            <div class = "header-title pull-left">\
              <p class = "ssidinfo_poptitle">');  ngx.print(T"More Details"); ngx.print('</p>\
            </div>\
          </div>\
          <div id = "ssidInfo_Poptxt" class = "content" style = "overflow-y:auto ; height:140px;">\
            <div class = "deviceinfoline"><span class = "hostinfoleft">');  ngx.print(T"SSID Name"); ngx.print('</span><span class = "hostinforight" id = "ssidName"></span></div>\
            <div class = "deviceinfoline"><span class = "hostinfoleft">');  ngx.print(T"MAC Address"); ngx.print('</span><span class = "hostinforight" id = "macAddrCh"></span></div>\
            <div class = "deviceinfoline"><span class = "hostinfoleft">');  ngx.print(T"Signal Strength(dBm)"); ngx.print('</span><span class = "hostinforight" id = "signalStrength"></span></div>\
            <div class = "deviceinfoline"><span class = "hostinfoleft">');  ngx.print(T"Channel"); ngx.print('</span><span class = "hostinforight" id = "channelInfo"></span></div>\
            <div class = "deviceinfoline"><span class = "hostinfoleft">');  ngx.print(T"Channel Width"); ngx.print('</span><span class = "hostinforight" id = "chWidth"></span></div>\
            <div class = "deviceinfoline"><span class = "hostinfoleft">');  ngx.print(T"Protection Mode"); ngx.print('</span><span class = "hostinforight" id = "protMode"></span></div>\
          </div>\
          <div class = "modal-footer" style = "font-size: 15px;padding-top:6px;padding-bottom:6px;">\
            <div id = "modal-no-change">\
              <div id = "moreDetails-btn-ok" class = "btn btn-primary">');  ngx.print(T"Close"); ngx.print('</div>\
            </div>\
          </div>\
        </div>\
\
        <script>\
          var radio = "');  ngx.print(radio); ngx.print('";\
          var UNII3 = "');  ngx.print(UNII3); ngx.print('";\
          var networkName = "');  ngx.print( T'Network Name (SSID)'); ngx.print('";\
          var channel = "');  ngx.print( T'Channel' ); ngx.print('";\
          var fortyMHz = "');  ngx.print( T'40MHz'); ngx.print('";\
          var eightyMHz = "');  ngx.print( T'80MHz'); ngx.print('";\
          var signalStrength = "');  ngx.print( T'Signal Strength (RSSI)'); ngx.print('";\
          var rescan = "');  ngx.print(T"Re-scanning"); ngx.print('...";\
          var getWifiAnalyzer = "');  ngx.print(getWifiAnalyzer); ngx.print('";\
          var graphGeneration = ');  ngx.print(post_helper.getVariantValue(variantHelper, "graphGeneration")); ngx.print(';\
          var channelList = ');  ngx.print(post_helper.getVariantValue(variantHelper, "channelList")); ngx.print(';\
          var isextenderSupported = false;\
        </script>\
        <script src = "/js/wireless-analyzer-newEM.js"></script>\
        ');  --End of wifi analyzer
      end  ngx.print('\
      ');  -- Do not display the navlist on the list if no SSID
      if #wls > 0 then   ngx.print('\
       </div>\
     ');  end   ngx.print('\
  </form>\
</div>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
<script>\
  var curiface = "');  ngx.print(curiface); ngx.print('";\
  var curradio = "');  ngx.print(curradio); ngx.print('";\
  var currentRole = "');  ngx.print(role); ngx.print('";\
  var helpmsg = ');  ngx.print(json.encode(helpmsg)); ngx.print(';\
  var channelWithNo160MHz = "');  ngx.print(channelWithNo160MHz); ngx.print('";\
  var channelWidth = "');  ngx.print(content["requested_channel_width"]); ngx.print('";\
  var smartwifivalue = "');  ngx.print(smartWifi); ngx.print('";\
  var smartwifiphasevalue = "');  ngx.print(smartWifiPhase); ngx.print('";\
  var smartWifiMsg = \'');  ngx.print(T"Your Smart Wi-Fi service is active and managing your existing Wi-Fi and Parental Control settings. You can override your Wi-Fi and Parental settings in the Smart Wi-Fi App."); ngx.print('\';\
  var smartwifi = ');  ngx.print(post_helper.isFeatureEnabled("smartwifi")); ngx.print(';\
\
  function stdSpecificCustomisation(value) {\
    var pattern =  new RegExp(/n/);\
    if (!pattern.test(value)) {\
      ');  is11nStdSelected = false   ngx.print('\
      $(".stdNSupportedParam").addClass("disabled").attr("disabled", true);\
      $("#cdd option:not(:selected)").attr("disabled", true);\
    }\
    else {\
      ');  is11nStdSelected = true   ngx.print('\
      $(".stdNSupportedParam").removeClass("disabled").removeAttr("disabled", true);\
      $("#cdd option:not(:selected)").attr("disabled", false);\
    }\
  }\
</script>\
<script src = "/js/wireless-radio-modal-newEM.js"></script>\
'); 