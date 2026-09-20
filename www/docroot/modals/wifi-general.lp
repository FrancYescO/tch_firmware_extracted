--pretranslated: do not change this file
 
-- Enable localization

gettext.textdomain('webui-core')
local ngx, pairs, ipairs, next, string = ngx,pairs,ipairs,next,string
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local valStrLen = post_helper.getValidateStringLengthInRange
local valEnumSel = post_helper.getValidateInEnumSelect
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local content, errmsg
local curAccPoint5ghz
local match, gmatch = string.match , string.gmatch
local json = require("dkjson")
local ap_paths={true}
local taint = string.taint

for i,v in ipairs(proxy.getPN("rpc.wireless.ap.", true)) do
  ap_paths[i] = v.path.."ssid"
end
local wl_list = proxy.get(unpack(ap_paths))
for i,v in ipairs(wl_list) do
  if(v.value == "wl1") then
    curAccPoint5ghz = match(v.path, "rpc%.wireless%.ap%.@([^%.]+)%.")
  end
end
local env_value = {
  localEthMac  = "uci.env.var.local_eth_mac",
  localWiFiMac = "uci.env.var.local_wifi_mac",
  qtnEthMac    = "uci.env.var.qtn_eth_mac",
  serialNumber = "uci.env.var.serial"
}
content_helper.getExactContent(env_value)
local wifi_value = {
  allowedChannels24 = "rpc.wireless.radio.@radio_2G.allowed_channels",
  bandwidth24 = "rpc.wireless.radio.@radio_2G.max_phy_rate",
  bandwidth5 = "rpc.wireless.radio.@radio_5G.max_phy_rate",
  allowedChannels5 = "rpc.wireless.radio.@radio_5G.allowed_channels",
  wifiLowEncryption = "uci.wireless.wifi-device.@radio_2G.encryptiontype"
}
content_helper.getExactContent(wifi_value)

