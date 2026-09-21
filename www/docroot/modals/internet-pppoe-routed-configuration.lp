--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local format, match, find, upper = string.format, string.match, string.find, string.upper
local post_helper = require("web.post_helper")
local session = ngx.ctx.session
local role = session:getrole()
local dyntab_helper = require("web.dyntab_helper")
local imh = require("internetmode_helper").get()
local tabdata = dyntab_helper.process(imh)
local mode_current = tabdata.current.name
local zonenum = ""
local firewall_zone = proxy.get("uci.firewall.zone.")
local firewall_zone_path = content_helper.convertResultToObject("uci.firewall.zone.",firewall_zone)
local wanIntf = post_helper.getActiveInterface()
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "InternetAccess", "IPv4PPPCred")
local wan6Intf = post_helper.getActiveInterface_v6()
local mode_selected = session:retrieve("postedIntf_internet_modal") or wanIntf
local xtmPath = "uci.xtm.atmdevice.@."
local untaint = string.untaint

for _, firewallValue in ipairs(firewall_zone_path) do
  if (firewallValue["name"] == "wan") then
    zonenum = firewallValue["paramindex"]
    break
  end
end
local firewall_forwarding = proxy.get("uci.firewall.forwarding.")
local firewall_forwarding_path = content_helper.convertResultToObject("uci.firewall.forwarding.",firewall_forwarding)
local forwdnum = ""
for _, firewallForwardingValue in ipairs(firewall_forwarding_path) do
  if (firewallForwardingValue["src"] ==  wanIntf and firewallForwardingValue["dest"] == "lan") then
    forwdnum = firewallForwardingValue["paramindex"]
    break
  end
end

local mapParams = {
  uci_wan_auto = format("uci.network.interface.@%s.auto", wanIntf),
  uci_wan_username = format("uci.network.interface.@%s.username", wanIntf),
  uci_wan_password = format("uci.network.interface.@%s.password", wanIntf),
  uci_wan_masq = "uci.firewall.zone."..zonenum..".masq"
}

local mapPPPstats = {
  discardR = "sys.class.net.@pppoe-wan.statistics.rx_dropped",
  discardS = "sys.class.net.@pppoe-wan.statistics.tx_dropped",
  broadcastR = "sys.class.net.@pppoe-wan.statistics.rx_broadcast",
  broadcastS = "sys.class.net.@pppoe-wan.statistics.tx_broadcast",
  multicastR = "sys.class.net.@pppoe-wan.statistics.multicast",
  multicastS = "sys.class.net.@pppoe-wan.statistics.txpckt",
  packetsR = "sys.class.net.@pppoe-wan.statistics.rx_packets",
  packetsS = "sys.class.net.@pppoe-wan.statistics.tx_packets",
  errorsR = "sys.class.net.@pppoe-wan.statistics.rx_errors",
  errorsS = "sys.class.net.@pppoe-wan.statistics.tx_errors",
  bytesR = "sys.class.net.@pppoe-wan.statistics.rx_bytes",
  bytesS = "sys.class.net.@pppoe-wan.statistics.tx_bytes",
  unicastR = "sys.class.net.@pppoe-wan.statistics.rx_unicast",
  unicastS = "sys.class.net.@pppoe-wan.statistics.tx_unicast",
  unknownR = "sys.class.net.@pppoe-wan.statistics.rxerr"
}

content_helper.getExactContent(mapPPPstats)

-- Shortcuts to validation helpers to make lines shorter
local validateConditional = post_helper.getConditionalValidation
local validateBoolean = post_helper.validateBoolean
local validateNonEmpty = post_helper.validateNonEmptyString
local validatePassword = post_helper.getValidationPassword
local validateOptional = post_helper.getOptionalValidation

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
  uci_wan_username = validateConditional(isWanEnabled, post_helper.validateUsername, validateOptional(post_helper.validateUsername)),
  uci_wan_password = validateConditional(isWanEnabled, validatePassword(validateNonEmpty), validatePassword()),
  uci_wan_masq = validateNat
}


local content_uci = {
  wan_proto = format("uci.network.interface.@%s.proto", wanIntf),
  wan_domain = format("uci.network.interface.@%s.domain" , wanIntf)
}
content_helper.getExactContent(content_uci)

