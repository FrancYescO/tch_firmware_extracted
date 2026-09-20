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
local numToIPv4 = vdf_helper.numToIPv4
local secondsToUptime = vdf_helper.secondsToUptime
local systemTimeToDateandTime = vdf_helper.systemTimeToDateandTime
local session = ngx.ctx.session
local untaint_mt = require("web.taint").untaint_mt
local setMetaTable = setmetatable

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
  wifi_mac = "rpc.wireless.ssid.@wl0.mac_address",
  wifi5_mac = "rpc.wireless.ssid.@wl1.mac_address",
  sys_gw_serial = "uci.env.var.serial",
  sys_gw_version = "uci.version.version.@version[0].version",
  sys_bootloader_version = "uci.env.var.bootloader_version",
  sys_hw_version = "uci.env.var.hardware_version",
  sys_mem_total = "sys.mem.RAMTotal",
  sys_reboot_cause = "InternetGatewayDevice.DeviceInfo.X_000E50_RebootCause",
  sys_wireless_driver_version24GHz = "rpc.wireless.radio.@radio_2G.driver_version",
  sys_wireless_driver_version5GHz = "rpc.wireless.radio.@radio_5G.driver_version",
}
if not session:retrieve("sessionstatus") then
  content_helper.getExactContent(staticContent)
  session:store("sessionstatus", staticContent)
else
  staticContent = session:retrieve("sessionstatus")
end

local status_content = {
  -- Internet
  wan_ip_address = "rpc.network.interface.@wan.ipaddr",
  wan_wwan_status = "rpc.network.interface.@wwan.up",
  wan_dsl_status = "sys.class.xdsl.@line0.Status",
  wan_eth_status = "sys.class.net.@eth4.operstate",
  wwan_ip_address = "rpc.network.interface.@wwan.ipaddr",
  wan_gw_ipv4 = "rpc.network.interface.@wan.nexthop",
  wan_primary_dnsipv4 = "rpc.network.interface.@wan.dnsservers",
  wan_primary_dnsipv6 = "rpc.network.interface.@wan6.dnsservers",
  wan_prefix_ipv6 = "rpc.network.interface.@wan6.ip6prefix",
  wan_gwaddress_ipv6 = "rpc.network.interface.@wan6.nexthop",
  wan_ipaddress_ipv6 = "rpc.network.interface.@wan6.ip6addr",
  wan_firewall = "rpc.network.firewall.mode",
  wan_ipv6_linklocal = "rpc.network.interface.@wan.ipv6linklocaladdr",

  -- LAN Network
  lan_ip_netmask = "uci.network.interface.@lan.netmask",
  lan_ip_ipmask = "rpc.network.interface.@lan.ipmask",
  lan_ip_ipaddr = "uci.network.interface.@lan.ipaddr",
  lan_ip_address = "rpc.network.interface.@lan.ipaddr",
  lan_subnet_addess = "rpc.network.interface.@lan.ip6prefix",
  lan_dhcp_server = "uci.dhcp.dhcp.@lan.ignore",
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
  wifi_channel = "rpc.wireless.radio.@radio_2G.requested_channel",
  wifi_bandwidth = "rpc.wireless.radio.@radio_2G.max_phy_rate",
  wifi_LowChannel = "rpc.wireless.radio.@radio_2G.channel",

  -- wifi_5
  wifi5_status = "rpc.wireless.radio.@radio_5G.oper_state",
  wifi5_ssid = "uci.wireless.wifi-iface.@wl1.ssid",
  wifi5_security = "uci.wireless.wifi-ap.@ap1.security_mode",
  wifi5_channel = "rpc.wireless.radio.@radio_5G.requested_channel",
  wifi5_bandwidth = "rpc.wireless.radio.@radio_5G.max_phy_rate",
  wifi_HighChannel = "rpc.wireless.radio.@radio_5G.channel",

  -- system
  sys_uptime = "rpc.system.uptime",
  sys_cpu_usage = "sys.proc.CPUUsage",
  sys_mem_usage = "sys.mem.RAMUsed",
  sys_time = "sys.time.CurrentLocalTime",

}
content_helper.getExactContent(status_content)

