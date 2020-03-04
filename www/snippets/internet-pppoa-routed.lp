--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local format, untaint = string.format, string.untaint

local cvtBoolean = {
    ["0"] = "1",
    ["1"] = "0",
}

local mapParams = {
  uci_wan_auto = "uci.network.interface.@wan.auto",
  uci_wan_username = "uci.network.interface.@wan.username",
  uci_wan_password = "uci.network.interface.@wan.password",
  uci_wan_peerdns = "uci.network.interface.@wan.peerdns",
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

local function isWanEnabled(value, object, key)
  return object["uci_wan_auto"] ~= "0"
end

local function validPeerdns(value, object, key)
    local valid, helpmsg = vB(value, object, key)
    if (valid ~= true) then
        return valid,  helpmsg
    end
    object[key] = cvtBoolean[untaint(value)]

    return true
end

-- Validation allows empty values if wan access disabled but will stil check for validity if the parameter is set
-- if wan is enabled then it checks for validaty anyway
local mapValid = {
  uci_wan_auto = vB,
  uci_wan_username = gCV(isWanEnabled, validateUsername, gOV(validateUsername)),
  uci_wan_password = gCV(isWanEnabled, gVP(vNES), gVP()),
  uci_wan_peerdns = validPeerdns,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
-- End POST process

local string = string

local content_uci = {
  wan_proto = "uci.network.interface.@wan.proto",
  wan_domain = "uci.network.interface.@wan.domain",
  wan_sensing_enable = "uci.wansensing.global.enable",
}
content_helper.getExactContent(content_uci)

local content_rpc = {
  wan_ppp_state = "rpc.network.interface.@wan.ppp.state",
  wan_ppp_error = "rpc.network.interface.@wan.ppp.error",
  ipaddr = "rpc.network.interface.@wan.ipaddr",
  nexthop = "rpc.network.interface.@wan.nexthop",
  dns = "rpc.network.interface.@wan.dnsservers",
}

for i,v in ipairs(proxy.getPN("rpc.network.interface.", true)) do
  local intf = string.match(v.path, "rpc%.network%.interface%.@([^%.]+)%.")
  if intf then
    if intf == "6rd" then
      content_rpc.ip6addr = "rpc.network.interface.@6rd.ip6addr"
    elseif intf == "wan6" then
      content_rpc.ip6addr = "rpc.network.interface.@wan6.ip6addr"
    end
  end
end

content_helper.getExactContent(content_rpc)

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
  ppp_status = format("%s", content_rpc.wan_ppp_state) -- untaint
  if ppp_status == "" or ppp_status == "authenticating" then
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

---
--- DNS CONFIGURATION TABLE ITEMS
---
local dnsColumns = {
    {
       header = "DNS IP Address",
       name   = "wanDnsParam",
       param  = "value",
       type   = "text",
       attr   = { input = { class="span2", maxlength="15" } },
    },
}

local dnsOptions = {
    tableid    = "dnsserver",
    basepath   = "uci.network.interface.@wan.dns.@.",
    createMsg  = T"Add New DNS",
}

local dnsValid = {
    wanDnsParam = post_helper.advancedIPValidation,
}

local dnsData, dnsHelpMsg = post_helper.handleTableQuery(dnsColumns, dnsOptions, nil, nil, dnsValid)
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
if content_rpc["ip6addr"] and content_rpc["ip6addr"]:len() > 0 then
  html[#html+1] = ui_helper.createLabel(T"IPv6 address", content_rpc["ip6addr"])
end
  html[#html+1] = ui_helper.createLabel(T"Gateway", content_rpc["nexthop"])
  html[#html+1] = ui_helper.createLabel(T"DNS servers", content_rpc["dns"])

  ngx.print(html)
  ngx.print('\
</fieldset>\
<fieldset>\
    ');  
        if(content_uci["wan_sensing_enable"] == '0') then
          local html = {}
          html[#html + 1] = string.format([[<legend>%s</legend>]], T"Domain Name Server Configuration")
          local peerdns = untaint(content["uci_wan_peerdns"])
          html[#html+1] = ui_helper.createSwitch(T"Enabled", "uci_wan_peerdns", cvtBoolean[peerdns])
          if peerdns == "0" then
            html[#html+1] = ui_helper.createTable(dnsColumns, dnsData, dnsOptions, nil, dnsHelpMsg)
          end
          ngx.print(html)
	end
      ngx.print('\
</fieldset>\
'); 