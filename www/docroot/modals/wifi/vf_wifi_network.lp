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
local validateQTN = post_helper.validateQTN
local reservedIP = post_helper.reservedIPValidation
local string = string
local gmatch, format, next = string.gmatch, string.format, next
local isStringLengthValid = post_helper.getValidateStringLengthInRange
local isNumberRangeValid  = post_helper.getValidateNumberInRange
local ui_helper = require("vdf_ui_helper")
local vdf_helper = require("vodafone_helper")
local contentHelper = require("web.content_helper")
local json = require("dkjson")
local pageInfo, errMsg

local getUser = contentHelper.getMatchedContent("uci.web.rule.@vfwifinetwork.roles.", {value = "user"})

local function validateServers(value, object, key)
  local successRes, errmsgRes = reservedIP(value)
  if not successRes then
    return nil, errmsgRes
  end
  return validateServerIPs(value, validateQTN), T"Invalid IP"
end

local wifiData = {
  VodafoneWiFi          = "rpc.services.x_vfwifi.Enabled",
  UserSelectable        = "rpc.services.x_vfwifi.UserSelectable",
  EAPServers            = "rpc.services.x_vfwifi.EAPServer",
  AuthPort              = "rpc.services.x_vfwifi.EAPServerAuth",
  AccountingPort        = "rpc.services.x_vfwifi.EAPServerAcc",
  VLANOpenSSID          = "rpc.services.x_vfwifi.gre.VLAN_SSID",
  VLANEAPSSID           = "rpc.services.x_vfwifi.gre.VLAN_EAPSSID",
  EAPSecret             = "rpc.services.x_vfwifi.EAPServerSecret",
  Maxassocusers         = "rpc.services.x_vfwifi.MaxAssocUsers",
  MaxassocusersOpenSSID = "rpc.services.x_vfwifi.MaxAssocUsersSSID",
  MaxassocusersEAPSSID  = "rpc.services.x_vfwifi.MaxAssocUsersEAPSSID",
  MinimumSyncSpeed      = "rpc.services.x_vfwifi.BandwidthMinimum",
  bandWidth             = "rpc.services.x_vfwifi.Bandwidthpercentage",
  MaxBW                 = "rpc.services.x_vfwifi.BandwidthEgress",
  Servers               = "rpc.services.x_vfwifi.gre.Server"
}

local mapValid = {
  VodafoneWiFi          = post_helper.validateBoolean ,
  UserSelectable        = post_helper.validateBoolean ,
  EAPServers            = post_helper.getAndValidation(post_helper.getAndValidation(validateQTN, reservedIP), validateIP),
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
  Servers               = post_helper.getOptionalValidation(validateServers),
}
local pageInfo, errMsg = post_helper.handleQuery(wifiData, mapValid)
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
      -- The params X_VFWifi.GRE.VLAN_SSID and X_VFWifi.GRE.VLAN_EAPSSID returns empty values when hostapd restart is in progress,
      -- so introduce delay to hold the save operation until gets valid data from datamodel and also introduce timeout (1 minute)
      -- to break this loop

      local step = 0
      ngx.sleep(1)
      while step <= 60 do
        local getVLANData = {
          vlan = "rpc.services.x_vfwifi.gre.VLAN_SSID",
          eap  = "rpc.services.x_vfwifi.gre.VLAN_EAPSSID",
        }
        contentHelper.getExactContent(getVLANData)
        if (getVLANData and getVLANData["vlan"] ~= "" and getVLANData["eap"] ~= "") then
          break
        end
        step = step + 2
      end
      ngx.print('<input type="hidden" id="post_status" value="success">')
    end
  end
end

