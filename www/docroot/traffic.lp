<%
local lp = require("web.lp")
lp.setpath("/www/snippets/")
lp.include("header.lp")
lp.include("navbar.lp")
lp.include("menubar.lp")
lp.include("message.lp")
%>
<script src ="/js/graphic-min.js"></script>
<%
-- Localization
gettext.textdomain('webui-telstra')

local table, ipairs, require, ngx, io = table, ipairs, require, ngx, io
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local format = string.format
local tonumber = tonumber

local getargs = ngx.req.get_uri_args()
local getiface = getargs.iface

local curiface = "wl0"
local curssid = ""

local fonpath = "uci.hotspotd.wifi-iface."
local fonifaces = content_helper.convertResultToObject(fonpath .. "@.", proxy.get(fonpath))

local ssidMap = {}

for i,v in ipairs(fonifaces) do
    local iface = string.format("%s", v.iface)
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
            curssid = v.ssid
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

local attributes = {
  label = { class = "control-llabel" } ,
  span = { class = "span2 text-right" } ,
}

local wan_intf ="wan"
local ipaddr = proxy.get("rpc.network.interface.@wwan.ipaddr")[1].value
if ipaddr:len() ~= 0 then
  wan_intf = "wwan"
end

local content_wan = {
  tx_bytes = "rpc.network.interface.@" .. wan_intf .. ".tx_bytes",
  rx_bytes = "rpc.network.interface.@" .. wan_intf .. ".rx_bytes",
  ifname = "uci.network.interface.@" .. wan_intf .. ".ifname",
}
content_helper.getExactContent(content_wan)

local content_lan = {
  tx_bytes = "rpc.network.interface.@lan.tx_bytes",
  rx_bytes = "rpc.network.interface.@lan.rx_bytes",
  ifname = "uci.network.interface.@lan.ifname",
}
content_helper.getExactContent(content_lan)

local function s2n(str)
  if str == nil or str == "" then
    return 0
  else
    return tonumber(str)
  end
end

local function b2m(number)
  return format("%.3f", number / 1048576)
end

local wantx = b2m(s2n(content_wan.tx_bytes))
local wanrx = b2m(s2n(content_wan.rx_bytes))
local lantx = b2m(s2n(content_lan.tx_bytes))
local lanrx = b2m(s2n(content_lan.rx_bytes))

local wifitx, wifirx = 0, 0
local content_wifi = {}
for i,v in ipairs(wls) do
    content_wifi["tx_bytes"] = "sys.class.net.@" .. v.iface .. ".statistics.tx_bytes"
    content_wifi["rx_bytes"] = "sys.class.net.@" .. v.iface .. ".statistics.rx_bytes"
    content_helper.getExactContent(content_wifi)
    wifitx = wifitx + s2n(content_wifi.tx_bytes)
    wifirx = wifirx + s2n(content_wifi.rx_bytes)
end
wifitx = b2m(wifitx)
wifirx = b2m(wifirx)

local wantotal = format("%.3f", wantx + wanrx)
local lantotal = format("%.3f", lantx + lanrx)
local wifitotal = format("%.3f", wifitx + wifirx)

local function getTrafficData(dtype, name)
    local nline = 1
    local data = ""
    filename = string.format("/var/trafficmon/%s_%s", name, dtype)
    f = io.open(filename, "r")
    if f then
        for line in f:lines() do
            if (nline == 1) then
                nline = 2
            elseif (nline == 2) then
                nline = 3
                data = line
            else
                data = data .. "," .. line
            end
        end
        f:close()
    end
    return data
end

local wanTx, wanRx, lanTx, lanRx, wifiTx, wifiRx
proxy.set("rpc.system.lock.datadir", "/var/trafficmon/")
local lock = proxy.get("rpc.system.lock.lock")[1].value
local count = 0
while lock ~= "1" and count < 5 do
    ngx.sleep(1)
    lock = proxy.get("rpc.system.lock.lock")[1].value
    count = count + 1
end

if count == 5 then
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

_, wanTx = pcall(getTrafficData, "tx_bytes", content_wan.ifname)
_, wanRx = pcall(getTrafficData, "rx_bytes", content_wan.ifname)
_, lanTx = pcall(getTrafficData, "tx_bytes", content_lan.ifname)
_, lanRx = pcall(getTrafficData, "rx_bytes", content_lan.ifname)
_, wifiTx = pcall(getTrafficData, "tx_bytes", curiface)
_, wifiRx = pcall(getTrafficData, "rx_bytes", curiface)
proxy.set("rpc.system.lock.free", "0")
%>

