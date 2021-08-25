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
local content_helper = require("web.content_helper")

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
}

local device_valid = {}
local devices_options = {
    canEdit = false,
    canAdd = false,
    canDelete = false,
    tableid = "devices",
    basepath = "sys.hosts.host.",
}

local function findFreqBand(sta_mac)
  local wifiBand
  for _, agent in ipairs(proxy.getPN("Device.Services.X_TELSTRA_MultiAP.Agent.",true)) do
    local agentname = format("%s", proxy.get(agent["path"] .. "Alias")[1].value)
    local BSSID2GHz = format("%s", proxy.get(agent["path"] .. "BSSID2GHZ")[1].value)
    if agentname ~= "" then
      local staPath = agent["path"] .. "STA."
      local staInfo = proxy.get(staPath)
      local staList = content_helper.convertResultToObject(staPath, staInfo)
      for _, sta_v in ipairs(staList) do
        if sta_v.Active == "1" and sta_mac == string.lower(sta_v.MACAddress) then
          wifiBand = sta_v.BSSID == BSSID2GHz and "wireless - 2.4GHz" or "wireless - 5GHz"
        end
      end
    end
  end
  return wifiBand
end


--add a device filter to remove the table line in case we have a host connected by FON.
local devices_filter = function(data)
  if match(data["L2Interface"], "^wl0") then
    data["InterfaceType"] = "wireless - 2.4GHz"
  elseif match(data["L2Interface"], "^wl1") then
    data["InterfaceType"] = "wireless - 5GHz"
  elseif match(data["L2Interface"], "^wds%d+") then
    data["InterfaceType"] = findFreqBand(data["MACAddress"])  and findFreqBand(data["MACAddress"]) or "wireless - 5GHz"
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
'); 