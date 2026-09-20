--pretranslated: do not change this file
 ngx.print(' ');  
-- Enable localization
gettext.textdomain('webui-core')
local ngx = ngx
local proxy = require("datamodel")
local post_helper = require("web.post_helper")
local vodafone_helper = require("vodafone_helper")
local lp = require("web.lp")
local session = ngx.ctx.session
local validateIP = post_helper.validateStringIsIP
local validateServerIPs = vodafone_helper.validateCommaSeparatedIPs
local string = string
local gmatch, format, next = string.gmatch, string.format, next
local isStringLengthValid = post_helper.getValidateStringLengthInRange
local isNumberRangeValid  = post_helper.getValidateNumberInRange
local contentHelper = require("web.content_helper")
local json = require("dkjson")
local pageInfo, errMsg

local getUser = contentHelper.getMatchedContent("uci.web.rule.@vfwifinetwork.roles.", {value = "user"})

local wifiData = {
  VodafoneWiFi          = "InternetGatewayDevice.Services.X_VFWifi.Enabled",
  UserSelectable        = "InternetGatewayDevice.Services.X_VFWifi.UserSelectable",
  EAPServers            = "InternetGatewayDevice.Services.X_VFWifi.EAPServer",
  AuthPort              = "InternetGatewayDevice.Services.X_VFWifi.EAPServerAuth",
  AccountingPort        = "InternetGatewayDevice.Services.X_VFWifi.EAPServerAcc",
  VLANOpenSSID          = "InternetGatewayDevice.Services.X_VFWifi.GRE.VLAN_SSID",
  VLANEAPSSID           = "InternetGatewayDevice.Services.X_VFWifi.GRE.VLAN_EAPSSID",
  EAPSecret             = "InternetGatewayDevice.Services.X_VFWifi.EAPServerSecret",
  Maxassocusers         = "InternetGatewayDevice.Services.X_VFWifi.MaxAssocUsers",
  MaxassocusersOpenSSID = "InternetGatewayDevice.Services.X_VFWifi.MaxAssocUsersSSID",
  MaxassocusersEAPSSID  = "InternetGatewayDevice.Services.X_VFWifi.MaxAssocUsersEAPSSID",
  MinimumSyncSpeed      = "InternetGatewayDevice.Services.X_VFWifi.BandwidthMinimum",
  bandWidth             = "InternetGatewayDevice.Services.X_VFWifi.Bandwidthpercentage",
  MaxBW                 = "InternetGatewayDevice.Services.X_VFWifi.BandwidthEgress",
  Servers               = "InternetGatewayDevice.Services.X_VFWifi.GRE.Server"
}

local mapValid = {
  VodafoneWiFi          = post_helper.validateBoolean ,
  UserSelectable        = post_helper.validateBoolean ,
  EAPServers            = validateIP,
  AuthPort              = isNumberRangeValid(0, 65535),
  AccountingPort        = isNumberRangeValid(0, 65535),
  VLANOpenSSID          = isNumberRangeValid(1, 4095),
  VLANEAPSSID           = isNumberRangeValid(1, 4095),
  EAPSecret             = isStringLengthValid(1, 63),
  Maxassocusers         = isNumberRangeValid(0, 125),
  MaxassocusersOpenSSID = isNumberRangeValid(0, 125),
  MaxassocusersEAPSSID  = isNumberRangeValid(0, 125),
  MinimumSyncSpeed      = isNumberRangeValid(0, 2147483647),
  bandWidth             = isNumberRangeValid(0, 100),
  MaxBW                 = isNumberRangeValid(0, 2147483647),
  Servers               = post_helper.getOptionalValidation(validateServerIPs),
}
pageInfo, errMsg = post_helper.handleQuery(wifiData, mapValid)
local resetvfwifi = {
  reset_enabled = "uci.uci-defaults.vodafoneWiFi.enabled",
  reset_user_selectable = "uci.uci-defaults.vodafoneWiFi.user_selectable",
  reset_gre_server = "uci.uci-defaults.vodafoneWiFi.gre_server",
  reset_eap_server = "uci.uci-defaults.vodafoneWiFi.eap_server",
  reset_auth_port = "uci.uci-defaults.vodafoneWiFi.auth_port",
  reset_accounting_port = "uci.uci-defaults.vodafoneWiFi.accounting_port",
  reset_vlan_open_ssid = "uci.uci-defaults.vodafoneWiFi.vlan_open_ssid",
  reset_vlan_eap_ssid = "uci.uci-defaults.vodafoneWiFi.vlan_eap_ssid",
  reset_eap_secret = "uci.uci-defaults.vodafoneWiFi.eap_secret",
  reset_qos_max_user = "uci.uci-defaults.vodafoneWiFi.qos_max_user",
  reset_qos_assoc_users_open = "uci.uci-defaults.vodafoneWiFi.qos_assoc_users_open",
  reset_qos_assoc_users_eap_ssid = "uci.uci-defaults.vodafoneWiFi.qos_assoc_users_eap_ssid",
  reset_qos_min_sync_speed = "uci.uci-defaults.vodafoneWiFi.qos_min_sync_speed",
  reset_qos_bw = "uci.uci-defaults.vodafoneWiFi.qos_bw"
}
contentHelper.getExactContent(resetvfwifi)

