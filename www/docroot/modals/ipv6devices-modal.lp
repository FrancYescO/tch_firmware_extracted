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
local vSIDN = post_helper.validateStringIsDomainName
local format, match, gsub = string.format, string.match, string.gsub
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
   {--[2]
    header = T"Device Type",
    name = "DeviceType",
    param = "DeviceType",
    type = "text",
    readonly = true,
    attr = { input = { class="span3" } }
   },
  {--[3]
    header = T"Hostname",
    name = "FriendlyName",
    param = "FriendlyName",
    type = "text",
    readonly = true,
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
  FriendlyName = gOrV(vSIDN, post_helper.validateUnknownHostname)
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
  data["InterfaceType"] = tonumber(data["State"]) == 0 and "-" or data["InterfaceType"]
  if data["InterfaceType"] and data["InterfaceType"] ~= "unknown" then
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
    elseif data["InterfaceType"] == "ethernet" then
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
end

local devices_data, devices_helpmsg = post_helper.handleTableQuery(devices_columns, devices_options, devices_filter , nil, device_valid)

local function dhcplease()
  local function Split(s, delimiter)
      local result = {}
      for match in (s..delimiter):gmatch("(.-)"..delimiter) do
          table.insert(result, match);
      end
      return result
  end
  local function file_exists(file)
    local f = io.open(file, "rb")
    if f then f:close() end
    return f ~= nil
  end
  local function lines_from(file)
    if not file_exists(file) then return {} end
    local lines = {}
    for line in io.lines(file) do
      lines[#lines + 1] = line
    end
    return lines
  end
  local file = '/var/dhcp.leases'
  local lines = lines_from(file)
  for k, v in pairs(lines) do
    lines[k] = Split(v," ")
  end
  return lines
end

local function get_from_var()
  local device_infos = dhcplease()
  for devices_index, devices_value in pairs (devices_data) do
    duplicate_ip = untaint(devices_value[4] or "")
    if string.match (devices_value[3], pattern) then
      local count = 0
      for token in string.gmatch(duplicate_ip, "[^%s]+") do
        count = count+1
        if count == 1 then
          devices_data[devices_index][4] = token
        else
          devices_data[#devices_data+1] = {}
          for sub_index, sub_data in pairs(devices_data[devices_index]) do
            devices_data[#devices_data][sub_index] = sub_data
          end
          devices_data[#devices_data][4] = token
        end
      end
    end
  end

  local devices_data_copy = {}
  for devices_index, devices_value in pairs (devices_data) do
    if devices_value[4] ~= "" and devices_value[1] ~= "0" then
      devices_data_copy[#devices_data_copy+1] = devices_value
    end
    if string.match (devices_value[3], pattern) then
      for token in string.gmatch(devices_value[4], "[^%s]+") do
        for dhcp_lease_index, dhcp_lease_data in pairs(device_infos) do
          if token == dhcp_lease_data[3] and #dhcp_lease_data > 4 and dhcp_lease_data[4] ~= "*" then
            devices_data[devices_index][3] = dhcp_lease_data[4]
            devices_data[devices_index][5] = dhcp_lease_data[2]
          end
        end
      end
    end
  end
  devices_data = devices_data_copy
end
if post_helper.getVariantValue(variantHelper, "varDhcpLeases") then
  get_from_var()
end 
for k, v in pairs (devices_data) do
   devices_data[k][1] = format("%s",v[1])
   devices_data[k][5] = format("%s",v[5]:gsub("^%l", string.upper))
    if v[1] == "1" then
      if v[8] ~= "" and v[7] ~= "" then
        if v[8] == "0" then
          v[8] = T"Infinity"
        else
          v[8] = post_helper.secondsToTime(tonumber(v[8])) or T"Infinity"
        end
      else
        v[8]="-"
      end
      local seconds = v[7] and v[7] ~= "" and (os.time()- tonumber(v[7])) or ""
      v[7] = (seconds and seconds ~= "" and seconds > 0) and post_helper.secondsToTime(seconds) or '-'
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
  local tabs = {
    {
      desc = T"Global Information",
      target = "modals/device-modal.lp"
    },
    {
      desc = T"Devices List",
      active = "active",
      target = "modals/ipv6devices-modal.lp"
    }
  }
  ngx.print(ui_helper.createModalTabs(tabs))
  ngx.print('\
  <form class="form-horizontal" method="post" action="modals/ipv6devices-modal.lp">\
    ');  
      local button_class = {
        button = {
            id = "to_top"
          }
        }
      ngx.print(ui_helper.createSimpleButton("", "", button_class))
      ngx.print('\
    ');  
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      ngx.print('\
      <legend>');  ngx.print( T"Devices" ); ngx.print('</legend>\
      ');  ngx.print( ui_helper.createTable(devices_columns, devices_data, devices_options, nil, devices_helpmsg) ); ngx.print('\
    </fieldset>\
  </form>\
</div>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
<script>\
  var featureFlag = ');  ngx.print(featureFlag); ngx.print(';\
</script>\
<script src="/js/ipv6devices-modal.js"></script>\
'); 
