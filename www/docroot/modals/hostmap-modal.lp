<%
-- Localization
gettext.textdomain('webui-core')
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local taint_mt = require("web.taint").taint_mt
local type, setmetatable, random = type, setmetatable, math.random
local table, ipairs, istainted, format, print= table, ipairs, string.istainted, string.format, ngx.print
local eth0, eth1, eth2, eth3, wifi = {}, {}, {}, {}, {}

function generate_host(HostName,IPAddress,MACAddress,Speed,State)
   local fade = "" 
   if State == "0" then
      fade = "fadedtxt"
   end
   return format("<div><span class=\"centertxt host %s\" data-host=\"%s\" data-ip=\"%s\" data-MAC=\"%s\" data-speed=\"%s\" data-state=\"%s\">%s</span></div>",fade,HostName,IPAddress,MACAddress,Speed,State,HostName)
end
local content_helper = require("web.content_helper")
    
print(ui_helper.createHeader(T"Devices", false, true)) 
local tabs = {
    {
        desc = T"Devices List",
        target = "modals/device-modal.lp",
    },
    {
        desc = T"Devices Map",
        active = "active",
        target = "modals/hostmap-modal.lp",
    },
}
ngx.print(ui_helper.createModalTabs(tabs))
%>

<div class="modal-body update">
<form class="form-horizontal" method="post" action="modals/hostmap-modal.lp">
<fieldset>
<%
  local html = {} 
  local ch = require("web.content_helper")
  
  local  hosts = proxy.get("sys.hosts.host.")
  local hosts = ch.convertResultToObject("sys.hosts.host.",hosts)
  for x=1, #hosts, 1 do
  
  
   --if hosts[x].State == "1" then
      local displayname = hosts[x].HostName
      if displayname == "" then
         hosts[x].HostName = T"Unknown"..hosts[x].MACAddress:sub(-6)
      end
      local intf = hosts[x].L2Interface
      --print(format("<script>alert('%s')</script>",intf))
      if       intf == "eth0" then eth0[#eth0+1] = hosts[x] 
      elseif   intf == "eth1" then eth1[#eth1+1] = hosts[x] 
      elseif   intf == "eth2" then eth2[#eth2+1] = hosts[x] 
      elseif   intf == "eth3" then eth3[#eth3+1] = hosts[x] 
      else     wifi[#wifi+1] = hosts[x] 
      end

   --end
  end
  local usb = proxy.get("sys.usb.device.")
  local usb = ch.convertResultToObject("sys.usb.device.",usb)
  
  
  local  cpename = format("%s", proxy.get("uci.env.var.prod_friendly_name")[1].value)
  
  html[#html+1]=format("<legend>%s</legend>",T"Ethernet Ports")
  html[#html+1]="<table class=\"hostmaptable\">"
  html[#html+1]=format("<tr class=\"grey\"><td class=\"centertxt centertitle\">%s</td><td class=\"centertxt centertitle\">%s</td><td class=\"centertxt centertitle\">%s</td><td class=\"centertxt centertitle\">%s</td></tr>",T"Port 1",T"Port 2",T"Port 3",T"Port 4")
  html[#html+1]="<tr>"
  --ETH0
  html[#html+1]="<td class=\"twentyfive\">"
  for x=1, #eth0, 1 do
      html[#html+1] = generate_host(eth0[x].HostName, eth0[x].IPAddress, eth0[x].MACAddress, eth0[x].Speed, eth0[x].State)
  end

  html[#html+1]="</td>"
  --ETH1
  html[#html+1]="<td class=\"twentyfive\">"
  for x=1, #eth1, 1 do
      html[#html+1] = generate_host(eth1[x].HostName, eth1[x].IPAddress, eth1[x].MACAddress, eth1[x].Speed, eth1[x].State)
  end
  html[#html+1]="</td>"
  --ETH2
  html[#html+1]="<td class=\"twentyfive\">"
  for x=1, #eth2, 1 do
      html[#html+1] = generate_host(eth2[x].HostName, eth2[x].IPAddress, eth2[x].MACAddress, eth2[x].Speed, eth2[x].State)
  end
  html[#html+1]="</td>"
  --ETH3
  html[#html+1]="<td class=\"twentyfive\">"
  for x=1, #eth3, 1 do
      html[#html+1] = generate_host(eth3[x].HostName, eth3[x].IPAddress, eth3[x].MACAddress, eth3[x].Speed, eth3[x].State)
  end
  html[#html+1]="</td></tr></table><br/>"
  --WIFI

  
  
  --Wireless
  local wifiintf = proxy.get("uci.wireless.wifi-iface.")
  local wifiintf = ch.convertResultToObject("uci.wireless.wifi-iface.",wifiintf)
  local paramindex = {}
  local wifispan = 100 / #wifiintf
  html[#html+1]=format("<script>$(\".wifilist\").css({\"width\":\"%s%s\"})</script>",wifispan,"%")
  html[#html+1]=format("<legend>%s</legend>",T"Wireless Networks")
  html[#html+1]="<table class=\"hostmaptable\">"
  html[#html+1]="<tr class=\"grey\">"
  for x=1, #wifiintf, 1 do
      local disabled, radio = "","2.4GHz"
      paramindex[x] = wifiintf[x].paramindex
      if wifiintf[x].state == "0" then disabled = "wifidisabled" end
      if wifiintf[x].device ~= "radio_2G" then radio = "5GHz" end
      html[#html+1]=format("<td class=\"centertxt centertitle %s wifilist\">%s (%s)</td>",disabled, wifiintf[x].ssid, radio)
  end
  html[#html+1]="</tr><tr>"
  for x=1, #paramindex, 1 do
      html[#html+1]="<td class=\"twentyfive wifilist\">"
      for y=1, #wifi, 1 do
         ngx.log(ngx.ERR, format("paramindex %s L2Interface %s",paramindex[x]:sub(-3),wifi[y].L2Interface))
         ngx.log(ngx.ERR, format("Host %s",wifi[y].HostName))
         if paramindex[x]:sub(-3) == wifi[y].L2Interface then
         
            html[#html+1] = generate_host(wifi[y].HostName, wifi[y].IPAddress, wifi[y].MACAddress, wifi[y].Speed, wifi[y].State)
         end
      end
  
      html[#html+1]="</td>"
   
  end
  html[#html+1]="</tr></table>"
  
  
  print(html)
%>

</fieldset>
</form>
</div>

<%= ui_helper.createFooter() %>


<script type='text/javascript'>
   
function Popup(Title,txt){
    var moveLeft = 10;
    var moveRight = -390;
    var moveDown = -50;
    var header = '<div class="header"><div  class="header-title pull-left"><p id="poptitle"></p></div></div>';
   $("body").append('<div class=\"popUpBG\"></div>');
   $("body").append('<div id="popUp"  class="smallcard span4">'+header+'<div id="Poptxt" class="content"></div>');
   $("#poptitle").html(Title);    
   $("#Poptxt").html(txt);
   $d = $("#popUp");
   var pagewidth = $("body").width();
   var thiswidth = $d.width();
   var center = (pagewidth / 2) - (thiswidth / 2);
   var width = window.innerWidth || document.documentElement.clientWidth;
   $d.css({'left': center, 'height': '200px', 'margin' : '0px', 'border-radius': '13px'}).appendTo('body').slideDown("fast");
   
  $( ".popUpBG" ).click(function() {
        $(".popUpBG").remove();
        $("#popUp").remove();
  });
  $( "#popUp" ).click(function() {
        $(".popUpBG").remove();
        $("#popUp").remove();
  });   
}  
   $(function() {
      
      $( ".host" ).click(function(e) {
        var host = $(this).html();
        var ip = ($(this).attr('data-ip') != "" ? $(this).attr('data-ip') : "<%=T"No IP"%>");

        var mac = $(this).attr('data-mac');
        var speed = ($(this).attr('data-state') == "1" ? $(this).attr('data-speed')+" Mbs" : "<%=T"Last"%>@ "+$(this).attr('data-speed')+" Mbs");

        var state = ($(this).attr('data-state') == "1" ? "<%=T"Online"%>" : "<%=T"Offline"%>");
        var ips=ip.split(' ');
        var txt = "<div class=\"ctsinfoline\"><span class=\"hostinfoleft\"><%=T"IP Address"%></span><span class=\"hostinforight\">"+ips[0]+"</span></div>";
        if (ips[1]) {
            txt = txt + "<div class=\"ctsinfoline\"><span class=\"hostinfoleft\">&nbsp;</span><span class=\"hostinforight\">"+ips[1]+"</span></div>";
        
        }
        
        txt = txt + "<div class=\"ctsinfoline\"><span class=\"hostinfoleft\"><%=T"MAC Address"%></span><span class=\"hostinforight\">"+mac+"</span></div>";
        txt = txt + "<div class=\"ctsinfoline\"><span class=\"hostinfoleft\"><%=T"Speed"%></span><span class=\"hostinforight\">"+speed+"</span></div>";
        txt = txt + "<div class=\"ctsinfoline\"><span class=\"hostinfoleft\"><%=T"Status"%></span><span class=\"hostinforight\">"+state+"</span></div>";
        
        Popup(host,txt)
        });
  });
     
         

</script>
<%

%>
