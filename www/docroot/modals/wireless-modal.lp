--pretranslated: do not change this file
 
local istainted = string.istainted
local untaint_mt = require("web.taint").untaint_mt
local setmetatable = setmetatable
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
local match, format, next, lower = string.match, string.format, next, string.lower
local bandsteer_helper = require("bandsteer_helper")
local isBaseIface = bandsteer_helper.isBaseIface
local disableBandSteer = bandsteer_helper.disableBandSteer
local json = require("dkjson")
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "Wireless", "wireless")
local timhelper = post_helper.getVariantValue(variantHelper, "helperFunction") and require("tim_helper") or ""
local role = session:getrole()
local currentuser = session:getusername()

-- Shortcuts to validation helpers to make lines shorter
local getValidationIfPropInList = post_helper.getValidationIfPropInList
local getValidateInEnumSelect = post_helper.getValidateInEnumSelect
local validateBoolean = post_helper.validateBoolean
local validateNonEmptyString = post_helper.validateNonEmptyString
local validateStringIsIP = post_helper.validateStringIsIP()
local validateStringIsPort = post_helper.validateStringIsPort
local getOptionalValidation = post_helper.getOptionalValidation
local getConditionalValidation = post_helper.getConditionalValidation
local getAndValidation = post_helper.getAndValidation
local validatePSK = post_helper.validatePSK
local getValidateStringLengthInRange = post_helper.getValidateStringLengthInRange
local isTableLoaded = false
local smartWifi = proxy.get("rpc.wireless.SmartWiFi.Active")
smartWifi = smartWifi and untaint(smartWifi[1].value) or ""
local smartWifiPhase = proxy.get("rpc.wireless.SmartWiFi.Phase")
smartWifiPhase = smartWifiPhase and untaint(smartWifiPhase[1].value) or ""
local validateWEP = post_helper.validateWEP
local validateWPSPIN = post_helper.validateWPSPIN
if post_helper.getVariantValue(variantHelper, "helperFunction") then
  validateWEP = timhelper.validateWEP
  validateWPSPIN = timhelper.validateWPSPIN
end
local validateStringIsIPv6 = post_helper.validateStringIsIP(6)
local getOrValidation = post_helper.getOrValidation
local getValidateStringISIP = getOrValidation(validateStringIsIP, validateStringIsIPv6)
local wpa_list = {"wpa2", "wpa-wpa2"}
local validateIfProp_IP = getValidationIfPropInList(getValidateStringISIP, "security", wpa_list)
local validateIfProp_port = getValidationIfPropInList(validateStringIsPort, "security", wpa_list)
local validateQTN = post_helper.validateQTN
local validateLXC = post_helper.validateLXC

-- Take the input options for a listbox, the value and return the associated text
local listboxToText = function(options, value)
  for _, v in ipairs(options) do
    if v[1] == value then
      return v[2]
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
local curap = "ap0"
local isguest = "0"
local isExtRemman = "0" -- AP remotely managed, like a TG233 DANT-5 board in AP mode.
local isIntRemman = "0" -- Quantenna
local stbLimit = false
local radio2iface = {}
local is11nStdSelected, is11nStdSelected_5G = false

local standard = {
  standard_2G = "uci.wireless.wifi-device.@radio_2G.standard",
  standard_5G = "uci.wireless.wifi-device.@radio_5G.standard",
}
content_helper.getExactContent(standard)

if string.match(standard.standard_2G, "n") then
  is11nStdSelected = true
elseif string.match(standard.standard_5G, "n") then
  is11nStdSelected_5G = true
end

if post_helper.getVariantValue(variantHelper, "todConfigFlush") then
  --Section to flush the tod config
  --When timer data is not defined in action section of tod config, then corresponding action, wifitod, and ap section will be deleted

  local tod_action_path = "uci.tod.action."
  local action_list = content_helper.convertResultToObject(tod_action_path, proxy.get(tod_action_path))

  for  _ , v in ipairs(action_list) do
    if v["timers.@1.value"] == "" then
      local param_index = v["paramindex"]:match("action(.+)")
      if param_index then
        proxy.del(format("uci.tod.action.@action%s.", param_index))
        proxy.del(format("uci.tod.ap.@ap%s.", param_index))
        proxy.del(format("uci.tod.wifitod.@wifitod%s.", param_index))
      end
    end
  end
end