local getData = {
  serverip        = "rpc.services.x_vfwifi.gre.Server",
  UserSelectState = "rpc.services.x_vfwifi.UserSelectable",
}
contentHelper.getExactContent(getData)
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")
  ngx.print('\
\
<form id="vf-wifi-network_form" method="post" action="modals/wifi/vf_wifi_network.lp">\
<input type="hidden" value="');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('" id="CSRFtoken">\
<input type="hidden" value="');  ngx.print(pageInfo["VodafoneWiFi"]); ngx.print('" id="wifiStatus">\
<h1><span>');  ngx.print(T"Vodafone WiFi"); ngx.print('</span></h1>\
<h2><span>');  ngx.print(T"Vodafone WiFi Management"); ngx.print('</span></h2>\
');  
  local row = {          {
      label = T"Vodafone WiFi",
      rowClass = "vdf-row padding-top-bottom-20",
      element = ui_helper.createButton(
      {
        id = "vf-wifi-btn-onoff",
        class = pageInfo["VodafoneWiFi"] == "1" and "button button-on" or "button button-off"
      })
    }
  }
  ngx.print(ui_helper.createTable(row, "", "h3-content h3-content-mobile vdf-table no-padding-bottom"))
  ngx.print('\
\
<div id="hide-page" style="');  if pageInfo["VodafoneWiFi"] == "1" then   ngx.print('display:block');  else  ngx.print('display:none');  end  ngx.print('">\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  ');  
    local row = {
      {
        label = T"User Selectable",
        rowClass = "row padding-top-bottom-20",
        colLeftClass = "col-xs-6 col-md-6 col-sm-6",
        colRightClass = "col-xs-6 col-md-6 col-sm-6 text-right",
        element = ui_helper.createButton(
        {
          id = "vf-wifi-btn-userselect",
          class = getData["UserSelectState"] and next(getUser) and "button button-on notedited" or "button button-off notedited"
      })
    }
    }
    ngx.print(ui_helper.createTable(row, "", "h3-content h3-content-mobile"))
    ngx.print('\
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
  ');  
    local rows = {
      {
        label = T"EAP Servers",
        rowClass = "vdf-row padding-top-bottom-20 margin-top-lg",
        element = ui_helper.createTextField({
          id = "vf-wifi-txt-EAPServer",
          value = pageInfo.EAPServers,
          type = "text"
        })
      },
      {
        label = T"Auth Port",
        rowClass = "vdf-row padding-top-bottom-20 margin-top-lg",
        element = ui_helper.createTextField({
          id = "vf-wifi-txt-AuthPort",
          value = pageInfo["AuthPort"],
          type = "text"
        })
      },
      {
        label = T"Accounting Port",
        rowClass = "vdf-row padding-top-bottom-20",
        element = ui_helper.createTextField({
          id = "vf-wifi-txt-AccPort",
          value = pageInfo["AccountingPort"],
          type = "text"
        })
      },
      {
        label = T"VLAN OpenSSID",
        rowClass = "vdf-row padding-top-bottom-20",
        element = ui_helper.createTextField({
          id = "vf-wifi-txt-openSSID",
          value = pageInfo["VLANOpenSSID"],
          type = "text"
        })
      },
      {
        label = T"VLAN EAPSSID",
        rowClass = "vdf-row padding-top-bottom-20",
        element = ui_helper.createTextField{
          id = "vf-wifi-txt-EAPSSID",
          value = pageInfo["VLANEAPSSID"],
          type = "text"
        },
      },
      {
        label = T"EAP Secret",
        rowClass = "vdf-row padding-top-bottom-20",
        element = ui_helper.createTextField({
          id = "vf-wifi-txt-EAPSecret",
          value = pageInfo["EAPSecret"],
          type = "text"
        })
      },
    }
    ngx.print(ui_helper.createTable(rows, "", "h3-content h3-content-mobile vdf-table"))
    ngx.print('\
\
  <h3><span>');  ngx.print(T"QoS"); ngx.print('</span></h3>\
  ');  
    local rows = {
      {
        label = T"Max assoc users",
        rowClass = "vdf-row padding-top-bottom-20",
        element = ui_helper.createTextField({
          id = "vf-wifi-txt-maxUser",
          value = pageInfo["Maxassocusers"],
          type = "text"
        })
      },
      {
        label = T"Max assoc users OpenSSID",
        rowClass = "vdf-row padding-top-bottom-20",
        element = ui_helper.createTextField({
          id = "vf-wifi-txt-maxUserOpen",
          value = pageInfo["MaxassocusersOpenSSID"],
          type = "text"
        })
      },
      {
        label = T"Max assoc users EAPSSID",
        rowClass = "vdf-row padding-top-bottom-20",
        element = ui_helper.createTextField({
          id = "vf-wifi-txt-maxUserEAP",
          value = pageInfo["MaxassocusersEAPSSID"],
          type = "text"
        })
      },
      {
        label = T"Minimum Sync Speed",
        rowClass = "vdf-row padding-top-bottom-20",
        element = ui_helper.createTextField({
          id = "vf-wifi-txt-syncSpeed",
          value = pageInfo["MinimumSyncSpeed"],
          type = "text"
        })
      },
    }
    ngx.print(ui_helper.createTable(rows, "", "h3-content h3-content-mobile vdf-table"))
    ngx.print('\
  <div class="h3-content h3-content-mobile vdf-table">\
    <div class="vdf-row padding-top-bottom-20">\
      <div class="left">\
        <span class="fL">\
          ');  
            ngx.print(ui_helper.createRadioButton({
              class = "radio",
              name = "bw-setting",
              checked = pageInfo.bandWidth ~= "0" and "true" or "false",
              id = "percentBw",
              type = "radio",
              value = ""
            },"percentBw",
            {

            },T"% BW"))
            ngx.print('\
        </span>\
      </div>\
      <div class="right">\
        <input id="vf-wifi-txt-BWpercent"  value= "');  ngx.print(pageInfo["bandWidth"]); ngx.print('" type="text">\
      </div>\
    </div>\
    <div class="vdf-row padding-top-bottom-20">\
      <div class="left">\
        <span class="fL">\
          ');  
            ngx.print(ui_helper.createRadioButton({
              class = "radio",
              name = "bw-setting",
              checked = pageInfo.MaxBW ~= "0" and "true" or "false",
              id = "maxBw",
              type = "radio",
              value = ""
            },"maxBw",
            {

            },T"Max BW"))
            ngx.print('\
        </span>\
      </div>\
      <div class="right">\
        <input id="vf-wifi-txt-BWkbps"  value= "');  ngx.print(pageInfo["MaxBW"]); ngx.print('" type="text">\
      </div>\
    </div>\
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
<script src="/js/global-min.js" ></script>\
<script>\
  var resetVfWifi = ');  ngx.print(json.encode(resetvfwifi)); ngx.print('\
  var getUserSelectState = ');  ngx.print(json.encode(getData["UserSelectState"])); ngx.print('\
</script>\
<script src="/js/wifi/vf_wifi_network.js" ></script>\
'); 