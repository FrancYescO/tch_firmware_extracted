<%
-- Enable localization
local format = string.format
gettext.textdomain('webui-core')
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local tprint = require("tch.tableprint")
-- Process POST query
local post_helper = require("web.post_helper")

local untaint_mt = require("web.taint").untaint_mt

local mapParams = {
    uci_wan_auto = "uci.network.interface.@wan.auto",
    uci_wan_username = "uci.network.interface.@wan.username",
    uci_wan_password = "uci.network.interface.@wan.password",
}

-- Listbox that shows the supported PPP modes
local routed_mode = {
      { "pppoe", T"PPPoE" },
      { "dhcp", T"DHCP" },
      { "static", T"Static" }, 
      { "bridge", T"Bridge" },  
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


local function validateVLAN (value, postdata)
  local err,msg = vNES(value)
  if not err then
    return err,msg
  end
  --ngx.print('<script>alert("',value,'");</script>')
  local valuenum = tonumber(value) 
  
  if valuenum then
    if valuenum >= 2 and valuenum <= 4094 then
        return true
    end    
  end
  return nil, T"Invalid VLAN ID - should be between 2 and 4096"
  
end

local function isWanEnabled(value, object, key)
    return object["uci_wan_auto"] ~= "0"
end

-- Validation allows empty values if wan access disabled but will stil check for validity if the parameter is set
-- if wan is enabled then it checks for validaty anyway
local mapValid = {
    uci_wan_auto = vB,
    uci_wan_username = gVIPIL(gCV(isWanEnabled, validateUsername, gOV(validateUsername)), "uci_wan_proto", {"pppoe","pppoa"}),
    uci_wan_password = gVIPIL(gCV(isWanEnabled, gVP(vNES), gVP()), "uci_wan_proto", {"pppoe","pppoa"}),    
    uci_wan_vlan     = gVIPIL(gCV(isWanEnabled, validateVLAN, gOV(validateVLAN)), "uci_wan_vlan_enabled", {"1"}),
    uci_wan_ipaddr   = gVIPIL(gCV(isWanEnabled, vSII), "uci_wan_proto", {"static"}),
    uci_wan_subnet   = gVIPIL(gCV(isWanEnabled, vSII), "uci_wan_proto", {"static"}),
    uci_wan_gateway  = gVIPIL(gCV(isWanEnabled, vSII), "uci_wan_proto", {"static"}),
}
local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

if ngx.var.request_method == "POST" then
      proxy.apply()  
end
-- End POST process

local string = string

local content_uci = {
  wan_proto = "uci.network.interface.@wan.proto",
  wan_domain = "uci.network.interface.@wan.domain",
}
content_helper.getExactContent(content_uci)

local content_rpc = {
    wan_ppp_state    = "rpc.network.interface.@wan.ppp.state",
    wan_ppp_error    = "rpc.network.interface.@wan.ppp.error",
    wan_ppp_ll_intf  = "rpc.network.interface.@wan.ppp.ll_intf",
    ipaddr           = "rpc.network.interface.@wan.ipaddr",
    nexthop          = "rpc.network.interface.@wan.nexthop",
    ip6addr          = "rpc.network.interface.@wan6.ip6addr",
}
content_helper.getExactContent(content_rpc)

local display_DNS = ""
local uci_dnsservers = {}
for i,v in ipairs(proxy.getPN("uci.network.interface.@wan.dns.", true)) do
   local thispath = format("%svalue",v.path)
   uci_dnsservers[#uci_dnsservers+1] = format("%s", proxy.get(thispath)[1].value)
   display_DNS = format("%s%s ",display_DNS,uci_dnsservers[i])
    
end




wan_ppp_over_atm = 1
local content_uci_xtm
if wan_ppp_over_atm then
  -- need to untaint the string otherwise getExactContent will get lost
  local wan_atm_uci_path = string.format("uci.xtm.atmdevice.@%s.", content_rpc["wan_ppp_ll_intf"])
  content_uci_xtm = {
    wan_atm_vpi = wan_atm_uci_path.."vpi",
    wan_atm_vci = wan_atm_uci_path.."vci",
    wan_atm_enc = wan_atm_uci_path.."enc",
  }
  content_helper.getExactContent(content_uci_xtm)
end

if content_uci["wan_domain"] ~= "" then
  content["uci_wan_username"] = string.match(content["uci_wan_username"], "[^@]*")
end

local ppp_state_map = {
    disabled = T"Disabled",
    disconnecting = T"Disconnecting",
    connected = T"Connected",
    connecting = T"Connecting",
    disconnected = T"Disconnected",
    error = T"Error",
    network = T"Network Error",
    AUTH_TOPEER_FAILED = T"Authentication failed",
    NEGOTIATION_FAILED = T"Negotiation failed",
}
setmetatable(ppp_state_map, untaint_mt)

local ppp_light_map = {
    disabled = "off",
    disconnected = "red",
    disconnecting = "orange",
    connecting = "orange",
    connected = "green",
    error = "red",
    network = "red",
    AUTH_TOPEER_FAILED = "red",
    NEGOTIATION_FAILED = "red",
}
setmetatable(ppp_light_map, untaint_mt)

local ppp_status = ""
if content.uci_wan_auto ~= "0" then
  -- WAN enabled
  content.uci_wan_auto = "1"
  ppp_status = string.format("%s", content_rpc.wan_ppp_state) -- untaint
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


-- Figure out interface state DHCP
local cs = {
    ipaddr = "rpc.network.interface.@wan.ipaddr",
    nexthop = "rpc.network.interface.@wan.nexthop",
    ip6addr = "rpc.network.interface.@wan6.ip6addr",
}

content_helper.getExactContent(cs)

local dhcp_state = "connecting"
local dhcp_state_map = {
    disabled = T"Disabled",
    connected = T"Connected",
    connecting = T"Connecting",
}

local dhcp_light_map = {
  disabled = "off",
  connecting = "orange",
  connected = "green",
}

if content["uci_wan_auto"] ~= "0" then
    content["uci_wan_auto"] = "1"
    if cs["ipaddr"]:len() > 0 then
        dhcp_state = "connected"
    else
        dhcp_state = "connecting"
    end
else
    dhcp_state = "disabled"
end

%>

<fieldset>
<%
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
%>
<legend><%= T"Connection Configuration - Auto (PPP)" %></legend>

<%
   
    local html = {}
   html[#html + 1] = ui_helper.createLight(T"Status", nil, ppp_state_map[ppp_status], { light = { class = ppp_light_map[ppp_status] } })
    -- Label that shows PPP status
    if content["uci_wan_proto"] == "pppoa" or content["uci_wan_proto"] == "pppoe" then
      html[#html + 1] = ui_helper.createLight(T"Status", nil, ppp_state_map[ppp_status], { light = { class = ppp_light_map[ppp_status] } })
    elseif content["uci_wan_proto"] == "dhcp" then
    -- Or DHCP
      html[#html + 1] = ui_helper.createLight(T"Status", nil, dhcp_state_map[dhcp_state], { light = { class = dhcp_light_map[dhcp_state] } })
    end

   local security_warning = {
        alert = {
            class = "alert-warning monitor-uci_wan_proto monitor-pppoe"
        },
    }
    html[#html + 1] = ui_helper.createAlertBlock(T"Please complete the user details below", security_warning)

  
    -- PPP username
    local class_username = {
      group = {
            class ="monitor-uci_wan_proto monitor-pppoe monitor-pppoa",
        },
        input = {
        maxlength= "128",
        class = "span6",
      }
    }
    


    
    html[#html + 1] = "<div class='control-group'><label class='control-label monitor-uci_wan_proto monitor-pppoe monitor-pppoa'>" .. T"Username" .. "</label><div class='controls monitor-uci_wan_proto monitor-pppoe monitor-pppoa'>"
    html[#html + 1] = ui_helper.createSimpleInputText("uci_wan_username", content["uci_wan_username"], class_username, helpmsg["uci_wan_username"])
    if content_uci["wan_domain"] ~= "" then
      html[#html + 1] = " @ " .. content_uci["wan_domain"]
    end
    html[#html + 1] = "</div></div>"
    
    


    -- PPP password
    local class_password = class_username
    html[#html + 1] = ui_helper.createInputPassword(T"Password", "uci_wan_password", content["uci_wan_password"], class_username , helpmsg["uci_wan_password"])


    ngx.print(html)
%>

</fieldset>
