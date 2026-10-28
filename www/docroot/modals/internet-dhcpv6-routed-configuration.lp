--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "InternetAccess", "IPv6PPPUsername")
local dyntab_helper = require("web.dyntab_helper")
local session = ngx.ctx.session
local role = session:getrole()
local imh = require("internetmode_ex_helper")
local tabdata = dyntab_helper.process(imh)
local mode_current = tabdata.current.name
local proxy = require("datamodel")
local format = string.format
local wanIntf = post_helper.getActiveInterface()
local wan6Intf = post_helper.getActiveInterface_v6()

local validateIPv6andUsername= function(value, object, key)
        local valid, msg = post_helper.validateBoolean(value, object, key)
        local ipv6_state = proxy.get("uci.network.interface.@"..wanIntf..".ipv6")[1].value == "0" and "0" or "1"

        if valid and ipv6_state and value ~= ipv6_state then
          if post_helper.getVariantValue(variantHelper, "Username") then
            local ipv6_realm = proxy.get("uci.env.var.ppp_realm_ipv6")[1].value
            local ipv4_realm = proxy.get("uci.env.var.ppp_realm_ipv4")[1].value
            proxy.set("uci.network.interface.@"..wanIntf..".username", value == "1" and ipv6_realm or ipv4_realm)
            proxy.set("uci.network.device.@waneth4.ipv6", value == "1" and "1" or "0")
            proxy.set("uci.network.device.@wanptm0.ipv6", value == "1" and "1" or "0")
          end
             proxy.set("uci.network.interface.@"..wanIntf..".ipv6", value)
          proxy.apply()
        end
        return valid, msg
end


-- Shortcuts to validation helpers to make lines shorter
local validateBoolean = post_helper.validateBoolean
-- Configurable data
local mapParams = {
  uci_wan_auto = format("uci.network.interface.@%s.auto", wan6Intf),
}

local mapValid = {
  uci_wan_auto = validateIPv6andUsername
}

local content = post_helper.handleQuery(mapParams, mapValid)

local ajax_attr = {
  span = {
    ["data-ajaxrefresh"] = "5"
  }
}

-- default value
content["uci_wan_auto"] = content["uci_wan_auto"] == "0" and "0" or "1"

local cs = {
  ipaddr = format("rpc.network.interface.@%s.ip6addr", wan6Intf),
  nexthop = format("rpc.network.interface.@%s.nexthop", wan6Intf),
  dns = format("rpc.network.interface.@%s.dnsservers", wan6Intf),
  rpc_ip6prefix = format("rpc.network.interface.@%s.ip6prefix", wan6Intf),
  uci_delegate = format("uci.network.interface.@%s.delegate", wan6Intf)
}
content_helper.getExactContent(cs)

ngx.print(ui_helper.createHeader(T"Internet Access", true, true))
  ngx.print('\
<div class="modal-body update">\
');  
  ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  local tabs = {
    {
      desc = T"IPv4 Configuration",
      target = "modals/internet-modal.lp"
    },
    {
      desc = T"IPv6 Configuration",
      active = "active",
      target = "modals/internet-ex-modal.lp"
    }
  }
  ngx.print(ui_helper.createModalTabs(tabs))

  if session:hasAccess("/modals/internet-"..mode_current.."-routed-configuration.lp") then
    local tab = {
      {
        desc = T"Status",
        target = "modals/internet-"..mode_current.."-routed-status.lp"
      },
      {
        desc = T"Configuration",
        active = "active",
        target = "modals/internet-"..mode_current.."-routed-configuration.lp"
      },
    }
    if post_helper.isFeatureEnabled("InternetStatusSettingsTab" , role) then
      tab[#tab+1] = {
        desc = T"Settings",
        target = "modals/internet-"..mode_current.."-routed-settings.lp",
      }
    end
    ngx.print(ui_helper.createModalTabs(tab))
  end
  ngx.print('\
<fieldset>\
<legend>');  ngx.print( T"DHCPv6 connection" ); ngx.print('</legend>\
<form class = "form-horizontal" method = "post" action = "modals/internet-dhcpv6-routed-configuration.lp">\
');  
  local html = {}
  html[#html+1] = ui_helper.createSwitch(T"Enabled", "uci_wan_auto", content["uci_wan_auto"])
  html[#html+1] = ui_helper.createLabel(T"IPv6 address", cs["ipaddr"], ajax_attr)
  ajax_attr.span.id = "nexthop"
  html[#html+1] = ui_helper.createLabel(T"Gateway", cs["nexthop"], ajax_attr)
  ajax_attr.span.id = "dns"
  html[#html+1] = ui_helper.createLabel(T"DNS servers", cs["dns"], ajax_attr)
  if cs["uci_delegate"] ~= "0" then
    html[#html+1] = ui_helper.createLabel(T"IPv6 prefix delegation", cs["rpc_ip6prefix"])
  end
  ngx.print(html)
  ngx.print('\
\
</fieldset>\
</form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 