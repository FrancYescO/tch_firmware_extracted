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
local tel_helper = require("telstra_helper")
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
      param = "FriendlyName",
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
    if match(data["L2Interface"], "^wl%d+") or match(data["L2Interface"], '^wds%d+') then
        data["InterfaceType_img"] = "<div style='width:40px'><img align='middle' src='/img/wirelessGrey.png'></div>"
        if match(data["L2Interface"], "^wl0") then
            data["InterfaceType"] = "2.4GHz"
        elseif match(data["L2Interface"], "^wl1") then
            data["InterfaceType"] = "5GHz"
        else
            data["InterfaceType"] = "wireless"
        end
    else
        data["InterfaceType"] = "ethernet"
        data["InterfaceType_img"] = "<div><img width='20' align='middle' src='/img/ethernet.png'></div>"
    end
    return true
end

local devices_data, devices_helpmsg = post_helper.handleTableQuery(devices_columns, devices_options, devices_filter, nil, device_valid)

devices_columns[#devices_columns+1] = {--[7]
  header = T"Signal Strength",
  name = "signalstrength",
  param = "deviceSignalStrength",
  type = "text",
  readonly = true,
  attr = { input = { class="span1" } },
}
devices_columns[#devices_columns+1] = {--[8]
  header = T"Link Rate",
  name = "linkrate",
  param = "deviceLinkRate",
  type = "text",
  readonly = true,
  attr = { input = { class="span1" } },
}
--Defining level table with default values incase retreival of values from web config fails
local level = {
  ["threshold_weak"]=-90,
  ["threshold_avg"]=-75,
  ["threshold_good"]=-60,
  ["threshold_excel"]=-50
}
local thresholdPath = "uci.web.wireless."
local thresholdData = content_helper.convertResultToObject(thresholdPath, proxy.get(thresholdPath))
--The below "for" loop is to iterate and get all the available threshold values from the web config and store in "level" table
for _, data in pairs(thresholdData) do
  for option, value in pairs(data) do
    if option ~= "@paramindex" then
      level[option] = tonumber(value)
    end
  end
end

-- function updateIcon is to provide the different icons based on their respective signal strengths such as wirelessRed,wirelessGreen etc.
local function updateIcon(rssi)
  if not rssi then
    return nil
  else
    rssi = tonumber(rssi)
  end
  local signalStrength = "wirelessGrey.png"
  if rssi >= level["threshold_excel"] then
    signalStrength = "wirelessGreen.png"
  elseif rssi < level["threshold_excel"] and rssi >= level["threshold_good"] then
    signalStrength = "wirelessYellow.png"
  elseif rssi < level["threshold_good"] and rssi >= level["threshold_avg"] then
    signalStrength = "wirelessOrange.png"
  elseif rssi < level["threshold_avg"] and rssi >= level["threshold_weak"] then
    signalStrength = "wirelessRed.png"
  end
  return format("<div style='width:40px'><img align='middle' src='/img/%s'></div>", signalStrength)
end

  ngx.print('\
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
                        v[#v+1] = sta_v.rssi and sta_v.rssi ~= "" and sta_v.rssi .. "dBm" or ""
                        v[#v+1] = sta_v.tx_phy_rate and sta_v.tx_phy_rate ~= "" and sta_v.tx_phy_rate/1000 .. "Mbps" or ""
                        v[1] = updateIcon(sta_v.rssi) or v[1]
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
    local MultiAP = content_helper.convertResultToObject("rpc.multiap.device.",proxy.get("rpc.multiap.device."))
    local staList = content_helper.convertResultToObject("rpc.multiap.sta.",proxy.get("rpc.multiap.sta."))
    for k, v in ipairs(MultiAP or {}) do
        local agent_MAC = v.al_mac and tostring(string.untaint(v.al_mac)) or ""
        local agent_name = v.device_name and string.untaint(v.device_name) or "Unknown_Name"
        local sta_count = 0
        local newdevices_data = {}
        for key, value in pairs(v) do
            if match(key, "^%S+.sta_list$") and value ~= "" then
                for sta_i in string.gmatch(value, '([^,]+)') do
                    sta_count = sta_count + 1
                    for _, sta_v in ipairs(staList) do
                        if sta_v.mac == sta_i then
                            local deviceLinkRate = sta_v.dl_mac_rate and sta_v.dl_mac_rate/1000 .. "Mbps" or ""
                            sta_v.rssi = tonumber(sta_v.rssi)
                            if sta_v.rssi == 0 then
                                sta_v.rssi = -109.5
                            elseif sta_v.rssi >= 1 and sta_v.rssi <= 220 then
                                sta_v.rssi = sta_v.rssi and (sta_v.rssi / 2) - 110 or ""
                            else
                                sta_v.rssi = ""
                            end
                            local deviceSignalStrength = sta_v.rssi and sta_v.rssi .. "dBm" or ""
                            for i, v in pairs(devices_data) do
                                if sta_v.mac == v[MACcolumnindex] and #v == 6 then
                                   v[#v+1] = deviceSignalStrength
                                   v[#v+1] = deviceLinkRate
                                   v[1] = updateIcon(sta_v.rssi) or v[1]
                                   newdevices_data[#newdevices_data+1]=devices_data[i]
                                end
                            end
                        end
                    end
                end
            end
        end
        html[#html+1] = format('<span id=%s>%s<br />'..T'Connected Devices:'..'%s<br /></span>', agent_MAC, agent_name, sta_count)
        html[#html+1] = ui_helper.createTable(devices_columns, newdevices_data, devices_options, nil, devices_helpmsg)
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