local channels24GHz = {{"auto", T"Auto"}}
for i in gmatch(wifi_value.allowedChannels24, "%d+") do
  channels24GHz[#channels24GHz + 1] = {i, i}
end

local channels5GHz = {{"auto", T"Auto"}}
for i in gmatch(wifi_value.allowedChannels5, "%d+") do
  channels5GHz[#channels5GHz + 1] = {i, i}
end

local wifiProtectionModes = {
  {"none", T"off"},
  {"wpa2-psk", "WPA2"},
  {"wpa-wpa2-psk", "WPA + WPA2"}
}

local mapParam = {
  wifi_stat24 = "uci.wireless.wifi-ap.@ap0.state",
  wifi_ssid24 = "uci.wireless.wifi-iface.@wl0.ssid",
  channel24 = "rpc.wireless.radio.@radio_2G.requested_channel",
  wifiLowChnSel  = "rpc.wireless.radio.@radio_2G.channel",
  broadcast_ssid24 = "uci.wireless.wifi-ap.@ap0.public" ,
  securityMode24 = "uci.wireless.wifi-ap.@ap0.security_mode",
  wifi_stat5 = "uci.wireless.wifi-ap.@ap1.state",
  wifi_ssid5 = "uci.wireless.wifi-iface.@wl1.ssid",
  channel5 = "rpc.wireless.radio.@radio_5G.requested_channel",
  wifiHighChnSel = "rpc.wireless.radio.@radio_5G.channel",
  broadcast_ssid5 = "uci.wireless.wifi-ap.@"..curAccPoint5ghz..".public" ,
  securityMode5 = "uci.wireless.wifi-ap.@"..curAccPoint5ghz..".security_mode",
}

local mapValid = {
  wifi_stat24 = post_helper.validateBoolean,
  wifi_ssid24 = post_helper.getValidationIfPropInList(valStrLen(1,32), "wifi_stat24", {"1"}),
  channel24 = valEnumSel(channels24GHz),
  broadcast_ssid24 = post_helper.validateBoolean,
  securityMode24 = valEnumSel(wifiProtectionModes),
  wifi_stat5 = post_helper.validateBoolean ,
  wifi_ssid5 = post_helper.getValidationIfPropInList(valStrLen(1,32), "wifi_stat5", {"1"}),
  channel5 = valEnumSel(channels5GHz),
  broadcast_ssid5 = post_helper.validateBoolean,
  securityMode5 = valEnumSel(wifiProtectionModes),
}

content, errmsg = post_helper.handleQuery(mapParam, mapValid)

local invalidKeys = {
  [env_value.localEthMac]  = true, [env_value.localWiFiMac] = true, [env_value.qtnEthMac]    = true,
  [env_value.serialNumber] = true, [content.wifi_ssid24]  = true, [content.wifi_ssid5]    = true,
}
-- Description : Function to validate WiFi password
-- @function   : validatePSK
-- @param      : password(string)
-- @return     : return boolean
local function validatePSK(password)
--if password does not match with the list of invalid keys then true
--invalid keys like ethMac, SSID name, serial number etc. Refer variable "invalidKeys" for full list.
  if invalidKeys[taint(password)] == nil then
    local psklength = valStrLen(8,63)
    local asciiLevel, hexLevel = 0, 0
    --if password is either a string of 64 hexadecimal characters or ASCII printable with range 8-63 then true
    --if password is a Hexadecimal string in a valid range then give 3 points
    if (string.len(password) == 64 and match(password, "^[a-fA-F0-9]+$")) then
      hexLevel = 3
    end
    --if password is an Ascii in a valid range give 1 point
    if (psklength(password) and match(password, "^[ -~]+$")) then
      asciiLevel = 1
    end
    if hexLevel ~= 0 or asciiLevel ~= 0 then
      --if password has both lower and uppercase characters give 1 point
      if password:find("[a-z]") and password:find("[A-Z]") then
        asciiLevel = asciiLevel + 1
      end
      --if password has at least one number give 1 point
      if password:find("%d+") then
        asciiLevel = asciiLevel + 1
      end
      --if password has at least one special character and length is not equal to 64 give 1 point
      if password:find("[.!@#%$%%^&%*%?_~%-%(%)]") and password.len ~= "64" then
        asciiLevel = asciiLevel + 1
      end
      if (asciiLevel > 1) or (hexLevel > 2) then
        return true
      end
    end
  end
  return nil
end
local wifi_password_get = {
  password24wpa = "uci.wireless.wifi-ap.@ap0.wpa_psk_key",
  password5wpa = "uci.wireless.wifi-ap.@"..curAccPoint5ghz..".wpa_psk_key",
}
content_helper.getExactContent(wifi_password_get)
local resetwifi = {
  reset_wifi_low_enable = "uci.uci-defaults.general.wifi_low_enable",
  reset_wifi_low_ssid = "uci.uci-defaults.general.wifi_low_ssid",
  reset_wifi_low_channel = "uci.uci-defaults.general.wifi_low_channel",
  reset_wifi_low_broadcast = "uci.uci-defaults.general.wifi_low_broadcast",
  reset_wifi_low_protection_mode = "uci.uci-defaults.general.wifi_low_protection_mode",
  reset_wifi_low_password = "uci.uci-defaults.general.wifi_low_password",
  reset_wifi_high_enable = "uci.uci-defaults.general.wifi_high_enable",
  reset_wifi_high_ssid = "uci.uci-defaults.general.wifi_high_ssid",
  reset_wifi_high_channel = "uci.uci-defaults.general.wifi_high_channel",
  reset_wifi_high_broadcast = "uci.uci-defaults.general.wifi_high_broadcast",
  reset_wifi_high_protection_mode = "uci.uci-defaults.general.wifi_high_protection_mode",
  reset_wifi_high_password = "uci.uci-defaults.general.wifi_high_password"
}
content_helper.getExactContent(resetwifi)

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SAVE" then
  local passwordUpdate24 = ngx.req.get_post_args().password24
  local passwordUpdate5 = ngx.req.get_post_args().password5
  if not next(errmsg) then
    local setTable = {}
    local isPasswordChanged2 = wifi_password_get.password24wpa ~= passwordUpdate24
    local isPasswordChanged5 = wifi_password_get.password5wpa  ~= passwordUpdate5
    local passwordMaps   = {
      Password24         = passwordUpdate24,
      Password5          = passwordUpdate5,
      isPasswordChanged2 = isPasswordChanged2,
      isPasswordChanged5 = isPasswordChanged5,
    }
    local passwordValid  = {
      Password24         = post_helper.getValidationIfPropInList(validatePSK, "isPasswordChanged2", {true}),
      Password5          = post_helper.getValidationIfPropInList(validatePSK, "isPasswordChanged5", {true}),
    }
    local success = content_helper.validateObject(passwordMaps, passwordValid)
    if success then
      if isPasswordChanged2 then
        if((ngx.req.get_post_args().securityMode24 ~= "none")) then
          setTable["uci.wireless.wifi-ap.@ap0.wpa_psk_key"] = passwordUpdate24
        end
      end
      if isPasswordChanged5 then
        if((ngx.req.get_post_args().securityMode5 ~= "none")) then
          setTable["uci.wireless.wifi-ap.@"..curAccPoint5ghz..".wpa_psk_key"] = passwordUpdate5
        end
      end
      if next(setTable) then
        proxy.set(setTable)
        proxy.apply()
      end
      ngx.print('<input type="hidden" id="post_status" value="success">')
    else
      ngx.print('<input type="hidden" id="post_status" value="error">')
    end
  else
    ngx.print('<input type="hidden" id="post_status" value="error">')
  end
end

local wifi_password = {
  passwordDefault = "uci.env.var.default_key_r0_s0",
  password24wpa = "uci.wireless.wifi-ap.@ap0.wpa_psk_key",
  password5wpa = "uci.wireless.wifi-ap.@"..curAccPoint5ghz..".wpa_psk_key",
}
content_helper.getExactContent(wifi_password)

local offStateTimersAction = proxy.getPC("uci.tod.action.@wifischedactionOFF.enabled")
local onStateTimersAction = proxy.getPC("uci.tod.action.@wifischedactionON.enabled")
local offStateTimersList = proxy.getPC("uci.tod.action.@wifischedactionOFF.timers.")
local onStateTimersList = proxy.getPC("uci.tod.action.@wifischedactionON.timers.")
local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")
  ngx.print('\
\
<h1>');  ngx.print(T"General"); ngx.print('</h1>\
<h2>');  ngx.print(T"Your router supports b/g/n/ac. AC2100"); ngx.print('</h2>\
<form id="wifigeneral_form" class="form-horizontal" method="post" action="modals/wifi-general.lp">\
  <input type="hidden" name="CSRFtoken" id="CSRFtoken" value="');  ngx.print(CSRFtoken); ngx.print('"></input>\
  <input type="hidden" name="action" id="action" value="SAVE"></input>\
  <h3>');  ngx.print(T"Setup"); ngx.print('</h3>\
  <div class="h3-wrapper-content">\
    <div class="h3-content general">\
      ');  if (offStateTimersAction == "1" and offStateTimersList > 1) or (onStateTimersAction == "1" and onStateTimersList > 1)  then  ngx.print('\
      <div class="row" id="wifiGen-info-scheduleOnOff">\
        <div class="col-md-12 col-sm-12 col-xs-12 padding-right-12">\
          <div style="margin-bottom: 24px;"  class="message message-info">\
            <span class="font-normal">');  ngx.print(T"The Wi-Fi Schedule is currently enabled. Your Wi-Fi connection will turn on and off as specified."); ngx.print('</span>\
          </div>\
        </div>\
      </div>\
      ');  end  ngx.print('\
      <div class="row not-flex-row">\
        <div class="col-xs-12 col-md-6 col-sm-6 padding-right-pc paddingRight15">\
          <div class="row">\
            <div class="col-xs-6 col-md-6 col-sm-6 padding-top-bottom-20">\
              <span>');  ngx.print(T"Wi-Fi (2.4 GHz)"); ngx.print('</span>\
            </div>\
            <div class="col-xs-6 col-md-6 col-sm-6 text-right padding-top-bottom-20">\
              <div id="wifiGen-btn-edit24" class="button ');  if content.wifi_stat24 == "1" then   ngx.print(' button-on ');  else  ngx.print(' button-off ');  end  ngx.print(' wifiGen-btn-edit24"></div>\
            </div>\
          </div>\
          <div id="wifiGen-info24" class="hide">\
            <div class="row padding-left padding-left-mobile status-border-top left">\
              <div class="col-xs-12 col-md-12 col-sm-12 padding-top-bottom-20">\
                <div class="inner-row">\
                  <span class="light-font">');  ngx.print(T"Wi-Fi Name (SSID)"); ngx.print('</span>\
                </div>\
                <div class="inner-row"><input id="wifiGen-txt-ssid24" name="wifi_ssid24" class="col-md-12 col-sm-12 inner-row" value="');  ngx.print(content["wifi_ssid24"]); ngx.print('" type="text" /></div>\
             </div>\
            </div>\
            <div class="row padding-left padding-left-mobile left-select status-border-top">\
              <div class="col-xs-12 col-md-12 col-sm-12 padding-top-bottom-20 full-width-mobile left">\
                <div class="inner-row"><span class="light-font">');  ngx.print(T"Channel"); ngx.print('</span></div>\
                <div class="inner-row">\
                  <div id="top-info-mode" class="rel col-xs-12 col-md-12 col-sm-12 padding-left-right-mobile">\
                    <select id = "wifiGen-sel-channel24" class="wifiGen-sel-channel24">\
                      ');  for _, chnl in ipairs(channels24GHz) do  ngx.print('\
                        <option value = "');  ngx.print(chnl[1]); ngx.print('" ');  ngx.print((content.channel24 == chnl[1]) and ("selected") or ""); ngx.print('>');  ngx.print(chnl[2]); ngx.print('</option>\
                      ');  end  ngx.print('\
                    </select>\
                  </div>\
                </div>\
              </div>\
            </div>\
            <div class="row padding-left padding-left-mobile left-select status-border-top">\
              <div class="col-xs-12 col-md-12 col-sm-12 padding-top-bottom-20 full-width-mobile left" id ="wifi24channel">\
                <div class="col-xs-6 col-md-6 col-sm-6">\
                  <span class="light-font">');  ngx.print(T"Current Channel"); ngx.print('</span>\
                </div>\
                <div class="col-xs-6 col-md-6 col-sm-6 text-right" id = "wifiGen-txt-channel24">\
                  <span>');  ngx.print(content.wifiLowChnSel); ngx.print('</span>\
                </div>\
              </div>\
            </div>\
            <div class="row padding-left padding-left-mobile padding-top-bottom-20 status-border-top">\
              <div class="col-xs-6 col-md-6 col-sm-6">\
                <span class="light-font">');  ngx.print(T"Bandwidth"); ngx.print('</span>\
              </div>\
              <div class="col-xs-6 col-md-6 col-sm-6 text-right" id = "wifiGen-info-bandWidth24">\
                <span>');  ngx.print(wifi_value.bandwidth24/1000); ngx.print(' Mbit/s</span>\
              </div>\
            </div>\
            <div class="row padding-left padding-left-mobile child-of-bullet not-flex-row">\
              <div class="col-xs-6 col-md-6 col-sm-6 padding-top-bottom-20 status-border-top">\
                <span class="light-font">');  ngx.print(T"Broadcast SSID"); ngx.print('</span>\
              </div>\
              <div class="col-xs-6 col-md-6 col-sm-6 text-right padding-top-bottom-20 status-border-top">\
                <div id="wifiGen-btn-bssid24" class="button  ');  if content.broadcast_ssid24 == "1" then   ngx.print(' button-on ');  else  ngx.print(' button-off ');  end  ngx.print(' wifiGen-btn-bssid24"></div>\
              </div>\
            </div>\
            <div class="row padding-left padding-left-mobile left-select status-border-top">\
              <div class="col-xs-12 col-md-12 col-sm-12 padding-top-bottom-20 full-width-mobile left">\
                <div class="inner-row">\
                  <span class="light-font">');  ngx.print(T"Protection Mode"); ngx.print('</span>\
                </div>\
                <div class="inner-row">\
                  <div id="top-info-mode" class="rel col-xs-12 col-md-12 col-sm-12 padding-left-right-mobile">\
                    <select id="wifiGen-sel-mode24" class="wifiGen-sel-mode24">\
                      ');  for k,v in pairs(wifiProtectionModes) do  ngx.print('\
                        <option ');  if content.securityMode24 == v[1] then  ngx.print(' selected ');  end  ngx.print('  value="');  ngx.print(v[1]); ngx.print('">');  ngx.print(v[2]); ngx.print('</option>\
                      ');  end  ngx.print('\
                    </select>\
                  </div>\
                </div>\
              </div>\
            </div>\
            <div class="row padding-left padding-left-mobile padding-top-bottom-20" id="password-div-2ghz">\
              <div class="left child-of-bullet" id="wifi24password">\
                <div class="inner-row light-font">\
                  <span class="light-font">');  ngx.print(T"Wi-Fi Password"); ngx.print('</span>\
                </div>\
                <div class="inner-row">\
                  <label id="wifiGen-textLabel-pwd24" class="wifiGen-textLabel wifiGen-textBullet">');  ngx.print(wifi_password.password24wpa); ngx.print('</label>\
                  <input readonly="readonly" id="wifiGen-txt-pwd24" value="');  ngx.print(wifi_password.password24wpa); ngx.print('" class="secondColumn hidden" type="password" />\
                </div>\
                <div class="inner-row mobile-wifi-fix-width">\
                  <div class="inner-cell-left mobile-no-padding" style="padding-left: 105px;">\
                    <span>');  ngx.print(T"Display Characters"); ngx.print('</span>\
                  </div>\
                  <div class="inner-cell-right" style="line-height:24px;">\
                    <input id="wifiGen-chk-pwd24" class="checkbox checkbox-unchecked show-hide-pw" data-id="1" type="checkbox" />\
                    <label for="wifiGen-chk-pwd24"></label>\
                  </div>\
                </div>\
                <div class="inner-row mobile-clear-both" style="float:right;">\
                  <input class="button button-blank change-pw mob-button-width mob-apply-cancel" id="wifiGen-btn-cpwd24" data-id="1" value="');  ngx.print(T"Change Password"); ngx.print('" type="button" data-toggle="modal" data-target="#passwordModal" />\
                </div>\
              </div>\
            </div>\
          </div>\
        </div>\
        <!-- Main 2.4G wifi End -->\
        <!-- Main 5G Wifi Start -->\
        <div class="col-xs-12 col-md-6 col-sm-6 padding-left-pc paddingLeft15">\
          <div class="row">\
            <div class="col-xs-6 col-md-6 col-sm-6 padding-top-bottom-20">\
              <span>');  ngx.print(T"Wi-Fi (5 GHz)"); ngx.print('</span>\
            </div>\
            <div class="col-xs-6 col-md-6 col-sm-6 text-right padding-top-bottom-20">\
              <div id="wifiGen-btn-edit5" class="button ');  if content.wifi_stat5 == "1" then   ngx.print(' button-on ');  else  ngx.print(' button-off ');  end  ngx.print(' wifiGen-btn-edit5"></div>\
            </div>\
          </div>\
          <div id="wifiGen-info5" class="hide guestWiFi shadowProblem shadowProblemLeft">\
            <div class="row padding-left padding-left-mobile status-border-top">\
              <div class="col-xs-12 col-md-12 col-sm-12 padding-top-bottom-20 child-of-bullet left">\
                <div class="inner-row">\
                  <span class="light-font">');  ngx.print(T"Wi-Fi Name (SSID)"); ngx.print('</span>\
                </div>\
                <div class="inner-row"><input id="wifiGen-txt-ssid5" name ="wifi_ssid5" class="col-xs-12 col-md-12 col-sm-12 inner-row" value="');  ngx.print(content.wifi_ssid5); ngx.print('" type="text" /></div>\
              </div>\
            </div>\
            <div class="row padding-left padding-left-mobile status-border-top">\
              <div class="col-xs-12 col-md-12 col-sm-12 full-width-mobile padding-top-bottom-20 left">\
                <div class="inner-row"><span class="light-font">');  ngx.print(T"Channel"); ngx.print('</span></div>\
                <div class="inner-row">\
                  <div id="top-info-mode" class="rel col-xs-12 col-md-12 col-sm-12 padding-left-right-mobile">\
                      <select id = "wifiGen-sel-channel5" class = "wifiGen-sel-channel5">\
                        ');  for _, chnl in ipairs(channels5GHz) do  ngx.print('\
                          <option value = "');  ngx.print(chnl[1]); ngx.print('" ');  ngx.print((content.channel5 == chnl[1]) and ("selected") or ""); ngx.print('>');  ngx.print(chnl[2]); ngx.print('</option>\
                        ');  end  ngx.print('\
                    </select>\
                  </div>\
                </div>\
              </div>\
            </div>\
            <div class="row padding-left padding-left-mobile status-border-top">\
              <div class="col-xs-12 col-md-12 col-sm-12 padding-top-bottom-20 full-width-mobile left" id ="wifi5channel">\
                <div class="col-xs-6 col-md-6 col-sm-6">\
                  <span class="light-font">');  ngx.print(T"Current Channel"); ngx.print('</span>\
                </div>\
                <div class="col-xs-6 col-md-6 col-sm-6 text-right" id = "wifiGen-txt-channel5">\
                  <span>');  ngx.print(content.wifiHighChnSel); ngx.print('</span>\
                </div>\
              </div>\
            </div>\
            <div class="row padding-left padding-left-mobile status-border-top">\
              <div class="col-xs-6 col-md-6 col-sm-6 padding-top-bottom-20" id= "bandWidth2">\
                <span class="light-font">');  ngx.print(T"Bandwidth"); ngx.print('</span>\
              </div>\
              <div class="col-xs-6 col-md-6 col-sm-6 text-right padding-top-bottom-20" id = "wifiGen-info-bandWidth5">\
                <span>');  ngx.print(wifi_value.bandwidth5/1000); ngx.print(' Mbit/s</span>\
              </div>\
            </div>\
            <div class="row padding-left padding-left-mobile child-of-bullet not-flex-row">\
              <div class="col-xs-6 col-md-6 col-sm-6 padding-top-bottom-20 status-border-top">\
                <span class="light-font">');  ngx.print(T"Broadcast SSID"); ngx.print('</span>\
              </div>\
              <div class="col-xs-6 col-md-6 col-sm-6 text-right padding-top-bottom-20 status-border-top">\
                <div id="wifiGen-btn-bssid5" class="button ');  if content.broadcast_ssid5 == "1" then   ngx.print(' button-on ');  else  ngx.print(' button-off ');  end  ngx.print(' wifiGen-btn-bssid5"></div>\
              </div>\
            </div>\
            <div class="row padding-left padding-left-mobile status-border-top">\
              <div class="col-xs-12 col-md-12 col-sm-12 full-width-mobile padding-top-bottom-20 left">\
                <div class="inner-row">\
                  <span class="light-font">');  ngx.print(T"Protection Mode"); ngx.print('</span>\
                </div>\
                <div class="inner-row">\
                  <div id="top-info-mode" class="rel col-xs-12 col-md-12 col-sm-12 padding-left-right-mobile">\
                    <select id="wifiGen-sel-mode5" class="wifiGen-sel-mode5">\
                    ');  for k,v in pairs(wifiProtectionModes) do  ngx.print('\
                      <option ');  if content.securityMode5 == v[1] then  ngx.print(' selected ');  end  ngx.print('  value="');  ngx.print(v[1]); ngx.print('">');  ngx.print(v[2]); ngx.print('</option>\
                      ');  end  ngx.print('\
                    </select>\
                  </div>\
                </div>\
              </div>\
            </div>\
            <div class="row padding-left padding-left-mobile not-flex-row status-border-top padding-top-bottom-20" id="password-div-5ghz">\
              <div class="left child-of-bullet" id="wifi5password">\
                <div class="inner-row light-font">\
                  <span class="light-font">');  ngx.print(T"Wi-Fi Password"); ngx.print('</span>\
                </div>\
                <div class="inner-row">\
	              <label id="wifiGen-textLabel-pwd5" class="wifiGen-textLabel wifiGen-textBullet">');  ngx.print(wifi_password.password5wpa); ngx.print('</label>\
                  <input readonly="readonly"  id="wifiGen-txt-pwd5" value="');  ngx.print(wifi_password.password5wpa); ngx.print('" class="secondColumn hidden" type="password" />\
                </div>\
                <div class="inner-row mobile-wifi-fix-width">\
                  <div class="inner-cell-left mobile-no-padding" style="padding-left: 105px;">\
                    <span>');  ngx.print(T"Display Characters"); ngx.print('</span>\
                  </div>\
                  <div class="inner-cell-right" style="line-height: 24px;">\
                    <input id="wifiGen-chk-pwd5" class="checkbox checkbox-unchecked show-hide-pw" data-id="1" type="checkbox" />\
                    <label for="wifiGen-chk-pwd5"></label>\
                  </div>\
                </div>\
                <div class="inner-row mobile-clear-both" style="float:right;">\
                  <input class="button button-blank change-pw mob-button-width mob-apply-cancel" id="wifiGen-btn-cpwd5" data-id="1" value="');  ngx.print(T"Change Password"); ngx.print('"  type="button" data-toggle="modal" data-target="#passwordModal" />\
                </div>\
              </div>\
            </div>\
          </div>\
        </div>\
        <!-- Main 5G wifi End -->\
      </div>\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12 col-sm-12 col-xs-12 ">\
      <div style="margin-top: 24px; display: none;" id="wifiGen-info-WSSID" class="message message-error">\
        <span class="bold">\
          <span >');  ngx.print(T"Corrections needed"); ngx.print('</span>\
        </span>\
        <br />\
        <br />\
        <span >');  ngx.print(T"You are using forbidden characters."); ngx.print('</span>\
        </div>\
      <div id="wifiGen-info-defPwd" class="message info message-info margin-top-20 no-padding-right hide ">\
        <span  style="font-weight:normal;"></span>\
      </div>\
      <div style="margin-top: 24px; display: none;" id="protectionOff" class="message info message-info">\
        <span  style="font-weight:normal;line-height:0px;">');  ngx.print(T"Without a password your wireless network is unsecured. Anyone within the range of your Vodafone Ultra Hub Wi-Fi can use your connection and access your shared files. It is highly recommended to set Wi-Fi protection."); ngx.print('\
        </span>\
      </div>\
      <div style="margin-top: 24px; display: none;" id="SSIDProtectionChange" class="message info message-info">\
        <span  style="font-weight:normal;line-height:0px;">');  ngx.print(T"You're attempting to change certain options which shall cause the currently connected devices to be disconnected. These devices will not be able to reconnect automatically."); ngx.print('\
        </span>\
      </div>\
    </div>\
  </div>\
</form>\
\
');  
    lp.include("apply-cancel.lp")
    lp.include("reset-wrap-mobile.lp")
  ngx.print('\
<!-- Modal -->\
<div id="mobile-popup" class="mobile-reset hidden-md hidden-sm hidden-lg">\
  <div class="row padding-bottom-lg">\
    <div class="col-xs-12">\
      <div class="close-icon cancelR"></div>\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-12">\
      <h3>');  ngx.print(T"General"); ngx.print('</h3>\
    </div>\
  </div>\
  <div class="row margin-top-bottom-20">\
    <div class="col-xs-12">\
      ');  ngx.print(T"Do you want to reset this page to default settings?"); ngx.print('\
    </div>\
    <div class="col-xs-12 padding-top-bottom-20">\
      <input id="resetR" class="button button-apply mob-button-width" value="');  ngx.print(T"Reset"); ngx.print('" type="button">\
      <input id="cancelR" class="button button-cancel mob-button-width mob-apply-cancel cancelR" value="');  ngx.print(T"Cancel"); ngx.print('" type="button">\
    </div>\
  </div>\
</div>\
<!-- End -->\
\
<!-- Password Popup Modal -->\
<div class="modal fade content-general change-password-content" id="passwordModal" role="dialog">\
  <div class="modal-dialog">\
    <div class="modal-content change-password-content">\
      <div class="modal-header hidden-md hidden-lg">\
        <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
      </div>\
      <div class="modal-body no-padding">\
        <p class="title tL">');  ngx.print(T"Password"); ngx.print('</p>\
        <div class="vdf-row">\
          <div class="left">\
            <span>');  ngx.print(T"New Password"); ngx.print('</span>\
          </div>\
          <div class="right paddingLeft mobile-no-padding-left">\
            <input type="password" class="inputKeyPressed" id="wifiGen-info-pwd" name="new_pwd" placeholder="');  ngx.print(T"password"); ngx.print('" />\
          </div>\
        </div>\
        <div class="vdf-row">\
          <div class="left">\
            <span>');  ngx.print(T"Re-enter Password"); ngx.print('</span>\
          </div>\
          <div class="right paddingLeft mobile-no-padding-left">\
            <input type="password" id="wifiGen-info-pwd2" name= "cnf_pwd" placeholder="');  ngx.print(T"password"); ngx.print('" />\
          </div>\
        </div>\
        <div class="vdf-row">\
          <div class="left">\
            <span>');  ngx.print(T"Password Strength"); ngx.print('</span>\
          </div>\
          <div class="right paddingLeft mobile-no-padding-left">\
            <div  id="passStrength"  class="passwordStrength strength0">\
              <span id="password-span-strwk" class="show">');  ngx.print(T"Weak"); ngx.print('</span>\
              <span id="password-span-strgd" class="hide">');  ngx.print(T"Good"); ngx.print('</span>\
              <span id="password-span-strsg" class="hide">');  ngx.print(T"Strong"); ngx.print('</span>\
            </div>\
          </div>\
        </div>\
        <div class="table-wrapper">\
          <div class="message message-info" id="wifiGen-info-pwdstd" style="display: block;">\
            ');  ngx.print(T"For your security we suggest you to use lower & uppercase letters, numbers and symbols"); ngx.print('\
          </div>\
          <div class="message message-error not-similar" id="wifiGen-info-pwdmismat"  style="display: none;">\
            ');  ngx.print(T"The passwords you entered do not match."); ngx.print('\
          </div>\
          <div class="message message-error current-password" id="wifiGen-info-pwdsame" style="display: none;">\
            ');  ngx.print(T"The new password cannot be the same as your current one. Please type a new password."); ngx.print('\
          </div>\
          <div class="message message-error wrong-password" id="wifiGen-info-pwdwrong" style="display: none;">\
            ');  ngx.print(T"You are using forbidden characters."); ngx.print('\
          </div>\
          <div class="message message-error old-password" id="wifiGen-info-pwdold" style="display: none;">\
            ');  ngx.print(T"The typed password is incorrect"); ngx.print('\
          </div>\
          <div class="message message-error short-password" id="wifiGen-info-pwdshort" style="display: none;">\
            ');  ngx.print(T"The length of password must be between 8 to 64 characters."); ngx.print('\
          </div>\
          <div class="message message-error weak-password" id="wifiGen-info-pwdsecreq" style="display: none;">\
            ');  ngx.print(T"The password you have entered doesnt meet the minimum security requirements."); ngx.print('\
          </div>\
          <div class="message message-error" style="display: none;">\
          <!--The email you have entered is invalid. Please provide a valid email address.-->\
            ');  ngx.print(T"Please enter a proper email address."); ngx.print('\
          </div>\
        </div>\
        <div class="apply-cancel">\
          <input class="button button-apply save mob-button-width" value="');  ngx.print(T"Save"); ngx.print('"  type="button" id="password_apply" data-dismiss="modal" />\
          <input class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" id="wifiGen-btn-password_cancel"  data-dismiss="modal" value="');  ngx.print(T"Cancel"); ngx.print('" type="button" onClick="CloseModal()" />\
        </div>\
      </div>\
    </div>\
  </div>\
</div>\
<!-- End -->\
\
<script src="/js/global.js" ></script>\
<script>\
  $(function() {\
    ');  if content.securityMode24 == "none" or wifi_password.passwordDefault ~= wifi_password.password24wpa then   ngx.print('\
         $("#global-msg-wifi").hide();\
         $("#global-msg-wifi24").hide();\
    ');  end   ngx.print('\
    ');  if content.securityMode5 == "none" or wifi_password.passwordDefault ~= wifi_password.password5wpa then   ngx.print('\
         $("#global-msg-wifi").hide();\
         $("#global-msg-wifi5").hide();\
    ');  end   ngx.print('\
  });\
  var resetWifi = ');  ngx.print(json.encode(resetwifi)); ngx.print('\
  var passwordDefault = "');  ngx.print(wifi_password.passwordDefault); ngx.print('";\
  var password24wpa = "');  ngx.print(wifi_password.password24wpa); ngx.print('";\
  var password5wpa = "');  ngx.print(wifi_password.password5wpa); ngx.print('";\
  var wifi_stat24 = "');  ngx.print(content.wifi_stat24); ngx.print('";\
  var wifi_stat5 = "');  ngx.print(content.wifi_stat5); ngx.print('";\
  var broadcast_ssid24 = "');  ngx.print(content.broadcast_ssid24); ngx.print('";\
  var broadcast_ssid5 = "');  ngx.print(content.broadcast_ssid5); ngx.print('";\
  var wifi24ChannelSelectIndex = $("#wifiGen-sel-channel24")[0].selectedIndex;\
  var wifi5ChannelSelectIndex = $("#wifiGen-sel-channel5")[0].selectedIndex;\
  var wifi24ModeSelectIndex = $("#wifiGen-sel-mode24")[0].selectedIndex;\
  var wifi5ModeSelectIndex = $("#wifiGen-sel-mode5")[0].selectedIndex;\
  var invalidKeys = ["');  ngx.print(env_value.localEthMac); ngx.print('", "');  ngx.print(env_value.localWiFiMac); ngx.print('", "');  ngx.print(env_value.qtnEthMac); ngx.print('",\
                     "');  ngx.print(env_value.serialNumber); ngx.print('", "');  ngx.print(content.wifi_ssid24); ngx.print('", "');  ngx.print(content.wifi_ssid5); ngx.print('"];\
  var T = {\
    "default_password_24GHz" : "');  ngx.print(T"Please change the default password for Wi-Fi (2.4 GHz)."); ngx.print('",\
    "default_password_5GHz" : "');  ngx.print(T"Please change the default password for Wi-Fi (5 GHz)."); ngx.print('",\
    "default_password_24GHz_and_5GHz" : "');  ngx.print(T"Please change the default password for Wi-Fi (2.4 GHz) and Wi-Fi (5 GHz)."); ngx.print('"\
  };\
</script>\
<script src="js/wifi-general.js"></script>\
'); 
