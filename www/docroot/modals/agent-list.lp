--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain("webui-core")

local untaint, gsub, format = string.untaint, string.gsub, string.format
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local lp = require("web.lp")
local ngx = ngx
local session = ngx.ctx.session

local agentMac = proxy.get("rpc.multiap.device.")
local agentObj = content_helper.convertResultToObject("rpc.multiap.device.", agentMac)
local getargs = ngx.req.get_uri_args()
local getiface = untaint(getargs.iface)

if getiface then
  session:store("mac", getiface)
end
getiface = untaint(session:retrieve("mac"))

if next(agentObj) then
  for i, j in pairs(agentObj) do
    if not getiface then
      getiface = gsub(agentObj[i].paramindex, "@", "") or ""
    end
  end
end

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "removeMac" then
  ngx.header.content_type = "application/json"
  session:store("mac", nil)
  ngx.print('{"status":"success"}')
  ngx.sleep(1)
  ngx.exit(ngx.HTTP_OK)
end

local content = {}
if getiface then
  content = {
    Mac_address = "rpc.multiap.device.@" .. getiface .. ".al_mac",
    Ip_address = "rpc.multiap.device.@" .. getiface .. ".ip_address",
    Status = "rpc.multiap.device.@" .. getiface .. ".state",
    BH_connection_type = "rpc.multiap.device.@" .. getiface .. ".backhaul_interface_type",
    Manufacturer_name = "rpc.multiap.device.@" .. getiface .. ".manufacturer_name",
    Serial_number = "rpc.multiap.device.@" .. getiface .. ".serial_number",
    Signal_strength = "rpc.multiap.device.@" .. getiface .. ".rssi",
    Backhaul_datalink_rate = "rpc.multiap.device.@" .. getiface .. ".phyrate",
    No_of_radios = "rpc.multiap.device.@" .. getiface .. ".radio_count"
  }
  content_helper.getExactContent(content)
end

local tab = {
  {
    desc = T"Status",
    active = "active",
    target = "modals/agent-list.lp"
  },
  {
    desc = T"2.4GHZ",
    target = "modals/agent-list-2g.lp"
  },
  {
    desc = T"5GHZ",
    target = "modals/agent-list-5g.lp"
  }
}

lp.setpath("/www/snippets/")
ngx.print(ui_helper.createHeader(T"EasyMesh Info", false, true))
  ngx.print('\
<form class="modal-body form-horizontal" method="post" action="');  ngx.print(ngx.var.request_uri); ngx.print('">\
  ');  
  lp.include("tabs-easyMesh.lp")
  local html={}
  if next(agentObj) then
    ngx.print('\
  <div class="span2">\
    <ul class="nav nav-list">\
      ');  
      html[#html+1] = format('<li class="nav-header">%s</li>', T"Connected Devices")
      local active = ""
      for k,v in pairs(agentObj) do
        if agentObj[k].paramindex then
          local agent_mac = gsub(agentObj[k].paramindex, "@" , "")
          if agent_mac == getiface then
            active = "active"
          end
          local url = "modals/agent-list.lp?iface="..agent_mac
          local device_name = agentObj[k].device_name and agentObj[k].device_name or "Unknown-"..agent_mac
          html[#html+1] = format('<li class="%s"><a  id = "Agent_Tab_%s" href="#" data-remote="%s">%s</a></li>', active, k, url, device_name)
        end
        active = ""
      end
    else
      local infomessage = {
        alert = {
          class = "alert-info"
        }
      }
      local info = format("<p>No extenders are connected. </p>")
      html[#html + 1] = ui_helper.createAlertBlock(T(info), infomessage)
    end
    ngx.print(html);
      ngx.print('\
  </div>\
  ');  
  if next(content) then
  html={}
    ngx.print('\
  <div class="span6">\
    ');  
    ngx.print(ui_helper.createModalTabs(tab))
    ngx.print('<legend>');  ngx.print(T"Agent Information" ); ngx.print('</legend>');
    html[#html + 1] = ui_helper.createLabel(T"MAC Address", content["Mac_address"] or "")
    html[#html + 1] = ui_helper.createLabel(T"IP Address", content["Ip_address"] or "")
    html[#html + 1] = ui_helper.createLabel(T"Status", content["Status"] or "")
    html[#html + 1] = ui_helper.createLabel(T"BH Connection Type", content["BH_connection_type"] or "")
    html[#html + 1] = ui_helper.createLabel(T"Manufacturer Name", content["Manufacturer_name"] or "")
    html[#html + 1] = ui_helper.createLabel(T"Serial Number", content["Serial_number"] or "")
    html[#html + 1] = ui_helper.createLabel(T"Signal Strength", content["Signal_strength"] or "")
    html[#html + 1] = ui_helper.createLabel(T"Backhaul Datalink Rate", content["Backhaul_datalink_rate"] or "")
    html[#html + 1] = ui_helper.createLabel(T"No. of Radios", content["No_of_radios"] or "")
    ngx.print(html);
      ngx.print('\
  </div>\
  ');  end  ngx.print('\
</form>\
\
<script>\
  $("ul.nav.nav-tabs:first, .btn-close").click(function() {\
    var data = [{ name : "action", value : "removeMac" }, { name : "CSRFtoken", value : $("meta[name=CSRFtoken]").attr("content") }]\
    $.post("modals/agent-list.lp" , data)\
  })\
</script>\
'); 