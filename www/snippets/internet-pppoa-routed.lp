<%
-- NG-49023 GUI-Nat Settings not changeable
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")

-- Process POST query
local post_helper = require("web.post_helper")

local firewall_zone = "uci.firewall.zone."
local firewall_zone_path = content_helper.getMatchedContent(firewall_zone)
local zonenum = ""
for i, v in ipairs(firewall_zone_path) do
   local path = string.match(firewall_zone_path[i].path, "uci%.firewall%.zone%.([^%.]+)")
   if (v["name"] == "wan") then
	   zonenum = path
   end
end
local firewall_forwarding = "uci.firewall.forwarding."
local firewall_forwarding_path = content_helper.getMatchedContent(firewall_forwarding)
local forwdnum = ""
for i, v in ipairs(firewall_forwarding_path) do
   local path = string.match(firewall_forwarding_path[i].path, "uci%.firewall%.forwarding%.([^%.]+)")
   if (v["src"] == "wan" and v["dest"] == "lan") then
	   forwdnum = path
   end
end

local mapParams = {
  uci_wan_auto = "uci.network.interface.@wan.auto",
  uci_wan_username = "uci.network.interface.@wan.username",
  uci_wan_password = "uci.network.interface.@wan.password",
  uci_wan_masq = "uci.firewall.zone."..zonenum..".masq",
}

-- Shortcuts to validation helpers to make lines shorter
local gVIPIL = post_helper.getValidationIfPropInList
local gCV = post_helper.getConditionalValidation
local gVIES = post_helper.getValidateInEnumSelect
local vB = post_helper.validateBoolean
local vNES = post_helper.validateNonEmptyString
local vSII = post_helper.validateStringIsIP
local vSIP = post_helper.validateStringIsPort
local gVP = post_helper.getValidationPassword
local gOV = post_helper.getOptionalValidation

local function validateUsername (value, postdata)
  local err,msg = vNES(value)
  if not err then
    return err,msg
  end

  local content_uci = {
    wan_domain = "uci.network.interface.@wan.domain",
  }
  content_helper.getExactContent(content_uci)

  if content_uci["wan_domain"] ~= "" then
    if string.find(value, "@") then
      return nil, T"Invalid username, domain locked"
    end
    postdata["uci_wan_username"] = format('%s@%s', value, content_uci["wan_domain"])
  end

  return true
end

local function validateNat(value, object, key)
    local valid = post_helper.validateBoolean(value, object, key)
		if valid and value ~= proxy.get("uci.firewall.zone."..zonenum..".masq")[1].value then
		proxy.set("uci.firewall.zone."..zonenum..".conntrack", "1")
			if value == "1" then
				if forwdnum == "" then
					forwdnum = proxy.add("uci.firewall.forwarding.")
						proxy.set("uci.firewall.forwarding."..forwdnum..".src", "wan")
						proxy.set("uci.firewall.forwarding."..forwdnum..".dest", "lan")
						proxy.set("uci.firewall.forwarding."..forwdnum..".name", "for_w2l")
						proxy.set("uci.firewall.forwarding."..forwdnum..".enabled", "0")
				else
					proxy.set("uci.firewall.forwarding."..forwdnum..".enabled", "0")
				end
			else
				if forwdnum == "" then
					forwdnum = proxy.add("uci.firewall.forwarding.")
						proxy.set("uci.firewall.forwarding."..forwdnum..".src", "wan")
						proxy.set("uci.firewall.forwarding."..forwdnum..".dest", "lan")
						proxy.set("uci.firewall.forwarding."..forwdnum..".name", "for_w2l")
						proxy.set("uci.firewall.forwarding."..forwdnum..".enabled", "1")
				else
					proxy.set("uci.firewall.forwarding."..forwdnum..".enabled", "1")
				end
			end
			proxy.apply()
		end
    return valid, msg
end

local function isWanEnabled(value, object, key)
  return object["uci_wan_auto"] ~= "0"
end

