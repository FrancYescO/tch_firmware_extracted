--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-telia')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local cui = {
  nsplink = "uci.web.uiconfig.@uidefault.nsplink",
  versionmask = "uci.version.version.@version[0].mask",
}
content_helper.getExactContent(cui)

local str_IGMP = T"Multicast Information"
--TODO get this from somewhere logical
local DSLType = "Ethernet"
local info
if DSLType == "ADSL" or DSLType == "ADSL2+" then
  info = T"ADSL Information"
elseif DSLType == "VDSL" then
  info = T"VDSL Information"
else
  info = T"Ethernet Information"
end

local str_DSLStatus = T"DSL Status"
local str_Type = T"Type"
local str_LineRate = T"Line Rate (Up / Down)"
local str_NoiseMargin = T"Noise Margin (Up / Down)"
local str_CVErr = T"CV Errors"
local str_Ethernettype = T"Ethernet Type"
local str_Ethernetstate = T"Ethernet state"
local str_Unknown = T"Unknown"
  ngx.print('\r\
<!DOCTYPE HTML>\r\
');  ngx.print( string.format('<html lang="%s">', gettext.language()) ); ngx.print('\r\
  <head>\r\
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">\r\
    <meta name="viewport" content="width=device-width, initial-scale=1.0">\r\
    <meta charset="UTF-8">\r\
    <meta name="CSRFtoken" content="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\r\
    <link href="/css/gw.css" rel="stylesheet">\r\
    <link href="/css/responsive.css" rel="stylesheet">\r\
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->\r\
    <script src="/js/main-min.js" ></script>\r\
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->\r\
    <title>');  ngx.print( T"IPTV Information" ); ngx.print('</title>\r\
  </head>\r\
\r\
<body>\r\
  ');  if cui.versionmask:match("^%d%d%d9%d%d%d$") or cui.versionmask:match("^%d%d1%d%d%d%d$") then   ngx.print('\r\
    <div style="color: red; font-weight: bold; text-align: center; font-size:x-large; line-height:150%; background-color: yellow; border: 2px solid; border-color: red; border-radius: 4px;">Demo build, unofficial Technicolor SW, not suitable for deployment!</div>\r\
  ');  end   ngx.print('\r\
  <div class="feedback">\r\
\r\
  </div>\r\
    <div class="container">\r\
    <div class="row">\r\
      <div class="header span12">\r\
        <a href="');  ngx.print( cui.nsplink ); ngx.print('" target="_blank"><img src="/img/logo.gif"></a>\r\
        ');  
        local html = {}

        html[#html + 1] = [[<div class="pull-right">]]
        html[#html + 1] = ui_helper.createLanguageSelect('webui-telia', gettext.language())
        html[#html + 1] = [[</div>]]

        ngx.print(html)
          ngx.print('\r\
      </div>\r\
    </div>\r\
    <div class="row">\r\
      <table cellspacing=\'0\' cellpadding=\'0\'>\r\
        <tr>\r\
          ');  
            --TODO get the cs or adapt classes
            --TODO get the image
            ngx.print('\r\
          <td class=\'icon\' valign=\'top\' width=\'100px\'><img src=\'/images/tbox__xl.gif\' alt=\'Information\'></td>\r\
          <td class=\'data\' valign=\'top\'>\r\
          <table cellspacing=\'0\' cellpadding=\'0\'>\r\
            <tr><td align=\'left\'><span class=\'itemtitle\'>Information</span></td><td align=\'right\'></td></tr>\r\
            <tr><td align=\'left\'>&nbsp;</td><td align=\'right\'></td></tr>\r\
          </table>\r\
          <table cellspacing=\'0\' cellpadding=\'0\' class="infotable">\r\
            <tr>\r\
              <td class="blocktitle">1.&nbsp;</td>\r\
              <td colspan="2"><span class=\'blocktitle\'><a href="#">');  ngx.print(info)   ngx.print('</a></span></td>\r\
              <td align=\'left\'></td>\r\
            </tr>\r\
            ');  
              if DSLType ~= "Ethernet" then
              ngx.print('\r\
            <tr id="more1">\r\
              <td class="index">1.1&nbsp;</td><td class="description"><span> ');  ngx.print(str_DSLStatus)   ngx.print(' :</span></td>\r\
              <td id=\'right\'><span id=\'dslstatus\'>');  ngx.print(str_Unknown)  ngx.print('</span></td>\r\
            </tr>\r\
            <tr id="more2">\r\
              <td class="index">1.2&nbsp;</td><td class="description"><span> ');  ngx.print(str_Type)   ngx.print(' :</span></td>\r\
              <td id=\'right\'><span id="dsltype">');  ngx.print(str_Unknown)  ngx.print('</span></td>\r\
            </tr>\r\
            <tr id="more3">\r\
              <td class="index">1.3&nbsp;</td><td class="description"><span> ');  ngx.print(str_LineRate)   ngx.print(' :</span></td>\r\
              <td id=\'right\'><span id=\'dslup\'>');  ngx.print(str_Unknown)  ngx.print('</span>&nbsp;/&nbsp;<span id=\'dsldown\'>');  ngx.print(str_Unknown)  ngx.print('</span></td>\r\
            </tr>\r\
            <tr id="more4">\r\
              <td class="index">1.4&nbsp;</td><td class="description"><span> ');  ngx.print(str_NoiseMargin)   ngx.print(' :</span></td>\r\
              <td id=\'right\'><span id=\'dslnoup\'>');  ngx.print(str_Unknown)  ngx.print('</span>&nbsp;/&nbsp;<span id=\'dslnodown\'>');  ngx.print(str_Unknown)  ngx.print('</span></td>\r\
            </tr>\r\
            <tr id="more5">\r\
              <td class="index">1.5&nbsp;</td><td class="description"><span> ');  ngx.print(str_CVErr)   ngx.print(' :</span></td>\r\
              <td id=\'right\'><span id=\'dslcrcdown\'>');  ngx.print(str_Unknown)  ngx.print('</span></td>\r\
            </tr>\r\
            ');  
              else
              ngx.print('\r\
            <tr id="more6">\r\
              <td class="index">1.1&nbsp;</td><td class="description"><span> ');  ngx.print(str_Ethernetstate)   ngx.print(' :</span></td>\r\
              <td id=\'right\'><span id=\'ethtype\'>');  ngx.print(str_Unknown)  ngx.print('</span></td></tr>\r\
            </tr>\r\
            <tr id="more7">\r\
              <td class="index">1.2&nbsp;</td><td class="description"><span> ');  ngx.print(str_Ethernettype)   ngx.print(' :</span></td>\r\
              <td id=\'right\'><span id=\'ethstate\'>');  ngx.print(str_Unknown)  ngx.print('</span></td>\r\
            </tr>\r\
            ');  
              end
              ngx.print('\r\
          </table>\r\
          <table cellspacing=\'0\' cellpadding=\'0\' class="infotable">\r\
            <tr>\r\
              <td class="blocktitle">2.&nbsp;</td>\r\
              <td colspan="2"><span class=\'blocktitle\'><a href="#">');  ngx.print(str_IGMP)   ngx.print('</a></span></td>\r\
              <td align=\'left\'></td>\r\
            </tr>\r\
            <tr>\r\
              <td><strong>');  ngx.print(T"Host")   ngx.print('</strong></td>\r\
              <td align="right"><strong>');  ngx.print(T"Multicast group")   ngx.print('</strong></td>\r\
            </tr>\r\
            ');  
              local count = 1
              while (count <= 3) do
              ngx.print('\r\
            <tr>\r\
              <td colspan="1" witdh="10"><span id=\'igmphost\'>');  ngx.print(count.."."..count.."."..count.."."..count)  ngx.print('</span></td>\r\
              <td colspan="1" align="right"><span id=\'igmpgroup\'>255.255.255.255</span></td>\r\
            </tr>\r\
            ');  
                count = count + 1
              end
              ngx.print('\r\
          </table>\r\
        </tr>\r\
        <tr>\r\
          <td></td>\r\
          <td><input type="button" name="Refresh" value="Refresh" onclick=\'var URL = unescape(window.location.pathname);window.location.replace( URL );\' /></td>\r\
        </tr>\r\
      </table>\r\
    </div>\r\
    <div class="row"><div class="copyright span12"><p>&copy; Technicolor 2016</p></div></div>\r\
  </div>\r\
</body>\r\
</html>\r\
'); 