--pretranslated: do not change this file
 
--Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local string = string
local match,format = string.match,string.format
local bit = require("bit")
local floor = math.floor
local tonumber = tonumber
local vdf_helper = require("vodafone_helper")
local num2ipv4 = post_helper.num2ipv4
local secondsToUptime = vdf_helper.secondsToUptime
local systemTimeToDateandTime = vdf_helper.systemTimeToDateandTime
local session = ngx.ctx.session
local untaint_mt = require("web.taint").untaint_mt
local setMetaTable = setmetatable
local ui_helper = require("vdf_ui_helper")

local onOffState = setMetaTable({
  ["1"] = T"On",
  ["0"] = T"Off",
}, untaint_mt)

local state = setMetaTable({
  ["Connected"] = T"Connected",
  ["Disconnected"] = T"Disconnected",
}, untaint_mt)

local staticContent = {
  lan_mac_addr = "uci.env.rip.eth_mac",
  ip6_enable = "rpc.network.ipv6_enable",
  wifi_mac = "rpc.wireless.ssid.@wl0.mac_address",
  wifi5_mac = "rpc.wireless.ssid.@wl1.mac_address",
  sys_gw_serial = "uci.env.var.serial",
  sys_gw_version = "uci.version.version.@version[0].version",
  sys_bootloader_version = "uci.env.var.bootloader_version",
  sys_hw_version = "uci.env.var.prod_number",
  sys_mem_total = "sys.mem.RAMTotal",
  sys_reboot_cause = "rpc.system.RebootCause",
  sys_wireless_driver_version24GHz = "rpc.wireless.radio.@radio_2G.driver_version",
  sys_wireless_driver_version5GHz = "rpc.wireless.radio.@radio_5G.driver_version",
}

local rebootCause = {
  ["PWR"]   = T"Power",
  ["CLI"]   = T"Support",
  ["BOOTP"] = T"Support",
  ["CWMP"]  = T"Support",
  ["STS"]   = T"Support",
  ["TR64"]  = T"Support",
  ["GUI"]   = T"User Initiated",
  ["RTFD"]  = T"Factory Reset",
  ["UPGRADE"] = T"Upgrade",
  ["ROLLBACK"] = T"Upgrade",
  ["SWOVER"] = T"Upgrade",
  ["CRASH"]   = T"System Self",
  ["UERR"]   = T"System Self",
}

if not session:retrieve("sessionstatus") then
  content_helper.getExactContent(staticContent)
  session:store("sessionstatus", staticContent)
else
  staticContent = session:retrieve("sessionstatus")
end

local splitSSIDGet
if vdf_helper.getVariant() == "VF-UK" then
  splitSSIDGet = {
    splitSSID_2G = "uci.wireless.wifi-ap.@ap0.group_id",
    splitSSID_5G = "uci.wireless.wifi-ap.@ap1.group_id",
    splitSSID2_2G = "uci.wireless.wifi-ap.@ap2.group_id",
    splitSSID2_5G = "uci.wireless.wifi-ap.@ap3.group_id",
  }
  content_helper.getExactContent(splitSSIDGet)
end

local status_content = {
  -- Internet
  wwan_ip_address = "rpc.network.interface.@wwan.ipaddr",
  wan_ip_address = "rpc.network.interface.@wan.ipaddr",
  wan_wwan_status = "rpc.network.interface.@wwan.up",
  wan_dsl_status = "sys.class.xdsl.@line0.Status",
  wan_eth_status = "sys.class.net.@eth4.operstate",
  wwan_gw_ipv4 = "rpc.network.interface.@wwan.nexthop",
  wan_gw_ipv4 = "rpc.network.interface.@wan.nexthop",
  wwan_dns_servers = "rpc.network.interface.@wwan.dnsservers",
  wan_primary_dnsipv4 = "rpc.network.interface.@wan.dnsservers",
  wan_primary_dnsipv6 = "rpc.network.interface.@wan6.dnsservers",
  wan_prefix_ipv6 = "rpc.network.interface.@wan6.ip6prefix",
  wan_gwaddress_ipv6 = "rpc.network.interface.@wan6.nexthop",
  wan_ipaddress_ipv6 = "rpc.network.interface.@wan6.ip6addr",
  wan_firewall = "rpc.network.firewall.mode",
  wan_ipv6_linklocal = "rpc.network.interface.@wan6.ipv6linklocaladdr",

  -- LAN Network
  lan_ip_netmask = "uci.network.interface.@lan.netmask",
  lan_ip_ipmask = "rpc.network.interface.@lan.ipmask",
  lan_ip_ipaddr = "uci.network.interface.@lan.ipaddr",
  lan_ip_address = "rpc.network.interface.@lan.ipaddr",
  lan_subnet_addess = "rpc.network.interface.@lan.subnet_addr",
  lan_dhcp_ignore = "uci.dhcp.dhcp.@lan.ignore",
  lan_dhcpv4_server = "uci.dhcp.dhcp.@lan.dhcpv4",
  lan_dhcpv6_server = "uci.dhcp.dhcp.@lan.dhcpv6",
  lan_ra_server = "uci.dhcp.dhcp.@lan.ra",
  lan_ipv6_gw = "rpc.network.interface.@lan.ip6prefix_assignment",
  lan_port1_status = "sys.class.net.@eth0.operstate",
  lan_port1_speed = "sys.class.net.@eth0.speed",
  lan_port2_status = "sys.class.net.@eth1.operstate",
  lan_port2_speed = "sys.class.net.@eth1.speed",
  lan_port3_status = "sys.class.net.@eth2.operstate",
  lan_port3_speed = "sys.class.net.@eth2.speed",

  -- wifi_2.4
  wifi_status = "rpc.wireless.radio.@radio_2G.oper_state",
  wifi_ssid = "uci.wireless.wifi-iface.@wl0.ssid",
  wifi_security = "uci.wireless.wifi-ap.@ap0.security_mode",
  wifi_channel = "rpc.wireless.radio.@radio_2G.channel",
  wifi_bandwidth = "rpc.wireless.radio.@radio_2G.phy_rate",
  wifi_max_bandwidth = "rpc.services.x_vfwifi.Bandwidthpercentage",
  wifi_min_speed = "rpc.services.x_vfwifi.BandwidthMinimum",
  wifi_bandwidth_egress = "rpc.services.x_vfwifi.BandwidthEgress",

  -- wifi_5
  wifi5_status = "rpc.wireless.radio.@radio_5G.oper_state",
  wifi5_ssid = "uci.wireless.wifi-iface.@wl1.ssid",
  wifi5_security = "uci.wireless.wifi-ap.@ap1.security_mode",
  wifi5_channel = "rpc.wireless.radio.@radio_5G.channel",
  wifi5_bandwidth = "rpc.wireless.radio.@radio_5G.phy_rate",

  -- system
  sys_uptime = "rpc.system.uptime",
  sys_cpu_usage = "sys.proc.CPUUsage",
  sys_mem_usage = "sys.mem.RAMUsed",
  sys_time = "sys.time.CurrentLocalTime",
}