local lan_ip = post_helper.ipv42num(status_content["lan_ip_ipaddr"])
local lan_netmask = post_helper.ipv42num(status_content["lan_ip_netmask"])
local lan_network_address = bit.band(lan_ip,lan_netmask)
lan_network_address = numToIPv4(lan_network_address)

local wan_primary_dns, wan_secondary_dns = match(status_content["wan_primary_dnsipv4"], "([%w.]+)[%,%s]+([%w.]+)")
local lan_dhcp_server
if status_content["lan_dhcp_server"] == "" or status_content["lan_dhcp_server"] == "0" then
  lan_dhcp_server = T"On"
else
  lan_dhcp_server = T"Off"
end
local uptime_sec = status_content["sys_uptime"]
local uptime_days, uptime_hours, uptime_minutes = secondsToUptime(tonumber(uptime_sec))
local sys_memory = (status_content["sys_mem_usage"]/staticContent["sys_mem_total"])*100
if sys_memory then
  sys_memory = match(sys_memory,"([%d]+)")
end
local sys_time = status_content["sys_time"]
local year, month, current_date, current_hour, current_minute, current_timezone = systemTimeToDateandTime(sys_time)

-- WAN IP Address is populated from rpc.network.interface.@wwan.ipaddr parameter
-- When the DSL and ETH WAN Connections are not available and Mobile connection is up
if string.upper(status_content["wan_dsl_status"]) ~= "UP" and string.upper(status_content["wan_eth_status"]) ~= "UP" and status_content["wan_wwan_status"] == "1" then
  status_content["wan_ip_address"] = status_content["wwan_ip_address"]
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
<script src="js/global.js"></script>\
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
    <span>');  ngx.print(T"Status"); ngx.print('\
    </span>\
  </h1>\
<h2>\
  <span>');  ngx.print(T"Find an overview of all your router parameters. This may help you in optimizing or trouble shooting your router."); ngx.print('\
  </span>\
