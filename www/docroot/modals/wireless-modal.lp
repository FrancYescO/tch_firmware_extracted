<%
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
local match, format, gsub, next = string.match, string.format, string.gsub, next
local bandsteer_helper = require("bandsteer_helper")
local isBaseIface = bandsteer_helper.isBaseIface
local disableBandSteer = bandsteer_helper.disableBandSteer
local currentuserrole = ngx.ctx.session:getrole()
local telstra_helper = require("telstra_helper")
local symbolv1 = telstra_helper.symbolnamev1
local symbolv2 = telstra_helper.symbolnamev2
-- Shortcuts to validation helpers to make lines shorter
local gVIPIL = post_helper.getValidationIfPropInList
local gVIES = post_helper.getValidateInEnumSelect
local vB = post_helper.validateBoolean
local vNES = post_helper.validateNonEmptyString
local vSII = post_helper.validateStringIsIP()
local vSIP = post_helper.validateStringIsPort
local vSIM = post_helper.validateStringIsMAC
local gOV = post_helper.getOptionalValidation
local gCV = post_helper.getConditionalValidation
local gAV = post_helper.getAndValidation
local vPSK = post_helper.validatePSK
local gVSLIR = post_helper.getValidateStringLengthInRange
local gVChkbox = post_helper.getValidateCheckboxSwitch()
local vWEP = post_helper.validateWEP
local vPIN = post_helper.validateWPSPIN
local vSIPV6 = post_helper.validateStringIsIP(6)
local gRV = post_helper.getOrValidation
local gVSIIP = gRV(vSII,vSIPV6)
local wpa_list = {"wpa2", "wpa-wpa2"}
local VIPIL_IP = gVIPIL(gVSIIP, "security", wpa_list)
local VIPIL_port = gVIPIL(vSIP, "security", wpa_list)
local vQTN = post_helper.validateQTN
local is11nStdSelected, is11nStdSelected_5G = false
-- Take the input options for a listbox, the value and return the associated text
local listboxToText = function(options, value)
    for i,v in ipairs(options) do
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

local curradio = "radio_2G"
local curiface = "wl0"
local curap = "ap0"
local isguest = "0"
local isExtRemman = "0" -- AP remotely managed, like a TG233 DANT-5 board in AP mode.
local radio2iface = {}
local stbLimit = false

-- Return the acs data for selected radio to generate Analyzer graph
local function getAcsData(cradio, delay)
  local json = require("dkjson")
  local bsslistData = proxy.get("rpc.wireless.bssid.@" .. cradio .. ".bsslist.")
  --Timeout of 30 secs Delay is introduced to get values from bsslistData when the rescan button is clicked
  if delay then
    local step = 0
    while step <= 10 do
      bsslistData = proxy.get("rpc.wireless.bssid.@" .. cradio .. ".bsslist.")
      if next(bsslistData) then
        break
      end
      ngx.sleep(3)
      step = step + 1
    end
  end
  bsslistData = content_helper.convertResultToObject("rpc.wireless.bssid.@" .. cradio .. ".bsslist.",bsslistData)
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
   getAcsData(cradio, true)
elseif getWifiAnalyzer and getargs.getAcsData then
   getAcsData(getradio)
end

