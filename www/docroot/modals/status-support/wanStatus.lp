--pretranslated: do not change this file
 
--Enable Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local vdf_helper = require("vodafone_helper")
local content_helper = require("web.content_helper")
local untaint_mt = require("web.taint").untaint_mt
local string, table, math, unpack = string, table, math, unpack
local format, match, sort, tolower =  string.format, string.match, table.sort, string.lower
local ipairs, ngx, tonumber, tostring = ipairs, ngx, tonumber, tostring
local wanUptime, wanIPAddress, wanIPMask, wanDNS
local secondsToHours = vdf_helper.secondsToHours
local variant = vdf_helper.getVariant()
local ui_helper = require("vdf_ui_helper")
local setmetatable = setmetatable
local adslInterfaceName = {
  ["ull_data"] = "adsl_ull_data",
  ["ull_voice"] = "adsl_ull_voice",
}
adslInterfaceName = setmetatable(adslInterfaceName, untaint_mt)

local ignoreInterface = {
  ["wan"] = true,
  ["voip"] = true,
  ["wan6"] = true,
  ["iptv"] = true,
  ["lan"] = true,
  ["loopback"] = true,
  ["dummy"] = true,
}

if variant == "NZ" then
    ignoreInterface.wan = nil
    ignoreInterface.adsl = true
    ignoreInterface.vdsl = true
    ignoreInterface.ewan = true
end

local wanStatusCommonGet = {
  ["l3type"] = "uci.wansensing.global.l3type",
  ["firewallStatus"] = "rpc.network.firewall.enable",
}
content_helper.getExactContent(wanStatusCommonGet)

local function netmask2mask(maskbits)
  if (type(maskbits) ~= "number") then
    return nil
  end
  local result = ""
  for i=1,4 do
    result = result .. string.match(tostring(256 - 2^(8 - math.min(8, maskbits))),"([%d]+)")
    if (i < 4) then
      result = result .. "."
    end
    maskbits = math.max(0, maskbits - 8)
  end
  return result
end

if ngx.var.request_method == "POST" then
  local postArgs = ngx.req.get_post_args()
  if postArgs.action == "reset" then
    local resetStatTable = {}
    if postArgs.statisticsType == "atm" then
      resetStatTable["rpc.ATMStats.reset"] = "1"
    else
      for paramindex in string.gmatch(postArgs.interface, '([^,]+)') do
        resetStatTable[format("sys.class.net.%s.statistics.%s.reset", paramindex, postArgs.iptype)] = "1"
      end
    end
    proxy.set(resetStatTable)
    proxy.apply()
  end
end