</h2>\
<div class="status-container">\
  <h3><span>');  ngx.print(T"Internet"); ngx.print('</span></h3>\
  <div class="h3-content h3-content-mobile">\
    <div class="row padding-top-bottom-20 no-margin-right">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
        <span>');  ngx.print(T"IP Address"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 padding-left-1">\
        <span id ="status-lbl-wanip" >');  ngx.print(status_content["lan_ip_address"]); ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
        <span>');  ngx.print(T"Gateway"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 padding-left-1">\
        <span id= "status-lbl-gwip" >');  ngx.print(status_content["lan_ip_address"]); ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
        <span  >');  ngx.print(T"Primary DNS IP Address"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 padding-left-1">\
        <span id ="status-lbl-pdnsip">');  if status_content["lan_ip_address"] then   ngx.print(status_content["lan_ip_address"]); end  ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
        <span>');  ngx.print( T"Secondary DNS IP Address"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 padding-left-1">\
        <span id ="status-lbl-sdnsip">');  if status_content["lan_ip_address"] then  ngx.print(status_content["lan_ip_address"]); end  ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
        <span>');  ngx.print(T"Firewall"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 padding-left-1">\
        <span id="status-lbl-wfirwal">');  if status_content["wan_firewall"] ~= "lax" then  ngx.print(T"On"); else  ngx.print(T"Off"); end  ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5 status-padding-right-lg mobile-status-padding-right-none">\
        <span>');  ngx.print(T"WAN IP Address"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 padding-left-1">\
        <span id="status-lbl-wipv6" >');  ngx.print(status_content["wan_ip_address"]); ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
       <span>');  ngx.print(T"IPv6 Link Local Address"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 padding-left-1">\
        <span id = "status-lbl-wv6lnloc">');  ngx.print(status_content["wan_ipv6_linklocal"]); ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
       <span>');  ngx.print(T"IPv6 Gateway"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 padding-left-1">\
        <span id ="status-lbl-wv6gwad">');  ngx.print( status_content["wan_gwaddress_ipv6"]); ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
       <span>');  ngx.print(T"IPv6 prefix delegation"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 padding-left-1">\
        <span id ="staus-lbl-wv6pre" >');  ngx.print(status_content["wan_prefix_ipv6"]); ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
       <span>');  ngx.print(T"Primary DNS IPv6 Address"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 padding-left-1">\
       <span id="status-lbl-wv6dns">');  ngx.print(status_content["wan_primary_dnsipv6"]); ngx.print('</span>\
      </div>\
    </div>\
  </div>\
\
  <h3><span>');  ngx.print( T"LAN Network"); ngx.print(' </span></h3>\
  <div class="h3-content h3-content-mobile">\
    <div class="row padding-top-bottom-20 no-margin-right">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
        <span>');  ngx.print(T"IP Network"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left padding-left-1">\
        <span id ="status-lbl-lipnw">');  ngx.print(lan_network_address.."/"..status_content["lan_ip_ipmask"]); ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
        <span>');  ngx.print(T"Default Gateway"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left padding-left-1">\
        <span id ="status-lbl-lip" >');  ngx.print(status_content["lan_ip_ipaddr"]); ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
        <span>');  ngx.print(T"Subnet Address for Subnet 1"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
        <span id ="status-lbl-lanSubnetAddr" >');  ngx.print(status_content["lan_subnet_addess"]); ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
        <span>');  ngx.print(T"MAC Address"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left padding-left-1">\
        <span id="status-lbl-lmac">');  ngx.print(staticContent["lan_mac_addr"]:upper()); ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
        <span>');  ngx.print(T"DHCP Server"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left padding-left-1">\
        <span id="status-lbl-ldhcpser">');  ngx.print(lan_dhcp_server); ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
        <span>');  ngx.print(T"DHCPv6 Server"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left padding-left-1">\
        <span id="status-lbl-ldhcpv6ser" >');  if (status_content["lan_dhcpv6_server"] == "server" or status_content["lan_dhcpv6_server"] == "relay" or  status_content["lan_dhcpv6_server"] == "hybrid") then  ngx.print(T"On"); else   ngx.print(T"Off"); end  ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
        <span>');  ngx.print(T"Router Advertisement"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left padding-left-1">\
        <span id="status-lbl-lra" >');  if (status_content["lan_ra_server"] == "server" or status_content["lan_ra_server"] =="relay" or  status_content["lan_ra_server"] == "hybrid") then  ngx.print(T"On"); else   ngx.print(T"Off"); end  ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
       <span>');  ngx.print(T"IPv6 Default Gateway"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left padding-left-1">\
        <span id ="status-lbl-lv6gw">');  ngx.print(status_content["lan_ipv6_gw"]); ngx.print('</span>\
      </div>\
    </div>\
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
  </div>\
\
  <h3><span>');  ngx.print(T"Wi-Fi (2.4GHz)"); ngx.print('</span></h3>\
    <div class="h3-content h3-content-mobile">\
      <div class="row padding-top-bottom-20 no-margin-right">\
        <div class="col-xs-12 col-sm-5 col-md-5">\
          <span>');  ngx.print(T"Status"); ngx.print('</span>\
        </div>\
        <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
          <span id ="status-lbl-w24sta">');  if status_content["wifi_status"] == "1" then  ngx.print(T"On"); else  ngx.print(T"Off"); end  ngx.print('</span>\
        </div>\
      </div>\
      <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
        <div class="col-xs-12 col-sm-5 col-md-5">\
          <span>');  ngx.print(T"SSID"); ngx.print('</span>\
        </div>\
        <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
          <span id ="status-lbl-w24ssid">');  ngx.print(status_content["wifi_ssid"]); ngx.print('</span>\
        </div>\
      </div>\
      <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
        <div class="col-xs-12 col-sm-5 col-md-5">\
          <span>');  ngx.print(T"MAC Address"); ngx.print('</span>\
        </div>\
        <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
          <span id ="status-lbl-w24mac">');  ngx.print(staticContent["wifi_mac"]:upper()); ngx.print('</span>\
        </div>\
      </div>\
      <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
        <div class="col-xs-12 col-sm-5 col-md-5">\
          <span>');  ngx.print(T"Security"); ngx.print('</span>\
        </div>\
        <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
          <span id ="status-lbl-w24sec" >');  if status_content["wifi_security"] then   ngx.print(status_content["wifi_security"]:upper()); ngx.print(' ');  end  ngx.print('</span>\
        </div>\
      </div>\
      <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
        <div class="col-xs-12 col-sm-5 col-md-5">\
          <span>');  ngx.print(T"Channel"); ngx.print('</span>\
        </div>\
        <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
          <span id ="status-lbl-w24chan">');  ngx.print(status_content["wifi_channel"]); ngx.print('</span>\
        </div>\
      </div>\
      <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
        <div class="col-xs-12 col-sm-5 col-md-5">\
          <span>');  ngx.print(T"Current Channel"); ngx.print('</span>\
        </div>\
        <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
\
          <span id="status-lbl-w24cntchan">');  ngx.print(status_content["wifi_LowChannel"]); ngx.print('</span>\
        </div>\
      </div>\
      <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
        <div class="col-xs-12 col-sm-5 col-md-5">\
          <span>');  ngx.print(T"Bandwidth"); ngx.print('</span>\
        </div>\
        <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
          <span id="status-lbl-w24bndwd">');  ngx.print(getWifiData(status_content["wifi_bandwidth"])); ngx.print('</span>\
        </div>\
      </div>\
  </div>\
\
  <h3><span>');  ngx.print(T"Wi-Fi (5GHz)"); ngx.print('</span></h3>\
    <div class="h3-content h3-content-mobile">\
      <div class="row padding-top-bottom-20 no-margin-right">\
        <div class="col-xs-12 col-sm-5 col-md-5">\
          <span>');  ngx.print(T"Status"); ngx.print('</span>\
        </div>\
        <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
          <span id="status-lbl-w5sta">');  if status_content["wifi5_status"] == "1" then  ngx.print(T"On"); else  ngx.print(T"Off"); end  ngx.print('</span>\
        </div>\
      </div>\
      <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
        <div class="col-xs-12 col-sm-5 col-md-5">\
          <span>');  ngx.print(T"SSID"); ngx.print('</span>\
        </div>\
        <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
          <span id ="status-lbl-w5ssid">');  ngx.print(status_content["wifi5_ssid"]); ngx.print('</span>\
        </div>\
      </div>\
      <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
        <div class="col-xs-12 col-sm-5 col-md-5">\
          <span>');  ngx.print(T"MAC Address"); ngx.print('</span>\
        </div>\
        <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
          <span id ="status-lbl-w5mac">');  ngx.print(staticContent["wifi5_mac"]:upper()); ngx.print('</span>\
        </div>\
      </div>\
      <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
        <div class="col-xs-12 col-sm-5 col-md-5">\
          <span>');  ngx.print(T"Security"); ngx.print('</span>\
        </div>\
        <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
          <span id ="status-lbl-w5sec" >');  if status_content["wifi5_security"] then   ngx.print(status_content["wifi5_security"]:upper()); ngx.print(' ');  end  ngx.print('</span>\
        </div>\
      </div>\
      <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
        <div class="col-xs-12 col-sm-5 col-md-5">\
          <span>');  ngx.print(T"Channel"); ngx.print('</span>\
        </div>\
        <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
          <span id ="status-lbl-w5chan">');  ngx.print(status_content["wifi5_channel"]); ngx.print('</span>\
        </div>\
      </div>\
      <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
        <div class="col-xs-12 col-sm-5 col-md-5">\
          <span>');  ngx.print(T"Bandwidth"); ngx.print('</span>\
        </div>\
        <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
          <span id="status-lbl-w5bndwd">');  ngx.print(getWifiData(status_content["wifi5_bandwidth"])); ngx.print('</span>\
        </div>\
      </div>\
      <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
        <div class="col-xs-12 col-sm-5 col-md-5">\
          <span>');  ngx.print(T"Current Channel"); ngx.print('</span>\
        </div>\
        <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
          <span id="status-lbl-w5cntchan">');  ngx.print(status_content["wifi_HighChannel"]); ngx.print('</span>\
        </div>\
      </div>\
    </div>\
  </div>\
\
  <h3><span>');  ngx.print(T"System"); ngx.print('</span></h3>\
  <div class="h3-content h3-content-mobile">\
    <div class="row padding-top-bottom-20 no-margin-right">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
        <span>');  ngx.print(T"Serial Number"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
        <span id="status-lbl-gwser">');  ngx.print(staticContent["sys_gw_serial"]); ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
        <span>');  ngx.print(T"Firmware version"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
        <span class="text-word-wrap" id="status-lbl-gwver">');  ngx.print(staticContent["sys_gw_version"]); ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
        <span >');  ngx.print(T"Bootloader Version"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
        <span id="status-lbl-btldver" >');  ngx.print(staticContent["sys_bootloader_version"]); ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
        <span>');  ngx.print(T"Hardware Type &amp; Version"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
        <span id ="status-lbl-hwver">');  ngx.print(staticContent["sys_hw_version"]); ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
        <span>');  ngx.print(T"Uptime since last reboot"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
        <span id="status-lbl-uptme">');  ngx.print(format("%s %s, %s %s %s %s %s",uptime_days,T"days",uptime_hours,T"hours",T"and",uptime_minutes,T"minutes")); ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
        <span>');  ngx.print(T"CPU Usage"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
        <span id="statu-lbl-cpuusag">');  ngx.print(status_content["sys_cpu_usage"].." %"); ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
        <span>');  ngx.print(T"Memory Usage"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
        <span id="status-lbl-memusg">');  ngx.print(sys_memory.." %"); ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
        <span>');  ngx.print(T"Reboot Cause"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
        <span id="status-lbl-rebootcause">');  ngx.print(staticContent["sys_reboot_cause"]); ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
	      <span>');  ngx.print(T"Wireless Driver Version"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
        <span id="status-lbl-wlDrvrVrsn24GHz">');  ngx.print(staticContent["sys_wireless_driver_version24GHz"]); ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
        <span>');  ngx.print(T"Wireless Driver Version 5 GHz"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
        <span id="status-lbl-wlDrvrVrsn5GHz">');  ngx.print(staticContent["sys_wireless_driver_version5GHz"]); ngx.print('</span>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20 no-margin-right status-border-top">\
      <div class="col-xs-12 col-sm-5 col-md-5">\
        <span>');  ngx.print(T"Date &amp; Time"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-7 col-sm-7 dns-text-left">\
        <span id="status-lbl-datetime">');  ngx.print(format("%s.%s.%s | %s:%s %s", current_date, month, year, current_hour, current_minute, current_timezone)); ngx.print('</span>\
      </div>\
    </div>\
  </div>\
</div>\
<script>\
$(function(){\
  var port1status = "');  ngx.print(status_content["lan_port1_status"]); ngx.print('";\
  var port2status = "');  ngx.print(status_content["lan_port2_status"]); ngx.print('";\
  var port3status = "');  ngx.print(status_content["lan_port3_status"]); ngx.print('";\
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
});\
</script>\
'); 