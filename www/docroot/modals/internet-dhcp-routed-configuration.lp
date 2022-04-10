--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
local ajax_helper = require("web.ajax_helper")
local tonumber = tonumber
local match, format = string.match, string.format
local session = ngx.ctx.session
local role = session:getrole()
local dyntab_helper = require("web.dyntab_helper")
local imh = require("internetmode_helper").get()
local tabdata = dyntab_helper.process(imh)
local mode_current = tabdata.current.name
local wanIntf = post_helper.getActiveInterface()
local wan6Intf = post_helper.getActiveInterface_v6()
local val_selected = session:retrieve("postedIntf_internet_modal") or wanIntf
local wan_ifname = proxy.get("rpc.network.interface.@"..val_selected..".ifname")
wan_ifname = wan_ifname and wan_ifname[1].value or ""

-- State data
local dhcp_state = "connecting"
local dhcp_state_map = {
  disabled = T"Disabled",
  connected = T"Connected",
  connecting = T"Connecting"
}

local dhcp_light_map = {
  disabled = "off",
  connecting = "orange",
  connected = "green"
}

local ajax_attr = {
  span = {
    ["data-ajaxrefresh"] = "5"
  }
}
local ajax_attr_light = {
  light = {
    id = "DHCP_Status_LED"
  },
  controls = {
    id = "wan_status",
    ["data-ajaxrefresh"] = "5"
  }
}

local mapDHCPstats = {
  discardR = format("sys.class.net.@%s.statistics.rx_dropped", wan_ifname),
  discardS = format("sys.class.net.@%s.statistics.tx_dropped", wan_ifname),
  broadcastR = format("sys.class.net.@%s.statistics.rx_broadcast", wan_ifname),
  broadcastS = format("sys.class.net.@%s.statistics.tx_broadcast", wan_ifname),
  multicastR = format("sys.class.net.@%s.statistics.multicast", wan_ifname),
  multicastS = format("sys.class.net.@%s.statistics.txpckt", wan_ifname),
  packetsR = format("sys.class.net.@%s.statistics.rx_packets", wan_ifname),
  packetsS = format("sys.class.net.@%s.statistics.tx_packets", wan_ifname),
  errorsR = format("sys.class.net.@%s.statistics.rx_errors", wan_ifname),
  errorsS = format("sys.class.net.@%s.statistics.tx_errors", wan_ifname),
  bytesR = format("sys.class.net.@%s.statistics.rx_bytes", wan_ifname),
  bytesS = format("sys.class.net.@%s.statistics.tx_bytes", wan_ifname),
  unicastR = format("sys.class.net.@%s.statistics.rx_unicast", wan_ifname),
  unicastS = format("sys.class.net.@%s.statistics.tx_unicast", wan_ifname),
  unknownR = format("sys.class.net.@%s.statistics.rxerr", wan_ifname)
}

content_helper.getExactContent(mapDHCPstats)

local function get_dhcp_state(wan_auto, ipaddr)
  -- Figure out interface state
  if wan_auto ~= "0" then
    if ipaddr:len() > 0 then
      return "connected"
    else
      return "connecting"
    end
  else
    return "disabled"
  end
end

-- Process POST query
local post_helper = require("web.post_helper")
local firewall_zone = proxy.get("uci.firewall.zone.")
local firewall_zone_path = content_helper.convertResultToObject("uci.firewall.zone.", firewall_zone)
local zonenum = ""
for _, firewallZoneValue in ipairs(firewall_zone_path) do
  if (firewallZoneValue["name"] == "wan") then
    zonenum = firewallZoneValue["paramindex"]
    break
  end
end
local firewall_forwarding = proxy.get("uci.firewall.forwarding.")
local firewall_forwarding_path = content_helper.convertResultToObject("uci.firewall.forwarding.", firewall_forwarding)
local forwdnum = ""
for _, firewallForwardValue in ipairs(firewall_forwarding_path) do
  if (firewallForwardValue["src"] == "wan" and firewallForwardValue["dest"] == "lan") then
    forwdnum = firewallForwardValue["paramindex"]
    break
  end