-- VF wifi status
if vdf_helper.getVariant() ~= "NZ" and vdf_helper.getVariant() ~= "VF-UK" then
  status_content.wifi_vf_status = "rpc.services.x_vfwifi.ServiceStatus"
  status_content.wifi_vf_nw_status = "rpc.network.interface.@gt0.up"
end

if vdf_helper.getVariant() == "VF-UK" then
  status_content.wan_ppp_session_uptime = "rpc.network.interface.@wan.ppp.uptime"
  status_content.lan_port4_status = "sys.class.net.@eth3.operstate"
  status_content.lan_port4_speed = "sys.class.net.@eth3.speed"
  status_content.wifi2_ip_ipaddr = "uci.network.interface.@guest.ipaddr"
  status_content.wifi2_ip_netmask = "uci.network.interface.@guest.netmask"
  status_content.wifi2_dhcp_ignore = "uci.dhcp.dhcp.@guest_private.ignore"
  status_content.wifi2_dhcpv4_server = "uci.dhcp.dhcp.@guest_private.dhcpv4"

  -- wifi2_2.4
  status_content.wifi2_ssid = "uci.wireless.wifi-iface.@wl0_1.ssid"
  status_content.wifi2_security = "uci.wireless.wifi-ap.@ap2.security_mode"
  status_content.wifi2_mac = "rpc.wireless.ssid.@wl0_1.mac_address"
  status_content.wifi2_24_status = "uci.wireless.wifi-ap.@ap2.state"
  status_content.wifi_max_bandwidth = "rpc.wireless.radio.@radio_2G.max_phy_rate"
  status_content.wifi_min_speed = "rpc.wireless.radio.@radio_2G.phy_rate"
  status_content.wifi_bandwidth_egress = nil
  -- wifi2_5
  status_content.wifi2_5_ssid = "uci.wireless.wifi-iface.@wl1_1.ssid"
  status_content.wifi2_5_security = "uci.wireless.wifi-ap.@ap3.security_mode"
  status_content.wifi2_5_mac = "rpc.wireless.ssid.@wl1_1.mac_address"
  status_content.wifi2_5_status = "uci.wireless.wifi-ap.@ap3.state"

  status_content.wifi_2G_admin_state = "rpc.wireless.radio.@radio_2G.admin_state"
  status_content.wifi_5G_admin_state = "rpc.wireless.radio.@radio_5G.admin_state"
  status_content.wifi_max_bandwidth = "rpc.wireless.radio.@radio_2G.max_phy_rate"
  status_content.wifi_min_speed = "rpc.wireless.radio.@radio_2G.phy_rate"
  status_content.wifi5_max_bandwidth = "rpc.wireless.radio.@radio_5G.max_phy_rate"
  status_content.wifi5_min_speed = "rpc.wireless.radio.@radio_5G.phy_rate"
end

if vdf_helper.getVariant() == "NZ" then
  status_content.wifi_max_bandwidth = nil
  status_content.wifi_min_speed = nil
  status_content.wifi_bandwidth_egress = nil
  status_content.wifi_vf_nw_status = nil
  status_content.wifi_vf_status = nil
end

content_helper.getExactContent(status_content)
if vdf_helper.getVariant() == "VF-UK" then
  if status_content.wifi_2G_admin_state == "0" then
     status_content.wifi_bandwidth = "0"
     status_content.wifi_max_bandwidth = "0"
     status_content.wifi_min_speed = "0"
  end
  if status_content.wifi_5G_admin_state == "0" then
     status_content.wifi5_bandwidth = "0"
     status_content.wifi5_max_bandwidth = "0"
     status_content.wifi5_min_speed = "0"
  end
end

