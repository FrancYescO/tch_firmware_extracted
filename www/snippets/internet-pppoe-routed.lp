--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local format, match, find, upper = string.format, string.match, string.find, string.upper
-- Process POST query
local post_helper = require("web.post_helper")
local wanIntf = post_helper.getActiveInterface()
local firewall_zone = proxy.get("uci.firewall.zone.")
local firewall_zone_path = content_helper.convertResultToObject("uci.firewall.zone.",firewall_zone)
local zonenum = ""
for _, v in ipairs(firewall_zone_path) do
  if (v["name"] == "wan") then
    zonenum = v["paramindex"]
    break
  end
end
local firewall_forwarding = proxy.get("uci.firewall.forwarding.")
local firewall_forwarding_path = content_helper.convertResultToObject("uci.firewall.forwarding.",firewall_forwarding)
local forwdnum = ""
for _, v in ipairs(firewall_forwarding_path) do
  if (v["src"] == "wan" and v["dest"] == "lan") then
    forwdnum = v["paramindex"]
    break
  end
end

local mapParams = {
  uci_wan_auto = format("uci.network.interface.@%s.auto", wanIntf),
  uci_wan_username = format("uci.network.interface.@%s.username", wanIntf),
  uci_wan_password = format("uci.network.interface.@%s.password", wanIntf),
  uci_wan_masq = "uci.firewall.zone."..zonenum..".masq",
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
  unknownR = "sys.class.net.@pppoe-wan.statistics.rxerr",
}

content_helper.getExactContent(mapPPPstats)

-- Shortcuts to validation helpers to make lines shorter
local gVIPIL = post_helper.getValidationIfPropInList
local gCV = post_helper.getConditionalValidation
local gVIES = post_helper.getValidateInEnumSelect
local vB = post_helper.validateBoolean
local vNES = post_helper.validateNonEmptyString
local vSII = post_helper.validateStringIsIP()
local vSIP = post_helper.validateStringIsPort
local gVP = post_helper.getValidationPassword
local gOV = post_helper.getOptionalValidation

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
  uci_wan_auto = vB,
  uci_wan_username = gCV(isWanEnabled, post_helper.validateUsername, gOV(post_helper.validateUsername)),
  uci_wan_password = gCV(isWanEnabled, gVP(vNES), gVP()),
  uci_wan_masq = validateNat,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
-- End POST process

local string = string

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
  ipv6_gua = "rpc.network.interface.@wan6.ipv6uniqueglobaladdr",
  dns_loopback = "rpc.network.interface.@loopback.dnsservers", -- Added to include static dns servers configured on loopback interface (for TI custo)
}

for i,v in ipairs(proxy.getPN("rpc.network.interface.", true)) do
  local intf = match(v.path, "rpc%.network%.interface%.@([^%.]+)%.")
  if intf then
    if intf == "6rd" then
      content_rpc.ip6addr = "rpc.network.interface.@6rd.ip6addr"
      content_rpc.ip6prefix = "rpc.network.interface.@6rd.ip6prefix"
      content_rpc.dnsv6 = "rpc.network.interface.@6rd.dnsservers"
    elseif intf == "wan6" then
      content_rpc.ip6addr = "rpc.network.interface.@wan6.ip6addr"
      content_rpc.ip6prefix = "rpc.network.interface.@wan6.ip6prefix"
      content_rpc.dnsv6 = "rpc.network.interface.@wan6.dnsservers"
      break
    elseif intf == wanIntf then
      content_rpc.ip6addr = format("rpc.network.interface.@%s.ip6addr", wanIntf)
      content_rpc.ip6prefix = format("rpc.network.interface.@%s.ip6prefix", wanIntf)
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
    wan_vpi = format("uci.network.interface.@%s.vpi", wanIntf),
    wan_vci = format("uci.network.interface.@%s.vci", wanIntf),
  }
  content_helper.getExactContent(content_uci_xtm)

  local params = {}
  local setting = false
  if content_uci_xtm.wan_vpi ~= "" then
    params[format("uci.network.interface.@%s.vpi", wanIntf)] = ""
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