end
local firewall_value = {["uci.firewall.forwarding.@"..forwdnum..".src"] = "wan",
                        ["uci.firewall.forwarding.@"..forwdnum..".dest"] = "lan",
                        ["uci.firewall.forwarding.@"..forwdnum..".name"] = "for_w2l"}
local function validateNat(value, object, key)
  return post_helper.validateNat(value, object, key, forwdnum, zonenum)
end

-- Configurable data
local mapParams = {
  uci_wan_auto = format("uci.network.interface.@%s.auto", wanIntf),
  uci_wan_masq = "uci.firewall.zone."..zonenum..".masq"
}

-- Shortcuts to validation helpers to make lines shorter
local validateBoolean = post_helper.validateBoolean

local mapValid = {
  uci_wan_auto = validateBoolean,
  uci_wan_masq = validateNat
}

local content = post_helper.handleQuery(mapParams, mapValid)
-- default value
content["uci_wan_auto"] = content["uci_wan_auto"] ~= "0" and "1"

local wan_ppp_ll_intf = proxy.get("rpc.network.interface.@"..wanIntf..".ppp.ll_intf")[1].value
local wan_atm_uci_path = format("uci.xtm.atmdevice.@%s.", wan_ppp_ll_intf)
local wan_ppp_over_atm = proxy.get(wan_atm_uci_path) ~= nil
if wan_ppp_over_atm then
  local content_uci_xtm = {
    wan_atm_ulp = wan_atm_uci_path.."ulp",
    wan_vpi = format("uci.network.interface.@%s.vpi", wanIntf),
    wan_vci = format("uci.network.interface.@%s.vci" , wanIntf)
  }
  content_helper.getExactContent(content_uci_xtm)

  local params = {}
  local setting = false
  if content_uci_xtm.wan_vpi ~= "" then
    params["uci.network.interface.@wan.vpi"] = ""
    setting = true
  end
  if content_uci_xtm.wan_vci ~= "" then
    params[format("uci.network.interface.@%s.vci", wanIntf)] = ""
    setting = true
  end
  if content_uci_xtm.wan_atm_ulp ~= "eth" then
    params[wan_atm_uci_path.."ulp"] = "eth"
    setting = true
  end

  if setting then
    proxy.set(params)
    proxy.apply()
  end
end

-- Non-configurable data
local configData = {
  ipaddr = format("rpc.network.interface.@%s.ipaddr", val_selected),
  nexthop = format("rpc.network.interface.@%s.nexthop", val_selected),
  dns_wan = format("rpc.network.interface.@%s.dnsservers", val_selected) ,
  ipv6_gua = format("rpc.network.interface.@%s.ipv6uniqueglobaladdr", val_selected),
  dns_loopback = "rpc.network.interface.@loopback.dnsservers"  -- Added to include static dns servers configured on loopback interface (for TI custo)
}

for _, interfaceValue in ipairs(proxy.getPN("rpc.network.interface.", true)) do
  local intf = match(interfaceValue.path, "rpc%.network%.interface%.@([^%.]+)%.")
  if intf then
    configData.ip6addr = "rpc.network.interface.@"..intf..".ip6addr"
    configData.ip6prefix = "rpc.network.interface.@"..intf..".ip6prefix"
    if intf ~= wanIntf then
      configData.dnsv6 = "rpc.network.interface.@"..intf..".dnsservers"
    elseif intf == wan6Intf then
      break
    end
  end
end

local dhcp_lease = {
  uptime = "rpc.system.uptime",
  connect_time = format("uci.network.interface.@%s.connect_time", wanIntf),
  lease = format("uci.network.interface.@%s.lease", wanIntf),
  lease_expires = format("uci.network.interface.@%s.lease_expires" ,wanIntf)
}

local function getLeaseTime(uptime, lease, expires)
  local leaseobtained = os.date("%F %T", os.time() - (tonumber(uptime) - (tonumber(expires ~="" and expires or 0) - tonumber(lease ~="" and lease or 0))))
  local leaseexpires = os.date("%F %T", os.time() + (tonumber(expires ~="" and expires or 0) - tonumber(uptime)))
  return leaseobtained, leaseexpires
end

