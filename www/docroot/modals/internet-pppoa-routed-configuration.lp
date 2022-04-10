--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
local match, format, find, upper = string.match, string.format, string.find, string.upper
local session = ngx.ctx.session
local role = session:getrole()
local dyntab_helper = require("web.dyntab_helper")
local imh = require("internetmode_helper").get()
local tabdata = dyntab_helper.process(imh)
local mode_current = tabdata.current.name
local wanIntf = post_helper.getActiveInterface()
local wan6Intf = post_helper.getActiveInterface_v6()
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "InternetAccess", "IPv4PPPCred")

-- Process POST query
local post_helper = require("web.post_helper")
local firewall_zone = proxy.get("uci.firewall.zone.")
local firewall_zone_path = content_helper.convertResultToObject("uci.firewall.zone.", firewall_zone)
local zonenum = ""
for _, v in ipairs(firewall_zone_path) do
  if (v["name"] == "wan") then
    zonenum = v["paramindex"]
    break
  end
end
local firewall_forwarding = proxy.get("uci.firewall.forwarding.")
local firewall_forwarding_path = content_helper.convertResultToObject("uci.firewall.forwarding." ,firewall_forwarding)
local forwdnum = ""
for _, v in ipairs(firewall_forwarding_path) do
  if (v["src"] == wanIntf and v["dest"] == "lan") then
    forwdnum = v["paramindex"]
    break
  end
end
local mapParams = {
  uci_wan_auto = format("uci.network.interface.@%s.auto", wanIntf),
  uci_wan_username = format("uci.network.interface.@%s.username", wanIntf),
  uci_wan_password = format("uci.network.interface.@%s.password", wanIntf),
  uci_wan_masq = "uci.firewall.zone."..zonenum..".masq"
}

-- Shortcuts to validation helpers to make lines shorter
local conditionalValid = post_helper.getConditionalValidation
local validateBoolean = post_helper.validateBoolean
local validateEmptyString = post_helper.validateNonEmptyString
local validatePassword = post_helper.getValidationPassword
local optionalValidation = post_helper.getOptionalValidation

local firewall_value = {["uci.firewall.forwarding.@"..forwdnum..".src"] = wanIntf,
                        ["uci.firewall.forwarding.@"..forwdnum..".dest"] = "lan",
                        ["uci.firewall.forwarding.@"..forwdnum..".name"] = "for_w2l"}

local function validateNat(value, object, key)
  return post_helper.validateNat(value, object, key, forwdnum, zonenum)
end

local function isWanEnabled(value, object, key)
  return object["uci_wan_auto"] ~= "0"
end

-- Validation allows empty values if wan access disabled but will stil check for validity if the parameter is set
-- if wan is enabled then it checks for validaty anyway
local mapValid = {
  uci_wan_auto = validateBoolean,
  uci_wan_username = conditionalValid(isWanEnabled, post_helper.validateUsername, optionalValidation(post_helper.validateUsername)),
  uci_wan_password = conditionalValid(isWanEnabled, validatePassword(validateEmptyString), validatePassword()),
  uci_wan_masq = validateNat
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
-- End POST process

local content_uci = {
  wan_proto = format("uci.network.interface.@%s.proto", wanIntf),
  wan_domain = format("uci.network.interface.@%s.domain", wanIntf)
}
content_helper.getExactContent(content_uci)

local content_rpc = {
  wan_ppp_state = format("rpc.network.interface.@%s.ppp.state", wanIntf),
  wan_ppp_error = format("rpc.network.interface.@%s.ppp.error", wanIntf),
  wan_ppp_ll_intf = format("rpc.network.interface.@%s.ppp.ll_intf", wanIntf),
  ipaddr = format("rpc.network.interface.@%s.ipaddr", wanIntf),
  nexthop = format("rpc.network.interface.@%s.nexthop", wanIntf),
  dns_wan = format("rpc.network.interface.@%s.dnsservers", wanIntf),
  ipv6_gua = format("rpc.network.interface.@wan6.ipv6uniqueglobaladdr", wan6Intf),
  dns_loopback = "rpc.network.interface.@loopback.dnsservers"  -- Added to include static dns servers configured on loopback interface (for TI custo)
}

for _, v in ipairs(proxy.getPN("rpc.network.interface.", true)) do
  local intf = match(v.path, "rpc%.network%.interface%.@([^%.]+)%.")
  if intf then
    content_rpc.ip6addr = "rpc.network.interface.@"..intf..".ip6addr"
    content_rpc.ip6prefix = "rpc.network.interface.@"..intf..".ip6prefix"
    content_rpc.dnsv6 = "rpc.network.interface.@"..intf..".dnsservers"
    break
  end
end

content_helper.getExactContent(content_rpc)
content_rpc.dns = content_helper.getMergedList(content_rpc.dns_wan, content_rpc.dns_loopback)

-- need to untaint the string otherwise getExactContent will get lost
local wan_atm_uci_path = format("uci.xtm.atmdevice.@%s.", content_rpc["wan_ppp_ll_intf"])
local  content_uci_xtm = {
  wan_atm_vpi = wan_atm_uci_path.."vpi",
  wan_atm_vci = wan_atm_uci_path.."vci",
  wan_atm_enc = wan_atm_uci_path.."enc",
  wan_atm_ulp = wan_atm_uci_path.."ulp",
  wan_vpi = format("uci.network.interface.@%s.vpi", wanIntf),
  wan_vci = format("uci.network.interface.@%s.vci", wanIntf)
}
content_helper.getExactContent(content_uci_xtm)

local params = {}
local setting = false
if content_uci_xtm.wan_atm_vpi ~= content_uci_xtm.wan_vpi then
  params[format("uci.network.interface.@%s.vpi", wanIntf)] = content_uci_xtm.wan_atm_vpi
  setting = true
end
if content_uci_xtm.wan_atm_vci ~= content_uci_xtm.wan_vci then
  params[format("uci.network.interface.@%s.vci", wanIntf)] = content_uci_xtm.wan_atm_vci
  setting = true
end
if content_uci_xtm.wan_atm_ulp ~= "ppp" then
  params[wan_atm_uci_path.."ulp"] = "ppp"
  setting = true
end

if setting then
  proxy.set(params)
  proxy.apply()
end

if content_uci["wan_domain"] ~= "" then
  content["uci_wan_username"] = match(content["uci_wan_username"], "[^@]*")
end

ngx.print(ui_helper.createHeader(T"Internet Access", true, true))
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
  },
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
  ngx.print('\
\
<form class = "form-horizontal" method = "post" action = "modals/internet-pppoa-routed-configuration.lp">\
<fieldset>\
');  
   ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<legend>');  ngx.print( T"PPP connection" ); ngx.print('</legend>\
