--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
local content_helper = require("web.content_helper")
local untaint_mt = require("web.taint").untaint_mt
local ifacepath = "uci.wireless.wifi-iface.@"
local appath = "uci.wireless.wifi-ap.@"

local secmodes = setmetatable({
  ["none"] =  "nopass" ,
  ["wpa2-psk"] = "WPA",
  ["wpa-wpa2-psk"] = "WPA",
}, untaint_mt )

local content = {
  ssid24 = ifacepath .. "wl0" .. ".ssid",
  secmode24 = appath .. "ap0" .. ".security_mode",
  wpakey24 = appath .. "ap0" .. ".wpa_psk_key",
  public24 = appath .. "ap0" .. ".public",
  ssid5 = ifacepath .. "wl1" .. ".ssid",
  secmode5 = appath .. "ap1" .. ".security_mode",
  wpakey5 = appath .. "ap1" .. ".wpa_psk_key",
  public5 = appath .. "ap1" .. ".public",
  lanip = "uci.network.interface.@lan.ipaddr"
}
content_helper.getExactContent(content)

local keypassphrases24 = setmetatable({
  ["none"] = "" ,
  ["wpa2-psk"] = content.wpakey24,
  ["wpa-wpa2-psk"] = content.wpakey24,
}, untaint_mt )

local keypassphrases5 = setmetatable({
  ["none"] = "" ,
  ["wpa2-psk"] = content.wpakey5,
  ["wpa-wpa2-psk"] = content.wpakey5,
}, untaint_mt )

