--pretranslated: do not change this file
 
local untaint_mt = require("web.taint").untaint_mt
local setmetatable = setmetatable
local untaint = string.untaint
local session = ngx.ctx.session

-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local crypto = require("lcrypto")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local ajax_helper = require("web.ajax_helper")
local pairs = pairs
local match, format, next, lower, upper = string.match, string.format, next, string.lower, string.upper
local bandsteer_helper = require("bandsteer_helper")
local isBaseIface = bandsteer_helper.isBaseIface
local disableBandSteer = bandsteer_helper.disableBandSteer
local json = require("dkjson")
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "Wireless", "wireless")
local timhelper = post_helper.getVariantValue(variantHelper, "helperFunction") and require("tim_helper") or ""
local role = session:getrole()

local getargs = ngx.req.get_uri_args()
local gettype = untaint(getargs.type)

-- Shortcuts to validation helpers to make lines shorter
local getValidationIfPropInList = post_helper.getValidationIfPropInList
local getValidateInEnumSelect = post_helper.getValidateInEnumSelect
local validateBoolean = post_helper.validateBoolean
local validateNonEmptyString = post_helper.validateNonEmptyString
local validateStringIsPort = post_helper.validateStringIsPort
local getOptionalValidation = post_helper.getOptionalValidation
local getConditionalValidation = post_helper.getConditionalValidation
local getAndValidation = post_helper.getAndValidation
local validatePSK = post_helper.validatePSK
local getValidateStringLengthInRange = post_helper.getValidateStringLengthInRange
local isTableLoaded = false
local cursor = require("uci").cursor("/etc/telia_app_config", nil)
local config = "airties_edge"
local smartWifiStatus = proxy.get("rpc.wireless.SmartWiFi.Active")
smartWifiStatus = smartWifiStatus and smartWifiStatus[1] and smartWifiStatus[1].value or ""
local validateWEP = post_helper.validateWEP
local validateWPSPIN = post_helper.validateWPSPIN
if post_helper.getVariantValue(variantHelper, "helperFunction") then
  validateWEP = timhelper.validateWEP
  validateWPSPIN = timhelper.validateWPSPIN
end
local validateStringIsIPv6 = post_helper.validateStringIsIP(6)
local validateStringIsIP = post_helper.validateStringIsIP()
local getOrValidation = post_helper.getOrValidation
local getValidateStringISIP = getOrValidation(validateStringIsIP, validateStringIsIPv6)
local wpa_list = {"wpa2", "wpa-wpa2"}
local validateQTN = post_helper.validateQTN
local validateLXC = post_helper.validateLXC
local html_escape = require("web.web").html_escape

local isguest = "0"
local isExtRemman = {"0"} -- AP remotely managed, like a TG233 DANT-5 board in AP mode.
local isIntRemman = {"0"} -- Quantenna
local stbLimit = false
local curap = "ap0"
local curradio = "radio_2G"
local curiface = "wl0"
local agentView = true

--To check whether multiAP is enabled or not
local multiap_enabled = false
local multiap_agent = false
if post_helper.getVariantValue(variantHelper, "multiAP") then
  local multiap_state = {
    agent = "uci.multiap.agent.enabled",
    controller = "uci.multiap.controller.enabled"
  }
  content_helper.getExactContent(multiap_state)
  multiap_enabled = multiap_state.agent == "1" and multiap_state.controller == "1"
  if multiap_state.agent == "1" and multiap_state.controller == "0" then
    multiap_agent = true
  end
  if multiap_agent and post_helper.getVariantValue(variantHelper, "agentView") then
    agentView = false
  end
end

local networktype = "uci.web.network."
networktype = content_helper.convertResultToObject(networktype .. "@.", proxy.get(networktype))
local wls = {}
local ap_details = proxy.get("rpc.wireless.ap.")
ap_details = content_helper.convertResultToObject("rpc.wireless.ap.", ap_details)
local device_details = proxy.get("rpc.wireless.radio.")
device_details = content_helper.convertResultToObject("rpc.wireless.radio.", device_details)
local ssid_details = proxy.get("rpc.wireless.ssid.")
ssid_details = content_helper.convertResultToObject("rpc.wireless.ssid.", ssid_details)

-- function used to return the splitssid and interface details from web config
local function loadAvailableInterface()
  wls = {}
  for _, intfVal in ipairs(networktype) do
    if untaint(intfVal.paramindex) ~= "backhaul" then
      wls[#wls+1] = {
        type = intfVal.paramindex,
      }
    end
  end
  return wls
end

local availableCredentials, availableCredentials, availableCredentialsInstance = {}, {}, {}
local function loadInterfaceCredList(gettype)
  local interfacesPath = "uci.web.network.@"..gettype..".intf."
  if proxy.getPN("uci.web.network.@"..gettype..".intf.", true) then
    availableInterfaces = content_helper.convertResultToObject(interfacesPath .. "@.", proxy.get(interfacesPath))
  end
  local credentials = "uci.web.network.@"..gettype..".cred."
  if proxy.getPN("uci.web.network.@"..gettype..".cred.", true) then
    availableCredentials = content_helper.convertResultToObject(credentials .. "@.", proxy.get(credentials))
  end
  local credentialsInstance = "uci.web.network.@"..gettype..".credInstance."
  if proxy.getPN("uci.web.network.@"..gettype..".credInstance.", true) then
    availableCredentialsInstance = content_helper.convertResultToObject(credentialsInstance .. "@.", proxy.get(credentialsInstance))
  end
  return availableInterfaces, availableCredentials, availableCredentialsInstance
end
gettype = gettype and gettype or (session:retrieve("networktype") or "main")
availableInterfaces, availableCredentials, availableCredentialsInstance = loadInterfaceCredList(gettype)

local guestMultiap = false
if post_helper.getVariantValue(variantHelper, "guestMultiap") and gettype == "guest" and multiap_enabled then
  guestMultiap = true
end