-- Split dns servers
-- @function splitDnsServers
-- @param dnsList string, primary and secondary dns Server IP combined
-- @param separator string, used to seperate ips from the dnsList.
-- @return dnsServer table, primary and secondary DNS server
local function splitDnsServers(dnsList, separator)
  local dnsServer = {}
  if dnsList and separator ~= "" then
    for ip in dnsList:gmatch("[^"..separator.."]+") do
      dnsServer[#dnsServer+1] = ip
    end
  end
  return dnsServer or ""
end

local dns = splitDnsServers(status_content.wan_primary_dnsipv4, ", ")
local wwan_dns = splitDnsServers(status_content.wwan_dns_servers, ", ")

local lan_ip = post_helper.ipv42num(status_content["lan_ip_ipaddr"])
local lan_netmask = post_helper.ipv42num(status_content["lan_ip_netmask"])
local lan_network_address = bit.band(lan_ip,lan_netmask)
lan_network_address = num2ipv4(lan_network_address)

local wifi2_network_address
if vdf_helper.getVariant() == "VF-UK" then
  local wifi2_ip = post_helper.ipv42num(status_content["wifi2_ip_ipaddr"])
  local wifi2_netmask = post_helper.ipv42num(status_content["wifi2_ip_netmask"])
  wifi2_network_address = bit.band(wifi2_ip,wifi2_netmask)
  wifi2_network_address = num2ipv4(wifi2_network_address)
end

local wifi2_dhcp_ignore
if status_content["wifi2_dhcp_ignore"] == "1" or status_content["wifi2_dhcpv4_server"] == "disabled" then
  wifi2_dhcp_ignore = T"Off"
else
  wifi2_dhcp_ignore = T"On"
end

local lan_dhcp_ignore
if status_content["lan_dhcp_ignore"] == "1" or status_content["lan_dhcpv4_server"] == "disabled" then
  lan_dhcp_ignore = T"Off"
else
  lan_dhcp_ignore = T"On"
end
local uptime_sec = status_content["sys_uptime"]
local uptime_days, uptime_hours, uptime_minutes = secondsToUptime(tonumber(uptime_sec))
local sys_memory = (status_content["sys_mem_usage"]/staticContent["sys_mem_total"])*100
if sys_memory then
  sys_memory = match(sys_memory,"([%d]+)")
end
local sys_time = status_content["sys_time"]
local year, month, current_date, current_hour, current_minute, current_timezone = systemTimeToDateandTime(sys_time)

if vdf_helper.getVariant() ~= "NZ" and vdf_helper.getVariant() ~= "VF-UK" then
  if status_content["wifi_bandwidth_egress"] == "0" then
    status_content["wifi_max_bandwidth"] = (status_content["wifi_max_bandwidth"]/100) * status_content["wifi_bandwidth"]
    -- Max BandWidth value is converted to Mbps based on BandWidth Egress
  else
    status_content["wifi_max_bandwidth"] = status_content["wifi_bandwidth_egress"]
  end
end

-- WAN IP Address is populated from rpc.network.interface.@wwan.ipaddr parameter
-- When the DSL and ETH WAN Connections are not available and Mobile connection is up
if ((string.upper(status_content["wan_dsl_status"]) ~= "UP" and string.upper(status_content["wan_eth_status"]) ~= "UP") or
   (vdf_helper.getVariant() == "NZ" and status_content.wan_ip_address == "" and status_content.wan_ipaddress_ipv6 == "")) and status_content["wan_wwan_status"] == "1" then
  status_content.wan_ip_address = status_content.wwan_ip_address
  status_content.wan_gw_ipv4 = status_content.wwan_gw_ipv4
  --Primary and Secondary DNS namely 1 & 2
  dns[1] = wwan_dns[1]
  dns[2] = wwan_dns[2]
end

-- @function getEthSpeed
-- @param ethSpeed Speed of ethernet Port(In Mbps)
-- @return ethernet speed of format 100Mbps, 1Gbps etc
local function getEthSpeed(ethSpeed)
  ethSpeed = tonumber(ethSpeed)
  if ethSpeed then
    if ethSpeed >= 1000 then
      ethSpeed = format("%d Gbps", ethSpeed/1000)
    else
      ethSpeed = format("%d Mbps", ethSpeed)
    end
  end
  return ethSpeed or "0 Mbps"
end

-- @function getWifiData
-- @param Bandwidth or minimum sync speed(In Kbps)
-- @return bandwidth or minimum sync speed of format 100Mbps, 1Gbps etc
local function getWifiData(Bandwidth)
  Bandwidth = tonumber(Bandwidth)
  if Bandwidth then
    if Bandwidth > 1000000 then
      Bandwidth = format("%d Gbps", floor(Bandwidth/1000000))
    elseif Bandwidth > 1000 then
      Bandwidth = format("%d Mbps", floor(Bandwidth/1000))
    else
      Bandwidth = format("%d Kbps", Bandwidth)
    end
  end
  return Bandwidth or "0 Kbps"
end
  ngx.print('\
<script src="js/global-min.js"></script>\
<div class="row no-margin-right">\
  <div id="resetBar" class="resetBar resetContainer" style="display:none">\
    <div class="col-md-7 col-xs-12">\
      ');  ngx.print(T"Do you want to reset this page to default settings?"); ngx.print('\
    </div>\
    <div class="col-md-5 col-xs-12 text-right no-padding-right">\
      <input value="Reset" title="Reset" class="resetR button button-apply" id="resetR" type="button">\
      <input value="Cancel" title="Cancel" class="cancelR button button-cancel" id="cancelR" type="button">\
    </div>\
  </div>\
</div>\
  <h1>\
    ');  if vdf_helper.getVariant() == "VF-UK" then  ngx.print('\
      <span>');  ngx.print(T"Vodafone Broadband Router status"); ngx.print('\
    ');  else  ngx.print('\
      <span>');  ngx.print(T"Status"); ngx.print('\
    ');  end  ngx.print('\
    </span>\
  </h1>\
<h2>\
  <span>');  ngx.print(T"Find an overview of all your router parameters. This may help you in optimizing or trouble shooting your router."); ngx.print('\
  </span>\
</h2>\
<div class="status-container">\
  <h3><span>');  ngx.print(T"Internet"); ngx.print('</span></h3>\
  ');  
  local row = {
    {
      label   = T"IP Address",
      element = ui_helper.createOnlyText({id = "status-lbl-wanip"}, status_content.wan_ip_address),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 padding-left-1",
      rowClass = "row padding-top-bottom-20 no-margin-right"
    },
    {
      label   = T"Gateway",
      element = ui_helper.createOnlyText({id = "status-lbl-gwip"}, status_content.wan_gw_ipv4),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 padding-left-1",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    },
    {
      label = T"Primary DNS IP Address",
      element = ui_helper.createOnlyText({id = "status-lbl-pdnsip"}, dns[1] or ""),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 padding-left-1",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    },
    {
      label = T"Secondary DNS IP Address",
      element = ui_helper.createOnlyText({id = "status-lbl-sdnsip"}, dns[2] or ""),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 padding-left-1",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    },
   }
    row[#row + 1] = {
      label   = T"Firewall",
      element = ui_helper.createOnlyText({id = "status-lbl-wfirwal"}, status_content["wan_firewall"] ~= "lax" and T"On" or T"Off"),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 padding-left-1",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    }
    if tonumber(staticContent["ip6_enable"]) == 1 then
      row[#row + 1] = {
        label   = T"IPv6 Link Local Address",
        element = ui_helper.createOnlyText({id = "status-lbl-wv6lnloc"}, status_content["wan_ipv6_linklocal"]),
        colLeftClass = "col-xs-12 col-sm-5 col-md-5",
        colRightClass = "col-xs-12 col-md-7 col-sm-7 padding-left-1",
        rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
      }
      row[#row + 1] = {
        label   = T"IPv6 Gateway",
        element = ui_helper.createOnlyText({id = "status-lbl-wv6gwad"}, status_content["wan_gwaddress_ipv6"]),
        colLeftClass = "col-xs-12 col-sm-5 col-md-5",
        colRightClass = "col-xs-12 col-md-7 col-sm-7 padding-left-1",
        rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
      }
      row[#row + 1] = {
        label   = T"IPv6 prefix delegation",
        element = ui_helper.createOnlyText({id = "staus-lbl-wv6pre"}, status_content["wan_prefix_ipv6"]),
        colLeftClass = "col-xs-12 col-sm-5 col-md-5",
        colRightClass = "col-xs-12 col-md-7 col-sm-7 padding-left-1",
        rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
      }
      row[#row + 1] = {
        label   = T"Primary DNS IPv6 Address",
        element = ui_helper.createOnlyText({id = "status-lbl-wv6dns"}, status_content["wan_primary_dnsipv6"]),
        colLeftClass = "col-xs-12 col-sm-5 col-md-5",
        colRightClass = "col-xs-12 col-md-7 col-sm-7 padding-left-1",
        rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
      }
    end
    if vdf_helper.getVariant() == "VF-UK" then
      row[#row + 1] = {
        label   = T"PPP session uptime",
        element = ui_helper.createOnlyText({id = "status-lbl-pppuptime"}, status_content["wan_ppp_session_uptime"]),
        colLeftClass = "col-xs-12 col-sm-5 col-md-5",
        colRightClass = "col-xs-12 col-md-7 col-sm-7 padding-left-1",
        rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
      }
    end
  ngx.print(ui_helper.createTable(row, "", "h3-content h3-content-mobile font-bold"))
  ngx.print('\
\
  <h3><span>');  ngx.print( T"LAN Network"); ngx.print(' </span></h3>\
  <div class="h3-content h3-content-mobile font-bold">\
  ');  
    row = {
        label = T"IP Network",
        element = ui_helper.createOnlyText({id = "status-lbl-lipnw"}, lan_network_address.."/"..status_content["lan_ip_ipmask"]),
        colLeftClass = "col-xs-12 col-sm-5 col-md-5",
        colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left padding-left-1",
        rowClass = "row padding-top-bottom-20 no-margin-right"
      }
    ngx.print(ui_helper.createRow(row))
    row = {
      label = T"Default Gateway",
      element = ui_helper.createOnlyText({id = "status-lbl-lip"}, status_content["lan_ip_ipaddr"]),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left padding-left-1",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    }
    ngx.print(ui_helper.createRow(row))
    if tonumber(staticContent["ip6_enable"]) == 1 then
      row = {
        label = T"Subnet Address for Subnet 1",
        element = ui_helper.createOnlyText({id = "status-lbl-lanSubnetAddr"}, status_content["lan_subnet_addess"]),
        colLeftClass = "col-xs-12 col-sm-5 col-md-5",
        colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left padding-left-1",
        rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
      }
      ngx.print(ui_helper.createRow(row))
    end
    row = {
      label = T"MAC Address",
      element = ui_helper.createOnlyText({id = "status-lbl-lmac"}, staticContent["lan_mac_addr"]:upper()),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left padding-left-1",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    }
    ngx.print(ui_helper.createRow(row))
    row = {
      label = T"DHCP Server",
      element = ui_helper.createOnlyText({id = "status-lbl-ldhcpser"}, lan_dhcp_ignore),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left padding-left-1",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    }
    ngx.print(ui_helper.createRow(row))
    if vdf_helper.getVariant() ~= "VF-UK" then
      if tonumber(staticContent["ip6_enable"]) == 1 then
        row = {
          label = T"DHCPv6 Server",
          element = ui_helper.createOnlyText({id = "status-lbl-ldhcpv6ser"}, (status_content["lan_dhcpv6_server"] == "server" or status_content["lan_dhcpv6_server"] == "relay" or  status_content["lan_dhcpv6_server"] == "hybrid") and T"On" or T"Off"),
          colLeftClass = "col-xs-12 col-sm-5 col-md-5",
          colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left padding-left-1",
          rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
        }
        ngx.print(ui_helper.createRow(row))
      end
      row = {
        label = T"Router Advertisement",
        element = ui_helper.createOnlyText({id = "status-lbl-lra"}, (status_content["lan_ra_server"] == "server" or status_content["lan_ra_server"] =="relay" or  status_content["lan_ra_server"] == "hybrid") and T"On" or T"Off"),
        colLeftClass = "col-xs-12 col-sm-5 col-md-5",
        colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left padding-left-1",
        rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
      }
      ngx.print(ui_helper.createRow(row))
      if tonumber(staticContent["ip6_enable"]) == 1 then
        local lable_lan_ipv6_prefix = T"IPv6 Default Gateway"
        if vdf_helper.getVariant() == "NZ" then
          lable_lan_ipv6_prefix = T"IPv6 Prefix Assignment"
        end
        row = {
          label = lable_lan_ipv6_prefix,
          element = ui_helper.createOnlyText({id = "status-lbl-lv6gw"}, status_content["lan_ipv6_gw"]),
          colLeftClass = "col-xs-12 col-sm-5 col-md-5",
          colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left padding-left-1",
          rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
        }
        ngx.print(ui_helper.createRow(row))
      end
    end
    ngx.print('\
  <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
    <div class="col-xs-12 col-sm-5 col-md-5">\
      <span>');  ngx.print(T"LAN Port 1"); ngx.print('</span>\
    </div>\
    <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left no-padding-right">\
      <div class="col-xs-6 col-md-6 col-sm-6 dns-text-left no-padding-left-right">\
        <span class="status-service-indicator status-service-off" style="display:block" id ="status-span-por1st" > ');  if status_content["lan_port1_status"] == "up" then   ngx.print(T"Active"); ngx.print(' ');  else  ngx.print(' ');  ngx.print(T"Inactive"); ngx.print(' ');  end  ngx.print('</span>\
      </div>\
      <div class="col-xs-6 col-md-6 col-sm-6 text-right no-padding-right">\
        <span id="status-span-port1spd" >');  ngx.print(getEthSpeed(status_content["lan_port1_speed"])); ngx.print('</span>\
      </div>\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
    <div class="col-xs-12 col-sm-5 col-md-5">\
      <span>');  ngx.print(T"LAN Port 2"); ngx.print('</span>\
    </div>\
    <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left no-padding-right">\
      <div class="col-xs-6 col-md-6 col-sm-6 dns-text-left no-padding-left-right">\
        <span class="status-service-indicator status-service-off" style="display:block" id ="status-span-por2st">');  if status_content["lan_port2_status"] == "up" then   ngx.print(T"Active"); ngx.print(' ');  else  ngx.print(' ');  ngx.print(T"Inactive"); ngx.print(' ');  end  ngx.print('</span>\
      </div>\
      <div class="col-xs-6 col-md-6 col-sm-6 text-right no-padding-right">\
        <span id="status-span-port2spd">');  ngx.print(getEthSpeed(status_content["lan_port2_speed"])); ngx.print('</span>\
      </div>\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
    <div class="col-xs-12 col-sm-5 col-md-5">\
      <span>');  ngx.print(T"LAN Port 3"); ngx.print('</span>\
    </div>\
    <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left no-padding-right">\
      <div class="col-xs-6 col-md-6 col-sm-6 dns-text-left no-padding-left-right">\
        <span class="status-service-indicator status-service-off" style="display:block" id ="status-span-por3st">');  if status_content["lan_port3_status"] == "up" then   ngx.print(T"Active"); ngx.print(' ');  else  ngx.print(' ');  ngx.print(T"Inactive"); ngx.print(' ');  end  ngx.print('</span>\
      </div>\
      <div class="col-xs-6 col-md-6 col-sm-6 text-right no-padding-right">\
        <span id="status-span-port3spd">');  ngx.print(getEthSpeed(status_content["lan_port3_speed"])); ngx.print('</span>\
      </div>\
    </div>\
  </div>\
  ');  if vdf_helper.getVariant() == "VF-UK" then   ngx.print('\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
        <span>');  ngx.print(T"LAN Port 4"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left no-padding-right">\
        <div class="col-xs-6 col-md-6 col-sm-6 dns-text-left no-padding-left-right">\
          <span class="status-service-indicator status-service-off" style="display:block" id ="status-span-por4st">');  if status_content["lan_port4_status"] == "up" then   ngx.print(T"Active"); ngx.print(' ');  else  ngx.print(' ');  ngx.print(T"Inactive"); ngx.print(' ');  end  ngx.print('</span>\
        </div>\
        <div class="col-xs-6 col-md-6 col-sm-6 text-right no-padding-right">\
          <span id="status-span-port3spd">');  ngx.print(getEthSpeed(status_content["lan_port4_speed"])); ngx.print('</span>\
        </div>\
      </div>\
    </div>\
  ');  end  ngx.print('\
  </div>\
\
  ');  if vdf_helper.getVariant() == "NZ" then  ngx.print('\
    <h3><span>');  ngx.print(T"Wi-Fi (2.4GHz)"); ngx.print('</span></h3>\
  ');  elseif vdf_helper.getVariant() == "VF-UK" then  ngx.print('\
    <h3><span>');  ngx.print(T"Split Main Wi-Fi bands (SSID)"); ngx.print('</span></h3>\
    ');  
      local wifi_ssid_row = {
        {
          label = T"Main Wi-Fi SSID Status",
          element = ui_helper.createOnlyText({id = "wifi-ssid"}, (splitSSIDGet.splitSSID_2G == "off" and splitSSIDGet.splitSSID_5G == "off") and T"Enabled" or T"Disabled"),
          colLeftClass = "col-xs-12 col-sm-5 col-md-5",
          colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
          rowClass = "row padding-top-bottom-20 no-margin-right"
        }
        }
      ngx.print(ui_helper.createTable(wifi_ssid_row, "", "h3-content h3-content-mobile font-bold"))
      ngx.print('\
    <h3><span>');  ngx.print(T"Main Wi-Fi 2.4 GHz"); ngx.print('</span></h3>\
  ');  else  ngx.print('\
    <h3><span>');  ngx.print(T"Wi-Fi"); ngx.print('</span></h3>\
  ');  end  ngx.print('\
');  
  -- main wifi 2.4GHZ starts here
    local wifi_24GHZ_row = {
      {
        label   = T"Status",
        element = ui_helper.createOnlyText({id = "status-lbl-w24sta"}, status_content.wifi_status == "1" and T"On" or T"Off"),
        colLeftClass = "col-xs-12 col-sm-5 col-md-5",
        colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
        rowClass = "row padding-top-bottom-20 no-margin-right"
      }
      }
      wifi_24GHZ_row[#wifi_24GHZ_row+1] = {
        label   = T"SSID",
        element = ui_helper.createOnlyText({id = "status-lbl-w24ssid"}, status_content.wifi_ssid),
        colLeftClass = "col-xs-12 col-sm-5 col-md-5",
        colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
        rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
      }
      wifi_24GHZ_row[#wifi_24GHZ_row+1] = {
        label   = T"MAC Address",
        element = ui_helper.createOnlyText({id = "status-lbl-w24mac"}, staticContent.wifi_mac:upper()),
        colLeftClass = "col-xs-12 col-sm-5 col-md-5",
        colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
        rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
      }
      wifi_24GHZ_row[#wifi_24GHZ_row+1] = {
        label   = T"Security",
        element = ui_helper.createOnlyText({id = "status-lbl-w24sec"}, status_content.wifi_security and status_content.wifi_security:upper() or ""),
        colLeftClass = "col-xs-12 col-sm-5 col-md-5",
        colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
        rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
      }
      wifi_24GHZ_row[#wifi_24GHZ_row+1] = {
        label   = T"Channel",
        element = ui_helper.createOnlyText({id = "status-lbl-w24chan"}, status_content.wifi_channel),
        colLeftClass = "col-xs-12 col-sm-5 col-md-5",
        colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
        rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
      }
      wifi_24GHZ_row[#wifi_24GHZ_row+1] = {
        label   = T"Bandwidth",
        element = ui_helper.createOnlyText({id = "status-lbl-w24bndwd"}, getWifiData(status_content.wifi_bandwidth)),
        colLeftClass = "col-xs-12 col-sm-5 col-md-5",
        colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
        rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
      }

    if vdf_helper.getVariant() ~= "NZ" and vdf_helper.getVariant() ~= "VF-UK"then
      wifi_24GHZ_row[#wifi_24GHZ_row + 1] = {
        label   = T"VF WiFi network status",
        element = ui_helper.createOnlyText({id = "status-lbl-vfw24nwstatus"}, onOffState[status_content.wifi_vf_nw_status]),
        colLeftClass = "col-xs-12 col-sm-5 col-md-5",
        colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
        rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
      }
      wifi_24GHZ_row[#wifi_24GHZ_row + 1] = {
        label   = T"VF WiFi status",
        element = ui_helper.createOnlyText({id = "status-lbl-vfw24status", style = "display:block", class = (state[status_content.wifi_vf_status] == "Connected") and "status-service-indicator status-service-on" or "status-service-indicator status-service-off"}, state[status_content.wifi_vf_status]),
        colLeftClass = "col-xs-12 col-sm-5 col-md-5",
        colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
        rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
      }
    end
     if vdf_helper.getVariant() == "VF-UK" then
      wifi_24GHZ_row[#wifi_24GHZ_row + 1] = {
        label   = T"Max BW",
        element = ui_helper.createOnlyText({id = "status-lbl-w24mxbndwd"}, getWifiData(status_content["wifi_max_bandwidth"])),
        colLeftClass = "col-xs-12 col-sm-5 col-md-5",
        colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
        rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
      }
      wifi_24GHZ_row[#wifi_24GHZ_row + 1] = {
        label   = T"Minimum Sync Speed",
        element = ui_helper.createOnlyText({id = "status-lbl-w24minspd"}, getWifiData(status_content["wifi_min_speed"])),
        colLeftClass = "col-xs-12 col-sm-5 col-md-5",
        colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
        rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
      }
    end
    ngx.print(ui_helper.createTable(wifi_24GHZ_row, "", "h3-content h3-content-mobile font-bold"))
    -- main wifi 2.4GHZ ends here
  ngx.print('\
  ');  if vdf_helper.getVariant() == "VF-UK" then  ngx.print('\
       <h3><span>');  ngx.print(T"Main Wi-Fi 5 GHz"); ngx.print('</span></h3>\
  ');  else  ngx.print('\
    <h3><span>');  ngx.print(T"Wi-Fi (5GHz)"); ngx.print('</span></h3>\
  ');  end  ngx.print('\
');  
  -- main wifi 5GHZ starts here
  local wifi_5GHZ_row = {
    {
      label   = T"Status",
      element = ui_helper.createOnlyText({id = "status-lbl-w5sta"}, status_content.wifi5_status == "1" and T"On" or T"Off"),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right"
    }
  }
  wifi_5GHZ_row[#wifi_5GHZ_row+1] = {
    label   = vdf_helper.getVariant() == "VF-UK" and T"Name" or T"SSID",
    element = ui_helper.createOnlyText({id = "status-lbl-w5ssid"}, status_content.wifi5_ssid),
    colLeftClass = "col-xs-12 col-sm-5 col-md-5",
    colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
    rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
  }
  wifi_5GHZ_row[#wifi_5GHZ_row+1] = {
    label   = T"MAC Address",
    element = ui_helper.createOnlyText({id = "status-lbl-w5mac"}, staticContent.wifi5_mac:upper()),
    colLeftClass = "col-xs-12 col-sm-5 col-md-5",
    colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
    rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
  }
  wifi_5GHZ_row[#wifi_5GHZ_row+1] = {
    label   = T"Security",
    element = ui_helper.createOnlyText({id = "status-lbl-w5sec"}, status_content.wifi5_security and status_content.wifi5_security:upper() or ""),
    colLeftClass = "col-xs-12 col-sm-5 col-md-5",
    colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
    rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
  }
  if vdf_helper.getVariant() == "NZ" or vdf_helper.getVariant() == "VF-UK" then
    wifi_5GHZ_row[#wifi_5GHZ_row + 1] = {
      label   = T"Channel",
      element = ui_helper.createOnlyText({id = "status-lbl-w5chan"}, status_content.wifi5_channel),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    }
    wifi_5GHZ_row[#wifi_5GHZ_row + 1] = {
      label   = T"Bandwidth",
      element = ui_helper.createOnlyText({id = "status-lbl-w5bndwd"}, getWifiData(status_content.wifi5_bandwidth)),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    }
  end
  if vdf_helper.getVariant() == "VF-UK" then
    wifi_5GHZ_row[#wifi_5GHZ_row + 1] = {
      label   = T"Max BW",
      element = ui_helper.createOnlyText({id = "status-lbl-w5mxbndwd"}, getWifiData(status_content["wifi5_max_bandwidth"])),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    }
    wifi_5GHZ_row[#wifi_5GHZ_row + 1] = {
      label   = T"Minimum Sync Speed",
      element = ui_helper.createOnlyText({id = "status-lbl-w5minspd"}, getWifiData(status_content["wifi5_min_speed"])),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    }
  end
  if vdf_helper.getVariant() == "VF-UK" then
      ngx.print(ui_helper.createTable(wifi_5GHZ_row, "", "h3-content h3-content-mobile font-bold"))
  else
    ngx.print(ui_helper.createTable(wifi_5GHZ_row, "", "h3-content h3-content-mobile font-bold"))
  end
  -- main wifi 5GHZ ends here
  ngx.print('\
  ');  if vdf_helper.getVariant() == "VF-UK" then  ngx.print('\
    <h3><span>');  ngx.print(T"Split Wi-Fi 2 bands (SSID)"); ngx.print('</span></h3>\
    ');  
      local wifi2_ssid_row = {
        {
          label = T"Main Wi-Fi 2 SSID Status",
          element = ui_helper.createOnlyText({id = "wifi2-ssid"}, (splitSSIDGet.splitSSID2_2G == "off" and splitSSIDGet.splitSSID2_5G == "off") and T"Enabled" or T"Disabled"),
          colLeftClass = "col-xs-12 col-sm-5 col-md-5",
          colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
          rowClass = "row padding-top-bottom-20 no-margin-right"
        }
        }
      ngx.print(ui_helper.createTable(wifi2_ssid_row, "", "h3-content h3-content-mobile font-bold"))
      ngx.print('\
    <h3><span>');  ngx.print(T"Wi-Fi 2 2.4 GHz"); ngx.print('</span></h3>\
  ');  
  -- wifi2 2.4GHZ starts here
  local wifi2_24GHZ_row = {
    {
      label   = T"Status",
      element = ui_helper.createOnlyText({id = "status-lbl-w2-24sta"}, status_content.wifi2_24_status == "1" and T"On" or T"Off"),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right"
    },
    {
      label   = T"Name",
      element = ui_helper.createOnlyText({id = "status-lbl-w2-24ssid"}, status_content.wifi2_ssid),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    },
    {
      label   = T"MAC Address",
      element = ui_helper.createOnlyText({id = "status-lbl-w2-24mac"}, status_content.wifi2_mac:upper()),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    },
    {
      label   = T"Security",
      element = ui_helper.createOnlyText({id = "status-lbl-w2-24sec"}, status_content.wifi2_security and status_content.wifi2_security:upper() or ""),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    },
    {
      label   = T"IP Network WiFi",
      element = ui_helper.createOnlyText({id = "status-lbl-w2-24lipnw"}, wifi2_network_address.."/"..status_content.lan_ip_ipmask),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    },
    {
      label   = T"DHCP Server",
      element = ui_helper.createOnlyText({id = "status-lbl-w2-24ldhcpser"}, wifi2_dhcp_ignore),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    },
    {
      label   = T"Channel",
      element = ui_helper.createOnlyText({id = "status-lbl-w2-24chan"}, status_content.wifi_channel),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    },
    {
      label   = T"Bandwidth",
      element = ui_helper.createOnlyText({id = "status-lbl-w2-24bndwd"}, getWifiData(status_content.wifi_bandwidth)),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    },
  }
  ngx.print(ui_helper.createTable(wifi2_24GHZ_row, "", "h3-content h3-content-mobile font-bold"))
  -- Wifi2 2.4GHZ for VF-UK ends here
  end  ngx.print('\
\
  ');  if vdf_helper.getVariant() == "VF-UK" then  ngx.print('\
    <h3><span>');  ngx.print(T"Wi-Fi 2 5 GHz"); ngx.print('</span></h3>\
  ');  
  --wifi2 5GHz starts here
  local wifi2_5_row = {
    {
      label   = T"Status",
      element = ui_helper.createOnlyText({id = "status-lbl-w2-5sta"}, status_content.wifi2_5_status == "1" and T"On" or T"Off"),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right"
    },
    {
      label   = T"Name",
      element = ui_helper.createOnlyText({id = "status-lbl-w2-5ssid"}, status_content.wifi2_5_ssid),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    },
    {
      label   = T"MAC Address",
      element = ui_helper.createOnlyText({id = "status-lbl-w2-5mac"}, status_content.wifi2_5_mac:upper()),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    },
    {
      label   = T"Security",
      element = ui_helper.createOnlyText({id = "status-lbl-w2-5sec"}, status_content.wifi2_5_security and status_content.wifi2_5_security:upper() or ""),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    },
     {
      label   = T"IP Network WiFi",
      element = ui_helper.createOnlyText({id = "status-lbl-w2-5lipnw"}, wifi2_network_address.."/"..status_content.lan_ip_ipmask),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    },
    {
      label   = T"DHCP Server",
      element = ui_helper.createOnlyText({id = "status-lbl-w2-5ldhcpser"}, wifi2_dhcp_ignore),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    },
    {
      label   = T"Channel",
      element = ui_helper.createOnlyText({id = "status-lbl-w2-5chan"}, status_content.wifi5_channel),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    },
    {
      label   = T"Bandwidth",
      element = ui_helper.createOnlyText({id = "status-lbl-w2-5bndwd"}, getWifiData(status_content.wifi5_bandwidth)),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    },
  }
  ngx.print(ui_helper.createTable(wifi2_5_row, "", "h3-content h3-content-mobile font-bold"))
  --wifi2 5GHz for VF-UK ends here
  end  ngx.print('\
\
  <h3><span>');  ngx.print(T"System"); ngx.print('</span></h3>\
  ');  
  local system_row = {
    {
      label   = T"Serial Number",
      element = ui_helper.createOnlyText({id = "status-lbl-gwser"}, staticContent["sys_gw_serial"]),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right"
    },
    {
      label   = T"Firmware version",
      element = ui_helper.createOnlyText({id = "status-lbl-gwver"}, staticContent["sys_gw_version"]),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    },
    {
      label   = T"Bootloader Version",
      element = ui_helper.createOnlyText({id = "status-lbl-btldver"}, staticContent["sys_bootloader_version"]),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    }
  }
  system_row[#system_row + 1] = {
    label   = T"Hardware Type &amp; Version",
    element = ui_helper.createOnlyText({id = "status-lbl-hwver"}, staticContent["sys_hw_version"]),
    colLeftClass = "col-xs-12 col-sm-5 col-md-5",
    colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
    rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
  }
  system_row[#system_row + 1] = {
    label   = T"Uptime since last reboot",
    element = ui_helper.createOnlyText({id = "status-lbl-uptme"}, format("%s %s, %s %s %s %s %s",uptime_days,T"days",uptime_hours,T"hours",T"and",uptime_minutes,T"minutes")),
    colLeftClass = "col-xs-12 col-sm-5 col-md-5",
    colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
    rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
  }
  if ngx.ctx.session:getrole() ~= "user" or vdf_helper.getVariant() == "VF-UK" then
    system_row[#system_row + 1] = {
      label   = T"CPU Usage",
      element = ui_helper.createOnlyText({id = "statu-lbl-cpuusag"}, status_content["sys_cpu_usage"].." %"),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    }
    system_row[#system_row + 1] = {
      label   = T"Memory Usage",
      element = ui_helper.createOnlyText({id = "status-lbl-memusg"}, sys_memory.." %"),
      colLeftClass = "col-xs-12 col-sm-5 col-md-5",
      colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
      rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
    }
  end
  local rebootCauseStr = string.untaint(staticContent["sys_reboot_cause"])
  if vdf_helper.getVariant() == "VF-UK" or vdf_helper.getVariant() == "NZ" then
     rebootCauseStr = rebootCause[string.untaint(staticContent["sys_reboot_cause"])]
  end
  system_row[#system_row + 1] = {
    label   = T"Reboot Cause",
    element = ui_helper.createOnlyText({id = "status-lbl-rebootcause"}, rebootCauseStr),
    colLeftClass = "col-xs-12 col-sm-5 col-md-5",
    colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
    rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
  }
  system_row[#system_row + 1] = {
    label   = T"Wireless Driver Version",
    element = ui_helper.createOnlyText({id = "status-lbl-wlDrvrVrsn24GHz"}, staticContent["sys_wireless_driver_version24GHz"]),
    colLeftClass = "col-xs-12 col-sm-5 col-md-5",
    colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
    rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
  }
  system_row[#system_row + 1] = {
    label   = T"Wireless Driver Version 5 GHz",
    element = ui_helper.createOnlyText({id = "status-lbl-wlDrvrVrsn5GHz"}, staticContent["sys_wireless_driver_version5GHz"]),
    colLeftClass = "col-xs-12 col-sm-5 col-md-5",
    colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
    rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
  }
  system_row[#system_row + 1] = {
    label   = T"Date &amp; Time",
    element = ui_helper.createOnlyText({id = "status-lbl-datetime"}, format("%s.%s.%s | %s:%s %s", current_date, month, year, current_hour, current_minute, current_timezone)),
    colLeftClass = "col-xs-12 col-sm-5 col-md-5",
    colRightClass = "col-xs-12 col-md-7 col-sm-7 dns-text-left",
    rowClass = "row padding-top-bottom-20 no-margin-right status-border-top"
  }
  ngx.print(ui_helper.createTable(system_row, "", "h3-content h3-content-mobile font-bold"))
    ngx.print('\
</div>\
<script>\
$(function(){\
  var port1status = "');  ngx.print(status_content["lan_port1_status"]); ngx.print('";\
  var port2status = "');  ngx.print(status_content["lan_port2_status"]); ngx.print('";\
  var port3status = "');  ngx.print(status_content["lan_port3_status"]); ngx.print('";\
  var port4status = "');  ngx.print(status_content["lan_port4_status"]); ngx.print('";\
  if (port1status == "up"){\
    $("#status-span-por1st").removeClass("status-service-off").addClass("status-service-on");\
  }\
  else {\
    $("#status-span-por1st").removeClass("status-service-on").addClass("status-service-off");\
  }\
  if (port2status == "up"){\
    $("#status-span-por2st").removeClass("status-service-off").addClass("status-service-on");\
  }\
  else {\
    $("#status-span-por2st").removeClass("status-service-on").addClass("status-service-off");\
  }\
  if (port3status == "up"){\
    $("#status-span-por3st").removeClass("status-service-off").addClass("status-service-on");\
  }\
  else {\
    $("#status-span-por3st").removeClass("status-service-on").addClass("status-service-off");\
  }\
  if (port4status == "up"){\
    $("#status-span-por4st").removeClass("status-service-off").addClass("status-service-on");\
  }\
  else {\
    $("#status-span-por4st").removeClass("status-service-on").addClass("status-service-off");\
  }\
});\
</script>\
\
'); 