-- QR-Code escape function for SSID and PSK strings
-- the following characters needs to be escaped with a backslash (\): backslash (\), single-quote ('), double-quote ("),
-- dot (.), colon (:), comma (,), and semicolon (;)
-- we have the lua and the JavaScript escaping to pass as well, that's way you see so many backslashes
local qrcode_escape_entities = {  ["\\"] = "\\\\", ["\'"] = "\\'", ['"'] = '\\"',
["."] = "\\.", [":"] = "\\:", [","] = "\\,", [";"] = "\\;" }
local javascript_escape_entities = {  ["\\"] = "\\\\", ["\'"] = "\\'", ['"'] = '\\"'}

--Use WLAN configuratin to compose a string: "WIFI:T:WEP;S:mynetwork;P:mypassword;;"
--These parameters are needed: SSID, Security Mode and password
local wlanconfstr24 = ""
local wlanconfstr5 = ""
if content.ssid24 and content.ssid5 then
  local mode24 =  secmodes[content.secmode24]
  local mode5 =  secmodes[content.secmode5]
  local password24 = keypassphrases24[content.secmode24]
  local password5 = keypassphrases5[content.secmode5]
  local ssid24 = content.ssid24
  local ssid5 = content.ssid5
  local public24 = content.public24
  local public5 = content.public5
  --qr code escaping of dynamic data
  ssid24 = ssid24:gsub('[\\\'".:,;]', qrcode_escape_entities)
  ssid5 = ssid5:gsub('[\\\'".:,;]', qrcode_escape_entities)
  password24 = password24:gsub('[\\\'".:,;]', qrcode_escape_entities)
  password5 = password5:gsub('[\\\'".:,;]', qrcode_escape_entities)

  local hidden = ";H:false;;"
  if public24 == "0" then
    hidden = ";H:true;;"
  end

  if public5 == "0" then
    hidden = ";H:true;;"
  end

  if mode24 == "nopass" then
    wlanconfstr24  = "WIFI:T:" .. mode24 .. ";S:" .. ssid24 .. hidden
  else
    wlanconfstr24  = "WIFI:T:" .. mode24 .. ";S:" .. ssid24 .. ";P:" .. password24 .. hidden
  end

  if mode5 == "nopass" then
    wlanconfstr5  = "WIFI:T:" .. mode5 .. ";S:" .. ssid5 .. hidden
  else
    wlanconfstr5 = "WIFI:T:" .. mode5 .. ";S:" .. ssid5 .. ";P:" .. password5 .. hidden
  end

  --javascript escaping of special characters
  wlanconfstr24 = string.untaint(wlanconfstr24:gsub('[\\\'"]', javascript_escape_entities))
  wlanconfstr5 = string.untaint(wlanconfstr5:gsub('[\\\'"]', javascript_escape_entities))
end
  ngx.print('\
<script src="/js/qrcode.js"></script>\
<div style="font-weight:  bold;" class="row no-margin-right">\
  <div class="col-xs-12 col-md-12 col-sm-12">\
    <h1>\
      <span>');  ngx.print(T"Ways to connect to Wi-Fi and modem"); ngx.print('\
      </span>\
    </h1>\
  </div>\
</div>\
\
<div style="padding-bottom: 25px;">\
  <div class="row not-flex-row">\
    <div class="col-xs-12 col-md-6 col-sm-6 padding-right-pc paddingRight15">\
      <span style="font:bold">');  ngx.print(T"5 GHz Wi-Fi (Preferred)"); ngx.print('</span>\
      <div>\
        <span class="light-font">');  ngx.print(T"5 GHz Wi-Fi has the best performance over a shorter range for most devices. If your device cannot find it, use 2.4 GHz"); ngx.print('</span>\
      </div>\
    </div>\
    <div class="col-xs-12 col-md-6 col-sm-6 padding-left-pc paddingLeft15">\
      <span style="font:bold">');  ngx.print(T"2.4 GHz Wi-Fi"); ngx.print('</span>\
      <div><span class="light-font">');  ngx.print(T"2.4 GHz Wi-Fi is slower but has a longer range. so only connect to this if your device cannot find 5 GHz"); ngx.print('</span></div>\
    </div>\
  </div>\
</div>\
\
<div style="padding-bottom: 25px;">\
  <div class="row not-flex-row">\
    <div class="col-xs-12 col-md-6 col-sm-6 padding-right-pc paddingRight15">\
      <div style=" float:left">\
        <div>\
          <span class="light-font">');  ngx.print(content.ssid5); ngx.print('</span>\
        </div>\
        ');  if content.secmode5 ~= "none" then  ngx.print('\
          <div>\
            <span class="light-font">');  ngx.print(T"password:"); ngx.print('</span>\
          </div>\
          <div>\
            <span class="light-font">');  ngx.print(content.wpakey5); ngx.print('</span>\
          </div>\
        ');  end  ngx.print('\
      </div>\
      <div style=" float:right">\
        <div class="modal-body update">\
          <form class="form-horizontal" method="POST" action="modals/reminderCard.lp">\
            <fieldset>\
              <div id="qrcode_5G"><span style="width:0px"></span></div>\
            </fieldset>\
          </form>\
        </div>\
      </div>\
    </div>\
\
    <div class="col-xs-12 col-md-6 col-sm-6 padding-left-pc paddingLeft15">\
      <div class="left" style=" float:left">\
        <div>\
          <span class="light-font">');  ngx.print(content.ssid24); ngx.print('</span>\
        </div>\
        ');  if content.secmode24 ~= "none" then  ngx.print('\
          <div>\
            <span class="light-font">');  ngx.print(T"password:"); ngx.print('</span>\
          </div>\
          <div>\
            <span class="light-font">');  ngx.print(content.wpakey24); ngx.print('</span>\
          </div>\
        ');  end  ngx.print('\
      </div>\
      <div class="right" style=" float:right">\
        <div class="modal-body update">\
          <form class="form-horizontal" method="POST" action="modals/reminderCard.lp">\
            <fieldset>\
              <div id="qrcode_2G"></div>\
            </fieldset>\
          </form>\
        </div>\
      </div>\
    </div>\
  </div>\
</div>\
<div class="status-border-top" style="text-align: center;padding-top: 10px;padding-bottom: 10px;border-width: 2px;border-color: black;">\
  <div style="font-size: 20px;line-height:24px">\
    ');  ngx.print(T"To log into your modem go to http://" .. content.lanip .. T" or http://ultraplus.hub"); ngx.print('\
    <br>\
    ');  ngx.print(T"Login details are available on the label underneath your gateway."); ngx.print('\
  </div>\
</div>\
<div>\
  <p class="row padding-left padding-left-mobile left-select status-border-top" style="font-size: 19px; line-height: 20px; font-weight: normal;padding-top: 21px;border-width: 2px;border-color:  black;">\
    ');  ngx.print(T"To join via QR code, hover your mobile camera over the QR code to select and join automatically"); ngx.print('\
  </p>\
</div>\
<div>\
  <p style="font-size: 47px;font-weight: bold;padding-top: 32px;text-align: center;">\
    ');  ngx.print(T"IMPORTANT INFORMATION"); ngx.print('\
  </p>\
  <p style="padding-top: 23px;text-align: center;">\
    ');  ngx.print(T"PLEASE STORE THIS CARD IN A SAFE PLACE"); ngx.print('\
  </p>\
  <p style="padding-top: 24px;text-align: center;">\
    ');  ngx.print(T"If you change the Wi-Fi name or password you can reprint this card."); ngx.print('\
  </p>\
</div>\
<script>\
$(document).ready(function() {\
    var wlanconfstr5 = "');  ngx.print(wlanconfstr5); ngx.print('";\
    var typeNumber = 4;\
    var errorCorrectLevel = \'M\';\
    var qrcode_5 = qrcode(typeNumber, errorCorrectLevel);\
    qrcode_5.addData(wlanconfstr5);\
    qrcode_5.make();\
    qrcode_5.createImgTag(typeNumber);\
    var html = qrcode_5.createTableTag(typeNumber);\
    $("#qrcode_5G").html(html)\
    $(\'#qrcode_5G table\').css(\'width\', \'auto\')\
    $(\'#qrcode_5G table\').css(\'margin\', \'0px\')\
\
    var wlanconfstr24 = "');  ngx.print(wlanconfstr24); ngx.print('";\
    var typeNumber = 4;\
    var errorCorrectLevel = \'M\';\
    var qrcode_24 = qrcode(typeNumber, errorCorrectLevel);\
    qrcode_24.addData(wlanconfstr24);\
    qrcode_24.make();\
    qrcode_24.createImgTag(typeNumber);\
    var html = qrcode_24.createTableTag(typeNumber);\
    $("#qrcode_2G").html(html);\
    $(\'#qrcode_2G table\').css(\'width\', \'auto\');\
    $(\'#qrcode_2G table\').css(\'margin\', \'0px\')\
});\
</script>\
'); 