ajax_helper.handleAjaxQuery(configData, function(c)
  -- this will add the HTML for the light
  local dhcpState = get_dhcp_state(content["uci_wan_auto"], c["ipaddr"])
  ajax_attr_light.light.class = dhcp_light_map[dhcpState]
  c.wan_status = ui_helper.createSimpleLight(nil, dhcp_state_map[dhcpState], ajax_attr_light)
  if dhcpState == "connected" then
    content_helper.getExactContent(dhcp_lease)
    c["leaseobtained"], c["leaseexpires"] = getLeaseTime(dhcp_lease["uptime"],  dhcp_lease["lease"], dhcp_lease["lease_expires"])
  end
end)
-- will stop in handleAjaxQuery if it is an actual AJAX query
content_helper.getExactContent(configData)

configData.dns = content_helper.getMergedList(configData.dns_wan, configData.dns_loopback)

-- account for inconsistencies in DNS display format by removing extra spaces
if configData["dns"] and #configData["dns"] > 0 then
  configData["dns"] = configData["dns"]:gsub("%s+", "")
end
if configData["dnsv6"] and #configData["dnsv6"] > 0 then
  configData["dnsv6"] = configData["dnsv6"]:gsub("%s+", "")
end

dhcp_state = get_dhcp_state(content["uci_wan_auto"], configData["ipaddr"])

-- dhcp lease data
configData["leaseobtained"] = ""
configData["leaseexpires"] = ""
if dhcp_state == "connected" then
  content_helper.getExactContent(dhcp_lease)
  configData["leaseobtained"], configData["leaseexpires"] = getLeaseTime(dhcp_lease["uptime"], dhcp_lease["lease"], dhcp_lease["lease_expires"])
end

if ngx.req.get_method() == "POST" then
  local postargs  = ngx.req.get_post_args()
  if postargs.action == "ReleaseAndRenew" then
    if proxy.set("rpc.network.release_renew", "1") then
      proxy.apply()
    end
  end
end

