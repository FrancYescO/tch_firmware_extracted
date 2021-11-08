--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local string, ngx, os = string, ngx, os
local gmatch = string.gmatch
local tonumber = tonumber
local gOrV = post_helper.getOrValidation
local gVIES = post_helper.getValidateInEnumSelect
local vSIDN = post_helper.validateStringIsDomainName
local format, match = string.format, string.match
local pattern = "^Unknown%-%x%x:%x%x:%x%x:%x%x:%x%x:%x%x$"
local network = require("transformer.shared.common.network")
local untaint = string.untaint
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local session = ngx.ctx.session
local role = session:getrole()
local leaseType
local proxy = require("datamodel")
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "DevicesModal", "devicesList")

local device_types = {
      { "console", "Console"},
      { "laptop", "Laptop"},
      { "printer", "Printer"},
      { "nas", "NAS"},
      { "smartphone", "Smartphone"},
      { "tablet", "Tablet"},
      { "desktop", "Desktop"},
      { "switch", "Switch"},
      { "stb", "STB"},
}
-- devices forwarding rules
local devices_columns = {
  {--[1]
    header = T"Status",
    name = "state",
    param = "State",
    type = "light",
    readonly = true,
    attr = { input = { class="span1" } }
  },
  -- Changed to select boxx due to removal of the map view
  {--[2]
    header = T"Device Type",
    name = "DeviceType",
    param = "DeviceType",
    type = "select",
    values = device_types,
    readonly = false,
    attr = { select = { class="span2" } },
   },
  {--[3]
    header = T"Hostname",
    name = "FriendlyName",
    param = "FriendlyName",
    type = "text",
    readonly = false,
    attr = { input = { class="span3" } }
  },
   {
    header =  T"IPv4",
    name = "IPv4",
    param = "IPv4",
    type = "text",
    readonly = true,
    attr = { input = { class="span3" } }
   },
  {--[5]
    header = T"MAC Address",
    name = "macaddress",
    param = "MACAddress",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } }
  },
  {--[6]
    header = T"Interface",
    name = "interfacetype",
    param = "InterfaceType",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } }
  },
  {
    header = T"Connected Time",
    name = "ConnectedTime",
    param = "ConnectedTime",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } }
  },
  {
    header = T"Expires In",
    name = "LeaseTimeRemaining",
    param = "LeaseTimeRemaining",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } }
  },
  {--[4]
    header = T"IPv6",
    name = "ipv6",
    param = "IPv6",
    type = "time",
    readonly = true,
    attr = { input = { class="span1" } }
  },
  {--[7]
    header =  T"IPv6 Link Local Addr",
    name = "ipv6linklocaladdress",
    param = "ipv6linklocaladdr",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" } }
  },
  {
    header = T"Priority",
    name = "priority",
    param = "Priority",
    type = "text",
    readonly = true,
    attr = { input = { class="span3" } },
  },
  {
    header = T"Priority",
    name = "priority",
    param = "Priority",
    type = "switch",
    readonly = false,
    attr = { input = { class="span3" } },
  }
}

local device_valid = {
  FriendlyName = gOrV(vSIDN, post_helper.validateUnknownHostname),
  DeviceType = gVIES(device_types),
}

local devices_options = {
  canEdit = false,
  canAdd = false,
  canDelete = false,
  tableid = "ipv6Devices",
  basepath = "sys.hosts.host."
}

local featureFlag = post_helper.isFeatureEnabled("ipv6DeviceFeatureModal", role)
if featureFlag then
  devices_options.canEdit = true
end

--Construct the device ipv6 global, link local address and lease type
local devices_filter = function(data)
  leaseType = data["LeaseType"]
  if data["InterfaceType"] == "wireless" then
    if post_helper.getVariantValue(variantHelper, "ssidNetwork") then
      local wirelessClient = {
        network = format("rpc.wireless.ssid.@%s.network", data["L2Interface"]),
        ssid = format("rpc.wireless.ssid.@%s.ssid", data["L2Interface"])
      }
      content_helper.getExactContent(wirelessClient)
      if data["Radio"] == "radio_2G" then
        data["InterfaceType"] = "wireless - 2.4GHz - " .. wirelessClient.network .. " - " .. wirelessClient.ssid
      elseif data["Radio"] == "radio_5G" then
        data["InterfaceType"] = "wireless - 5GHz - " .. wirelessClient.network .. " - " .. wirelessClient.ssid
      end
    else
      if data["Radio"] == "radio_2G" then
        data["InterfaceType"] = "wireless - 2.4GHz"
      elseif data["Radio"] == "radio_5G" then
        data["InterfaceType"] = "wireless - 5GHz"
      end
    end
  elseif match(data["L2Interface"], "(eth[%d+])") then
    local ethPort = data["Port"]
    data["InterfaceType"] = "Ethernet Port"..ethPort
  elseif match(data["L2Interface"], "moca*") then
    data["InterfaceType"] = "MoCA"
  end

  if data["State"] and data["State"] == "0" then
     data["IPAddress"] = ""
  end

  local ipv6State = proxy.get("uci.dhcp.dhcp.@lan.dhcpv6") and proxy.get("uci.dhcp.dhcp.@lan.dhcpv6")[1].value or ""
  if ipv6State == "disabled" then
    data["IPv6"] = ""
    data["ipv6linklocaladdr"] = ""
    return true
  end

  --Display only the IPv6 devices
  if data["IPv6"] == "" then
    return true
  end
  local IPv6Details = {
    IPv6DefaultGW_lan    = "rpc.network.interface.@lan.ipv6uniqueglobaladdr"
  }
  content_helper.getExactContent(IPv6Details)
  data["ipv6defaultgateway"] = IPv6Details.IPv6DefaultGW_lan
  if data["L3Interface"] then
    local mac = untaint(data["MACAddress"])
    local cmd = "ip -6 neigh show | grep "..mac.." | grep fe80 "
    local output =  network.executeCommand(cmd)
    for i in gmatch(output, "%S+") do
      if match(i, "fe80*") then
        data["ipv6linklocaladdr"] = i
        return true
      else
        return false
      end
    end
  end
end

local devices_data, devices_helpmsg = post_helper.handleTableQuery(devices_columns, devices_options, devices_filter , nil, device_valid)

for k, v in pairs (devices_data) do
   devices_data[k][1] = format("%s",v[1])
   devices_data[k][5] = format("%s",v[5]:gsub("^%l", string.upper))
    if v[1] == "1" then
      if v[8] ~= "" and v[7] ~= "" then
        if v[8] == "0" and leaseType == "DHCP" then
          v[8] = T"Infinity"
        else
          v[8] = post_helper.secondsToTime(tonumber(v[8])) or T"Infinity"
        end
      else
        v[8]="-"
      end
      if v[7] ~= "" then
        v[7] = post_helper.secondsToTime(os.time()- tonumber(v[7]))
      else
        v[7] = "-"
      end
    else
      v[8] = "-"
      v[7] = "-"
    end
end
  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"Devices", false, true) ); ngx.print('\
<div class="modal-body update no-save">\
');  
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-devices.lp")
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/ipv6devices-modal.lp">\
    ');  
      local button_class = {
        button = {
            id = "to_top"
          }
        }
      ngx.print(ui_helper.createButton("", "", "", button_class))
      ngx.print('\
    ');  
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
    ngx.print( ui_helper.createTable(devices_columns, devices_data, devices_options, nil, devices_helpmsg) ); ngx.print('\
    </fieldset>\
  </form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
<script>\
  var featureFlag = ', featureFlag, ';\
</script>\
<script src="/js/ipv6devices-modal.js"></script>\
'); 