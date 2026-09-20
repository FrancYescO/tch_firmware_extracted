<%
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
%>
<!DOCTYPE HTML>
<%= string.format('<html lang="%s">', gettext.language()) %>
  <head>
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta charset="UTF-8">
    <meta name="CSRFtoken" content="<%= ngx.ctx.session:getCSRFtoken() %>">
    <link href="/css/gw.css" rel="stylesheet">
    <link href="/css/responsive.css" rel="stylesheet">
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->
    <script src="/js/main-min.js" ></script>
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->
    <title><%= T"IPTV Information" %></title>
  </head>

<body>
  <% if cui.versionmask:match("^%d%d%d9%d%d%d$") or cui.versionmask:match("^%d%d1%d%d%d%d$") then %>
    <div style="color: red; font-weight: bold; text-align: center; font-size:x-large; line-height:150%; background-color: yellow; border: 2px solid; border-color: red; border-radius: 4px;">Demo build, unofficial Technicolor SW, not suitable for deployment!</div>
  <% end %>
  <div class="feedback">

  </div>
    <div class="container">
    <div class="row">
      <div class="header span12">
        <a href="<%= cui.nsplink %>" target="_blank"><img src="/img/logo.gif"></a>
        <%
        local html = {}

        html[#html + 1] = [[<div class="pull-right">]]
        html[#html + 1] = ui_helper.createLanguageSelect('webui-telia', gettext.language())
        html[#html + 1] = [[</div>]]

        ngx.print(html)
        %>
      </div>
    </div>
    <div class="row">
      <table cellspacing='0' cellpadding='0'>
        <tr>
          <%
            --TODO get the cs or adapt classes
            --TODO get the image
          %>
          <td class='icon' valign='top' width='100px'><img src='/images/tbox__xl.gif' alt='Information'></td>
          <td class='data' valign='top'>
          <table cellspacing='0' cellpadding='0'>
            <tr><td align='left'><span class='itemtitle'>Information</span></td><td align='right'></td></tr>
            <tr><td align='left'>&nbsp;</td><td align='right'></td></tr>
          </table>
          <table cellspacing='0' cellpadding='0' class="infotable">
            <tr>
              <td class="blocktitle">1.&nbsp;</td>
              <td colspan="2"><span class='blocktitle'><a href="#"><%ngx.print(info) %></a></span></td>
              <td align='left'></td>
            </tr>
            <%
              if DSLType ~= "Ethernet" then
            %>
            <tr id="more1">
              <td class="index">1.1&nbsp;</td><td class="description"><span> <%ngx.print(str_DSLStatus) %> :</span></td>
              <td id='right'><span id='dslstatus'><%ngx.print(str_Unknown)%></span></td>
            </tr>
            <tr id="more2">
              <td class="index">1.2&nbsp;</td><td class="description"><span> <%ngx.print(str_Type) %> :</span></td>
              <td id='right'><span id="dsltype"><%ngx.print(str_Unknown)%></span></td>
            </tr>
            <tr id="more3">
              <td class="index">1.3&nbsp;</td><td class="description"><span> <%ngx.print(str_LineRate) %> :</span></td>
              <td id='right'><span id='dslup'><%ngx.print(str_Unknown)%></span>&nbsp;/&nbsp;<span id='dsldown'><%ngx.print(str_Unknown)%></span></td>
            </tr>
            <tr id="more4">
              <td class="index">1.4&nbsp;</td><td class="description"><span> <%ngx.print(str_NoiseMargin) %> :</span></td>
              <td id='right'><span id='dslnoup'><%ngx.print(str_Unknown)%></span>&nbsp;/&nbsp;<span id='dslnodown'><%ngx.print(str_Unknown)%></span></td>
            </tr>
            <tr id="more5">
              <td class="index">1.5&nbsp;</td><td class="description"><span> <%ngx.print(str_CVErr) %> :</span></td>
              <td id='right'><span id='dslcrcdown'><%ngx.print(str_Unknown)%></span></td>
            </tr>
            <%
              else
            %>
            <tr id="more6">
              <td class="index">1.1&nbsp;</td><td class="description"><span> <%ngx.print(str_Ethernetstate) %> :</span></td>
              <td id='right'><span id='ethtype'><%ngx.print(str_Unknown)%></span></td></tr>
            </tr>
            <tr id="more7">
              <td class="index">1.2&nbsp;</td><td class="description"><span> <%ngx.print(str_Ethernettype) %> :</span></td>
              <td id='right'><span id='ethstate'><%ngx.print(str_Unknown)%></span></td>
            </tr>
            <%
              end
            %>
          </table>
          <table cellspacing='0' cellpadding='0' class="infotable">
            <tr>
              <td class="blocktitle">2.&nbsp;</td>
              <td colspan="2"><span class='blocktitle'><a href="#"><%ngx.print(str_IGMP) %></a></span></td>
              <td align='left'></td>
            </tr>
            <tr>
              <td><strong><%ngx.print(T"Host") %></strong></td>
              <td align="right"><strong><%ngx.print(T"Multicast group") %></strong></td>
            </tr>
            <%
              local count = 1
              while (count <= 3) do
            %>
            <tr>
              <td colspan="1" witdh="10"><span id='igmphost'><%ngx.print(count.."."..count.."."..count.."."..count)%></span></td>
              <td colspan="1" align="right"><span id='igmpgroup'>255.255.255.255</span></td>
            </tr>
            <%
                count = count + 1
              end
            %>
          </table>
        </tr>
        <tr>
          <td></td>
          <td><input type="button" name="Refresh" value="Refresh" onclick='var URL = unescape(window.location.pathname);window.location.replace( URL );' /></td>
        </tr>
      </table>
    </div>
    <div class="row"><div class="copyright span12"><p>&copy; Technicolor 2016</p></div></div>
  </div>
</body>
</html>