-- Description Function to get the list of wan interface Paths
-- @function getWanInterfacePath
-- @return table
local function getWanInterfacePath()
  local interfaceList = proxy.getPN("rpc.network.interface.", true)
  local wanIntfPaths = {}
  if interfaceList then
    for _,intf in ipairs(interfaceList) do
      local values = proxy.get(intf.path .. "type")
      if values ~= "" and values[1].value == "wan" then
        wanIntfPaths[#wanIntfPaths + 1] = values[1].path
      end
    end
  end
  return wanIntfPaths
end

-- Description Function to get the list of network values
-- @function getNetworkValues
-- @return table
local function getNetworkValues()
  local natInfo =  proxy.get("uci.firewall.zone.")
  local maskList = {}
  for _, v in ipairs(natInfo) do
    if v.param == "masq" then
      local index = match(v.path, "uci.firewall.zone.@([^.]+).")
      maskList["masq"..index] = v.value
    end
  end
  local resultList = {}
  for _, v in ipairs(natInfo) do
    local index = match(v.path, "uci.firewall.zone.@([^.]+).network")
    if index then
      resultList[string.untaint(v.value)] = maskList["masq"..index] or "0"
    end
  end
  return resultList
end

local wanIntfPaths = getWanInterfacePath()
local wanData = content_helper.convertResultToObject("rpc.network.interface.", proxy.get(unpack(wanIntfPaths)))
local wanConInfo = {}
local statsPath = {}
for _, data in ipairs(wanData) do
  if data["type"] == "wan" then
    wanConInfo[#wanConInfo + 1] = {}
    wanConInfo[#wanConInfo].interface = match(data["paramindex"], "([%w%_]+)")
    -- populating wan details in order to replace values of connected interface
    if match(data["paramindex"], "([%w%_]+)") == "wan" then
      wanUptime = data["uptime"]
      wanIPAddress = data["ipaddr"]
      wanIPMask = data["ipmask"]
      wanDNS = data["dnsservers"]
    end
    wanConInfo[#wanConInfo].type = data["proto"]
    if variant == "NZ" then
      wanConInfo[#wanConInfo].ll = data["ppp.ll_intf"]
    end
    wanConInfo[#wanConInfo].up = data["up"]
    wanConInfo[#wanConInfo].upTime = data["uptime"]
    wanConInfo[#wanConInfo].IPAddress = data["ipaddr"]
    wanConInfo[#wanConInfo].IPMask = data["ipmask"]
    wanConInfo[#wanConInfo].DNSServer = data["dnsservers"]
    wanConInfo[#wanConInfo].IPv6LinkAddress = data["ipv6linklocaladdr"]
    wanConInfo[#wanConInfo].nextHop = data["nexthop"]
    wanConInfo[#wanConInfo].ifName = data["ifname"]
    if data['ifname'] ~= "" and data['ifname'] ~= "SET_BY_SCRIPT" and data["up"] == "1" then
      if variant ~= "NZ" then
        statsPath[#statsPath+1] = format("sys.class.net.@%s.", data['ifname'])
      else
        statsPath[#statsPath+1] = format("sys.class.net.@%s.", data['ppp.ll_intf'])
      end
    end
  end
end
sort(wanConInfo, function(interface1, interface2)
  return tostring(interface1.interface) < tostring(interface2.interface)
end)

-- statsPath may contain invalid/duplicate paths.
local duplicatePaths, delPaths = {}, {}

-- collect all invalid/duplicate paths
for wanPathIndex, wanPath in ipairs(statsPath) do
  if not proxy.getPN(wanPath, false) or duplicatePaths[wanPath] then
    delPaths[#delPaths+1] = wanPathIndex
  end
  duplicatePaths[wanPath] = true
end

-- and delete them
for i = #delPaths, 1, -1 do
  table.remove(statsPath, delPaths[i])
end

local wanStats = content_helper.convertResultToObject("sys.class.net.", proxy.get(unpack(statsPath)))

-- returns WAN Statistics for provided iptype (ipv4/ipv6)
local function getWanStatistics(ipType)
  local wanStatsData = {}
  if ipType ~= "ipv4" and ipType ~= "ipv6" then
    return wanStatsData
  end
  local index = (variant == "NZ") and "ll" or "ifname"
  for _,stats in ipairs(wanStats) do
    wanStatsData[#wanStatsData + 1] = {}
    local paramIndexName =  stats.paramindex
    paramIndexName = match(paramIndexName, "([%w%-%_]+)") or ""
    for _,name in ipairs(wanConInfo) do
      if paramIndexName == name[index] then
        wanStatsData[#wanStatsData].interface = name.interface
        wanStatsData[#wanStatsData].type = name.type
        break
      end
    end
    if variant == "NZ" then
      wanStatsData[#wanStatsData].ll         = paramIndexName
      wanStatsData[#wanStatsData].duplex     = stats["duplex"]
      wanStatsData[#wanStatsData].speed      = stats["speed"]
      wanStatsData[#wanStatsData].address    = stats["address"]
      wanStatsData[#wanStatsData].operstate  = stats["operstate"]
    end
    wanStatsData[#wanStatsData].rxBytes    = stats["statistics." .. ipType .. ".rx_bytes"]
    wanStatsData[#wanStatsData].rxPackets  = stats["statistics." .. ipType .. ".rx_packets"]
    wanStatsData[#wanStatsData].rxErrors   = stats["statistics." .. ipType .. ".rx_errors"]
    wanStatsData[#wanStatsData].rxDrops    = stats["statistics." .. ipType .. ".rx_dropped"]
    wanStatsData[#wanStatsData].txBytes    = stats["statistics." .. ipType .. ".tx_bytes"]
    wanStatsData[#wanStatsData].txPackets  = stats["statistics." .. ipType .. ".tx_packets"]
    wanStatsData[#wanStatsData].txErrors   = stats["statistics." .. ipType .. ".tx_errors"]
    wanStatsData[#wanStatsData].txDrops    = stats["statistics." .. ipType .. ".tx_dropped"]
    wanStatsData[#wanStatsData].paramindex = stats.paramindex
  end
  sort(wanStatsData, function(interface1, interface2)
    return tostring(interface1.interface) < tostring(interface2.interface)
  end)
  return wanStatsData
end

local ipTypeSection = {
  {header = T"IPv4 WAN statistics", version = "ipv4"},
  {header = T"IPv6 WAN statistics", version = "ipv6"},
}

local atmStats = setmetatable({}, untaint_mt)
local atmStatsData = proxy.get("rpc.ATMStats.")
if atmStatsData ~= nil then
  for _, statsIndex in ipairs(atmStatsData) do
    atmStats[statsIndex.param] = statsIndex.value
  end
end

local headers = {
  {"inOctets", T"In Octets"},
  {"outOctets", T"Out Octets"},
  {"inPackets", T"In Packets"},
  {"outPackets", T"Out Packets"},
  {"inOAMcells", T"In ATM Cells"},
  {"outOAMcells", T"Out ATM Cells"},
  {"inPacketerrors", T"In Packets Errors"},
  {"inCellerrors", T"In Cell Errors"}
}

local ipVersion = {
  [0] = T"no IP address",
  [4] = T"IPv4",
  [6] = T"IPv6",
  [10] = T"IPv4/IPv6"
}
local ipIndex = 0

local getParams = {
  ipaddr = "rpc.network.interface.@wan.ipaddr",
  ip6addr = "rpc.network.interface.@wan6.ip6addr"
}
content_helper.getExactContent(getParams)

if getParams["ipaddr"] ~= "" then
  ipIndex = ipIndex + 4
end
if getParams["ip6addr"] ~= "" then
  ipIndex = ipIndex + 6
end

local Ipv6_WanDetails = {}
for _, data in ipairs(wanConInfo) do
  if data["interface"] == "wan6" then
    Ipv6_WanDetails[#Ipv6_WanDetails + 1] = {
      data and data["interface"],
      data and data["type"],
      data and data["IPv6LinkAddress"],
      data and data["nextHop"],
      data and data["DNSServer"]
    }
  end
end

local WanDetails = {}
local networkList = getNetworkValues()
for _, data in ipairs(wanConInfo) do
  if (not adslInterfaceName[data.interface] and wanStatusCommonGet and tolower(wanStatusCommonGet.l3type) == tolower(data.interface)) or
    (wanStatusCommonGet and adslInterfaceName[data.interface]  and adslInterfaceName[data.interface] == tolower(wanStatusCommonGet.l3type)) then
    data.upTime = wanUptime
    data.up = "1"
  end
  local upTime
  if data and data.upTime and data.upTime ~= "" then
    local totalHrs, totalMts, totalSec = secondsToHours(tonumber(data.upTime))
    local timeDuration = totalHrs..":"..totalMts..":"..totalSec
    upTime = timeDuration.."s"
  else
    upTime = T"0s"
  end
  if not ignoreInterface[data.interface] then
    if variant ~= "NZ" then
      WanDetails[#WanDetails + 1] = {
        data and data.interface,
        data and data.type,
        networkList[string.untaint(data.interface)] == "1" and T"Enabled" or T"Disabled",
        (wanStatusCommonGet and wanStatusCommonGet.firewallStatus == "1") and T"Enabled" or T"Disabled",
        data and data.up == "1" and T"Up" or T"Down",
       upTime
     }
    else
      WanDetails[#WanDetails + 1] = {
        data and data.interface,
        data and data.ll,
        data and data.type,
        networkList[string.untaint(data.interface)] == "1" and T"Enabled" or T"Disabled",
        (wanStatusCommonGet and wanStatusCommonGet.firewallStatus == "1") and T"Enabled" or T"Disabled",
        data and data.up == "1" and T"Up" or T"Down",
       upTime
     }
    end
  end
end

local WanConDetails = {}
  for _, data in ipairs(wanConInfo) do
    if not adslInterfaceName[data["interface"]]  and wanStatusCommonGet and tolower(wanStatusCommonGet["l3type"]) == tolower(data["interface"]) then
      data["IPAddress"] = wanIPAddress
      data["IPMask"] = wanIPMask
      data["DNSServer"] = wanDNS
    elseif adslInterfaceName[data["interface"]] and wanStatusCommonGet and adslInterfaceName[data["interface"]] == tolower(wanStatusCommonGet.l3type) then
      data["IPAddress"] = wanIPAddress
      data["IPMask"] = wanIPMask
      data["DNSServer"] = wanDNS
    end
    if data["interface"] ~= "wan6" and not ignoreInterface[data.interface] then
      WanConDetails[#WanConDetails + 1] = {
        data and data.interface,
        data and data.type,
        data and data["IPAddress"] ~= "" and data["IPAddress"] or "0.0.0.0",
        data and data["IPMask"] ~="" and netmask2mask(tonumber(data["IPMask"])) or "0.0.0.0",
        data and data["DNSServer"]~= "" and data["DNSServer"] or "0.0.0.0"
      }
    end
  end

local wanStatusDetails
if variant == "NZ" then
  wanStatusDetails = {}
  for _,data in pairs(getWanStatistics("ipv4")) do
    wanStatusDetails[#wanStatusDetails + 1 ] = { data.interface, data.ll, data.address, data.duplex, data.speed, data.operstate }
  end
end

  ngx.print('\
\
<h1>');  ngx.print(T"WAN Status"); ngx.print('</h1>\
');  if variant == "VHA" then  ngx.print('\
  <h3>');  ngx.print(T"IP Version"); ngx.print('</h3>\
  <div class="h3-content content-wan-status wan-status-padding-bottom-50" id="wstatus-tbl-wanconstatus">\
    <div class="table-responsive wan-status-margin-bottom-none">\
      <table class="table wan-table wan-table-margin-bottom-none">\
        <tbody>\
          <tr>\
            <th><span>');  ngx.print(ipVersion[ipIndex]); ngx.print('</span></th>\
          </tr>\
        </tbody>\
      </table>\
    </div>\
  </div>\
');  end  ngx.print('\
<h3>');  ngx.print(T"WAN Connection Details"); ngx.print('</h3>\
');  
local columns_WanDetails = {"Interface", "Type", "NAT", "Firewall", "Status", "Connection Uptime"}
if variant == "NZ" then
  columns_WanDetails = {"Interface", "L2", "Type", "NAT", "Firewall", "Status", "Connection</br>Uptime"}
end
local classInfo_WanDetails = {
  outerDivClass = "h3-content content-wan-status wan-status-padding-bottom-50",
  outerId = "wstatus-tbl-wanconstatus",
  innerDivClass = "table-responsive wan-status-margin-bottom-none",
  innerId = "",
  tableClass = "table wan-table wan-table-margin-bottom-none",
  tableId = "",
}
ngx.print(ui_helper.createTrTable(classInfo_WanDetails, columns_WanDetails, WanDetails))

local columns_WanConDetails = {"Interface", "Type", "IPv4 Address", "IPv4 Mask", "DNS Server"}
local classInfo_WanConDetails = {
  outerDivClass = "h3-content content-wan-status wan-status-padding-bottom-50",
  outerId = "wstatus-tbl-wancondetails",
  innerDivClass = "table-responsive wan-status-margin-bottom-none",
  innerId = "",
  tableClass = "table wan-table wan-table-margin-bottom-none",
  tableId = "",
}
ngx.print(ui_helper.createTrTable(classInfo_WanConDetails, columns_WanConDetails, WanConDetails))

if variant == "NZ" then
  local columns_wanStatusDetails = {"Interface", "L2", "MAC", "Duplex", "Speed", "Up"}
  local classInfo_wanStatusDetails = {
    outerDivClass = "h3-content content-wan-status wan-status-padding-bottom-50",
    outerId = "wstatus-tbl-wanstatusdetails",
    innerDivClass = "table-responsive wan-status-margin-bottom-none",
    innerId = "",
    tableClass = "table wan-table wan-table-margin-bottom-none",
    tableId = "",
  }
  ngx.print(ui_helper.createTrTable(classInfo_wanStatusDetails, columns_wanStatusDetails, wanStatusDetails))
end
  ngx.print('\
\
<h3>');  ngx.print(T"IPv6 WAN Connection Details"); ngx.print('</h3>\
');  
local columns_Ipv6_WanDetails = {"Interface", "Type", "IPv6 Link Local Addr", "IPv6 Default Gateway", "IPv6 DNS Servers"}
local classInfo_Ipv6_WanDetails = {
  outerDivClass = "h3-content content-wan-status wan-status-padding-bottom-50",
  outerId = "wstatus-tbl-wan6condetails",
  innerDivClass = "table-responsive wan-status-margin-bottom-none",
  innerId = "",
  tableClass = "table wan-table wan-table-margin-bottom-none",
  tableId = "",
}
ngx.print(ui_helper.createTrTable(classInfo_Ipv6_WanDetails, columns_Ipv6_WanDetails, Ipv6_WanDetails))
  ngx.print('\
\
');  for _, iptype in ipairs(ipTypeSection) do  ngx.print('\
  <h3>');  ngx.print(iptype.header); ngx.print('</h3>\
  <div class="h3-content content-wan-status wan-status-padding-bottom-50" id="wstatus-tbl-wanstats">\
    <div class="table-responsive wan-status-margin-bottom-none">\
      <table class="table wan-table wan-table-margin-bottom-none">\
        <tbody>\
          <tr>\
            <th><span>');  ngx.print(T"Interface"); ngx.print('</span></th>\
            <th><span>');  ngx.print(T"Type"); ngx.print('</span></th>\
            <th><span>');  ngx.print(T"Recvd. Bytes"); ngx.print('</span></th>\
            <th><span>');  ngx.print(T"Pkts"); ngx.print('</span></th>\
            <th><span>');  ngx.print(T"Errs"); ngx.print('</span></th>\
            <th><span>');  ngx.print(T"Drops"); ngx.print('</span></th>\
            <th><span>');  ngx.print(T"Trans. Bytes"); ngx.print('</span></th>\
            <th><span>');  ngx.print(T"Pkts"); ngx.print('</span></th>\
            <th><span>');  ngx.print(T"Errs"); ngx.print('</span></th>\
            <th><span>');  ngx.print(T"Drops"); ngx.print('</span></th>\
          </tr>\
          ');  for _, stats in ipairs(getWanStatistics(iptype.version)) do
            if not (iptype.version == "ipv4" and stats.interface == "wan6") then  ngx.print('\
              <tr>\
                <td>');  ngx.print(stats.interface); ngx.print('</td>\
                <td>');  ngx.print(stats.type); ngx.print('</td>\
                <td>');  ngx.print(stats.rxBytes); ngx.print('</td>\
                <td>');  ngx.print(stats.rxPackets); ngx.print('</td>\
                <td>');  ngx.print(stats.rxErrors); ngx.print('</td>\
                <td>');  ngx.print(stats.rxDrops); ngx.print('</td>\
                <td>');  ngx.print(stats.txBytes); ngx.print('</td>\
                <td>');  ngx.print(stats.txPackets); ngx.print('</td>\
                <td>');  ngx.print(stats.txErrors); ngx.print('</td>\
                <td>');  ngx.print(stats.txDrops); ngx.print('</td>\
                <input type="hidden" class="interface" value="');  ngx.print(stats.paramindex); ngx.print('">\
              </tr>\
            ');  end
          end  ngx.print('\
        </tbody>\
      </table>\
    </div>\
    <div class="row padding-top-bottom-20">\
      <input type="hidden" class="ip_version" value="');  ngx.print(iptype.version); ngx.print('">\
      <div class="col-md-12 col-sm-12 col-xs-12 pull-right text-right">\
        <input class="button button-cancel mob-button-width mob-apply-cancel" id="wanstatus-btn-resetstats_');  ngx.print(iptype.version); ngx.print('" value="');  ngx.print(T"Reset Statistics"); ngx.print('" type="button">\
      </div>\
    </div>\
  </div>\
');  end  ngx.print('\
\
<h3>');  ngx.print(T"ATM statistics"); ngx.print('</h3>\
<div class="h3-content atmStatsContent vdf-table">\
  ');  for _, param in ipairs(headers) do
    local ATM_row = {
      element = ui_helper.createOnlyText({}, atmStats[param[1]]),
      rowClass = "vdf-row",
      label = param[2]
    }
    ngx.print(ui_helper.createRow(ATM_row))
  end  ngx.print('\
</div>\
<div class="row padding-top-bottom-20">\
  <div class="col-md-12 col-sm-12 col-xs-12 pull-right text-right">\
    <input class="interface" value="atm" type="hidden">\
    <input class="button button-cancel mob-button-width mob-apply-cancel" id = "wanstatus-btn-resetstats_atm" value="');  ngx.print(T"Reset Statistics"); ngx.print('" type="button">\
  </div>\
</div>\
\
<script>\
  // handles reset statistics and reloads the page with updated values\
  function resetStatistics(additionalParams) {\
    $(this).attr("disabled", true).addClass("table-button-faded");\
    var params = {\
      CSRFtoken: "');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('",\
      action: "reset",\
    }\
    $.extend(params, additionalParams);\
    $("#content").load("/modals/status-support/wanStatus.lp", params);\
  }\
\
  $(function(){\
    // handler for Reset Statistics button under WAN Statistics Section\
    $("#wanstatus-btn-resetstats_ipv4, #wanstatus-btn-resetstats_ipv6").click(function(){\
      var interface = [];\
      $(this).closest(".content-wan-status").find(".interface").each(function() {\
        interface.push($(this).val());\
      });\
      resetStatistics.call(this, {\
        iptype: $(this).closest(".row").find(".ip_version").val(),\
        interface: interface.join(",")\
      })\
    });\
\
    // handler for Reset Statistics button under ATM Statistics Section\
    $("#wanstatus-btn-resetstats_atm").click(function() {\
      resetStatistics.call(this, {\
        statisticsType: "atm"\
      })\
    });\
  });\
</script>\
'); 