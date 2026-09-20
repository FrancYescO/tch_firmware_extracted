--pretranslated: do not change this file
 
----Enable Localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local vdf_helper = require("vodafone_helper")
local ui_helper = require("vdf_ui_helper")
local secondsToHours = vdf_helper.secondsToHours
local string = string
local untaint_mt = require("web.taint").untaint_mt
local ngx, untaint, ipairs, tonumber = ngx, string.untaint, ipairs, tonumber
local arpData   = content_helper.convertResultToObject("sys.proc.net.arp.", proxy.get("sys.proc.net.arp."))
local leaseData = content_helper.convertResultToObject("rpc.hosts.host.", proxy.get("rpc.hosts.host."))
local staticInfo = content_helper.convertResultToObject("uci.dhcp.host.", proxy.get("uci.dhcp.host."))
local vfwifiClient = content_helper.convertResultToObject("rpc.services.x_vfwifi.client.", proxy.get("rpc.services.x_vfwifi.client."))
local variant = vdf_helper.getVariant()
local leaseInfo = {}
local deviceCount ={}
local deviceDuplicate = {}
local MACDuplicate = {}
local lanDevicesCount = 0

if ngx.var.request_method == "POST" and ngx.req.get_post_args().reset then
   local resetTable = {
     ["sys.class.net.@br-lan.statistics.ipv4.reset"] = "1",
     ["sys.class.net.@br-lan.statistics.ipv6.reset"] = "1"
   }
   proxy.set(resetTable)
   proxy.apply()
end

