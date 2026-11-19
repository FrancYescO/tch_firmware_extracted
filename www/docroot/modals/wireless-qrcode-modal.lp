--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local untaint_mt = require("web.taint").untaint_mt
local proxy = require("datamodel")
local format, match, untaint = string.format, string.match, string.untaint
local session = ngx.ctx.session
local getargs = ngx.req.get_uri_args()
local getiface = string.format("%s",getargs.iface or "")
local getap = string.format("%s",getargs.ap or "")
local ifacepath = "uci.wireless.wifi-iface.@"
local appath = "uci.wireless.wifi-ap.@"
local wireless_qr = require("wireless_qr")
local isNewLayout = proxy.get("uci.env.var.em_new_ui_layout")
local post_helper = require("web.post_helper")
local variantHelper = post_helper.getVariant(variant_helper, "Wireless", "wireless")
isNewLayout = isNewLayout and isNewLayout ~= "" and isNewLayout[1].value or "0"

local secmodes = setmetatable({
     ["none"] =  "nopass" ,
     ["wpa2-psk"] = "WPA",
     ["wpa-wpa2-psk"] = "WPA",
     ["wpa2"] = "WPA",
     ["wpa-wpa2"] =  "WPA",
     ["wep"] =  "WEP",
     ["wpa3-psk"] = "WPA",
     ["wpa2-wpa3-psk"] = "WPA",
}, untaint_mt )

local content = {
    ssid = ifacepath .. getiface .. ".ssid",
    device = ifacepath .. getiface .. ".device",
    secmode = appath .. getap .. ".security_mode",
    wepkey = appath .. getap .. ".wep_key",
    wpakey = appath .. getap .. ".wpa_psk_key",
    public = appath .. getap .. ".public",
}
content_helper.getExactContent(content)

local keypassphrases = setmetatable({
    ["none"] = "" ,
    ["wpa2-psk"] = content.wpakey,
    ["wpa-wpa2-psk"] = content.wpakey,
    ["wep"] = content.wepkey,
    ["wpa3-psk"] = content.wpakey,
    ["wpa2-wpa3-psk"] = content.wpakey,
}, untaint_mt )

local wlanconfstr = wireless_qr.format(content, secmodes, keypassphrases, false)
local radioID = string.match(content["device"], "%d+")
local currentType = getiface:match("%d+%_(.*)") and "guest" or "main"

local availableInterfaces, availableCredentials = {}, {}
local function loadInterfaceCredList(gettype)
  local interfacesPath = "uci.web.network.@"..gettype..".intf."
  if proxy.getPN("uci.web.network.@"..gettype..".intf.", true) then
    availableInterfaces = content_helper.convertResultToObject(interfacesPath .. "@.", proxy.get(interfacesPath))
  end
  local credentials = "uci.web.network.@"..gettype..".cred."
  if proxy.getPN("uci.web.network.@"..gettype..".cred.", true) then
    availableCredentials = content_helper.convertResultToObject(credentials .. "@.", proxy.get(credentials))
  end
  return availableInterfaces, availableCredentials
end

