--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain("webui-core")

local untaint, gmatch, gsub = string.untaint, string.gmatch, string.gsub
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local format = string.format
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
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

local mac5g, agent_devices_columns, agent_devices_options, devices_filter
local radio5G =
  content_helper.convertResultToObject(
  "rpc.multiap.device.@" .. getiface .. ".radio.",
  proxy.get("rpc.multiap.device.@" .. getiface .. ".radio.")
)

if radio5G then
  for k, l in pairs(radio5G) do
    if not mac5g then
      for m, n in pairs(l) do
        if m == "freq" and n == "radio_5G" then
          mac5g = untaint(radio5G[k]["radio_id"])
        end
      end
    end
  end
end

if mac5g then
  agent_devices_columns = {
    {
      --[1]
      header = T"BSSID",
      name = "bssid",
      param = "bssid",
      type = "text",
      readonly = true,
      attr = {input = {class = "span1"}}
    },
    {
      --[2]
      header = T"SSID",
      name = "ssid",
      param = "ssid",
      type = "text",
      readonly = true,
      attr = {input = {class = "span3"}}
    },
    {
      --[3]
      header = T"Type",
      name = "bssType",
      param = "bss_type",
      type = "text",
      readonly = true,
      attr = {input = {class = "span3"}}
    },
    {
      --[4]
      header = T"No of STA",
      name = "No_of_stations",
      param = "paramindex",
      type = "text",
      readonly = true,
      attr = {input = {class = "span3"}}
    },
    {
      --[5]
      header = T"List of STA MacAddress",
      name = "list_stations",
      param = "sta_list",
      type = "text",
      readonly = true,
      attr = {input = {class = "span1"}}
    }
  }

  agent_devices_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "devices",
    basepath = format("rpc.multiap.device.@%s.radio.@%s.bss.@.", getiface, mac5g)
  }

  devices_filter = function(data)
    local sta_count = 0
    for i, j in pairs(data) do
      if i == "sta_list" and j ~= "" then
        for z in gmatch(j, "([^%s]+)") do
          sta_count = sta_count + 1
        end
        data["paramindex"] = sta_count
      else
        data["paramindex"] = sta_count
      end
    end
    return true
  end
end

local devices_data, devices_helpmsg =
  post_helper.handleTableQuery(agent_devices_columns, agent_devices_options, devices_filter)

local content = {}
if mac5g then
  content = {
    Radio_Id = "rpc.multiap.device.@" .. getiface .. ".radio.@" .. mac5g .. ".radio_id",
    Frequency_Band = "rpc.multiap.device.@" .. getiface .. ".radio.@" .. mac5g .. ".freq",
    Capability = "rpc.multiap.device.@" .. getiface .. ".radio.@" .. mac5g .. ".cap",
    Security_Mode = "rpc.multiap.device.@" .. getiface .. ".radio.@" .. mac5g .. ".sec",
    Operating_class = "rpc.multiap.device.@" .. getiface .. ".radio.@" .. mac5g .. ".op_class",
    Channel = "rpc.multiap.device.@" .. getiface .. ".radio.@" .. mac5g .. ".channel",
    Bandwidth = "rpc.multiap.device.@" .. getiface .. ".radio.@" .. mac5g .. ".bw",
    Transmit_Power = "rpc.multiap.device.@" .. getiface .. ".radio.@" .. mac5g .. ".tx_pwr",
    No_of_BSS = "rpc.multiap.device.@" .. getiface .. ".radio.@" .. mac5g .. ".bss_count"
  }
  content_helper.getExactContent(content)
end

local tab = {
  {
    desc = T"Status",
    target = "modals/agent-list.lp"
  },
  {
    desc = T"2.4GHZ",
    target = "modals/agent-list-2g.lp"
  },
  {
    desc = T"5GHZ",
    active = "active",
    target = "modals/agent-list-5g.lp"
  }
}

lp.setpath("/www/snippets/")
ngx.print(ui_helper.createHeader(T"EasyMesh Info", false, true))
  ngx.print('\
<form class="form-horizontal" method="post" action="');  ngx.print(ngx.var.request_uri); ngx.print('">\
  <div class="modal-body update">\
    <div class="container">\
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
              local url = "modals/agent-list-5g.lp?iface="..agent_mac
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
        </ul>\
      </div>\
      ');  html = {}   ngx.print('\
      <div class="span6">\
        ');  
        ngx.print(ui_helper.createModalTabs(tab))
        ngx.print('<legend>');  ngx.print(T"5GHz" ); ngx.print('</legend>');
        html[#html + 1] = ui_helper.createLabel(T"Radio ID", content["Radio_Id"] or "")
        html[#html + 1] = ui_helper.createLabel(T"Frequency Band", content["Frequency_Band"] or "")
        html[#html + 1] = ui_helper.createLabel(T"Capability", content["Capability"] or "")
        html[#html + 1] = ui_helper.createLabel(T"Security Mode", content["Security_Mode"] or "")
        html[#html + 1] = ui_helper.createLabel(T"Operating class", content["Operating_class"] or "")
        html[#html + 1] = ui_helper.createLabel(T"Channel", content["Channel"] or "")
        html[#html + 1] = ui_helper.createLabel(T"Bandwidth", content["Bandwidth"] or "")
        html[#html + 1] = ui_helper.createLabel(T"Transmit Power", content["Transmit_Power"] or "")
        html[#html + 1] = ui_helper.createLabel(T"No of BSS", content["No_of_BSS"] or "")
        ngx.print(html);
        html={}
          ngx.print('\
        <legend>List of connected STA</legend>\
        ');  
        html[#html + 1] = ui_helper.createTable(agent_devices_columns, devices_data, agent_devices_options, nil, devices_helpmsg)
        ngx.print(html);
          ngx.print('\
      </div>\
    </div>\
  </div>\
</form>\
\
<script>\
  $("ul.nav.nav-tabs:first, .btn-close").click(function() {\
    var data = [{ name : "action", value : "removeMac" }, { name : "CSRFtoken", value : $("meta[name=CSRFtoken]").attr("content") }]\
    $.post("modals/agent-list.lp" , data)\
  })\
</script>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 