local qtnMac = {mac = "uci.env.var.qtn_eth_mac"}
content_helper.getExactContent(qtnMac)
qtnMac.mac = qtnMac.mac and qtnMac.mac:lower() or ""
local wifi_24Count, wifi_5Count = 0, 0 -- Number of active devices connected to wifi 2.4Ghz/5Ghz
local timeDuration
for _, data in ipairs(leaseData) do
  if data["LeaseType"] ~= "" then
    leaseInfo[#leaseInfo + 1] = {}
    leaseInfo[#leaseInfo].hostName = data["FriendlyName"]
    leaseInfo[#leaseInfo].MACAddress = data["MACAddress"]
    leaseInfo[#leaseInfo].IPAddress =  data["IPAddress"] ~= "" and  data["IPAddress"] or data["DhcpLeaseIP"]
    leaseInfo[#leaseInfo].type = data["LeaseType"]
    leaseInfo[#leaseInfo].interface = data["L2Interface"]
    leaseInfo[#leaseInfo].status = data["State"]
    local totalHrs, totalMts, totalSec = secondsToHours(tonumber(data["LeaseTimeRemaining"]))
    if tonumber(totalHrs) >= 1 then
      timeDuration = totalHrs.."h"..", "..totalMts.."m"
    elseif tonumber(totalMts) >= 1 then
      timeDuration = totalMts.."m"
    else
      timeDuration = totalSec.."sec"
    end
    leaseInfo[#leaseInfo].expiresIn = timeDuration
    MACDuplicate[data.MACAddress] = true
  end

  -- Determine the number of active devices connected to wifi 2.4Ghz/5Ghz interfaces
  if data.L2Interface == "wl0" then
    wifi_24Count = data.State == "1" and wifi_24Count + 1 or wifi_24Count
  elseif data.L2Interface == "wl1" then
    wifi_5Count = data.State == "1" and wifi_5Count + 1 or wifi_5Count
  elseif deviceDuplicate[data.L2Interface]  then
    deviceCount[untaint(data.L2Interface)] = deviceCount[untaint(data.L2Interface)] + 1
  else
    deviceCount[untaint(data.L2Interface)] = 1
    deviceDuplicate[data.L2Interface] = true
  end

  if data.L3Interface == "br-lan" then
    lanDevicesCount = lanDevicesCount + 1
  end
end

-- Get the state of each wifi interfaces
local getWifiStates = {
  wifiState24 = "uci.wireless.wifi-ap.@ap0.state",
  wifiState5  = "uci.wireless.wifi-ap.@ap1.state",
}
content_helper.getExactContent(getWifiStates)

for _, info in ipairs(staticInfo) do
  if not MACDuplicate[info.mac] then
    leaseInfo[#leaseInfo + 1 ] = {}
    leaseInfo[#leaseInfo].hostName = info["name"]
    leaseInfo[#leaseInfo].MACAddress = info["mac"]
    leaseInfo[#leaseInfo].IPAddress = info["ip"]
    leaseInfo[#leaseInfo].type = T"Static"
    leaseInfo[#leaseInfo].interface = ""
    leaseInfo[#leaseInfo].status = T"Inactive"
  end
end

local IPv6Details = {
  IPv6Intf         = "rpc.network.interface.@lan.ifname",
  IPv6Global       = "rpc.network.interface.@lan.ipv6uniqueglobaladdr",
  IPv6UniqueLocal  = "rpc.network.interface.@lan.ipv6uniquelocaladdr",
  IPv6LinkLocal    = "rpc.network.interface.@lan.ipv6linklocaladdr",
  IPv6DHCPAddrPool = "rpc.network.interface.@lan.ipv6dhcpaddresspool",
  IPv6DefaultGW    = "uci.network.interface.@lan.ip6gw",
  IPv6DNS          = "uci.network.interface.@lan.dnsset",
  IPv6State        = "uci.network.interface.@lan.ipv6"
}content_helper.getExactContent(IPv6Details)


local data_Ipv6_Lan_Details = {
  {
    IPv6Details and IPv6Details.IPv6Intf,
    IPv6Details and IPv6Details.IPv6Global,
    IPv6Details and IPv6Details.IPv6UniqueLocal,
    IPv6Details and IPv6Details.IPv6LinkLocal,
    IPv6Details and IPv6Details.IPv6DHCPAddrPool,
    IPv6Details and IPv6Details.IPv6DefaultGW,
    IPv6Details and IPv6Details.IPv6DNS
  }
}
data_Ipv6_Lan_Details = setmetatable(data_Ipv6_Lan_Details, untaint_mt)

local dataDevice = {}
local dataDhcp = {}
local dataIpv4_Lan_Stats = {}
local dataIpv6_Lan_Stats = {}
local data_wifi = {}

for _,data in ipairs(arpData) do
  if data and data.device == "br-lan" then
    if qtnMac.mac ~= data.hw_address then
      dataDevice[#dataDevice + 1 ] = {
        data.ip_address,
        data.hw_type,
        data.flags,
        data.hw_address,
        data.device
      }
    end
  end
end

for _, data in ipairs(leaseInfo) do
  if data then
    if data.status == "1" then
      data.status = T"Active"
    else
      data.status = T"Inactive"
    end
    if data.expiresIn == "00sec" then
      data.expiresIn = T"0sec"
    else
      data.expiresIn = data.expiresIn
    end
    dataDhcp[#dataDhcp + 1] = {
      data.hostName,
      data.MACAddress,
      data.IPAddress,
      data.type,
      data.interface,
      data.status,
      data.expiresIn
    }
  end
end

for _, stats in ipairs(vfwifiClient) do
  data_wifi[#data_wifi + 1] = {
    stats.MAC or "",
    stats.SSID or "",
    stats.SessionDuration or ""
  }
end

-- Interface names needs to be changed for the lab2 boards
local lanStatsPathbrlan = content_helper.convertResultToObject("sys.class.net.@br-lan.", proxy.get("sys.class.net.@br-lan."))

for _, stats in ipairs(lanStatsPathbrlan) do
  dataIpv4_Lan_Stats[#dataIpv4_Lan_Stats + 1] = {
    "br-lan",
    stats["ipv4.rx_bytes"],
    stats["ipv4.rx_packets"],
    stats["ipv4.rx_errors"],
    stats["ipv4.rx_dropped"],
    stats["ipv4.tx_bytes"],
    stats["ipv4.tx_packets"],
    stats["ipv4.tx_errors"],
    stats["ipv4.tx_dropped"],
    lanDevicesCount
  }
end

if IPv6Details.IPv6State == "1" then
  for _, stats in ipairs(lanStatsPathbrlan) do
    dataIpv6_Lan_Stats[#dataIpv6_Lan_Stats + 1] = {
      "br-lan",
      stats["ipv6.rx_bytes"],
      stats["ipv6.rx_packets"],
      stats["ipv6.rx_errors"],
      stats["ipv6.rx_dropped"],
      stats["ipv6.tx_bytes"],
      stats["ipv6.tx_packets"],
      stats["ipv6.tx_errors"],
      stats["ipv6.tx_dropped"],
      lanDevicesCount
    }
  end
end
  ngx.print('\
\
<h1>');  ngx.print(T"LAN Status"); ngx.print('</h1>\
<h3>');  ngx.print(T"Device info ARP"); ngx.print('</h3>\
');  
local columns_ARP = {"IP address", "HW Type", "Flags", "HW Address", "Device"}
local classInfo_ARP = {
  outerDivClass = "h3-content content-lan-status",
  outerId = "",
  innerDivClass = "table-responsive",
  innerId = "",
  tableClass = "table lan-table",
  tableId = "lstatus-tbl-arp",
}
ngx.print(ui_helper.createTrTable(classInfo_ARP, columns_ARP, dataDevice))
  ngx.print('\
\
<h3>');  ngx.print(T"Device info DHCP Leases"); ngx.print('</h3>\
');  
local columns_DHCP = {"Host Name", "MAC Address", "IP address", "Type", "Interface", "Status", "Expires in"}
local classInfo_DHCP = {
  outerDivClass = "h3-content content-lan-status",
  outerId = "",
  innerDivClass = "table-responsive",
  innerId = "",
  tableClass = "table lan-table",
  tableId = "lstatus-tbl-dhcplease",
}
ngx.print(ui_helper.createTrTable(classInfo_DHCP, columns_DHCP, dataDhcp))
  ngx.print('\
\
<h3>');  ngx.print(T"IPv6 LAN Connection Details"); ngx.print('</h3>\
');  
local columns_IPv6_LanDetails = {"Interface", "IPv6 Global Addr", "IPv6 Unique Local Addr", "IPv6 Link Local Addr", "IPv6 DHCP Addr Pool", "IPv6 Default Gateway", "IPv6 DNS Servers"}
local classInfo_IPv6_LanDetails = {
  outerDivClass = "h3-content content-lan-status",
  outerId = "",
  innerDivClass = "table-responsive",
  innerId = "",
  tableClass = "table lan-table",
  tableId = "lstatus-tbl-ipv6landetails",
}
ngx.print(ui_helper.createTrTable(classInfo_IPv6_LanDetails, columns_IPv6_LanDetails, data_Ipv6_Lan_Details))
  ngx.print('\
\
<h3>');  ngx.print(T"IPv4 LAN statistics"); ngx.print('</h3>\
');  
local columns_IPv4_LanStats = {"Interface", "Recvd. Bytes", "Pkts", "Errs", "Drops", "Trans. Bytes", "Pkts", "Errs", "Drops", "Devices"}
local classInfo_IPv4_LanStats = {
  outerDivClass = "h3-content content-lan-status",
  outerId = "",
  innerDivClass = "table-responsive",
  innerId = "",
  tableClass = "table lan-table",
  tableId = "lstatus-tbl-lanstats",
}
ngx.print(ui_helper.createTrTable(classInfo_IPv4_LanStats, columns_IPv4_LanStats, dataIpv4_Lan_Stats))
  ngx.print('\
\
<h3>');  ngx.print(T"IPv6 LAN statistics"); ngx.print('</h3>\
');  
local columns_IPv6_LanStats = {"Interface", "Recvd. Bytes", "Pkts", "Errs", "Drops", "Trans. Bytes", "Pkts", "Errs", "Drops", "Devices"}
local classInfo_IPv6_LanStats = {
  outerDivClass = "h3-content content-lan-status",
  outerId = "",
  innerDivClass = "table-responsive",
  innerId = "",
  tableClass = "table lan-table",
  tableId = "lstatus-tbl-lanstats",
}
ngx.print(ui_helper.createTrTable(classInfo_IPv6_LanStats, columns_IPv6_LanStats, dataIpv6_Lan_Stats))
  ngx.print('\
');  if variant ~= "NZ" then  ngx.print('\
<h3>');  ngx.print(T"Vodafone WiFi network devices"); ngx.print('</h3>\
');  
local columns_wifi = {"MAC", "SSID", "Session Duration"}
local classInfo_wifi = {
  outerDivClass = "h3-content content-lan-status",
  outerId = "",
  innerDivClass = "table-responsive",
  innerId = "",
  tableClass = "table lan-table",
  tableId = "lstatus-tbl-vfwificlientstbl",
}
ngx.print(ui_helper.createTrTable(classInfo_wifi, columns_wifi, data_wifi))
  ngx.print('\
');  end  ngx.print('\
\
<form id="lanStatus_form" class="form-horizontal" method="post" action="modals/status-support/lanStatus.lp">\
  <input type="hidden" name= "CSRFtoken" id= "CSRFtoken" value = "');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('"></input>\
  <input type="hidden" name= "reset" id= "reset" value = "resetStat"></input>\
  <div class="row padding-top-bottom-20">\
    <div class="col-md-12 col-sm-6 col-xs-12 pull-right text-right">\
    <input class="button button-cancel mob-button-width mob-apply-cancel" value="');  ngx.print(T"Reset Statistics"); ngx.print('" id= "lanstatus-btn-resetstats" type="button">\
    </div>\
  </div>\
</form>\
<!--</div> -->\
<script>\
$(function(){\
  $("#lanstatus-btn-resetstats").click(function(){\
    $("#lanstatus-btn-resetstats").attr("disabled",true)\
    $("#lanstatus-btn-resetstats").addClass("table-button-faded");\
    var target = "/modals/status-support/lanStatus.lp";\
    var form = $("#lanStatus_form");\
    var params = form.serializeArray();\
    $("#content").load(target, params);\
});\
});\
</script>\
'); 