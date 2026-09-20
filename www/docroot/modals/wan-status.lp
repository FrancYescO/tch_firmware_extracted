--pretranslated: do not change this file
 
--Enable Localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local string, table, math, unpack = string, table, math, unpack
local format, match, sort, tolower =  string.format, string.match, table.sort, string.lower
local ipairs, ngx, tonumber, tostring = ipairs, ngx, tonumber, tostring
local resetStatTable, resetTable = {}, {}
local vdf_helper = require("vodafone_helper")
local secondsToHours = vdf_helper.secondsToHours
local wanUptime, wanIPAddress, wanIPMask, wanDNS

local ignoreInterface = {
  ["adsl"] = true,
  ["vdsl"] = true,
  ["ewan"] = true,
  ["voip"] = true,
  ["wan6"] = true,
  ["iptv"] = true,
  ["lan"] = true,
  ["loopback"] = true,
  ["dummy"] = true,
}

local lowerlayer = {
  atm_wan = "ADSL",
  ptm0 = "VDSL",
  vlanptm0 = "VDSL",
  eth4 = "Fibre",
  vlanwan = "Fibre",
}

local wanStatusCommonGet = {
  ["l3type"] = "uci.wansensing.global.l3type",
  ["firewallStatus"] = "rpc.network.firewall.enable",
}content_helper.getExactContent(wanStatusCommonGet)

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

if ngx.var.request_method == "POST" and ngx.req.get_post_args().reset then
  local postArgs = ngx.req.get_post_args()
  local resetStatValue = string.untaint(postArgs.paramIndexList)
  for paramindex in string.gmatch(resetStatValue, '([^,]+)') do
    resetStatTable["sys.class.net." .. paramindex .. ".statistics.reset"] = "1"
  end
 proxy.set(resetStatTable)
 proxy.apply()
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