local function getCredListMain(gettype)
  local credentialsInstance = "uci.web.network.@"..gettype..".credInstance."
  local credential_instance_list, availableCredentialsInstance = {}, {}
  if proxy.getPN("uci.web.network.@"..gettype..".credInstance.", true) then
    availableCredentialsInstance = content_helper.convertResultToObject(credentialsInstance .. "@.", proxy.get(credentialsInstance))
  end
  for _, cred in ipairs(availableCredentialsInstance) do
    credential_instance_list[#credential_instance_list + 1] = cred.value
  end
  return credential_instance_list
end

local function generateInterfaceList(gettype)
  availableInterfaces, availableCredentials = loadInterfaceCredList(gettype)
  interface_list, credential_list = {}, {}
  for _, intf in ipairs(availableInterfaces) do
    interface_list[#interface_list + 1] = intf.value
  end
  for _, cred in ipairs(availableCredentials) do
    credential_list[#credential_list + 1] = cred.value
  end
  return interface_list, credential_list
end

local interface_list, credential_list, guests_interface_list, guests_credential_list = {}, {}, {}, {}
local function loadAvailableInterface()
  local objPath = "uci.web.network."
  local objFound = proxy.getPN(objPath, true)
  local networktype = {}
  if objFound then
    for _, v in ipairs(objFound) do
      if v.path and v.path ~= "" then
        networktype[#networktype + 1] = v.path:match("%@(.*)%.")
      end
    end
  end
  for _, v in pairs(networktype) do
    if untaint(v) == "main" then
      interface_list, credential_list = generateInterfaceList("main")
    end
    if untaint(v) == "guest" then
      guests_interface_list, guests_credential_list  = generateInterfaceList("guest")
    end
  end
end

local function checkSplitMode(credential_list, type)
   local split_ssid
   local getType = session:retrieve("networktype") or "main"
   --To check whether multiAP is enabled or not
   local multiap_enabled = false
   if post_helper.getVariantValue(variantHelper, "multiAP") then
     local multiap_state = {
       agent = "uci.multiap.agent.enabled",
       controller = "uci.multiap.controller.enabled"
     }
     content_helper.getExactContent(multiap_state)
     multiap_enabled = multiap_state.agent == "1" and multiap_state.controller == "1"
   end
    local smartWifiStatus = proxy.get("rpc.wireless.SmartWiFi.Active")
    smartWifiStatus = smartWifiStatus and smartWifiStatus[1] and smartWifiStatus[1].value or ""
    if smartWifiStatus ~= "" then
    local main = {}
    if smartWifiStatus == "0" then
      main = {
       state_2g = "uci.multiap.controller_credentials.@cred0.state",
       state_5g = "uci.multiap.controller_credentials.@cred1.state",
       ssid_2g  = "uci.multiap.controller_credentials.@cred0.ssid",
       ssid_5g  = "uci.multiap.controller_credentials.@cred1.ssid",
       password_2g = "uci.multiap.controller_credentials.@cred0.wpa_psk_key",
       password_5g = "uci.multiap.controller_credentials.@cred1.wpa_psk_key",
       security_2g = "uci.multiap.controller_credentials.@cred0.security_mode",
       security_5g = "uci.multiap.controller_credentials.@cred1.security_mode"
      }
    else
      main = {
        state_2g = "rpc.X_AIRTIES_OBJ.MultiAPController.SSIDProfile.1.Enable",
        state_5g = "rpc.X_AIRTIES_OBJ.MultiAPController.SSIDProfile.2.Enable",
        ssid_2g = "rpc.X_AIRTIES_OBJ.MultiAPController.SSIDProfile.1.SSID",
        ssid_5g = "rpc.X_AIRTIES_OBJ.MultiAPController.SSIDProfile.2.SSID",
        password_2g = "rpc.X_AIRTIES_OBJ.MultiAPController.SSIDProfile.1.KeyPassphrase",
        password_5g = "rpc.X_AIRTIES_OBJ.MultiAPController.SSIDProfile.2.KeyPassphrase",
        security_2g = "rpc.X_AIRTIES_OBJ.MultiAPController.SSIDProfile.1.SecurityMode",
        security_5g = "rpc.X_AIRTIES_OBJ.MultiAPController.SSIDProfile.2.SecurityMode"
      }
    end
    local splitssid_from_web = proxy.get("uci.web.network.@main.splitssid")
    splitssid_from_web = splitssid_from_web and splitssid_from_web[1].value or "0"
    content_helper.getExactContent(main)
    if type == "main" then
      if main.state_2g == main.state_5g and main.ssid_2g == main.ssid_5g and main.password_2g == main.password_5g and main.security_2g == main.security_5g and splitssid_from_web == "0" then
        split_ssid = "0"
      else
        split_ssid = "1"
      end
    else
      local guest_split_ssid = proxy.get("uci.web.network.@guest.splitssid")
      guest_split_ssid = guest_split_ssid and guest_split_ssid[1].value or "0"
      return guest_split_ssid
    end
    end
    return split_ssid
end

local guestsplitssid, splitssid
if isNewLayout == "1" then
  loadAvailableInterface()
  splitssid = checkSplitMode(credential_list, "main")
  if #guests_credential_list > 1 then
    guestsplitssid = checkSplitMode(guests_credential_list, "guest")
  end
end
  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"Wi-Fi QR Code", false, false) ); ngx.print('\
\
<div class="modal-body update">\
  <form class="form-horizontal" method="post" action="modals/wireless-qrcode-modal.lp">\
   <fieldset>\
        <center>\
            <div id="qrcode"></div>\
        <center>\
    </fieldset>\
  </form>\
</div>\
\
<div class="modal-footer">\
  <div id="btn-close" class="btn btn-primary btn-large">');  ngx.print(T"Close"); ngx.print('</div>\
  <div id="btn-to-print" class="btn btn-primary btn-large">');  ngx.print(T"Print"); ngx.print('</div>\
</div>\
\
<script src="/js/qrcode-min.js"></script>\
\
<script>\
  var wlanconfstr = "');  ngx.print(untaint(wlanconfstr or "")); ngx.print('";\
  var content_device = "');  ngx.print(content.device); ngx.print('";\
  var getiface = "');  ngx.print(getiface); ngx.print('";\
  var ssid = "');  ngx.print(untaint(content.ssid or "")); ngx.print('";\
  var password = "');  ngx.print(untaint(content.wpakey or "")); ngx.print('";\
  var radio_id = "');  ngx.print(radioID); ngx.print('";\
  var currentType = "');  ngx.print(currentType); ngx.print('";\
  var split_ssid = "');  ngx.print(splitssid); ngx.print('";\
  var guest_split_ssid = "');  ngx.print(guestsplitssid); ngx.print('";\
  var isNewLayout = "');  ngx.print(isNewLayout); ngx.print('";\
</script>\
<script src="/js/wireless-qrcode-modal.js"></script>\
'); 