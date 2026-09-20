--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local find, match = string.find, string.match

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
    header = T"Priority",
    name = "priority",
    param = "Priority",
    type = "switch",
    readonly = false,
    attr = { input = { class="span3" } },
  },
  {--[3]
    header = T"Hostname",
    name = "hostname",
    param = "HostName",
    type = "text",
    readonly = true,
    attr = { input = { class="span3" } },
  },
  {--[4]
    header = T"IP address",
    name = "ipaddress",
    param = "IPAddress",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } },
  },
  {--[5]
    header = T"MAC address",
    name = "macaddress",
    param = "MACAddress",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } },
  },
  {--[6]
    header = T"Type",
    name = "interfacetype",
    param = "InterfaceType",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } },
  },
  {--[7]
    header = T"Port",
    name = "port",
    param = "Port",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } },
  },
}

local devices_options = {
    canEdit = true,
    canAdd = false,
    canDelete = false,
    tableid = "devices",
    basepath = "sys.hosts.host.",
}

--add a device filter to remove the table line in case we have a host connected by FON.
local devices_filter = function(data)
  -- Do not display devices not in the LAN bridge
  if data["FirewallZone"] == "LAN" then
    if data["InterfaceType"] == "wireless" then
      if match(data["L2Interface"], "^wl0") then
        data["InterfaceType"] = data["InterfaceType"].." - 2.4GHz"
      elseif match(data["L2Interface"], "^wl1") then
        data["InterfaceType"] = data["InterfaceType"].." - 5GHz"
      end
    end
     return true
  else
    return false
  end
end
-- Get the DSL "mode" connected
local datarows = {xdsl = "sys.class.xdsl.@line0.ModulationType" }
content_helper.getExactContent(datarows)
local devices_data, device_helpmsg = {}, {}
-- Currently the following modes are supported by the "mapping" file
-- "ADSL_G.dmt",
-- "ADSL_G.lite",
-- "ADSL_G.dmt.bis",
-- "ADSL_re-adsl",
-- "ADSL_2plus",
-- "ADSL_four",
-- "ADSL_ANSI_T1.413",
-- All the modes are starting with "ADSL". So i am checking if mode is starting with "ADSL"
-- If connected mode is not "ADSL", remove the "Priority" field.
if not find(datarows.xdsl, "ADSL") then
  table.remove(devices_columns , 2)
  devices_options.canEdit = false
end
devices_data, devices_helpmsg = post_helper.handleTableQuery(devices_columns, devices_options, devices_filter, nil, nil)
  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"Devices", false, true) ); ngx.print('\
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
$("#devices tbody tr").each(function (key, val) {\
  var obj = $(this)\
  if(obj.children("td").find("div").hasClass("off")){\
    obj.children("td:nth-child(2)").html("");\
  }\
  });\
</script>\
'); 