local function getDeviceDetails(cradio)
  local device_details = proxy.get("rpc.wireless.ssid.")
  device_details = content_helper.convertResultToObject("rpc.wireless.ssid.", device_details)
  local ap_details = proxy.get("rpc.wireless.ap.")
  ap_details = content_helper.convertResultToObject("rpc.wireless.ap.", ap_details)
  local ssid_details = {}
  local count = 0
  local ssid, ap, channel_width
  local path = "rpc.wireless.ap."
  for _, v in ipairs(device_details) do
    if v["radio"] == cradio then
      ssid = match(v.paramindex, "@([^%.]+)")
      count = count+1
      ssid_details[count]={}
      ssid_details[count]["ssid"] = v.ssid
      ssid_details[count]["mac_address"] = v.mac_address
      ssid_details[count]["channel"] = proxy.get("rpc.wireless.radio.@" ..cradio.. ".channel")[1].value
      channel_width = match(proxy.get("rpc.wireless.radio.@" ..cradio.. ".channel_width")[1].value, "([^%.]+)MHz")
      ssid_details[count]["chan_descr"] = cradio == "radio_2G" and channel_width or ((proxy.get("rpc.wireless.radio.@" ..cradio.. ".channel")[1].value).."/"..channel_width)
      for _, pathVal in ipairs(ap_details) do
         if ssid == pathVal.ssid then
           ap = match(pathVal.paramindex, "@([^%.]+)")
           mac_address_path = path.."@"..ap..".station."
           mac_address_value = content_helper.convertResultToObject(mac_address_path, proxy.get(mac_address_path))
           for _,macAddr in  ipairs(mac_address_value) do
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
  local bsslistData = proxy.get("rpc.wireless.bssid.@" .. cradio .. ".bsslist.")
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
  for _, v in ipairs(ssid_details) do
    bsslistData[#bsslistData+1] = v
  end
  local buffer = {}
  local success = json.encode (bsslistData, { indent = false, buffer = buffer})
  if success then
    ngx.header.content_type = "application/json"
    ngx.print(buffer)
    ngx.exit(ngx.HTTP_OK)
  end
end

if ngx.req.get_method() == "POST" and  ngx.req.get_post_args().action =="rescan" then
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
  for i=0, 60, step do
    ngx.sleep(step)
    local radio = proxy.get("rpc.wireless.radio.")
    if (radio and #radio > 0) then
      break
    end
  end
end

local radios = {}
for _, v in ipairs(proxy.getPN("rpc.wireless.radio.", true)) do
  local radio = match(v.path, "rpc%.wireless%.radio%.@([^%.]+)%.")
  if radio then
    radios[#radios + 1] = radio
    if radio == getradio then
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

local fonPath = "uci.hotspotd.wifi-iface."
local fonIfaces = content_helper.convertResultToObject(fonPath .. "@.", proxy.get(fonPath))
local ssidMap = {}
for _, v in ipairs(fonIfaces) do
  local iface = format("%s", v.iface)
  ssidMap[iface] = true
end

local pIface = "uci.wireless.wifi-iface."
local availableWirelessInterfaces = content_helper.convertResultToObject(pIface .. "@.", proxy.get(pIface))
local wls = {}
for _, v in ipairs(availableWirelessInterfaces) do
  if not ssidMap[v.paramindex] and v.backhaul ~= "1" then
    wls[#wls+1] = {
      radio = v.device,
      ssid = v.ssid,
      iface = v.paramindex
    }
    if v.paramindex == getiface then
      curiface = v.paramindex
    end
    -- For each radio, we store the "shortest" iface name (that should be the main SSID)
    if not radio2iface[v.device] or string.len(v.paramindex) < string.len(radio2iface[v.device]) then
      radio2iface[v.device] = v.paramindex
    end
  end
end
table.sort(wls, function(a,b)
  if a.radio == b.radio then
    return a.iface < b.iface
  else
    return a.radio < b.radio
  end
end)

local bandsteeriface = bandsteer_helper.getBandSteerPeerIface(curiface)

local pIfaceNetwork = proxy.get("uci.wireless.wifi-iface.@".. curiface ..".network")[1].value or ""

local ap_paths = {true}
for i, v in ipairs(proxy.getPN("rpc.wireless.ap.", true)) do
  ap_paths[i] = v.path.."ssid"
end

local wl_list = proxy.get(unpack(ap_paths)) or {}
local ap_list = "uci.wireless.wifi-ap."
local apContent = content_helper.convertResultToObject(ap_list, proxy.get(ap_list))
local wls = {}
for _, v in ipairs(wl_list) do
  local path = "rpc.wireless.ssid.@" .. v.value
  local values = proxy.get(path .. ".radio" , path .. ".ssid",path .. ".stb", path .. ".ap_display_name")
  if values ~= nil then
    wls[#wls + 1] = {
      radio = values[1].value,
      ssid = values[2].value,
      iface = v.value,
      stb = values[3].value,
      ap_display_name = values[4].value
    }

    for _, apValue in ipairs(apContent) do
      if apValue.iface == v.value then
        wls[#wls].ap = apValue.paramindex:match("(%w+)")
      end
    end

    if (v.value == getiface) or (not getiface and v.value == curiface) then
      curiface = v.value
      curap = match(v.path, "rpc%.wireless%.ap%.@([^%.]+)%.")
      isguest = proxy.get(v.path .. "ap_isolation") and proxy.get(v.path .. "ap_isolation")[1].value or ""
      cur_ssid = values[2].value
    end
  end
end
table.sort(wls, function(a,b)
  if a.radio == b.radio then
    return a.iface < b.iface
  else
    return a.radio < b.radio
  end
end)


if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SAVE" then
  local postargs = ngx.req.get_post_args()
  local success = false
  if postargs.wpa3 and postargs.security and string.match(postargs.security, "wpa3") then
    success = proxy.set("rpc.wireless.ap.@" .. curap  .. ".security.wpa_psk_passphrase", postargs.wpa3)
    success = proxy.set("uci.wireless.wifi-ap-credential.@" .. curap .. "_credential0.passphrase", postargs.wpa3)
    if postargs.security == "wpa2-wpa3-psk" then
      success = proxy.set("uci.wireless.wifi-ap.@" .. curap  .. ".pmf", "enabled")
    elseif postargs.security == "wpa3-psk" then
      success = proxy.set("uci.wireless.wifi-ap.@" .. curap  .. ".pmf", "required")
    end
  else
    success = proxy.set("uci.wireless.wifi-ap.@" .. curap  .. ".pmf", "disabled")
  end

  if success then
    proxy.apply()
  end
end

local wirelessap = "rpc.wireless.ap."
local wirelessContentAp = content_helper.convertResultToObject(wirelessap .. "@.", proxy.get(wirelessap))
local wps_ssid, wps_radio
for _, v in ipairs(wirelessContentAp) do
  if v.ssid == curiface then
    curap = v.paramindex
    isguest = v.ap_isolation
  elseif v["wps.admin_state"] == "1" then
    wps_ssid = wps_ssid or {}
    wps_radio = proxy.get(format("rpc.wireless.ssid.@%s.radio", v.ssid))
    wps_radio = wps_radio and wps_radio[1].value or ""
    wps_ssid[untaint(wps_radio)] = proxy.get(format("rpc.wireless.ssid.@%s.ssid", v.ssid))
    wps_ssid[untaint(wps_radio)] = wps_ssid[untaint(wps_radio)] and wps_ssid[untaint(wps_radio)][1].value or {}
  end
end

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "set_reg" then
  local content_acl ={
    state = "rpc.wireless.ap.@"..curap..".acl.state"
  }
  content_helper.getExactContent(content_acl)
  local acl_ap = ngx.req.get_post_args().curap
  local content_acl_state = format('%s', content_acl["state"])
  if content_acl_state ~= "register" then
    local acl_ap_url1 = format ('rpc.wireless.ap.@%s.acl.mode', acl_ap)
    proxy.set(acl_ap_url1, "register" )
    proxy.apply()
    ngx.sleep(10)
  end
  local acl_ap_url = format ('rpc.wireless.ap.@%s.acl.reg', acl_ap)
  proxy.set(acl_ap_url, "1" )
  ngx.print('{ "success":"true" }')
  proxy.apply()
  ngx.exit(ngx.HTTP_OK)
end

if ngx.req.get_method() == "GET" and ngx.req.get_uri_args().action == "get_reg_status"  then
  local acl_ap = ngx.req.get_uri_args().curap
  local reg_status = proxy.get("rpc.wireless.ap.@"..acl_ap..".acl.state")
  reg_status = reg_status and reg_status[1].value or ""
  ngx.print(reg_status)
  ngx.exit(ngx.HTTP_OK)
end

-- The function can be reused to load the ACL mac list by ajax and normal request
-- Normal request means - Adding, Editing and Deleting the ACL mac address entries by normal POST request
local function loadAclList(aclmode, action)
  local macvalid = {}
  local html={}
  local acl_columns = {
    {
      header = T"MAC Address",
      name = "acl_macaddress",
      param = "value",
      type = "text",
      attr = { input = { class = "span2", maxlength = "17" } }
    }
  }
  local function validateAclMac(value, object, key)
    return post_helper.validateAclMac(value, object, key, curap)
  end
  if post_helper.getVariantValue(variantHelper, "validateLXCCheck") then
    macvalid.acl_macaddress = getAndValidation(validateAclMac, validateQTN, validateLXC)
  else
    macvalid.acl_macaddress = getAndValidation(validateAclMac, validateQTN)
  end
  local acl_whitelist_options = {
    tableid = "acl_whitelist",
    basepath = format("uci.wireless.wifi-ap.@%s.acl_accept_list.@.",curap),
    createMsg = T"Add new MAC address"
  }
  if aclmode == "register" then
    acl_whitelist_options["tableid"] = "acl_register"
  end
  local acl_whitelist_data, acl_whitelist_helpmsg = post_helper.handleTableQuery(acl_columns, acl_whitelist_options, nil, nil, macvalid)
  local acl_blacklist_options = {
    tableid = "acl_blacklist",
    basepath = format("uci.wireless.wifi-ap.@%s.acl_deny_list.@.",curap),
    createMsg = T"Add new MAC address"
  }

  acl_blacklist_filter = function(data)
    local curap_path = "uci.wireless.wifi-ap.@" .. curap
    local aclmode_value = proxy.get(curap_path .. ".acl_mode")
    local aclmac_value = proxy.get(curap_path.. ".acl_deny_list.")
    for aclMacData, aclMacDataValue in ipairs(aclmac_value) do
      for aclMode, aclModeValue in ipairs(aclmode_value) do
        if aclmode == "disabled" then
          proxy.del(format(curap_path..".acl_deny_list.", acl_deny_list_value))
          proxy.apply()
          return nil
        end
      end
    end
    return true
  end
  local acl_blacklist_data, acl_blacklist_helpmsg = post_helper.handleTableQuery(acl_columns, acl_blacklist_options, acl_blacklist_filter, nil, macvalid)
  local whitelistclass = {
    group = {
      class = "monitor-acl_mode monitor-lock monitor-register"
    }
  }
  if aclmode == "unlock" or aclmode == "disabled" then
    whitelistclass["group"].style = "display:none;"
  end
  if #acl_whitelist_data < 1 and action ~= "POST" then
    whitelistclass["group"].style = "display:none;"
    whitelistclass ["span"] = {id = "Address_list_Whitelistclass"}
    html[#html+1] = ui_helper.createLabel("", T"MAC Address list is empty", whitelistclass, nil)
    acl_columns[1].header=""
  else
    acl_columns[1].header = format("<span style=\"font-weight:normal;\">%s</span>", T"MAC Address")
  end
  html[#html+1] = ui_helper.createTable(acl_columns, acl_whitelist_data, acl_whitelist_options, whitelistclass, acl_whitelist_helpmsg)
  local blacklistclass = {
    group = {
      class = "monitor-acl_mode monitor-unlock"
    }
  }
  if #acl_blacklist_data < 1 and  action ~= "POST" then
    blacklistclass["group"].style = "display:none;"
    blacklistclass ["span"] = {id = "Address_list_Blacklistclass"}
    html[#html+1] =  ui_helper.createLabel("", T"MAC Address list is empty", blacklistclass, nil)
    acl_columns[1].header=""
  else
    acl_columns[1].header = format("<span style=\"font-weight:normal;\">%s</span>", T"MAC Address")
  end
  if aclmode == "lock" or aclmode == "register" or aclmode == "disabled" then
    blacklistclass["group"].style = "display:none;"
  end
  html[#html+1] = ui_helper.createTable(acl_columns, acl_blacklist_data, acl_blacklist_options, blacklistclass, acl_blacklist_helpmsg)
  return html
end

-- Load the ACL Mac Address list by ajax get request
if getargs.action=="GET_ACL_MAC_LIST" then
  local acl_mode = getargs.acl_mode
  ngx.print(loadAclList(acl_mode, "GET"))
  ngx.exit(ngx.HTTP_OK)
end

local radioData ={}
for _, v in ipairs(radios) do
  local path = "rpc.wireless.radio.@" .. v
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
  if rdata ~= nil then
    radioData[v] = {
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
      capabilites = rdata[11].value,
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

-- We're defining the listbox enums here to be able to use them to validate the input
-- Listbox that shows the supported WiFi standards


local wifi_standard_24GHz = {}
local wifi_standard_5GHz = {}
local supported_standards = radioData[curradio] and radioData[curradio].supported_standards or ""

if radioData[curradio] and radioData[curradio].supported_frequency_bands == "2.4GHz" then
     wifi_standard_24GHz = {
      { "bg", T'802.11b/g'},
      { "bgn", T'802.11b/g/n'},
     }
  if supported_standards == "bgnax" then
    table.remove(wifi_standard_24GHz, 1)
    wifi_standard_24GHz[#wifi_standard_24GHz + 1] = { "bgnax", T'802.11b/g/n/ax'}
  end
else
    wifi_standard_5GHz = {
      { "an", T'802.11a/n'},
      { "anac", T'802.11a/n/ac'},
    }

  if supported_standards == "anacax" then
    table.remove(wifi_standard_5GHz, 1)
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

local bandsteer_rssi_threshold = {
  {"-10", T"-10dBm"},
  {"-20", T"-20dBm"},
  {"-30", T"-30dBm"},
  {"-40", T"-40dBm"},
  {"-50", T"-50dBm"},
  {"-60", T"-60dBm"},
  {"-70", T"-70dBm"},
  {"-80", T"-80dBm"},
  {"-90", T"-90dBm"}
}
-- Choose Wifi power
local wifipower = {
  {"-3", T"100%"},
  {"-2", T"125%"},
  {"-1", T"160%"},
  {"0", T"200%"}
}

local cw_40 = {
  {"20", T"20MHz"},
  {"auto", T"Auto (20/40MHz)"}
}

local channelWithNo160MHz = post_helper.getVariantValue(variantHelper, "channelWithNo160MHz")
local cw_80 = {}

if channelWithNo160MHz then
  cw_80 = {
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
end

local cw_160 = {}

if channelWithNo160MHz then
  cw_160 = {
    {"20",  T"20MHz"},
    {"20/40", T"20/40MHz"},
    {"20/40/80", T"Auto (20/40/80MHz)"}
  }
else
  cw_160 = {
    {"20",  T"20MHz"},
    {"20/40", T"20/40MHz"},
    {"20/40/80", T"20/40/80MHz"},
    {"auto", T"Auto (20/40/80/160MHz)"}
  }
end

local cw = {
  ["bg"] = "channelwidth20",
  ["bgn"] = "channelwidth40",
  ["bgnax"] = "channelwidth40",
  ["an"] = "channelwidth40",
  ["anac"] = "channelwidth80",
  ["anacax"] = "channelwidth160"
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

local supported_modes_data  = proxy.get("rpc.wireless.ap.@" .. curap .. ".security.supported_modes")
local supported_modes = format("%s", supported_modes_data and supported_modes_data[1] and supported_modes_data[1].value or "")
local secmodes = {}
local secmodes_matched = {
  ["none"] = T"None",
  ["wpa2-psk"] = T"WPA2 PSK",
  ["wpa-wpa2-psk"] = T"WPA+WPA2 PSK",
  ["wpa-wpa2"] = T"WPA+WPA2"
}
if not post_helper.getVariantValue(variantHelper, "securityMode") then
  local wifi_show_security = proxy.get("uci.env.var.wifi_open_security_show") and proxy.get("uci.env.var.wifi_open_security_show")[1].value or ""
  if wifi_show_security and wifi_show_security ~= "0" then
    secmodes_matched["none"] = T"None"
  else
    secmodes_matched["none"] = nil
  end
end
supported_modes:gsub("[^%s]+", function(c)
  if secmodes_matched[c] then
    secmodes[#secmodes+1] = { c, secmodes_matched[c] }
  elseif string.lower(c) ~= "none" then
    secmodes[#secmodes+1] = { c, T(string.upper(c)) }
  end
end)
-- remove radius modes if in guest ap page
if isguest == "1" then
  local num = #secmodes
  for i=num, 1, -1 do
    if secmodes[i][1] == "wpa2" or secmodes[i][1] == "wpa-wpa2" then
      table.remove(secmodes, i)
    end
  end
end

-- Listbox that shows the supported Access Control modes
local acl_modes = {
  { "disabled", T"Disabled" },
  { "unlock", T"Blacklist" },
  { "lock", T"Whitelist" }
}

if radioData[curradio] and radioData[curradio].remotely_managed ~= "1" then
  acl_modes[#acl_modes+1] = {"register", T"Register"}
end

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

local function getValidateExtraSpaces(value)
  if match(value, "^%s+") or match(value, "%s+$") then
    return nil, T"Leading and trailing whitespaces are not allowed."
  end
  return true
end

-- Here we're adding logic to make sure that we set the state of the authent and accounting server
-- for radius to 0/1.
-- This is done by checking if we're in EAP mode (wpa2 or wpa-wpa2), and if so, setting the state
-- accordingly (we use the validation chain for that through the use of a condional check)
-- For accounting, we need to additionally check that the IP and port are non empty since they're
-- optional.
local radius_modes = setmetatable({
  ["wpa2"] = true,
  ["wpa-wpa2"] = true
}, untaint_mt)
local radiusCond = function(value, object, key)
  return radius_modes[object["security"]], ""
end

local function checkIPandPort(value, object, key)
  local ip = object["radius_account_ip"]
  local port = object["radius_account_port"]
  if istainted(port) and istainted(ip) and #ip > 0 and #port > 0 then
    return true
  end
  return false, "IP or port is empty"
end

local function getReplaceValue(newval)
  return function(value, object, key)
    object[key] = newval
    return true
  end
end
-- End of code specific to Radius settings

-- Bug fix for NG-12032 GUI wireless enable/disable not working properly
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
local pathap = format("rpc.wireless.ap.@%s.", curap)
local pathapWpa3 = format("uci.wireless.wifi-ap-credential.@%s_", curap)
local pathRadius = format("uci.wireless.wifi-radius-server.@%s_", curap)
local bsPeerAP = nil
local pap = "uci.wireless.wifi-ap."
local aap = content_helper.convertResultToObject(pap .. "@.", proxy.get(pap))
local radius_account = proxy.get(pathRadius .. "acct0.")
local radius_authent = proxy.get(pathRadius .. "auth0.")
local bsid = bandsteer_helper.getBandSteerId(curiface)
local bandsteerobj = proxy.get("uci.wireless.wifi-bandsteer.@" .. bsid .. ".")
local pathpmf = format("uci.wireless.wifi-ap.@%s.", curap)
for _, v in ipairs(aap) do
  if bandsteerobj then
    if bandsteeriface and v.iface == bandsteeriface then
      bsPeerAP = v.paramindex
    end
  end
end

for _, v in ipairs(availableWirelessInterfaces) do
  if v.backhaul == "1" and v.paramindex == curiface then
    bsPeerAP = nil
  end
end

-- If this AP connects to STB, "engineer" role has full access, other roles only have simple stats
if proxy.get(pathiface .. "stb") and proxy.get(pathiface .. "stb")[1].value then
  if proxy.get(pathiface .. "stb")[1].value == "1" then
    if ngx.ctx.session:getrole() ~= "engineer" then
      stbLimit = true
    end
  end
end

local bandsteerpathap = bsPeerAP and format("rpc.wireless.ap.@" .. "%s.", bsPeerAP) or ""
local multiap_enabled = false
if post_helper.getVariantValue(variantHelper, "multiAP") then
  local multiap_state = {
    agent = "uci.multiap.agent.enabled",
    controller = "uci.multiap.controller.enabled"
  }
  content_helper.getExactContent(multiap_state)
  multiap_enabled = multiap_state.agent == "1" and multiap_state.controller == "1"
  if multiap_enabled then
    proxy.set("uci.multiap.controller_credentials.@cred1.state","0")
  else
    proxy.set("uci.multiap.controller_credentials.@cred1.state","1")
  end
  proxy.apply()
end

local mapParams = {
  ap_enabled = pathap .. "admin_state",
  ssid = pathiface .. "ssid",
  ap_broadcast_ssid = pathap .. "public",
  security = pathap .. "security.mode",
  wep_key = pathap .. "security.wep_key",
  wpa_psk = pathap .. "security.wpa_psk_passphrase",
  acl_mode = "uci.wireless.wifi-ap.@"..curap..".acl_mode",
  wps_button_handler = wpshandler_data and "uci.button.button.@wps.handler",
  standard = pathradio .. "standard",
  requested_channel = pathradio .. "requested_channel",
  requested_channel_width = pathradio .. "requested_channel_width",
}

if proxy.get(pathapWpa3 .. "credential0.passphrase") then
  mapParams.wpa3 = pathapWpa3 .. "credential0.passphrase"
end

if proxy.get(pathpmf .. "pmf") then
  mapParams.pmf = pathpmf .. "pmf"
end

local function getValidateBandSteerPeerFields(value, object, key)
  local bsid = bandsteer_helper.getBandSteerId(curiface)
  local  bandsteer_state
  if post_helper.isFeatureEnabled("bandsteerDisabled", role) then
    bandsteer_state = proxy.get(pathap .. "bs_oper_state")[1].value or ""
  else
    if isguest ~= "1" or post_helper.getVariantValue(variantHelper, "guestBandsteer") then
      bandsteer_state = proxy.get("uci.wireless.wifi-bandsteer.@"..bsid..".state")[1].value or ""
    end
  end
  if bandsteer_state == "" then
    bandsteer_state = "1"
  end
  if post_helper.getVariantValue(variantHelper, "bandsteerSupport") then
    if object.multiap_security then
      object.multiap_security = object.security
      object.multiap_wpa_psk = object.wpa_psk
      object.multiap_ssid = object.ssid
    end
    if not object.band_steer_enabled then
      if "table" ~= type(object.ap_enabled) and "1" ~= object.ap_enabled then --bandsteer enabled, network disable
        if not isBaseIface(curiface) then --for 5G disable network
          return disableBandSteer(object, bandsteer_state, multiap_enabled, isguest, bsPeerAP)
        end
      end
      return true
    end

    if object.band_steer_enabled == "1" then
      if "table" ~= type(object.ap_enabled) and "1" ~= object.ap_enabled then --bandsteer enabled, network disabled
        return disableBandSteer(object, bandsteer_state, multiap_enabled, isguest, bsPeerAP)
      elseif object.bsid ~= "" and (((not multiap_enabled or isguest == '1' ) and object.bsid ~= "off") or (multiap_enabled and object.multiap_cred_secondary_state == "0")) then
        if object.security == "wep" then
          return nil, T"The Band Steering can not be supported under WEP security mode."
        end
        if isBaseIface(curiface) then
          if object.bspeer_security then
            if bsPeerAP then
              object["ssid"..bsPeerAP] = object.ssid
            end
            object.bspeer_security = object.security
            object.bspeer_wpa_psk = object.wpa_psk
            object.bspeer_passphrase = object.wpa3
            object.bspifacessid = object.ssid
            object.bs_state = object.band_steer_enabled
            object.bspeer_pmf = object.pmf
          end
          if object.multiap_bspeer_security then
            object.multiap_bspeer_security = object.security
            object.multiap_bspeer_wpa_psk = object.wpa_psk
            object.multiap_bspifacessid = object.ssid
          end
        end
        return true
      else
        local bsid = bandsteer_helper.getBandSteerId(curiface)
        --to check wether the bs obj exist or not
        local bandsteerobj = proxy.get("uci.wireless.wifi-bandsteer.@" .. bsid .. ".")
        if not bandsteerobj then
          return nil, format('%s%s%s', T"Please configure wifi-bandsteer ", bsid, T" first!")
        else
          if object.security == "wep" then
            return nil, T"The Band Steering can not be supported under WEP security mode."
          end

          if isBaseIface(curiface) then
            object.bsid = "bs0"
            object.bspeerid = "bs0"
            object.bs_state = "0"
            if multiap_enabled then
              object.band_steer_enabled = "1"
            elseif isguest == "1" then
              --object.band_steer_enabled = "0"
            else
              object.bsid = bsid
              object.bspeerid = bsid
            end
            object.bs_state = object.band_steer_enabled
            if object.bspeer_security then
              if bsPeerAP then
                object["ssid"..bsPeerAP] = object.ssid
              end
              object.bspeer_security = object.security
              object.bspeer_wpa_psk = object.wpa_psk
              object.bspeer_passphrase = object.wpa3
              object.bspifacessid = object.ssid
              object.bspeer_pmf = object.pmf
            end
            if object.multiap_bspeer_security then
              object.multiap_bspeer_security = object.security
              object.multiap_bspeer_wpa_psk = object.wpa_psk
              object.multiap_bspifacessid = object.ssid
            end
          end
        end
      end
      if object.multiap_cred_primary_bands then
        object.multiap_cred_primary_bands = "radio_2G,radio_5Gu,radio_5Gl"
        object.multiap_cred_secondary_state = "0"
      end
    else --to disable bandsteer
      if multiap_enabled then
        proxy.set("uci.multiap.controller_credentials.@cred1.state", "1")
        proxy.apply()
      end
      return disableBandSteer(object, bandsteer_state, multiap_enabled, isguest, bsPeerAP)
    end

    return true
  else
    local state = object.ap_enabled
    local bandsteer_enabled
    if isguest ~= "1" then
      state = object.admin_state
    end
    local state_5g = object.admin_state_radio_5G
    if session:retrieve("bs_check_action") then
      session:store("bs_check_action", false)
      bandsteer_enabled = proxy.get(pathap .. "bs_oper_state")[1].value or ""
    else
      bandsteer_enabled = object.band_steer_enabled
    end
    if bandsteer_enabled == "1" then
      if "" ~= object.bsid and "off" ~= object.bsid then
        if object.security == "wep" then
          return nil, T"The Band Steering can not be supported under WEP security mode."
        end
        if isBaseIface(curiface) then
          if object.bspeer_security then
            if bsPeerAP then
              object["ssid"..bsPeerAP] = object.ssid
            end
            object.bspeer_security = object.security
            object.bspeer_wpa_psk = object.wpa_psk
            object.bspeer_passphrase = object.wpa3
            object.bspifacessid = object.ssid
            object.bspeer_pmf = object.pmf
            object.bs_state = object.band_steer_enabled
          end
        end
        return true
      else
        local bsid = bandsteer_helper.getBandSteerId(curiface)
        --to check wether the bs obj exist or not
	local bandsteerobj = proxy.get("uci.wireless.wifi-bandsteer.@" .. bsid .. ".")
        if not bandsteerobj then
	  return nil, format('%s%s%s',T"Please configure wifi-bandsteer ", bsid, T" first!")
	else
	  if object.security == "wep" then
	    return nil, T"The Band Steering can not be supported under WEP security mode."
	  end

          if isBaseIface(curiface) then
            object.bsid = bsid
            object.bspeerid = bsid
            if object.bspeer_security then
              if bsPeerAP then
                object["ssid"..bsPeerAP] = object.ssid
              end
              object.bspeer_security = object.security
              object.bspeer_wpa_psk = object.wpa_psk
              object.bspeer_passphrase = object.wpa3
              object.bspifacessid = object.ssid
              object.bspeer_pmf = object.pmf
              object.bs_state = object.band_steer_enabled
            end
          end
        end
      end
    elseif object.band_steer_enabled then --to disable bandsteer
      return disableBandSteer(object, bandsteer_state, multiap_enabled, isguest, bsPeerAP)
    end

    return true
  end
end

local multiap_cred_secondary_path, bandsteerpath, bandsteers
if bandsteerobj then
  bandsteerpath = "uci.wireless.wifi-bandsteer."
  bandsteers = content_helper.convertResultToObject(bandsteerpath .. "@.", proxy.get(bandsteerpath))
  table.sort(bandsteers, function(a,b)
    return a.paramindex < b.paramindex
  end)
end

local param = {
  allowed_channels = pathradio .. "allowed_channels"
}

if post_helper.getVariantValue(variantHelper, "platformfield") then
  param.platform =  "uci.wireless.wifi-device.@"..curradio..".type"
end

content_helper.getExactContent(param)
local allowed_channels = { {"auto", T"Auto"} }
for i in string.gmatch(param["allowed_channels"], "%S+") do
  allowed_channels[#allowed_channels + 1] = {i, i}
end

local function validateRadioandAp(value, object, key)
  return post_helper.validateRadioandAp(value, object, key, pathap)
end

-- Only include radius configuration in UI if not in guest/hotspot mode or not remotely managed
-- Only include SGI, CDD, and STBC if not guest/hotspot or not remotely managed
local function getParamsAndValidationForRadius()
  local mapRadiusParams = {}
  if isguest ~= "1" and isExtRemman ~= "1" and isIntRemman ~= "1" and not stbLimit then
    if radius_authent then
      mapRadiusParams.radius_authent_state = pathRadius .. "auth0.state"
      mapRadiusParams.radius_authent_ip = pathRadius .. "auth0.ip"
      mapRadiusParams.radius_authent_port = pathRadius .. "auth0.port"
      mapRadiusParams.radius_authent_secret = pathRadius .. "auth0.secret"
    end
    if radius_account then
      mapRadiusParams.radius_account_state = pathRadius .. "acct0.state"
      mapRadiusParams.radius_account_ip = pathRadius .. "acct0.ip"
      mapRadiusParams.radius_account_port = pathRadius .. "acct0.port"
      mapRadiusParams.radius_account_secret = pathRadius .. "acct0.secret"
    end
    -- validation check on cdd with default value 'auto' would fail in guest page
    -- just ignore these parameters since they are not shown in guest page
    if (isguest ~= "1" and is11nStdSelected) or (isguest ~= "1" and is11nStdSelected_5G) then
      mapRadiusParams.sgi = pathradio .. "sgi"
      mapRadiusParams.cdd = pathradio .. "cdd"
      mapRadiusParams.stbc = pathradio .. "stbc"
    end
  end

  local mapRadiusValid = {
    radius_authent_ip = validateIfProp_IP,
    radius_account_ip = getOptionalValidation(validateIfProp_IP),
    radius_authent_secret = getValidationIfPropInList(validateNonEmptyString, "security", wpa_list),
    radius_account_secret = getValidationIfPropInList(validateNonEmptyString, "security", wpa_list),
    radius_authent_port = validateIfProp_port,
    radius_account_port = getOptionalValidation(validateIfProp_port),
    radius_authent_state = getConditionalValidation(radiusCond, getReplaceValue("1"), getReplaceValue("0")), -- we know that we're enforcing the server ip and port is there
    radius_account_state = getConditionalValidation(getAndValidation(radiusCond, checkIPandPort), getReplaceValue("1"), getReplaceValue("0")), -- if no server ip or port, don't set to 1
    sgi = getOptionalValidation(validateBoolean),
    cdd = function(val, object)
      if object.cdd == "auto" then
        object.cdd = "1"
      end
      return getValidateInEnumSelect(cddList)
    end,
    stbc = getOptionalValidation(validateBoolean)
  }
  return mapRadiusParams, mapRadiusValid
end

-- Constructing the rpc parameters and validations for post handleQuery
local function getParamsAndValidation()
  local wps_button_handler = setmetatable({
    ["1"] = "wps_button_pressed.sh",
    ["0"] = "acl_button_pressed.sh"
  }, untaint_mt)

  if isguest ~= "1" then
    mapParams.admin_state = pathradio .. "admin_state"
    mapParams.standard = pathradio .. "standard"
    mapParams.requested_channel = pathradio .. "requested_channel"
    mapParams.requested_channel_width = pathradio .. "requested_channel_width"
    mapParams.wps_enabled = pathap .. "wps.admin_state"
    mapParams.wps_pin_enabled = pathap .. "wps.ap_setup_locked"
    mapParams.frame_bursting = pathradio .. "frame_bursting"
    for _, v in pairs(radios) do
      if v ~= curradio then
        mapParams["admin_state_" .. v] = "rpc.wireless.radio.@" .. v .. ".admin_state"
      end
    end
  elseif post_helper.getVariantValue(variantHelper, "guestCheck") then
    mapParams.ap_enabled = pathap .. "admin_state"
    for _, v in pairs(radios) do
      if v == curradio then
        mapParams["admin_state"] = "rpc.wireless.radio.@" .. v .. ".admin_state"
      end
    end
  end

  if isguest == "1" and post_helper.getVariantValue(variantHelper, "guestCheck") then
    mapParams.ap_enabled = pathap .. "admin_state"
  end

  if wps_ssid then
    mapParams.wps_button_handler = nil
  end

  if post_helper.getVariantValue(variantHelper, "getBandsteerParams") then
    if bsPeerAP then
      local bsid = bandsteer_helper.getBandSteerId(curiface)
      local bandsteerParams = {
        bsid = pap .. "@" .. curap .. ".bandsteer_id",
        bspeerid = pap .. "@" .. bsPeerAP .. ".bandsteer_id",
      }
      if isguest ~= "1" or post_helper.getVariantValue(variantHelper, "guestBandsteer") then
        bandsteerParams.bs_state = "uci.wireless.wifi-bandsteer.@".. bsid ..".state"
      end

      if bandsteerobj then
        if isBaseIface(curiface) then
          if bandsteeriface then
            local bandsteerAddParams = {
              bspifacessid = pIface .. "@" .. bandsteeriface .. ".ssid",
              bspeer_security = pap .. "@" .. bsPeerAP .. ".security_mode",
              bspeer_wpa_psk = pap .. "@" .. bsPeerAP .. ".wpa_psk_key",}
              local pathpeerpmf = format("uci.wireless.wifi-ap.@%s.", bsPeerAP)
              if pathpeerpmf and proxy.get(pathpeerpmf .. "pmf")[1].value ~= "disabled" then
                bandsteerAddParams.bspeer_pmf = pathpeerpmf .. "pmf"
              end
              local pathpeerapWpa3= format("uci.wireless.wifi-ap-credential.@%s_", bsPeerAP)
              if proxy.get(pathpeerapWpa3 .. "credential0.passphrase") then
                bandsteerAddParams.bspeer_passphrase = pathpeerapWpa3 .. "credential0.passphrase"
              end
            for k,v in pairs(bandsteerAddParams) do
              bandsteerParams[k] = v
            end
          end
        end

        for k,v in pairs(bandsteerParams) do
          mapParams[k] = v
        end
      end
    end
  end

  local mapValid = {
    interface_enabled = validateBoolean,
    standard = getValidateInEnumSelect(wifi_standard),
    outputpower = getValidateInEnumSelect(wifipower), -- if the parameter is not included, it does not matter, this validation function will never be called
    channelwidth20 = getValidateChannelWidth(cw_40),
    channelwidth40 = getValidateChannelWidth(cw_40),
    channelwidth80 = getValidateChannelWidth(cw_80),
    channelwidth160 = getValidateChannelWidth(cw_160),
    security = getValidateInEnumSelect(secmodes),
    ssid = getAndValidation(getValidateStringLengthInRange(1,32),getValidateExtraSpaces),
    wep_key = getValidationIfPropInList(validateWEP,"security", {"wep"}),
    wpa_psk = getValidationIfPropInList(validatePSK,"security", {"wpa-psk", "wpa2-psk", "wpa-wpa2-psk"}),
    wps_enabled = getOptionalValidation(validateBoolean),
    acl_mode = getValidateInEnumSelect(acl_modes),
    wpa3 = getValidationIfPropInList(validatePSK,"security", {"wpa3", "wpa3-psk", "wpa2-wpa3", "wpa2-wpa3-psk"}),
    wps_button_handler = function(val, object)
      object.wps_button_handler = wps_button_handler[object.wps_enabled]
      return true
    end,
    ap_broadcast_ssid = validateBoolean,
    requested_channel = getValidateInEnumSelect(allowed_channels),
    admin_state = validateBoolean
  }

  if bandsteerobj then
    mapValid.bsid = getValidateBandSteerPeerFields
  end

  local function validateSSIDWireless(value)
    return post_helper.validateSSIDWireless(value, wls)
  end
  if post_helper.getVariantValue(variantHelper, "ssidCheck") then
    mapValid.ssid = validateSSIDWireless
  end

  if post_helper.getVariantValue(variantHelper, "frameBursting") then
    mapParams.frame_bursting = pathradio .. "frame_bursting"
    mapValid.ap_enabled = validateBoolean
    mapValid.frame_bursting = validateBoolean
    if bandsteerobj then
      mapValid.rssi_threshold = getValidateInEnumSelect(bandsteer_rssi_threshold)
    end
  else
    mapValid.ap_enabled = function(val,object)
      if isguest ~= "1" then
        object.ap_enabled = object.admin_state
      end
      return true
    end
    if isguest ~= "1" then
      mapValid.admin_state = validateRadioandAp
    end
  end
   -- Bug fix for NG-12032 GUI wireless enable/disable not working properly
  for _, v in pairs(radios) do
    if v ~= curradio then
      mapValid["admin_state_" .. v] = getInterfaceEnabled2
    end
  end
  return mapParams, mapValid
end

local bandsteerhelpmsg = {}
local content_rssi = {}
mapRadiusParams, mapRadiusValid = getParamsAndValidationForRadius()
mapParams, mapValid = getParamsAndValidation()
for k,v in pairs(mapRadiusParams) do
  mapParams[k] = v
end
for k,v in pairs(mapRadiusValid) do
  mapValid[k] = v
end
local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "bs_check" then
  local postargs = ngx.req.get_post_args()
  local validateStringInlength = getValidateStringLengthInRange(1,32)
  local is_main = (postargs.apName and proxy.get("rpc.wireless.ap.@"..postargs.apName..".ap_isolation")[1].value == "0") and true or false
  if post_helper.isFeatureEnabled("bandsteerDisabled" , role) then
    if is_main and (content["ssid"] ~= postargs.ssidName or content["security"] ~= postargs.security or content["wpa_psk"] ~= postargs.wpa_psk or (content["wpa3"] and content["wpa3"] ~= postargs.wpa3)) then
      if validatePSK(postargs.wpa_psk) and validateStringInlength(postargs.ssidName) and getValidateExtraSpaces(postargs.ssidName) then
        session:store("bs_check_action", true)
        proxy.set("uci.wireless.wifi-bandsteer.@bs0.state","0")
        proxy.apply()
      end
    end
  else
    if is_main and (content["ssid"] ~= postargs.ssidName or content["security"] ~= postargs.security or content["wpa_psk"] ~= postargs.wpa_psk or (content["wpa3"] and content["wpa3"] ~= postargs.wpa3)) then
      if validatePSK(postargs.wpa_psk) and validateStringInlength(postargs.ssidName) and getValidateExtraSpaces(postargs.ssidName) then
        session:store("bs_check_action", true)
        proxy.set("uci.wireless.wifi-bandsteer.@bs0.state","0")
        proxy.apply()
      end
    end
  end
  ngx.exit(ngx.HTTP_OK)
end

-- Process POST query
if ngx.req.get_method() == "POST" then
  local postargs = ngx.req.get_post_args()
  if post_helper.getVariantValue(variantHelper, "channelWithNo160MHz") then
    if (content["standard"] == "anacax" and content["channelwidth160"] == "20/40/80") or (content["standard"] == "anac" and content["channelwidth80"] == "20/40/80")then  
      proxy.set(format("uci.system.system.@system[0].autochannel_enable"), "Auto")
      proxy.apply()
    else
      if (content["standard"] == "anacax") then
        proxy.set(format("uci.system.system.@system[0].autochannel_enable"), content["channelwidth160"])
        proxy.apply()
      elseif (content["standard"] == "anac") then
        proxy.set(format("uci.system.system.@system[0].autochannel_enable"), content["channelwidth80"])
        proxy.apply()
      end
    end
  end

  if smartWifi == "1" and (curiface == "wl0" or curiface == "wl0_1") then
    proxy.set(format("uci.wireless.wifi-iface.@%s.ssid", bandsteeriface), postargs.ssid)
    proxy.set(format("uci.wireless.wifi-ap.@%s.wpa_psk_key", bspeerap), postargs.wpa_psk)
    proxy.apply()
  end
  local tmpbandsteerhelpmsg = {}
  for k, v in pairs(helpmsg) do
    if k == "bsid" then
      tmpbandsteerhelpmsg["content"] = v
      tmpbandsteerhelpmsg["level"] = "error"
    end
  end

  if not next(tmpbandsteerhelpmsg) then
    bandsteerhelpmsg = nil
  else
    bandsteerhelpmsg[1] = tmpbandsteerhelpmsg
  end

  if content["action"] == "SAVE" and post_helper.getVariantValue(variantHelper, "frameBursting") then
    local retval = false
    local postargs = ngx.req.get_post_args()
    if postargs["rssi_threshold"] ~= nil and bandsteerobj then
      retval = proxy.set(format('%s@%s.rssi_threshold', bandsteerpath, content["bsid"]), format("%d", postargs["rssi_threshold"]))
    end
    if retval == true then
      proxy.apply()
    end
  end

  -- End of parameters saving / loading

  -- Support for device PIN code
  content["wps_device_pin_code"] = ""

  -- triggered only on a POST with action set wps_device_pin_code (button next to field should trigger that)
  if #wls > 1 then
    for _, v in ipairs(wls) do
      if v.iface == curiface then
        v.ssid = content["ssid"]
      end
    end
  end
  local args = ngx.req.get_post_args()
  local action = args["action"]
  local pin = args["wps_device_pin_code"]
  if action == "wps_device_pin_code" and content["wps_enabled"] == "1" and isguest ~= 0 then
    local res, help = validateWPSPIN(pin)
    content["wps_device_pin_code"] = pin

    if res then
      proxy.set("rpc.wireless.ap.@" .. curap .. ".wps.enrollee_pin",pin)
    else
      helpmsg["wps_device_pin_code"] = help
    end
  end
  -- End of device PIN code support
  -- triggered only on a POST with action set wps_pbc
  if action == "wps_pbc" and content["wps_enabled"] == "1" and isguest ~= 0 then
    if post_helper.getVariantValue(variantHelper, "wpsValue") then
      proxy.set("rpc.wireless.ap.@"..curap..".wps.enrollee_pbc","1")
    else
      proxy.set("rpc.wireless.wps_button","1")
    end
  end
  -- End of WPS PBC code support
end
-- AP PIN code and Mac - read only
-- "rpc.wireless.ssid.@wl0." and "rpc.wireless.ssid.@wl1." returns empty during hostapd reload is in progress,
-- so introduce delay to hold the save operation until gets valid data from datamodel and also introduce timeout (1 minute max)
-- to break this loop
local content_ssid = {
  pathiface .. "mac_address",
  pathiface .. "stb",
  pathiface .. "ap_display_name",
  pathap .. "wps.ap_pin",
  pathap .. "wps.ap_setup_locked"
}
local step = 2
for i = 0, 60, step do
  ngx.sleep(step)
  local content_val = proxy.get(unpack(content_ssid))
  if (content_val and #content_val > 0) then
    content["macaddress"] = content_val[1].value
    content["stb"] = content_val[2].value
    content["ap_display_name"] = content_val[3].value
    content["wps_ap_pin_code"] = content_val[4].value
    content["wps_ap_setup_locked"] = content_val[5].value
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
for i in string.gmatch(param["allowed_channels"], "%S+") do
  allowed_channels[#allowed_channels + 1] = {i, i}
end
if radioData[curradio] then
  for k, v in pairs(radioData[curradio]) do
    -- Not replace the value that already exists
    if not content[k] then
      content[k] = v
    end
  end
end

local band_steer_supported
local bs_peer_network_enable = "0"
local band_steer_enabled

if "" ~= bandsteerpathap then
  --Need to consider the constraint
  band_steer_supported, band_steer_enabled = bandsteer_helper.getBandSteerState(bsPeerAP, curap, multiap_enabled and multiap_cred_secondary_path, isguest)
  local content_band_steer = {
    band_steer_id = "uci.wireless.wifi-ap.@".. curap .. ".bandsteer_id"
  }
  if post_helper.isFeatureEnabled("bandsteerDisabled" , role) then
    content_band_steer.band_steer_ap_enabled = pathap .. "bs_oper_state"
  else
    content_band_steer.band_steer_ap_enabled = bandsteerpathap .. "admin_state"
  end

  if bandsteerobj then
     content_helper.getExactContent(content_band_steer)
  end

  bs_peer_network_enable = content_band_steer.band_steer_ap_enabled

  if bs_peer_network_enable == "1" and band_steer_supported and post_helper.getVariantValue(variantHelper, "frameBursting") then
    local bsid = bandsteer_helper.getBandSteerId(curiface)
    content_rssi = {
      rssi_threshold = bandsteerpath .. "@" .. bsid .. ".rssi_threshold",
    }
  end
  if bandsteerobj then
    content_helper.getExactContent(content_rssi)
  end
end

local function checkCurrentUser(currentuser)
  if (currentuser == "user" or currentuser == "support") then
    return true
  else
    return false
  end
end

local multiap_bsslist
if multiap_enabled then
  multiap_bsslist = proxy.get("uci.multiap.agent.bss_list")
  multiap_bsslist = multiap_bsslist and multiap_bsslist[1].value or ""
end
ngx.print(ui_helper.createHeader(T"Wireless", true, false))   ngx.print('\
\
<div class="modal-body update">\
');  
  local lp = require("web.lp")
  if post_helper.getVariantValue(variantHelper, "navTab") then
    lp.setpath("/www/snippets/")
    lp.include("tabs-wireless.lp")
  end
  ngx.print('\
<style>\
  .tooltip-inner {\
    max-width: 100% !important;\
  }\
</style>\
<form class="form-horizontal" method="post" action="');  ngx.print( ngx.var.request_uri ); ngx.print('">\
');  
-- Do not display the navlist on the list if no SSID
local navlist = 0
if post_helper.getVariantValue(variantHelper, "navlistCheck") then
  navlist = 1
end

local wifi_iface =  proxy.get("uci.gre_hotspotd.hotspot.")
local hotspot_devices = content_helper.convertResultToObject("uci.gre_hotspotd.hotspot.", wifi_iface)
if #wls > navlist then
  ngx.print('\
  <div class="span2">\
    <ul class="nav nav-list">\
    ');  
      local html = {}
      local prevradio = ""
      for i, v in ipairs(wls) do
        if content["ssid"..v.ap] and v.ap == bsPeerAP then
          v.ssid = content["ssid"..v.ap]
        end
        if v.radio ~= prevradio then
          if radioData[untaint(v.radio)] then
            if radioData[untaint(v.radio)].remotely_managed == "1" and radioData[untaint(v.radio)].integrated_ap ~= "1" then
              html[#html+1] = format('<li class="nav-header">%s %s</li>', T"External access points", radioData[untaint(v.radio)].supported_frequency_bands)
            else
              html[#html+1] = format('<li class="nav-header">%s %s</li>', T"Access points", radioData[untaint(v.radio)].supported_frequency_bands)
            end
          end
          prevradio = v.radio
        end
        local active = ""
        if v.iface == curiface and getWifiAnalyzer == nil then
          active = "active"
        end
	local ishotspotDevice = false
	for _, wifi_interface in ipairs(hotspot_devices) do
	  if wifi_interface.wifi_iface == v.iface then
	    ishotspotDevice = true
	  end
	end
        local url = "modals/wireless-modal.lp?radio=" .. v.radio .. "&iface=" .. v.iface
        local showSSID = post_helper.getVariantValue(variantHelper, "showSSIDTelusBooster")
        local checkGuestSSID = checkCurrentUser(currentuser)
        if not showSSID or (showSSID and not match(v.iface, "_2$")) then
          -- Do not display stb ssid
          if v.ap_display_name ~= nil and v.ap_display_name ~= "" then
            html[#html+1] = format('<li class="%s"><a  id = "Wireless_Tab_%s" href="#" data-remote="%s">%s</a></li>', active, i, url, v.ap_display_name)
          elseif v.stb == "1" then
            html[#html+1] = format('<li class="%s"><a  id = "Wireless_Tab_%s" href="#" data-remote="%s">%s</a></li>', active, i, url, "IPTV")
          elseif post_helper.isFeatureEnabled("Hotspot", role) or not ishotspotDevice then
            if post_helper.getVariantValue(variantHelper, "hideGuestSSID") then
              if (checkGuestSSID and not match(v.iface, "_1$")) or not checkGuestSSID  then
                html[#html+1] = format('<li class="%s"><a  id = "Wireless_Tab_%s" href="#" data-remote="%s">%s</a></li>', active, i, url, v.ssid)
              end
            else
              html[#html+1] = format('<li class="%s"><a  id = "Wireless_Tab_%s" href="#" data-remote="%s">%s</a></li>', active, i, url, v.ssid)
            end
          end
        end
      end
      -- If wifi analyzer enabled, draw it
      local wifi_analyzer_disable = proxy.get("uci.wireless.wifi.@global.wifi_analyzer_disable")
      if wifi_analyzer_disable and wifi_analyzer_disable[1].value ~= "1" and post_helper.getVariantValue(variantHelper, "wifiAnalyzer") then
        html[#html+1] = string.format('<li class="nav-header">%s</li>', T"Wireless Data")
        local freq = "2.4"
        local isDuplicate = {}
        for i, v in ipairs(wls) do
          if not isDuplicate[v.radio] and (v.radio == "radio_5G" or v.radio == "radio_2G") then
            if v.radio == "radio_5G" then freq = "5" or "2.4" end
              local active = ""
              if getWifiAnalyzer == v.iface then
                active = "active"
                radio = v.radio
              end
              local url = "modals/wireless-modal.lp?radio=" .. v.radio .. "&isWifiAnalyzer=" .. v.iface
              if smartWifi ~= "1" or (smartWifi == "1") then
                html[#html+1] = format('<li class="%s"><a href="#" data-remote="%s" id ="wifianalyzer_%s">%s %sGHz</a></li>',active, url,freq,T"Analyzer",freq )
              end
              local link_id = "2"
              if freq == "5" then link_id = "5" end
                html[#html + 1] = format([[
                <div><div id = linkconfirming-msg_%s class= "alert hide"> %s </div> ]],
                link_id,T"If you use this tool, devices connected will be disconnected and will be able to connect after 1 minute.")
                html[#html + 1] = format([[
                <div id="linkrescan-changes_%s" class="hide">
                  <div id="linkrescan-cancel_%s" class="btn">%s</div>
                    <a id="linkrescan-confirm_%s" class="btn btn-primary" href="#" data-remote="%s">%s</a>
                </div></div>
               ]],
               link_id,link_id,T"Cancel",link_id,url,T"Accept")
             end
             isDuplicate[v.radio] = true
           end
         end
         if session:hasAccess("/modals/wireless-client-modal.lp") then
           html[#html+1] = format("<li><a href=\"#\" id=\"Client Monitoring\" data-remote=\"modals/wireless-client-modal.lp\" >%s</a></li>", T"Client Monitoring" )
         end
         ngx.print(html)
           ngx.print('\
     </ul>\
  </div>\
  <div class="span6">\
  ');  
end

local current_acl_mode = content["acl_mode"]
if getWifiAnalyzer == nil then
  ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  if bandsteerhelpmsg then ngx.print(ui_helper.createMessages(bandsteerhelpmsg)) end
  ngx.print('\
    <fieldset>\
      <legend>');  ngx.print( T"Interface" ); ngx.print('</legend>\
      ');  
        local html = {}
        local advanced = {
          group = {
            class = "advanced hide",
          }
        }

        local labelstate = T"Off"
        if post_helper.getVariantValue(variantHelper, "radiolabelState") then
          if content["admin_state"] == "1" then
            labelstate = T"On"
          end
        end
        -- In guest page, do not let the user change the configuration of the wifi radio. Only in main AP
        if isguest == "1" then
          local guest_alert = {
            alert = {
              class = "alert-info"
            },
          }
          if post_helper.getVariantValue(variantHelper, "radiolabelState") then
            html[#html + 1] = ui_helper.createLabel(T"Radio", labelstate)
          elseif match(pIfaceNetwork, "guest*") then
            -- Display infomation indicating it is a guest SSID
            html[#html + 1] = ui_helper.createAlertBlock(T"This is a guest network. The guest network has no local network access.", guest_alert)
          end

          -- Switch that shows if the Wifi interface is enabled or not
          html[#html + 1] = ui_helper.createLabel(T"Frequency band", content["supported_frequency_bands"])
          -- Show Antenna Setup
          html[#html + 1] = ui_helper.createLabel(T"Antenna", antenna, advanced)
          -- Label that shows the MAC address of the Wifi interface
          html[#html + 1] = ui_helper.createLabel(T"MAC address", content["macaddress"])
          if radioData[curradio] and radioData[curradio].supported_frequency_bands == "5GHz" then
            html[#html + 1] = ui_helper.createLabel(T"Standard", listboxToText(wifi_standard, wifiStandard.standard), advanced)
          else
            html[#html + 1] = ui_helper.createLabel(T"Standard", listboxToText(wifi_standard, content["standard"]), advanced)
          end
          -- Current speed of the Wifi interface
          html[#html + 1] = ui_helper.createLabel(T"Speed", content["phy_rate"] / 1000 .. "Mbps", { span = {
            id = "phy_rate",
            ["data-ajaxrefresh"] = "5",
          }})

          html[#html + 1] = ui_helper.createLabel(T"Channel", content["requested_channel"])
          -- Show which region is being used
          html[#html + 1] = ui_helper.createLabel(T"Region", content["country"], advanced)
          html[#html + 1] = ui_helper.createLabel(T"Current channel", content["channel"], { span = {
            id = "channel",
            ["data-ajaxrefresh"] = "10",
          }})

          html[#html + 1] = ui_helper.createLabel(T"Channel width", listboxToText(channelwidth, content["requested_channel_width"]), advanced)
        else
          -- Switch that shows if the Wifi interface is enabled or not
          if post_helper.getVariantValue(variantHelper, "radiolabelState") then
            html[#html + 1] = ui_helper.createLabel(T"Radio", labelstate)
          else
            if not stbLimit then
              html[#html + 1] = ui_helper.createSwitch(T"Enabled", "admin_state", content["admin_state"])
            end
          end
          html[#html + 1] = ui_helper.createLabel(T"Frequency band", content["supported_frequency_bands"] or "")
           -- Show Antenna Setup
          html[#html + 1] = ui_helper.createLabel(T"Antenna", antenna, advanced)
          -- Label that shows the MAC address of the Wifi interface
          html[#html + 1] = ui_helper.createLabel(T"MAC address", content["macaddress"])

          -- Select the standard to use
          local stdattributes = {
            group = {
              class = "advanced hide",
            },
            select = {
              class = "monitor-changes"
            }
          }
          if radioData[curradio] and radioData[curradio].supported_frequency_bands == "5GHz" then
            html[#html + 1] = ui_helper.createInputSelect(T"Standard", "standard", wifi_standard, content["standard"], stdattributes)
          else
            if not stbLimit then
              html[#html + 1] = ui_helper.createInputSelect(T"Standard", "standard", wifi_standard, content["standard"], stdattributes)
            else
              html[#html + 1] = ui_helper.createLabel(T"Standard", listboxToText(wifi_standard, content["standard"]), stdattributes)
            end
          end

          -- Current speed of the Wifi interface
          html[#html + 1] = ui_helper.createLabel(T"Speed", (content["phy_rate"] and content["phy_rate"] ~= "") and tonumber(content["phy_rate"])/1000 .. "Mbps" or "", { span = {
            id = "phy_rate",
            ["data-ajaxrefresh"] = "5",
          }})

          -- Choose which channel to use
          if ((not stbLimit) and (smartWifi ~= "1")) then
            html[#html + 1] = ui_helper.createInputSelect(T"Channel", "requested_channel", allowed_channels, content["requested_channel"])
          end

          -- Show which region is being used
          html[#html + 1] = ui_helper.createLabel(T"Region", content["country"] or "", advanced)
          html[#html + 1] = ui_helper.createLabel(T"Current channel", content["channel"] or "", { span = {
            id = "channel",
            ["data-ajaxrefresh"] = "5",
          }})
          if not stbLimit then
            html[#html + 1] ='<div class ="advanced hide">'
            local cw20attributes  = {
              group = {
                class ="hide monitor-standard monitor-b monitor-bg",
              },
            }
            if (smartWifi == "0" or smartWifi == "") or (smartWifi == "1" and role ~= "admin") then
              html[#html + 1] = ui_helper.createInputSelect(T"Channel width", "channelwidth20", cw_40, content["requested_channel_width"], cw20attributes)

              local cw40attributes  = {
                group = {
                  class ="hide monitor-standard monitor-bgn monitor-bgnax monitor-an",
                },
              }

              html[#html + 1] = ui_helper.createInputSelect(T"Channel width", "channelwidth40", cw_40, content["requested_channel_width"], cw40attributes)
              local cw80attributes  = {
                group = {
                  class ="hide monitor-standard monitor-anac",
                },
              }

              html[#html + 1] = ui_helper.createInputSelect(T"Channel width", "channelwidth80", cw_80, content["requested_channel_width"], cw80attributes)
              local cw160attributes  = {
                group = {
                  class ="hide monitor-standard monitor-anacax",
                },
              }
              local cw160alert = {
                alert = {
                  class = "alert alert-warning hide",
                  id = "channel160alert",
                }
              }
              html[#html + 1] = ui_helper.createInputSelect(T"Channel width", "channelwidth160", cw_160, content["requested_channel_width"], cw160attributes)
              html[#html + 1] = ui_helper.createAlertBlock(T"Auto (20/40/80/160 MHz): In this mode all channels of your region can be used including the weather channels and this can cause longer scan time of up to 10 mins", cw160alert)
              html[#html + 1] = '</div>'

              if isExtRemman ~= "1" and isIntRemman ~= "1" then
                local stdNSupportedParamAttr = {
                  group = {
                    class = "advanced hide",
                  },
                  switch = {
                    class = "stdNSupportedParam"
                  },
                  select = {
                    class = "stdNSupportedParam"
                  },
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
        end
        ngx.print(html)
          ngx.print('\
   </fieldset>\
');  
  html = {}

  if not stbLimit then
    html[#html + 1] = "<fieldset>"
  else
    html[#html + 1] = "<fieldset class=\"advanced hide\">"
  end
  html[#html + 1] = "<legend>"
  html[#html + 1] = T"Access Point"
  html[#html + 1] = [[</legend>]]

  -- Show if the AP is enabled
  if post_helper.getVariantValue(variantHelper, "guestCheck") then
    if isguest == "1" then
      if content["admin_state"] == "0" then
        html[#html + 1] = ui_helper.createAlertBlock(string.format("%s", T"WARNING: If you would like to connect to the GuestSSID, please activate your Main SSID"), SUB_PF_CSS)
      else
        html[#html + 1] = ui_helper.createSwitch(T"Enabled", "ap_enabled", content["ap_enabled"])
      end
    else
      html[#html + 1] = ui_helper.createSwitch(T"Enabled", "admin_state", (content["admin_state"] and content["ap_enabled"]))
    end
  else
    html[#html + 1] = ui_helper.createSwitch(T"Enabled", "ap_enabled", content["ap_enabled"], advanced)
  end

  if not stbLimit then
    -- Show the SSID
    local ssidclass = {
      input = {
        maxlength= "32",
        class= "span4",
      }
    }
    --Only baseiface can modify ssid when bandsteer enabled

    if (band_steer_enabled and not isBaseIface(curiface) and post_helper.getVariantValue(variantHelper, "frameBursting") and bandsteerobj) or (smartWifi == "1" and curiface == "wl1") or (multiap_enabled and string.find(multiap_bsslist, curiface)) then
      html[#html + 1] = ui_helper.createLabel( T"SSID name", content["ssid"], ssidclass)
    else
      html[#html + 1] = ui_helper.createInputText(T"SSID name", "ssid", content["ssid"], ssidclass, helpmsg["ssid"])
    end

    local broadcastclass = {
      group = {
        class = "advanced hide",
      },
      input = {
        class = "monitor-changes"
      }
    }

    -- Should we broadcast the SSID
    if smartWifi ~= "1" then
      html[#html + 1] = ui_helper.createSwitch(T"Broadcast SSID", "ap_broadcast_ssid", content["ap_broadcast_ssid"], broadcastclass)
    end

    -- Select the security mode to use
    local secattributes = {
      group = {
        class = "",
      },
      select = {
        class = "monitor-changes"
      }
    }

    if band_steer_enabled and not isBaseIface(curiface) and post_helper.getVariantValue(variantHelper, "frameBursting") and bandsteerobj or (multiap_enabled and string.find(multiap_bsslist, curiface)) then
      html[#html + 1] = ui_helper.createLabel(T"Security Mode", content["security"], secattributes)
    else
      local security_warning = {
        alert = {
          class = "alert-error monitor-security monitor-none"
        },
      }
      html[#html + 1] = ui_helper.createAlertBlock(T"Security for this wireless network is disabled, anybody can connect or listen to it", security_warning)

      local wep_warning = {
        alert = {
          class = "alert-error monitor-security monitor-wep"
        },
      }
      html[#html + 1] = ui_helper.createAlertBlock(T"WEP is known to be flawed as a wireless security mode, usage of a more secure mode based on WPA2 is recommended.",wep_warning)

      html[#html + 1] = ui_helper.createInputSelect(T"Security Mode", "security", secmodes, content["security"], secattributes)
    end

    local pskclass = {
      group = {
        class ="monitor-security monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk",
      },
      input = {
        class= "span4",
        maxlength="63"
      }
    }

    local pskwpa3 = {
      group = {
        class ="monitor-security monitor-wpa3 monitor-wpa3-psk monitor-wpa2-wpa3 monitor-wpa2-wpa3-psk",
      },
      input = {
        class= "span4",
        maxlength="63"
      }
    }

    local wepclass = {
      group = {
        class ="monitor-security monitor-wep",
      },
      input = {
        class= "span4",
      }
    }

    if post_helper.getVariantValue(variantHelper, "frameBursting") then
      if bandsteerobj and band_steer_enabled and not isBaseIface(curiface) then
        if "wep" == content["security"] then
          html[#html + 1] = ui_helper.createLabel(T"WEP Key", content["wep_key"], wepclass)
        end

        if "wpa-psk" == content["security"] or "wpa2-psk" == content["security"] or "wpa-wpa2-psk" == content["security"] then
          html[#html + 1] = ui_helper.createLabel(T"Wireless Password", content["wpa_psk"], pskclass)
        end

        if "wpa3" == content["security"] or "wpa3-psk" == content["security"] or "wpa2-wpa3-psk" == content["security"] or "wpa2-wpa3" == content["security"] then
          html[#html + 1] = ui_helper.createInputText(T"Wireless Password", "wpa3", content["wpa3"], pskwpa3)
        end

      else
        if smartWifi == "1" and curiface == "wl1" or (multiap_enabled and string.find(multiap_bsslist, curiface)) then
          html[#html + 1] = ui_helper.createLabel(T"Wireless Password", content["wpa_psk"], pskclass)
        else
          html[#html + 1] = ui_helper.createInputText(T"Wireless Password", "wpa_psk", content["wpa_psk"], pskclass, helpmsg["wpa_psk"])
          html[#html + 1] = ui_helper.createInputText(T"Wireless Password", "wpa3", content["wpa3"], pskwpa3, helpmsg["wpa3"])
        end
        html[#html + 1] = ui_helper.createInputText(T"WEP Key", "wep_key", content["wep_key"], wepclass, helpmsg["wep_key"])
      end
    else
      local wait_alert = {
        alert = {
          class = "alert-info hide",
          id = "wait-time-msg"
        },
      }
      if smartWifi == "1" and curiface == "wl1" then
          html[#html + 1] = ui_helper.createLabel(T"Wireless Password", content["wpa_psk"], pskclass)
      else
        html[#html + 1] = ui_helper.createAlertBlock(T"Please apply your changes after few seconds", wait_alert)
        if not multiap_enabled then
          html[#html + 1] = ui_helper.createInputText(T"Wireless Password", "wpa_psk", content["wpa_psk"], pskclass, helpmsg["wpa_psk"])
          html[#html + 1] = ui_helper.createInputText(T"Wireless Password", "wpa3", content["wpa3"], pskwpa3, helpmsg["wpa3"])
        else
          if "wpa-psk" == content["security"] or "wpa2-psk" == content["security"] or "wpa-wpa2-psk" == content["security"] then
            html[#html + 1] = ui_helper.createLabel(T"Wireless Password", content["wpa_psk"])
          elseif "wpa3" == content["security"] or "wpa3-psk" == content["security"] or "wpa2-wpa3-psk" == content["security"] or "wpa2-wpa3" == content["security"] then
            html[#html + 1] = ui_helper.createLabel(T"Wireless Password", content["wpa3"])
          end
        end
      end
      if not multiap_enabled then
        html[#html + 1] = ui_helper.createInputText(T"WEP Key", "wep_key", content["wep_key"], wepclass, helpmsg["wep_key"])
      end
    end

    if ( isguest ~= "1" and isExtRemman  ~= "1" and isIntRemman ~= "1") and not multiap_enabled then
      local monitorradius = {
        class ="monitor-security monitor-wpa monitor-wpa2 monitor-wpa-wpa2",
      }
      local ipclass = {
        pattern="^(((([1]?\\d)?\\d|2[0-4]\\d|25[0-5])\\.){3}(([1]?\\d)?\\d|2[0-4]\\d|25[0-5]))|([\\da-fA-F]{1,4}(\\:[\\da-fA-F]{1,4}){7})|(([\\da-fA-F]{1,4}:){0,5}::([\\da-fA-F]{1,4}:){0,5}[\\da-fA-F]{1,4})$"
      }
      local serverclass = {
        group = monitorradius,
        input = ipclass
      }
      local basicclass = {
        group = monitorradius,
      }
      if bandsteerobj and band_steer_enabled and not isBaseIface(curiface) then
        if "wpa" == content["security"] or "wpa2" == content["security"] or "wpa-wpa2" == content["security"] then
          if radius_authent then
            html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server's IP", "radius_authent_ip", content["radius_authent_ip"], serverclass, helpmsg["radius_authent_ip"])
            html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server's port", "radius_authent_port", content["radius_authent_port"],basicclass, helpmsg["radius_authent_port"])
            html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server's secret", "radius_authent_secret", content["radius_authent_secret"],basicclass, helpmsg["radius_authent_secret"])
          end
          if radius_account then
            html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server's IP", "radius_account_ip", content["radius_account_ip"], serverclass, helpmsg["radius_account_ip"])
            html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server's port", "radius_account_port", content["radius_account_port"],basicclass, helpmsg["radius_account_port"])
            html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server's secret", "radius_account_secret", content["radius_account_secret"],basicclass, helpmsg["radius_account_secret"])
          end
        end
      else
        if radius_authent then
          html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server's IP", "radius_authent_ip", content["radius_authent_ip"], serverclass, helpmsg["radius_authent_ip"])
          html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server's port", "radius_authent_port", content["radius_authent_port"],basicclass, helpmsg["radius_authent_port"])
          html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server's secret", "radius_authent_secret", content["radius_authent_secret"],basicclass, helpmsg["radius_authent_secret"])
        end
        if radius_account then
          html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server's IP", "radius_account_ip", content["radius_account_ip"], serverclass, helpmsg["radius_account_ip"])
          html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server's port", "radius_account_port", content["radius_account_port"],basicclass, helpmsg["radius_account_port"])
          html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server's secret", "radius_account_secret", content["radius_account_secret"],basicclass, helpmsg["radius_account_secret"])
        end
      end
    end

    --Don't show wps for Guest

    if isguest ~= "1" or post_helper.getVariantValue(variantHelper, "WPSWarning") then
      local wps_warning = {
        alert = {
          class = "alert-warning monitor-security monitor-wep monitor-wpa-psk monitor-ap_broadcast_ssid monitor-0 monitor-default-show"
        },
      }
      if "wep" == content["security"] then
        html[#html + 1] = ui_helper.createAlertBlock(T"WPS is automatically disabled if you choose WEP or disable broadcast of the SSID", wps_warning)
      else
        html[#html + 1] = ui_helper.createAlertBlock(T"WPS is automatically disabled if you choose to disable broadcast of the SSID", wps_warning)
      end
      if wps_ssid and wps_ssid[curradio] and post_helper.getVariantValue(variantHelper, "WPSWarning") then
        local wps_other = {
          alert = {
            class = "alert-warning"
          },
        }
        html[#html + 1] = ui_helper.createAlertBlock(format(T"WPS is automatically disabled as %s has WPS enabled", wps_ssid[curradio]),wps_other)
      else
        local wps_class = {
          group = {
            class = "monitor-security monitor-none monitor-wpa2-psk monitor-wpa-wpa2-psk monitor-ap_broadcast_ssid monitor-1"
          }
        }
        if ((curiface ~= "wl1" and smartWifi == "1") or (smartWifi ~= "1")) then
          html[#html + 1] = ui_helper.createSwitch(T"WPS", "wps_enabled", content["wps_enabled"], wps_class)
        end
        if (tonumber(content["wps_ap_setup_locked"]) == 1) then
          content["wps_ap_pin_code"] = "Disabled"
        end

        if post_helper.getVariantValue(variantHelper, "showWPSPin") then
	  if not post_helper.isFeatureEnabled("hideWPSAPPin", role) then
            html[#html + 1] = ui_helper.createLabel(T"WPS AP PIN code", content["wps_ap_pin_code"], wps_class)
	  end
          wps_class["input"] = {
            class="no-save",
            ["data-for"] = "wps_device_pin_code",
          }
          wps_class["button"] = {
            ["data-name"] = "action",
            ["data-value"] = "wps_device_pin_code",
          }
          html[#html + 1] = ui_helper.createInputTextWithButton(T"WPS Device PIN code", "wps_device_pin_code", content["wps_device_pin_code"], T"Set PIN code", "icon-ok-sign" ,wps_class, helpmsg["wps_device_pin_code"])
        end

        wps_class["button"] = {
          ["data-name"] = "action",
          ["data-value"] = "wps_pbc",
        }
        if radioData[curradio] and (radioData[curradio].remotely_managed ~= "1" or radioData[curradio].integrated_ap == "1") or "" then
           html[#html + 1] = ui_helper.createButton(T"WPS PBC", T"Trigger", "icon-refresh", wps_class)
        end
      end
    end

    if post_helper.isFeatureEnabled("bandSteerField", role) and bandsteerobj and not multiap_enabled then
      if post_helper.getVariantValue(variantHelper, "bandsteerSupport")  then
        if content["ap_enabled"] == "1" and bs_peer_network_enable == "1" and band_steer_supported then
          local bssecclass = {
            group = {
              class ="monitor-security monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk monitor-wpa3-psk monitor-wpa2-wpa3-psk monitor-wep monitor-wpa-wpa2 monitor-wpa2 monitor-none",
            },
          }
          if smartWifi ~= "1" then
            if isBaseIface(curiface) then
              html[#html + 1] = ui_helper.createAlertBlock(T"Detecting a Wi-Fi client's capabilities and monitoring its interfaces, Band Steering actively guides the client to the more suitable Wi-Fi band.", bssecclass)
              if not band_steer_enabled and post_helper.getVariantValue(variantHelper, "bandsteerDisabledAlert") then
                html[#html + 1] = ui_helper.createAlertBlock(T"If you want to control which band to connect to you must give each SSID a separate name, if you keep same name for both SSIDs the clients will choose which band to connect.", bssecclass)
              end
	      html[#html + 1] = ui_helper.createSwitch(T"Band Steering Enabled", "band_steer_enabled", band_steer_enabled and "1" or "0", bssecclass)
              html[#html + 1] = ui_helper.createAlertBlock( T"If a wireless device reports this gateway's 2.4GHz signal strength is above this threshold, the gateway will ask the device to test the 5GHz band . Please see 5GHz section for additional parameter.",bssecclass)
              html[#html + 1] = ui_helper.createSliderSelect(T"2.4GHz Band Steering Threshold", "rssi_threshold", bandsteer_rssi_threshold, content_rssi["rssi_threshold"], bssecclass)
            else
              html[#html + 1] = ui_helper.createAlertBlock( T"Detecting a Wi-Fi client's capabilities and monitoring its interfaces, Band Steering actively guides the client to the more suitable Wi-Fi band.", ssidclass)
              if not band_steer_enabled and post_helper.getVariantValue(variantHelper, "bandsteerDisabledAlert") then
                html[#html + 1] = ui_helper.createAlertBlock(T"If you want to control which band to connect to you must give each SSID a separate name, if you keep same name for both SSIDs the clients will choose which band to connect.", bssecclass)
              end
	      html[#html + 1] = ui_helper.createLabel(T"Band Steering Enabled", band_steer_enabled and "On" or "Off", ssidclass)
            end
          end
        end
      else
        if band_steer_supported and bandsteerobj then
          local bssecclass = {
            group = {
              class ="monitor-security monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk monitor-wpa2 monitor-none monitor-wpa3 monitor-wpa3-psk monitor-wpa2-wpa3 monitor-wpa2-wpa3-psk",
            },
          }
          if isBaseIface(curiface) then
	    html[#html + 1] = ui_helper.createSwitch(T"Band Steering Enabled", "band_steer_enabled", band_steer_enabled and "1" or "0", bssecclass)
            html[#html + 1] = ui_helper.createAlertBlock( T"Band Steering works only if 2.4 GHz and 5 GHz have the same configuration. By enabling the Band Steering, the 2.4 GHz network settings will be propagated on 5GHz settings", bssecclass)
          else
	    html[#html + 1] = ui_helper.createLabel(T"Band Steering Enabled", band_steer_enabled and "On" or "Off", ssidclass)
            html[#html + 1] = ui_helper.createAlertBlock(T"Band Steering works only if 2.4 GHz and 5 GHz have the same configuration. By enabling the Band Steering, the 2.4 GHz network settings will be propagated on 5GHz settings", bssecclass)
          end
        end
      end
    end
  end
  ngx.print(html)
  ngx.print('\
  <input type="hidden" name="radius_authent_state" value="" >\
  <input type="hidden" name="radius_account_state" value="" >\
  ');  if post_helper.getVariantValue(variantHelper, "hiddenSupport") then   ngx.print('\
    <input type="hidden" id= "check_band_change" name="check_band_change" value="0">\
  ');  end   ngx.print('\
</fieldset>\
');  
if not stbLimit then
  html = {}
  html[#html + 1] = "<fieldset class=\"advanced hide\">"
  html[#html + 1] = "<legend>"
  html[#html + 1] =  T"Access Control List"
  html[#html + 1] = [[</legend>]]
  local aclmodeclass = {
    select = {
      class = "monitor-changes",
      id="aclmode"
    }
  }

  if post_helper.getVariantValue(variantHelper, "ACLWarning") then
    if ngx.req.get_method() == "POST" and  ngx.req.get_post_args().action ~="nil" and string.find(ngx.req.get_post_args().action, "TABLE") ~= nil then
      local tableid = ngx.req.get_post_args().tableid
      if tableid == "acl_whitelist" then
        content["acl_mode"] = "lock"
      elseif tableid == "acl_blacklist" then
        content["acl_mode"] = "unlock"
      elseif tableid == "acl_register" then
        content["acl_mode"] = "register"
      end
      html[#html + 1] = ui_helper.createInputSelect(T"ACL mode", "acl_mode", acl_modes, content["acl_mode"], aclmodeclass)
      html[#html + 1] = loadAclList(content["acl_mode"], "POST")
      isTableLoaded =  true
    else
      html[#html + 1] = ui_helper.createInputSelect(T"ACL mode", "acl_mode", acl_modes, content["acl_mode"], aclmodeclass)
      local acl_attribute = {
        label = {
          class = "monitor-acl_mode monitor-register"
        },
        button = {
          class = "monitor-acl_mode monitor-register",
          id = "btn_acl"
        }
      }
      html[#html + 1] = ui_helper.createButton(T"ACL Reg", T"Register", nil, acl_attribute)
      html[#html + 1] = "<div id=\"acl_list_div\" class=\"monitor-acl_mode monitor-lock monitor-register monitor-unlock\"><img src=\"/img/loading.gif\"/></div>"
    end
   else
     html[#html + 1] = ui_helper.createInputSelect( T"ACL mode", "acl_mode", acl_modes, content["acl_mode"], aclmodeclass)
    local infomessage = {
        alert = {
          class = "alert-info monitor-acl_mode monitor-disabled",
        }
    }
    html[#html + 1] = ui_helper.createAlertBlock(T"Disabled mode will allow access to all devices", infomessage)
    local whitelistinfoclass = {
        alert = {
          class = "alert-info monitor-acl_mode monitor-lock",
        }
    }
    html[#html + 1] = ui_helper.createAlertBlock(T"White List mode will deny access to all devices, except for the devices with MAC address in the list below:", whitelistinfoclass)

    local blacklistinfoclass = {
        alert = {
          class = "alert-info  monitor-acl_mode monitor-unlock",
        }
    }
    html[#html + 1] = ui_helper.createAlertBlock(T"Black List mode will allow access to all devices, except for the devices with MAC address in the list below:", blacklistinfoclass)
     html[#html + 1] = loadAclList(content["acl_mode"], "POST")
   end
  html[#html + 1] = [[</fieldset>]]
  ngx.print(html)
end
  ngx.print('\
\
');  if post_helper.getVariantValue(variantHelper, "qrCodeFeature") then   ngx.print('\
  <fieldset>\
    ');  if content["security"] ~= "wpa-wpa2" and content["security"] ~= "wpa2" then   ngx.print('\
        <legend>');  ngx.print( T"QR Code" ); ngx.print('</legend>\
        ');  ngx.print( format([[
          <center>
             <div class="btn custom-handler" data-remote="modals/wireless-qrcode-modal.lp?iface=%s&ap=%s" data-toggle="modal">
             %s
             </div>
          </center>
        ]], curiface, curap, T"Generate QRCode")
     ); ngx.print('\
    ');  end  ngx.print('\
  </fieldset>\
');  
end
if post_helper.isFeatureEnabled("wpsdevlist", role) then
  local devColumns = {
    {
      header = T"Device Name",
      type = "text",
      param = "DeviceName",
      readonly = true
    },
    {
      header = T"IP Address",
      type = "text",
      param = "IPAddress",
      readonly = true
    },
    {
      header = T"MAC Address",
      type = "text",
      param = "MACAddress",
      readonly = true
    },
    {
      header = T"WPS Type",
      type = "text",
      param = "WPSType",
      readonly = true
    },
    {
      header = T"WPS State",
      type = "text",
      param = "WPSState",
      readonly = true
    }
  }

  local devList = proxy.get("uci.wpsdevlist.dev.")
  devList = content_helper.convertResultToObject("uci.wpsdevlist.dev.", devList)
  local function updateList(index)
    for var, name in pairs(devList) do
      if index == devList[var]["paramindex"] then
        local wps_dev = proxy.add("uci.wireless.wifi-ap.@"..curap..".acl_deny_list.")
        proxy.set(format("uci.wireless.wifi-ap.@"..curap..".acl_deny_list.@%s.value",wps_dev), devList[var]["MACAddress"])
        proxy.apply()
      end
    end
  end

  local devOptions = {
    tableid = "wpsDev",
    basepath = "uci.wpsdevlist.dev.",
    canAdd = false,
    canEdit = false,
    canDelete = true,
    onDelete = updateList
  }

  local devicefilter =  function(data)
    local hostsList = proxy.get("sys.hosts.host.")
    hostsList = content_helper.convertResultToObject("sys.hosts.host.", hostsList)
    for _, host in pairs(hostsList) do
      if lower(data["MACAddress"]) == lower(host["MACAddress"]) then
        data.IPAddress = match(host["IPAddress"], "%d+.%d+.%d+.%d+") or ""
        data.DeviceName =  host["FriendlyName"]
      end
    end
    return true
  end
  local deviceData = post_helper.handleTableQuery(devColumns, devOptions, devicefilter , nil, nil)
  ngx.print('\
<fieldset>\
<legend>');  ngx.print( T"WPS Device Service List" ); ngx.print('</legend>\
<div class="wpsEnabled">\
  ');  
     local html = {}
     html[#html + 1] = ui_helper.createAlertBlock(T"Removing the device from the WPS list will place the device in the MAC authentication denied device list. To allow the device remove the device from the MAC authentication denied list.")
     html[#html + 1] = ui_helper.createTable(devColumns, deviceData, devOptions, nil)
     ngx.print(html)
    ngx.print('\
</div>\
</fieldset>\
');  
end
else
  --wifi analyzer handler
  local uri = ngx.var.uri
  if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
  end
  ngx.print('\
<form id="wifiForm" class="form-horizontal" method="post" action="');  ngx.print(uri); ngx.print('">\
');  if radio == "radio_2G" then   ngx.print('\
  <div class="span6">\
');  else   ngx.print('\
  <div class="span6" style="margin-left:0;">\
');  end   ngx.print('\
<fieldset>\
  <legend>');  ngx.print( T"Wifi Analyzer" ); ngx.print('</legend>\
  <div style = "display:block;" class = "alert-info hide">');  ngx.print(T"Please press Rescan button to view the updated wifi list"); ngx.print('</div></br>\
    <div id ="analyzerloader" style="height:100px"><img src = "/img/loading.gif"></img></div>\
    <div id = "analyzerGraph" class="hide">\
      ');  ngx.print( T"The below chart shows the results of the latest scan of your local area from your gateway." ); ngx.print('\
      ');  if radio == "radio_2G" then   ngx.print('\
        <canvas id="wrapper" width="720px" height="400px" style="border:1px solid #c3c3c3;">\
      ');  else   ngx.print('\
        <canvas id="wrapper" width="890px" height="400px" style="border:1px solid #c3c3c3;">\
      ');  end   ngx.print('\
      ');  ngx.print( T"Please update your browser to use this page." ); ngx.print('\
      </canvas>\
');  
    html = {}

    local freq = "2"
    if radio == "radio_5G" then freq = "5" or "2" end
    html[#html + 1] = format([[
    <div id="ReScan_%s" style="width:650px;text-align:right;margin-right:20px;"><div id="rescanbtn" class="btn btn-primary btn-large">%s</div></div>]],
      freq,T"Re-scan")

    html[#html + 1] = format([[
      <div id = confirming-msg_%s class= "alert hide"> %s </div> ]],
      freq,T"If you use this tool, devices connected will be disconnected and will be able to connect after 1 minute.")
    html[#html + 1] = format([[
      <div id="rescan-changes_%s" class="hide">
      <div id="rescan-cancel_%s" class="btn">%s</div>
      <div id="rescan-confirm_%s" class="btn btn-primary" data-dimiss="modal">%s</div></div>]],
      freq,freq,T"Cancel",freq,T"Accept")
    ngx.print(html)
  ngx.print('\
\
\
</div>\
<div id="key" style="width: 700px;"></div>\
<div id ="analyzerloader1" style="height:100px"><img src = "/img/loading.gif"></img></div>\
</fieldset>\
</div>\
</form>\
\
<div id="ssid_info" class="popUp smallcard span4" style="left: 32%; margin: 0px; border-radius: 13px;display:none;height:254px;top:480px">\
  <div class="header">\
     <div class="header-title pull-left">\
       <p class="ssidinfo_poptitle">');  ngx.print(T"More Details"); ngx.print('</p>\
     </div>\
  </div>\
  <div id="ssidInfo_Poptxt" class="content" style="height:140px;">\
    <div class="deviceinfoline"><span class="hostinfoleft">');  ngx.print(T"SSID Name"); ngx.print('</span><span class="hostinforight" id="ssidName"></span></div>\
    <div class="deviceinfoline"><span class="hostinfoleft">');  ngx.print(T"MAC Address"); ngx.print('</span><span class="hostinforight" id = "macAddrCh"></span></div>\
    <div class="deviceinfoline"><span class="hostinfoleft">');  ngx.print(T"Signal Strength(dBm)"); ngx.print('</span><span class="hostinforight" id="signalStrength"></span></div>\
    <div class="deviceinfoline"><span class="hostinfoleft">');  ngx.print(T"Channel"); ngx.print('</span><span class="hostinforight" id="channelInfo"></span></div>\
   <div class="deviceinfoline"><span class="hostinfoleft">');  ngx.print(T"Channel Width"); ngx.print('</span><span class="hostinforight" id="chWidth"></span></div>\
   <div class="deviceinfoline"><span class="hostinfoleft">');  ngx.print(T"Protection Mode"); ngx.print('</span><span class="hostinforight" id="protMode"></span></div>\
 </div>\
 <div class="modal-footer" style="font-size: 15px;padding-top:6px;padding-bottom:6px;">\
   <div id="modal-no-change">\
     <div id="moreDetails-btn-ok" class="btn btn-primary">');  ngx.print(T"Close"); ngx.print('</div>\
   </div>\
 </div>\
</div>\
\
<script>\
  var radio = "');  ngx.print(radio); ngx.print('";\
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
<script src="/js/wireless-analyzer.js"></script>\
\
');  
--End of wifi analyzer
end  ngx.print('\
');  
-- Do not display the navlist on the list if no SSID
if #wls > 0 then
  ngx.print('\
</div>\
');  
end
  ngx.print('\
</form>\
</div>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
<script>\
  var curiface = "');  ngx.print(curiface); ngx.print('";\
  var curradio = "');  ngx.print(curradio); ngx.print('";\
  var currentRole = "');  ngx.print(role); ngx.print('";\
  var smartwifivalue = "');  ngx.print(smartWifi); ngx.print('";\
  var smartwifiphasevalue = "');  ngx.print(smartWifiPhase); ngx.print('";\
  var smartWifiMsg = \'');  ngx.print(T"Your Smart Wi-Fi service is active and managing your existing Wi-Fi and Parental Control settings. You can override your Wi-Fi and Parental settings in the Smart Wi-Fi App."); ngx.print('\';\
  var smartwifi = ');  ngx.print(post_helper.isFeatureEnabled("smartwifi")); ngx.print(';\
  var isTableLoaded = ');  ngx.print(isTableLoaded); ngx.print(';\
  var acl_mode = "');  ngx.print(content["acl_mode"]); ngx.print('";\
  var current_acl_mode = "');  ngx.print(current_acl_mode); ngx.print('";\
  var curap = "');  ngx.print(curap); ngx.print('";\
  var helpmsg = ');  ngx.print(json.encode(helpmsg)); ngx.print(';\
  var bandsteerSupport = ');  ngx.print(bandsteerobj and post_helper.getVariantValue(variantHelper, "bandsteerSupport") or false); ngx.print(';\
  var bandsteerDisabled = ');  ngx.print(post_helper.isFeatureEnabled("bandsteerDisabled" , role)); ngx.print(';\
  var ssidCheck = ');  ngx.print(post_helper.getVariantValue(variantHelper, "ssidCheck")); ngx.print(';\
  var passwordStrength = ');  ngx.print(post_helper.getVariantValue(variantHelper, "passwordStrength")); ngx.print(';\
  var ssidCheck = ');  ngx.print(post_helper.getVariantValue(variantHelper, "ssidCheck")); ngx.print(';\
  var securitynone = ');  ngx.print(post_helper.getVariantValue(variantHelper, "securityPopupShow")); ngx.print(';\
  var channelWithNo160MHz = "');  ngx.print(channelWithNo160MHz); ngx.print('";\
  var channelWidth = "');  ngx.print(content["requested_channel_width"]); ngx.print('";\
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
<script src="/js/wireless-modal.js"></script>\
'); 