local radios = {}
for i,v in ipairs(proxy.getPN("rpc.wireless.radio.", true)) do
    local radio = match(v.path, "rpc%.wireless%.radio%.@([^%.]+)%.")
    if radio then
        radios[#radios+1] = radio
        if radio == getradio then
            curradio = radio
        end
    end
end
table.sort(radios)

ajax_helper.handleAjaxQuery({
    phy_rate = "rpc.wireless.radio.@" .. curradio .. ".phy_rate",
    channel = "rpc.wireless.radio.@" .. curradio .. ".channel",
    }, function(content)
        content["phy_rate"] = content["phy_rate"] / 1000 .. "Mbps"
    end)

-- fbt add
local fonpath = "uci.hotspotd.wifi-iface."
local fonifaces = content_helper.convertResultToObject(fonpath .. "@.", proxy.get(fonpath))

local ssidMap = {}
for i,v in ipairs(fonifaces) do
    local iface = format("%s", v.iface)
    ssidMap[iface] = true
end

local piface = "uci.wireless.wifi-iface."
local awls = content_helper.convertResultToObject(piface .. "@.", proxy.get(piface))
local wls = {}
for i,v in ipairs(awls) do
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
local bspeerap = nil

local pap = "uci.wireless.wifi-ap."
local aap = content_helper.convertResultToObject(pap .. "@.", proxy.get(pap))
for i,v in ipairs(aap) do
    if v.iface == curiface then
        curap = v.paramindex
        isguest = v.ap_isolation
    end

    if bandsteeriface and v.iface == bandsteeriface then
        bspeerap = v.paramindex
    end
end
-- fbt end

local bsid = bandsteer_helper.getBandSteerId(curiface)
local pbsidstate = 'uci.wireless.wifi-bandsteer.@' .. bsid .. '.state'

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SAVE" then
  local postargs = ngx.req.get_post_args()
  local success = false
  if "wpa-psk" == postargs.security or "wpa2-psk" == postargs.security or "wpa-wpa2-psk" == postargs.security then
      success = proxy.set("rpc.wireless.ap.@" .. curap  .. ".security.wpa_psk_passphrase", postargs.wpa_psk)
      success = proxy.set("uci.wireless.wifi-ap-credential.@" .. curap .. "_credential0.passphrase", postargs.wpa_psk)
  elseif "wpa3" == postargs.security or "wpa3-psk" == postargs.security or "wpa2-wpa3-psk" == postargs.security or "wpa2-wpa3" == postargs.security then
      success = proxy.set("rpc.wireless.ap.@" .. curap  .. ".security.wpa_psk_passphrase", postargs.wpa3)
      success = proxy.set("uci.wireless.wifi-ap-credential.@" .. curap .. "_credential0.passphrase", postargs.wpa3)
  end

  if success then
    proxy.apply()
  end
end


if ngx.req.get_method() == "POST"  and  ngx.req.get_post_args().action == "set_reg" then
    local content_acl ={
       state = "rpc.wireless.ap.@"..curap..".acl.state"
    }
    content_helper.getExactContent(content_acl)
    local acl_ap = ngx.req.get_post_args().curap
    local content_acl_state = format('%s',content_acl["state"])
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
    local reg_status = proxy.get("rpc.wireless.ap.@"..acl_ap..".acl.state")[1].value
    ngx.print(reg_status)
    ngx.exit(ngx.HTTP_OK)
end

-- The function can be reused to load the ACL mac list by ajax and normal request
-- Normal request means - Adding, Editing and Deleting the ACL mac address entries by normal POST request
local function loadAclList(aclmode, action)
  local acl_columns = {
   {
    header = T"MAC Address",
    name = "acl_macaddress",
    param = "value",
    type = "text",
    attr = { input = { class = "span2", maxlength = "17" } },
   }
  }
  local function validateAclMac(value,object,key)
    local retval, errmsg = vSIM(value,object,key)
    if not retval then
       return retval, errmsg
    end
    local path = "uci.wireless.wifi-ap.@" .. curap
    local macdata = proxy.get(path .. ".acl_accept_list.", path .. ".acl_deny_list.")

    if post_helper.valueInList(macdata, value, post_helper.compareMACAddresses) then
       return nil, T"Mac address duplicate with either current whitelist or current blacklist"
    end
    return true
  end
  local macvalid = {
    acl_macaddress = gAV(validateAclMac,vQTN)
  }
  local acl_whitelist_options = {
    tableid = "acl_whitelist",
    basepath = format("uci.wireless.wifi-ap.@%s.acl_accept_list.@.",curap),
    createMsg = T"Add new MAC address",
  }
  if aclmode == "register" then
    acl_whitelist_options["tableid"] = "acl_register"
  end
  local acl_whitelist_data, acl_whitelist_helpmsg = post_helper.handleTableQuery(acl_columns, acl_whitelist_options, nil, nil, macvalid)
  local acl_blacklist_options = {
    tableid = "acl_blacklist",
    basepath = format("uci.wireless.wifi-ap.@%s.acl_deny_list.@.",curap),
    createMsg = T"Add new MAC address",
  }
  local acl_blacklist_data, acl_blacklist_helpmsg = post_helper.handleTableQuery(acl_columns, acl_blacklist_options, nil, nil, macvalid)

  local html={}
  local whitelistclass = {
    group = {
      class = "monitor-acl_mode monitor-lock monitor-register",
    }
  }
  if aclmode == "unlock" or aclmode == "disabled" then
    whitelistclass["group"].style = "display:none;"
  end
  if #acl_whitelist_data < 1 and action ~= "POST" then
        whitelistclass ["span"] = {id = "Address_list_Whitelistclass"}
        html[#html+1] = ui_helper.createLabel("", T"MAC Address list is empty", whitelistclass, nil)
        acl_columns[1].header=""
  end
  html[#html+1] = ui_helper.createTable(acl_columns, acl_whitelist_data, acl_whitelist_options, whitelistclass, acl_whitelist_helpmsg)

  local blacklistclass = {
    group = {
      class = "monitor-acl_mode monitor-unlock"
    }
  }
  if aclmode == "lock" or aclmode == "register" or aclmode == "disabled" then
    blacklistclass["group"].style = "display:none;"
  end
  if #acl_blacklist_data < 1 and  action ~= "POST" then
       blacklistclass ["span"] = {id = "Address_list_Blacklistclass"}
       html[#html+1] =  ui_helper.createLabel("", T"MAC Address list is empty", blacklistclass, nil)
       acl_columns[1].header=""
  else
    acl_columns[1].header = format("<span style=\"font-weight:normal;\">%s</span>", T"MAC Address")
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
for i,v in ipairs(radios) do
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
        path .. ".requested_channel_width")
  if rdata ~= nil then
    radioData[v] = {
      supported_frequency_bands=rdata[1].value,
      remotely_managed=rdata[2].value,
      supported_standards=rdata[3].value,
      integrated_ap=rdata[4].value,
      phy_rate = rdata[5].value,
      country = rdata[6].value,
      channel = rdata[7].value,
      standard = rdata[8].value,
      requested_channel = rdata[9].value,
      requested_channel_width = rdata[10].value,
    }
  end
end

if radioData[curradio].remotely_managed == "1" and radioData[curradio].integrated_ap ~= "1" then
    isExtRemman = "1"
end

-- We're defining the listbox enums here to be able to use them to validate the input
-- Listbox that shows the supported WiFi standards
local wifi_standard_24GHz = {
      { "bg", T'802.11b/g'},
      { "bgn", T'802.11b/g/n'},
}

local wifi_standard_5GHz = {
    ["an"]= T'802.11a/n',
    ["anac"]= T'802.11a/n/ac',
}

local wifiStandard = {
  standard = "uci.wireless.wifi-device.@radio_5G.standard"
}

local wifi_standard={}
if radioData[curradio].supported_frequency_bands == "5GHz" then
  content_helper.getExactContent(wifiStandard)
  if wifiStandard.standard and wifiStandard.standard ~= "" then
    wifi_standard[1] = {wifiStandard.standard,wifi_standard_5GHz[untaint(wifiStandard.standard)]}
  else
    wifi_standard[1] = {"",""}
  end
else
    wifi_standard = wifi_standard_24GHz
end

local bandsteer_rssi_threshold = {
    {"-10", T"10%"},
    {"-20", T"20%"},
    {"-30", T"30%"},
    {"-40", T"40%"},
    {"-50", T"50%"},
    {"-60", T"60%"},
    {"-70", T"70%"},
    {"-80", T"80%"},
    {"-90", T"90%"},
}
-- Choose Wifi power
local wifipower = {
    {"-6", T"25%"},
    {"-3", T"50%"},
    {"-2", T"75%"},
    {"0", T"100%"},
}

local cw_20 = {
    {"20MHz", T"20MHz"},
}
local cw_40 = {
    {"20MHz", T"20MHz"},
    {"auto", T"Auto (20/40MHz)"},
}
local cw_80 = {
    {"20MHz", T"20MHz"},
    {"20/40MHz", T"20/40MHz"},
    {"auto", T"Auto (20/40/80MHz)"},
}

local cw = {
  ["bg"] = "channelwidth20",
  ["bgn"] = "channelwidth40",
  ["an"] = "channelwidth40",
  ["anac"] = "channelwidth80",
}

local cwmaps = {
    ["channelwidth20"] = cw_20,
    ["channelwidth40"] = cw_40,
    ["channelwidth80"] = cw_80,
}
-- Define different Channel Width contain different Channel
local list5g20 = {
    {"auto", T"Auto"},
    {"36", T"36"},
    {"40", T"40"},
    {"44", T"44"},
    {"48", T"48"},
    {"52", T"52(DFS)"},
    {"56", T"56(DFS)"},
    {"60", T"60(DFS)"},
    {"64", T"64(DFS)"},
    {"100", T"100(DFS)"},
    {"104", T"104(DFS)"},
    {"108", T"108(DFS)"},
    {"112", T"112(DFS)"},
    {"116", T"116(DFS)"},
    {"132", T"132(DFS)"},
    {"136", T"136(DFS)"},
    {"149", T"149"},
    {"153", T"153"},
    {"157", T"157"},
    {"161", T"161"},
}

local list5g40 = {
    {"auto", T"Auto"},
    {"36", T"36"},
    {"44", T"44"},
    {"52", T"52(DFS)"},
    {"60", T"60(DFS)"},
    {"100", T"100(DFS)"},
    {"108", T"108(DFS)"},
    {"132", T"132(DFS)"},
    {"149", T"149"},
    {"157", T"157"},
}

local list5gAuto = {
    {"auto", T"Auto"},
    {"36", T"36"},
    {"52", T"52(DFS)"},
    {"100", T"100(DFS)"},
    {"132", T"132(DFS)"},
    {"149", T"149"},
}

local bandLockState = proxy.get("uci.multiap.bandlock.active")
bandLockState = bandLockState and bandLockState[1].value or ""
local bandLockChannel = proxy.get("uci.wireless.wifi-device.@radio_5G.acs_allowed_channels")
bandLockChannel = bandLockChannel and untaint(bandLockChannel[1].value) or ""
local dfsChannels = {
   ["100"] = true,
   ["104"] = true,
   ["108"] = true,
   ["112"] = true,
   ["132"] = true,
   ["136"] = true,
}

local bandLockChannelVal = {{"auto", T"Auto"}}
for channelVal in string.gmatch(bandLockChannel, "[^%s]+") do
  bandLockChannelVal[#bandLockChannelVal + 1] = dfsChannels[channelVal] and {channelVal,channelVal.."(DFS)"}  or { channelVal, channelVal }
end
if bandLockState ~= "1" then
  list5g = setmetatable({
      ["20MHz"] = list5g20,
      ["20/40MHz"] = list5g40,
      ["auto"] = list5gAuto,
  }, untaint_mt)
else
  list5g = setmetatable({
      ["20MHz"] = bandLockChannelVal,
      ["20/40MHz"] = bandLockChannelVal,
      ["auto"] = bandLockChannelVal,
  }, untaint_mt)
end

local cddList = {
  {"1", T"Auto"},
  {"on", T"On"},
  {"off", T"Off"}
}

pmfList = {
  {"enabled", T"Enabled"},
  {"disabled", T"Disabled"},
}

local channelwidth = cwmaps[cw[untaint(radioData[curradio].supported_standards)]]

local supported_modes_data  = proxy.get("rpc.wireless.ap.@" .. curap .. ".security.supported_modes")
local supported_modes = format("%s", supported_modes_data and supported_modes_data[1] and supported_modes_data[1].value or "")
local secmodes = {}
local secmodes_matched = {
     ["none"] = T"None",
     ["wpa2-psk"] = T"WPA2 PSK",
     ["wpa-wpa2-psk"] =  T"WPA+WPA2 PSK",
     ["wpa-wpa2"] =  T"WPA+WPA2",
}
supported_modes:gsub("[^%s]+", function(c)
  if c ~= "wep" then
    if secmodes_matched[c] then
        secmodes[#secmodes+1] = { c, secmodes_matched[c] }
    else
        secmodes[#secmodes+1] = { c, T(string.upper(c)) }
    end
  end
end)

-- remove radius modes if in guest ap page or no radio server
local pathradius = format("uci.wireless.wifi-radius-server.@%s_", curap)
local isRadiusIncluded = false
if proxy.get(pathradius .. "auth0.") then
    isRadiusIncluded = true
end
if isguest == "1" or not isRadiusIncluded then
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
      { "lock", T"Whitelist" },
 }

 if radioData[curradio].remotely_managed ~= "1" then
    acl_modes[#acl_modes+1] = {"register", T"Register"}

 end

local function getValidateChannelWidth(channelWidth)
  return function(value, postdata, key)
    local success, msg = gVIES(channelWidth)
    if success then
      postdata["requested_channel_width"] = postdata[cw[untaint(postdata["standard"])]]
      return true
    else
      return nil, msg
    end
  end
end

--toggle the input as wps_ap_setup_locked = 1 means wps pin method is disabled
local function vApPinEnabled (value, postdata, key)
  local err,msg = gVChkbox(value, postdata, key)
  if not err then
    return err,msg
  end

  postdata[key] = tostring(1-postdata[key])
  return true
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

local piface = "uci.wireless.wifi-iface."
local pathradio = format("rpc.wireless.radio.@%s.", curradio)
local pathiface = format("rpc.wireless.ssid.@%s.", curiface)
local pathap = format("rpc.wireless.ap.@%s.", curap)
local pathapWpa3 = format("uci.wireless.wifi-ap-credential.@%s_", curap)
local pathradius = format("uci.wireless.wifi-radius-server.@%s_", curap)
local pap = "uci.wireless.wifi-ap."
local radius_account = proxy.get(pathradius .. "acct0.")
local radius_authent = proxy.get(pathradius .. "auth0.")
-- If this AP connects to STB, "engineer" role has full access, other roles only have simple stats
if proxy.get(pathiface .. "stb")[1].value == "1" then
    if ngx.ctx.session:getrole() ~= "guest" then
        stbLimit = true
    end
end

local bandsteerpathap = bspeerap and format("rpc.wireless.ap.@" .. "%s.", bspeerap) or ""

local multiap_state = {
    agent = "uci.multiap.agent.enabled",
    controller = "uci.multiap.controller.enabled",
}
content_helper.getExactContent(multiap_state)
local multiap_enabled = multiap_state.agent == "1" and multiap_state.controller == "1"

local function getValidateBandSteerPeerFields(value, object, key)
    if "wpa-psk" == object.security or "wpa2-psk" == object.security or "wpa-wpa2-psk" == object.security then
        object.wpa3 = object.wpa_psk
    elseif "wpa3" == object.security or "wpa3-psk" == object.security or "wpa2-wpa3-psk" == object.security or "wpa2-wpa3" == object.security then
        object.wpa_psk = object.wpa3
    end
    if object.multiap_security then
        object.multiap_security = object.security
        object.multiap_wpa_psk = object.wpa_psk
        object.multiap_ssid = object.ssid
    end
    if not object.band_steer_enabled then
        return true
    end
    if "1" == object.band_steer_enabled then
        if object.bsid ~= "" and (((not multiap_enabled or isguest == '1' ) and object.bsid ~= "off" and object.bsid_state == "1") or (multiap_enabled and object.multiap_cred_secondary_state == "0")) then
            if object.security == "wep" then
                return nil, T"The Band Steering can not be supported under WEP security mode."
            end

            if isBaseIface(curiface) then
                if object.bspeer_security then
                    object.bspeer_security = object.security
                    object.bspeer_wpa_psk = object.wpa_psk
                    object.bspifacessid = object.ssid
                    object.bspeer_passphrase = object.wpa3
                    object.bs_state = object.band_steer_enabled
                end
                if object.multiap_bspeer_security then
                    object.multiap_bspeer_security = object.security
                    object.multiap_bspeer_wpa_psk = object.wpa_psk
                    object.multiap_bspifacessid = object.ssid
                end
            end
            return true
        else
            --to check wether the bs obj exist or not
            local bsid_state = proxy.get(pbsidstate)
            if not bsid_state then
                return nil, T"Please configure wifi-bandsteer " .. bsid .. " first!"
            else
                if object.security == "wep" then
                    return nil, T"The Band Steering can not be supported under WEP security mode."
                end

                if isBaseIface(curiface) then
                    object.bsid = bsid
                    object.bspeerid = bsid
                    if (not multiap_enabled) or isguest == '1' then
                        object.bsid_state = '1'
                    else
                        object.bsid_state = '0'
                        object.bsid = "off"
                        object.bspeerid = "off"
                    end

                    if object.bspeer_security then
                        object.bspeer_security = object.security
                        object.bspeer_wpa_psk = object.wpa_psk
                        object.bspifacessid = object.ssid
                        object.bspeer_passphrase = object.wpa3
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
            object.multiap_cred_primary_bands = "radio_2G,radio_5Gl"
            object.multiap_cred_secondary_state = "0"
        end
    else --to disable bandsteer
        return disableBandSteer(object, multiap_enabled, isguest)
    end

    return true
end

local multiap_cred_secondary_path
local bandsteerpath = "uci.wireless.wifi-bandsteer."
local bandsteers = content_helper.convertResultToObject(bandsteerpath .. "@.", proxy.get(bandsteerpath))
table.sort(bandsteers, function(a,b)
    return a.paramindex < b.paramindex
end)

local bandsteerindex = "0"
if not bandsteers or 0 == #bandsteers then
    bandsteerindex = "0"
else
    bandsteerindex = bandsteers[#bandsteers].paramindex
end

local param = {
    allowed_channels = pathradio .. "allowed_channels"
}
content_helper.getExactContent(param)
local allowed_channels = { {"auto", T"Auto"} }
for i in string.gmatch(param["allowed_channels"], "%S+") do
    allowed_channels[#allowed_channels + 1] = {i, i}
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
    if (isguest ~= "1" and is11nStdSelected) or (isguest ~= "1" and is11nStdSelected_5G) then
      mapRadiusParams.sgi = pathradio .. "sgi"
      mapRadiusParams.cdd = pathradio .. "cdd"
      mapRadiusParams.stbc = pathradio .. "stbc"
    end
  end

  local mapRadiusValid = {
    radius_authent_ip = validateIfProp_IP,
    radius_account_ip = gOV(validateIfProp_IP),
    radius_authent_secret = gVIPIL(vNES, "security", wpa_list),
    radius_account_secret = gVIPIL(vNES, "security", wpa_list),
    radius_authent_port = validateIfProp_port,
    radius_account_port = gOV(validateIfProp_port),
    radius_authent_state = gCV(radiusCond, getReplaceValue("1"), getReplaceValue("0")), -- we know that we're enforcing the server ip and port is there
    radius_account_state = gCV(gAV(radiusCond, checkIPandPort), getReplaceValue("1"), getReplaceValue("0")), -- if no server ip or port, don't set to 1
    sgi = gOV(vB),
    cdd = function(val, object)
      if object.cdd == "auto" then
        object.cdd = "1"
      end
      return gVIES(cddList)
    end,
    stbc = gOV(vB)
  }
  return mapRadiusParams, mapRadiusValid
end

  -- rpc parameters list
  local mapParams = {
    ap_enabled = pathap .. "admin_state",
    ssid = pathiface .. "ssid",
    ap_broadcast_ssid = pathap .. "public",
    security = pathap .. "security.mode",
    wep_key = pathap .. "security.wep_key",
    wpa_psk = pathap .. "security.wpa_psk_passphrase",
    acl_mode = pathap .. "acl.mode",
    wps_button_handler = wpshandler_data and "uci.button.button.@wps.handler",
    standard = pathradio .. "standard",
    requested_channel = pathradio .. "requested_channel",
    requested_channel_width = pathradio .. "requested_channel_width",
    outputpower = pathradio .. "tx_power_adjust",
    }

if proxy.get(pathapWpa3 .. "credential0.passphrase") then
  mapParams.wpa3 = pathapWpa3 .. "credential0.passphrase"
end


local wps_button_handler = setmetatable({
      ["1"] = "wps_button_pressed.sh",
      ["0"] = "acl_button_pressed.sh",
}, untaint_mt)
-- Constructing the rpc parameters and validations for post handleQuery
function getParamsAndValidation()
  if isguest ~= "1" then
        mapParams.admin_state = pathradio .. "admin_state"
        mapParams.standard = pathradio .. "standard"
        mapParams.requested_channel = pathradio .. "requested_channel"
        mapParams.requested_channel_width = pathradio .. "requested_channel_width"
        mapParams.wps_enabled = pathap .. "wps.admin_state"
        mapParams.wps_pin_enabled = pathap .. "wps.ap_setup_locked"
        mapParams.frame_bursting = pathradio .. "frame_bursting"
  -- Bug fix for NG-12032 GUI wireless enable/disable not working properly
    for k, v in pairs(radios) do
      if v~=curradio then
        mapParams["admin_state_" .. v] = "rpc.wireless.radio.@" .. v .. ".admin_state"
      end
    end
  end

  if bspeerap then
    local bandsteerParams = {
      bsid = pap .. "@" .. curap .. ".bandsteer_id",
      bspeerid = pap .. "@" .. bspeerap .. ".bandsteer_id",
      bsid_state = pbsidstate,  }

    if isBaseIface(curiface) then
      if bandsteeriface then
        local bandsteerAddParams = {
          bspifacessid = piface .. "@" .. bandsteeriface .. ".ssid",
          bspeer_security = pap .. "@" .. bspeerap .. ".security_mode",
          bspeer_wpa_psk = pap .. "@" .. bspeerap .. ".wpa_psk_key", }
        local pathpeerapWpa3= format("uci.wireless.wifi-ap-credential.@%s_", bspeerap)
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
  if isguest ~= "1" then
    local multiap_cred_path = "uci.multiap.controller_credentials."
    local multiap_cred_data = content_helper.convertResultToObject(multiap_cred_path .. "@.", proxy.get(multiap_cred_path))
    local multiap_cred = {}
    for i,v in ipairs(multiap_cred_data) do
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

    local _, bandsteer_enabled = bandsteer_helper.getBandSteerState(bspeerap, curap, multiap_enabled and multiap_cred_secondary_path, bsid)
    local multiap_prefix = "multiap_"
    if multiap_enabled then
      multiap_prefix = ""
    end

    if not isBaseIface(curiface) and not bandsteer_enabled and multiap_cred_secondary_path then
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
  mapParams["pmf"] = pap .. "@" .. curap .. ".pmf"

  local mapValid = {
    interface_enabled = vB,
    standard = gVIES(wifi_standard),
    sgi = gOV(vB),
    cdd = gVIES(cddList),
    stbc = gOV(vB),
    outputpower = gVIES(wifipower), -- if the parameter is not included, it does not matter, this validation function will never be called
    channelwidth20 = getValidateChannelWidth(cw_20),
    channelwidth40 = getValidateChannelWidth(cw_40),
    channelwidth80 = getValidateChannelWidth(cw_80),
    ap_enabled = vB,
    security = gVIES(secmodes),
    ssid = gAV(gVSLIR(1,32),getValidateExtraSpaces),
    wep_key = gVIPIL(vWEP,"security", {"wep"}),
    wpa_psk = gVIPIL(vPSK,"security", {"wpa-psk", "wpa2-psk", "wpa-wpa2-psk"}),
    wps_enabled = gOV(vB),
    wps_pin_enabled = vApPinEnabled,
    acl_mode = gVIES(acl_modes),
    wpa3 = gVIPIL(vPSK,"security", {"wpa3", "wpa3-psk", "wpa2-wpa3", "wpa2-wpa3-psk"}),
    radius_authent_ip = VIPIL_IP,
    radius_account_ip = gOV(VIPIL_IP),
    radius_authent_secret = gVIPIL(vNES,"security", wpa_list),
    radius_account_secret = gVIPIL(vNES,"security", wpa_list),
    radius_authent_port = VIPIL_port,
    radius_account_port = gOV(VIPIL_port),
    radius_authent_state = gCV(radiusCond, getReplaceValue("1"), getReplaceValue("0")), -- we know that we're enforcing the server ip and port is there
    radius_account_state = gCV(gAV(radiusCond, checkIPandPort), getReplaceValue("1"), getReplaceValue("0")), -- if no server ip or port, don't set to 1
    wps_button_handler = function(val, object)
      object.wps_button_handler = wps_button_handler[object.wps_enabled]
     return true
    end,
    bsid = getValidateBandSteerPeerFields,
    bsid_state = function(val, object)
      return true
    end,
    frame_bursting = vB,
    ap_broadcast_ssid = vB,
    requested_channel = gVIES(allowed_channels),
    admin_state = vB,
    rssi_threshold = gVIES(bandsteer_rssi_threshold),
    rssi_5g_threshold = gVIES(bandsteer_rssi_threshold),
    pmf = gVIES(pmfList)
  }

  if multiap_enabled then
      mapParams.ssid_uci = pathiface .. "ssid"
      mapValid.ssid_uci = gAV(gVSLIR(1,32),getValidateExtraSpaces)
      if curiface == "wl1" then
        mapParams.bspifacessid_uci = "uci.wireless.wifi-iface.@wl1.ssid"
        mapValid.bspifacessid_uci = gAV(gVSLIR(1,32),getValidateExtraSpaces)
      end
  end

   -- Bug fix for NG-12032 GUI wireless enable/disable not working properly
  for k, v in pairs(radios) do
    if v~=curradio then
      mapValid["admin_state_" .. v] = getInterfaceEnabled2
    end
  end

  return mapParams, mapValid
end

local bandsteerhelpmsg = {}
local content_rssi = {}
mapRadiusParams, mapRadiusValid = getParamsAndValidationForRadius()
local mapParams, mapValid = getParamsAndValidation()
for k,v in pairs(mapRadiusParams) do
  mapParams[k] = v
end
for k,v in pairs(mapRadiusValid) do
  mapValid[k] = v
end

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

-- Process POST query
if ngx.req.get_method() == "POST" then
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

  if content["action"] == "SAVE" then
    local retval = false
    local postargs = ngx.req.get_post_args()

    if multiap_cred_secondary_path then
      local fronthaul = proxy.get(multiap_cred_secondary_path .. ".fronthaul")[1].value
      if multiap_enabled and postargs["band_steer_enabled"] == "0" and content["multiap_cred_secondary_state"] == "1" and fronthaul == "1" then
        retval = proxy.set(multiap_cred_secondary_path .. ".frequency_bands", "radio_5Gl")
      end
    end

    if postargs["rssi_threshold"] ~= nil then
      retval = proxy.set(format('%s@%s.rssi_threshold', bandsteerpath, content["bsid"]), format("%d", postargs["rssi_threshold"]))
    end
    if postargs["rssi_5g_threshold"] ~= nil then
      retval = proxy.set(format('%s@%s.rssi_5g_threshold', bandsteerpath, content["bsid"]), format("%d", postargs["rssi_5g_threshold"]))
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
      for _,v in ipairs(wls) do
        if v.iface == curiface then
          v.ssid = content["ssid"]
        end
        if v.iface == bandsteeriface and content["bspifacessid"] then
          if multiap_enabled and curiface == "wl0" then
            proxy.set("uci.wireless.wifi-iface.@wl1.ssid", content["bspifacessid"])
            proxy.apply()
          end
        end
      end
    end
    local args = ngx.req.get_post_args()
    local action = args["action"]
    local pin = args["wps_device_pin_code"]
    if action == "wps_device_pin_code" and content["wps_enabled"] == "1" and isguest ~= 0 then
        local res, help = vPIN(pin)
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
        proxy.set("rpc.wireless.wps_button","1")
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
         pathap .. "wps.ap_pin"
  }
  local step = 2
  for i=0, 60, step do
     ngx.sleep(step)
     local content_val = proxy.get(unpack(content_ssid))
     if (content_val and #content_val > 0) then
        content["macaddress"] = content_val[1].value
        content["stb"] = content_val[2].value
        content["ap_display_name"] = content_val[3].value
        content["wps_ap_pin_code"] = content_val[4].value
        break
     end
  end

param = {
    allowed_channels = pathradio .. "allowed_channels"
}
content_helper.getExactContent(param)
allowed_channels = { {"auto", T"Auto"} }
for i in string.gmatch(param["allowed_channels"], "%S+") do
    allowed_channels[#allowed_channels + 1] = {i, i}
end
for k,v in pairs(radioData[curradio]) do
    -- Not replace the value that already exists
    if not content[k] then
        content[k] = v
    end
end

-- Ensure Channel and Current channel are the same value after clicking Save
if content["requested_channel"] ~= nil and content["channel"] ~= nil and content["requested_channel"] ~= "auto" then
    content["channel"] = content["requested_channel"]
end

local band_steer_supported
local band_steer_enabled

if "" ~= bandsteerpathap then
    --Need to consider the constraint
    band_steer_supported, band_steer_enabled = bandsteer_helper.getBandSteerState(bspeerap, curap, multiap_enabled and multiap_cred_secondary_path, bsid)

    if band_steer_supported then
        content_rssi = {
            rssi_threshold = bandsteerpath .. "@" .. bsid .. ".rssi_threshold",
            rssi_5g_threshold = bandsteerpath .. "@" .. bsid .. ".rssi_5g_threshold"
       }
    end
    content_helper.getExactContent(content_rssi)
end

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. format("%s", uri:match("/([^/]+)%.lp")) }
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end


%>

<% =ui_helper.createHeader(T"Wireless", true, true, nil, help_link) %>

<div class="modal-body update">
<%
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-wireless.lp")
%>
<form class="form-horizontal" method="post" action="<%= ngx.var.request_uri %>">
<%
-- Do not display the navlist on the list if only 1 SSID
if #wls > 1 then
%>
<div class="span3">
    <ul class="nav nav-list">
    <%
   local html = {}
    local prevradio = ""
    for i,v in ipairs(wls) do
        if v.radio ~= prevradio then
            if radioData[untaint(v.radio)].remotely_managed == "1" and radioData[untaint(v.radio)].integrated_ap ~= "1" then
                html[#html+1] = format('<li class="nav-header">%s %s</li>', T"External access points", radioData[untaint(v.radio)].supported_frequency_bands)
            else
                html[#html+1] = format('<li class="nav-header">%s %s</li>', T"Access points", radioData[untaint(v.radio)].supported_frequency_bands)
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
        else
            html[#html+1] = format('<li class="%s"><a  id = "Wireless_Tab_%s" href="#" data-remote="%s">%s</a></li>', active, i, url, v.ssid)
        end
    end
    -- If wifi analyzer enabled, draw it
    local wifi_analyzer_disable = proxy.get("uci.wireless.wifi.@global.wifi_analyzer_disable")
    if wifi_analyzer_disable and wifi_analyzer_disable[1].value ~= "1" then
      html[#html+1] = string.format('<li class="nav-header">%s</li>', T"Wireless Data")
      local freq = "2.4"
      local isDuplicate = {}
      for i,v in ipairs(wls) do
        if not isDuplicate[v.radio] and (v.radio == "radio_5G" or v.radio == "radio_2G") then
          if v.radio == "radio_5G" then freq = "5" or "2.4" end
          local active = ""
          if getWifiAnalyzer == v.iface then
            active = "active"
            radio = v.radio
          end
          local url = "modals/wireless-modal.lp?radio=" .. v.radio .. "&isWifiAnalyzer=" .. v.iface
          html[#html+1] = format('<li class="%s"><a href="#" data-remote="%s" id ="wifianalyzer_%s">%s %sGHz</a></li>',active, url,freq,T"Analyzer",freq )
          local link_id = "2"
          if freq == "5" then link_id = "5" end
          html[#html + 1] = format([[
             <div><div id = linkconfirming-msg_%s class= "alert hide"> %s </div> ]],
             link_id,T"If you use this tool, devices connected will be disconnected and will be able to connect after 1 minute.")
          html[#html + 1] = format([[
             <div id="linkrescan-changes_%s" class="hide">
             <div id="linkrescan-cancel_%s" class="btn">%s</div>
             <div id="linkrescan-confirm_%s" class="btn btn-primary" data-toggle="modal", data-remote="%s">%s</div>
             </div></div>
             ]],
             link_id,link_id,T"Cancel",link_id,url,T"Accept")
        end
        isDuplicate[v.radio] = true
      end
    end
    if session:hasAccess("/modals/wireless-client-modal.lp") then
      html[#html+1] = format("<li><a href=\"#\" <a href=\"#\" data-remote=\"modals/wireless-client-modal.lp\" >%s</a></li>", T"Client Monitoring" )
    end
    ngx.print(html)
    %>
    </ul>
</div>
<div class="span6">
<%
end

local current_acl_mode = content["acl_mode"]
if getWifiAnalyzer == nil then%>
<%
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
if bandsteerhelpmsg then ngx.print(ui_helper.createMessages(bandsteerhelpmsg)) end
%>
<fieldset>
<legend><%= T"Interface" %></legend>

<%
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
        html[#html + 1] = ui_helper.createLabel(T"Frequency band", content["supported_frequency_bands"])
        -- Label that shows the MAC address of the Wifi interface
        html[#html + 1] = ui_helper.createLabel(T"MAC address", content["macaddress"])
    if radioData[curradio].supported_frequency_bands == "5GHz" then
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
        if not stbLimit then
            html[#html + 1] = ui_helper.createSwitch(T"Enabled", "admin_state", content["admin_state"])
        end
        html[#html + 1] = ui_helper.createLabel(T"Frequency band", content["supported_frequency_bands"])
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
   if radioData[curradio].supported_frequency_bands == "5GHz" then
     html[#html + 1] = ui_helper.createLabel(T"Standard", listboxToText(wifi_standard, wifiStandard.standard), stdattributes)
     stdattributes.select={class = "monitor-changes",style="display:none"}
     html[#html + 1] = ui_helper.createSimpleInputSelect("standard", wifi_standard, wifiStandard.standard,stdattributes)
   else
    if not stbLimit then
        html[#html + 1] = ui_helper.createInputSelect(T"Standard", "standard", wifi_standard, content["standard"], stdattributes)
    else
        html[#html + 1] = ui_helper.createLabel(T"Standard", listboxToText(wifi_standard, content["standard"]), stdattributes)
    end
   end

        -- Current speed of the Wifi interface
        html[#html + 1] = ui_helper.createLabel(T"Speed", content["phy_rate"] / 1000 .. "Mbps", { span = {
            id = "phy_rate",
            ["data-ajaxrefresh"] = "5",
        }})
        local channel_select_class = {
          select = {},
          label = {
          class = "channelValue",
            title = ""
          }
        }
        -- Choose which channel to use
        if not stbLimit then
           if radioData[curradio].supported_frequency_bands ~= "5GHz" then
               html[#html + 1] = ui_helper.createInputSelect(T"Channel", "requested_channel", allowed_channels, content["requested_channel"])
		   else
               local allowed_channels_5G = { {"auto", T"Auto"} }
               allowed_channels_5G = list5g[content["requested_channel_width"]] or list5g["auto"]
               html[#html + 1] = ui_helper.createInputSelect(T"Channel", "requested_channel", allowed_channels_5G, content["requested_channel"],channel_select_class)
		   end
        end

        -- Show which region is being used
        html[#html + 1] = ui_helper.createLabel(T"Region", content["country"], advanced)
        html[#html + 1] = ui_helper.createLabel(T"Current channel", content["channel"], { span = {
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

            html[#html + 1] = ui_helper.createInputSelect(T"Channel Width", "channelwidth20", cw_20, content["requested_channel_width"], cw20attributes)

            local cw40attributes  = {
                group = {
                    class ="hide monitor-standard monitor-bgn monitor-an",
                },

            }

            html[#html + 1] = ui_helper.createInputSelect(T"Channel Width", "channelwidth40", cw_40, content["requested_channel_width"], cw40attributes)

            local cw80attributes  = {
                group = {
                    class ="hide monitor-standard monitor-anac",
                },
            }

            html[#html + 1] = ui_helper.createInputSelect(T"Channel Width", "channelwidth80", cw_80, content["requested_channel_width"], cw80attributes)
            html[#html + 1] = '</div>'

            if isExtRemman ~= "1" then
                html[#html + 1] = ui_helper.createSwitch(T"Short Guard Interval", "sgi", content["sgi"], advanced)
                html[#html + 1] = ui_helper.createInputSelect(T"Cyclic-Delay Diversity", "cdd", cddList, content["cdd"], advanced)
                html[#html + 1] = ui_helper.createSwitch(T"Space Time Block Code", "stbc", content["stbc"], advanced)
                --html[#html + 1] = ui_helper.createSwitch(T"Frame Bursting", "frame_bursting", content["frame_bursting"], advanced)
            end

            html[#html + 1] = ui_helper.createSliderSelect(T"Output Power", "outputpower", wifipower, content["outputpower"], advanced)
        end
    end
    ngx.print(html)
%>
</fieldset>

<%
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
    html[#html + 1] = ui_helper.createSwitch(T"Enabled", "ap_enabled", content["ap_enabled"], advanced)

    if not stbLimit then
        -- Show the SSID
        local ssidclass = {
            input = {
                pattern= "[!-~][ -~]{0,30}[!-~]",
                maxlength= "32",
                class= "span4",
                }
        }
        --Only baseiface can modify ssid when bandsteer enabled
        if band_steer_enabled and not isBaseIface(curiface) then
            html[#html + 1] = ui_helper.createLabel(T"SSID name", content["ssid"], ssidclass)
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
        html[#html + 1] = ui_helper.createSwitch(T"Broadcast SSID", "ap_broadcast_ssid", content["ap_broadcast_ssid"], broadcastclass)

        -- Select the security mode to use
        local secattributes = {
            group = {
                class = "",
            },
            select = {
                class = "monitor-changes"
            }
        }

        if band_steer_enabled and not isBaseIface(curiface) then
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

    if band_steer_enabled and not isBaseIface(curiface) then
        if "wep" == content["security"] then
            html[#html + 1] = ui_helper.createLabel(T"WEP Key", content["wep_key"], wepclass)
        end

        if "wpa-psk" == content["security"] or "wpa2-psk" == content["security"] or "wpa-wpa2-psk" == content["security"] then
            html[#html + 1] = ui_helper.createLabel(T"Wireless Password", content["wpa_psk"], pskclass)
        end
        if "wpa3" == content["security"] or "wpa3-psk" == content["security"] or "wpa2-wpa3-psk" == content["security"] or "wpa2-wpa3" == content["security"] then
          html[#html + 1] = ui_helper.createLabel(T"Wireless Password", content["wpa3"], pskwpa3)
        end
    else
        html[#html + 1] = ui_helper.createInputText(T"Wireless Password", "wpa_psk", content["wpa_psk"], pskclass, helpmsg["wpa_psk"])
        html[#html + 1] = ui_helper.createInputText(T"Wireless Password", "wpa3", content["wpa3"], pskwpa3, helpmsg["wpa3"])
        html[#html + 1] = ui_helper.createInputText(T"WEP key", "wep_key", content["wep_key"], wepclass, helpmsg["wep_key"])
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
        if band_steer_enabled and not isBaseIface(curiface) then
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
if isguest ~= "1" and ("wpa3" ~= content["security"] or "wpa3-psk" ~= content["security"]) then
    local wps_warning = {
        alert = {
            class = "alert-warning monitor-security monitor-wep monitor-wpa-psk monitor-ap_broadcast_ssid monitor-0 monitor-default-show"
        },
    }

    html[#html + 1] = ui_helper.createAlertBlock(T"WPS is automatically disabled if you choose WEP or WPA-only security or disable broadcast of the SSID", wps_warning)

    local wps_class = {
        group = {
            class = "monitor-security monitor-none monitor-wpa2-psk monitor-wpa-wpa2-psk monitor-wpa2-wpa3-psk monitor-wpa2-wpa3 monitor-ap_broadcast_ssid monitor-1"
        }
    }
    if ("wpa3" == content["security"] or "wpa3-psk" == content["security"]) and curiface == "wl1" then
        wps_class["group"] = {
            style = "display:none;"
        }
    end
    html[#html + 1] = ui_helper.createSwitch(T"WPS", "wps_enabled", content["wps_enabled"], wps_class)
    html[#html + 1] = ui_helper.createCheckboxSwitch(T"WPS AP PIN Enabled", "wps_pin_enabled", tostring(1-content["wps_pin_enabled"]), wps_class)
    html[#html + 1] = ui_helper.createLabel(T"WPS AP PIN code", content["wps_ap_pin_code"], wps_class)

    wps_class["input"] = {
        class="no-save",
        ["data-for"] = "wps_device_pin_code",
    }
    wps_class["button"] = {
        ["data-name"] = "action",
        ["data-value"] = "wps_device_pin_code",
    }
    html[#html + 1] = ui_helper.createInputTextWithButton(T"WPS Device PIN code", "wps_device_pin_code", content["wps_device_pin_code"], T"Set PIN code", "icon-ok-sign" ,wps_class, helpmsg["wps_device_pin_code"])

    wps_class["button"] = {
        ["data-name"] = "action",
        ["data-value"] = "wps_pbc",
    }
    if radioData[curradio].remotely_managed ~= "1" or radioData[curradio].integrated_ap == "1"  then
     html[#html + 1] = ui_helper.createButton(T"Connect using WPS", T"Trigger", "icon-refresh", wps_class)
    end
end
    html[#html + 1] = ui_helper.createInputSelect(T"Protected Management Frames", "pmf", pmfList, content["pmf"], advanced)

    if band_steer_supported and "wep" ~= content["security"] then
        local bssecclass = {
            group = {
                class ="monitor-security monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk monitor-none monitor-wpa2 monitor-wpa3 monitor-wpa3-psk monitor-wpa2-wpa3 monitor-wpa2-wpa3-psk",
            },
        }

        if isBaseIface(curiface) then
            html[#html + 1] = ui_helper.createAlertBlock(T"Detecting a Wi-Fi client's capabilities and monitoring its interfaces, Band Steering actively guides the client to the more suitable Wi-Fi band.", bssecclass)
            html[#html + 1] = ui_helper.createSwitch(T"Band Steering Enabled", "band_steer_enabled", band_steer_enabled and "1" or "0", bssecclass)
            if currentuserrole == "guest" then
              html[#html + 1] = ui_helper.createAlertBlock(T("If a wireless device reports this " .. symbolv2 .. "'s 2.4GHz signal strength is above this threshold, the " .. symbolv2 .. " will ask the device to test the 5GHz band . Please see 5GHz section for additional parameter."), bssecclass)
              html[#html + 1] = ui_helper.createSliderSelect(T"2.4GHz Band Steering Threshold", "rssi_threshold", bandsteer_rssi_threshold, content_rssi["rssi_threshold"], bssecclass)
            end
        else
          if currentuserrole == "guest" then
            html[#html + 1] = ui_helper.createAlertBlock(T"Detecting a Wi-Fi client's capabilities and monitoring its interfaces, Band Steering actively guides the client to the more suitable Wi-Fi band.", ssidclass)
            html[#html + 1] = ui_helper.createLabel(T"Band Steering Enabled", band_steer_enabled and "On" or "Off", ssidclass)
            html[#html + 1] = ui_helper.createAlertBlock(T"Please see 2.4GHz section for initial parameter. If a wireless device tests the 5GHz band and reports the 5GHz signal strength is above this threshold, the " .. symbolv2 .. " will direct the device to switch to the 5GHz band.", ssidclass)
            html[#html + 1] = ui_helper.createSliderSelect(T"5GHz Band Steering Threshold", "rssi_5g_threshold", bandsteer_rssi_threshold, content_rssi["rssi_5g_threshold"], ssidclass)
          end
        end
    end
end
    ngx.print(html)
%>
    <input type="hidden" name="ssid_uci" id="ssid_uci" value=""
    <input type="hidden" name="bspifacessid_uci" id="bspifacessid_uci" value="" >
    <input type="hidden" name="radius_authent_state" value="" >
    <input type="hidden" name="radius_account_state" value="" >


</fieldset>

        <%
        if not stbLimit then
            html = {}
            html[#html + 1] = "<fieldset class=\"advanced hide\">"
            html[#html + 1] = "<legend>"
            html[#html + 1] = T"Access Control List"
            html[#html + 1] = [[</legend>]]
            local aclmodeclass = {
                select = {
                  class = "monitor-changes",
                  id="aclmode"
                }
            }

            local isTableLoaded =  false
            local acl_attribute = {
                label = {
                  class = "monitor-acl_mode monitor-register"
                },
                button = {
                  class = "monitor-acl_mode monitor-register",
                  id = "btn_acl"
                }
              }
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
                if content["acl_mode"] == "register" then
                    html[#html + 1] = ui_helper.createButton(T"ACL Reg",T"Register", nil, acl_attribute)
                end
                html[#html + 1] = loadAclList(content["acl_mode"], "POST")
                    isTableLoaded =  true
            else
                html[#html + 1] = ui_helper.createInputSelect(T"ACL mode", "acl_mode", acl_modes, content["acl_mode"], aclmodeclass)
                html[#html + 1] = ui_helper.createButton(T"ACL Reg",T"Register", nil, acl_attribute)
                html[#html + 1] = "<div id=\"acl_list_div\" class=\"monitor-acl_mode monitor-lock monitor-register monitor-unlock\"><img src=\"/img/loading.gif\"/></div>"
            end
            html[#html + 1] = [[</fieldset>]]
            ngx.print(html)
        end
        %>

<%
else
  --wifi analyzer handler
  local uri = ngx.var.uri
  if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
  end
%>
<form id="wifiForm" class="form-horizontal" method="post" action="<%=uri%>">
<% if radio == "radio_2G" then %>

<div class="span6">

<% else %>

<div class="span6" style="margin-left:0;">

<% end %>
<fieldset>
<legend><%= T"Wifi Analyzer" %></legend>
<div style = "display:block;" class = "alert-info hide"><%=T"Please press Rescan button to view the updated wifi list"%></div></br>
<div id ="analyzerloader" style="height:100px"><img src = "/img/loading.gif"></img></div>
<div id = "analyzerGraph" class="hide">
<%= T("The below chart shows the results of the latest scan of your local area from your " .. symbolv2 .. ".") %>
<% if radio == "radio_2G" then %>
<canvas id="wrapper" width="720px" height="400px" style="border:1px solid #c3c3c3;">
<% else %>
<canvas id="wrapper" width="890px" height="400px" style="border:1px solid #c3c3c3;">
<% end %>
<%= T"Please update your browser to use this page." %>
</canvas>

<%
    html = {}

    local freq = "2"
    if radio == "radio_5G" then freq = "5" or "2" end
    html[#html + 1] = format([[
      <div id="ReScan_%s" style="width:650px;text-align:right;margin-right:20px;"><div class="btn btn-primary btn-large">%s</div></div>]],
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
%>


</div>
<div id="key" style="width: 700px;"></div>
<div id ="analyzerloader1" style="height:100px"><img src = "/img/loading.gif"></img></div>
</fieldset>
</div>
</form>

<script language ="javascript">

function get_random_color() {
  var letters = '0123456789ABCDEF'.split('');
  var color = '#';
  for (var i = 0; i < 6; i++ ) {
    color += letters[Math.round(Math.random() * 15)];
  }
   return color;
}
  function get_y_from_sig(max, min, range, sig) {
    return ((sig-max)/((min-max)/range))+30;
  }
  function get_curve_y_from_sig(max, min, range, sig) {
      var line = 350 - get_y_from_sig(max, min, range, sig);
      var line = 350 - (line *2);
    return line;
  }
    var maximum= -20;
    var minimum= -105;
    var range = 320;
    var bittarget40 = 10;
    var bittarget80 = 16;
    var ctx
  function initializeAnalyzer() {
    var c=document.getElementById("wrapper");
    ctx=c.getContext("2d");
    ctx.lineStyle="#FF0000";

    //Y Axis
    ctx.moveTo(30,30);
    ctx.lineTo(30,350);
    ctx.stroke();

    //Power Marks
    //30
    var line10 = get_y_from_sig(maximum, minimum, range, -10);

    ctx.moveTo(30,line10);
    ctx.lineTo(25,line10);
    ctx.stroke();
    ctx.font="9px Arial";
    ctx.fillText("-10",7,line10 + 3);

    var line30 = get_y_from_sig(maximum, minimum, range, -30);

    ctx.moveTo(30,line30);
    ctx.lineTo(25,line30);
    ctx.stroke();
    ctx.font="9px Arial";
    ctx.fillText("-30",7,line30 + 3);

    //60
    var line60 = get_y_from_sig(maximum, minimum, range, -60);

    ctx.moveTo(30,line60);
    ctx.lineTo(25,line60);
    ctx.stroke();
    ctx.font="9px Arial";
    ctx.fillText("-60",7,line60 + 3);

     //90
    var line90 = get_y_from_sig(maximum, minimum, range, -90);

    ctx.moveTo(30,line90);
    ctx.lineTo(25,line90);
    ctx.stroke();
    ctx.font="9px Arial";
    ctx.fillText("-90",7,line90 + 3);

    //X Axis
    ctx.moveTo(30,350);
    <% if radio == "radio_2G" then %>
    ctx.lineTo(690,350);
    <% else %>
    ctx.lineTo(870,350);
    <% end %>
    ctx.stroke();
    //Titles
    ctx.font="9px Arial";
    ctx.fillText("Channel",310,390);
    ctx.save();
    ctx.translate(0, 0);
    //ctx.rotate(Math.PI/2);
    ctx.textAlign = "center";
    ctx.fillText("Signal Strength (-dBm)", 60, 25);
    ctx.restore();

    //Channel Marks
    <% if radio == "radio_2G" then %>
    var chn_diff = 35;
    for (i = 1; i<=13; i++) {
      ctx.moveTo((i*chn_diff)+140, 350);
      ctx.lineTo((i*chn_diff)+140, 355);
      ctx.stroke();
      ctx.font="9px Arial";
      ctx.fillText(i.toString(), 140+(chn_diff*i), 370);
    }
    <%else%>
    var chn_diff = 30;
    var chnl = 0;
    for (i = 0; i <= 7; i++) {
         ctx.moveTo(60+(chn_diff*i),350);
         ctx.lineTo(60+(chn_diff*i),355);
         ctx.stroke();
         ctx.font="9px Arial";
         chnl = 36+(i*4);
         ctx.fillText(chnl.toString(),60+(chn_diff*i)-4,370);
    }

    for (i = 10; i <= 27; i++) {
         ctx.moveTo(60+(chn_diff*i),350);
         ctx.lineTo(60+(chn_diff*i),355);
         ctx.stroke();
         ctx.font="9px Arial";
         chnl = 60+(i*4);
         ctx.fillText(chnl.toString(),60+(chn_diff*i)-6,370);
    }

    <%end%>
   // analyzer table header
    $("#key").empty().append(
      $("<br/>"),
      $("<div>").addClass("col_ssid").text("<%= T'Network Name (SSID)'%>"),
      $("<div>").addClass("col_channel").text("<%= T'Channel' %>"),
      $("<div>").addClass("col_str").text("<%= T'40MHz'%>"),
      <% if radio ~= "radio_2G" then %>
        $("<div>").addClass("col_str").text("<%= T'80MHz'%>"),
      <% end %>
      $("<div>").addClass("col_rssi").text("<%= T'Signal Strength (RSSI)'%>"),
      $("<br/>")
    );
  }
  function generateGraph(ssid,channel,channelCentre,rssi,cap){
      color =  get_random_color();
      var Mhz = 0.5;
      var Str = "";
      var cap = parseInt(cap,16).toString(2);

      /*if(cap.indexOf("40MHz")!=-1)
      {
        Mhz = 1;
        Str = "*"
      }
      */
      while (cap.length <= 16)
        {
         cap = "0"+cap;
        }

     if (cap.charAt(cap.length-bittarget40) == "1") {
         Mhz = 1;
         Str = '*';
      }
      <% if radio == "radio_2G" then %>
      //2.4GHz
      var xcoord = 140+(channel*35);
      var sig = rssi;
      if (sig > maximum){sig = maximum }else if (sig < minimum){sig = minimum}
      ctx.beginPath();

      color =  get_random_color();
      ctx.strokeStyle = color;

        ctx.moveTo(xcoord-(140*Mhz), 350);
        ctx.quadraticCurveTo(xcoord, get_curve_y_from_sig(maximum, minimum, range, sig), xcoord+(140*(Mhz)), 350);

      ctx.stroke();
       <% else %>
       //5GH
      var chlist40 = [38,46,54,62,102,110,118,126,134,142,151,159]
      var chlist80 = [42,58,106,122,138,155]
      var str40 = ""
      var str80 = ""
      for (i = 0; i <= chlist40.length; i++) {
          if (chlist40[i] == channelCentre){
            str40 = "*";
            Mhz = 1;
          }
      }
      for (i = 0; i <= chlist80.length; i++) {
          if (chlist80[i] == channelCentre){
            str80 = "*";
            Mhz = 2;
          }
      }
      var xcoord = 0
      if  (channelCentre <= 64) {
         xcoord = 60+((channelCentre-36)*7.5);
      }else{
         xcoord = 360+((channelCentre-100)*7.5);
      }

      var sig = rssi;

      if (sig > maximum){sig = maximum }else if (sig < minimum){sig = minimum}
          ctx.beginPath();
          color =  get_random_color();
          ctx.strokeStyle = color;
          ctx.moveTo(xcoord-(30*Mhz), 350);
          ctx.quadraticCurveTo(xcoord, get_curve_y_from_sig(maximum, minimum, range, sig) , xcoord+(30*Mhz), 350);
          ctx.stroke();
       <% end %>

       // A new row for analyzer table
       var row = $("<div>").css("color", color);

       // Append the row
       $("#key").append(row);

       // Add columns to the new row
      $(row).append(
        $("<div>").addClass("col_ssid").text(ssid),
        $("<div>").addClass("col_channel").text(channel),
        <% if radio == "radio_2G" then %>
          $("<div>").addClass("col_str").text(Str),
        <%else%>
          $("<div>").addClass("col_str").text(str40),
          $("<div>").addClass("col_str").text(str80),
        <%end%>
        $("<div>").addClass("col_rssi").text(rssi),
        $("<br/>")
      );
    }

  function show_rescanconfirming(freq,show){
    var msg_id = "confirming-msg_" + freq;
    var rescan_id = "rescan-changes_" + freq;
    if (show == 1){
      $("div[id^= "+ rescan_id +"]").show();
      $("div[id^= "+ msg_id +"]").show();
    }
    else {
      $("div[id^= "+ rescan_id +"]").hide();
      $("div[id^= "+ msg_id +"]").hide();
    }
  }

  $("div[id^='ReScan_']").click(function() {
    var freq = (this.id).split("_")[1];
    show_rescanconfirming(freq,1);
  });

  $("div[id^='rescan-confirm_']").click(function() {
    var freq = (this.id).split("_")[1];
    show_rescanconfirming(freq,0);
  });

  $("div[id^='rescan-cancel_']").click(function() {
    var freq = (this.id).split("_")[1];
    show_rescanconfirming(freq,0);
  });

    $(document).ready(function(){
      $("div[id^='rescan-confirm_']").on("click",function(a) {
        var freq = (this.id).split("_")[1];
        show_rescanconfirming(freq,0);

        var params = [];
        params.push({
          name : "action",
          value : "rescan"
        });
        params.push({
          name : "curradio",
          value : "<%=radio%>"
        });
        params.push(tch.elementCSRFtoken());
        tch.showProgress("<%=T"Re-scanning"%>...");
        $.post("/modals/wireless-modal.lp", params, function(acsData){
          tch.removeProgress();
          initializeAnalyzer();
          if ( acsData.length > 0 ) {
            $.each(acsData, function(i, data){
              generateGraph(data.ssid,data.channel,data.channelCentre,data.rssi,data.cap);
            });
          }
        });
      });
      initializeAnalyzer();
      $.get("/modals/wireless-modal.lp?isWifiAnalyzer=<%=getWifiAnalyzer%>&getAcsData=true&radio=<%=radio%>",function(acsData){
         $("#analyzerloader").addClass("hide");
         $("#analyzerGraph").removeClass("hide");
         $("#analyzerloader1").addClass("hide");
         $.each(acsData, function(i, data) {
           generateGraph(data.ssid,data.channel,data.channelCentre,data.rssi,data.cap);
         });
       });
    });
</script>

<%
--End of wifi analyzer
end%>
<%
-- Do not display the navlist on the list if only 1 SSID
if #wls > 1 then
%>
</div>
<%
end
%>
</form>
</div>

<% ngx.print(ui_helper.createFooter()) %>
<script>
<%if not isTableLoaded then %>
    $.get("/modals/wireless-modal.lp?radio=<%=curradio%>&iface=<%=curiface%>&action=GET_ACL_MAC_LIST&acl_mode=<%=content["acl_mode"]%>", function (data){
        $('#acl_list_div').replaceWith(data);
    });
<%end%>

function show_linkconfirming(freq,show){
  var msg_id = "linkconfirming-msg_" + freq;
  var link_id = "linkrescan-changes_" + freq;

  if (show == 1){
    $("div[id = "+ link_id +"]").show();
    $("div[id = "+ msg_id +"]").show();
  }
  else{
    $("div[id = "+ link_id +"]").hide();
    $("div[id = "+ msg_id +"]").hide();
  }
}

$("a[id^='wifianalyzer_']").click(function() {
  var iface = (this.id).split("_")[1];
  var freq = iface.split(".")[0];
  show_linkconfirming(freq, 1);
  return false;
});

$("div[id^='linkrescan-confirm_']").click(function() {
  var iface = (this.id).split("_")[1];
  var freq = iface.split(".")[0];
  show_linkconfirming(freq, 0);
});

$("div[id^='linkrescan-cancel_']").click(function() {
  var iface = (this.id).split("_")[1];
  var freq = iface.split(".")[0];
  show_linkconfirming(freq, 0);
});

$("#aclmode").change(function(){
var aclmode = $(this).val();
if(aclmode == "register"){
    $("#acl_whitelist").attr("id","acl_register");
}else{
    $("#acl_register").attr("id","acl_whitelist");
}
});
<%if current_acl_mode ~= content["acl_mode"] then%>
  $('#modal-no-change').hide();
  $('#modal-changes').show();
<%end%>

function get_status_acl() {
   $("#btn_acl").attr('disabled', true);
   setTimeout(function(){
   $.get("modals/wireless-modal.lp?action=get_reg_status&curap=<%=curap%>", function(res){
     if (res != "register"){
       get_status_acl();
     }
     else{
       $("#btn_acl").removeAttr('disabled', false);
    }
    $("#btn_acl").html(res);
    });	},5000);
}

$("#btn_acl").click(function() {
   if($("#btn_acl").attr("disabled")!= undefined ) return false;
   $.post("modals/wireless-modal.lp",{ action: "set_reg", curap: "<%=curap%>", CSRFtoken: $("meta[name=CSRFtoken]").attr("content")},
      get_status_acl);
 });

var bandLockState = "<%=bandLockState%>"
if (bandLockState == "1") {
  $(".channelValue").addClass("tooltipEnabled")
  $(".channelValue").attr('title', "BandLock is Enabled");
}else{
  $(".channelValue").removeClass("tooltipEnabled")
  $(".channelValue").removeAttr('title', "BandLock is Enabled");
}
var bschecked = $('input[id="band_steer_enabled"]').val();
$(document).ready(function() {
    if ("1" == bschecked) {
        $('option[value="wep"]').hide();
        $('option[value="wpa-wpa2"]').hide();
        $('option[value="wpa2"]').hide();
        $('option[value="wpa"]').hide();
    }
});

$('input[id="band_steer_enabled"]').click(function(){
    if ("1" == bschecked) {
        $('option[value="wep"]').hide();
        $('option[value="wpa-wpa2"]').hide();
        $('option[value="wpa2"]').hide();
        $('option[value="wpa"]').hide();
    }
});

$("#standard").change(function(){
 $("#channelwidth40").val("auto");
 });

$("#save-config").click(function(){
  var ssid = $("#ssid").val();
  if (! $("body").find("#ssid").length) {
    ssid = "<%= content["ssid"]%>";
  }
  $("#ssid_uci").val(ssid);
  $("#bspifacessid_uci").val(ssid);
});

</script>