-- Validation allows empty values if wan access disabled but will stil check for validity if the parameter is set
-- if wan is enabled then it checks for validaty anyway
local mapValid = {
  uci_wan_auto = vB,
  uci_wan_username = gCV(isWanEnabled, validateUsername, gOV(validateUsername)),
  uci_wan_password = gCV(isWanEnabled, gVP(vNES), gVP()),
  uci_wan_masq = validateNat,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
-- End POST process

local string = string

local content_uci = {
  wan_proto = "uci.network.interface.@wan.proto",
  wan_domain = "uci.network.interface.@wan.domain",
}
content_helper.getExactContent(content_uci)

local content_rpc = {
  wan_ppp_state = "rpc.network.interface.@wan.ppp.state",
  wan_ppp_error = "rpc.network.interface.@wan.ppp.error",
  wan_ppp_ll_intf = "rpc.network.interface.@wan.ppp.ll_intf",
  ipaddr = "rpc.network.interface.@wan.ipaddr",
  nexthop = "rpc.network.interface.@wan.nexthop",
  dns = "rpc.network.interface.@wan.dnsservers",
}

for i,v in ipairs(proxy.getPN("rpc.network.interface.", true)) do
  local intf = string.match(v.path, "rpc%.network%.interface%.@([^%.]+)%.")
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
    end
  end
end

content_helper.getExactContent(content_rpc)

-- need to untaint the string otherwise getExactContent will get lost
local wan_atm_uci_path = string.format("uci.xtm.atmdevice.@%s.", content_rpc["wan_ppp_ll_intf"])
local  content_uci_xtm = {
  wan_atm_vpi = wan_atm_uci_path.."vpi",
  wan_atm_vci = wan_atm_uci_path.."vci",
  wan_atm_enc = wan_atm_uci_path.."enc",
  wan_atm_ulp = wan_atm_uci_path.."ulp",
  wan_vpi = "uci.network.interface.@wan.vpi",
  wan_vci = "uci.network.interface.@wan.vci",
}
content_helper.getExactContent(content_uci_xtm)

local params = {}
local setting = false
if content_uci_xtm.wan_atm_vpi ~= content_uci_xtm.wan_vpi then
  params["uci.network.interface.@wan.vpi"] = content_uci_xtm.wan_atm_vpi
  setting = true
end
if content_uci_xtm.wan_atm_vci ~= content_uci_xtm.wan_vci then
  params["uci.network.interface.@wan.vci"] = content_uci_xtm.wan_atm_vci
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
  content["uci_wan_username"] = string.match(content["uci_wan_username"], "[^@]*")
end

local ppp_state_map = {
  disabled = T"disabled",
  disconnecting = T"disconnecting",
  connected = T"connected",
  connecting = T"connecting",
  disconnected = T"disconnected",
  error = T"error",
  AUTH_TOPEER_FAILED = T"authentication failed",
  NEGOTIATION_FAILED = T"negotiation failed",
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
  ppp_status = string.format("%s", content_rpc.wan_ppp_state) -- untaint
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

%>

<fieldset>
<%
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
%>
<legend><%= T"PPP connection" %></legend>

<%
  local html = {}
  -- Label that shows PPP status
  html[#html + 1] = ui_helper.createLight(T"Status", nil, ppp_state_map[ppp_status], { light = { class = ppp_light_map[ppp_status] } })
  -- Switch PPP on/off
  html[#html + 1] = ui_helper.createSwitch(T"Enabled", "uci_wan_auto", content.uci_wan_auto)
  html[#html + 1] = ui_helper.createSwitch(T"Nat", "uci_wan_masq", content.uci_wan_masq)

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

  html[#html+1] = ui_helper.createLabel(T"IP address", content_rpc["ipaddr"])
  html[#html+1] = ui_helper.createLabel(T"Gateway", content_rpc["nexthop"])
  html[#html+1] = ui_helper.createLabel(T"DNS servers", content_rpc["dns"])
  if content_rpc["ip6addr"] and content_rpc["ip6addr"]:len() > 0 then
        html[#html+1] = ui_helper.createLabel(T"IPv6 Address", content_rpc["ip6addr"])
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
      class = "advanced hide",
    }
  }
  local vp_vc = string.format("%s / %s", content_uci_xtm["wan_atm_vpi"], content_uci_xtm["wan_atm_vci"])
  html[#html + 1] = ui_helper.createLabel(T"ATM VP / VC", vp_vc, advanced)
  html[#html + 1] = ui_helper.createLabel(T"Encapsulation", string.upper(content_uci_xtm["wan_atm_enc"]), advanced)

  ngx.print(html)
%>

</fieldset>
