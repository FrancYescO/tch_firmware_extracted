<%
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")

local ajax_helper = require("web.ajax_helper")

local ajax_attr = {
    span = {
      class = "span4",
      ["data-ajaxrefresh"] = "5",
    }
}
local ajax_attr_light = {
    light = {
        class = ""
    },
    controls = {
        id = "wan_status",
        ["data-ajaxrefresh"] = "5",
    }
}


local format = string.format
local floor = math.floor

local function secondsToTime(uptime)
  if not uptime then return "" end
  local days =  floor(uptime / 86400)
  local hours =  floor(uptime / 3600) % 24
  local minutes = floor(uptime / 60) % 60
  local seconds = uptime % 60
  if (days > 0) then
    return format(T"%d days %d hours %d minutes %d seconds", days, hours, minutes, seconds)
  elseif (hours > 0) then
    return format(T"%d hours %d minutes %d seconds", hours, minutes, seconds)
  elseif (minutes > 0) then
    return format(T"%d minutes %d seconds", minutes, seconds)
  else
    return format(T"%d seconds", seconds)
  end
end


-- Process POST query
local post_helper = require("web.post_helper")

local mapParams = {
    uci_wan_auto = "uci.network.interface.@wan.auto",
    uci_wan_username = "uci.network.interface.@wan.username",
    uci_wan_password = "uci.network.interface.@wan.password",
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

-- Validation allows empty values if wan access disabled but will stil check for validity if the parameter is set
-- if wan is enabled then it checks for validaty anyway
local mapValid = {
    uci_wan_auto = vB,
    uci_wan_username = gCV(isWanEnabled, validateUsername, gOV(validateUsername)),
    uci_wan_password = gCV(isWanEnabled, gVP(vNES), gVP()),
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
-- End POST process

local string = string

local content_uci = {
  wan_proto = "uci.network.interface.@wan.proto",
  wan_domain = "uci.network.interface.@wan.domain",
  wan_username = "uci.network.interface.@wan.username",
  wan_password = "uci.network.interface.@wan.password",
}

content_helper.getExactContent(content_uci)

local content_rpc = {
    wan_ppp_state = "rpc.network.interface.@wan.ppp.state",
    wan_ppp_error = "rpc.network.interface.@wan.ppp.error",
    wan_ppp_ll_intf = "rpc.network.interface.@wan.ppp.ll_intf",
    ipaddr = "rpc.network.interface.@wan.ipaddr",
    nexthop = "rpc.network.interface.@wan.nexthop",
    dns = "rpc.network.interface.@wan.dnsservers",
    uptime = "rpc.network.interface.@wan.ppp.uptime",
   
}  

local ppptype = format("%s",proxy.get("uci.network.interface.@wan.proto")[1]["value"])

local content_sys = {
    mtu =  format("sys.class.net.@%s-wan.mtu",ppptype),
}

local pppmap = {
      pppoe = T"PPPoE",
      pppoa = T"PPPoA",
}
 

-- Non-configurable data
local cs = {
    wan_status = "rpc.network.interface.@wan.ppp.state",
    uptime = "rpc.network.interface.@wan.ppp.uptime",
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
	elseif intf == "wan" then
      	    content_rpc.ip6addr = "rpc.network.interface.@wan.ip6addr"
	    content_rpc.ip6prefix = "rpc.network.interface.@wan.ip6prefix"
            content_rpc.dnsv6 = "rpc.network.interface.@wan.dnsservers"
        end
    end
end

content_helper.getExactContent(content_rpc)
content_helper.getExactContent(content_sys)


local wan_ppp_over_atm = string.find(content_rpc["wan_ppp_ll_intf"], "atm_") == 1
local content_uci_xtm
if wan_ppp_over_atm then
  -- need to untaint the string otherwise getExactContent will get lost
  local wan_atm_uci_path = format("uci.xtm.atmdevice.@%s.", content_rpc["wan_ppp_ll_intf"])
  content_uci_xtm = {
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
  content["uci_wan_username"] = string.match(content["uci_wan_username"], "[^@]*")
end

local ppp_state_map = {
    disabled = T"Disabled",
    disconnecting = T"Disconnecting",
    connected = T"Connected",
    connecting = T"Connecting",
    disconnected = T"Disconnected",
    error = T"Error",
    networking = T"Network Error",
    noconf = T"PPP Not Configured",
    AUTH_TOPEER_FAILED = T"Authentication Failed",
    NEGOTIATION_FAILED = T"Negotiation Failed",
}

local untaint_mt = require("web.taint").untaint_mt 
setmetatable(ppp_state_map, untaint_mt) 

local ppp_light_map = {
    disabled = "off",
    noconf = "off",
    disconnected = "red",
    disconnecting = "orange",
    connecting = "orange",
    connected = "green",
    error = "red",
    networking = "red",
    AUTH_TOPEER_FAILED = "red",
    NEGOTIATION_FAILED = "red",
}

setmetatable(ppp_light_map, untaint_mt)

local ppp_status = ""
if content.uci_wan_auto ~= "0" then
  -- WAN enabled
  content.uci_wan_auto = "1"
  ppp_status = format("%s", content_rpc.wan_ppp_state) -- untaint
  if ppp_status == "" or ppp_status == "authenticating" then
    ppp_status = "connecting"
  end

  if not (content_rpc.wan_ppp_error == "" or content_rpc.wan_ppp_error == "USER_REQUEST") then
    if ppp_state_map[format("%s", content_rpc.wan_ppp_error)] then
        ppp_status = format("%s", content_rpc.wan_ppp_error)
    else
        if content_uci.wan_username ~= "" then
            ppp_status = "error"
        else
            ppp_status = "noconf"
        end
    end
  end
else
  -- WAN disabled
  ppp_status = "disabled"
end


ajax_helper.handleAjaxQuery(cs, function(c)
    local tp = require("tch.tableprint")
    -- this will add the HTML for the light
    c["uptime"] = secondsToTime(tonumber(content_rpc["uptime"]))
    c["mtu"] = content_sys["mtu"]

    c["ipaddr"] = content_rpc["ipaddr"]
    c["ip6addr"] = content_rpc["ip6addr"]
    c["ip6prefix"] = content_rpc["ip6prefix"]
    c["nexthop"] = content_rpc["nexthop"]
    c["dns"] = content_rpc["dns"]
    c["dnsv6"] = content_rpc["dnsv6"]
    ajax_attr_light.light.class = ppp_light_map[ppp_status] or "red" 
    c["wan_status"] = ui_helper.createSimpleLight(nil, ppp_state_map[ppp_status] or T"Unknown", ajax_attr_light)
end)

-- will stop in handleAjaxQuery if it is an actual AJAX query
content_helper.getExactContent(cs)
%>

<fieldset>
<%
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
%>
<legend><%= T"PPP Connection" %></legend>

<%
    local html = {}
    -- Label that shows PPP status
    ajax_attr_light.light.class = ppp_light_map[ppp_status] or "red"
    html[#html + 1] = ui_helper.createLight(T"Status", nil, ppp_state_map[ppp_status] or T"Unknown", ajax_attr_light)
    -- Switch PPP on/off
    html[#html + 1] = ui_helper.createSwitch(T"Enabled", "uci_wan_auto", content.uci_wan_auto)
    --Uptime
    local attributes = { span = { class = "span4" } }
    uptime = secondsToTime(tonumber(content_rpc["uptime"]))    

    ajax_attr.span.id = "uptime"
    html[#html + 1] = ui_helper.createLabel(T"Uptime", uptime, ajax_attr)
    local Standard_style = {
           span = {
                class = "span6"
            }
          }
    html[#html + 1] = ui_helper.createLabel(T"PPP Type", pppmap[ppptype],Standard_style)
    ajax_attr.span.id = "mtu"
    html[#html + 1] = ui_helper.createLabel(T"Operating MTU", content_sys["mtu"], ajax_attr)
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
    ajax_attr.span.id = "ipaddr"
    html[#html+1] = ui_helper.createLabel(T"IP Address", content_rpc["ipaddr"],ajax_attr)

    ajax_attr.span.id = "nexthop"
    html[#html+1] = ui_helper.createLabel(T"Gateway", content_rpc["nexthop"],ajax_attr)
    ajax_attr.span.id = "dns"
    html[#html+1] = ui_helper.createLabel(T"DNS Servers", content_rpc["dns"],ajax_attr)
    if content_rpc["ip6addr"] and content_rpc["ip6addr"]:len() > 0 then
        ajax_attr.span.id = "ip6addr"
        html[#html+1] = ui_helper.createLabel(T"IPv6 Address", content_rpc["ip6addr"],ajax_attr)
    end
    if content_rpc["ip6prefix"] and content_rpc["ip6prefix"]:len() > 0 then
        ajax_attr.span.id = "ip6prefix"
        html[#html+1] = ui_helper.createLabel(T"IPv6 Prefix", content_rpc["ip6prefix"],ajax_attr)
    end
    if content_rpc["dnsv6"] and content_rpc["dnsv6"]:len() > 0 then
        ajax_attr.span.id = "dnsv6"
        html[#html+1] = ui_helper.createLabel(T"IPv6 DNS", content_rpc["dnsv6"],ajax_attr)
    end
    -- ATM VP/VC
    if wan_ppp_over_atm then
      local advanced = {
        group = {
          class = "advanced hide",
        }
      }
      local vp_vc = string.format("%s / %s", content_uci_xtm["wan_atm_vpi"], content_uci_xtm["wan_atm_vci"])
      html[#html + 1] = ui_helper.createLabel(T"ATM VP / VC", vp_vc, advanced)
      html[#html + 1] = ui_helper.createLabel(T"Encapsulation", string.upper(content_uci_xtm["wan_atm_enc"]), advanced)
    end

    ngx.print(html)
%>

</fieldset>

<script>
var username = $("[name='uci_wan_username']");
var password = $("[name='uci_wan_password']");
$(function() {
  //Clear the password box on select and leave of username
   username.focusout(function() {
     password.val('');
   });
   password.focus(function() {
     password.val('');
   });
   
});
</script>
