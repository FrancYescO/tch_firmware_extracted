--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local untaint_mt = require("web.taint").untaint_mt

local getargs = ngx.req.get_uri_args()
local getiface = string.format("%s",getargs.iface or "")
local getap = string.format("%s",getargs.ap or "")
local ifacepath = "uci.wireless.wifi-iface.@"
local appath = "uci.wireless.wifi-ap.@"
local wireless_qr = require("wireless_qr")

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
  var wlanconfstr = "');  ngx.print(wlanconfstr); ngx.print('";\
  var content_device = "');  ngx.print(content.device); ngx.print('";\
  var getiface = "');  ngx.print(getiface); ngx.print('";\
  var ssid = "');  ngx.print(content.ssid); ngx.print('";\
  var password = "');  ngx.print(content.wpakey); ngx.print('";\
  var radio_id = "');  ngx.print(radioID); ngx.print('";\
</script>\
<script src="/js/wireless-qrcode-modal.js"></script>\
'); 