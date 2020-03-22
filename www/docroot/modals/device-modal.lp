--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
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
    header = T"Connection Time",
    name = "ConnectionTime",
    param = "ConnectedTime",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } },
  },
  {--[8]
    header = T"Lease time",
    name = "dhcpLeaseTime",
    param = "DhcpLeaseTime",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } },
  },
}

local device_valid = {}
local devices_options = {
    canEdit = false,
    canAdd = false,
    canDelete = true,
    tableid = "devices",
    basepath = "rpc.hosts.host.",
}

--Construct the device type based on value of L2Interface
local devices_filter = function(data)
  --Display only the IP Address of physically connected devices
  if data["State"] and data["State"] == "0" then
     data["IPAddress"] = ""
  end

  if match(data["L2Interface"], "^wl0") then
    data["InterfaceType"] = T"wireless - 2.4GHz"
  elseif match(data["L2Interface"], "^wl1") then
    data["InterfaceType"] = T"wireless - 5GHz"
  elseif match(data["L2Interface"], "eth*") then
    data["InterfaceType"] = T"Ethernet"
  end
  return true
end

local tprint = require("tch.tableprint")
local devices_data, devices_helpmsg = post_helper.handleTableQuery(devices_columns, devices_options, devices_filter , device_valid)

for k, v in pairs (devices_data) do
   devices_data[k][1] = format("%s",v[1])
   devices_data[k][5] = format("%s",v[5]:gsub("^%l", string.upper))

   if v[1] == "1" then
      if v[8] ~= "" then
        --v[7]=1498524635, os.time()=1498525323, v[8]=86400, the left lease time should be v[7]+v[8]-os.time()
        v[8] = post_helper.secondsToTime(tonumber(v[8])+ tonumber(v[7]) - os.time())
      else
        v[8]="-"
      end

      if v[7] ~= "" then
        v[7] = post_helper.secondsToTime(os.time()- tonumber(v[7]))
      else
        v[7] = "-"
      end
   else
      v[7] = "-"
      v[8] = "-"
   end
end

  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"Devices", false, true) ); ngx.print('\
<div class="modal-body update no-save">\
');  
if ngx.ctx.session:hasAccess("/modals/hostmap-modal.lp") then
    local tabs = {
        {
            desc = T"Devices List",
            active = "active",
            target = "modals/device-modal.lp",
        },
        {
            desc = T"Devices Map",
            target = "modals/hostmap-modal.lp",
        },
    }
    ngx.print(ui_helper.createModalTabs(tabs))
end
  ngx.print('\
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
\
\
<script>\
  $(function(){\
    $(\'#devices tbody tr\').each (function() {\
      var status_column = 0;\
      var light = $(this).find("td").eq(status_column).find("div");\
      var light_class = light.attr("class");\
      if (light_class == "light green") {\
        var btn = $(this).find("td").find("div.btn-table-delete");\
        btn.hide();\
      }\
    })\
  });\
</script>\
'); 