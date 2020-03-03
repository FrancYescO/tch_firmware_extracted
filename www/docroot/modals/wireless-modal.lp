--pretranslated: do not change this file
 
local istainted = string.istainted
local untaint_mt = require("web.taint").untaint_mt
local setmetatable = setmetatable
local untaint, format, strmatch = string.untaint, string.format, string.match

-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local pairs = pairs
local floor = math.floor
local bandsteer_helper = require("bandsteer_helper")
local isBaseIface = bandsteer_helper.isBaseIface
local disableBandSteer = bandsteer_helper.disableBandSteer

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

local curradio = "radio_2G"
local curiface = "wl0"
local curap = "ap0"
local isguest = "0"
local radio2iface = {}

local radios = {}
for i,v in ipairs(proxy.getPN("uci.wireless.wifi-device.", true)) do
    local radio = strmatch(v.path, "uci%.wireless%.wifi%-device%.@([^%.]+)%.")
    if radio then
        radios[#radios+1] = radio
        if radio == getradio then
            curradio = radio
        end
    end
end
table.sort(radios)

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
    if not ssidMap[v.paramindex] then
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

local radioData = setmetatable({}, untaint_mt)
-- Radio data
for _,v in ipairs(radios) do
    local res = {}
    local rpath = "rpc.wireless.radio.@" .. v .. "."
    local rdata = proxy.get(rpath)
    if rdata ~= nil then
        for i,v in ipairs(rdata) do
            if v.path ~= rpath then
                rdata[i] = nil
            end
        end
    end
    post_helper.mergeTables(res, rdata);
    radioData[v] = res
end

local curband = radioData[curradio].supported_frequency_bands

local pathradio = format("uci.wireless.wifi-device.@%s.", curradio)
local pathiface = format("rpc.wireless.ssid.@%s.", curiface)
local rpcappath = "rpc.wireless.ap.@"
local pathap = format(rpcappath .. "%s.", curap)
local bandsteerpathap = bspeerap and format(rpcappath .. "%s.", bspeerap) or ""
local pathradius = format("uci.wireless.wifi-radius-server.@%s_", curap)
local isRadiusIncluded = false
if proxy.get(pathradius .. "auth0.") then
    isRadiusIncluded = true
end

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

-- Process POST query
-- UCI parameters list
local mapParams = {
    ap_enabled = pathap .. "admin_state",
    ssid = pathiface .. "ssid",
    ap_broadcast_ssid = pathap .. "public",
    security = pathap .. "security.mode",
    wep_key = pathap .. "security.wep_key",
    wpa_psk = pathap .. "security.wpa_psk_passphrase",
    acl_mode = pathap .. "acl.mode",
    wps_button_handler = "uci.button.button.@wps.handler",
}

if bspeerap then
    local bandsteerParams = {
        bsid = pap .. "@" .. curap .. ".bandsteer_id",
        bspeerid = pap .. "@" .. bspeerap .. ".bandsteer_id",
    }

    if isBaseIface(curiface) then
        if bandsteeriface then
            local bandsteerAddParams = {
                bspifacessid = piface .. "@" .. bandsteeriface .. ".ssid",
                bspeer_security_mode = pap .. "@" .. bspeerap .. ".security_mode",
                bspeer_wpa_psk_key = pap .. "@" .. bspeerap .. ".wpa_psk_key",
            }
            for k,v in pairs(bandsteerAddParams) do
                bandsteerParams[k] = v
            end
        end
    end

    for k,v in pairs(bandsteerParams) do
        mapParams[k] = v
    end
end

-- Only include radius/radio configuration in UI if not in guest/hotspot mode
if isguest ~= "1" then
    local addParams = {
        wps_enabled = pathap .. "wps.admin_state",
        wps_pin_enabled = pathap .. "wps.ap_setup_locked",
        wps_ap_pin_code = pathap .. "wps.ap_pin",
        interface_enabled = pathradio .. "state",
        standard = pathradio .. "standard",
        channelconf= pathradio .. "channel",
        channelwidth = pathradio .. "channelwidth",
        sgi = pathradio .. "sgi",
        cdd = pathradio .. "cdd",
        stbc = pathradio .. "stbc",
    }
    for k,v in pairs(addParams) do
        mapParams[k] = v
    end
    if isRadiusIncluded then
        addParams = {
            radius_authent_state = pathradius .. "auth0.state",
            radius_authent_ip = pathradius .. "auth0.ip",
            radius_authent_port = pathradius .. "auth0.port",
            radius_authent_secret = pathradius .. "auth0.secret",
            radius_account_state = pathradius .. "acct0.state",
            radius_account_ip = pathradius .. "acct0.ip",
            radius_account_port = pathradius .. "acct0.port",
            radius_account_secret = pathradius .. "acct0.secret",
        }
        for k,v in pairs(addParams) do
            mapParams[k] = v
        end
    end
end

-- Only include outputpower if changing the power is allowed
-- It won't be possible to touch this parameter unless this is allowed
-- local output_change_allowed = proxy.get(pathradio .. "tx_power_overrule_reg")[1].value
-- if output_change_allowed == "1" then
    mapParams["outputpower"] = pathradio .. "tx_power_adjust"
-- end

-- We're defining the listbox enums here to be able to use them to validate the input
-- Listbox that shows the supported WiFi standards
local wifi_standard_24GHz = {
      { "bg", T'802.11b/g'},
      { "bgn", T'802.11b/g/n'},
}

local wifi_standard_5GHz = {
    { "anac", T'802.11a/n/ac'},
}

local wifi_standard
if radioData[curradio].supported_frequency_bands == "5GHz" then
    wifi_standard = wifi_standard_5GHz
else
    wifi_standard = wifi_standard_24GHz
end

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
  ["b"] = "channelwidth20",
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
local channelwidth = cwmaps[cw[untaint(radioData[curradio].supported_standards)]]

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

list5g = setmetatable({
    ["20MHz"] = list5g20,
    ["20/40MHz"] = list5g40,
    ["auto"] = list5gAuto,
}, untaint_mt)

local secmodes
if radioData[curradio].supported_frequency_bands == "5GHz" then
-- do NOT show wep in 5G wifi
  secmodes = {
    { "none", T"None"},
    { "wpa2-psk", T"WPA2 PSK"},
    { "wpa-wpa2-psk", T"WPA+WPA2 PSK"},
    { "wpa2", T"WPA2"},
    { "wpa-wpa2", T"WPA+WPA2"},
}
  -- remove radius modes if in guest ap page
  if isguest == "1" or not isRadiusIncluded then
    secmodes[5] = nil
    secmodes[4] = nil
  end
else
  secmodes = {
    { "none", T"None"},
     { "wep", T"WEP"},
    { "wpa2-psk", T"WPA2 PSK"},
    { "wpa-wpa2-psk", T"WPA+WPA2 PSK"},
    { "wpa2", T"WPA2"},
    { "wpa-wpa2", T"WPA+WPA2"},
}

  -- remove radius modes if in guest ap page
  if isguest == "1" or not isRadiusIncluded then
    secmodes[6] = nil
    secmodes[5] = nil
  end
end

-- Listbox that shows the supported Access Control modes
local acl_modes = {
      -- { "disabled", T"Disabled" },
      { "unlock", T"Blacklist" },
      { "lock", T"Whitelist" },
      --{ "register", T"Register" },
}

-- Shortcuts to validation helpers to make lines shorter
local gVIPIL = post_helper.getValidationIfPropInList
local gVIES = post_helper.getValidateInEnumSelect
local gVSL = post_helper.getValidateStringLength
local gVChkbox = post_helper.getValidateCheckboxSwitch()
local vNES = post_helper.validateNonEmptyString
local vSII = post_helper.validateStringIsIP
local vSIP = post_helper.validateStringIsPort
local vSIM = post_helper.validateStringIsMAC
local gOV = post_helper.getOptionalValidation
local gCV = post_helper.getConditionalValidation
local gAV = post_helper.getAndValidation
local vPSK = post_helper.validatePSK
local gVSLIR = post_helper.getValidateStringLengthInRange
local vWEP = post_helper.validateWEP
local vPIN = post_helper.validateWPSPIN
local wpa_list = {"wpa2", "wpa-wpa2"}
local VIPIL_IP = gVIPIL(vSII, "security", wpa_list)
local VIPIL_port = gVIPIL(vSIP, "security", wpa_list)

local function getValidateChannelWidth(channelwidth)
  return function(value, postdata, key)
    local success, msg = gVIES(channelwidth)
    if success then
      postdata["channelwidth"] = postdata[cw[untaint(postdata["standard"])]]
      return true
    else
      return nil, msg
    end
  end
end
local function getValidateChannelConf(value, postdata, key)
  if radioData[curradio].supported_frequency_bands == "5GHz" then
      -- if the exist channel is not in the channelwidth which the newest selected, set "auto" to it, if not, keep it not changed
      -- the type of postdata["channelwidth"] is userdata which is not able to compare to string directly
      local gVEIS_CC = gVIES(list5g[postdata["channelwidth"]])
      local err,msg = gVEIS_CC(value)
      if not err then
        postdata["channelconf"] = "auto"
      end
  end
  return true
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

---
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
    if istainted(port) and istainted(ip) and ip:len() > 0 and port:len() > 0 then
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

local function getValidateBandSteerPeerFields(value, object, key)
    if "table" == type(object.band_steer_supported) then
        if "" ~= object.bsid and "off" ~= object.bsid then
            if object.security == "wep" then
                return nil, T"The Band Steering can not be supported under WEP security mode."
            end

            if isBaseIface(curiface) then
                if object.bspeer_security_mode then
                    object.bspeer_security_mode = object.security
                    object.bspeer_wpa_psk_key = object.wpa_psk
                    object.bspifacessid = object.ssid
                end
            end
            return true
        else
            local bsid = bandsteer_helper.getBandSteerId(curiface)
            --to check wether the bs obj exist or not
            local bandsteerobj = proxy.get("uci.wireless.wifi-bandsteer.@" .. bsid .. ".")
            if not bandsteerobj then
                return nil, T"Please configure wifi-bandsteer " .. bsid .. " first!"
            else
                if object.security == "wep" then
                    return nil, T"The Band Steering can not be supported under WEP security mode."
                end

                if isBaseIface(curiface) then
                    object.bsid = bsid
                    object.bspeerid = bsid

                    if object.bspeer_security_mode then
                        object.bspeer_security_mode = object.security
                        object.bspeer_wpa_psk_key = object.wpa_psk
                        object.bspifacessid = object.ssid
                    end
                end
            end
        end
    elseif object.band_steer_supported then --to disable bandsteer
        return disableBandSteer(object)
    end

    return true
end

local mapValid = {
    interface_enabled = post_helper.getValidateCheckboxSwitch(),
    standard = gVIES(wifi_standard),
    sgi = gOV(gVChkbox),
    cdd = gOV(gVChkbox),
    stbc = gOV(gVChkbox),
    ap_broadcast_ssid = gVChkbox,
    outputpower = gVIES(wifipower), -- if the parameter is not included, it does not matter, this validation function will never be called
    channelwidth20 = getValidateChannelWidth(cw_20),
    channelwidth40 = getValidateChannelWidth(cw_40),
    channelwidth80 = getValidateChannelWidth(cw_80),
    channelconf = getValidateChannelConf,
    ap_enabled = gVChkbox,
    security = gVIES(secmodes),
    ssid = gVSLIR(1,32),
    wep_key = gVIPIL(vWEP,"security", {"wep"}),
    wpa_psk = gVIPIL(vPSK,"security", {"wpa-psk", "wpa2-psk", "wpa-wpa2-psk"}),
    wps_enabled = gOV(gVChkbox),
    wps_pin_enabled = vApPinEnabled,
    acl_mode = gVIES(acl_modes),
    radius_authent_ip = VIPIL_IP,
    radius_account_ip = gOV(VIPIL_IP),
    radius_authent_secret = gVIPIL(vNES,"security", wpa_list),
    radius_account_secret = gVIPIL(vNES,"security", wpa_list),
    radius_authent_port = VIPIL_port,
    radius_account_port = gOV(VIPIL_port),
    radius_authent_state = gCV(radiusCond, getReplaceValue("1"), getReplaceValue("0")), -- we know that we're enforcing the server ip and port is there
    radius_account_state = gCV(gAV(radiusCond, checkIPandPort), getReplaceValue("1"), getReplaceValue("0")), -- if no server ip or port, don't set to 1
    wps_button_handler = function(val, object)
      object.wps_button_handler = "wps_button_pressed.sh"
      return true
    end,
    bsid = getValidateBandSteerPeerFields,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
local bandsteerhelpmsg = {}
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
-- End of parameters saving / loading

-- Support for device PIN code
content["wps_device_pin_code"] = ""

-- triggered only on a POST with action set wps_device_pin_code (button next to field should trigger that)
if ngx.req.get_method() == "POST" then
    if #wls >1 then
        for _,v in ipairs(wls) do
            if v.iface == curiface then
                v.ssid = content["ssid"]
            end
            if v.iface == bandsteeriface and content["bspifacessid"] then
                v.ssid = content["bspifacessid"]
            end
        end
    end
    local args = ngx.req.get_post_args()
    local action = args["action"]
    local pin = args["wps_device_pin_code"]
    if action == "wps_device_pin_code" and content["wps_enabled"] == "1" then
        local res, help = vPIN(pin)
        content["wps_device_pin_code"] = pin

        if res then
            proxy.set("rpc.wireless.ap.@" .. curap .. ".wps.enrollee_pin", pin)

        else
            helpmsg["wps_device_pin_code"] = help
        end
    end
    -- End of device PIN code support

    -- triggered only on a POST with action set wps_pbc
    if action == "wps_pbc" and content["wps_enabled"] == "1" then
        proxy.set("rpc.wireless.wps_button","1")
    end
    -- End of WPS PBC code support
end


-- AP PIN code - read only
content["wps_ap_pin_code"] = proxy.get("uci.wireless.wifi-ap.@" .. curap .. ".wps_ap_pin")[1].value

for k,v in pairs(radioData[curradio]) do
    -- Not replace the value that already exists
    if not content[k] then
        content[k] = v
    end
end

if isguest == "1" then
    local radioConf = {
        interface_enabled = pathradio .. "state",
        standard = pathradio .. "standard",
        channelconf = pathradio .. "channel",
        channelwidth = pathradio .. "channelwidth",
    }

    content_helper.getExactContent(radioConf)
    for k,v in pairs(radioConf) do
        content[k] = v
    end
end
-- Mac Address
content["macaddress"] = proxy.get("rpc.wireless.ssid.@" .. curiface .. ".mac_address")[1].value

local acl_columns = {
  {
    header = T"MAC Address",
    name = "acl_macaddress",
    param = "value",
    type = "text",
    attr = { input = { class = "span2", maxlength = "17" } },
  }
}

local function valueInList(inputlist, value)
  if inputlist then
     for _,v in ipairs(inputlist) do
       if v.value == value then
         return true
       end
     end
  end
  return false
end

local function validateAclMac(value,object,key)
    local path = "uci.wireless.wifi-ap.@" .. curap                  
    local macdata = proxy.get(path .. ".acl_accept_list.", path .. ".acl_deny_list.")

    if valueInList(macdata, value) then
       return nil, T"Mac address duplicate with either current whitelist or current blacklist"
    end
  return true
end

local macvalid = {
    acl_macaddress = gAV(vSIM,validateAclMac)
}

local acl_whitelist_options = {
    tableid = "acl_whitelist",
    basepath = "uci.wireless.wifi-ap.@" .. curap .. ".acl_accept_list.@.",
    createMsg = T"Add new MAC address",
}
local acl_whitelist_data, acl_whitelist_helpmsg = post_helper.handleTableQuery(acl_columns, acl_whitelist_options, nil, nil, macvalid)

local acl_blacklist_options = {
    tableid = "acl_blacklist",
    basepath = "uci.wireless.wifi-ap.@" .. curap .. ".acl_deny_list.@.",
    createMsg = T"Add new MAC address",
}
local acl_blacklist_data, acl_blacklist_helpmsg = post_helper.handleTableQuery(acl_columns, acl_blacklist_options, nil, nil, macvalid)

local band_steer_supported = 0
local band_steer_enabled = "0"

if "" ~= bandsteerpathap then
    --Need to consider the constraint
    local content_band_steer = {
        band_steer_id = "uci.wireless.wifi-ap.@".. curap .. ".bandsteer_id",
    }
    content_helper.getExactContent(content_band_steer)

    --To get the content_band_steer value
    if "" ~= content_band_steer.band_steer_id then
        band_steer_supported = 1
        if "off" ~= content_band_steer.band_steer_id then
            band_steer_enabled = "1"
        end
    end
end

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. format("%s", uri:match("/([^/]+)%.lp")) }
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end

  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Wi-Fi", true, true, nil, help_link) ); ngx.print('\
\
<div class="modal-body update">\
<form class="form-horizontal" method="post" action="');  ngx.print( uri ); ngx.print('">\
');  
-- Do not display the navlist on the list if only 1 SSID
if #wls > 1 then
  ngx.print('\
<div class="span3">\
    <ul class="nav nav-list">\
    ');  
    html = {}
    local prevradio = ""
    for i,v in ipairs(wls) do
        if v.radio ~= prevradio then
            html[#html+1] = format('<li><strong>%s</strong> <strong>%s</strong></li>', T"Access points", radioData[v.radio].supported_frequency_bands)
            prevradio = v.radio
        end
        local active = ""
        if v.iface == curiface then
            active = "active"
        end
        local url = "modals/wireless-modal.lp?radio=" .. v.radio .. "&iface=" .. v.iface
        html[#html+1] = format('<li class="%s"><a href="#" data-remote="%s">%s</a></li>', active, url, v.ssid)
    end
    ngx.print(html)
      ngx.print('\
    </ul>\
</div>\
<div class="span6">\
');  
end
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
if bandsteerhelpmsg then ngx.print(ui_helper.createMessages(bandsteerhelpmsg)) end
  ngx.print('\
\
<fieldset>\
<legend>');  ngx.print( T"Wi-Fi Radio" ); ngx.print('</legend>\
\
');  
html = {}
--Enable/Disable radio
    if isguest == "1" then
        -- Switch that shows if the Wifi interface is enabled or not
        html[#html + 1] = ui_helper.createCheckboxSwitch(T"Enabled", "interface_enabled", content["interface_enabled"], { input = { disabled = "disabled" }})
   else
        -- Switch that shows if the Wifi interface is enabled or not
        html[#html + 1] = ui_helper.createCheckboxSwitch(T"Enabled", "interface_enabled", content["interface_enabled"])
   end
ngx.print(html)
  ngx.print('\
\
</fieldset>\
\
<fieldset>\
<legend>');  ngx.print( T"Wi-Fi Channel" ); ngx.print('</legend>\
\
');  
    local html = {}
    local advanced = {
        group = {
            class = "advanced hide",
        }
    }

    -- In guest page, do not let the user change the configuration of the wifi radio. Only in main AP
    if isguest == "1" then
        html[#html + 1] = ui_helper.createLabel(T"Frequency Band", content["supported_frequency_bands"])
        -- Label that shows the MAC address of the Wifi interface
        html[#html + 1] = ui_helper.createLabel(T"MAC Address", content["macaddress"])
        html[#html + 1] = ui_helper.createLabel(T"Standard", listboxToText(wifi_standard, content["standard"]), advanced)

        -- Current speed of the Wifi interface
        html[#html + 1] = ui_helper.createLabel(T"Speed", content["phy_rate"] / 1000 .. "Mbps")

        html[#html + 1] = ui_helper.createLabel(T"Channel", content["channelconf"])

        -- Show which region is being used
        html[#html + 1] = ui_helper.createLabel(T"Region", content["country"], advanced)
        html[#html + 1] = ui_helper.createLabel(T"Current Channel", content["channel"])

        html[#html + 1] = ui_helper.createLabel(T"Channel Width", listboxToText(channelwidth, content["channelwidth"]), advanced)
    else
        html[#html + 1] = ui_helper.createLabel(T"Frequency Band", content["supported_frequency_bands"])
        -- Label that shows the MAC address of the Wifi interface
        html[#html + 1] = ui_helper.createLabel(T"MAC Address", content["macaddress"])

        -- Select the standard to use
        local stdattributes = {
            group = {
                class = "advanced hide",
            },
            select = {
                class = "monitor-changes"
            }
        }
        html[#html + 1] = ui_helper.createInputSelect(T"Standard", "standard", wifi_standard, content["standard"], stdattributes)

        -- Current speed of the Wifi interface
        html[#html + 1] = ui_helper.createLabel(T"Speed", content["phy_rate"] / 1000 .. "Mbps")

        -- Choose which channel to use
        local allowed_channels = { {"auto", T"Auto"} }
        if radioData[curradio].supported_frequency_bands ~= "5GHz" then
           for i in string.gmatch(content["allowed_channels"], "%S+") do
             allowed_channels[#allowed_channels + 1] = {i, i}
           end
        else
           allowed_channels = list5g[content["channelwidth"]] or list5g["auto"]
        end
        html[#html + 1] = ui_helper.createInputSelect(T"Channel", "channelconf", allowed_channels, content["channelconf"])

        -- Show which region is being used
        html[#html + 1] = ui_helper.createLabel(T"Region", content["country"], advanced)
        html[#html + 1] = ui_helper.createLabel(T"Current Channel", content["channel"])

        local cw20attributes  = {
            group = {
                class ="advanced hide monitor-standard monitor-b monitor-bg",
            },
        }

        html[#html + 1] = ui_helper.createInputSelect(T"Channel Width", "channelwidth20", cw_20, content["channelwidth"], cw20attributes)

        local cw40attributes  = {
            group = {
                class ="advanced hide monitor-standard monitor-bgn monitor-an",
            },
        }

        html[#html + 1] = ui_helper.createInputSelect(T"Channel Width", "channelwidth40", cw_40, content["channelwidth"], cw40attributes)

        local cw80attributes  = {
            group = {
                class ="advanced hide monitor-standard monitor-anac",
            },
        }

        html[#html + 1] = ui_helper.createInputSelect(T"Channel Width", "channelwidth80", cw_80, content["channelwidth"], cw80attributes)
        -- html[#html + 1] = ui_helper.createCheckboxSwitch("Frame Bursting", "framebursting", content["framebursting"], advanced)
        html[#html + 1] = ui_helper.createCheckboxSwitch(T"Short Guard Interval", "sgi", content["sgi"], advanced)
        html[#html + 1] = ui_helper.createCheckboxSwitch(T"Cyclic-Delay Diversity", "cdd", content["cdd"], advanced)
        html[#html + 1] = ui_helper.createCheckboxSwitch(T"Space Time Block Code", "stbc", content["stbc"], advanced)

--      if output_change_allowed == "1" then
            html[#html + 1] = ui_helper.createSliderSelect(T"Output Power", "outputpower", wifipower, content["outputpower"], advanced)
--      end
    end
    ngx.print(html)
  ngx.print('\
</fieldset>\
<fieldset>\
<legend>');  ngx.print( T"Wi-Fi Network" ); ngx.print('</legend>\
');  
    html = {}
    -- Show if the AP is enabled
    html[#html + 1] = ui_helper.createCheckboxSwitch(T"Enabled", "ap_enabled", content["ap_enabled"], advanced)

    -- Show the SSID
    local ssidclass = {
        input = {
            pattern= "[!-~][ -~]{0,30}[!-~]",
            maxlength= "32",
            class= "span4",
            }
    }
    --Only baseiface can modify ssid when bandsteer enabled
    if "1" == band_steer_enabled and not isBaseIface(curiface) then
        html[#html + 1] = ui_helper.createLabel(T"Network Name", content["ssid"], ssidclass)
    else
        html[#html + 1] = ui_helper.createInputText(T"Network Name", "ssid", content["ssid"], ssidclass, helpmsg["ssid"])
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
    html[#html + 1] = ui_helper.createCheckboxSwitch(T"Broadcast SSID", "ap_broadcast_ssid", content["ap_broadcast_ssid"], broadcastclass)

    if "1" == band_steer_enabled and not isBaseIface(curiface) then
        html[#html + 1] = ui_helper.createLabel(T"Security Mode", content["security"], secattributes)
    else
        local security_warning = {
            alert = {
                class = "alert-error monitor-security monitor-none"
            },
        }
        html[#html + 1] = ui_helper.createAlertBlock(T"Security for this Wi-Fi network is disabled, anybody can connect or listen to it", security_warning)

        -- Select the security mode to use
        local secattributes = {
            group = {
                class = "",
            },
            select = {
                class = "monitor-changes"
            }
        }

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

    local wepclass = {
        group = {
            class ="monitor-security monitor-wep",
        },
        input = {
            class= "span4",
        }
    }

    if "1" == band_steer_enabled and not isBaseIface(curiface) then
        if "wep" == content["security"] then
            html[#html + 1] = ui_helper.createLabel(T"WEP Key", content["wep_key"], wepclass)
        end

        if "wpa-psk" == content["security"] or "wpa2-psk" == content["security"] or "wpa-wpa2-psk" == content["security"] then
            html[#html + 1] = ui_helper.createLabel(T"Network Key", content["wpa_psk"], pskclass)
        end
    else
        html[#html + 1] = ui_helper.createInputText(T"WEP Key", "wep_key", content["wep_key"], wepclass, helpmsg["wep_key"])
        html[#html + 1] = ui_helper.createInputText(T"Network Key", "wpa_psk", content["wpa_psk"], pskclass, helpmsg["wpa_psk"])
    end
    if isguest ~= "1" and isRadiusIncluded then
        local monitorradius = {
                class ="monitor-security monitor-wpa monitor-wpa2 monitor-wpa-wpa2",
        }
        local ipclass = {
                pattern="(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])",
        }
        local serverclass = {
            group = monitorradius,
            input = ipclass
        }
        local basicclass = {
            group = monitorradius,
        }
        html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server's IP", "radius_authent_ip", content["radius_authent_ip"], serverclass, helpmsg["radius_authent_ip"])
        html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server's port", "radius_authent_port", content["radius_authent_port"],basicclass, helpmsg["radius_authent_port"])
        html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server's secret", "radius_authent_secret", content["radius_authent_secret"],basicclass, helpmsg["radius_authent_secret"])
        html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server's IP", "radius_account_ip", content["radius_account_ip"], serverclass, helpmsg["radius_account_ip"])
        html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server's port", "radius_account_port", content["radius_account_port"],basicclass, helpmsg["radius_account_port"])
        html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server's secret", "radius_account_secret", content["radius_account_secret"],basicclass, helpmsg["radius_account_secret"])
    end
    if isguest ~= "1" then
        local wps_warning = {
            alert = {
                class = "alert-warning monitor-security monitor-wep monitor-wpa-psk monitor-ap_broadcast_ssid monitor-0 monitor-default-show"
            },
        }

        html[#html + 1] = ui_helper.createAlertBlock(T"WPS is automatically disabled if you choose WEP or WPA-only security or disable broadcast of the SSID", wps_warning)

        local wps_class = {
            group = {
                class = "monitor-security monitor-none monitor-wpa2-psk monitor-wpa-wpa2-psk monitor-ap_broadcast_ssid monitor-1"
            }
        }
        html[#html + 1] = ui_helper.createCheckboxSwitch(T"WPS", "wps_enabled", content["wps_enabled"], wps_class)

        local content_wps = {
            wps_pin_enabled = pathap .. "wps.ap_setup_locked",
        }
        content_helper.getExactContent(content_wps)

        html[#html + 1] = ui_helper.createCheckboxSwitch(T"WPS AP PIN Enabled", "wps_pin_enabled", tostring(1-content_wps["wps_pin_enabled"]), wps_class)

        html[#html + 1] = ui_helper.createLabel(T"WPS AP PIN Code", content["wps_ap_pin_code"], wps_class)

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
        html[#html + 1] = ui_helper.createButton(T"Connect using WPS", T"Start", "icon-refresh", wps_class)
    end

    if 1 == band_steer_supported and "wep" ~= content["security"] then
        local bssecclass = {
            group = {
                class ="monitor-security monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk monitor-none",
            },
        }

        local bs_warning = {
            alert = {
                class = "alert-warning monitor-security monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk monitor-none"
            },
        }
        if isBaseIface(curiface) then
            html[#html + 1] = ui_helper.createCheckboxSwitch(T"Band Steering Enabled", "band_steer_supported", band_steer_enabled, bssecclass)
            html[#html + 1] = ui_helper.createAlertBlock(T"The Band Steering actively guides the client to the most suitable Wi-Fi band, by detecting the client's capabilities and monitoring the interfaces.", bs_warning)
        else
            html[#html + 1] = ui_helper.createLabel(T"Band Steering Enabled", band_steer_enabled == "1" and "Yes" or "No", ssidclass)
        end
    end

    ngx.print(html)
  ngx.print('\
    <input type="hidden" name="radius_authent_state" value="" >\
    <input type="hidden" name="radius_account_state" value="" >\
\
\
</fieldset>\
\
<fieldset class="advanced hide">\
<legend>');  ngx.print( T"Access Control List" ); ngx.print('</legend>\
');  
    html = {}

    local aclmodeclass = {
        select = {
          class = "monitor-changes"
        }
    }
    html[#html + 1] = ui_helper.createInputSelect(T"ACL mode", "acl_mode", acl_modes, content["acl_mode"], aclmodeclass)

    local whitelistclass = {
        group = {
          class = "monitor-acl_mode monitor-lock monitor-register"
        }
    }
    html[#html + 1] = ui_helper.createTable(acl_columns, acl_whitelist_data, acl_whitelist_options, whitelistclass, acl_whitelist_helpmsg)

    local blacklistclass = {
        group = {
          class = "monitor-acl_mode monitor-unlock"
        }
    }
    html[#html + 1] = ui_helper.createTable(acl_columns, acl_blacklist_data, acl_blacklist_options, blacklistclass, acl_blacklist_helpmsg)

    ngx.print(html)
  ngx.print('\
</fieldset>\
\
<fieldset class="advanced hide">\
');  
if isguest ~= "1" then
    -----------------------------------------------------------
    -- Detect whether NFC module exists, if exists, show the pop up info
    -----------------------------------------------------------
    local nfc_enabled = proxy.get("rpc.nfc.exists")
    if (nfc_enabled and nfc_enabled[1].value == "true") then
        local nfc_alert = {
            alert = {
                class = "alert alert-warning"
            },
        }  ngx.print('\
        <legend>');  ngx.print( T"Near Field Communication (NFC)" ); ngx.print('</legend>\
        ');  ngx.print(ui_helper.createAlertBlock(T"Near Field Communication (NFC) allows you to tap an Android smartphone or tablet against the front of your Gateway to automatically configure Wi-Fi credentials on your device, so that you can connect over Wi-Fi. This feature is not supported on Apple iOS devices.<br><br><a href=/gateway.lp?openmodal=nfc-modal.lp ><u>Click here</u></a> to configure NFC.", nfc_alert))
    end
end
  ngx.print('\
</fieldset>\
\
');  
-- Do not display the navlist on the list if only 1 SSID
if #wls > 1 then
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
var bschecked = $(\'input[id="band_steer_supported"]\').prop("checked");\
$(document).ready(function() {\
    if (true == bschecked) {\
        $(\'option[value="wep"]\').hide();\
    }\
});\
\
$(\'input[id="band_steer_supported"]\').click(function(){\
    if (true == bschecked) {\
        $(\'option[value="wep"]\').hide();\
    }\
});\
</script>\
\
'); 