if ngx.req.get_method() == "POST" then
  if next(errMsg) then
    ngx.print('<input type="hidden" id="post_status" value="error">')
  else
    local isUserEdited = false
    ngx.header.content_type = "application/json"
    local postargs = ngx.req.get_post_args()
    local isUser = tonumber(postargs.SelectUser)
    if isUser == 1 and not next(getUser) then
      local setRole = {}
      local roleInstance = proxy.add("uci.web.rule.@vfwifinetwork.roles.")
      local rolePath = format("uci.web.rule.@vfwifinetwork.roles.@%s.value", roleInstance)
      setRole[rolePath] = "user"
      proxy.set(setRole)
      isUserEdited = true
    elseif isUser == 0 and next(getUser) then
      proxy.del(getUser[1].path)
      isUserEdited = true
    end
    if isUserEdited then
      proxy.apply()
      session:logout()
      ngx.exit(ngx.HTTP_OK)
    else
      ngx.print('<input type="hidden" id="post_status" value="success">')
    end
  end
end

local getData = {
  serverip        = "InternetGatewayDevice.Services.X_VFWifi.GRE.Server",
  UserSelectState = "InternetGatewayDevice.Services.X_VFWifi.UserSelectable",
}
contentHelper.getExactContent(getData)
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")
  ngx.print('\
\
<form id="vf-wifi-network_form" method="post" action="modals/vf-wifi-network.lp">\
<input type="hidden" value="');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('" id="CSRFtoken">\
<input type="hidden" value="');  ngx.print(pageInfo["VodafoneWiFi"]); ngx.print('" id="wifiStatus">\
<h1><span>');  ngx.print(T"Vodafone WiFi"); ngx.print('</span></h1>\
<h2><span>');  ngx.print(T"Vodafone WiFi Management"); ngx.print('</span></h2>\
<div class="h3-content h3-content-mobile vdf-table no-padding-bottom">\
  <div class="vdf-row padding-top-bottom-20">\
    <div class="left">\
      <span>');  ngx.print(T"Vodafone WiFi "); ngx.print('</span>\
    </div>\
    <div class="right">\
      <div id="vf-wifi-btn-onoff" class="button ');  if pageInfo["VodafoneWiFi"] == "1" then   ngx.print('button-on');  else  ngx.print('button-off');  end  ngx.print('"></div>\
      </div>\
    </div>\
  </div>\
<div id="hide-page" style="');  if pageInfo["VodafoneWiFi"] == "1" then   ngx.print('display:block');  else  ngx.print('display:none');  end  ngx.print('">\
<div class="row">\
        <div class="col-md-12">\
          <hr/>\
        </div>\
      </div>\
          <div class="h3-content h3-content-mobile">\
    <div class="row padding-top-bottom-20">\
        <div class="col-xs-6 col-md-6 col-sm-6">\
          <span>');  ngx.print(T"User Selectable"); ngx.print('</span>\
        </div>\
        <div class="col-xs-6 col-md-6 col-sm-6 text-right">\
        <div id="vf-wifi-btn-userselect" class="button ');  if getData["UserSelectState"] and next(getUser) then   ngx.print(' button-on  ');  else  ngx.print(' button-off ');  end  ngx.print(' notedited"></div>\
        </div>\
      </div>\
</div>\
<h3><span>');  ngx.print(T"SoftGRE"); ngx.print('</span></h3>\
<div id="server-table" class="h3-content h3-content-mobile vdf-table">\
      <div class="vdf-row padding-top-bottom-20">\
          <span>');  ngx.print(T"Server"); ngx.print('</span>\
      </div>\
      ');  
        local id = 1
        for ip in gmatch(getData["serverip"], '([^,]+)') do
        ngx.print('\
          <div class="vdf-row server" style="font-weight:bold;line-height:24px;">\
            <div id="vf-wifi-info-server');  ngx.print(id); ngx.print('" class="left">');  ngx.print(ip); ngx.print('</div>\
            <div class="right"><input type="button" class="button button-delete" id="vf-wifi-btn-server-del');  ngx.print(id); ngx.print('"></div>\
          </div>\
      ');  
          id = id + 1
        end
        ngx.print('\
\
     <div class="vdf-row padding-top-bottom-20 maxRow">\
        <div class="left">\
          <input id="vf-wifi-txt-server" class="keypressvalue" type="text">\
        </div>\
        <div class="right">\
          <input id="vf-wifi-btn-server-add" class="button button-add faded" type="button" disabled="true">\
        </div>\
      </div>\
</div>\
<div class="h3-content h3-content-mobile vdf-table">\
    <div class="vdf-row padding-top-bottom-20 margin-top-lg">\
        <div class="left">\
          <span>');  ngx.print(T"EAP Servers"); ngx.print('</span>\
        </div>\
        <div class="right">\
           <input name="" id="vf-wifi-txt-EAPServer"  value= "');  ngx.print(pageInfo["EAPServers"]); ngx.print('" type="text">\
        </div>\
      </div>\
    </div>\
    <div class="h3-content h3-content-mobile vdf-table">\
    <div class="vdf-row padding-top-bottom-20 margin-top-lg">\
        <div class="left">\
          <span>');  ngx.print(T"Auth Port"); ngx.print('</span>\
        </div>\
        <div class="right">\
    <input name="" id="vf-wifi-txt-AuthPort"  value= "');  ngx.print(pageInfo["AuthPort"]); ngx.print('" type="text">\
        </div>\
      </div>\
    <div class="vdf-row padding-top-bottom-20">\
        <div class="left">\
         <span>');  ngx.print(T"Accounting Port"); ngx.print('</span>\
        </div>\
        <div class="right">\
    <input name="" id="vf-wifi-txt-AccPort"  value= "');  ngx.print(pageInfo["AccountingPort"]); ngx.print('" type="text">\
        </div>\
      </div>\
     <div class="vdf-row padding-top-bottom-20">\
        <div class="left">\
         <span>');  ngx.print(T"VLAN OpenSSID"); ngx.print('</span>\
        </div>\
        <div class="right">\
          <input name="" id="vf-wifi-txt-openSSID"  value= "');  ngx.print(pageInfo["VLANOpenSSID"]); ngx.print('" type="text">\
        </div>\
      </div>\
    <div class="vdf-row padding-top-bottom-20">\
        <div class="left">\
        <span>');  ngx.print(T"VLAN EAPSSID"); ngx.print('</span>\
        </div>\
        <div class="right">\
    <input name="" id="vf-wifi-txt-EAPSSID"  value= "');  ngx.print(pageInfo["VLANEAPSSID"]); ngx.print('" type="text">\
        </div>\
      </div>\
    <div class="vdf-row padding-top-bottom-20">\
        <div class="left">\
       <span>');  ngx.print(T"EAP Secret"); ngx.print('</span>\
        </div>\
        <div class="right">\
    <input name="" id="vf-wifi-txt-EAPSecret"  value= "');  ngx.print(pageInfo["EAPSecret"]); ngx.print('" type="text">\
        </div>\
      </div>\
</div>\
<h3><span>');  ngx.print(T"QoS"); ngx.print('</span></h3>\
<div class="h3-content h3-content-mobile vdf-table">\
    <div class="vdf-row padding-top-bottom-20">\
        <div class="left">\
          <span>');  ngx.print(T"Max assoc users"); ngx.print('</span>\
        </div>\
        <div class="right">\
    <input name="" id="vf-wifi-txt-maxUser"  value= "');  ngx.print(pageInfo["Maxassocusers"]); ngx.print('" type="text">\
        </div>\
      </div>\
    <div class="vdf-row padding-top-bottom-20">\
        <div class="left">\
          <span>');  ngx.print(T"Max assoc users OpenSSID"); ngx.print('</span>\
        </div>\
        <div class="right">\
    <input name="" id="vf-wifi-txt-maxUserOpen"  value= "');  ngx.print(pageInfo["MaxassocusersOpenSSID"]); ngx.print('" type="text">\
        </div>\
      </div>\
    <div class="vdf-row padding-top-bottom-20">\
        <div class="left">\
         <span>');  ngx.print(T"Max assoc users EAPSSID"); ngx.print('</span>\
        </div>\
        <div class="right">\
    <input name="" id="vf-wifi-txt-maxUserEAP"  value= "');  ngx.print(pageInfo["MaxassocusersEAPSSID"]); ngx.print('" type="text">\
        </div>\
      </div>\
    <div class="vdf-row padding-top-bottom-20">\
        <div class="left">\
         <span>');  ngx.print(T"Minimum Sync Speed"); ngx.print('</span>\
        </div>\
        <div class="right">\
    <input name="" id="vf-wifi-txt-syncSpeed"  value= "');  ngx.print(pageInfo["MinimumSyncSpeed"]); ngx.print('" type="text">\
        </div>\
      </div>\
     <div class="vdf-row padding-top-bottom-20">\
        <div class="left">\
     <span class="fL">\
      <input class="radio" ');  if pageInfo.bandWidth ~= "0" then  ngx.print('checked="checked"');  end  ngx.print(' name="bw-setting" id="percentBw" type="radio">\
      <label for="percentBw"></label>\
      <span>');  ngx.print(T"% BW"); ngx.print('</span>\
      </span>\
        </div>\
        <div class="right">\
          <input id="vf-wifi-txt-BWpercent"  value= "');  ngx.print(pageInfo["bandWidth"]); ngx.print('" type="text">\
        </div>\
      </div>\
    <div class="vdf-row padding-top-bottom-20">\
        <div class="left">\
     <span class="fL">\
      <input class="radio" ');  if pageInfo.MaxBW ~= "0" then  ngx.print('checked="checked"');  end  ngx.print(' name="bw-setting" id="maxBw" type="radio">\
      <label for="maxBw"></label>\
      <span>');  ngx.print(T"Max BW"); ngx.print('</span>\
      </span>\
        </div>\
        <div class="right">\
          <input id="vf-wifi-txt-BWkbps"  value= "');  ngx.print(pageInfo["MaxBW"]); ngx.print('" type="text">\
        </div>\
      </div>\
\
</div>\
</div>\
</form>\
<div class="modal fade" id="vf-wifi-network-modal-popup" role="dialog" data-backdrop="static">\
    <div class="modal-dialog">\
        <!-- Modal content-->\
        <div class="modal-content">\
            <div class="modal-header hidden-md hidden-sm hidden-lg">\
                <button type="button" class="close" data-dismiss="modal">&times;</button>\
            </div>\
            <div class="modal-body">\
                <form class="form-horizontal">\
                    <div class="form-group no-margin-bottom">\
                        <div class="col-md-12 col-sm-12 col-lg-12">\
                            <p class="title">');  ngx.print(T"Are you sure you want to apply your changes?"); ngx.print('</p>\
                        </div>\
                    </div>\
                    <div class="form-group no-margin-bottom">\
                        <div class="col-md-12 col-sm-12 col-lg-12 padding-top-bottom-20">\
                            <p><span>');  ngx.print(T"You will be logged out for your changes to apply. Click apply to save your changes."); ngx.print('</span>\
                            </p>\
                        </div>\
                    </div>\
                    <div class="row apply-cancel-hr no-margin-right">\
                        <div class="col-md-12 col-sm-12 col-lg-12 col-xs-12 no-padding-right">\
                            <input value="');  ngx.print(T"Apply"); ngx.print('" class="button button-apply mob-button-width" id="vf-wifi-network-btn-apply" type="button">\
                            <input id="vf-wifi-network-btn-cancel" class="button button-cancel mob-button-width mob-apply-cancel" value="');  ngx.print(T"Cancel"); ngx.print('" type="button" data-dismiss="modal">\
                        </div>\
                    </div>\
                </form>\
            </div>\
        </div>\
    </div>\
</div>\
 ');  
 lp.include("apply-cancel.lp")
 lp.include("reset-wrap-mobile.lp")
   ngx.print('\
\
<script src="/js/global.js" ></script>\
<script>\
  var resetVfWifi = ');  ngx.print(json.encode(resetvfwifi)); ngx.print('\
  var getUserSelectState = ');  ngx.print(json.encode(getData["UserSelectState"])); ngx.print('\
</script>\
<script src="/js/vf-wifi-network.js" ></script>\
'); 