local find = string.find
-- Description Function to get the list of network values
-- @function getNetworkValues
-- @return table
function getNetworkValues()
  local natInfo =  proxy.get("uci.firewall.zone.")
  local maskList = {}
  for _, v in ipairs(natInfo) do
    if v.param == "masq" then
      local index = match(v.path, "uci.firewall.zone.(%d+).")
      maskList["masq"..index] = v.value
    end
  end
  local resultList = {}
  for _, v in ipairs(natInfo) do
    local index = match(v.path, "uci.firewall.zone.(%d+).network")
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
    wanConInfo[#wanConInfo].ll = data["ppp.ll_intf"]
    wanConInfo[#wanConInfo].up = data["up"]
    wanConInfo[#wanConInfo].upTime = data["uptime"]
    wanConInfo[#wanConInfo].IPAddress = data["ipaddr"]
    wanConInfo[#wanConInfo].IPMask = data["ipmask"]
    wanConInfo[#wanConInfo].DNSServer = data["dnsservers"]
    wanConInfo[#wanConInfo].IPv6LinkAddress = data["ipv6linklocaladdr"]
    wanConInfo[#wanConInfo].nextHop = data["nexthop"]
    wanConInfo[#wanConInfo].ifName = data["ifname"]
    if data['ifname'] ~= "" and data['ifname'] ~= "SET_BY_SCRIPT" and wanConInfo[#wanConInfo].interface ~= "wan6" then
      statsPath[#statsPath+1] = format("sys.class.net.@%s.", data['ppp.ll_intf'])
    end
  end
end
sort(wanConInfo, function(interface1, interface2)
  return tostring(interface1.interface) < tostring(interface2.interface)
end)

local wanStatsData = {}
for wanPathIndex, wanPath in ipairs(statsPath) do
  if not proxy.getPN(wanPath, false) then
     statsPath[wanPathIndex] = nil
  end
end
local wanStats = content_helper.convertResultToObject("sys.class.net.", proxy.get(unpack(statsPath)))

for _,stats in ipairs(wanStats) do
  wanStatsData[#wanStatsData + 1] = {}
  table.insert(resetTable,stats["paramindex"])
  local paramIndexName =  match(stats["paramindex"], "([%w%-%_]+)")
  for _,name in ipairs(wanConInfo) do
    if paramIndexName == name["ll"] then
      wanStatsData[#wanStatsData].interface = name["interface"]
      wanStatsData[#wanStatsData].type = name["type"]
      break
    end
  end
  wanStatsData[#wanStatsData].ll        = paramIndexName
  wanStatsData[#wanStatsData].duplex    = stats["duplex"]
  wanStatsData[#wanStatsData].speed     = stats["speed"]
  wanStatsData[#wanStatsData].mtu       = stats["mtu"]
  wanStatsData[#wanStatsData].address   = stats["address"]
  wanStatsData[#wanStatsData].operstate = stats["operstate"]
  wanStatsData[#wanStatsData].rxBytes   = stats["statistics.rx_bytes"]
  wanStatsData[#wanStatsData].rxPackets = stats["statistics.rx_packets"]
  wanStatsData[#wanStatsData].rxErrors  = stats["statistics.rx_errors"]
  wanStatsData[#wanStatsData].rxDrops   = stats["statistics.rx_dropped"]
  wanStatsData[#wanStatsData].txBytes   = stats["statistics.tx_bytes"]
  wanStatsData[#wanStatsData].txPackets = stats["statistics.tx_packets"]
  wanStatsData[#wanStatsData].txErrors  = stats["statistics.tx_errors"]
  wanStatsData[#wanStatsData].txDrops   = stats["statistics.tx_dropped"]
end
sort(wanStatsData, function(interface1, interface2)
  return tostring(interface1.interface) < tostring(interface2.interface)
end)
local paramTable = table.concat(resetTable,",")
  ngx.print('\
\
<h1>');  ngx.print(T"WAN Status"); ngx.print('</h1>\
<h3>');  ngx.print(T"WAN Connection Details"); ngx.print('</h3>\
<div class="h3-content content-wan-status wan-status-padding-bottom-50" id="wstatus-tbl-wanconstatus">\
  <div class="table-responsive wan-status-margin-bottom-none">\
    <table class="table wan-table wan-table-margin-bottom-none">\
      <tbody>\
        <tr>\
          <th><span>');  ngx.print(T"Interface"); ngx.print('</span></th>\
          <th><span>');  ngx.print(T"L2"); ngx.print('</span></th>\
          <th><span>');  ngx.print(T"Type"); ngx.print('</span></th>\
          <th><span>');  ngx.print(T"NAT"); ngx.print('</span></th>\
          <th><span>');  ngx.print(T"Firewall"); ngx.print('</span></th>\
          <th><span>');  ngx.print(T"Status"); ngx.print('</span></th>\
          <th><span>');  ngx.print(T"Connection</br>Uptime"); ngx.print('</span></th>\
        </tr>\
        ');  
         local networkList = getNetworkValues()
         for _, data in ipairs(wanConInfo) do
           if not ignoreInterface[data.interface] then
           ngx.print('\
          <tr>\
            <td>');  ngx.print(data and data["interface"]); ngx.print('</td>\
            <td>');  ngx.print(data and data["ll"]); ngx.print('</td>\
            <td>');  ngx.print(data and data["type"]); ngx.print('</td>\
            <td>\
            ');  
              ngx.print(networkList[string.untaint(data.interface)] == "1" and T"Enabled" or T"Disabled")
              ngx.print('\
            </td>\
            <td>');  if wanStatusCommonGet and wanStatusCommonGet.firewallStatus == "1" then  ngx.print(T"Enabled"); else  ngx.print(T"Disabled"); end  ngx.print('</td>\
            ');  if wanStatusCommonGet and tolower(wanStatusCommonGet["l3type"]) == tolower(data["interface"]) then
                data["upTime"] = wanUptime
                data["up"] = "1"
              end   ngx.print('\
            <td><span>');  if data and data["up"] == "1"then  ngx.print(T"Up"); else  ngx.print(T"Down"); end  ngx.print('</span></td>\
            <td>\
\
              ');  if data and data["upTime"] and data["upTime"] ~= "" then  ngx.print('\
                ');  local totalHrs, totalMts, totalSec = secondsToHours(tonumber(data["upTime"]))  ngx.print('\
                ');  local timeDuration = totalHrs..":"..totalMts..":"..totalSec  ngx.print('\
                ');  ngx.print(timeDuration.."s"); else  ngx.print("0s"); ngx.print('\
              ');  end  ngx.print('\
            </td>\
          </tr>\
          ');  end  ngx.print('\
        ');  end  ngx.print('\
      </tbody>\
    </table>\
  </div>\
</div>\
\
<div class="h3-content content-wan-status wan-status-padding-bottom-50" id = "wstatus-tbl-wancondetails">\
  <div class="table-responsive wan-status-margin-bottom-none">\
    <table class="table wan-table wan-table-margin-bottom-none">\
      <tbody>\
        <tr>\
          <th><span>');  ngx.print(T"Interface"); ngx.print('</span></th>\
          <th><span>');  ngx.print(T"Type"); ngx.print('</span></th>\
          <th><span>');  ngx.print(T"IPv4 Address"); ngx.print('</span></th>\
          <th><span>');  ngx.print(T"IPv4 Mask"); ngx.print('</span></th>\
          <th><span>');  ngx.print(T"DNS Server"); ngx.print('</span></th>\
        </tr>\
        ');  for _, data in ipairs(wanConInfo) do  ngx.print('\
          ');  if data["interface"] ~= "wan6" and not ignoreInterface[data.interface] then   ngx.print('\
            <tr>\
              <td>');  ngx.print(data and data["interface"]); ngx.print('</td>\
              <td>');  ngx.print(data and data["type"]); ngx.print('</td>\
              ');  if wanStatusCommonGet and tolower(wanStatusCommonGet["l3type"]) == tolower(data["interface"]) then
                data["IPAddress"] = wanIPAddress
                data["IPMask"] = wanIPMask
                data["DNSServer"] = wanDNS
              end   ngx.print('\
              <td>');  ngx.print(data and data["IPAddress"] ~= "" and data["IPAddress"] or "0.0.0.0"); ngx.print('</td>\
              <td>');  ngx.print(data and data["IPMask"] ~="" and netmask2mask(tonumber(data["IPMask"])) or "0.0.0.0"); ngx.print('</td>\
              <td>');  ngx.print(data and data["DNSServer"]~= "" and data["DNSServer"] or "0.0.0.0"); ngx.print('</td>\
            </tr>\
          ');  end  ngx.print('\
        ');  end   ngx.print('\
      </tbody>\
    </table>\
  </div>\
</div>\
<h3>');  ngx.print(T"IPv6 WAN Connection Details"); ngx.print('</h3>\
<div class="h3-content content-wan-status wan-status-padding-bottom-50" id="wstatus-tbl-wan6condetails">\
  <div class="table-responsive wan-status-margin-bottom-none">\
    <table class="table wan-table wan-table-margin-bottom-none">\
      <tbody>\
        <tr>\
          <th><span>');  ngx.print(T"Interface"); ngx.print('</span></th>\
          <th><span>');  ngx.print(T"Type"); ngx.print('</span></th>\
          <th><span>');  ngx.print(T"IPv6 Link Local Addr"); ngx.print('</span></th>\
          <th><span>');  ngx.print(T"IPv6 Default Gateway"); ngx.print('</span></th>\
          <th><span>');  ngx.print(T"IPv6 DNS Servers"); ngx.print('</span></th>\
        </tr>\
        ');  for _, data in ipairs(wanConInfo) do
          if data["interface"] == "wan6" then   ngx.print('\
            <tr>\
              <td>');  ngx.print(data and data["interface"]); ngx.print('</td>\
              <td>');  ngx.print(data and data["type"]); ngx.print('</td>\
              <td>');  ngx.print(data and data["IPv6LinkAddress"]); ngx.print('</td>\
              <td>');  ngx.print(data and data["nextHop"]); ngx.print('</td>\
              <td>');  ngx.print(data and data["DNSServer"]); ngx.print('</td>\
            </tr>\
          ');  end
        end   ngx.print('\
      </tbody>\
    </table>\
  </div>\
</div>\
<h3>');  ngx.print(T"IPv4 WAN statistics"); ngx.print('</h3>\
<div class="h3-content content-wan-status wan-status-padding-bottom-50" id="wstatus-tbl-wanstats1">\
  <div class="table-responsive wan-status-margin-bottom-none">\
    <table class="table wan-table wan-table-margin-bottom-none">\
      <tbody>\
        <tr>\
          <th><span>');  ngx.print(T"Interface"); ngx.print('</span></th>\
          <th><span>');  ngx.print(T"L2"); ngx.print('</span></th>\
          <th><span>');  ngx.print(T"MAC"); ngx.print('</span></th>\
          <th><span>');  ngx.print(T"Duplex"); ngx.print('</span></th>\
          <th><span>');  ngx.print(T"Speed"); ngx.print('</span></th>\
          <th><span>');  ngx.print(T"Up"); ngx.print('</span></th>\
        </tr>\
        ');  for _, stats in ipairs(wanStatsData) do  ngx.print('\
          <tr>\
            <td>');  ngx.print(stats and stats["interface"]); ngx.print('</td>\
            <td>');  ngx.print(stats and stats["ll"]); ngx.print('</td>\
            <td>');  ngx.print(stats and stats["address"]); ngx.print('</td>\
            <td>');  ngx.print(stats and stats["duplex"]); ngx.print('</td>\
            <td>');  ngx.print(stats and stats["speed"]); ngx.print('</td>\
            <td>');  ngx.print(stats and stats["operstate"]); ngx.print('</td>\
          </tr>\
        ');  end  ngx.print('\
      </tbody>\
    </table>\
  </div>\
</div>\
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
        ');  for _, stats in ipairs(wanStatsData) do  ngx.print('\
          <tr>\
            <td>');  ngx.print(stats and stats["interface"]); ngx.print('</td>\
            <td>');  ngx.print(stats and stats["type"]); ngx.print('</td>\
            <td>');  ngx.print(stats and stats["rxBytes"]); ngx.print('</td>\
            <td>');  ngx.print(stats and stats["rxPackets"]); ngx.print('</td>\
            <td>');  ngx.print(stats and stats["rxErrors"]); ngx.print('</td>\
            <td>');  ngx.print(stats and stats["rxDrops"]); ngx.print('</td>\
            <td>');  ngx.print(stats and stats["txBytes"]); ngx.print('</td>\
            <td>');  ngx.print(stats and stats["txPackets"]); ngx.print('</td>\
            <td>');  ngx.print(stats and stats["txErrors"]); ngx.print('</td>\
            <td>');  ngx.print(stats and stats["txDrops"]); ngx.print('</td>\
          </tr>\
        ');  end  ngx.print('\
      </tbody>\
    </table>\
  </div>\
  <form id="wanStatus_form" class="form-horizontal" method="post" action="modals/wan-status.lp">\
    <input type="hidden" name= "CSRFtoken" id= "CSRFtoken" value = "');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('"></input>\
    <input type="hidden" name= "reset" id= "reset" value = "');  ngx.print(T"resetStat"); ngx.print('"></input>\
    <div class="row padding-top-bottom-20">\
      <div class="col-md-12 col-sm-12 col-xs-12 pull-right text-right">\
        <input class="button button-cancel mob-button-width mob-apply-cancel" id = "wanstatus-btn-resetipv4" value="');  ngx.print(T"Reset Statistics"); ngx.print('" type="button">\
      </div>\
    </div>\
  </form>\
</div>\
\
<script>\
  $(function(){\
    $("#wanstatus-btn-resetipv4").click(function(){\
      $("#wanstatus-btn-resetipv4").attr("disabled",true)\
      $("#wanstatus-btn-resetipv4").addClass("table-button-faded");\
      var target = "/modals/wan-status.lp";\
      var form = $("#wanStatus_form");\
      var params = form.serializeArray();\
      params.push({\
        name : "paramIndexList",\
        value : "');  ngx.print(paramTable); ngx.print('"\
      });\
      $("#content").load(target, params);\
    });\
  });\
</script>\
'); 