--pretranslated: do not change this file
 
----Enable Localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local vdf_helper = require("vodafone_helper")
local secondsToHours = vdf_helper.secondsToHours
local string = string
local match, sort, ngx, untaint, ipairs, math, tonumber  = string.match, table.sort, ngx, string.untaint, ipairs, math, tonumber

local arpData   = content_helper.convertResultToObject("sys.proc.net.arp.", proxy.get("sys.proc.net.arp."))
local leaseData = content_helper.convertResultToObject("rpc.hosts.host.", proxy.get("rpc.hosts.host."))
local staticInfo = content_helper.convertResultToObject("uci.dhcp.host.", proxy.get("uci.dhcp.host."))
local leaseInfo = {}
local deviceCount ={}
local deviceDuplicate = {}
local MACDuplicate = {}

if ngx.var.request_method == "POST" and ngx.req.get_post_args().reset then
   local resetTable = {
     ["sys.class.net.@eth0.statistics.reset"] = "1",
     ["sys.class.net.@eth1.statistics.reset"] = "1",
     ["sys.class.net.@eth2.statistics.reset"] = "1",
     ["sys.class.net.@eth5.statistics.reset"] = "1",
     ["sys.class.net.@wl0.statistics.reset"] = "1"
   }
   proxy.set(resetTable)
   proxy.apply()
end

local qtnMac = {mac = "uci.env.var.qtn_eth_mac"}
content_helper.getExactContent(qtnMac)
qtnMac.mac = qtnMac.mac and qtnMac.mac:lower() or ""
local wifi_24Count, wifi_5Count = 0, 0 -- Number of active devices connected to wifi 2.4Ghz/5Ghz

