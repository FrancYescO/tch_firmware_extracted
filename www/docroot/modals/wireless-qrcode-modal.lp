<%
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

local secmodes = setmetatable({
     ["none"] =  "" ,
     ["wpa2-psk"] = "WPA PSK",
     ["wpa-wpa2-psk"] = "WPA PSK",
     ["wpa2"] = "WPA2",
     ["wpa-wpa2"] =  "WPA2",
     ["wep"] =  "WEP",
}, untaint_mt )

local content = {
    ssid = ifacepath .. getiface .. ".ssid",
    secmode = appath .. getap .. ".security_mode",
    wepkey = appath .. getap .. ".wep_key",
    wpakey = appath .. getap .. ".wpa_psk_key",
}
content_helper.getExactContent(content)

local keypassphrases = setmetatable({
    ["none"] = "" ,
    ["wpa2-psk"] = content.wpakey,
    ["wpa-wpa2-psk"] = content.wpakey,
    ["wep"] = content.wepkey,
}, untaint_mt )

--Use WLAN configuratin to compose a string: "WIFI:T:WEP;S:mynetwork;P:mypassword;;"
--These parameters are needed: SSID, Security Mode and password
local wlanconfstr = ""
if content.ssid then
    local mode =  secmodes[content.secmode] or ""
    local password = keypassphrases[content.secmode] or ""
    wlanconfstr = "WIFI:T:" .. mode .. ";S:" .. content.ssid .. ";P:" .. password .. ";;"
end
%>

<%= ui_helper.createHeader(T"Wi-Fi QRCode", false, true) %>

<div class="modal-body update">
  <form class="form-horizontal" method="post" action="modals/wireless-qrcode-modal.lp">
   <fieldset>
        <center>
            <div id="qrcode"></div>
        <center>
    </fieldset>
    </form>
</div>

<%= ui_helper.createFooter() %>

<script>
$(function(){
    var wlanconfstr = "<%=wlanconfstr%>";
    var typeNumber = 4;
    var errorCorrectLevel = 'M';
    var qr = qrcode(typeNumber, errorCorrectLevel);
    qr.addData(wlanconfstr);

    qr.make();
    qr.createImgTag(typeNumber);
    var html = qr.createTableTag(typeNumber);
    $("#qrcode").html(html)
  });
</script>