local content_rpc = {
  wan_ppp_ll_intf = format("rpc.network.interface.@%s.ppp.ll_intf", mode_selected),
  ipaddr = format("rpc.network.interface.@%s.ipaddr", mode_selected),
  nexthop = format("rpc.network.interface.@%s.nexthop", mode_selected),
  dns_wan = format("rpc.network.interface.@%s.dnsservers", mode_selected),
  ipv6_gua = format("rpc.network.interface.@%s.ipv6uniqueglobaladdr", mode_selected),
  dns_loopback = "rpc.network.interface.@loopback.dnsservers", -- Added to include static dns servers configured on loopback interface (for TI custo)
}

for i,v in ipairs(proxy.getPN("rpc.network.interface.", true)) do
  local intf = match(v.path, "rpc%.network%.interface%.@([^%.]+)%.")
  if intf then
    content_rpc.ip6addr = "rpc.network.interface.@"..intf..".ip6addr"
    content_rpc.ip6prefix = "rpc.network.interface.@"..intf..".ip6prefix"
    if intf ~= wanIntf then
      content_rpc.dnsv6 = "rpc.network.interface.@"..intf..".dnsservers"
    elseif intf == wan6Intf then
      break
    end
  end
end

content_helper.getExactContent(content_rpc)
local wan_atm_uci_path = format("uci.xtm.atmdevice.@%s.", content_rpc["wan_ppp_ll_intf"])
local wan_ppp_over_atm = proxy.get(wan_atm_uci_path) ~= nil

if wan_ppp_over_atm then
    mapParams["wan_atm_vpi"] = wan_atm_uci_path.."vpi"
    mapParams["wan_atm_vci"] = wan_atm_uci_path.."vci"
    mapValid["wan_atm_vpi"] = post_helper.getValidateWholeNumber
    mapValid["wan_atm_vci"] = post_helper.getValidateWholeNumber
end
local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
-- End POST process

content_rpc.dns = content_helper.getMergedList(content_rpc.dns_wan, content_rpc.dns_loopback)

local content_uci_xtm
if wan_ppp_over_atm then
  content_uci_xtm = {
    wan_atm_enc = wan_atm_uci_path.."enc",
    wan_atm_ulp = wan_atm_uci_path.."ulp",
    wan_vpi = format("uci.network.interface.@wan.vpi", wanIntf),
    wan_vci = format("uci.network.interface.@wan.vci" , wanIntf),
  }
  content_helper.getExactContent(content_uci_xtm)

  local params = {}
  local setting = false
  if content_uci_xtm.wan_vpi ~= "" then
    params["uci.network.interface.@wan.vpi"] = ""
    setting = true
  end
  if content_uci_xtm.wan_vci ~= "" then
    params["uci.network.interface.@wan.vci"] = ""
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

if content_uci["wan_domain"] ~= "" then
  content["uci_wan_username"] = match(content["uci_wan_username"], "[^@]*")
end

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SAVE" and not next(helpmsg) then
  local wan_intf =  proxy.get("uci.network.interface.@wan.ifname")
  wan_intf = wan_intf and wan_intf[1] and wan_intf[1].value
  local del_path = wan_intf and "uci.xtm.atmdevice.@".. wan_intf.."."
  local atm_content_get = wan_intf and proxy.get(del_path) or {}
  local succ,err = wan_intf and proxy.del(untaint(del_path))
  local atm_content = {}
  for i,v in ipairs(atm_content_get) do
     atm_content[v.param] = v.value
  end
  local args = ngx.req.get_post_args()
   local paramMapForNAT = {
          vpi = "vpi",
          vci = "vci",
          path = "path",
          ulp = "ulp",
          td = "td",
          priority = "priority",
          enc = "enc",
          weight = "weight"
        }
  atm_content["vci"] = args.wan_atm_vci and untaint(args.wan_atm_vci)
  atm_content["vpi"] = args.wan_atm_vpi and untaint(args.wan_atm_vpi)
  if atm_content["vci"] and atm_content["vpi"] then
    content_helper.addNewObject(xtmPath, atm_content, paramMapForNAT, nil, "atm_"..atm_content.vpi.."_"..atm_content.vci)
    proxy.set("uci.network.interface.@wan.ifname", "atm_"..atm_content.vpi.."_"..atm_content.vci)
    proxy.apply()
  end
end
ngx.print(ui_helper.createHeader(T"Internet Access",true, true))
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
      desc =  T"IPv6 Configuration",
      target = "modals/internet-ex-modal.lp"
    },
  }
  ngx.print(ui_helper.createModalTabs(tabs))
  ngx.print('\
');  if session:hasAccess("/modals/internet-"..mode_current.."-routed-configuration.lp") then
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
<form class = "form-horizontal" method = "post" action = "modals/internet-pppoe-routed-configuration.lp">\
<fieldset>\
');
  ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<legend>');  ngx.print( T"PPP connection" ); ngx.print('</legend>\