for _, data in ipairs(leaseData) do
  if data["LeaseType"] ~= "" then
    leaseInfo[#leaseInfo + 1] = {}
    leaseInfo[#leaseInfo].hostName = data["FriendlyName"]
    leaseInfo[#leaseInfo].MACAddress = data["MACAddress"]
    leaseInfo[#leaseInfo].IPAddress =  data["IPAddress"] ~= "" and  data["IPAddress"] or data["DhcpLeaseIP"]
    leaseInfo[#leaseInfo].type = data["LeaseType"]
    leaseInfo[#leaseInfo].interface = data["L2Interface"]
    leaseInfo[#leaseInfo].status = data["State"]
    --[[local totalHrs, totalMts, totalSec = secondsToHours(tonumber(data["LeaseTimeRemaining"])) TODO
    local timeDuration
    if totalHrs == "00" and totalMts == "00" then
      timeDuration = totalSec.."sec"
    end
    if totalHrs == "00" then
      timeDuration = totalMts.."m"
    end
    timeDuration = totalHrs.."h,"..totalMts.."m"
    leaseInfo[#leaseInfo].expriesIn = timeDuration]]--
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
end

-- Get the state of each wifi interfaces
local getWifiStates = {
  wifiState24 = "uci.wireless.wifi-ap.@ap0.state",
  wifiState5  = "uci.wireless.wifi-ap.@ap1.state",
}
content_helper.getExactContent(getWifiStates)

local wifiStats24, wifiStats5 = false, false -- Flag to determine whether to show stats of wifi interfaces(2.4Ghz/5Ghz) as zero or not

-- Show the stats only if the wifi interface(2.4Ghz/5Ghz) is up and also if any device has been connected to it
if (getWifiStates["wifiState24"] == "1" and wifi_24Count > 0) then
  wifiStats24 = true
end
if (getWifiStates["wifiState5"] == "1" and wifi_5Count > 0) then
  wifiStats5 = true
end

for _, info in ipairs(staticInfo) do
  if not MACDuplicate[info.mac] then
    leaseInfo[#leaseInfo + 1 ] = {}
    leaseInfo[#leaseInfo].hostName = info["name"]
    leaseInfo[#leaseInfo].MACAddress = info["mac"]
    leaseInfo[#leaseInfo].IPAddress = info["ip"]
    leaseInfo[#leaseInfo].type = T"Static"
    leaseInfo[#leaseInfo].interface = ""
    leaseInfo[#leaseInfo].status = T"Inactive"
    leaseInfo[#leaseInfo].expriesIn = ""
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
}content_helper.getExactContent(IPv6Details)


-- Interface names needs to be changed for the lab2 boards
local lanStatsPatheth0 = content_helper.convertResultToObject("sys.class.net.@eth0.", proxy.get("sys.class.net.@eth0."))
local lanStatsPatheth1 = content_helper.convertResultToObject("sys.class.net.@eth1.", proxy.get("sys.class.net.@eth1."))
local lanStatsPatheth2 = content_helper.convertResultToObject("sys.class.net.@eth2.", proxy.get("sys.class.net.@eth2."))
local lanStatsPathwl1 = content_helper.convertResultToObject("sys.class.net.@eth5.", proxy.get("sys.class.net.@eth5."))
local lanStatsPathwl0 = content_helper.convertResultToObject("sys.class.net.@wl0.", proxy.get("sys.class.net.@wl0."))
  ngx.print('\
<h1>');  ngx.print(T"LAN Status"); ngx.print('</h1>\
<h3>');  ngx.print(T"Device info ARP"); ngx.print('</h3>\
<div class="h3-content content-lan-status">\
  <div class="table-responsive">\
	  <table class="table lan-table" id="lstatus-tbl-arp">\
		<tbody><tr>\
				<th><span>');  ngx.print(T"IP address"); ngx.print('</span></th>\
				<th><span>');  ngx.print(T"HW Type"); ngx.print('</span></th>\
				<th><span>');  ngx.print(T"Flags"); ngx.print('</span></th>\
				<th><span>');  ngx.print(T"HW Address"); ngx.print('</span></th>\
				<th><span>');  ngx.print(T"Device"); ngx.print('</span></th>\
			</tr>\
            ');  for _,data in ipairs(arpData) do  ngx.print('\
              ');  if data["device"] == "br-lan" then  ngx.print('\
                ');  if qtnMac.mac ~= data["hw_address"] then  ngx.print('\
                  <tr>\
                    <td>');  ngx.print(data and data["ip_address"]); ngx.print('</td>\
                    <td>');  ngx.print(data and data["hw_type"]); ngx.print('</td>\
                    <td>');  ngx.print(data and data["flags"]); ngx.print('</td>\
                    <td>');  ngx.print(data and data["hw_address"]); ngx.print('</td>\
                    <td>');  ngx.print(data and data["device"]); ngx.print('</td>\
                  </tr>\
                ');  end  ngx.print('\
              ');  end  ngx.print('\
            ');  end  ngx.print('\
	</tbody></table>\
  </div>\
</div>\
<h3>');  ngx.print(T"Device info DHCP Leases"); ngx.print('</h3>\
<div class="h3-content content-lan-status">\
  <div class="table-responsive">\
	  <table class="table lan-table" id = "lstatus-tbl-dhcplease">\
			<tbody><tr>\
				<th><span>');  ngx.print(T"Host Name"); ngx.print('</span></th>\
				<th><span>');  ngx.print(T"MAC Address"); ngx.print('</span></th>\
				<th><span>');  ngx.print(T"IP address"); ngx.print('</span></th>\
				<th><span>');  ngx.print(T"Type"); ngx.print('</span></th>\
                <th><span>');  ngx.print(T"Interface"); ngx.print('</span></th>\
				<th><span>');  ngx.print(T"Status"); ngx.print('</span></th>\
				<!--<th><span>');  ngx.print(T"Expires in"); ngx.print('</span></th> TODO-->\
			</tr>\
            ');  for _,data in ipairs(leaseInfo) do   ngx.print('\
			<tr>\
				<td>');  ngx.print(data and data["hostName"]); ngx.print('</td>\
				<td>');  ngx.print(data and data["MACAddress"]); ngx.print('</td>\
				<td>');  ngx.print(data and data["IPAddress"]); ngx.print('</td>\
				<td>');  ngx.print(data and data["type"]); ngx.print('</td>\
                <td>');  ngx.print( data and data.interface ); ngx.print('</td>\
				<td><span>');  if data and data["status"] == "1" then  ngx.print(T"Active"); else  ngx.print(T"Inactive"); end  ngx.print('</span></td>\
				<!--<td>');  ngx.print(data and data["expriesIn"]); ngx.print('</td> TODO-->\
			</tr>\
            ');  end  ngx.print('\
	</tbody></table>\
  </div>\
</div>\
<!--TODO\
<div class="h3-content content-lan-status">\
  <div class="row">\
    <div class="col-md-12">\
      <h3>');  ngx.print(T"Vodafone WiFi network devices"); ngx.print('</h3>\
    </div>\
  </div>\
  <div class="table-responsive">\
	 <table class="table lan-table" id = "lstatus-tbl-vdfwifi" >\
			<tbody><tr>\
				<th><span>');  ngx.print(T"Host Name"); ngx.print('</span></th>\
				<th><span>');  ngx.print(T"Status"); ngx.print('</span></th>\
				<th><span>');  ngx.print(T"Expires in"); ngx.print('</span></th>\
			</tr>\
            <tr>\
				<td>');  ngx.print(); ngx.print('</td>\
				<td><span>');  ngx.print(); ngx.print('</span></td>\
				<td>');  ngx.print(); ngx.print('</td>\
			</tr>\
	</tbody></table>\
  </div>\
</div>\
-->\
<h3>');  ngx.print(T"IPv6 LAN Connection Details"); ngx.print('</h3>\
<div class="h3-content content-lan-status">\
  <div class="table-responsive">\
	 <table class="table lan-table" id = "lstatus-tbl-ipv6landetails" >\
			<tbody><tr>\
				<th><span>');  ngx.print(T"Interface"); ngx.print('</span></th>\
				<th><span>');  ngx.print(T"IPv6 Global Addr"); ngx.print('</span></th>\
				<th><span>');  ngx.print(T"IPv6 Unique Local Addr"); ngx.print('</span></th>\
				<th><span>');  ngx.print(T"IPv6 Link Local Addr"); ngx.print('</span></th>\
				<th><span>');  ngx.print(T"IPv6 DHCP Addr Pool"); ngx.print('</span></th>\
				<th><span>');  ngx.print(T"IPv6 Default Gateway"); ngx.print('</span></th>\
				<th><span>');  ngx.print(T"IPv6 DNS Servers"); ngx.print('</span></th>\
			</tr>\
			<tr>\
				<td>');  ngx.print(IPv6Details and IPv6Details["IPv6Intf"]); ngx.print('</td>\
				<td>');  ngx.print(IPv6Details and IPv6Details["IPv6Global"]); ngx.print('</td>\
				<td>');  ngx.print(IPv6Details and IPv6Details["IPv6UniqueLocal"]); ngx.print('</td>\
				<td>');  ngx.print(IPv6Details and IPv6Details["IPv6LinkLocal"]); ngx.print('</td>\
				<td>');  ngx.print(IPv6Details and IPv6Details["IPv6DHCPAddrPool"]); ngx.print('</td>\
				<td>');  ngx.print(IPv6Details and IPv6Details["IPv6DefaultGW"]); ngx.print('</td>\
				<td>');  ngx.print(IPv6Details and IPv6Details["IPv6DNS"]); ngx.print('</td>\
			</tr>\
	</tbody></table>\
  </div>\
</div>\
<h3>');  ngx.print(T"LAN statistics"); ngx.print('</h3>\
<div class="h3-content content-lan-status">\
  <div class="table-responsive">\
    <table class="table lan-table" id = "lstatus-tbl-lanstats">\
      <tbody><tr>\
        <th><span>');  ngx.print(T"Interface"); ngx.print('</span></th>\
        <th><span>');  ngx.print(T"Recvd. Bytes"); ngx.print('</span></th>\
        <th><span>');  ngx.print(T"Pkts"); ngx.print('</span></th>\
        <th><span>');  ngx.print(T"Errs"); ngx.print('</span></th>\
        <th><span>');  ngx.print(T"Drops"); ngx.print('</span></th>\
        <th><span>');  ngx.print(T"Trans. Bytes"); ngx.print('</span></th>\
        <th><span>');  ngx.print(T"Pkts"); ngx.print('</span></th>\
        <th><span>');  ngx.print(T"Errs"); ngx.print('</span></th>\
        <th><span>');  ngx.print(T"Drops"); ngx.print('</span></th>\
        <th><span>');  ngx.print(T"Devices"); ngx.print('</span></th>\
      </tr>\
      ');  for _, stats in ipairs(lanStatsPatheth0) do  ngx.print('\
        <tr>\
          <td>');  ngx.print(T"eth0"); ngx.print('</td>\
          <td>');  ngx.print(stats["rx_bytes"]); ngx.print('</td>\
          <td>');  ngx.print(stats["rx_packets"]); ngx.print('</td>\
          <td>');  ngx.print(stats["rx_errors"]); ngx.print('</td>\
          <td>');  ngx.print(stats["rx_dropped"]); ngx.print('</td>\
          <td>');  ngx.print(stats["tx_bytes"]); ngx.print('</td>\
          <td>');  ngx.print(stats["tx_packets"]); ngx.print('</td>\
          <td>');  ngx.print(stats["tx_errors"]); ngx.print('</td>\
          <td>');  ngx.print(stats["tx_dropped"]); ngx.print('</td>\
          <td>');  ngx.print(deviceCount["eth0"] and deviceCount["eth0"] or "0" ); ngx.print('</td>\
        </tr>\
      ');  end  ngx.print('\
      ');  for _, stats in ipairs(lanStatsPatheth1) do  ngx.print('\
        <tr>\
          <td>');  ngx.print(T"eth1"); ngx.print('</td>\
          <td>');  ngx.print(stats["rx_bytes"]); ngx.print('</td>\
          <td>');  ngx.print(stats["rx_packets"]); ngx.print('</td>\
          <td>');  ngx.print(stats["rx_errors"]); ngx.print('</td>\
          <td>');  ngx.print(stats["rx_dropped"]); ngx.print('</td>\
          <td>');  ngx.print(stats["tx_bytes"]); ngx.print('</td>\
          <td>');  ngx.print(stats["tx_packets"]); ngx.print('</td>\
          <td>');  ngx.print(stats["tx_errors"]); ngx.print('</td>\
          <td>');  ngx.print(stats["tx_dropped"]); ngx.print('</td>\
          <td>');  ngx.print(deviceCount["eth1"] and deviceCount["eth1"] or "0"); ngx.print('</td>\
        </tr>\
      ');  end  ngx.print('\
      ');  for _, stats in ipairs(lanStatsPatheth2) do  ngx.print('\
        <tr>\
          <td>');  ngx.print(T"eth2"); ngx.print('</td>\
          <td>');  ngx.print(stats["rx_bytes"]); ngx.print('</td>\
          <td>');  ngx.print(stats["rx_packets"]); ngx.print('</td>\
          <td>');  ngx.print(stats["rx_errors"]); ngx.print('</td>\
          <td>');  ngx.print(stats["rx_dropped"]); ngx.print('</td>\
          <td>');  ngx.print(stats["tx_bytes"]); ngx.print('</td>\
          <td>');  ngx.print(stats["tx_packets"]); ngx.print('</td>\
          <td>');  ngx.print(stats["tx_errors"]); ngx.print('</td>\
          <td>');  ngx.print(stats["tx_dropped"]); ngx.print('</td>\
          <td>');  ngx.print(deviceCount["eth2"] and deviceCount["eth2"] or "0"); ngx.print('</td>\
        </tr>\
      ');  end  ngx.print('\
      ');  for _, stats in ipairs(lanStatsPathwl0) do  ngx.print('\
        <tr>\
          <td>');  ngx.print(T"wl0"); ngx.print('</td>\
          <td>');  ngx.print(wifiStats24 and stats["rx_bytes"] or "0" ); ngx.print('</td>\
          <td>');  ngx.print(wifiStats24 and stats["rx_packets"] or "0" ); ngx.print('</td>\
          <td>');  ngx.print(wifiStats24 and stats["rx_errors"] or "0" ); ngx.print('</td>\
          <td>');  ngx.print(wifiStats24 and stats["rx_dropped"] or "0" ); ngx.print('</td>\
          <td>');  ngx.print(wifiStats24 and stats["tx_bytes"] or "0" ); ngx.print('</td>\
          <td>');  ngx.print(wifiStats24 and stats["tx_packets"] or "0" ); ngx.print('</td>\
          <td>');  ngx.print(wifiStats24 and stats["tx_errors"] or "0" ); ngx.print('</td>\
          <td>');  ngx.print(wifiStats24 and stats["tx_dropped"] or "0" ); ngx.print('</td>\
          <td>');  ngx.print((getWifiStates["wifiState24"] == "1" and wifi_24Count) or "0" ); ngx.print('</td>\
        </tr>\
      ');  end  ngx.print('\
      ');  for _, stats in ipairs(lanStatsPathwl1) do  ngx.print('\
        <tr>\
          <td>');  ngx.print(T"wl1"); ngx.print('</td>\
          <td>');  ngx.print(wifiStats5 and stats["rx_bytes"] or "0" ); ngx.print('</td>\
          <td>');  ngx.print(wifiStats5 and stats["rx_packets"] or "0" ); ngx.print('</td>\
          <td>');  ngx.print(wifiStats5 and stats["rx_errors"] or "0" ); ngx.print('</td>\
          <td>');  ngx.print(wifiStats5 and stats["rx_dropped"] or "0" ); ngx.print('</td>\
          <td>');  ngx.print(wifiStats5 and stats["tx_bytes"] or "0" ); ngx.print('</td>\
          <td>');  ngx.print(wifiStats5 and stats["tx_packets"] or "0" ); ngx.print('</td>\
          <td>');  ngx.print(wifiStats5 and stats["tx_errors"] or "0" ); ngx.print('</td>\
          <td>');  ngx.print(wifiStats5 and stats["tx_dropped"] or "0" ); ngx.print('</td>\
          <td>');  ngx.print((getWifiStates["wifiState5"] == "1" and wifi_5Count) or "0" ); ngx.print('</td>\
        </tr>\
      ');  end  ngx.print('\
    </tbody></table>\
  </div>\
</div>\
<!-- TODO\
<div class="h3-content content-lan-status">\
  <div class="row">\
    <div class="col-md-12">\
      <h3>IPv6 LAN statistics</h3>\
    </div>\
  </div>\
  <div class="table-responsive">\
	 <table class="table lan-table">\
			<tbody><tr>\
				<th><span class="language-string" name="PAGE_LAN_STATUS_INTERFACE" title="alias: PAGE_LAN_STATUS_INTERFACE">Interface</span></th>\
				<th><span class="language-string" name="PAGE_LAN_STATUS_RECVD_BYTES" title="alias: PAGE_LAN_STATUS_RECVD_BYTES">Recvd. Bytes</span></th>\
				<th><span class="language-string" name="PAGE_LAN_STATUS_PKTS" title="alias: PAGE_LAN_STATUS_PKTS">Pkts</span></th>\
				<th><span class="language-string" name="PAGE_LAN_STATUS_ERRS" title="alias: PAGE_LAN_STATUS_ERRS">Errs</span></th>\
				<th><span class="language-string" name="PAGE_LAN_STATUS_DROPS" title="alias: PAGE_LAN_STATUS_DROPS">Drops</span></th>\
				<th><span class="language-string" name="PAGE_LAN_STATUS_TRANS_BYTES" title="alias: PAGE_LAN_STATUS_TRANS_BYTES">Trans. Bytes</span></th>\
				<th><span class="language-string" name="PAGE_LAN_STATUS_PKTS" title="alias: PAGE_LAN_STATUS_PKTS">Pkts</span></th>\
				<th><span class="language-string" name="PAGE_LAN_STATUS_ERRS" title="alias: PAGE_LAN_STATUS_ERRS">Errs</span></th>\
				<th><span class="language-string" name="PAGE_LAN_STATUS_DROPS" title="alias: PAGE_LAN_STATUS_DROPS">Drops</span></th>\
			</tr>\
			<tr>\
				<td>LAN1</td>\
				<td>0</td>\
				<td>25842</td>\
				<td>0</td>\
				<td>0</td>\
				<td>8521476</td>\
				<td>12356</td>\
				<td>0</td>\
				<td>0</td>\
				<td></td>\
			</tr>\
			<tr>\
				<td>LAN2</td>\
				<td>0</td>\
				<td>0</td>\
				<td>0</td>\
				<td>0</td>\
				<td>265871</td>\
				<td>12596</td>\
				<td>0</td>\
				<td>0</td>\
				<td></td>\
			</tr>\
			<tr>\
				<td>LAN3</td>\
				<td>0</td>\
				<td>35442</td>\
				<td>0</td>\
				<td>0</td>\
				<td>7654321</td>\
				<td>12854</td>\
				<td>0</td>\
				<td>0</td>\
				<td></td>\
			</tr>\
			<tr>\
				<td>LAN4</td>\
				<td>5874602</td>\
				<td>968541</td>\
				<td>0</td>\
				<td>0</td>\
				<td>1234567</td>\
				<td>12574</td>\
				<td>0</td>\
				<td>0</td>\
				<td></td>\
			</tr>\
			<tr>\
				<td>WLAN</td>\
				<td>0</td>\
				<td>25842</td>\
				<td>0</td>\
				<td>0</td>\
				<td>265871</td>\
				<td>12356</td>\
				<td>0</td>\
				<td>0</td>\
				<td></td>\
			</tr>\
			<tr>\
				<td>LAN5</td>\
				<td>254802</td>\
				<td>0</td>\
				<td>0</td>\
				<td>0</td>\
				<td>2587413</td>\
				<td>14598</td>\
				<td>0</td>\
				<td>0</td>\
				<td></td>\
			</tr>\
	</tbody></table>\
  </div>\
  -->\
<form id="lanStatus_form" class="form-horizontal" method="post" action="modals/lan-status.lp">\
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
    var target = "/modals/lan-status.lp";\
    var form = $("#lanStatus_form");\
    var params = form.serializeArray();\
    $("#content").load(target, params);\
});\
});\
</script>\
\
\
\
'); 