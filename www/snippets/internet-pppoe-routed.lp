--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local format, untaint = string.format, string.untaint
local session = ngx.ctx.session
local interface_name = session:retrieve("network_interface_name") or "wan"
local interface_6rd_name = "6rd" .. interface_name
local interface_wan6_name = interface_name .. "6"
local uci_wan_path = format("uci.network.interface.@%s.", interface_name)
local rpc_wan_path = format("rpc.network.interface.@%s.", interface_name)
local rpc_6rd_path = format("rpc.network.interface.@%s.", interface_6rd_name)
local rpc_wan6_path = format("uci.network.interface.@%s.", interface_wan6_name)
local uci_ppp_path = "uci.network.interface.@ppp."
local uci_pppv_path = "uci.network.interface.@pppv."

local content_params = {
    variant = "uci.env.var.iinet_variant",
}
content_helper.getExactContent(content_params)
if content_params.variant == "novas" then
    interface_name = "wan"
end

local cvtBoolean = {
    ["0"] = "1",
    ["1"] = "0",
}

local mapParams = {
  uci_wan_auto = uci_wan_path .. "auto",
  uci_wan_username = uci_wan_path .. "username",
  uci_wan_password = uci_wan_path .. "password",
  uci_wan_peerdns = uci_wan_path .. "peerdns",
  uci_ppp_username = uci_ppp_path .. "username",
  uci_ppp_password = uci_ppp_path .. "password",
  uci_pppv_username = uci_pppv_path .. "username",
  uci_pppv_password = uci_pppv_path .. "password",
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
    wan_domain = uci_wan_path .. "domain",
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
    if value == "" then
        value = "0"
        object[key] = "0"
    end
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
  uci_wan_username = function(value, object, key)
    local ok, msg = validateUsername(value, object, key)
    if ok then
      object["uci_ppp_username"] = object["uci_wan_username"]
      object["uci_pppv_username"] = object["uci_wan_username"]
      return true
    else
      return ok, msg
    end
  end,
  uci_wan_password = function(value, object, key)
    local validate = gVP(vNES)
    local ok, msg = validate(value, object, key)
    if ok then
      object["uci_ppp_password"] = object["uci_wan_password"]
      object["uci_pppv_password"] = object["uci_wan_password"]
      return true
    else
      return ok, msg
    end
  end,
  uci_wan_peerdns = validPeerdns,
  uci_ppp_username = function(value,object)
    return true
  end,
  uci_ppp_password = function(value,object)
    return true
  end,
  uci_pppv_username = function(value,object)
    return true
  end,
  uci_pppv_password = function(value,object)
    return true
  end,
}

local content_uci = {
  wan_proto = uci_wan_path .. "proto",
  wan_domain = uci_wan_path .. "domain",
}
content_helper.getExactContent(content_uci)

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
-- End POST process

local string = string

local content_rpc = {
  wan_ppp_state = rpc_wan_path .. "ppp.state",
  wan_ppp_error = rpc_wan_path .. "ppp.error",
  ipaddr = rpc_wan_path .. "ipaddr",
  nexthop = rpc_wan_path .. "nexthop",
  dns = rpc_wan_path .. "dnsservers",
}

for i,v in ipairs(proxy.getPN("rpc.network.interface.", true)) do
  local intf = string.match(v.path, "rpc%.network%.interface%.@([^%.]+)%.")
  if intf then
    if intf == interface_6rd_name then
      content_rpc.ip6addr = rpc_6rd_path .. "ip6addr"
    elseif intf == interface_wan6_name then
      content_rpc.ip6addr = rpc_wan6_path .. "ip6addr"
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
    basepath   = uci_wan_path .. "dns.@.",
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
    local attr
    local uci_wans_enable = proxy.get("uci.wansensing.global.enable")[1].value
    if uci_wans_enable == "1" then
        attr = { group = { class = "hide" } }
    end
    html[#html + 1] = ui_helper.createSwitch(T"Enabled", "uci_wan_auto", content.uci_wan_auto, attr)

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


    -- ATM VP/VC
    if wan_ppp_over_atm then
      local advanced = {
        group = {
          class = "advanced hide",
        }
      }
      local vp_vc = format("%s / %s", content_uci_xtm["wan_atm_vpi"], content_uci_xtm["wan_atm_vci"])
      html[#html + 1] = ui_helper.createLabel(T"ATM VP / VC", vp_vc, advanced)
      html[#html + 1] = ui_helper.createLabel(T"Encapsulation", string.upper(content_uci_xtm["wan_atm_enc"]), advanced)
    end

    ngx.print(html)
  ngx.print('\
</fieldset>\
<fieldset>\
    ');  
          local html = {}
          html[#html + 1] = string.format([[<legend>%s</legend>]], T"Domain Name Server Configuration")
          local peerdns = untaint(content["uci_wan_peerdns"])
          html[#html+1] = ui_helper.createSwitch(T"Enabled", "uci_wan_peerdns", cvtBoolean[peerdns])
          if peerdns == "0" then
            html[#html+1] = ui_helper.createTable(dnsColumns, dnsData, dnsOptions, nil, dnsHelpMsg)
          end

          ngx.print(html)
      ngx.print('\
</fieldset>\
'); 