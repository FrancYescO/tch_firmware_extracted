--pretranslated: do not change this file
 
local lp = require("web.lp")
lp.setpath("/www/snippets/")
lp.include("header.lp")
lp.include("navbar.lp")
lp.include("menubar.lp")
lp.include("message.lp")
  ngx.print('\
\
');  
-- Enable localization
gettext.textdomain('webui-telstra')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local attributes = { span = { class = "span4" } }
local message_helper = require("web.uimessage_helper")
local ngx = ngx
local table, string = table, string
local tonumber = tonumber
local tostring = tostring
local format, match = string.format, string.match

local content = {
    hostname = "uci.system.system.@system[0].hostname",
}
content_helper.getExactContent(content)

local devices_columns = {
    {--[1]
      header = T"",
      name = "interfacetype",
      param = "InterfaceType_img",
      type = "text",
      readonly = true,
      attr = { input = { class="span1" } },
    },
    {--[2]
      header = T"Name",
      name = "name",
      param = "HostName",
      type = "text",
      readonly = true,
      attr = { input = { class="span1" } },
    },
    {--[3]
      header = T"MAC address",
      name = "macaddress",
      param = "MACAddress",
      type = "text",
      readonly = true,
      attr = { input = { class="span1" } },
    },
    {--[4]
      header = T"IPv4 address",
      name = "ipaddress",
      param = "IPv4",
      type = "text",
      readonly = true,
      attr = { input = { class="span1" } },
    },
    {--[5]
      header = T"IPv6 address",
      name = "ip6address",
      param = "IPv6",
      type = "text",
      readonly = true,
      attr = { input = { class="span1" } },
    },
    {--[6]
      header = T"Wi-Fi Band",
      name = "interfacetype",
      param = "InterfaceType",
      type = "text",
      readonly = true,
      attr = { input = { class="span2" } },
    },
}

local MACcolumnindex = 3
local device_valid = {}
local devices_options = {
    canEdit = false,
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
            data["InterfaceType_img"] = "<div><img width='20' align='middle' src='/img/wireless.png'></div>"
            if match(data["L2Interface"], "^wl0") then
                data["InterfaceType"] = "2.4GHz"
            elseif match(data["L2Interface"], "^wl1") then
                data["InterfaceType"] = "5GHz"
            end
        else
            data["InterfaceType_img"] = "<div><img width='20' align='middle' src='/img/ethernet.png'></div>"
        end
        return true
    else
        return false
    end
end

local devices_data, devices_helpmsg = post_helper.handleTableQuery(devices_columns, devices_options, devices_filter, nil, device_valid)

devices_columns[#devices_columns+1] = {--[7]
  header = T"Signal Strength",
  name = "signalstrength",
  param = "devicesignalstrength",
  type = "text",
  readonly = true,
  attr = { input = { class="span1" } },
}
devices_columns[#devices_columns+1] = {--[8]
  header = T"Link Rate",
  name = "linkrate",
  param = "devicelinkrate",
  type = "text",
  readonly = true,
  attr = { input = { class="span1" } },
}
  ngx.print('\
\
\
<div class="container">\
');  lp.include("tabs-home.lp")   ngx.print('\
<div class="row">\
<div class="span11">\
<fieldset>\
');  
--For gateway itself
local html={}
local internalstanumber = "0"
local station_aplist = {"ap0", "ap2"}
local newdevices_data = {}
for _, ap in pairs(station_aplist) do
    local staPath = "rpc.wireless.ap.@" .. ap .. ".station."
    local staInfo = proxy.get(staPath)
    local staList = content_helper.convertResultToObject(staPath, staInfo)
    if type(staList) == 'table' then
        for _, sta_v in ipairs(staList) do
            if sta_v.state ~= "Disconnected" and sta_v.state ~= "Authenticated" then
                for i, v in pairs(devices_data) do
                    if sta_v.paramindex == "@" .. v[MACcolumnindex] and #v == 6 then
                        v[#v+1] = sta_v.rssi .. "dBm"
                        v[#v+1] = sta_v.tx_phy_rate/1000 .. "Mbps"
                        internalstanumber = internalstanumber + 1
                        newdevices_data[#newdevices_data+1]=devices_data[i]
                        break
                    end
                end
            end
        end
    end
end
html[#html+1] = format(T'%s<br /><br /> Connected Devices: %s<br />', content.hostname, internalstanumber)
html[#html+1] = ui_helper.createTable(devices_columns, newdevices_data, devices_options, nil, devices_helpmsg)
ngx.print(html)
  ngx.print('\
');  
local html={}
for _, agent in ipairs(proxy.getPN("Device.Services.X_TELSTRA_MultiAP.Agent.",true)) do
    local agentname = format("%s", proxy.get(agent["path"] .. "Alias")[1].value)
    if agentname ~= "" then
        local agentdevicesnumber = format("%s", proxy.get(agent["path"] .. "AssociatedDeviceNumberOfEntries")[1].value)
        html[#html+1] = format(T'%s<br /><br /> Connected Devices: %s<br />', agentname, agentdevicesnumber)

        local staPath = agent["path"] .. "STA."
        local staInfo = proxy.get(staPath)
        local staList = content_helper.convertResultToObject(staPath, staInfo)
        local newdevices_data = {}
        for _, sta_v in ipairs(staList) do
            local staMAC = string.lower(sta_v.MACAddress)
            local devicesignalstrength = sta_v.SignalStrength .. "dBm"
            local devicelinkrate = sta_v.LastDataDownlinkRate/1000 .. "Mbps"
            for i, v in pairs(devices_data) do
                if staMAC == v[MACcolumnindex] and #v == 6 then
                    v[#v+1] = devicesignalstrength
                    v[#v+1] = devicelinkrate
                    newdevices_data[#newdevices_data+1]=devices_data[i]
                    break
                end
            end
        end
        html[#html+1] = ui_helper.createTable(devices_columns, newdevices_data, devices_options, nil, devices_helpmsg)
    end
end
ngx.print(html)
  ngx.print('\
</fieldset>\
\
</div>\
</div>\
</div>\
');  
lp.include("footer.lp")
  ngx.print('\
'); 