ngx.print(ui_helper.createHeader(T"Internet Access", #imh > 1, true))
  ngx.print('\
\
<div class="modal-body update">\
');  
  local tabs = {
    {
      desc = T"IPv4 Configuration",
      active = "active",
      target = "modals/internet-modal.lp"
    },
    {
      desc = T"IPv6 Configuration",
      target = "modals/internet-ex-modal.lp"
    }
  }
  ngx.print(ui_helper.createModalTabs(tabs))

  if session:hasAccess("/modals/internet-"..mode_current.."-routed-status.lp") then
    local tab = {
      {
        desc = T"Status",
        target = "modals/internet-"..mode_current.."-routed-status.lp"
      },
      {
        desc = T"Configuration",
        active = "active",
        target = "modals/internet-"..mode_current.."-routed-configuration.lp"
      }
    }
    if post_helper.isFeatureEnabled("InternetStatusSettingsTab" , role) then
      tab[#tab+1] = {
        desc = T"Settings",
        target = "modals/internet-"..mode_current.."-routed-settings.lp"
      }
    end
    ngx.print(ui_helper.createModalTabs(tab))
  end
  ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<form class = "form-horizontal" method = "post" action = "modals/internet-dhcp-routed-configuration.lp">\
<fieldset>\
  <legend>');  ngx.print( T"DHCP connection" ); ngx.print('</legend>\
  ');  
    local html = {}
    if post_helper.isFeatureEnabled("DHCPButton" , role) then
      html[#html+1] = ui_helper.createSwitch(T"Enabled", "uci_wan_auto", content["uci_wan_auto"])
    end
    if post_helper.isFeatureEnabled("NATButton" , role) then
      html[#html + 1] = ui_helper.createSwitch(T"NAT", "uci_wan_masq", content.uci_wan_masq)
    end
    ajax_attr.span.id = "ipaddr"
    html[#html+1] = ui_helper.createLabel(T"IPv4 address", configData["ipaddr"], ajax_attr)
    ajax_attr.span.id = "nexthop"
    html[#html+1] = ui_helper.createLabel(T"Gateway", configData["nexthop"], ajax_attr)
    ajax_attr.span.id = "dns"
    html[#html+1] = ui_helper.createLabel(T"DNS servers", configData["dns"], ajax_attr)
    if configData["ip6addr"] and configData["ip6addr"]:len() > 0 then
      ajax_attr.span.id = "ip6addr"
      html[#html+1] = ui_helper.createLabel(T"IPv6 address", configData["ip6addr"], ajax_attr)
    end
    if configData["ipv6_gua"] and configData["ipv6_gua"]:len() > 0 then
      ajax_attr.span.id = "ipv6gua"
      html[#html+1] = ui_helper.createLabel(T"IPv6 GUA", configData["ipv6_gua"], ajax_attr)
    end
    if configData["ip6prefix"] and configData["ip6prefix"]:len() > 0 then
      ajax_attr.span.id = "ip6prefix"
      html[#html+1] = ui_helper.createLabel(T"IPv6 Prefix", configData["ip6prefix"], ajax_attr)
    end
    if configData["dnsv6"] and configData["dnsv6"]:len() > 0 then
      -- make sure auto-refresh updates control with ONLY DNSv6 servers
      ajax_attr.span.id = "dnsv6"
      html[#html+1] = ui_helper.createLabel(T"IPv6 DNS", configData["dnsv6"], ajax_attr)
    end
    ajax_attr.span.id = "leaseobtained"
    html[#html+1] = ui_helper.createLabel(T"Lease obtained", configData["leaseobtained"], ajax_attr)
    ajax_attr.span.id = "leaseexpires"
    html[#html+1] = ui_helper.createLabel(T"Lease expires", configData["leaseexpires"], ajax_attr)

    local dhcp_release_renew = {
      group = {
        class = "advanced hide"
      },
      button = {
        id = "btn-dhcp-release-renew",
        class = "custom-handler"
      }
    }
    html[#html + 1] = ui_helper.createButton(T"Release and Renew", T"Release and Renew", "icon-refresh", dhcp_release_renew)
    ngx.print(html)
    ngx.print('\
</fieldset>\
<fieldset class = "advanced hide">\
  <legend>');  ngx.print(T"DHCP statistics"); ngx.print('</legend>\
  ');  
    local iconUp = "<i class=\"icon-upload icon-large gray\"></i>"
    local iconDown = "<i class=\"icon-download icon-large gray\"></i>"
    local html = {}

    html[#html + 1] = ui_helper.createLabel(
      T"Discard Packets",
      format("%s %s Pkd %s %s Pkd", iconUp, mapDHCPstats.discardS, iconDown, mapDHCPstats.discardR)
    )

    html[#html + 1] = ui_helper.createLabel(
      T"Broadcast Packets",
      format("%s %s Pkd %s %s Pkd", iconUp, mapDHCPstats.broadcastS, iconDown, mapDHCPstats.broadcastR)
    )

    html[#html + 1] = ui_helper.createLabel(
      T"Multicast Packets",
      format("%s %s Pkd %s %s Pkd", iconUp, mapDHCPstats.multicastS, iconDown, mapDHCPstats.multicastR)
    )

    html[#html + 1] = ui_helper.createLabel(
      T"Unicast Packets",
      format("%s %s Pkd %s %s Pkd", iconUp, mapDHCPstats.unicastS, iconDown, mapDHCPstats.unicastR)
    )

    html[#html + 1] = ui_helper.createLabel(
      T"Packets",
      format("%s %s Pkd %s %s Pkd", iconUp, mapDHCPstats.packetsS, iconDown, mapDHCPstats.packetsR)
    )

    html[#html + 1] = ui_helper.createLabel(
      T"Errors",
      format("%s %s Pkd %s %s Pkd", iconUp, mapDHCPstats.errorsS, iconDown, mapDHCPstats.errorsR)
    )

    html[#html + 1] = ui_helper.createLabel(
      T"Bytes",
      format("%s %s Bytes %s %s Bytes", iconUp, mapDHCPstats.bytesS, iconDown, mapDHCPstats.bytesR)
    )

    html[#html + 1] = ui_helper.createLabel(
      T"Unknown Proto Packets",
      format("%s %s Pkd", iconDown, mapDHCPstats.unknownR)
    )

    ngx.print(html)
    ngx.print('\
</fieldset>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
\
<script src = "/js/srp-min.js" ></script>\
<script src="/js/internet-routed-settings.js"></script>\
'); 