if content_uci["wan_domain"] ~= "" then
  content["uci_wan_username"] = match(content["uci_wan_username"], "[^@]*")
end

local ppp_state_map = {
  disabled = T"Disabled",
  disconnecting = T"Disconnecting",
  connected = T"Connected",
  connecting = T"Connecting",
  disconnected = T"Disconnected",
  error = T"Error",
  AUTH_TOPEER_FAILED = T"Authentication failed",
  NEGOTIATION_FAILED = T"Negotiation failed",
}

local untaint_mt = require("web.taint").untaint_mt
setmetatable(ppp_state_map, untaint_mt)

local ppp_light_map = {
  disabled = "off",
  disconnected = "red",
  disconnecting = "orange",
  connecting = "orange",
  connected = "green",
  error = "red",
  AUTH_TOPEER_FAILED = "red",
  NEGOTIATION_FAILED = "red",
}

setmetatable(ppp_light_map, untaint_mt)

local ppp_status
if content.uci_wan_auto ~= "0" then
  -- WAN enabled
  content.uci_wan_auto = "1"
  ppp_status = format("%s", content_rpc.wan_ppp_state) -- untaint
  if ppp_status == "" or ppp_status == "authenticating" or ppp_status == "networking" then
    ppp_status = "connecting"
  end

  if not (content_rpc.wan_ppp_error == "" or content_rpc.wan_ppp_error == "USER_REQUEST") then
    if ppp_state_map[content_rpc.wan_ppp_error] then
      ppp_status = content_rpc.wan_ppp_error
    else
      ppp_status = "error"
    end
  end
else
  -- WAN disabled
  ppp_status = "disabled"
end

  ngx.print('\
\
<fieldset>\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<legend>');  ngx.print( T"PPP connection" ); ngx.print('</legend>\
\
');  
    local html = {}
    -- Label that shows PPP status
    html[#html + 1] = ui_helper.createLight(T"Status", nil, ppp_state_map[ppp_status], { light = { class = ppp_light_map[ppp_status] } })
    -- Switch PPP on/off
    html[#html + 1] = ui_helper.createSwitch(T"Enabled", "uci_wan_auto", content.uci_wan_auto)
    html[#html + 1] = ui_helper.createSwitch(T"NAT", "uci_wan_masq", content.uci_wan_masq)
    -- PPP username
    local class_username = {
      input = {
        maxlength= "128",
        class = "span6",
      }
    }
    html[#html + 1] = "<div class='control-group'><label class='control-label'>" .. T"Username" .. "</label><div class='controls'>"
    html[#html + 1] = ui_helper.createSimpleInputText("uci_wan_username", content["uci_wan_username"], class_username, helpmsg["uci_wan_username"])
    if content_uci["wan_domain"] ~= "" then
      html[#html + 1] = " @ " .. content_uci["wan_domain"]
    end
    html[#html + 1] = "</div></div>"

    -- PPP password
    local class_password = class_username
    html[#html + 1] = ui_helper.createInputPassword(T"Password", "uci_wan_password", content["uci_wan_password"], class_username, helpmsg["uci_wan_password"])

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
          class = "advanced hide",
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
<fieldset>\
<legend>');  ngx.print( T"PPP statistics" ); ngx.print('</legend>\
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
            format("%s %s Pkd %s %s Pkd", iconUp, mapPPPstats.bytesS, iconDown, mapPPPstats.bytesR)
        )

        html[#html + 1] = ui_helper.createLabel(
            T"Unknown Proto Packets",
            format("%s %s Pkd", iconDown, mapPPPstats.unknownR)
        )

        ngx.print(html)
  ngx.print('\
\
</fieldset>\
');
