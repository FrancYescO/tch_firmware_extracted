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
local pairs = pairs
local match, format, next = string.match, string.format, next
local json = require("dkjson")
local role = session:getrole()

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
local validateStringIsIPv6 = post_helper.validateStringIsIP(6)
local getOrValidation = post_helper.getOrValidation
local getValidateStringISIP = getOrValidation(validateStringIsIP, validateStringIsIPv6)
local wpa_list = {"wpa2", "wpa-wpa2"}
local validateIfProp_IP = getValidationIfPropInList(getValidateStringISIP, "security", wpa_list)
local validateIfProp_port = getValidationIfPropInList(validateStringIsPort, "security", wpa_list)
local content, helpmsg = {},{}
local getargs = ngx.req.get_uri_args()
local getradio = getargs.radio
local getiface = getargs.iface
local getWifiAnalyzer = getargs.isWifiAnalyzer

local curradio = "radio_2G"
local curiface = "wl0"
local curap = "ap0"
local isguest = "0"
local isExtRemman = "0" -- AP remotely managed, like a TG233 DANT-5 board in AP mode.
local stbLimit = false
local radio2iface = {}
local is11nStdSelected, is11nStdSelected_5G = false

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
  --[[
  for _, v in ipairs(ssid_details) do
    bsslistData[#bsslistData+1] = v
  end
  ]]
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

local fonPath = "uci.hotspotd.wifi-iface."
local fonIfaces = content_helper.convertResultToObject(fonPath .. "@.", proxy.get(fonPath))
local ssidMap = {}
for _, v in ipairs(fonIfaces) do
  local iface = format("%s", v.iface)
  ssidMap[iface] = true
end

local pIface = "uci.wireless.wifi-iface."
local availableWirelessInterfaces = content_helper.convertResultToObject(pIface .. "@.", proxy.get(pIface))
local wifiEP = "uci.wireless.wifi-ep."
local availableEPIntf = content_helper.convertResultToObject(wifiEP .. "@.", proxy.get(wifiEP))
local wifiEPPath = "uci.wireless.wifi-ep-profile."
local availableEP = content_helper.convertResultToObject(wifiEPPath .."@.", proxy.get(wifiEPPath))

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

local intfCheck = 0
if getiface and string.match(getiface, "ep*") then
  intfCheck = 1
end
--Get the wifi-ep and wifi-ep-profile path values
local epIntfRadio, epIntfIface
local wls_ep = {}
for _, v in ipairs(availableEP) do
  for _, intf in ipairs(availableEPIntf) do
    if intf.state == "1" then
      epIntfIface = intf.iface
      epIntfRadio = proxy.get(format("rpc.wireless.ssid.@%s.radio", intf.iface))[1].value
      wls_ep[#wls_ep+1] = {
        radio = epIntfRadio,
        ssid = v.ssid,
        iface = v.paramindex
      }
    end
  end
  if v.paramindex == getiface then
    curiface = v.paramindex
  end
end
table.sort(wls_ep, function(a,b)
  if a.radio == b.radio then
    return a.iface < b.iface
  else
    return a.radio < b.radio
  end
end)

local ap_paths = {true}
for i, v in ipairs(proxy.getPN("rpc.wireless.ap.", true)) do
  ap_paths[i] = v.path.."ssid"
end

local wl_list = proxy.get(unpack(ap_paths)) or {}
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
    if (v.value == getiface) or (not getiface and v.value == curiface) then
      curiface = v.value
      curap = match(v.path, "rpc%.wireless%.ap%.@([^%.]+)%.")
      isguest = proxy.get(v.path .. "ap_isolation")[1].value
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
  local setTable = {}
  if postargs.wpa3 and postargs.security and string.match(postargs.security, "wpa3") then
    setTable["rpc.wireless.ap.@" .. curap  .. ".security.wpa_psk_passphrase"] = postargs.wpa3
    setTable["uci.wireless.wifi-ap-credential.@" .. curap .. "_credential0.passphrase"] = postargs.wpa3
    if postargs.security == "wpa2-wpa3-psk" then
      setTable["uci.wireless.wifi-ap.@" .. curap  .. ".pmf"] = "enabled"
    elseif postargs.security == "wpa3-psk" then
      setTable["uci.wireless.wifi-ap.@" .. curap  .. ".pmf"] = "required"
    end
  else
     setTable["uci.wireless.wifi-ap.@" .. curap  .. ".pmf"] = "disabled"
  end
  success = proxy.set(setTable)
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

local radioData ={}
for _, v in ipairs(radios) do
  local path = "rpc.wireless.radio.@" .. v
  local rdata = proxy.get(path..".supported_frequency_bands" ,
  path .. ".remotely_managed",
  path .. ".supported_standards",
  path .. ".integrated_ap",
  path .. ".capabilities")
  if rdata ~= nil then
    radioData[v] = {
      supported_frequency_bands = rdata[1].value,
      remotely_managed = rdata[2].value,
      supported_standards = rdata[3].value,
      integrated_ap = rdata[4].value,
      capabilites = rdata[5].value
    }
  end
end

if radioData[curradio] and radioData[curradio].remotely_managed == "1"  then
  if radioData[curradio].integrated_ap ~= "1" then
    isExtRemman = "1"
  end
end
local antenna = "2x2"
if radioData[curradio] and radioData[curradio].capabilites ~= "" then
   antenna = string.match(radioData[curradio].capabilites, "%dx%d")
end
local cddList = {
  {"1",  T"Auto"},
  {"on", T"On"},
  {"off", T"Off"}
}

local supported_modes_data  = proxy.get("rpc.wireless.ap.@" .. curap .. ".security.supported_modes")
local supported_modes = format("%s", supported_modes_data and supported_modes_data[1] and supported_modes_data[1].value or "")
local secmodes = {}
local secmodes_matched = {
  ["none"] = T"None",
  ["wpa2-psk"] = T"WPA2 PSK",
  ["wpa-wpa2-psk"] = T"WPA+WPA2 PSK",
  ["wpa-wpa2"] = T"WPA+WPA2"
}
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
local radius_account = proxy.get(pathRadius .. "acct0.")
local radius_authent = proxy.get(pathRadius .. "auth0.")

-- If this AP connects to STB, "engineer" role has full access, other roles only have simple stats
if proxy.get(pathiface .. "stb") and proxy.get(pathiface .. "stb")[1].value then
  if proxy.get(pathiface .. "stb")[1].value == "1" then
    if ngx.ctx.session:getrole() ~= "engineer" then
      stbLimit = true
    end
  end
end

local multiap_enabled = false
local multiap_state = {
  agent = "uci.multiap.agent.enabled",
  controller = "uci.multiap.controller.enabled"
}
content_helper.getExactContent(multiap_state)
multiap_enabled = multiap_state.agent == "1"
local pathepiface = intfCheck == 1 and epIntfIface or curiface
local pathmode = format("uci.wireless.wifi-iface.@%s.mode", pathepiface)

local mapParams,mapValid = {}, {}
local output = {}
if intfCheck == 0 then
  mapParams.ap_enabled = pathap .. "admin_state"
  mapParams.ssid = pathiface .. "ssid"
  mapParams.mode = pathmode
  mapParams.ap_broadcast_ssid = pathap .. "public"
  mapParams.security = pathap .. "security.mode"
  mapParams.wep_key = pathap .. "security.wep_key"
  mapParams.wpa_psk = pathap .. "security.wpa_psk_passphrase"
  mapParams.wps_button_handler = wpshandler_data and "uci.button.button.@wps.handler"
  if proxy.get(pathapWpa3 .. "credential0.passphrase") then
    mapParams.wpa3 = pathapWpa3 .. "credential0.passphrase"
  end

  local multiap_cred_secondary_path
  -- Only include radius configuration in UI if not in guest/hotspot mode or not remotely managed
  -- Only include SGI, CDD, and STBC if not guest/hotspot or not remotely managed
  local function getParamsAndValidationForRadius()
    local mapRadiusParams = {}
    if isguest ~= "1" and isExtRemman ~= "1" and not stbLimit then
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
      mapParams.wps_enabled = pathap .. "wps.admin_state"
      mapParams.wps_pin_enabled = pathap .. "wps.ap_setup_locked"
      for _, v in pairs(radios) do
        if v ~= curradio then
          mapParams["admin_state_" .. v] = "rpc.wireless.radio.@" .. v .. ".admin_state"
        end
      end
    end

    if wps_ssid then
      mapParams.wps_button_handler = nil
    end

    if isguest ~= "1" then
      local multiap_cred_path = "uci.multiap.controller_credentials."
      local multiap_cred_data = content_helper.convertResultToObject(multiap_cred_path .. "@.", proxy.get(multiap_cred_path))
      local multiap_cred = {}
      for _, v in ipairs(multiap_cred_data) do
        if v.fronthaul == '1' then
          if match(v.frequency_bands, "radio_2G") then
            multiap_cred.primary = v.paramindex
          else
            multiap_cred.secondary = v.paramindex
          end
        end
      end

      local multiap_cred_primary_path = multiap_cred.primary and multiap_cred_path .."@" .. multiap_cred.primary
      multiap_cred_secondary_path = multiap_cred.secondary and multiap_cred_path .."@" .. multiap_cred.secondary
      if multiap_cred_primary_path and multiap_cred_secondary_path then
        mapParams["multiap_cred_primary_bands"] = multiap_cred_primary_path .. ".frequency_bands"
        mapParams["multiap_cred_secondary_state"] = multiap_cred_secondary_path .. ".state"
      end

      local multiap_prefix = multiap_enabled and "" or "multiap_"
      if multiap_cred_secondary_path then
        mapParams[multiap_prefix .. "ssid"] = multiap_cred_secondary_path .. ".ssid"
        mapParams[multiap_prefix .. "wpa_psk"] = multiap_cred_secondary_path .. ".wpa_psk_key"
        mapParams[multiap_prefix .. "security"] = multiap_cred_secondary_path .. ".security_mode"
      elseif multiap_cred_primary_path then
        mapParams[multiap_prefix .. "ssid"] = multiap_cred_primary_path .. ".ssid"
        mapParams[multiap_prefix .. "wpa_psk"] = multiap_cred_primary_path .. ".wpa_psk_key"
        mapParams[multiap_prefix .. "security"] = multiap_cred_primary_path .. ".security_mode"
      end
      if multiap_cred_secondary_path then
        mapParams[multiap_prefix .. "bspifacessid"] = multiap_cred_secondary_path .. ".ssid"
        if mapParams.bspifacessid then
          mapParams[multiap_prefix .. "bspeer_wpa_psk"] = multiap_cred_secondary_path .. ".wpa_psk_key"
          mapParams[multiap_prefix .. "bspeer_security"] = multiap_cred_secondary_path .. ".security_mode"
        end
      end
    end
    mapValid.wpa3 = getValidationIfPropInList(validatePSK,"security", {"wpa3", "wpa3-psk", "wpa2-wpa3", "wpa2-wp3-psk"})
    if multiap_enabled then
      mapParams.ssid_uci = pathiface .. "ssid"
      mapValid.ssid_uci = getAndValidation(getValidateStringLengthInRange(1,32),getValidateExtraSpaces)
      mapParams.bspifacessid_uci = "uci.wireless.wifi-iface.@wl1.ssid"
      mapValid.bspifacessid_uci = getAndValidation(getValidateStringLengthInRange(1,32),getValidateExtraSpaces)
    end

    mapValid.ap_enabled = validateBoolean
    -- Bug fix for NG-12032 GUI wireless enable/disable not working properly
    for _, v in pairs(radios) do
      if v ~= curradio then
        mapValid["admin_state_" .. v] = getInterfaceEnabled2
      end
    end
    return mapParams, mapValid
  end
  mapRadiusParams, mapRadiusValid = getParamsAndValidationForRadius()
  mapParams, mapValid = getParamsAndValidation()
  for k,v in pairs(mapRadiusParams) do
    mapParams[k] = v
  end
  for k,v in pairs(mapRadiusValid) do
    mapValid[k] = v
  end
else
  local pathiface = format("uci.wireless.wifi-ep-profile.@%s.", curiface)
  mapParams.ap_enabled = pathap .. "admin_state"
  mapParams.mode = pathmode
  mapParams.admin_state = "rpc.wireless.radio.@" .. curradio .. ".admin_state"
  output.state = pathiface .. "state"
  output.ssid = pathiface .. "ssid"
  output.security = pathiface .. "security_mode"
  output.wpa_psk = pathiface .. "wpa_psk_key"
  mapParams.wps_button_handler = wpshandler_data and "uci.button.button.@wps.handler"
  content_helper.getExactContent(output)
end
mapValid.ap_enabled = validateBoolean
mapValid.interface_enabled = validateBoolean
mapValid.security = getValidateInEnumSelect(secmodes)
mapValid.ssid = getAndValidation(getValidateStringLengthInRange(1,32),getValidateExtraSpaces)
mapValid.wep_key = getValidationIfPropInList(validateWEP,"security", {"wep"})
mapValid.wpa_psk = getValidationIfPropInList(validatePSK,"security", {"wpa-psk", "wpa2-psk", "wpa-wpa2-psk"})
mapValid.wps_button_handler = function(val, object)
  object.wps_button_handler = wps_button_handler[object.wps_enabled]
  return true
end
mapValid.admin_state = validateBoolean
content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

-- Process POST query
if ngx.req.get_method() == "POST" then
  local postargs = ngx.req.get_post_args()
  if smartWifi == "1" and (curiface == "wl0" or curiface == "wl0_1") then
    proxy.set(format("uci.wireless.wifi-ap.@%s.wpa_psk_key", bspeerap), postargs.wpa_psk)
    proxy.apply()
  end
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
    proxy.set("rpc.wireless.ap.@"..curap..".wps.enrollee_pbc","1")
  end
  -- End of WPS PBC code support
end
-- AP PIN code and Mac - read only
-- "rpc.wireless.ssid.@wl0." and "rpc.wireless.ssid.@wl1." returns empty during hostapd reload is in progress,
-- so introduce delay to hold the save operation until gets valid data from datamodel and also introduce timeout (1 minute max)
-- to break this loop
epIntfIface = epIntfIface and epIntfIface or curiface
local pathInterf = format("rpc.wireless.ssid.@%s.", epIntfIface)
local content_ssid = {
  pathInterf .. "mac_address",
  pathInterf .. "stb",
  pathInterf .. "ap_display_name",
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
local param = {
   platform = "uci.wireless.wifi-device.@radio_5G.type"
}
content_helper.getExactContent(param)

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
  lp.setpath("/www/snippets/")
  lp.include("tabs-wireless.lp")
  ngx.print('\
<form class="form-horizontal" method="post" action="');  ngx.print( ngx.var.request_uri ); ngx.print('">\
');  
local wifi_iface  = proxy.get("uci.gre_hotspotd.hotspot.@hotspot.wifi_iface")
local wifi_iface = wifi_iface and wifi_iface[1] and wifi_iface[1].value or ""

if #wls > 0 then
  ngx.print('\
  <div class="span2">\
    <ul class="nav nav-list">\
    ');  
      local html = {}
      local prevradio = ""
      for i, v in ipairs(wls) do
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
        local url = "modals/wireless-modal.lp?radio=" .. v.radio .. "&iface=" .. v.iface
        -- Do not display stb ssid
        if v.ap_display_name ~= nil and v.ap_display_name ~= "" then
          html[#html+1] = format('<li class="%s"><a  id = "Wireless_Tab_%s" href="#" data-remote="%s">%s</a></li>', active, i, url, v.ap_display_name)
        elseif v.stb == "1" then
          html[#html+1] = format('<li class="%s"><a  id = "Wireless_Tab_%s" href="#" data-remote="%s">%s</a></li>', active, i, url, "IPTV")
        elseif wifi_iface ~= v.iface  then
          html[#html+1] = format('<li class="%s"><a  id = "Wireless_Tab_%s" href="#" data-remote="%s">%s</a></li>', active, i, url, v.ssid)
        end
      end
      for i, v in ipairs(wls_ep) do
       local url = "modals/wireless-modal.lp?radio=" .. v.radio .. "&iface=" .. v.iface
       html[#html+1] = format('<li class="nav-header">%s </li>', T"Station_5GHz")
       local active = ""
       if v.iface == curiface then
         active = "active"
       end
       html[#html+1] = format('<li class="%s"><a  id = "Wireless_Tab_%s" href="#" data-remote="%s">%s</a></li>', active, i, url, v.ssid)
      end
      -- If wifi analyzer enabled, draw it
      local wifi_analyzer_disable = proxy.get("uci.wireless.wifi.@global.wifi_analyzer_disable")
      if wifi_analyzer_disable and wifi_analyzer_disable[1].value ~= "1" then
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
	            html[#html+1] = string.format('<li class="%s"><a href="#" data-remote="%s" >%s %sGHz</a></li>',active, url, T"Analyzer",freq )
              end
             end
             isDuplicate[v.radio] = true
           end
         end
    ngx.print(html, '\
     </ul>\
  </div>\
  <div class="span6">\
  ');  
end

if getWifiAnalyzer == nil then
  ngx.print(ui_helper.createMessages(message_helper.popMessages()))
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

        -- In guest page, do not let the user change the configuration of the wifi radio. Only in main AP
        if isguest == "1" then
          local guest_alert = {
            alert = {
              class = "alert-info"
            },
          }
          -- Display infomation indicating it is a guest SSID
          html[#html + 1] = ui_helper.createAlertBlock(T"This is a guest network. The guest network has no local network access.", guest_alert)

          -- Switch that shows if the Wifi interface is enabled or not
          html[#html + 1] = ui_helper.createLabel(T"Frequency band", radioData[curradio].supported_frequency_bands)
          -- Show Antenna Setup
          html[#html + 1] = ui_helper.createLabel(T"Antenna", antenna, advanced)
          -- Label that shows the MAC address of the Wifi interface
          html[#html + 1] = ui_helper.createLabel(T"MAC address", content["macaddress"])
        else
          -- Switch that shows if the Wifi interface is enabled or not
          if not stbLimit then
            html[#html + 1] = ui_helper.createSwitch(T"Enabled", "admin_state", content["admin_state"])
          end
          html[#html + 1] = ui_helper.createLabel(T"Frequency band", radioData[curradio].supported_frequency_bands and radioData[curradio].supported_frequency_bands or "")
           -- Show Antenna Setup
          html[#html + 1] = ui_helper.createLabel(T"Antenna", antenna, advanced)
          -- Label that shows the MAC address of the Wifi interface
          html[#html + 1] = ui_helper.createLabel(T"MAC address", content["macaddress"])
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
  html[#html + 1] = content.mode and content.mode == "ap" and T"Access Point" or content.mode == "sta" and T"Station" or ""
  html[#html + 1] = [[</legend>]]

  local labelclass = {
    input = {
      maxlength= "32",
      class= "span4",
    }
  }
  if content.mode == "sta" then
    html[#html + 1] = ui_helper.createLabel(T"Enabled", output["state"] == "1" and T"On" or T"Off", advanced)
    html[#html + 1] = ui_helper.createLabel(T"SSID name", output["ssid"] , labelclass)
    html[#html + 1] = ui_helper.createLabel(T"Security Mode", output["security"] == "none" and T"None" or string.upper(output["security"]), labelclass)
    if output["security"] ~= "none" then
      html[#html + 1] = ui_helper.createLabel(T"Wireless Password", output["wpa_psk"], labelclass)
    end
    local wps_class = {
      button = {
        ["data-name"] = "action",
        ["data-value"] = "wps_pbc",
      }
    }
    html[#html + 1] = ui_helper.createButton(T"WPS PBC", T"Trigger", "icon-refresh", wps_class)
  else
  -- Show if the AP is enabled
  html[#html + 1] = ui_helper.createSwitch(T"Enabled", "ap_enabled", content["ap_enabled"], advanced)

  if not stbLimit then
    -- Show the SSID
    local ssidclass = {
      input = {
        maxlength= "32",
        class= "span4",
      }
    }
    --Only baseiface can modify ssid when bandsteer enabled
    if smartWifi == "1" and curiface == "wl1" or (multiap_enabled and string.find(multiap_bsslist, curiface)) then
      html[#html + 1] = ui_helper.createLabel( T"SSID name", content["ssid"], ssidclass)
    else
      html[#html + 1] = ui_helper.createInputText(T"SSID name", "ssid", content["ssid"], ssidclass, helpmsg["ssid"])
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
    if smartWifi == "1" and curiface == "wl1" or (multiap_enabled and string.find(multiap_bsslist, curiface)) then
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

    if smartWifi == "1" and curiface == "wl1" or (multiap_enabled and string.find(multiap_bsslist, curiface)) then
     if content["security"] ~= "none" then
       html[#html + 1] = ui_helper.createLabel(T"Wireless Password", content["wpa_psk"], pskclass)
     end
    else
     if content["security"] ~= "none" then
       html[#html + 1] = ui_helper.createInputText(T"Wireless Password", "wpa_psk", content["wpa_psk"], pskclass, helpmsg["wpa_psk"])
       html[#html + 1] = ui_helper.createInputText(T"Wireless Password", "wpa3", content["wpa3"], pskwpa3, helpmsg["wpa_psk"])
     end
    end
    if content["security"] == "wep" then
      html[#html + 1] = ui_helper.createInputText(T"WEP Key", "wep_key", content["wep_key"], wepclass, helpmsg["wep_key"])
    end

    if ( isguest ~= "1" and isExtRemman  ~= "1") then
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
      end

    --Don't show wps for Guest
    if isguest ~= "1" then
      local wps_class = {
          group = {
            class = "monitor-security monitor-none monitor-wpa2-psk monitor-wpa-wpa2-psk monitor-ap_broadcast_ssid monitor-1"
          },
          button = {
            ["data-name"] = "action",
            ["data-value"] = "wps_pbc",
          }
       }
      if radioData[curradio] and radioData[curradio].remotely_managed ~= "1" or radioData[curradio].integrated_ap == "1"  then
         html[#html + 1] = ui_helper.createButton(T"WPS PBC", T"Trigger", "icon-refresh", wps_class)
      end
    end
  end
  end
  ngx.print(html)
  ngx.print('\
  <input type="hidden" name="radius_authent_state" value="" >\
  <input type="hidden" name="radius_account_state" value="" >\
  <input type="hidden" name="ssid_uci" id="ssid_uci" value="" >\
  <input type="hidden" name="bspifacessid_uci" id="bspifacessid_uci" value="" >\
</fieldset>\
');  
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
<legend>', T"Wifi Analyzer" , '</legend>\
<div style = "display:block;" class = "alert-info hide">', T"Please press Rescan button to view the updated wifi list", '</div></br>\
<div id ="analyzerloader" style="height:100px"><img src = "/img/loading.gif"></img></div>\
<div id = "analyzerGraph" class="hide">\
', T"The below chart shows the results of the latest scan of your local area from your gateway.");
--if radio == "radio_2G" then
	ngx.print('<canvas id="wrapper" width="720px" height="400px" style="border:1px solid #c3c3c3;">');
--else
--	ngx.print('<canvas id="wrapper" width="890px" height="400px" style="border:1px solid #c3c3c3;">');
--end
ngx.print(T"Please update your browser to use this page." , '\
</canvas>\
\
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
    ngx.print(html, '\
\
\
</div>\
<div id="key" style="width: 700px;"></div>\
<div id ="analyzerloader1" style="height:100px"><img src = "/img/loading.gif"></img></div>\
</fieldset>\
</div>\
</form>\
\
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
<script language ="javascript">\
function cap2info(x){\
  var type = ""\
  var xhex = parseInt(x,16);\
  if (xhex & parseInt(1,16)) type = type + "802.11b";\
  if (xhex & parseInt(2,16)) type = type + "802.11g";\
  if (xhex & parseInt(4,16)) type = type + "802.11a";\
  if (xhex & parseInt(8,16)) type = type + "802.11n";\
  if (xhex & parseInt(8000,16)) type = type + "802.11ac";\
  \
  var ant = ""\
  if (xhex & parseInt(10,16)) ant = " 1x1";\
  if (xhex & parseInt(20,16)) ant = " 2x2";\
  if (xhex & parseInt(40,16)) ant = " 3x3";\
  if (xhex & parseInt(80,16)) ant = " 4x4";\
  var Features = ""\
  if (xhex & parseInt(100,16)) Features = Features +" WMM";\
  if (xhex & parseInt(2000,16)) Features = Features +" STBC";\
  if (xhex & parseInt(4000,16)) Features = Features +" LDPC";\
  if (xhex & parseInt(40000,16)) Features = Features +" BF";\
  var Bond = ""\
  if (xhex & parseInt(200,16)) Bond = Bond + " 40MHz";\
  if (xhex & parseInt(10000,16)) Bond = Bond + " 80MHz";\
  var SGI = ""\
  if (xhex & parseInt(400,16)) SGI = SGI + " SGI20";\
  if (xhex & parseInt(800,16)) SGI = SGI + " SGI40";\
  if (xhex & parseInt(20000,16)) SGI = SGI + " SGI80";\
  return type + ant + Bond + SGI + Features;\
');
--[[
0x40000    0 = BF - Station supports transmit beamforming (explicit NDP)
0x20000    1 = SGI80	SGI supported on 80MHz channels
0x10000    1 = 80MHz	- VHT channel bonding supported
0x8000     1 = 802.11ac - Association request contains HT IE’s
0x4000     1 = LDPC - LDPC supported
0x2000     0 = STBC - STBC supported
0x1000     0 = AMPDU	- AMPDU Supported
0x800      1 = SGI40	- SGI supported on 40MHz channels 
0x400      1 = SGI20	- SGI supported on 20MHz channels
0x200      1 = 40MHz	- Channel bonding supported
0x100      1 = WMM - WMM supported
0x80       0 = 4x4	- Association request contains HT IE’s and the highest supported MCS is 31 or VHT NSS > 3
0x40       1 = 3x3 -	Association request contains HT IE’s and the highest supported MCS is 23 or VHT NSS > 2
0x20       0 = 2x2 - Association request contains HT IE’s and the highest supported MCS is 15 or VHT NSS > 1
0x10       0 = 1x1 - Association request contains HT IE’s and the highest supported MCS is 7 or VHT MCS 9.
0x8        0 = 802.11n - Association request contains HT IE’s
0x4        0 = 802.11a - Station supports OFDM rates in the 5GHz band
0x2        0 = 802.11g - Station supports Legacy OFDM rates (+ also implies 802.11b)
0x1        0 = 802.11b - Station only support 802.11b rates
]]
ngx.print('\
}\
function get_random_color() {\
  var letters = \'0123456789ABCDEF\'.split(\'\');\
  var color = \'#\';\
  for (var i = 0; i < 6; i++ ) {\
    color += letters[Math.round(Math.random() * 15)];\
  }\
   return color;\
}\
  function get_y_from_sig(max, min, range, sig) {\
    return ((sig-max)/((min-max)/range))+30;\
  }\
  function get_curve_y_from_sig(max, min, range, sig) {\
      var line = 350 - get_y_from_sig(max, min, range, sig);\
      var line = 350 - (line *2);\
    return line;\
  }\
  var maximum= -20;\
  var minimum= -105;\
  var range = 320;\
  var bittarget40 = 10;\
  var bittarget80 = 16;\
  var ctx\
  function initializeAnalyzer() {\
    var c=document.getElementById("wrapper");\
    ctx=c.getContext("2d");\
    ctx.lineStyle="#FF0000";\
    ctx.strokeStyle = "#000000";\
\
    //Y Axis\
    ctx.moveTo(30,30);\
    ctx.lineTo(30,350);\
    ctx.stroke();\
\
    //Power Marks\
    //30\
    var line10 = get_y_from_sig(maximum, minimum, range, -10);\
\
    ctx.moveTo(30,line10);\
    ctx.lineTo(25,line10);\
    ctx.stroke();\
    ctx.font="9px Arial";\
    ctx.fillText("-10",7,line10 + 3);\
\
    var line30 = get_y_from_sig(maximum, minimum, range, -30);\
\
    ctx.moveTo(30,line30);\
    ctx.lineTo(25,line30);\
    ctx.stroke();\
    ctx.font="9px Arial";\
    ctx.fillText("-30",7,line30 + 3);\
\
    //60\
    var line60 = get_y_from_sig(maximum, minimum, range, -60);\
\
    ctx.moveTo(30,line60);\
    ctx.lineTo(25,line60);\
    ctx.stroke();\
    ctx.font="9px Arial";\
    ctx.fillText("-60",7,line60 + 3);\
\
     //90\
    var line90 = get_y_from_sig(maximum, minimum, range, -90);\
\
    ctx.moveTo(30,line90);\
    ctx.lineTo(25,line90);\
    ctx.stroke();\
    ctx.font="9px Arial";\
    ctx.fillText("-90",7,line90 + 3);\
\
    //X Axis\
    ctx.moveTo(30,350);');
    --if radio == "radio_2G" then
	     ngx.print('ctx.lineTo(690,350);');
    --else
    --	ngx.print('ctx.lineTo(870,350);');
    --end
    ngx.print('\
    ctx.stroke();\
    //Titles\
    ctx.font="9px Arial";\
    ctx.fillText("Channel",310,390);\
    ctx.save();\
    ctx.translate(0, 0);\
    //ctx.rotate(Math.PI/2);\
    ctx.textAlign = "center";\
    ctx.fillText("Signal Strength (-dBm)", 60, 25);\
    ctx.restore();');
    if radio == "radio_2G" then
    ngx.print('\
    //Channel Marks\
    ctx.moveTo(120,350);\
    ctx.lineTo(120,355);\
    ctx.stroke();\
    ctx.font="9px Arial";\
    ctx.fillText("1",117,370);\
    ctx.moveTo(320,350);\
    ctx.lineTo(320,355);\
    ctx.stroke();\
    ctx.font="9px Arial";\
    ctx.fillText("6",317,370);\
    ctx.moveTo(520,350);\
    ctx.lineTo(520,355);\
    ctx.stroke();\
    ctx.font="9px Arial";\
    ctx.fillText("11",517,370);\
    ');
    else
    ngx.print('\
    //Channel Marks\
    var chn_diff = 30;\
    var chnl = 0;\
    for (i = 0; i <= 7; i++) {\
         ctx.moveTo(60+(chn_diff*i),350);\
         ctx.lineTo(60+(chn_diff*i),355);\
         ctx.stroke();\
         ctx.font="9px Arial";\
         chnl = 36+(i*4);\
         ctx.fillText(chnl.toString(),60+(chn_diff*i)-4,370);\
    }\
\
    for (i = 10; i <= 20; i++) {\
    //20 = EU upto 140 27 = full\
         ctx.moveTo(60+(chn_diff*i),350);\
         ctx.lineTo(60+(chn_diff*i),355);\
         ctx.stroke();\
         ctx.font="9px Arial";\
         chnl = 60+(i*4);\
         ctx.fillText(chnl.toString(),60+(chn_diff*i)-6,370);\
    }\
\
    ');
    end
    ngx.print('\
    var color = parseInt("00000F", 16);\
    // analyzer table header\
    $("#key").empty().append(\
      $("<br/>"),\
      $("<div>").addClass("col_ssid").text("', T'Network Name (SSID)', '"),\
      $("<div>").addClass("col_channel").text("', T'Channel', '"),\
      $("<div>").addClass("col_str").text("', T'40MHz', '"),');  
      if radio ~= "radio_2G" then   
      	ngx.print('$("<div>").addClass("col_str").text("', T'80MHz', '"),');  
      end   
      ngx.print('$("<div>").addClass("col_rssi").text("', T'Signal Strength (RSSI)', '"),\
      $("<br/>")\
    );\
  }\
  function generateGraph(ssid,channel,channeldisplay,rssi,cap,extra){\
      color =  get_random_color();\
      var Mhz = 1;\
      var Str = "";\
      ');
      if radio == "radio_2G" then
	      ngx.print('\
	      //2.4GHz\
	      if ((extra == "u") || (extra == "l")) {\
	           Mhz = 2;\
	           Str = \'*\';\
	        }\
        var xcoord = 80+(channel*40);\
	      var sig = rssi;\
	      if (sig > maximum){sig = maximum }else if (sig < minimum){sig = minimum}\
	      ctx.beginPath();\
	\
	      color =  get_random_color();\
	      var curvey = get_y_from_sig(maximum, minimum, range, sig);\
	      ctx.strokeStyle = color;\
	\
	      ctx.moveTo(xcoord-(80*Mhz), 350);\
	      ctx.quadraticCurveTo(xcoord-(80*Mhz)+20, curvey, xcoord-(80*Mhz)+40, curvey);\
	      ctx.lineTo(xcoord+(80*(Mhz))-40,curvey);\
	      ctx.moveTo(xcoord+(80*(Mhz)), 350);\
	      ctx.quadraticCurveTo(xcoord+(80*(Mhz))-20, curvey, xcoord+(80*(Mhz))-40, curvey);\
	\
	      ctx.stroke();\
	       ');
       else
       ngx.print('\
	       //5GH\
	      var chlist40 = [38,46,54,62,102,110,118,126,134,142]\
	      var chlist80 = [42,58,106,122,138]\
	      var str40 = ""\
	      var str80 = ""\
	      var channel_text = channel\
	      for (i = 0; i <= chlist40.length; i++) {\
	          if (chlist40[i] == channel){\
	            str40 = "*";\
	            Mhz = 2;\
	          }\
	      }\
	      for (i = 0; i <= chlist80.length; i++) {\
	          if (chlist80[i] == channel){\
	            str80 = "*";\
	            Mhz = 4;\
	          }\
	      }\
	      var xcoord = 0\
	      if  (channel <= 64) {\
	         xcoord = 60+((channel-36)*7.5);\
	      }else{\
	         xcoord = 360+((channel-100)*7.5);\
	      }\
	\
	      var sig = rssi;\
	\
	      if (sig > maximum){sig = maximum }else if (sig < minimum){sig = minimum}\
	          ctx.beginPath();\
	          color =  get_random_color();\
	          ctx.strokeStyle = color;\
	          var curvey = get_y_from_sig(maximum, minimum, range, sig);\
	          ctx.moveTo(xcoord-(15*Mhz), 350);\
	          ctx.quadraticCurveTo(xcoord-(15*Mhz)+5, curvey, xcoord-(15*Mhz)+10, curvey);\
	          ctx.lineTo(xcoord+(15*Mhz)-10,curvey);\
	          ctx.moveTo(xcoord+(15*Mhz), 350);\
	          ctx.quadraticCurveTo(xcoord+(15*Mhz)-5, curvey, xcoord+(15*Mhz)-10, curvey);\
	          ctx.stroke();\
	          channel = channel_text;\
	       	');
       end
       ngx.print('\
\
     // A new row for analyzer table\
     var row = $("<div>").css("color", color);\
     // Append the row\
     $("#key").append(row);\
\
     // Add columns to the new row\
    var divinfo = " data-toggle=\'tooltip\' title=\'"+cap2info(cap)+"\' data-placement=\'right\'";\
    $(row).append(\
      $("<div"+divinfo+">").addClass("col_ssid").text(ssid),\
      $("<div"+divinfo+">").addClass("col_channel").text(channeldisplay),');  
      if radio == "radio_2G" then   
      	ngx.print('$("<div"+divinfo+">").addClass("col_str").text(Str),');  
      else  
      	ngx.print('$("<div"+divinfo+">").addClass("col_str").text(str40),\
	      $("<div"+divinfo+">").addClass("col_str").text(str80),');  
      end  
      ngx.print('$("<div"+divinfo+">").addClass("col_rssi").text(rssi),\
      $("<br/>")\
    );\
  }\
\
  function show_rescanconfirming(freq,show){\
    var msg_id = "confirming-msg_" + freq;\
    var rescan_id = "rescan-changes_" + freq;\
    if (show == 1){\
      $("div[id^= "+ rescan_id +"]").show();\
      $("div[id^= "+ msg_id +"]").show();\
    }\
    else {\
      $("div[id^= "+ rescan_id +"]").hide();\
      $("div[id^= "+ msg_id +"]").hide();\
    }\
  }\
\
  $("div[id^=\'ReScan_\']").click(function() {\
    var freq = (this.id).split("_")[1];\
    show_rescanconfirming(freq,1);\
  });\
\
  $("div[id^=\'rescan-confirm_\']").click(function() {\
    var freq = (this.id).split("_")[1];\
    show_rescanconfirming(freq,0);\
  });\
\
  $("div[id^=\'rescan-cancel_\']").click(function() {\
    var freq = (this.id).split("_")[1];\
    show_rescanconfirming(freq,0);\
  });\
\
    $(document).ready(function(){\
      $("div[id^=\'rescan-confirm_\']").on("click",function(a) {\
        var freq = (this.id).split("_")[1];\
        show_rescanconfirming(freq,0);\
\
        var params = [];\
        params.push({\
          name : "action",\
          value : "rescan"\
        });\
        params.push({\
          name : "curradio",\
          value : "', radio, '"\
        });\
        params.push(tch.elementCSRFtoken());\
        tch.showProgress("', T"Re-scanning", '...");\
        $.post("/modals/wireless-modal.lp", params, function(acsData){\
          \
        })\
        .always(function() {\
          tch.refreshModal();\
        });\
      });\
      initializeAnalyzer();\
      $.get("/modals/wireless-modal.lp?isWifiAnalyzer=', getWifiAnalyzer, '&getAcsData=true&radio=', radio, '",function(acsData){\
         $("#analyzerloader").addClass("hide");\
         $("#analyzerGraph").removeClass("hide");\
         $("#analyzerloader1").addClass("hide");\
         $.each(acsData, function(i, data) {\
           generateGraph(data.ssid,data.channelCentre,data.channel,data.rssi,data.cap,data.channelExtra);\
         });\
         $(\'[data-toggle="tooltip"]\').tooltip()\
       });\
    });\
  var isextenderSupported = false;\
</script>\
\
');
--End of wifi analyzer
end
  ngx.print('</div>\
</form>\
</div>', 
ui_helper.createFooter(), '\
<script>\
  var curiface = "');  ngx.print(curiface); ngx.print('";\
  var curradio = "');  ngx.print(curradio); ngx.print('";\
  var currentRole = "');  ngx.print(role); ngx.print('";\
  var smartwifivalue = "');  ngx.print(smartWifi); ngx.print('";\
  var smartwifiphasevalue = "');  ngx.print(smartWifiPhase); ngx.print('";\
  var smartWifiMsg = \'');  ngx.print(T"Your Smart Wi-Fi service is active and managing your existing Wi-Fi and Parental Control settings. You can override your Wi-Fi and Parental settings in the Smart Wi-Fi App."); ngx.print('\';\
  var smartwifi = true;\
  var isTableLoaded = ');  ngx.print(isTableLoaded); ngx.print(';\
  var acl_mode = "');  ngx.print(content["acl_mode"]); ngx.print('";\
  var curap = "');  ngx.print(curap); ngx.print('";\
  var helpmsg = ');  ngx.print(json.encode(helpmsg)); ngx.print(';\
\
</script>\
<script src="/js/wireless-modal.js"></script>\
'); 
