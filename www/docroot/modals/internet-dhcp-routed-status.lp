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

local ajax_attr_light = {
  light = {
    class = "",
    id = "DHCP_Status_LED"
  },
  controls = {
    id = "wan_status",
    ["data-ajaxrefresh"] = "5"
  }
}

local function get_dhcp_state(wan_auto, ipaddr)
  -- Figure out interface state
  if wan_auto ~= "0" then
    if #ipaddr > 0 then
      return "connected"
    else
      return "connecting"
    end
  else
    return "disabled"
  end
end

-- Configurable data
local mapParams = {
  uci_wan_auto = format("uci.network.interface.@%s.auto", wanIntf)
}

-- Shortcuts to validation helpers to make lines shorter
local validateBoolean = post_helper.validateBoolean

local mapValid = {
  uci_wan_auto = validateBoolean,
}
local content = post_helper.handleQuery(mapParams, mapValid)
-- default value
content["uci_wan_auto"] = content["uci_wan_auto"] ~= "0" and "1"

-- Non-configurable data
local cs = {
  ipaddr = format("rpc.network.interface.@%s.ipaddr", wanIntf),
  nexthop = format("rpc.network.interface.@%s.nexthop", wanIntf),
  dns_wan = format("rpc.network.interface.@%s.dnsservers", wanIntf),
  ipv6_gua = format("rpc.network.interface.@%s.ipv6uniqueglobaladdr", wan6Intf),
  dns_loopback = "rpc.network.interface.@loopback.dnsservers"  -- Added to include static dns servers configured on loopback interface (for TI custo)
}

for index, interfaceVal in ipairs(proxy.getPN("rpc.network.interface.", true)) do
  local intf = match(interfaceVal.path, "rpc%.network%.interface%.@([^%.]+)%.")
  if intf then
    cs.ip6addr = "rpc.network.interface.@"..intf..".ip6addr"
    cs.ip6prefix = "rpc.network.interface.@"..intf..".ip6prefix"
    cs.dnsv6 = "rpc.network.interface.@"..intf..".dnsservers"
  end
end

local dhcp_lease = {
  uptime = "rpc.system.uptime",
  connect_time = format("uci.network.interface.@%s.connect_time", wanIntf),
  lease = format("uci.network.interface.@%s.lease", wanIntf),
  lease_expires = format("uci.network.interface.@%s.lease_expires", wanIntf),
}

local function getLeaseTime(uptime, lease, expires)
  local leaseobtained = os.date("%F %T", os.time() - (tonumber(uptime) - (tonumber(expires ~="" and expires or 0) - tonumber(lease ~="" and lease or 0))))
  local leaseexpires = os.date("%F %T", os.time() + (tonumber(expires ~="" and expires or 0) - tonumber(uptime)))
  return leaseobtained, leaseexpires
end

ajax_helper.handleAjaxQuery(cs, function(c)
  -- this will add the HTML for the light
  local dhcpStste = get_dhcp_state(content["uci_wan_auto"], c["ipaddr"])
  ajax_attr_light.light.class = dhcp_light_map[dhcpStste]
  c.wan_status = ui_helper.createSimpleLight(nil, dhcp_state_map[dhcpStste], ajax_attr_light)
  if dhcpStste == "connected" then
    content_helper.getExactContent(dhcp_lease)
    c["leaseobtained"], c["leaseexpires"] = getLeaseTime(dhcp_lease["uptime"],  dhcp_lease["lease"], dhcp_lease["lease_expires"])
  end
end)
-- will stop in handleAjaxQuery if it is an actual AJAX query
content_helper.getExactContent(cs)

cs.dns = content_helper.getMergedList(cs.dns_wan, cs.dns_loopback)

-- account for inconsistencies in DNS display format by removing extra spaces
if cs["dns"] and cs["dns"]:len() > 0 then
  cs["dns"] = cs["dns"]:gsub("%s+", "")
end
if cs["dnsv6"] and cs["dnsv6"]:len() > 0 then
  cs["dnsv6"] = cs["dnsv6"]:gsub("%s+", "")
end

dhcp_state = get_dhcp_state(content["uci_wan_auto"], cs["ipaddr"])

-- dhcp lease data
cs["leaseobtained"] = ""
cs["leaseexpires"] = ""
if dhcp_state == "connected" then
  content_helper.getExactContent(dhcp_lease)
  cs["leaseobtained"], cs["leaseexpires"] = getLeaseTime(dhcp_lease["uptime"], dhcp_lease["lease"], dhcp_lease["lease_expires"])
end

ngx.print(ui_helper.createHeader(T"Internet Access", true, true))
  ngx.print('\
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
  if session:hasAccess("/modals/internet-"..mode_current .."-routed-configuration.lp") then
    local tabsConf = {
      {
        desc =  T"Status",
        active = "active",
        target = "modals/internet-"..mode_current .."-routed-status.lp"
      },
      {
        desc = T"Configuration",
        target = "modals/internet-"..mode_current .."-routed-configuration.lp"
      }
    }
    if post_helper.isFeatureEnabled("InternetStatusSettingsTab" , role) then
      tabsConf[#tabsConf+1] = {
        desc = T"Settings",
        target = "modals/internet-"..mode_current .."-routed-settings.lp"
      }
    end
    ngx.print(ui_helper.createModalTabs(tabsConf))
  end
  ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<form class = "form-horizontal" method = "post" action = "modals/internet-dhcp-routed-status.lp">\
<fieldset>\
<legend>');  ngx.print( T"DHCP connection" ); ngx.print('</legend>\
   ');  
     ajax_attr_light.light.class = dhcp_light_map[dhcp_state]
     ngx.print(ui_helper.createLight(T"Status", nil, dhcp_state_map[dhcp_state], ajax_attr_light))
     ngx.print('\
</fieldset>\
</form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 