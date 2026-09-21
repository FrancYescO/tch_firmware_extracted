--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local table, string = table, string
local tonumber = tonumber
local format, match = string.format, string.match

-- devices forwarding rules
local devices_columns = {
  {--[1]
    header = T"Status",
    name = "state",
    param = "State",
    type = "light",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  {--[2]
    header = T"Hostname",
    name = "FriendlyName",
    param = "FriendlyName",
    type = "text",
    readonly = true,
    attr = { input = { class="span3" } },
  },
  {--[3]
    header = T"IP address",
    name = "ipaddress",
    param = "IPAddress",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } },
  },
  {--[4]
    header = T"MAC address",
    name = "macaddress",
    param = "MACAddress",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } },
  },
  {--[5]
    header = T"Type",
    name = "interfacetype",
    param = "InterfaceType",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } },
  },
  {--[6]
    header = T"Port",
    name = "port",
    param = "Port",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
  {--[7]
    header = T"Priority",
    name = "priority",
    param = "Priority",
    type = "text",
    readonly = true,
    attr = { input = { class="span3" } },
  },
  { --[8]
    header = T"Priority",
    name = "priority",
    param = "Priority",
    type = "switch",
    readonly = false,
    attr = { input = { class="span3" } },
  }

}

local device_valid = {}
local devices_options = {
    canEdit = true,
    canAdd = false,
    canDelete = false,
    tableid = "devices",
    basepath = "sys.hosts.host.",
}


--add a device filter to remove the table line in case we have a host connected by FON.
local devices_filter = function(data)
  if match(data["L2Interface"], "^wl0") then
    data["InterfaceType"] = "wireless - 2.4GHz"
  elseif match(data["L2Interface"], "^wl1") then
    data["InterfaceType"] = "wireless - 5GHz"
  elseif match(data["L2Interface"], "^wds%d+") then
    data["InterfaceType"] = "wireless"
  elseif match(data["L2Interface"], "eth*") then
    data["InterfaceType"] = "ethernet"
  elseif match(data["L2Interface"], "moca*") then
    data["InterfaceType"] = "MoCA"
  end
  return true
end

local devices_data, devices_helpmsg = post_helper.handleTableQuery(devices_columns, devices_options, devices_filter, nil, device_valid)

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. format("%s", uri:match("/([^/]+)%.lp")) }
  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"Devices", false, true, nil, help_link) ); ngx.print('\
\
<div class="modal-body update">\
  <form class="form-horizontal" method="post" action="modals/device-modal.lp">\
    ');  
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      ngx.print('\
\
    <fieldset>\
      <legend>');  ngx.print( T"Devices" ); ngx.print('</legend>\
      ');  ngx.print( ui_helper.createTable(devices_columns, devices_data, devices_options, nil, devices_helpmsg) ); ngx.print('\
    </fieldset>\
  </form>\
</div>\
\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
<script>\
    var priority_toggle;\
    $("#devices thead" ).find("th:nth-child(7)").addClass("hide");\
    $("#devices tbody tr").each(function (key, val) {\
    var obj = $(this)\
    if(obj.children("td").find("div").hasClass("off")){\
      obj.children("td:nth-child(7), td:nth-child(8)").html("");\
    }\
    priority_toggle = obj.children("td:nth-child(7)").text();\
    if(priority_toggle != ""){\
      obj.children("td:nth-child(7)").text((priority_toggle=="1")?"ON" : "OFF");\
    }\
    if(obj.hasClass("line-edit")){\
      obj.children("td:nth-child(7)").addClass("hide");\
    }\
    else {\
      obj.children("td:nth-child(8)").addClass("hide");\
    }\
    });\
</script>\
'); 