\
');
  local html = {}
  -- Switch PPP on/off
  html[#html + 1] = ui_helper.createSwitch(T"Enabled", "uci_wan_auto", content.uci_wan_auto)
  html[#html + 1] = ui_helper.createSwitch(T"NAT", "uci_wan_masq", content.uci_wan_masq)
  -- PPP username
  local class_username = {
    group = {
      class = "advanced hide"
    },
    input = {
      maxlength= "128",
      class = "span6"
    }
  }
  if post_helper.variantHasAccess(variantHelper, "Userpass", role) then
    html[#html + 1] = "<div class='control-group advanced hide'><label class='control-label'>" ..  T"Username" .. "</label><div class='controls'>"
    html[#html + 1] = ui_helper.createSimpleInputText("uci_wan_username", content["uci_wan_username"], class_username, helpmsg["uci_wan_username"])
    if content_uci["wan_domain"] ~= "" then
      html[#html + 1] = " @ " .. content_uci["wan_domain"]
    end
    html[#html + 1] = "</div></div>"

    -- PPP password
    html[#html + 1] = ui_helper.createInputPassword( T"Password", "uci_wan_password", content["uci_wan_password"], class_username, helpmsg["uci_wan_password"])
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
  if wan_ppp_over_atm then
    local advanced = {
      group = {
        class = "advanced hide"
      }
    }
    local vp_vc = format("%s / %s", content["wan_atm_vpi"], content["wan_atm_vci"])
    if post_helper.variantHasAccess(variantHelper, "Userpass", role) then
       html[#html + 1] = ui_helper.createInputText( T"ATM VP", "wan_atm_vpi", content["wan_atm_vpi"], advanced )
       html[#html + 1] = ui_helper.createInputText( T"ATM VC", "wan_atm_vci", content["wan_atm_vci"], advanced )
    else
       html[#html + 1] = ui_helper.createLabel( T"ATM VP / VC", vp_vc, advanced)
    end
    html[#html + 1] = ui_helper.createLabel(T"Encapsulation", upper(content_uci_xtm["wan_atm_enc"]), advanced)
  end

  ngx.print(html)
  ngx.print('\
\
</fieldset>\
\
<fieldset class="advanced hide">\
<legend>');  ngx.print(  T"PPP statistics" ); ngx.print('</legend>\
<div id="internetView">\
');
  local iconUp = "<i class=\"icon-upload icon-large gray\"></i> "
  local iconDown = " <i class=\"icon-download icon-large gray\"></i> "

  local html = {}

  html[#html + 1] = ui_helper.createLabel(
    T"Discard Packets",
    format("%s %s Pkd %s %s Pkd", iconUp, mapPPPstats.discardS, iconDown, mapPPPstats.discardR)
  )

  html[#html + 1] = ui_helper.createLabel(
    T"Broadcast Packets",
    format("%s %s Pkd %s %s Pkd", iconUp, mapPPPstats.broadcastS, iconDown, mapPPPstats.broadcastR)
  )

  html[#html + 1] = ui_helper.createLabel(
    T"Multicast Packets",
    format("%s %s Pkd %s %s Pkd", iconUp, mapPPPstats.multicastS, iconDown, mapPPPstats.multicastR)
  )

  html[#html + 1] = ui_helper.createLabel(
    T"Unicast Packets",
    format("%s %s Pkd %s %s Pkd", iconUp, mapPPPstats.unicastS, iconDown, mapPPPstats.unicastR)
  )

  html[#html + 1] = ui_helper.createLabel(
    T"Packets",
    format("%s %s Pkd %s %s Pkd", iconUp, mapPPPstats.packetsS, iconDown, mapPPPstats.packetsR)
  )

  html[#html + 1] = ui_helper.createLabel(
    T"Errors",
    format("%s %s Pkd %s %s Pkd", iconUp, mapPPPstats.errorsS, iconDown, mapPPPstats.errorsR)
  )

  html[#html + 1] = ui_helper.createLabel(
    T"Bytes",
    format("%s %s Bytes %s %s Bytes", iconUp, mapPPPstats.bytesS, iconDown, mapPPPstats.bytesR)
  )

  html[#html + 1] = ui_helper.createLabel(
    T"Unknown Proto Packets",
    format("%s %s Pkd", iconDown, mapPPPstats.unknownR)
  )

  ngx.print(html)
  ngx.print('\
</div>\
</fieldset>\
</form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
');
