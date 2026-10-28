--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local ajax_helper = require("web.ajax_helper")
local post_helper = require("web.post_helper")
local dyntab_helper = require("web.dyntab_helper")
local session = ngx.ctx.session
local role = session:getrole()
local imh = require("internetmode_ex_helper")
local tabdata = dyntab_helper.process(imh)
local mode_current = tabdata.current.name
local format = string.format
local wan6Intf = post_helper.getActiveInterface_v6()

-- State data
local dhcp_state = "connecting"
local dhcp_state_map = {
  disabled = T"disabled",
  connected = T"connected",
  connecting = T"connecting"
}

local dhcp_light_map = {
  disabled = "off",
  connecting = "orange",
  connected = "green"
}

local ajax_attr_light = {
  light = {
    class = ""
  },
  controls = {
    id = "wan_status",
  }
}

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

-- Shortcuts to validation helpers to make lines shorter
local validateBoolean = post_helper.validateBoolean
-- Configurable data
local mapParams = {
  uci_wan_auto = format("uci.network.interface.@%s.auto", wan6Intf)
}

local mapValid = {
  uci_wan_auto = validateBoolean
}

local content = post_helper.handleQuery(mapParams, mapValid)
-- default value
content["uci_wan_auto"] = content["uci_wan_auto"] == "0" and "0" or "1"

-- Non-configurable data
local cs = {
  ipaddr = format("rpc.network.interface.@%s.ip6addr", wan6Intf),
  nexthop = format("rpc.network.interface.@%s.nexthop", wan6Intf),
  dns = format("rpc.network.interface.@%s.dnsservers", wan6Intf),
  rpc_ip6prefix = format("rpc.network.interface.@%s.ip6prefix", wan6Intf),
  uci_delegate = format("uci.network.interface.@%s.delegate", wan6Intf)
}

ajax_helper.handleAjaxQuery(cs, function(c)
  -- this will add the HTML for the light
  local ds = get_dhcp_state(content["uci_wan_auto"], c["ipaddr"])
  ajax_attr_light.light.class = dhcp_light_map[ds]
  c.wan_status = ui_helper.createSimpleLight(nil, dhcp_state_map[ds], ajax_attr_light)
end)
-- will stop in handleAjaxQuery if it is an actual AJAX query
content_helper.getExactContent(cs)

dhcp_state = get_dhcp_state(content["uci_wan_auto"], cs["ipaddr"])

ngx.print(ui_helper.createHeader(T"Internet Access", true, true))
  ngx.print('\
<div class="modal-body update">\
');  
local tabs = {
  {
    desc = T"IPv4 Configuration",
    target = "modals/internet-modal.lp"
  },
  {
    desc = T"IPv6 Configuration",
    active = "active",
    target = "modals/internet-ex-modal.lp"
  },
}
ngx.print(ui_helper.createModalTabs(tabs))

if session:hasAccess("/modals/internet-"..mode_current .."-routed-configuration.lp") then
  local tab = {
    {
      desc = T"Status",
      active = "active",
      target = "modals/internet-"..mode_current .."-routed-status.lp"
    },
    {
      desc = T"Configuration",
      target = "modals/internet-"..mode_current .."-routed-configuration.lp"
    }
  }
  if post_helper.isFeatureEnabled("InternetStatusSettingsTab" , role) then
    tab[#tab+1] = {
      desc = T"Settings",
      target = "modals/internet-"..mode_current .."-routed-settings.lp"
    }
  end
  ngx.print(ui_helper.createModalTabs(tab))
end
  ngx.print('\
<fieldset>\
');  
  ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<legend>');  ngx.print( T"DHCPv6 connection" ); ngx.print('</legend>\
<form class = "form-horizontal" method = "post" action = "modals/internet-dhcpv6-routed-status.lp">\
  ');  
    ajax_attr_light.light.class = dhcp_light_map[dhcp_state]
    ngx.print(ui_helper.createLight(T"Status", nil, dhcp_state_map[dhcp_state], ajax_attr_light))
    ngx.print('\
</form>\
</div>\
\
</fieldset>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 