<div class="container toplevel">
<% lp.include("tabs-services.lp") %>
<div class="row">
<div class="span11">
<fieldset>
<form class="form-horizontal" >
<legend><%= T"Internet Traffic" %></legend>
<%
ngx.print(
  ui_helper.createLabel(T"Total Send/Receive (in MB)", wantotal , attributes),
  ui_helper.createLabel(T"Total Send (in MB)", wantx, attributes),
  ui_helper.createLabel(T"Total Receive (in MB)", wanrx, attributes)
)
%>
<legend><%= T"Ethernet Network Traffic" %></legend>
<%
ngx.print(
  ui_helper.createLabel(T"Total Send/Receive (in MB)", lantotal , attributes),
  ui_helper.createLabel(T"Total Send (in MB)", lantx, attributes),
  ui_helper.createLabel(T"Total Receive (in MB)", lanrx, attributes)
)
%>
<legend><%= T"Wi-Fi Network Traffic" %></legend>
<%
ngx.print(
  ui_helper.createLabel(T"Total Send/Receive (in MB)",  wifitotal , attributes),
  ui_helper.createLabel(T"Total Send (in MB)", wifitx, attributes),
  ui_helper.createLabel(T"Total Receive (in MB)", wifirx, attributes)
)
%>
</form>
</fieldset>
</div>
</div>
</div>

<div class="container toplevel">
<div class="row">
<div class="span11">
<table width="100%">
  <tr>
    <td style="background-color:red">&nbsp;&nbsp;&nbsp;&nbsp;</td>
    <td nowrap>Total Send/Receive<input type="checkbox" id="redLine" name="redLine" checked onclick="redrawLine()"/></td>
    <td style="background-color:green">&nbsp;&nbsp;&nbsp;&nbsp;</td>
    <td nowrap>Total Send<input type="checkbox" id="greenLine" name="greenLine" checked onclick="redrawLine()"/></td>
    <td style="background-color:blue">&nbsp;&nbsp;&nbsp;&nbsp;</td>
    <td nowrap>Total Receive<input type="checkbox" id="blueLine" name="blueLine" checked onclick="redrawLine()"/></td>
    <td width="40%">&nbsp;</td>
  </tr>
</table>

<div id="wanTraffic">
<div id ="wanLineDiv" style ="position:relative;height:350px;width:800px;"></div>
<center>Internet Traffic</center>
</div>

<div id="lanTraffic">
<div id ="lanLineDiv" style ="position:relative;height:350px;width:800px;"></div>
<center>Ethernet Network Traffic</center>
</div>

<ul class="nav nav-tabs">
  <%
    html = {}
    for i,v in ipairs(wls) do
        local active = ""
        if v.iface == curiface then
            active = "active"
        end
        local url = "traffic.lp?iface=" .. v.iface
        html[#html+1] = string.format('<li class="%s"><a href="%s" target="_self">%s</a></li>', active, url, v.ssid)
    end
    ngx.print(html)
  %>
</ul>
<div id="wifiTraffic">
<div id ="wifiLineDiv" style ="position:relative;height:350px;width:800px;"></div>
<center>Wi-Fi <%=curssid%> Network Traffic</center>
</div>

<script language ="javascript">
  var wanLine, lanLine, wifiLine;
  // Data will be done

  function redrawLine()
  {
      wanLine.clearLine();
      lanLine.clearLine();
      wifiLine.clearLine();
      drawInit();
  }

  function drawInit()
  {
      //Draw the line chart for internet triffic.
      wanLine = drawLineDiv("<%=wanTx%>", "<%=wanRx%>", "wan");

      //Draw the line chart for lan triffic.
      lanLine = drawLineDiv("<%=lanTx%>", "<%=lanRx%>", "lan");

      //Draw the line chart for wifi triffic.
      wifiLine = drawLineDiv("<%=wifiTx%>", "<%=wifiRx%>", "wifi");
  }

  drawInit();
</script>
</div>
</div>
</div>

<%
lp.include("footer.lp")
%>