-- function used to generate the available interfaces for the selected network type
-- based on the multiap, split_ssid values
local interface_list, credential_list, credential_instance_list  = {}, {}, {}
local split_ssid, bandsteer_enabled, bsid, bandsteer_state, curiface, bandsteeriface, bandsteerobj
local function generateInterfaceList(gettype)
  availableInterfaces, availableCredentials, availableCredentialsInstance = loadInterfaceCredList(gettype)
  wls = loadAvailableInterface()
  credential_list = {}
  credential_instance_list = {}
  for _, v in ipairs(wls) do
    if gettype == v.type and v.type ~= "backhaul" then
      for _, intf in ipairs(availableInterfaces) do
        for _, iface in ipairs(ssid_details) do
          iface.paramindex = match(iface.paramindex, "@([^%.]+)") or iface.paramindex
          if intf.value == iface.paramindex then
            interface_list[#interface_list + 1] = intf.value
            break
          end
        end
      end
      for _, cred in ipairs(availableCredentials) do
        credential_list[#credential_list + 1] = cred.value
      end
      for _, cred in ipairs(availableCredentialsInstance) do
        credential_instance_list[#credential_instance_list + 1] = cred.value
      end
      if not multiap_enabled then
        if smartWifiStatus ~= "1" then
          curiface = interface_list[1] and interface_list[1] or ""
          bsid = bandsteer_helper.getBandSteerId(curiface)
          bandsteer_state = proxy.get("uci.wireless.wifi-bandsteer.@"..bsid..".state") and proxy.get("uci.wireless.wifi-bandsteer.@"..bsid..".state")[1].value or ""
          bandsteeriface = bandsteer_helper.getBandSteerPeerIface(curiface)
          bandsteerobj = proxy.get("uci.wireless.wifi-bandsteer.@" .. bsid .. ".") or ""
        end
      end
    end
  end
  if post_helper.getVariantValue(variantHelper, "showsplitToggle") then
    if multiap_enabled then
      split_ssid = proxy.get(format("uci.multiap.controller_credentials.@%s.state", credential_list[2]))[1].value or "1"
    elseif smartWifiStatus == "1" and gettype ~= "guest" then
      split_ssid = proxy.get(format("rpc.X_AIRTIES_OBJ.MultiAPController.SSIDProfile.%s.Enable", credential_instance_list[2]))[1].value or "1"
    else
      split_ssid = proxy.get("uci.web.network.@"..gettype..".splitssid")
      split_ssid = split_ssid and split_ssid[1].value or "1"
    end
  else
    split_ssid = "0"
  end
  return interface_list, split_ssid, bsid, bandsteer_state
end

interface_list, split_ssid, bsid, bandsteer_state = generateInterfaceList(gettype)

local preserveBandsteerState, preserveBandsteerId
if split_ssid == "0" and not multiap_enabled and post_helper.getVariantValue(variantHelper, "preserveBandsteer") then
  if gettype == "main" or post_helper.getVariantValue(variantHelper, "guestBandsteer") then
    preserveBandsteerState = bandsteer_state
    preserveBandsteerId = bsid
  end
end

local radios = {}
for _, v in ipairs(proxy.getPN("rpc.wireless.radio.", true)) do
  local radio = match(v.path, "rpc%.wireless%.radio%.@([^%.]+)%.")
  radios[#radios + 1] = radio and radio
end
table.sort(radios)

-- genreateAPList function used to generate the available AP's based on the interface_list
local ap_list, intf_check, radio_list, aplists = {}, {}, {}, {}
local function generateAPList(interface_list)
  ap_list, aplists = {}, {}
  for _, intf in ipairs(interface_list) do
    for _, ap in ipairs(ap_details) do
      if intf == ap.ssid then
        curap = match(ap.paramindex, "@([^%.]+)") or ap.paramindex
        local intf = ap.ssid
        ap_list[#ap_list + 1] = curap
        aplists[#aplists + 1] = curap
        intf_check[intf] = curap
        radio_list[curap] = proxy.get("rpc.wireless.ssid.@"..intf..".radio") and proxy.get("rpc.wireless.ssid.@"..intf..".radio")[1].value or ""
        break
      end
    end
  end
  --Telia smartwifi has only one guest ap/cred when smartwifi is enabled
  if smartWifiStatus == "1" and gettype == "guest" then
    ap_list = {}
    ap_list[#ap_list + 1] = "ap4"
  end
  return aplists, ap_list, intf_check, radio_list
end

aplists, ap_list, intf_check, radio_list = generateAPList(interface_list)
local adjacent_ap = curap

local securityVal = {}
for _, ap in ipairs(ap_list) do
  securityVal["security"..ap] = proxy.get("rpc.wireless.ap.@"..ap..".security.mode") and proxy.get("rpc.wireless.ap.@"..ap..".security.mode")[1].value or ""
end

--To get the frequency bands based on the ap details and based on the split ssid ap_list values gets updated.
local radiofreq, sec_modes, mergeAP = {}, {}, {}
local radioVal, curaplist
local function mergedAPDetails(split_ssid, bandsteer_state, ap_list)
  radiofreq = {}
  for _, v in ipairs(ap_details) do
    for _, curap in ipairs(ap_list) do
      v.paramindex = match(v.paramindex, "@([^%.]+)") or v.paramindex
      if curap  == v.paramindex then
        radioVal = proxy.get(format("rpc.wireless.ssid.@%s.radio", v.ssid))
        radioVal = radioVal and radioVal[1].value or ""
        radiofreq[untaint(v.paramindex)] = proxy.get(format("rpc.wireless.radio.@%s.supported_frequency_bands", radioVal))
        if radiofreq[untaint(v.paramindex)] then
          radiofreq[untaint(v.paramindex)] = radiofreq[untaint(v.paramindex)][1].value == "2.4GHz" and "2.4 GHz" or "5 GHz"
          if radioVal == "radio_5G" and #radios == 3 then
            radiofreq[untaint(v.paramindex)] = "5 GHz Low"
          end
          if radioVal == "radio2" then
            radiofreq[untaint(v.paramindex)] = radioVal == "radio2" and "5 GHz High"
          end
          if #radios == 3 and multiap_enabled then
            radiofreq[untaint(v.paramindex)] = "5 GHz"
          end
        end
      end
    end
  end
  curaplist = ap_list[1] and ap_list[1] or ""
  if split_ssid == "0" then
    for indexVal, apVal in ipairs(ap_list) do
      if indexVal ~= 1 then
        mergeAP[#mergeAP + 1] = apVal
      end
    end
    curaplist = ap_list[1] and ap_list[1] or ""
    ap_list = {}
    radiofreq = {}
    ap_list[#ap_list + 1] = curaplist
    radiofreq[curaplist] = mergeAP and "2.4 GHz and 5 GHz" or "2.4 GHz"
    curiface = interface_list[1] and interface_list[1] or ""
    interface_list = {}
    interface_list[#interface_list + 1] = curiface
  else
    radiofreq[curaplist] = "2.4 GHz"
  end
  return mergeAP, curaplist, ap_list, interface_list
end

mergeAP, curaplist, ap_list, interface_list = mergedAPDetails(split_ssid, bandsteer_state, ap_list)

local radioData = {}
for _, v in ipairs(radios) do
  local path = "rpc.wireless.radio.@" .. v
  local rdata = proxy.get(path .. ".remotely_managed",
  path .. ".integrated_ap")
  if rdata then
    radioData[v] = {
      remotely_managed = rdata[1].value,
      integrated_ap = rdata[2].value,
    }
  end
end

for _, ap in ipairs(ap_list) do
  curradio = radio_list[ap]
  if radioData[curradio] and radioData[curradio].remotely_managed == "1"  then
    if radioData[curradio].integrated_ap ~= "1" then
      isExtRemman[curap] = "1"
    elseif radioData[curradio].integrated_ap == "1" and post_helper.getVariantValue(variantHelper, "quantenna") then
      isIntRemman[curap] = "1"
    end
  end
end

local isTableLoaded = {"false"}

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "set_reg" then
  for _, curap in ipairs(aplists) do
    local content_acl ={
      state = "rpc.wireless.ap.@"..curap..".acl.state"
    }
    content_helper.getExactContent(content_acl)
    local acl_ap = ngx.req.get_post_args().curap
    local content_acl_state = format('%s', content_acl["state"])
    if content_acl_state ~= "register" then
      local acl_ap_url1 = format ('rpc.wireless.ap.@%s.acl.mode', acl_ap)
      proxy.set(acl_ap_url1, "register" )
      if split_ssid == "0" and mergeAP then
        for _, mergeAPVal in ipairs(mergeAP) do
          acl_ap_url1 = format ('rpc.wireless.ap.@%s.acl.mode', mergeAPVal)
          proxy.set(acl_ap_url1, "register" )
        end
      end
      proxy.apply()
      ngx.sleep(10)
    end
    local acl_ap_url = format ('rpc.wireless.ap.@%s.acl.reg', acl_ap)
    proxy.set(acl_ap_url, "1" )
    if split_ssid == "0" and mergeAP then
      acl_ap_url = format ('rpc.wireless.ap.@%s.acl.reg', mergeAP)
      proxy.set(acl_ap_url, "1" )
    end
    ngx.print('{ "success":"true" }')
    proxy.apply()
  end
  ngx.exit(ngx.HTTP_OK)
end

if ngx.req.get_method() == "GET" and ngx.req.get_uri_args().action == "get_reg_status"  then
  local acl_ap = ngx.req.get_uri_args().curap
  gettype = session:retrieve("networktype") or "main"
  local reg_status = proxy.get("rpc.wireless.ap.@"..acl_ap..".acl.state")
  reg_status = reg_status and reg_status[1].value and (reg_status[1].value:gsub("^%l", upper)) or ""
  ngx.print(reg_status)
  ngx.exit(ngx.HTTP_OK)
end

-- The function can be reused to load the ACL mac list by ajax and normal request
-- Normal request means - Adding, Editing and Deleting the ACL mac address entries by normal POST request
local function loadAclList(aclmode, action, curap)
if post_helper.getVariantValue(variantHelper, "steering") and split_ssid == "0" then
  if not (ngx.req.get_uri_args() and ngx.req.get_uri_args().splitssid == "1") then
    curap = untaint(aplists[2])
  end
end
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
    tableid = "acl_whitelist"..curap,
    basepath = format("uci.wireless.wifi-ap.@%s.acl_accept_list.@.",curap),
    createMsg = T"Add new MAC address"
  }
  if aclmode == "register" then
    acl_whitelist_options["tableid"] = "acl_register"..curap
  end
  local acl_whitelist_data, acl_whitelist_helpmsg = post_helper.handleTableQuery(acl_columns, acl_whitelist_options, nil, nil, macvalid)

  if split_ssid == "0" then
    for _, mergeAPVal in ipairs(mergeAP) do
      if post_helper.getVariantValue(variantHelper, "steering") then
        mergeAPVal = (mergeAPVal == "ap1" and "ap0") or (mergeAPVal == "ap4" and "ap3")
      end
      local path = format("uci.wireless.wifi-ap.@%s.acl_accept_list.", mergeAPVal)
      for i, v in ipairs(proxy.getPN(path, true)) do
        proxy.del(v.path)
      end
      for i, v in ipairs(acl_whitelist_data) do
        local indexVal, err = proxy.get("uci.wireless.wifi-ap.@"..mergeAPVal..".acl_accept_list.") and proxy.add("uci.wireless.wifi-ap.@"..mergeAPVal..".acl_accept_list.")
        local success = proxy.set("uci.wireless.wifi-ap.@"..mergeAPVal..".acl_accept_list.@"..i..".value", v[1])
        local paramValue = indexVal and proxy.get("uci.wireless.wifi-ap.@"..mergeAPVal..".acl_accept_list.@"..indexVal..".value") or false
        paramValue = paramValue and (paramValue == "" or paramValue[1].value == "") and true
        if paramValue then
          local _, error = proxy.del("uci.wireless.wifi-ap.@"..mergeAPVal..".acl_accept_list.@"..indexVal..".")
        end
        if not err and (success or not error) then
          proxy.apply()
        end
      end
    end
  end

  local acl_blacklist_options = {
    tableid = "acl_blacklist"..curap,
    basepath = format("uci.wireless.wifi-ap.@%s.acl_deny_list.@.",curap),
    createMsg = T"Add new MAC address"
  }
  acl_blacklist_filter = function(data)
    local curap_path = "uci.wireless.wifi-ap.@" .. curap
    local aclmode_value = proxy.get(curap_path .. ".acl_mode")
    local aclmac_value = proxy.get(curap_path.. ".acl_deny_list.")
    for aclMacData, aclMacDataValue in ipairs(aclmac_value) do
      for aclMode, aclModeValue in ipairs(aclmode_value) do
        if aclModeValue.value == "disabled" then
          proxy.del(format(curap_path..".acl_deny_list.", acl_deny_list_value))
          proxy.apply()
        end
      end
    end
    return true
  end
  local acl_blacklist_data, acl_blacklist_helpmsg = post_helper.handleTableQuery(acl_columns, acl_blacklist_options, acl_blacklist_filter, nil, macvalid)
  if split_ssid == "0" then
    for _, mergeAPVal in ipairs(mergeAP) do
      if post_helper.getVariantValue(variantHelper, "steering") then
        mergeAPVal = (mergeAPVal == "ap1" and "ap0") or (mergeAPVal == "ap4" and "ap3")
      end
      local path = format("uci.wireless.wifi-ap.@%s.acl_deny_list.", mergeAPVal)
      for i, v in ipairs(proxy.getPN(path, true)) do
        proxy.del(v.path)
      end
      for i, v in ipairs(acl_blacklist_data) do
        local indexVal = proxy.get("uci.wireless.wifi-ap.@"..mergeAPVal..".acl_deny_list.") and proxy.add("uci.wireless.wifi-ap.@"..mergeAPVal..".acl_deny_list.")
        local success = proxy.set("uci.wireless.wifi-ap.@"..mergeAPVal..".acl_deny_list.@"..i..".value", v[1])
        local paramValue = indexVal and proxy.get("uci.wireless.wifi-ap.@"..mergeAPVal..".acl_deny_list.@"..indexVal..".value") or false
        paramValue = paramValue and (paramValue == "" or paramValue[1].value == "") and true
        if paramValue then
          local _, error = proxy.del("uci.wireless.wifi-ap.@"..mergeAPVal..".acl_deny_list.@"..indexVal..".")
        end
        if not err and (success or not error) then
          proxy.apply()
        end
      end
    end
  end

  local whitelistclass = {
    group = {
      class = "monitor-acl_mode"..curap.." monitor-lock monitor-register"
    }
  }
  if aclmode == "unlock" or aclmode == "disabled" then
    whitelistclass["group"].style = "display:none;"
  end
  if #acl_whitelist_data < 1 and action ~= "POST" then
    whitelistclass ["span"] = {id = "Address_list_Whitelistclass"..curap}
    html[#html+1] = ui_helper.createLabel("", T"MAC Address list is empty", whitelistclass, nil)
    acl_columns[1].header=""
  end
  html[#html+1] = ui_helper.createTable(acl_columns, acl_whitelist_data, acl_whitelist_options, whitelistclass, acl_whitelist_helpmsg)
  local blacklistclass = {
    group = {
      class = "monitor-acl_mode"..curap.." monitor-unlock"
    }
  }
  if #acl_blacklist_data < 1 and action ~= "POST" and aclmode ~= "disabled" and aclmode ~= "lock" and aclmode ~= "register" then
    blacklistclass ["span"] = {id = "Address_list_Blacklistclass"..curap}
    html[#html+1] =  ui_helper.createLabel("", T"MAC Address list is empty", blacklistclass, nil)
    acl_columns[1].header=""
  else
    acl_columns[1].header =  T"MAC Address"
  end
  if aclmode == "lock" or aclmode == "register" or aclmode == "disabled" then
    blacklistclass["group"].style = "display:none;"
  else
    html[#html+1] = ui_helper.createTable(acl_columns, acl_blacklist_data, acl_blacklist_options, blacklistclass, acl_blacklist_helpmsg)
  end
  return html
end

-- Load the ACL Mac Address list by ajax get request
if getargs.action=="GET_ACL_MAC_LIST" then
  local acl_mode
  local ap = untaint(getargs["curap"])
  acl_mode = untaint(getargs["acl_mode"..ap])
  if acl_mode then
    ngx.print(loadAclList(acl_mode, "GET", ap))
  end
  ngx.exit(ngx.HTTP_OK)
end

-- Show RSSI Threshold level in slider
local min_rssi = -90
local max_rssi = -10
local step = 10
local unit = "dBm"

-- Listbox that shows the supported Access Control modes
local acl_modes = {}
local acl_supportedmodes = {}
for _, ap in ipairs(aplists) do
  acl_modes = {}
  acl_modes[#acl_modes + 1] = { "disabled", T"Disabled" }
  acl_modes[#acl_modes + 1] = { "unlock", T"Blacklist" }
  acl_modes[#acl_modes + 1] = { "lock", T"Whitelist" }
  curradio = radio_list[ap]
  curradio = untaint(curradio)
  if radioData[curradio] and radioData[curradio].remotely_managed ~= "1" then
    acl_modes[#acl_modes+1] = {"register", T"Register"}
  end
  acl_supportedmodes[ap] = acl_modes
end

--To get the security modes and display in the security mode dropdown when easymesh is enabled
local securityModes = {}
if multiap_enabled then
  local supported_modes_multiap = proxy.get("uci.multiap.controller.supported_security_modes") or ""
  if gettype ~= "guest" then
    supported_modes_multiap = supported_modes_multiap and supported_modes_multiap[1].value or ""
    supported_modes_multiap:gsub("[^%s]+", function(mode)
      if mode == "none" then
        securityModes[#securityModes+1] = { mode, ("<strong>"..untaint(mode:gsub("^%l", upper)).."</strong>")}
      else
        securityModes[#securityModes+1] = { mode, ("<strong>"..untaint(upper(mode)).."</strong>")}
      end
    end)
  end
end

--Supported security modes when smartwifi is enabled
if smartWifiStatus == "1" then
  securityModes = {
    { "wpa2-psk", "<strong>WPA2-PSK</strong>" },
    { "wpa3-psk", "<strong>WPA3-PSK</strong>" },
    { "wpa2-wpa3-psk", "<strong>WPA2-WPA3-PSK</strong>" }
  }
end

local secmodes, secmodesap = {}, {}
for _, curap in ipairs(aplists) do
  local supported_modes_data  = proxy.get("rpc.wireless.ap.@" .. curap .. ".security.supported_modes")
  local supported_modes = format("%s", supported_modes_data and supported_modes_data[1] and supported_modes_data[1].value or "")
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
      secmodes[#secmodes+1] = { c, T(upper(c)) }
     end
  end)
  secmodesap[curap] = secmodes
  secmodes = {}
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

local function getReplaceValue(newval)
  return function(value, object, key)
    object[key] = newval
    return true
  end
end

local function getValidateExtraSpaces(value)
  if match(value, "^%s+") or match(value, "%s+$") then
    return nil, T"Leading and trailing whitespaces are not allowed."
  end
  return true
end

local pathiface, pathap, pathapWpa3, pathRadius
local bsPeerAP = nil
local pap = "uci.wireless.wifi-ap."
local aap = content_helper.convertResultToObject(pap .. "@.", proxy.get(pap))
local radius_account, radius_authent = {}, {}
local pathpmf
local pIface = "uci.wireless.wifi-iface."
local availableWirelessInterfaces = content_helper.convertResultToObject(pIface .. "@.", proxy.get(pIface))

for _, pathiface in ipairs(aap) do
  if bandsteerobj and bandsteerobj ~= "" then
    if bandsteeriface and pathiface.iface == bandsteeriface then
      bsPeerAP = pathiface.paramindex
    end
  end
end

for _, iface in ipairs(availableWirelessInterfaces) do
  if iface.backhaul == "1" and iface.paramindex == curiface then
    bsPeerAP = nil
  end
end
local bandsteerpathap = bsPeerAP and format("rpc.wireless.ap.@" .. "%s.", bsPeerAP) or ""
local isguest = gettype == "guest" and "1" or "0"
local suffix = proxy.get("uci.env.var.commonssid_suffix")
suffix = suffix and suffix[1].value or ""
local function getValidateBandSteerPeerFields(value, object, key)
  local bsid = bandsteer_helper.getBandSteerId(curiface)
  local bandsteer_state
  if (isguest ~= "1" or bsid and bsid ~= "" and bsid == "bs1") or post_helper.getVariantValue(variantHelper, "guestBandsteer") then
    bandsteer_state = proxy.get("uci.wireless.wifi-bandsteer.@"..bsid..".state")[1].value or ""
  end
  object["security"]= object["security"..curaplist]
  object["wpa_psk"] = object["wpa_psk"..curaplist]
  object["ssid"] = object["ssid"..curaplist]
  object["ap_enabled"] = object["ap_enabled"..curaplist]
  if post_helper.getVariantValue(variantHelper, "bandsteerSupport") then
    if object.multiap_security then
      object.multiap_security = object.security
      object.multiap_wpa_psk = object.wpa_psk
      object.multiap_ssid = object.ssid
    end
    if not object.band_steer_enabled then
      if not multiap_enabled and suffix ~= "" then
        if smartWifiStatus ~= "1" then
          proxy.set("uci.wireless.wifi-bandsteer.@"..bsid..".state", "0")
          proxy.apply()
        end
      end
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
        if smartWifiStatus ~= "1" then
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
        end
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
              object.band_steer_enabled = "0"
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
      if multiap_enabled and split_ssid == "1" then
        proxy.set("uci.multiap.controller_credentials.@"..untaint(credential_list[2])..".state", "1")
        proxy.apply()
      end
      return disableBandSteer(object, bandsteer_state, multiap_enabled, isguest, bsPeerAP)
    end
    return true
  else
    local state = object.ap_enabled
    local bandsteer_enabled
    if isguest ~= "1" then
      state = object.ap_enabledap0
    end
    local state_5g = object.ap_enabledap1
    if session:retrieve("bs_check_action") then
      session:store("bs_check_action", false)
      bandsteer_enabled = proxy.get("uci.wireless.wifi-bandsteer.@bs0.state")[1].value or ""
    else
      bandsteer_enabled = object.band_steer_enabled
    end
    if bandsteer_enabled == "1" then
      bandsteer_enabled = proxy.get("uci.wireless.wifi-bandsteer.@bs0.state")[1].value or ""
      if post_helper.isFeatureEnabled("bandsteerDisabled", role) and "table" ~= type(state) and ("1" ~= state or "1" ~= state_5g) and (object.band_steer_enabled and object.band_steer_enabled == "1" and bandsteer_enabled == "0") then --network disabled
        return nil, T"Band Steering cannot be enabled when 2.4 Ghz/5 Ghz interface is OFF."
      end
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

-- function to validate SSID text field
local function validateSSID(value, key)
  if (match(value, "^[</>;,[%]()'~+\\^]") or match(value, '"') or match(value, "[</>;,()[%]'~+^\\]$")) then
    return nil, T"Invalid input."
  else
    local success, errmsg = getValidateStringLengthInRange(1,32)(value)
    if not success then
      return success, errmsg
    end
  end
  return true
end

local multiap_cred_secondary_path, bandsteerpath, bandsteers
if bandsteerobj then
  bandsteerpath = "uci.wireless.wifi-bandsteer."
  bandsteers = content_helper.convertResultToObject(bandsteerpath .. "@.", proxy.get(bandsteerpath))
  table.sort(bandsteers, function(a,b)
    return a.paramindex < b.paramindex
  end)
end

for _, intf in ipairs(interface_list) do
  pathiface = format("rpc.wireless.ssid.@%s.", intf)
  -- If this AP connects to STB, "engineer" role has full access, other roles only have simple stats
  if proxy.get(pathiface .. "stb") and proxy.get(pathiface .. "stb")[1].value then
    if proxy.get(pathiface .. "stb")[1].value == "1" then
      if ngx.ctx.session:getrole() ~= "engineer" then
        stbLimit = true
      end
    end
  end
end
local mapParams, mapValid = {}, {}
if post_helper.getVariantValue(variantHelper, "showsplitToggle") then
  if multiap_enabled then
    if credential_list[2] then
      mapParams.split_ssid = format("uci.multiap.controller_credentials.@%s.state", credential_list[2])
    end
    mapParams.em_band_steer = "rpc.multiap.X_000E50_BandSteering.Status"
  elseif smartWifiStatus == "1" and gettype ~= "guest" then
    if credential_instance_list[2] then
      mapParams.split_ssid = format("rpc.X_AIRTIES_OBJ.MultiAPController.SSIDProfile.%s.Enable", credential_instance_list[2])
    end
  else
    mapParams.split_ssid = "uci.web.network.@"..gettype..".splitssid"
  end
  mapValid.split_ssid = validateBoolean
end
if multiap_enabled and not guestMultiap then
  for _, credParamIndex in ipairs(credential_list) do
    credParamIndex = untaint(credParamIndex)
    mapParams["ssid" .. credParamIndex] = "uci.multiap.controller_credentials.@" .. credParamIndex .. ".ssid"
    mapParams["security" .. credParamIndex] = "uci.multiap.controller_credentials.@" .. credParamIndex .. ".security_mode"
    mapParams["password" .. credParamIndex] = "uci.multiap.controller_credentials.@" .. credParamIndex .. ".wpa_psk_key"
    mapValid["ssid" .. credParamIndex] = getAndValidation(getValidateStringLengthInRange(1,32),validateSSID,getValidateExtraSpaces)
    mapValid["security" .. credParamIndex] = getValidateInEnumSelect(securityModes)
    mapValid["password" .. credParamIndex] = getAndValidation(getValidationIfPropInList(validatePSK, "security"..  credParamIndex, {"wpa2-psk", "wpa-wpa2-psk", "wpa3-psk", "wpa2-wpa3-psk"}),getValidateExtraSpaces)
  end
  for _, curap in ipairs(aplists) do
    mapParams["ap_enabled"..curap] = "rpc.wireless.ap.@"..curap..".admin_state"
    mapValid["ap_enabled"..curap] = validateBoolean
  end
end

--To get and set the values when smartwifi is enabled
if smartWifiStatus == "1" then
  for _, credParamIndex in ipairs(credential_instance_list) do
    credParamIndex = untaint(credParamIndex)
    mapParams["ssid" .. credParamIndex] = "rpc.X_AIRTIES_OBJ.MultiAPController.SSIDProfile." .. credParamIndex .. ".SSID"
    mapParams["security" .. credParamIndex] = "rpc.X_AIRTIES_OBJ.MultiAPController.SSIDProfile." .. credParamIndex .. ".SecurityMode"
    mapParams["password" .. credParamIndex] = "rpc.X_AIRTIES_OBJ.MultiAPController.SSIDProfile." .. credParamIndex .. ".KeyPassphrase"
    mapValid["ssid" .. credParamIndex] = getAndValidation(getValidateStringLengthInRange(1,32),getValidateExtraSpaces)
    mapValid["security" .. credParamIndex] = getValidateInEnumSelect(securityModes)
    mapValid["password" .. credParamIndex] = getAndValidation(getValidationIfPropInList(validatePSK, "security"..  credParamIndex, { "wpa2-psk", "wpa3-psk", "wpa2-wpa3-psk" }),getValidateExtraSpaces)
  end
  for _, curap in ipairs(aplists) do
    mapParams["ap_enabled"..curap] = "rpc.wireless.ap.@"..curap..".admin_state"
    mapValid["ap_enabled"..curap] = validateBoolean
  end

end

if post_helper.getVariantValue(variantHelper, "steering") then
  mapParams["steering_state"] = "rpc.wireless.SmartWiFi.Steering_Enable"
  mapValid["steering_state"] = validateBoolean
end


if not post_helper.getVariantValue(variantHelper, "showsplitToggle") then
  aplists = ap_list
end
local pathap = format("rpc.wireless.ap.@%s.", curap)
for _, curap in ipairs(aplists) do
  if (not multiap_enabled or guestMultiap) or (not post_helper.getVariantValue(variantHelper, "showsplitToggle")) then
    if smartWifiStatus ~= "1" then
      mapParams["ap_broadcast_ssid"..curap] = "rpc.wireless.ap.@"..curap..".public"
      mapValid["ap_broadcast_ssid"..curap] = validateBoolean
    end
  end
  if not multiap_enabled  or guestMultiap then
    if smartWifiStatus ~= "1" then
      mapParams["ap_enabled"..curap] = "rpc.wireless.ap.@"..curap..".admin_state"
      mapParams["security"..curap] = "rpc.wireless.ap.@"..curap..".security.mode"
      mapParams["wep_key"..curap] = "rpc.wireless.ap.@"..curap..".security.wep_key"
      mapParams["wpa_psk"..curap] = "rpc.wireless.ap.@"..curap..".security.wpa_psk_passphrase"
      mapValid["ap_enabled"..curap] = validateBoolean
      mapValid["security"..curap] = getValidateInEnumSelect(secmodesap[curap])
      mapValid["wep_key"..curap] = getValidationIfPropInList(validateWEP,"security"..curap, {"wep"})
      mapValid["wpa_psk"..curap] = getValidationIfPropInList(validatePSK,"security"..curap, {"wpa-psk", "wpa2-psk", "wpa-wpa2-psk"})
      for iface, apVal in pairs(intf_check) do
      if apVal == curap then
        iface = untaint(iface)
        mapParams["ssid"..curap] = "rpc.wireless.ssid.@"..iface..".ssid"
        mapValid["ssid"..curap] = getAndValidation(getValidateStringLengthInRange(1,32),validateSSID,getValidateExtraSpaces)
      end
    end
  end
    pathapWpa3 = format("uci.wireless.wifi-ap-credential.@%s_", curap)
    pathRadius = format("uci.wireless.wifi-radius-server.@%s_", curap)
    radius_account["radius_account"..curap] = proxy.get(pathRadius .. "acct0.")
    radius_authent["radius_authent"..curap] = proxy.get(pathRadius .. "auth0.")
    pathpmf = format("uci.wireless.wifi-ap.@%s.", curap)
    if proxy.get(pathapWpa3 .. "credential0.passphrase") then
      mapParams["wpa3"..curap] = pathapWpa3 .. "credential0.passphrase"
      mapValid["wpa3"..curap] = getValidationIfPropInList(validatePSK,"security"..curap, {"wpa3", "wpa3-psk", "wpa2-wpa3", "wpa2-wpa3-psk"})
    end
    if proxy.get(pathpmf .. "pmf") then
      mapParams["pmf"..curap] = pathpmf .. "pmf"
    end
  end
  local isExtRemman = isExtRemman[curap] or "0"
  local isIntRemman = isIntRemman[curap] or "0"
  if isExtRemman ~= "1" and isIntRemman ~= "1" and not stbLimit and not multiap_enabled or guestMultiap then
    if smartWifiStatus ~= "1" then
      if radius_authent["radius_authent"..curap] then
        mapParams["radius_authent_state"..curap] = pathRadius .. "auth0.state"
        mapParams["radius_authent_ip"..curap] = pathRadius .. "auth0.ip"
        mapParams["radius_authent_port"..curap] = pathRadius .. "auth0.port"
        mapParams["radius_authent_secret"..curap] = pathRadius .. "auth0.secret"
        mapValid["radius_authent_state"..curap] = getConditionalValidation(radiusCond, getReplaceValue("1"), getReplaceValue("0"))
        mapValid["radius_authent_ip"..curap] = getValidationIfPropInList(getValidateStringISIP, "security"..curap, wpa_list)
        mapValid["radius_authent_port"..curap] = getValidationIfPropInList(validateStringIsPort, "security"..curap, wpa_list)
        mapValid["radius_authent_secret"..curap] = getValidationIfPropInList(validateNonEmptyString, "security"..curap, wpa_list)
      end
      if radius_account["radius_account"..curap] then
        mapParams["radius_account_state"..curap] = pathRadius .. "acct0.state"
        mapParams["radius_account_ip"..curap] = pathRadius .. "acct0.ip"
        mapParams["radius_account_port"..curap] = pathRadius .. "acct0.port"
        mapParams["radius_account_secret"..curap] = pathRadius .. "acct0.secret"
        mapValid["radius_account_state"..curap] = getConditionalValidation(getAndValidation(radiusCond, checkIPandPort), getReplaceValue("1"), getReplaceValue("0")) -- if no server ip or port, don't set to 1
        mapValid["radius_account_ip"..curap] = getValidationIfPropInList(getValidateStringISIP, "security"..curap, wpa_list)
        mapValid["radius_account_port"..curap] = getValidationIfPropInList(validateStringIsPort, "security"..curap, wpa_list)
        mapValid["radius_account_secret"..curap] = getValidationIfPropInList(validateNonEmptyString, "security"..curap, wpa_list)
      end
    end
  end
  if post_helper.getVariantValue(variantHelper, "getBandsteerParams") then
    if bsPeerAP then
      local bsid = bandsteer_helper.getBandSteerId(curiface)
      local bandsteerParams = {
        bsid = pap .. "@" .. curap .. ".bandsteer_id",
        bspeerid = pap .. "@" .. bsPeerAP .. ".bandsteer_id",
      }
      if (isguest ~= "1" or bsid and bsid ~= "" and bsid == "bs1") or post_helper.getVariantValue(variantHelper, "guestBandsteer") then
        bandsteerParams.bs_state = "uci.wireless.wifi-bandsteer.@".. bsid ..".state"
      end
      if bandsteerobj then
        if isBaseIface(curiface) then
          if bandsteeriface then
            local bandsteerAddParams = {
              bspifacessid = pIface .. "@" .. bandsteeriface .. ".ssid",
              bspeer_security = pap .. "@" .. bsPeerAP .. ".security_mode",}
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

        for index, val in pairs(bandsteerParams) do
          mapParams[index] = val
        end
      end
    end
  end
  if bandsteerobj then
    mapValid.bsid = getValidateBandSteerPeerFields
  end
end

if post_helper.getVariantValue(variantHelper, "frameBursting") and not bandsteerobj then
  mapValid.ap_enabled = function(val,object)
    if isguest ~= "1" then
      object.ap_enabled = object.admin_state
    end
    return true
  end
end

for _, curap in ipairs(aplists) do
  mapParams["acl_mode"..curap] = "uci.wireless.wifi-ap.@"..curap..".acl_mode"
  mapValid["acl_mode"..curap] = getValidateInEnumSelect(acl_supportedmodes[curap])
end

local splitMode
if smartWifiStatus == "1" and gettype ~= "guest" then
  splitMode = post_helper.getVariantValue(variantHelper, "showsplitToggle") and proxy.get(format("rpc.X_AIRTIES_OBJ.MultiAPController.SSIDProfile.%s.Enable", credential_instance_list[2]))[1].value or "0"
elseif multiap_enabled then
  splitMode = post_helper.getVariantValue(variantHelper, "showsplitToggle") and proxy.get(format("uci.multiap.controller_credentials.@%s.state", credential_list[2]))[1].value or "0"
else
  splitMode = post_helper.getVariantValue(variantHelper, "showsplitToggle") and proxy.get(format("uci.web.network.@"..gettype..".splitssid", gettype))[1].value or "0"
end

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

local bandsteerhelpmsg = {}

if ngx.req.get_method() == "POST" then
  local postargs = ngx.req.get_post_args()
  local preVal = proxy.get("rpc.wireless.SmartWiFi.Steering_Enable")
  preVal = preVal and preVal[1] and preVal[1].value or ""
  if postargs["split_ssid"] == "1" and preVal == "1" then
    proxy.set("rpc.wireless.SmartWiFi.Steering_Enable", "0")
    proxy.apply()
  end
  if smartWifiStatus == "1" and gettype ~= "guest" then
    if not next(helpmsg) then
      proxy.set(format("rpc.X_AIRTIES_OBJ.MultiAPController.SSIDProfile.%s.Enable", credential_instance_list[2]), postargs["split_ssid"])
      for indexVal, currentCred in ipairs(credential_instance_list) do
        currentCred = untaint(currentCred)
        proxy.set(format("rpc.X_AIRTIES_OBJ.MultiAPController.SSIDProfile.%s.SSID", currentCred), postargs["ssid" .. currentCred])
        proxy.set(format("rpc.X_AIRTIES_OBJ.MultiAPController.SSIDProfile.%s.KeyPassphrase", currentCred), postargs["password" .. currentCred])
        proxy.set(format("rpc.X_AIRTIES_OBJ.MultiAPController.SSIDProfile.%s.SecurityMode", currentCred), postargs["security" .. currentCred])
      end
      proxy.apply()
    end
  end

  -- Process POST query
  local tmpbandsteerhelpmsg = {}
  for k,v in pairs(helpmsg) do
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

  ngx.sleep(2)
end
  -- End of parameters saving / loading

if post_helper.getVariantValue(variantHelper, "showsplitToggle") then
  if content["split_ssid"] ~= split_ssid then
    interface_list, ap_list = {}, {}
    interface_list, split_ssid, bsid, bandsteer_state = generateInterfaceList(gettype)
    aplists, ap_list, intf_check, radio_list = generateAPList(interface_list)
    mergeAP, curaplist, ap_list, interface_list = mergedAPDetails(content["split_ssid"], content["bs_state"], ap_list)
  end
else
  content["split_ssid"] = "0"
end
if ngx.req.get_method() == "POST" and not next(helpmsg) then
  for _, curap in ipairs(aplists) do
    local securityMode = proxy.get(format("uci.wireless.wifi-ap.@%s.security_mode", curap))
    securityMode = securityMode and securityMode ~= "" and securityMode[1].value or ""
    if securityMode == "wpa3-psk" or securityMode == "wpa2-wpa3-psk" or securityMode == "wpa2-wpa3" or securityMode == "wpa3" then
      proxy.set(format("uci.wireless.wifi-ap-credential.@%s_credential0.state", curap), "1")
    else
      proxy.set(format("uci.wireless.wifi-ap-credential.@%s_credential0.state", curap), "0")
    end
    proxy.apply()
  end
end

local function hex2String(hexString)
    return hexString:gsub('(..)', function(value)
        return string.char(tonumber(value, 16))
    end)
end

local function decryptData(encryptedPassword)
    local ret = hex2String(encryptedPassword)
    local iv = ret:sub(1, 16)
    local rawcontent = ret:sub(17)
    local session_key = ngx.ctx.session:retrieve("session_key")
    local password, err = crypto.decrypt("AES-256-CBC", session_key, iv, rawcontent)
    return password
end

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SAVE" and not next(helpmsg) then
  local postargs = ngx.req.get_post_args()
  for k,v in pairs(postargs) do
    if match(k, "wpa_pskap") or match(k, "passwordcred") or match(k, "wep_keyap") or match(k, "wpa3") then
      v = decryptData(untaint(v))
    end
    postargs[k] = v
  end
  local setTable,setTablesec = {},{}
  for _, ap in ipairs(ap_list) do
    if postargs["wpa_psk"..ap] then
      proxy.set("rpc.wireless.ap.@" .. ap .. ".security.wpa_psk_passphrase", postargs["wpa_psk"..ap])
    end
    if postargs["security"..ap] == "wep" or postargs["security"..ap] == "wpa1" or postargs["security"..ap] == "wpa1/2" or (not post_helper.getVariantValue(variantHelper, "preserveWPSState") and (postargs["security"..ap] == "none") or false) or postargs["security"..ap] == "wpa3-psk" or postargs["ap_broadcast_ssid"..ap] == "0" then
      if post_helper.getVariantValue(variantHelper, "preserveWPSState") and postargs["security"..ap] == "wpa3-psk" and securityVal["security"..ap] ~= "wpa3-psk" then
        local wps_state = proxy.get("rpc.wireless.ap.@"..ap..".wps.admin_state") and proxy.get("rpc.wireless.ap.@"..ap..".wps.admin_state")[1].value or "0"
        proxy.set("uci.system.wifi-wps.@"..ap..".last_state", wps_state)
      end
      proxy.set("rpc.wireless.ap.@"..ap..".wps.admin_state", "0")
    end
    if postargs["ap_broadcast_ssid"..ap] == "1" and (postargs["security"..ap] ~= "wep" and postargs["security"..ap] ~= "wpa1" and postargs["security"..ap] ~= "wpa1/2" and postargs["security"..ap] ~= "none" and postargs["security"..ap] ~= "wpa3-psk") and post_helper.getVariantValue(variantHelper, "enableWPS") then
      proxy.set("rpc.wireless.ap.@"..ap..".wps.admin_state", "1")
    end
    proxy.apply()
  end
  postargs.split_ssid = postargs.split_ssid or split_ssid
  if multiap_enabled then
    if gettype == "main" or post_helper.getVariantValue(variantHelper, "showGuestWPS") then
      for _, cred in ipairs(credential_list) do
        if postargs[untaint("security"..cred)] == "wep" or postargs[untaint("security"..cred)] == "wpa1/2" or postargs[untaint("security"..cred)] == "wpa1" or (not post_helper.getVariantValue(variantHelper, "preserveWPSState") and ( postargs[untaint("security"..cred)] == "none") or false) or postargs[untaint("security"..cred)] == "wpa3-psk" then
          for _, ap in ipairs(ap_list) do
            if proxy.get("rpc.wireless.ap.@"..ap..".wps.admin_state")[1].value ~= "0" then
              proxy.set("rpc.wireless.ap.@"..ap..".wps.admin_state", "0")
              proxy.apply()
            end
          end
        else
          for _, ap in ipairs(ap_list) do
            if proxy.get("rpc.wireless.ap.@"..ap..".wps.admin_state")[1].value ~= "1" then
              proxy.set("rpc.wireless.ap.@"..ap..".wps.admin_state", "1")
              proxy.apply()
            end
          end
        end
      end
    end
  end
  if post_helper.getVariantValue(variantHelper, "frameBursting") then
    local retval = false
    local bsid = curiface and bandsteer_helper.getBandSteerId(curiface)
    if bsid and postargs["rssi_threshold"..bsid] then
      retval = proxy.set("uci.wireless.wifi-bandsteer.@" ..bsid..".rssi_threshold", format("%d", postargs["rssi_threshold"..bsid]))
    end
    if retval == true then
      proxy.apply()
    end
  end
  if (multiap_enabled and postargs.split_ssid == "0") then
    for indexVal, apVal in ipairs(aplists) do
      proxy.set("rpc.wireless.ap.@"..apVal..".admin_state", postargs["ap_enabled"..aplists[1]])
      if post_helper.getVariantValue(variantHelper, "multiapBroadCastACL") then
        proxy.set("rpc.wireless.ap.@"..apVal..".acl.mode", postargs["acl_mode"..aplists[1]])
        proxy.set("rpc.wireless.ap.@"..apVal..".public", postargs["ap_broadcast_ssid"..aplists[1]])
      end
      proxy.apply()
    end
  end
  if (not multiap_enabled and postargs.split_ssid == "0") or (guestMultiap and postargs.split_ssid == "0") then
    if smartWifiStatus ~= "1" then
      local mergeAPlist = {}
      for indexVal, apVal in ipairs(aplists) do
        if indexVal ~= 1 then
          mergeAPlist[#mergeAPlist + 1] = apVal
        end
      end
      if mergeAPlist then
        ap = aplists[1]
        local wps_state = proxy.get("rpc.wireless.ap.@"..ap..".wps.admin_state")
        wps_state = wps_state and wps_state[1] and wps_state[1].value and wps_state[1].value or ""
        local wps_last_state = proxy.get("uci.system.wifi-wps.@"..ap..".last_state")
        wps_last_state = wps_last_state and wps_last_state[1].value and wps_last_state[1].value or ""
        local radius_account, radius_authent = {}, {}
        for _, mergeAP in ipairs(mergeAPlist) do
          proxy.set("uci.wireless.wifi-ap.@"..mergeAP..".acl_mode", postargs["acl_mode"..ap])
          setTable["rpc.wireless.ap.@"..mergeAP..".admin_state"] = postargs["ap_enabled"..ap]
          setTable["rpc.wireless.ap.@"..mergeAP..".security.mode"] = postargs["security"..ap]
          setTable["rpc.wireless.ap.@"..mergeAP..".public"] = postargs["ap_broadcast_ssid"..ap]
          if wps_state ~= "" then
            setTable["rpc.wireless.ap.@" .. mergeAP .. ".wps.admin_state"] = wps_state
          end
          if wps_last_state ~= "" then
            setTable["uci.system.wifi-wps.@" ..mergeAP.. ".last_state"] = wps_last_state
          end
          if postargs["security"..ap] == "wpa3-psk" or postargs["security"..ap] == "wpa2-wpa3-psk" then
            setTablesec["rpc.wireless.ap.@"..mergeAP..".security.wpa_psk_passphrase"] = postargs["wpa3" ..ap]
            setTablesec["uci.wireless.wifi-ap.@" ..mergeAP..".wpa_psk_key"] = postargs["wpa3"..ap]
            setTablesec["uci.wireless.wifi-ap-credential.@" .. mergeAP .. "_credential0.passphrase"] = postargs["wpa3"..ap]
            setTable["uci.wireless.wifi-ap-credential.@" .. mergeAP .. "_credential0.state"] = "1"
            if postargs["security"..ap] == "wpa3-psk" then
                    setTable["rpc.wireless.ap.@" .. mergeAP .. ".wps.admin_state"] = "0"
            end
          else
            setTablesec["uci.wireless.wifi-ap.@" ..mergeAP..".wpa_psk_key"] = postargs["wpa_psk"..ap]
            if proxy.getPN('"uci.wireless.wifi-ap-credential.@" .. mergeAP .. "_credential0.state"', true) then
              setTable["uci.wireless.wifi-ap-credential.@" .. mergeAP .. "_credential0.state"] = "0"
            end
          end
          setTable["uci.wireless.wifi-ap.@" ..mergeAP..".pmf"] = postargs["security"..ap] == "wpa3-psk" and "required" or postargs["security"..ap] == "wpa2-wpa3-psk" and "enabled" or "disabled"
          for indexVal, apVal in pairs(intf_check) do
            indexVal = untaint(indexVal)
            if mergeAP == apVal then
              proxy.set("rpc.wireless.ssid.@"..indexVal..".ssid", postargs["ssid"..ap])
            end
          end
          setTable["rpc.wireless.ap.@"..mergeAP..".public"] = postargs["ap_broadcast_ssid"..ap]
          pathRadius = format("uci.wireless.wifi-radius-server.@%s_", mergeAP)
          radius_account["radius_account"..mergeAP] = proxy.get(pathRadius .. "acct0.")
          radius_authent["radius_authent"..mergeAP] = proxy.get(pathRadius .. "auth0.")
          if radius_authent["radius_authent".. mergeAP] then
            setTable[pathRadius .. "auth0.state"] = postargs["radius_authent_state"]
            setTable[pathRadius .. "auth0.ip"] = postargs["radius_authent_ip".. ap]
            setTable[pathRadius .. "auth0.port"] = postargs["radius_authent_port".. ap]
            setTable[pathRadius.. "auth0.secret"] = postargs["radius_authent_secret".. ap]
          end
          if radius_account["radius_account"..mergeAP] then
            setTable[pathRadius .. "acct0.state"] =  postargs["radius_account_state"]
            setTable[pathRadius .. "acct0.ip"] = postargs["radius_account_ip".. ap]
            setTable[pathRadius .. "acct0.port"] = postargs["radius_account_port".. ap]
            setTable[pathRadius .. "acct0.secret"] = postargs["radius_account_secret".. ap]
          end
        end
      end
    end
  end
  if multiap_enabled and gettype == "main" and postargs.split_ssid ~= "1" then
    local setTableCreds = {}
    setTableCreds["uci.multiap.controller_credentials.@" .. untaint(credential_list[2]) .. ".ssid"] = postargs["ssidcred0"]
    setTableCreds["uci.multiap.controller_credentials.@" .. untaint(credential_list[2]) .. ".wpa_psk_key"] = postargs["passwordcred0"]
    setTableCreds["uci.multiap.controller_credentials.@" .. untaint(credential_list[2]) .. ".security_mode"] = postargs["securitycred0"]
    proxy.set(setTableCreds)
    proxy.apply()
  end
  local success = false
  if gettype ~= "guest" then
    if postargs.split_ssid == "0" then
      success = proxy.set("uci.multiap.controller_credentials.@"..untaint(credential_list[1])..".frequency_bands", "radio_2G,radio_5Gl,radio_5Gu")
    elseif postargs.split_ssid == "1" then
      success = proxy.set("uci.multiap.controller_credentials.@"..untaint(credential_list[1])..".frequency_bands", "radio_2G")
    end
  end
  local pmfValue, apVal
  for _, curap in ipairs(ap_list) do
    apVal = curap
    if postargs["wpa3"..curap] and postargs["security"..curap] and string.match(postargs["security"..curap], "wpa3") then
      setTable["rpc.wireless.ap.@" .. curap  .. ".security.wpa_psk_passphrase"] = postargs["wpa3"..curap]
      setTable["uci.wireless.wifi-ap-credential.@" .. curap .. "_credential0.passphrase"] = postargs["wpa3"..curap]
      setTable["uci.wireless.wifi-ap-credential.@" .. curap .. "_credential0.state"] = "1"
      if postargs["security"..curap] == "wpa2-wpa3-psk" then
        setTable["uci.wireless.wifi-ap.@" .. curap  .. ".pmf"] = "enabled"
        pmfValue = "enabled"
      elseif postargs["security"..curap] == "wpa3-psk" then
        setTable["uci.wireless.wifi-ap.@" .. curap  .. ".pmf"] = "required"
        pmfValue = "required"
      end
    else
      setTable["uci.wireless.wifi-ap.@" .. curap  .. ".pmf"] = "disabled"
      pmfValue = "disabled"
      if proxy.getPN('"uci.wireless.wifi-ap-credential.@" .. curap .. "_credential0.state"', true) then
        setTable["uci.wireless.wifi-ap-credential.@" .. curap .. "_credential0.state"] = "0"
      end
    end
  end
  if not post_helper.getVariantValue(variantHelper, "showsplitToggle") and not multiap_enabled or guestMultiap then
    if smartWifiStatus ~= "1" then
      for _, curap in ipairs(mergeAP) do
        if postargs["wpa3"..apVal] and postargs["security"..apVal] and string.match(postargs["security"..apVal], "wpa3") then
          setTablesec["rpc.wireless.ap.@" .. curap  .. ".security.wpa_psk_passphrase"] = postargs["wpa3"..apVal]
          setTablesec["uci.wireless.wifi-ap-credential.@" .. curap .. "_credential0.passphrase"] = postargs["wpa3"..apVal]
          setTable["uci.wireless.wifi-ap-credential.@" .. curap .. "_credential0.state"] = "1"
          setTablesec["uci.wireless.wifi-ap.@" ..curap..".wpa_psk_key"] = postargs["wpa3"..apVal]
        else
          if proxy.getPN('"uci.wireless.wifi-ap-credential.@" .. curap .. "_credential0.state"', true) then
            setTable["uci.wireless.wifi-ap-credential.@" .. curap .. "_credential0.state"] = "0"
          end
        end
        setTable["uci.wireless.wifi-ap.@" .. curap  .. ".pmf"] = pmfValue
      end
    end
  end
  proxy.set(setTable)
  proxy.apply()
  proxy.set(setTablesec)
  proxy.apply()
  ngx.sleep(1)
end

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SAVE" then
  local postargs = ngx.req.get_post_args()
  if splitMode ~= postargs.split_ssid then
    session:store("issplitssid", "1")
  end
  if postargs.split_ssid == "1" and splitMode ~= postargs.split_ssid and not multiap_enabled and not next(helpmsg) then
    if gettype == "main" or post_helper.getVariantValue(variantHelper, "guestBandsteer") then
      proxy.set("uci.wireless.wifi-bandsteer.@"..bsid..".state", "0")
      if post_helper.getVariantValue(variantHelper, "preserveBandsteer") then
        proxy.set("uci.system.wifi-bandsteer.@"..preserveBandsteerId..".bandsteer_last_state", preserveBandsteerState)
      end
      proxy.apply()
    end
  end
  if post_helper.getVariantValue(variantHelper, "preserveWPSState") then
    for _, curap in ipairs(ap_list) do
      if postargs["security"..curap] ~= "wpa3-psk" and securityVal["security"..curap] == "wpa3-psk" then
        local wps_state = proxy.get("uci.system.wifi-wps.@"..curap..".last_state") and proxy.get("uci.system.wifi-wps.@"..curap..".last_state")[1].value or "0"
        proxy.set("rpc.wireless.ap.@"..curap..".wps.admin_state", wps_state)
      end
      proxy.apply()
    end
  end
  if content["split_ssid"] == "1" and splitMode ~= postargs.split_ssid then
    local suffix = proxy.get("uci.env.var.commonssid_suffix") and proxy.get("uci.env.var.commonssid_suffix")[1].value or ""
    if suffix and suffix ~= "" then
      local ssidVal
      if multiap_enabled and not guestMultiap then
        ssidVal = proxy.get("uci.multiap.controller_credentials.@"..untaint(credential_list[2])..".ssid") and proxy.get("uci.multiap.controller_credentials.@"..untaint(credential_list[2])..".ssid")[1].value or ""
      else
        ssidVal = interface_list[2] and proxy.get(format("rpc.wireless.ssid.@%s.ssid", interface_list[2])) and proxy.get(format("rpc.wireless.ssid.@%s.ssid", interface_list[2]))[1].value or ""
      end
      if not string.match(ssidVal, suffix) and ssidVal then
        ssidVal = ssidVal..suffix
        local path = multiap_enabled and not guestMultiap and "uci.multiap.controller_credentials.@"..untaint(credential_list[2])..".ssid" or format("rpc.wireless.ssid.@%s.ssid", interface_list[2])
        proxy.set(path, ssidVal)
        proxy.apply()
      end
      if multiap_enabled and not guestMultiap then
        content["ssid" .. untaint(credential_list[2])] = ssidVal
      else
        content["ssid" .. untaint(aplists[2])] = ssidVal
      end
    end
  end
end

local content_rssi = {}
local band_steer_supported, band_steer_enabled
local bs_peer_network_enable = "0"
local bs_peer_oper_state = "0"

if bandsteerpathap ~="" then
  curap = curaplist
  --Need to consider the constraint
  band_steer_supported, band_steer_enabled = bandsteer_helper.getBandSteerState(bsPeerAP, curap, multiap_enabled and multiap_cred_secondary_path, gettype == "guest" and "1" or "0")
  local content_band_steer = {
    band_steer_id = "uci.wireless.wifi-ap.@".. curap .. ".bandsteer_id",
    band_steer_ap_enabled = bandsteerpathap .. "admin_state",
    band_steer_oper_state = bandsteerpathap .. "bs_oper_state"
  }
  if bandsteerobj then
    content_helper.getExactContent(content_band_steer)
  end

  bs_peer_network_enable = content_band_steer.band_steer_ap_enabled
  bs_peer_oper_state = content_band_steer.band_steer_oper_state

  if bs_peer_network_enable == "1" and band_steer_supported and post_helper.getVariantValue(variantHelper, "frameBursting") then
    local bsid = bandsteer_helper.getBandSteerId(curiface)
    content_rssi = {}
    content_rssi["rssi_threshold"..bsid] = bandsteerpath .. "@" .. bsid .. ".rssi_threshold"
  end
  if bandsteerobj then
    content_helper.getExactContent(content_rssi)
  end
end

local function aclPageLoad(content, curap, split_ssid)
  if post_helper.variantHasAccess(variantHelper, "ACLList", role) then
    html = {}
    local aclClass = "acl_list"..curap
    html[#html + 1] = string.format("<fieldset class=\"%s\">", "acl_list"..curap)
    html[#html + 1] = "<legend>"
    html[#html + 1] =  T"Access Control List"
    html[#html + 1] = "</legend>"
    local aclmodeclass = {
      select = {
        class = "monitor-changes",
        id="aclmode"..curap
      }
    }
    if post_helper.getVariantValue(variantHelper, "ACLWarning") then
      local acl_attribute = {
        label = {
          class = "monitor-acl_mode"..curap.." monitor-register"
        },
        button = {
          class = "monitor-acl_mode"..curap.." monitor-register",
          id = "btn_acl"..curap
        }
      }
      if (ngx.req.get_method() == "POST" and  ngx.req.get_post_args().action ~="nil" and string.find(ngx.req.get_post_args().action, "TABLE") ~= nil) then
        local tableid = ngx.req.get_post_args().tableid
        if tableid == "acl_whitelist"..curap then
          content["acl_mode"..curap] = "lock"
        elseif tableid == "acl_blacklist"..curap then
          content["acl_mode"..curap] = "unlock"
        elseif tableid == "acl_register"..curap then
          content["acl_mode"..curap] = "register"
        end
        html[#html + 1] = ui_helper.createInputSelect(T"ACL mode", "acl_mode"..curap, acl_supportedmodes[curap], content["acl_mode"..curap], aclmodeclass)
        if content["acl_mode"..curap] == "register" then
          html[#html + 1] = ui_helper.createButton(T"ACL Reg", T"Register", nil, acl_attribute)
        end
        local mergeAP = post_helper.getVariantValue(variantHelper, "steering") and ngx.req.get_post_args().split_ssid == "0" and untaint(aplists[2]) or curap
        html[#html + 1] = loadAclList(content["acl_mode"..curap], "POST", mergeAP)
        isTableLoaded[curap] =  true
      elseif ngx.req.get_method() == "GET" and ngx.req.get_uri_args().action == "split_ssid" then
        html[#html + 1] = ui_helper.createInputSelect(T"ACL mode", "acl_mode"..curap, acl_supportedmodes[curap], content["acl_mode"..curap], aclmodeclass)
        if content["acl_mode"..curap] == "register" then
          html[#html + 1] = ui_helper.createButton(T"ACL Reg", T"Register", nil, acl_attribute)
        end
        local mergeAP = post_helper.getVariantValue(variantHelper, "steering") and ngx.req.get_uri_args().splitssid == "0" and untaint(aplists[2]) or curap
        html[#html + 1] = loadAclList(content["acl_mode"..curap], "GET", mergeAP)
      else
        html[#html + 1] = ui_helper.createInputSelect(T"ACL mode", "acl_mode"..curap, acl_supportedmodes[curap], content["acl_mode"..curap], aclmodeclass)
        html[#html + 1] = ui_helper.createButton(T"ACL Reg", T"Register", nil, acl_attribute)
        local acl_list = "acl_list_div"..curap
        local acl_class = "monitor-acl_mode"..curap.." monitor-lock monitor-register monitor-unlock"
        html[#html + 1] = string.format("<div id=\"%s\" class=\"%s\"><img src=\"/img/loading.gif\"/></div>", acl_list, acl_class)
      end
    else
      html[#html + 1] = ui_helper.createInputSelect( T"ACL mode", "acl_mode"..curap, acl_supportedmodes[curap], content["acl_mode"..curap], aclmodeclass)
      local infomessage = {
        alert = {
          class = "alert-info monitor-acl_mode"..curap.." monitor-disabled",
        }
      }
      html[#html + 1] = ui_helper.createAlertBlock(T"Disabled mode will allow access to all devices", infomessage)
      local whitelistinfoclass = {
        alert = {
          class = "alert-info monitor-acl_mode"..curap.." monitor-lock",
        }
      }
      html[#html + 1] = ui_helper.createAlertBlock(T"White List mode will deny access to all devices, except for the devices with MAC address in the list below:", whitelistinfoclass)

      local blacklistinfoclass = {
        alert = {
          class = "alert-info  monitor-acl_mode"..curap.." monitor-unlock",
        }
      }
      html[#html + 1] = ui_helper.createAlertBlock(T"Black List mode will allow access to all devices, except for the devices with MAC address in the list below:", blacklistinfoclass)
      html[#html + 1] = loadAclList(content["acl_mode"..curap], "POST", curap)
    end
    html[#html + 1] = [[</fieldset>]]
  return html
  end
end

local function loadQRCode(content, curiface, curap)
  if post_helper.getVariantValue(variantHelper, "qrCodeFeature") then   ngx.print('\
    <fieldset class="qrcode advanced hide">\
    ');  if content["security"] ~= "wpa-wpa2" and content["security"] ~= "wpa2" then   ngx.print('\
      <legend>');  ngx.print( T"QR Code" ); ngx.print('</legend>\
      ');  ngx.print( format([[
        <center>
          <div class="btn custom-handler" data-remote="modals/wireless-qrcode-modal.lp?iface=%s&ap=%s" data-toggle="modal">
            %s
          </div>
        </center>
      ]], curiface, curap, T"Generate QRCode")); ngx.print('\
    ');  end  ngx.print('\
    </fieldset>\
  ');  end
end

local function loadMultiAPDetails(content, indexVal, curap, split_ssid_em)
  html = {}
  if smartWifiStatus == "1" then
    credParam = untaint(credential_instance_list[indexVal])
  else
    credParam = untaint(credential_list[indexVal])
  end
  local checkbox2 = {
    group = {
      class ="monitor-security"..credParam.." monitor-wep monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk monitor-wpa3 monitor-wpa3-psk monitor-wpa2-wpa3 monitor-wpa2-wpa3-psk wirelessPwd"..credParam,
    },
    checkbox = {
      class = "inline"
    },
    input = {
      id = "showpass"..credParam,
      class = "no-save"
    },
  }
  if credParam then
    html[#html + 1] = "<fieldset>"
    html[#html + 1] = "<legend>"
    html[#html + 1] = radiofreq[untaint(curap)]
    html[#html + 1] = [[</legend>]]
    for index, intfVal in pairs(intf_check) do
      if intfVal == curap then
        curiface = index
      end
    end
    local stateClass = {
      group = {
        class = "multiapstateClass"..curap
      },
      switch = {
        class = "multiapstate"..curap
      }
    }
    if (smartWifiStatus == "1" and gettype == "guest") then
      local labelstate = T"Off"
      if content["ap_enabled"..curap] == "1" or content["split_ssid"] == "0" and content["ap_enabled"..adjacent_ap] == "1" then
        labelstate = T"On"
      end
      html[#html + 1] = ui_helper.createLabel(T"State", labelstate)
    else
      html[#html + 1] = ui_helper.createSwitch(T"State", "ap_enabled"..curap, content["ap_enabled"..curap], stateClass)
    end
    -- Show the SSID
    local ssidclass = {
      input = {
        maxlength= "32",
        class= "span4",
      }
    }
    local broadcastclass = {
      group = {
        class = "broadcast_ssid"..curap,
      },
      input = {
        class = "monitor-changes"
      }
    }
    -- Select the security mode to use
    local secattributes = {
      group = {
        class = "",
      },
      select = {
        class = "monitor-changes"
      }
    }
    if content["security"..credParam] == "none" then
      local security_warning = {
        alert = {
          class = "alert-error monitor-security"..credParam.." monitor-none"
        },
      }
      html[#html + 1] = ui_helper.createAlertBlock(T"Security for this wireless network is disabled, anybody can connect or listen to it", security_warning)
    end
    if multiap_agent or (smartWifiStatus == "1" and gettype == "guest") then
      html[#html + 1] = ui_helper.createLabel( T"SSID", content["ssid"..credParam], ssidclass)
    else
      html[#html + 1] = ui_helper.createInputText(T"SSID", "ssid"..credParam, content["ssid"..credParam], ssidclass, helpmsg["ssid"..credParam])
    end
    if post_helper.getVariantValue(variantHelper, "multiapBroadCastACL") then
      html[#html + 1] = ui_helper.createSwitch(T"Broadcast SSID", "ap_broadcast_ssid"..curap, content["ap_broadcast_ssid"..curap], broadcastclass)
    end
    if multiap_agent or (smartWifiStatus == "1" and gettype == "guest") then
      html[#html + 1] = ui_helper.createLabel(T"Security Mode", content["security"..credParam])
    else
      html[#html + 1] = ui_helper.createInputSelect(T"Security Mode", "security"..credParam, securityModes, content["security"..credParam], secattributes)
    end
    local pskclass = {
      group = {
        class ="monitor-security"..credParam.." monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk monitor-wpa3 monitor-wpa3-psk monitor-wpa2-wpa3 monitor-wpa2-wpa3-psk wirelessPwd"..credParam,
      },
      input = {
        class= "span4 password_class_input",
        maxlength="63"
      }
    }
    if multiap_agent or (smartWifiStatus == "1" and gettype == "guest")then
      if content["security"..credParam] ~= "none" then
        html[#html + 1] = ui_helper.createLabel(T"Wireless Password", content["password"..credParam], {span = { id = "wirelessPassword"..credParam }})
      end
    else
      html[#html + 1] = ui_helper.createInputText(T"Wireless Password", "password"..credParam, content["password"..credParam], pskclass, helpmsg["password"..credParam])
    end

    if post_helper.getVariantValue(variantHelper, "showWirelessPassword") then
      html[#html + 1] = ui_helper.createCheckboxSwitch(T"Show Password", "showpass"..credParam, "0", checkbox2)
    end
    local bssecclass = {
      group = {
        class = "bandsteer_support"
      },
      input = {
        class ="monitor-security"..credParam.." monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk monitor-none",
      },
      switch = {
        class = "bandsteerSupportedParam"
      },
      select = {
        class = "bandsteerSupportedParam"
      }
    }

    if split_ssid_em == "0" and smartWifiStatus ~= "1" then
      html[#html + 1] = ui_helper.createLabel(T"Band Steering State", content["em_band_steer"] == "1" and T"Enabled" or T"Disabled", {span = { id = "bs_status" }})
    elseif split_ssid_em == "0" and smartWifiStatus == "1" and gettype ~= "guest" then
      html[#html + 1] = ui_helper.createSwitch(T"Steering Enabled", "steering_state", content["steering_state"] == "1" and "1" or "0", bssecclass)
    end
  end
  return html
end

local function loadAPDetails(content, curap, split_ssid, intf_check)
  local html = {}
    if not stbLimit then
      html[#html + 1] = "<fieldset>"
    else
      html[#html + 1] = "<fieldset class=\"advanced hide\">"
    end
    html[#html + 1] = "<legend>"
    html[#html + 1] = radiofreq[untaint(curap)]
    html[#html + 1] = [[</legend>]]
    for index, intfVal in pairs(intf_check) do
      if intfVal == curap then
        curiface = index
      end
    end
    local checkbox2 = {
      group = {
        class ="monitor-security"..curap.." monitor-wep monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk wirelessPwd"..curap.." monitor-wpa3 monitor-wpa3-psk monitor-wpa2-wpa3 monitor-wpa2-wpa3-psk",
      },
      checkbox = {
        class = "inline"
      },
      input = {
        id = "showpass"..curap,
        class = "no-save"
      },
    }
    -- Show if the AP is enabled
    html[#html + 1] = ui_helper.createSwitch(T"State", "ap_enabled"..curap, content["ap_enabled"..curap], advanced)
    if not stbLimit then
      -- Show the SSID
      local ssidclass = {
        input = {
          maxlength= "32",
          class= "span4",
        }
      }
      if not post_helper.getVariantValue(variantHelper, "steering") then
        if multiap_agent or (band_steer_enabled and not isBaseIface(curiface) and post_helper.getVariantValue(variantHelper, "frameBursting") and bandsteerobj) or (smartWifiStatus == "1" and curiface == "wl1") then
          html[#html + 1] = ui_helper.createLabel( T"SSID name", content["ssid"..curap], ssidclass)
        else
          html[#html + 1] = ui_helper.createInputText(T"SSID", "ssid"..curap, content["ssid"..curap], ssidclass, helpmsg["ssid"..curap])
        end
      else
        html[#html + 1] = ui_helper.createInputText(T"SSID", "ssid"..curap, content["ssid"..curap], ssidclass, helpmsg["ssid"..curap])
      end
      local broadcastclass = {
        switch = {
          class = "broadcast_switch_class",
          id = "broadcast_switch_id"..curap,
        },
        group = {
          class = "broadcast_ssid"..curap,
        },
        input = {
          class = "monitor-changes"
        }
      }

      -- Should we broadcast the SSID
      if smartWifiStatus ~= "1" and agentView then
        html[#html + 1] = ui_helper.createSwitch(T"Broadcast SSID", "ap_broadcast_ssid"..curap, content["ap_broadcast_ssid"..curap], broadcastclass)
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

      if content["security"..curap] == "none" then
        local security_warning = {
          alert = {
            class = "alert-error monitor-security"..curap.." monitor-none"
          },
        }
        html[#html + 1] = ui_helper.createAlertBlock(T"Security for this wireless network is disabled, anybody can connect or listen to it", security_warning)
      end
      if not post_helper.getVariantValue(variantHelper, "steering") then
        if multiap_agent or (band_steer_enabled and not isBaseIface(curiface) and post_helper.getVariantValue(variantHelper, "frameBursting") and bandsteerobj) then
          html[#html + 1] = ui_helper.createLabel(T"Security Mode", content["security"..curap], secattributes)
        else
          html[#html + 1] = ui_helper.createInputSelect(T"Security Mode", "security"..curap, secmodesap[curap], content["security"..curap], secattributes)
        end
      else
        html[#html + 1] = ui_helper.createInputSelect(T"Security Mode", "security"..curap, secmodesap[curap], content["security"..curap], secattributes)
      end
      local pskclass = {
        group = {
          class ="monitor-security"..curap.." monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk wirelessPwd"..curap,
        },
        input = {
          class= "span4 password_class_input",
          maxlength="63"
        }
      }
      local pskwpa3 = {
        group = {
          class ="monitor-security"..curap.." monitor-wpa3 monitor-wpa3-psk monitor-wpa2-wpa3 monitor-wpa2-wpa3-psk",
          style = "display: none"
        },
        input = {
          class= "span4 password_class_input",
          maxlength="63"
        }
      }
      local wepclass = {
        group = {
          class ="monitor-security"..curap.." monitor-wep",
          style = "display: none"
        },
        input = {
          class= "span4 password_class_input",
        }
      }

      if post_helper.getVariantValue(variantHelper, "frameBursting") then
        if bandsteerobj and band_steer_enabled and not isBaseIface(curiface) and not post_helper.getVariantValue(variantHelper, "steering") then
          if "wep" == content["security"..curap] and not post_helper.getVariantValue(variantHelper, "hideWEPKey") then
             html[#html + 1] = ui_helper.createLabel(T"WEP Key", content["wep_key"..curap], {span = { id = "wirelessPassword"..curap }})
          end
          if "wpa-psk" == content["security"..curap] or "wpa2-psk" == content["security"..curap] or "wpa-wpa2-psk" == content["security"..curap] then
            html[#html + 1] = ui_helper.createLabel(T"Wireless Password", content["wpa_psk"..curap], {span = { id = "wirelessPassword"..curap }})
          end

          if "wpa3" == content["security"..curap] or "wpa3-psk" == content["security"..curap] or "wpa2-wpa3-psk" == content["security"..curap] or "wpa2-wpa3" == content["security"..curap] then
            if curiface == "wl1" or gettype == "guest" and curiface == "wl1_1" then
              html[#html + 1] = ui_helper.createLabel(T"Wireless Password", content["wpa3"..curap],{span = { id = "wirelessPassword"..curap }})
            end
            html[#html + 1] = ui_helper.createInputText(T"Wireless Password", "wpa3"..curap, content["wpa3"..curap], pskwpa3)
          end
        else
          if multiap_agent and content["security"..curap] ~= "none" then
            html[#html + 1] = ui_helper.createLabel(T"Wireless Password", content["wpa_psk"..curap], {span = { id = "wirelessPassword"..curap }})
          else
            html[#html + 1] = ui_helper.createInputText(T"Wireless Password", "wpa_psk"..curap, content["wpa_psk"..curap], pskclass, helpmsg["wpa_psk"..curap])
            html[#html + 1] = ui_helper.createInputText(T"Wireless Password", "wpa3"..curap, content["wpa3"..curap], pskwpa3, helpmsg["wpa3"..curap])
          end
          if not post_helper.getVariantValue(variantHelper, "hideWEPKey") then
            html[#html + 1] = ui_helper.createInputText(T"WEP Key", "wep_key"..curap, content["wep_key"..curap], wepclass, helpmsg["wep_key"..curap])
          end
        end
        if post_helper.getVariantValue(variantHelper, "showWirelessPassword") then
          html[#html + 1] = ui_helper.createCheckboxSwitch(T"Show Password", "showpass"..curap, "0", checkbox2)
        end
      else
        local wait_alert = {
          alert = {
            class = "alert-info hide",
            id = "wait-time-msg"
          },
        }
        if ((smartWifiStatus == "1" and curiface == "wl1") or multiap_agent) and content["security"..curap] ~= "none" then
          html[#html + 1] = ui_helper.createLabel(T"Wireless Password", content["wpa_psk"..curap], {span = { id = "wirelessPassword"..curap }})
        else
          html[#html + 1] = ui_helper.createAlertBlock(T"Please apply your changes after few seconds", wait_alert)
          html[#html + 1] = ui_helper.createInputText(T"Wireless Password", "wpa_psk"..curap, content["wpa_psk"..curap], pskclass, helpmsg["wpa_psk"..curap])
          html[#html + 1] = ui_helper.createInputText(T"Wireless Password", "wpa3"..curap, content["wpa3"..curap], pskwpa3, helpmsg["wpa3"..curap])
        end
        if not post_helper.getVariantValue(variantHelper, "hideWEPKey") then
          html[#html + 1] = ui_helper.createInputText(T"WEP Key", "wep_key"..curap, content["wep_key"..curap], wepclass, helpmsg["wep_key"..curap])
        end
        if post_helper.getVariantValue(variantHelper, "showWirelessPassword") then
          html[#html + 1] = ui_helper.createCheckboxSwitch(T"Show Password", "showpass"..curap, "0",checkbox2)
        end
      end
      if (isExtRemman  ~= "1" and isIntRemman ~= "1") then
        local monitorradius = {
          class ="monitor-security"..curap.." monitor-wpa monitor-wpa2 monitor-wpa-wpa2",
          style = "display:none"
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
        local radius_authent = radius_authent["radius_authent"..curap]
        local radius_account = radius_account["radius_account"..curap]
        if bandsteerobj and band_steer_enabled and not isBaseIface(curiface) then
          if "wpa" == content["security"..curap] or "wpa2" == content["security"..curap] or "wpa-wpa2" == content["security"..curap] then
            if radius_authent then
              html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server's IP", "radius_authent_ip"..curap, content["radius_authent_ip"..curap], serverclass, helpmsg["radius_authent_ip"..curap])
              html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server's port", "radius_authent_port"..curap, content["radius_authent_port"..curap], basicclass, helpmsg["radius_authent_port"..curap])
              html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server's secret", "radius_authent_secret"..curap, content["radius_authent_secret"..curap], basicclass, helpmsg["radius_authent_secret"..curap])
            end
            if radius_account then
              html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server's IP", "radius_account_ip"..curap, content["radius_account_ip"..curap], serverclass, helpmsg["radius_account_ip"..curap])
              html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server's port", "radius_account_port"..curap, content["radius_account_port"..curap], basicclass, helpmsg["radius_account_port"..curap])
              html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server's secret", "radius_account_secret"..curap, content["radius_account_secret"..curap], basicclass, helpmsg["radius_account_secret"..curap])
            end
          end
        else
          if radius_authent then
            html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server's IP", "radius_authent_ip"..curap, content["radius_authent_ip"..curap], serverclass, helpmsg["radius_authent_ip"..curap])
            html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server's port", "radius_authent_port"..curap, content["radius_authent_port"..curap], basicclass, helpmsg["radius_authent_port"..curap])
            html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server's secret", "radius_authent_secret"..curap, content["radius_authent_secret"..curap], basicclass, helpmsg["radius_authent_secret"..curap])
          end
         if radius_account then
           html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server's IP", "radius_account_ip"..curap, content["radius_account_ip"..curap], serverclass, helpmsg["radius_account_ip"..curap])
           html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server's port", "radius_account_port"..curap, content["radius_account_port"..curap], basicclass, helpmsg["radius_account_port"..curap])
           html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server's secret", "radius_account_secret"..curap, content["radius_account_secret"..curap], basicclass, helpmsg["radius_account_secret"..curap])
         end
       end
      end
      if post_helper.variantHasAccess(variantHelper, "BandSteerElement", role) and bandsteerobj and split_ssid == "0" then
        for index, intfVal in pairs(intf_check) do
          if intfVal == curap then
            curiface = index
          end
        end
        if post_helper.getVariantValue(variantHelper, "bandsteerSupport")  then
          if (content["ap_enabled"..curap] == "1" and bs_peer_network_enable == "1" and band_steer_supported) then
            local bssecclass = {
              group = {
                class = "bandsteer_support"
              },
              input = {
                class ="monitor-security"..curap.." monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk monitor-none",
              },
              switch = {
                class = "bandsteerSupportedParam"
              },
              select = {
                class = "bandsteerSupportedParam"
              }
            }
            -- General rangeSlider
            -- Created since some classes are missed in javascript load function
            -- @param #string label_name
            -- @param #string name
            -- @param #string content
            -- @param #number min
            -- @param #number max
            -- @param #number step
            -- @param #string unit
            function dynamicCreateSlider(label_name, name, content, min, max, step, unit)
                controlGroup = {
                    style = "display: inline;",
                }
                label = {
                    class = "control-label",
                }
                control = {
                    class = "controls",
                    style = "margin-top:5px;"
                }
                slider = {
                    class = "bandsteerSupportedParam",
                    style = "float:left;",
                }
                input = {
                    type = "range",
                    class="slider",
                    id="myRange",
                    onchange="showSlider(this.value)"
                }
                showSlider = {
                    id = "Slider_ID",
                    style = "padding-left:220px",
                }
                local html = {
                    format([[<div class="control-group bandsteer_support" style=%s>
                        <label class=%s>%s</label>
                            <div class=%s style=%s>
                                <div id=%s class=%s style=%s name=%s>
                                <input type=%s name=%s min=%s max=%s step=%s value=%s class=%s id=%s onchange=%s></div>
                                <div id=%s style=%s>%s%s </div>
                            </div>
                    </div>]], controlGroup["style"], label["class"], label_name, control["class"], control["style"], name, slider["class"], slider["style"], name, input["type"], name, min, max, step, content, input["class"], input["id"], input["onchange"], showSlider["id"], showSlider["style"], content, unit)
                }
                return html
            end
            if post_helper.getVariantValue(variantHelper, "steering") then
              if smartWifiStatus ~= "1" then
                if isBaseIface(curiface) then
                  bsid = bandsteer_helper.getBandSteerId(curiface)
                  html[#html + 1] = ui_helper.createSwitch(T"Band Steering Enabled", "steering_state", content["steering_state"] == "1" and "1" or "0", bssecclass)
                  html[#html + 1] = ui_helper.createLabel(T"Band Steering State", "steering_state" and content["steering_state"] == "1" and T"Enabled" or T"Disabled", bssecclass)
                  html[#html + 1] = dynamicCreateSlider(T"2.4 GHz Threshold", "rssi_threshold"..bsid, content_rssi["rssi_threshold"..bsid], min_rssi, max_rssi ,step, unit)
                end
              end
            else
              if isBaseIface(curiface) then
                bsid = bandsteer_helper.getBandSteerId(curiface)
                html[#html + 1] = ui_helper.createSwitch(T"Band Steering Enabled", "band_steer_enabled", band_steer_enabled and "1" or "0", bssecclass)
                html[#html + 1] = ui_helper.createLabel(T"Band Steering State", bs_peer_oper_state and bs_peer_oper_state == "1" and T"Enabled" or T"Disabled", bssecclass)
                html[#html + 1] = dynamicCreateSlider(T"2.4 GHz Threshold", "rssi_threshold"..bsid, content_rssi["rssi_threshold"..bsid], min_rssi, max_rssi ,step, unit)
              end
            end
          end
        else
          if band_steer_supported and bandsteerobj then
            local bssecclass = {
              group = {
                class = "bandsteer_support"
              },
              input = {
                class ="monitor-security"..curap.." monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk monitor-wpa2 monitor-none monitor-wpa3 monitor-wpa3-psk monitor-wpa2-wpa3 monitor-wpa2-wpa3-psk",
              },
            }
            if isBaseIface(curiface) then
              html[#html + 1] = ui_helper.createSwitch(T"Band Steering Enabled", "band_steer_enabled", band_steer_enabled and "1" or "0", bssecclass)
            else
              html[#html + 1] = ui_helper.createLabel(T"Band Steering Enabled", band_steer_enabled and "On" or "Off", ssidclass)
            end
            html[#html + 1] = ui_helper.createLabel(T"Band Steering State", bs_peer_oper_state and bs_peer_oper_state == "1" and T"Enabled" or T"Disabled", bssecclass)
          end
        end
      end
  end
  if gettype == "main" or post_helper.getVariantValue(variantHelper, "showGuestWPS") then
    local wep_warning_display = content["security"..curap] and content["security"..curap] == "wep" and "show" or "hide"
    local broadcast_warning_display = content["ap_broadcast_ssid"..curap] and content["ap_broadcast_ssid"..curap] == "0" and wep_warning_display == "hide"  and "show" or "hide"
    local broadcast_warning = {
      alert = {
        class = "alert-warning "..broadcast_warning_display.." broadcast_ssid_warning"..curap
      }
    }
    local wep_warning = {
      alert = {
        class = "alert-warning "..wep_warning_display.." wep_warning"..curap
      }
    }
    html[#html + 1] = ui_helper.createAlertBlock(T"WPS is automatically disabled if you choose to disable broadcast of the SSID", broadcast_warning)
    html[#html + 1] = ui_helper.createAlertBlock(T"WPS is automatically disabled if you choose WEP or disable broadcast of the SSID", wep_warning)
  end

  if post_helper.getVariantValue(variantHelper, "enableWPS") and (gettype == "main" or post_helper.getVariantValue(variantHelper, "showGuestWPS")) then
    local broadcast_warning_on_display = content["ap_broadcast_ssid"..curap] and content["ap_broadcast_ssid"..curap] == "1" and "show" or "hide"
    local broadcast_warning_on = {
      alert = {
        class = "alert-warning "..broadcast_warning_on_display.." broadcast_ssid_warning_on"..curap
      }
    }
    html[#html + 1] = ui_helper.createAlertBlock(T"WPS is automatically enabled if you choose to enable broadcast of the SSID", broadcast_warning_on)
  end

  radius_state = "radius_authent_state"..curap
  radius_acc_state = "radius_account_state"..curap  ngx.print('\
  <input type="hidden" name="');  ngx.print( radius_state ); ngx.print('" value="" >\
  <input type="hidden" name="');  ngx.print( radius_acc_state ); ngx.print('" value="" >\
  ');  
  html[#html + 1] = [[</fieldset>]]
  return html
end

if ngx.req.get_method() == "GET" and ngx.req.get_uri_args().action == "split_ssid" then
  gettype = session:retrieve("networktype") or "main"
  interface_list, ap_list = {}, {}
  interface_list, split_ssid, bsid, bandsteer_state = generateInterfaceList(gettype)
  aplists, ap_list, intf_check, radio_list = generateAPList(interface_list)
  local split_ssid = ngx.req.get_uri_args().splitssid
  mergeAP, curaplist, ap_list, interface_list = mergedAPDetails(split_ssid, bandsteer_state, ap_list)

   if split_ssid == "0" and not multiap_enabled and post_helper.getVariantValue(variantHelper, "preserveBandsteer") then
     if gettype == "main" or post_helper.getVariantValue(variantHelper, "guestBandsteer") then
       band_steer_enabled = proxy.get("uci.system.wifi-bandsteer.@"..untaint(content["bsid"])..".bandsteer_last_state") and proxy.get("uci.system.wifi-bandsteer.@"..untaint(content["bsid"])..".bandsteer_last_state")[1].value or band_steer_enabled
       content["bs_state"] = band_steer_enabled
       band_steer_enabled = band_steer_enabled == "1" and true or false
     end
   end

  if split_ssid == "0" and smartWifiStatus == "1" and gettype ~= "guest" then
    content["ssid"..untaint(credential_instance_list[1])] = content["ssid"..untaint(credential_instance_list[2])]
    content["password"..untaint(credential_instance_list[1])] = content["password"..untaint(credential_instance_list[2])]
    content["security"..untaint(credential_instance_list[1])] = content["security"..untaint(credential_instance_list[2])]
  end

  --smartWifiStatus will be "" for all customers except Telia
  if split_ssid == "0" and smartWifiStatus == "0" then
    content["ssid" .. untaint(aplists[1])] = content["ssid" .. untaint(aplists[2])]
    --When smartwifi is disabled, the name of security mode is dynamically taken from the selected security mode
    if content["security" .. untaint(aplists[2])] == "wpa2-psk" then
      content["wpa_psk" .. untaint(aplists[1])] = content["wpa_psk" .. untaint(aplists[2])]
    elseif content["security" .. untaint(aplists[2])] == "wpa3-psk" or content["security" .. untaint(aplists[2])] == "wpa2-wpa3-psk" then
      content["wpa3" .. untaint(aplists[1])] = content["wpa3" .. untaint(aplists[2])]
    end
    content["security" .. untaint(aplists[1])] = content["security" .. untaint(aplists[2])]
    content["acl_mode" .. untaint(aplists[1])] = content["acl_mode" .. untaint(aplists[2])]
  end

  if split_ssid == "1" then
    local suffix = proxy.get("uci.env.var.commonssid_suffix") and proxy.get("uci.env.var.commonssid_suffix")[1].value or ""
    if suffix and suffix ~= "" then
      local ssidVal
      if multiap_enabled and not guestMultiap then
        ssidVal = proxy.get("uci.multiap.controller_credentials.@"..untaint(credential_list[2])..".ssid") and proxy.get("uci.multiap.controller_credentials.@"..untaint(credential_list[2])..".ssid")[1].value or ""
      else
        ssidVal = interface_list[2] and proxy.get(format("rpc.wireless.ssid.@%s.ssid", interface_list[2])) and proxy.get(format("rpc.wireless.ssid.@%s.ssid", interface_list[2]))[1].value or ""
      end
      if not string.match(ssidVal, suffix) and ssidVal then
        ssidVal = ssidVal..suffix
      end

      if multiap_enabled and not guestMultiap then
        content["ssid"..untaint(credential_list[2])] = ssidVal
      else
        content["ssid"..untaint(ap_list[2])] = ssidVal
      end
    end
  end
  if not multiap_enabled or gettype ~= "guest" then
    if smartWifiStatus ~= "1" then
      content["security" .. untaint(aplists[2])] = content["security" .. untaint(aplists[1])]
      content["wpa_psk" .. untaint(aplists[2])] = content["wpa_psk" .. untaint(aplists[1])]
      content["wep_key" .. untaint(aplists[2])] = content["wep_key" .. untaint(aplists[1])]
      content["acl_mode" .. untaint(aplists[2])] = content["acl_mode" .. untaint(aplists[1])]
      content["ap_enabled" .. untaint(aplists[2])] = content["ap_enabled" .. untaint(aplists[1])]
      content["ap_broadcast_ssid" .. untaint(aplists[2])] = content["ap_broadcast_ssid" .. untaint(aplists[1])]
      content["wpa3" .. untaint(aplists[2])] = content["wpa3" .. untaint(aplists[1])]
    end
  end
  if (multiap_enabled and not guestMultiap) or smartWifiStatus == "1" then
    for indexVal, curap in ipairs(ap_list) do
      if indexVal == 2 then
        content["split_ssid"] = split_ssid
      end
      ngx.print(loadMultiAPDetails(content, indexVal, curap, split_ssid))
      ngx.print(loadQRCode(content, curiface, curap))
    end
  else
    for index_val, curap in ipairs(ap_list) do
      ngx.print(loadAPDetails(content, curap, split_ssid, intf_check))
      ngx.print(aclPageLoad(content, curap, split_ssid))
      ngx.print(loadQRCode(content, curiface, curap))
    end
  end
  ngx.exit(ngx.HTTP_OK)
end

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "bs_check" then
  local postargs = ngx.req.get_post_args()
  local validateStringInlength = getValidateStringLengthInRange(1,32)
  local curap = postargs.apName
  local is_main = (postargs.apName and proxy.get("rpc.wireless.ap.@"..postargs.apName..".ap_isolation")[1].value == "0") and true or false
  if not post_helper.isFeatureEnabled("bandsteerDisabled" , role) then
    if is_main and (content["ssid"..curap] ~= postargs.ssidName or content["security"..curap] ~= postargs.security or content["wpa_psk"..curap] ~= postargs.wpa_psk or content["wpa3"..curap] ~= postargs.wpa3) then
      if validatePSK(postargs.wpa_psk) and validateStringInlength(postargs.ssidName) and validateSSID(postargs.ssidName) and getValidateExtraSpaces(postargs.ssidName) then
        session:store("bs_check_action", true)
        proxy.set("uci.wireless.wifi-bandsteer.@bs0.state","0")
        proxy.apply()
      end
    end
  end
  ngx.exit(ngx.HTTP_OK)
end

local current_acl_mode = {}
for _, curap in ipairs(ap_list) do
  current_acl_mode[curap] = content["acl_mode"..curap]
end
local multiap_bsslist
if multiap_enabled then
  multiap_bsslist = proxy.get("uci.multiap.agent.bss_list")
  multiap_bsslist = multiap_bsslist and multiap_bsslist[1].value or ""
end

ngx.print(ui_helper.createHeader(T"Wireless", true, false))   ngx.print('\
<div class="modal-body update">\
  ');  local lp = require("web.lp")
  if post_helper.getVariantValue(variantHelper, "navTab") then
    lp.setpath("/www/snippets/")
    lp.include("tabs-wireless.lp")
  end   ngx.print('\
  <style>\
  .tooltip-inner {\
    max-width: 100% !important;\
  }\
  .table th {\
    font-weight: normal;\
  }\
  </style>\
  <form class="form-horizontal" method="post" action="');  ngx.print( ngx.var.request_uri ); ngx.print('">\
    ');  if #wls > 1 then   ngx.print('\
      <div class="span2">\
        <ul class="nav nav-list">\
          ');  local html = {}
          local active = ""
          html[#html+1] = format('<li class="nav-header">%s</li>', T"NETWORKS")
          for i, v in ipairs(wls) do
            local active = ""
            if v.type == gettype then
              active = "active"
              session:store("networktype", v.type)
            end
            local url = "modals/wireless-ap-modal-newEM.lp?type=" .. v.type
            v.type = v.type == "main" and "Home" or v.type
            local tabName = v.type
            tabName = tabName:gsub("^%l", upper)
            html[#html+1] = format('<li class="%s"><a  id = "Wireless_Tab_%s" href="#" data-remote="%s">%s</a></li>', active, i, url, tabName)
          end
          ngx.print(html)   ngx.print('\
        </ul>\
      </div>\
    <div class = "span6">\
    ');  else   ngx.print('\
    <div>\
    ');  end   ngx.print('\
      ');  ngx.print(ui_helper.createMessages(message_helper.popMessages()))
         if bandsteerhelpmsg then ngx.print(ui_helper.createMessages(bandsteerhelpmsg)) end

      local splitclass = {
        switch = {
          class = "float-right"
        },
        group = {
          style = "position:relative;top:42px;left:231px;width:20px;"
        }
      }

      local bs_warning = {
          alert = {
            class = "alert-warning hide",
            id = "bandsteer_warning"
          }
        }

      ngx.print(ui_helper.createAlertBlock(T"This action will disable the Band Steering functionality", bs_warning))
      if post_helper.getVariantValue(variantHelper, "showsplitToggle") and not multiap_agent then
        if smartWifiStatus ~= "1" or (smartWifiStatus == "1" and gettype ~= "guest") then
          ngx.print(ui_helper.createSwitch(T"Split", "split_ssid", content["split_ssid"], splitclass))
        end
      end   ngx.print('\
      <div class = "span6" id = "wirelessDivPage" >\
        ');  
          if (multiap_enabled and not guestMultiap) or smartWifiStatus == "1" then
            for indexVal, curap in ipairs(ap_list) do
              credParam = untaint(credential_list[indexVal])
              ngx.print(loadMultiAPDetails(content, indexVal, curap, split_ssid))
              if post_helper.getVariantValue(variantHelper, "multiapBroadCastACL") and credParam then
                ngx.print(aclPageLoad(content, curap, content["split_ssid"]))
              end
              ngx.print(loadQRCode(content, curiface, curap))
            end
          else
            for indexVal, curap in ipairs(ap_list) do
              ngx.print(loadAPDetails(content, curap, content["split_ssid"], intf_check))
              if agentView then
                ngx.print(aclPageLoad(content, curap, content["split_ssid"]))
              end
              ngx.print(loadQRCode(content, curiface, curap))
            end
          end  ngx.print('\
        </div>\
      </div>\
  </form>\
</div>\
');  ngx.print(ui_helper.createFooter())
for k, v in pairs(content) do
  if k ~= "acl_mode" and k ~= "showpassap0" and k ~= "showpassap1" and k ~= "showpasscred0" and k ~= "showpasscred1" and content[k] and content[k] ~= "" then
    content[k] = html_escape(content[k])
  end
end   ngx.print('\
<script>\
  var suffix = "');  ngx.print(suffix); ngx.print('";\
  var gettype = "');  ngx.print(gettype); ngx.print('";\
  var isTableLoaded = ');  ngx.print(json.encode(isTableLoaded)); ngx.print(';\
  var acl_mode = ');  ngx.print(json.encode(content)); ngx.print(';\
  var current_acl_mode = ');  ngx.print(json.encode(current_acl_mode)); ngx.print(';\
  var curap = "');  ngx.print(curaplist); ngx.print('";\
  var curiface = "');  ngx.print(curiface); ngx.print('";\
  var curradio = "');  ngx.print(curradio); ngx.print('";\
  var helpmsg = ');  ngx.print(json.encode(helpmsg)); ngx.print(';\
  var ap_list = ');  ngx.print(json.encode(ap_list)); ngx.print(';\
  var aplists = ');  ngx.print(json.encode(aplists)); ngx.print(';\
  var cred_list = ');  ngx.print(json.encode(credential_list)); ngx.print(';\
  var bandsteerSupport = ');  ngx.print(bandsteerobj and post_helper.getVariantValue(variantHelper, "bandsteerSupport") or false); ngx.print(';\
  var bandsteerDisabled = ');  ngx.print(post_helper.isFeatureEnabled("bandsteerDisabled" , role)); ngx.print(';\
  var ssidCheck = ');  ngx.print(post_helper.getVariantValue(variantHelper, "ssidCheck")); ngx.print(';\
  var passwordStrength = ');  ngx.print(post_helper.getVariantValue(variantHelper, "passwordStrength")); ngx.print(';\
  var showWirelessPassword = ');  ngx.print(post_helper.getVariantValue(variantHelper, "showWirelessPassword")); ngx.print(';\
  var split_ssid = "');  ngx.print(split_ssid); ngx.print('";\
  var multiap_enabled = "');  ngx.print(multiap_enabled); ngx.print('";\
  var bandsteer_state = "');  ngx.print(bandsteer_state); ngx.print('";\
  var securitynone = ');  ngx.print(post_helper.getVariantValue(variantHelper, "securityPopupShow")); ngx.print(';\
  var enableWPS = ');  ngx.print(post_helper.getVariantValue(variantHelper, "enableWPS")); ngx.print(';\
  var confirmationMsg = "');  ngx.print(T"Security for the wireless network will be <br> disabled and anyone will be able to connect <br> or listen, please confirm to continue?"); ngx.print('";\
  var confirmationTitle = "');  ngx.print(T"Security Mode"); ngx.print('";\
  var confirmationContinue = "');  ngx.print(T"Continue"); ngx.print('";\
  function loadACLList(acl_mode, curap) {\
    $.get("/modals/wireless-ap-modal-newEM.lp?action=GET_ACL_MAC_LIST&acl_mode"+curap+"="+acl_mode+"&curap="+curap, function (data){\
      $(\'#acl_list_div\'+curap).replaceWith(data);\
     });\
  }\
  if(split_ssid == "0" && multiap_enabled == "true") {\
    $(".bandsteerSupportedParam").addClass("disabled").attr("disabled", true);\
  }\
  else\
  {\
    $(".bandsteerSupportedParam").removeClass("disabled").removeAttr("disabled", true);\
  }\
</script>\
<script src="/js/wireless-ap-modal-newEM.js"></script>\
<script>\
  for(var ap in ap_list) {\
    var apVal = ap_list[ap];\
    var acl_modeVal = acl_mode["acl_mode"+apVal];\
    loadACLList(acl_modeVal, apVal);\
  }\
</script>\
'); 