');  
  local html = {}
  -- Label that shows PPP status
  -- Switch PPP on/off
  html[#html + 1] = ui_helper.createSwitch(T"Enabled", "uci_wan_auto", content.uci_wan_auto)
  html[#html + 1] = ui_helper.createSwitch( T"NAT", "uci_wan_masq", content.uci_wan_masq)
  -- PPP username
  local class_username = {
    input = {
      maxlength= "128",
      class = "span6"
    }
  }
  if post_helper.variantHasAccess(variantHelper, "Userpass", role) then
    html[#html + 1] = "<div class='control-group'><label class='control-label'>" .. T"Username" .. "</label><div class='controls'>"
    html[#html + 1] = ui_helper.createSimpleInputText("uci_wan_username", content["uci_wan_username"], class_username, helpmsg["uci_wan_username"])
    if content_uci["wan_domain"] ~= "" then
      html[#html + 1] = " @ " .. content_uci["wan_domain"]
    end
    html[#html + 1] = "</div></div>"
    -- PPP password
    local class_password = class_username
    html[#html + 1] = ui_helper.createInputPassword(T"Password", "uci_wan_password", content["uci_wan_password"], class_username, helpmsg["uci_wan_password"])
  end
  html[#html+1] = ui_helper.createLabel(T"IPv4 address", content_rpc["ipaddr"])
  html[#html+1] = ui_helper.createLabel(T"Gateway", content_rpc["nexthop"])
  html[#html+1] = ui_helper.createLabel(T"DNS servers", content_rpc["dns"])
  if content_rpc["ip6addr"] and content_rpc["ip6addr"]:len() > 0 then
    html[#html+1] = ui_helper.createLabel(T"IPv6 Address", content_rpc["ip6addr"])
  end
  if content_rpc["ipv6_gua"] and content_rpc["ipv6_gua"]:len() > 0 then
    html[#html+1] = ui_helper.createLabel(T"IPv6 GUA", content_rpc["ipv6_gua"])
  end
  if content_rpc["ip6prefix"] and content_rpc["ip6prefix"]:len() > 0 then
    html[#html+1] = ui_helper.createLabel(T"IPv6 Prefix", content_rpc["ip6prefix"])
  end
  if content_rpc["dnsv6"] and content_rpc["dnsv6"]:len() > 0 then
    html[#html+1] = ui_helper.createLabel(T"IPv6 DNS", content_rpc["dnsv6"])
  end
  -- ATM VP/VC
  local advanced = {
    group = {
      class = "advanced hide"
    }
  }
  local vp_vc = format("%s / %s", content_uci_xtm["wan_atm_vpi"], content_uci_xtm["wan_atm_vci"])
  html[#html + 1] = ui_helper.createLabel(T"ATM VP / VC", vp_vc, advanced)
  html[#html + 1] = ui_helper.createLabel(T"Encapsulation", upper(content_uci_xtm["wan_atm_enc"]), advanced)
  ngx.print(html)
  ngx.print('\
</fieldset>\
</form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 