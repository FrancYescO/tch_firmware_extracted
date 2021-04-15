--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local attributes = { span = { class = "span4" } }
local message_helper = require("web.uimessage_helper")
local lp = require("web.lp")
local ngx = ngx
local table, string = table, string
local tonumber, tostring = tonumber, tostring
local format, match = string.format, string.match
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "ExtenderPage", "extenderDeviceList")

local content = {
    hostname = "uci.system.system.@system[0].hostname",
}
content_helper.getExactContent(content)

if post_helper.getVariantValue(variantHelper, "agentHostname") then
  content.hostname = T"Gateway"
end

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
  basepath = "sys.hosts.host."
}

--add a device filter to remove the table line in case we have a host connected by FON.
local devices_filter = function(data)
  -- Do not display devices not in the LAN bridge
  if data["FirewallZone"] == "LAN" then
      if data["InterfaceType"] == "wireless" then
          data["InterfaceType_img"] = "<div><img width='30' align='middle' src='/img/wifi_all.png'></div>"
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
  header = T"RSSI",
  name = "signalstrength",
  param = "devicesignalstrength",
  type = "text",
  readonly = true,
  attr = { input = { class="span1" } },
}

devices_columns[#devices_columns+1] = {--[8]
  header = T"Download/Upload Link Rate",
  name = "linkrate",
  param = "devicelinkrate",
  type = "text",
  readonly = true,
  attr = { input = { class="span1" } },
}

devices_columns[#devices_columns+1] = {--[9]
  header = T"Tx/Rx Bytes",
  name = "linkrate",
  param = "devicetraffic",
  type = "text",
  readonly = true,
  attr = { input = { class="span1" } },
}
lp.setpath("/www/snippets/")
ngx.print(ui_helper.createHeader(T"EasyMesh Info", false, true))
  ngx.print('\
<form class="form-horizontal" method="post" action="/modals/wifi-devices-info.lp">\
  <div class="modal-body update">\
    ');  lp.include("tabs-easyMesh.lp")
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))  ngx.print('\
    <div class="container">\
      <div class="row">\
        <div class="span11">\
          <fieldset>\
            ');  
            --For gateway itself
            local html={}
            local internalstanumber = "0"
            local station_aplist = {"ap0", "ap1", "ap2", "ap3"}
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
                        v[#v+1] = sta_v.rssi and sta_v.rssi .. "dBm" or ""
                        v[#v+1] = sta_v.tx_phy_rate and sta_v.rx_phy_rate and sta_v.tx_phy_rate/1000 .. "Mbps/" .. sta_v.rx_phy_rate/1000 .. "Mbps" or ""
                        v[#v+1] = sta_v.tx_bytes and sta_v.rx_bytes and sta_v.tx_bytes/1000 .. "Mbps/" .. sta_v.rx_bytes/1000 .. "Mbps" or ""
                        internalstanumber = internalstanumber + 1
                        newdevices_data[#newdevices_data+1]=devices_data[i]
                        break
                      end
                    end
                  end
                end
              end
            end
            html[#html+1] = format('<legend>%s<br />'.. T'Connected Devices:'..'%s<br /></legend>', content.hostname, internalstanumber)
            html[#html+1] = ui_helper.createTable(devices_columns, newdevices_data, devices_options, nil, devices_helpmsg)
            ngx.print(html)
            local html={}
            local MultiAP = content_helper.convertResultToObject("rpc.multiap.device.",proxy.get("rpc.multiap.device."))
            local staList = content_helper.convertResultToObject("rpc.multiap.sta.",proxy.get("rpc.multiap.sta."))
            if MultiAP then
              for k, v in ipairs(MultiAP) do
                local agent_MAC = v.al_mac and tostring(string.untaint(v.al_mac)) or ""
                local agent_name = v.device_name and string.untaint(v.device_name) or "Unknown_Name"
                if post_helper.getVariantValue(variantHelper, "agentHostname") then
                  agent_name = T"Extender"
                end
                local sta_count = 0
                local newdevices_data = {}
                if agent_MAC ~= "" then
                  for key, value in pairs(v) do
                    if match(key, "^%S+.sta_list$") then
                      if value ~= "" then
                        for sta_i in string.gmatch(value, '([^%s]+)') do
                          sta_count = sta_count + 1
                          for _, sta_v in ipairs(staList) do
                            if sta_v.mac == sta_i then
                              local devicelinkrate = sta_v.dl_mac_rate and sta_v.ul_mac_rate and sta_v.dl_mac_rate/1000 .. "Mbps/" .. sta_v.ul_mac_rate/1000 .. "Mbps" or ""
                              local devicesignalstrength = sta_v.rssi and sta_v.rssi .. "dBm" or ""
                              local devicetraffic = sta_v.txbytes and sta_v.rxbytes and sta_v.txbytes/1000 .. "Mbps/" .. sta_v.rxbytes/1000 .. "Mbps" or ""
                              for i, v in pairs(devices_data) do
                                if sta_v.mac == v[MACcolumnindex] and #v == 6 then
                                  v[#v+1] = devicesignalstrength
                                  v[#v+1] = devicelinkrate
                                  v[#v+1] = devicetraffic
                                  newdevices_data[#newdevices_data+1]=devices_data[i]
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
                html[#html+1] = format('<span id=%s><legend>%s<br />'..T'Connected Devices:'..'%s<br /></legend></span>', agent_MAC, agent_name, sta_count)
                html[#html+1] = ui_helper.createTable(devices_columns, newdevices_data, devices_options, nil, devices_helpmsg)
              end
            end
            ngx.print(html)
              ngx.print('\
          </fieldset>\
        </div>\
      </div>\
    </div>\
  </div>\
</form>\
');  ngx.print(ui_helper.createFooter()); ngx.print('\
<script>\
  $(document).ready(function () {\
    //Dynamically adding ID to each row with the mac address of the device.\
    $("tbody").find(\'tr\').each(function (key, val) {\
      var cellObj = $(this).find(\'td\');\
      var macAddr = cellObj.eq(2).text();\
      $(this).attr("id", macAddr);\
    });\
\
    //Navigation to the the paricular ID(wifi-extender-status.lp) and higlighting it to blue\
    var url = window.location.toString();\
    var macRegex = /[a-fA-F0-9:]{17}|[a-fA-F0-9]{12}$/i;\
    var macID = url.match(macRegex);\
    var elem = document.getElementById(macID);\
    if (elem !== null) {\
      elem.scrollIntoView({ behavior: "smooth", block: "end", inline: "nearest" });\
      elem.classList.add("info");\
    }\
  });\
</script>\
'); 