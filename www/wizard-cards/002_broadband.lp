<%
-- Enable localization
gettext.textdomain('webui-wizard')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local wizard_helper = require("wizard")
local proxy = require("datamodel")
local session = ngx.ctx.session
local vNES = post_helper.validateNonEmptyString
local vN = post_helper.validatePositiveNum
local gVIES = post_helper.getValidateInEnumSelect
local vSIP = post_helper.validateStringIsIP
local vIPv4MSK = post_helper.validateIPv4Netmask
local gRV = post_helper.getOrValidation
local gmatch, format, lower = string.gmatch, string.format, string.lower
local untaint_mt = require("web.taint").untaint_mt
local timezones = require("tz_helper")
local setmetatable = setmetatable

local ifname2wantype = setmetatable({
    ["atm_8_35"] = "adsl",
    ["ptm0"] = "vdsl",
    ["eth4"] = "eth",
}, untaint_mt)

local wan_interface_path = "uci.network.interface.@wan."
local static_dns_path = "rpc.network.interface.@wan.static_dns_servers"
local wan_atm_path = "uci.xtm.atmdevice."
-- check whether the atm device exists or not
local wan_atm = proxy.get(wan_atm_path)

local mapParams = {
    wan_ifname = wan_interface_path .. "ifname",
    wan_proto = wan_interface_path .. "proto",
    wan_ppp_user_name = wan_interface_path .. "username",
    wan_ppp_password = wan_interface_path .. "password",
    wan_ppp_vpi_number_if = wan_interface_path .. "vpi",
    wan_ppp_vci_number_if = wan_interface_path .. "vci",
    wan_ppp_keepalive = wan_interface_path .. "keepalive",
    wan_static_ipaddr = wan_interface_path .. "ipaddr",
    wan_static_submsk = wan_interface_path .. "netmask",
    wan_static_gatewayip = wan_interface_path .. "gateway",
    wan_static_dns = static_dns_path,
    wan_metric = wan_interface_path .. "metric",
    wan_dhcp_reqopts = wan_interface_path .. "reqopts",
    wan_dhcp_neighreachabletime = wan_interface_path .. "neighreachabletime",
    wan_dhcp_neighgcstaletime = wan_interface_path .. "neighgcstaletime",
    wan_peerdns = wan_interface_path .. "peerdns",
    wan_auto = wan_interface_path .. "auto",
    system_timezone = "uci.system.system.@system[0].timezone",
    system_zonename = "uci.system.system.@system[0].zonename",
}

local function validateWanIfName(value, object, key)
    if object["wan_type"] == "adsl" and object["wan_proto"] == "pppoa" then
        object["wan_ifname"] = "atm_8_35"
    end
    if object["wan_type"] == "vdsl" then
        object["wan_ifname"] = "ptm0"
    end
    if object["wan_type"] == "eth" then
        object["wan_ifname"] = "eth4"
    end
    if object["wan_proto"] == "pppoe" then
        if object["wan_type"] == "eth" then
            object["wan_ifname"] = "eth4"
        else
            object["wan_ifname"] = "ptm0"
        end
    end

    return true
end

local function validateWanIfProto(value, object, key)
    if object["wan_type"] == "adsl" and object["wan_proto"] == "pppoa" then
        object["wan_ppp_ulp"] = "ppp"
        object["wan_ppp_enc"] = "vcmux"
    end

    if object["wan_proto"] == "pppoe" or object["wan_proto"] == "pppoa" then
        object["wan_metric"] = "10"
        object["wan_ppp_keepalive"] = "4,20"
    else
        object["wan_metric"] = "1"
        object["wan_ppp_keepalive"] = ""
    end

    if object["wan_proto"] == "dhcp" then
        object["wan_dhcp_reqopts"] = "1 3 6 15 33 42 43 51 121 249"
        object["wan_dhcp_neighreachabletime"] = "1200000"
        object["wan_dhcp_neighgcstaletime"] = "2400"
    else
        object["wan_dhcp_reqopts"] = ""
        object["wan_dhcp_neighreachabletime"] = ""
        object["wan_dhcp_neighgcstaletime"] = ""
    end

    if object["wan_proto"] ~= "static" then
        object["wan_static_ipaddr"] = ""
        object["wan_static_submsk"] = ""
        object["wan_static_gatewayip"] = ""
        object["wan_static_dns"] = ""
    end
    if object["wan_proto"] == "bridge" then
        object["wan_static_ipaddr"] = ""
        object["wan_static_submsk"] = ""
        object["wan_static_gatewayip"] = ""
        object["wan_static_dns"] = ""
        object["wan_dhcp_reqopts"] = ""
        object["wan_dhcp_neighreachabletime"] = ""
        object["wan_dhcp_neighgcstaletime"] = ""
    end
    object["wan_peerdns"] = ""

    return true
end

local function validateWanPPPUsername(value, object, key)
    if (object["wan_proto"] == "pppoe" or object["wan_proto"] == "pppoa")  then
        object["ppp_username"] = object[key]
        return vNES(value)
    end
    object[key] = ""
    return true
end

local function validateWanPPPPassword(value, object, key)
    if (object["wan_proto"] == "pppoe" or object["wan_proto"] == "pppoa") then
        if value == "********" then
            object[key] = session:retrieve("network_password")
            object["ppp_password"] = object[key]
            return true
        end
        local ret, msg = vNES(value)
        if ret then
            session:store("network_password", value)
        end
        return ret, msg
    end
    object[key] = ""
    return true
end

local function validateVpiAndVciNum(value, object, key)
    if object["wan_type"] == "adsl" and object["wan_proto"] == "pppoa" then
        if object["wan_proto"] == "pppoa" then
            object[key .. "_if"] = value
        else
            object[key .. "_if"] = ""
        end
        return vN(value)
    end
    object[key] = nil
    object[key .. "_if"] = ""
    return true
end

local function validateWanStaticIpAddr(value, object, key)
    if object["wan_proto"] == "static" then
        return vSIP(value)
    end
    object[key] = ""
    return true
end

local dns_errors = {}
local function validateDnsServers(value, object, key)
    if object["wan_proto"] == "static" then
        local ret1, msg1 = vSIP(object["wan_static_pri_dns"])
        local ret2, msg2 = gRV(vSIP(object["wan_static_sec_dns"]), "")
        if ret1 and ret2 then
            object["wan_static_dns"] = object["wan_static_pri_dns"]
            if object["wan_static_sec_dns"] ~= nil then
                object["wan_static_dns"] = object["wan_static_dns"]  .. "," .. object["wan_static_sec_dns"]
            end
            return true
        end
        if not ret1 then
            dns_errors["wan_static_pri_dns"] = true
        end

        if not ret2 then
            dns_errors["wan_static_sec_dns"] = true
        end
        if not ret1 then return ret1, msg1 end
        if not ret2 then return ret2, msg2 end
    end
    object[key] = ""
    return true
end

local function validateWanStaticIpNetMask(value, object, key)
    if object["wan_proto"] == "static" then
        return vIPv4MSK(value)
    end
    object[key] = ""
    return true
end

local function validateWansensing(value, object, key)
    if object["wansensing_enable"] == "1" then
        local content = {
            wan_ifname = "uci.network.interface.@wan.ifname",
            wan_proto = "uci.network.interface.@wan.proto",
        }
        content_helper.getExactContent(content)

        if (object["wan_type"] == ifname2wantype[content["wan_ifname"]] and content["wan_proto"] == object["wan_proto"]) or (content["wan_ifname"] == "" and object["wan_type"] == ifname2wantype[content["ppp_ifname"]]) then
            return true
        end
        object[key] = "0"
        object["wansensing_l2type"] = ""
        object["wansensing_l3type"] = ""
        object["wan_auto"] = "1"
        return true
    end
    object[key] = nil
    object["wansensing_l2type"] = nil
    object["wansensing_l3type"] = nil
    object["wan_auto"] = nil
    object["wansensing_enable"] = "0"
    return true
end
local function validateSystemtimezone(value, object, key)
    local gui_tz = value
    local valid, helpmsg = post_helper.validateNonEmptyString(value)
    if valid then
      local tz_value, zonename_value = string.match(gui_tz,'(.*)_timezone_(.*)')
      --tz_value is the matched result from tz_helper.lua, can not be empty string
      if not tz_value or not zonename_value then
        return valid, helpmsg
      end
      object["system_timezone"] = tz_value
      object["system_zonename"] = zonename_value
    end
    return valid, helpmsg
end
local function validateSystemzonename(value, object,key)
    return true
end

local function getWanType(content, content_wans)
    local wansensing_l2type = lower(content_wans["wansensing_l2type"])
    if wansensing_l2type == "" then wansensing_l2type = "adsl" end
    return content["wan_type"] or ifname2wantype[content["wan_ifname"]] or wansensing_l2type
end

local mapValid = {
    wan_ifname = validateWanIfName,
    wan_proto = validateWanIfProto,
    wan_static_ipaddr = validateWanStaticIpAddr,
    wan_static_submsk = validateWanStaticIpNetMask,
    wan_static_dns = validateDnsServers,
    wan_static_gatewayip = validateWanStaticIpAddr,
    wan_ppp_user_name = validateWanPPPUsername,
    wan_ppp_password = validateWanPPPPassword,
    system_timezone = validateSystemtimezone,
    system_zonename = validateSystemzonename,
}

local mapParams_wans = {
    wansensing_enable = "uci.wansensing.global.enable",
    wansensing_l2type = "uci.wansensing.global.l2type",
    wansensing_l3type = "uci.wansensing.global.l3type",
    wan_auto = wan_interface_path .. "auto",
}

local mapValid_wans = {
    wansensing_enable = validateWansensing,
}
local wan_interface_options = {
        {"eth",  T"Ethernet"},
    }
local wan_proto_options = {
        {"pppoe",  T"PPP over Ethernet"},
        {"dhcp",   T"Dynamic IP Address"},
        {"static", T"Static IP Address"},
        {"bridge", T"Bridged"},
    }
-- if wan_atm is not empty, then do adding the atm part
if next(wan_atm) ~= nil then
    local wan_atm_uci_path = wan_atm_path .."@atm_8_35."
    local atm_mapParams = {
        wan_ppp_vpi_number = wan_atm_uci_path .. "vpi",
        wan_ppp_vci_number = wan_atm_uci_path .. "vci",
        wan_ppp_enc = wan_atm_uci_path .. "enc",
        wan_ppp_ulp = wan_atm_uci_path .. "ulp",
    }
    for k, v in pairs(atm_mapParams) do
        mapParams[k] = v
    end

    local xtm_mapValid = {
        wan_ppp_vpi_number = validateVpiAndVciNum,
        wan_ppp_vci_number = validateVpiAndVciNum,
    }
    for k, v in pairs(xtm_mapValid) do
        mapValid[k] = v
    end

    xtm_wan_interface_options = {
        {"adsl", T"ADSL"},
        {"vdsl", T"VDSL"},
    }
    for i, v in ipairs(xtm_wan_interface_options) do
        wan_interface_options[#wan_interface_options + 1] = v
    end

    table.insert(wan_proto_options, {"pppoa",  T"PPP over ATM"})
end

local content_wans, helpmsg_wans = wizard_helper.handleQuery(mapParams_wans, mapValid_wans)
local content, helpmsg = wizard_helper.handleQuery(mapParams, mapValid)

local function getTimeZoneName(list, isRemote)
  local default_tztable = {
    [true] = "UTC",
    [false] = nil,
  }

  local tz = content["system_timezone"]
  local tz_name = content["system_zonename"]
  if tz == "" then
    return default_tztable[isRemote]
  end

  if isRemote then
    default_tztable[isRemote] = tz
  end

  if tz_name ~= "" then
    return isRemote and tz_name or tz .. "_timezone_" .. tz_name
  end

  for _,v in ipairs(list) do
    local key = string.match(v[1], "^([^_]*)")
    if key == tz then
      return isRemote and v[2] or v[1]
    end
  end
  return default_tztable[isRemote]
end


if ngx.req.get_method() == "GET" then
    session:store("network_password", content["wan_ppp_password"])
elseif content["action"] == "SAVE" then
    session:store("network_password", nil)
end

local wan_type = getWanType(content, content_wans)

if not content["wan_static_pri_dns"] then
    local dns_servers = {}
    --to get the dns server value, the string is 1.1.1.1,2.2.2.2,
    for dns_server in gmatch(content["wan_static_dns"], "([^,]+)") do
        dns_servers[#dns_servers+1] = dns_server
    end
    content["wan_static_pri_dns"] = dns_servers[1] or ""
    content["wan_static_sec_dns"] = dns_servers[2] or ""
end

local wan_interface_options_confirm = setmetatable({
    ["adsl"] = "ADSL",
    ["eth"] = "Ethernet",
    ["vdsl"] = "VDSL",
}, untaint_mt)

local wan_proto_options_confirm = setmetatable({
    ["pppoe"] = "PPP over Ethernet",
    ["pppoa"] = "PPP over ATM",
    ["dhcp"]   = "Dynamic IP Address",
    ["static"] = "Static IP Address",
    ["bridge"] = "Bridged",
}, untaint_mt)

%>
<div class='wizard-card'>
   <fieldset>
      <%="<legend>" .. T"Step 2 of 5" .. "</legend>"%>
      <%= "<h4>" .. T"Internet  Setup " .. "</h4>"%>
      <%
        local html = {}
        -- The reserved legend to be filled automatically when loading
        html[#html+1] = ui_helper.createMessages(message_helper.popMessages())

        local wan_type_class = {
            select = {
                class = "monitor-changes",
            },
        }
        html[#html+1] = ui_helper.createInputSelect(T"WAN Interfaces", "wan_type", wan_interface_options, wan_type, wan_type_class)

        local wan_proto_class = {
            select = {
                class = "monitor-changes",
            },
        }

        html[#html+1] = ui_helper.createInputSelect(T"WAN Type", "wan_proto", wan_proto_options, content["wan_proto"], wan_proto_class)

        local wan_pppoa_class = {
            group = {
                class = "monitor-wan_type monitor-adsl monitor-wan_proto monitor-pppoe monitor-pppoa",
            },
            input = {
                class= "span4",
            },
        }
        local wan_ppp_class = {
            group = {
                class = "monitor-wan_proto monitor-pppoa monitor-pppoe",
            },
            input = {
                class= "span4",
            },
        }
        html[#html+1] = ui_helper.createInputText(T"Username", "wan_ppp_user_name", content["wan_ppp_user_name"], wan_ppp_class, helpmsg["wan_ppp_user_name"])
        html[#html+1] = ui_helper.createInputPassword(T"Password", "wan_ppp_password", content["wan_ppp_password"], wan_ppp_class, helpmsg["wan_ppp_password"])
        html[#html+1] = ui_helper.createInputText(T"VPI Number", "wan_ppp_vpi_number", content["wan_ppp_vpi_number"], wan_pppoa_class, helpmsg["wan_ppp_vpi_number"])
        html[#html+1] = ui_helper.createInputText(T"VCI Number", "wan_ppp_vci_number", content["wan_ppp_vci_number"], wan_pppoa_class, helpmsg["wan_ppp_vci_number"])


        local wan_static_class = {
            group = {
               class ="monitor-wan_proto monitor-static",
            },
        }
        html[#html+1] = ui_helper.createInputText(T"Static IP Address", "wan_static_ipaddr", content["wan_static_ipaddr"], wan_static_class, helpmsg["wan_static_ipaddr"])
        html[#html+1] = ui_helper.createInputText(T"Static Subnet Mask", "wan_static_submsk", content["wan_static_submsk"], wan_static_class, helpmsg["wan_static_submsk"])
        html[#html+1] = ui_helper.createInputText(T"Static Gateway", "wan_static_gatewayip", content["wan_static_gatewayip"], wan_static_class, helpmsg["wan_static_gatewayip"])
        html[#html+1] = ui_helper.createInputText(T"Static Primary DNS",  "wan_static_pri_dns", content["wan_static_pri_dns"], wan_static_class, dns_errors["wan_static_pri_dns"] and helpmsg["wan_static_dns"])
        html[#html+1] = ui_helper.createInputText(T"Static Secondary DNS", "wan_static_sec_dns", content["wan_static_sec_dns"], wan_static_class, dns_errors["wan_static_sec_dns"] and helpmsg["wan_static_dns"])

        -- bridge mode
        local confirming = {
          alert = {
            class = "alert hide monitor-wan_proto monitor-bridge",
            id = "confirming-msg",
          }
        }
        html[#html + 1] = ui_helper.createAlertBlock(T"You are selecting switch modem to <strong>Bridged Mode</strong>. <br /> Note: if you want the gateway to run in Routed Mode again, factory reset is needed. <br />Modem need reboot to take effect. Please wait a while after complete this setup wizard.", confirming)

        html[#html+1] = ui_helper.createInputSelect(T"Current Timezone", "system_timezone", timezones, getTimeZoneName(timezones, false))
        ngx.print(html)
    %>
  </fieldset>
</div>

<div class='wizard-confirm'>
  <fieldset>
    <%
        local html = {}
        -- The reserved legend to be filled automatically when loading
        html[#html+1] = ui_helper.createLabel(T"WAN Interfaces", wan_interface_options_confirm[wan_type] or "")
        html[#html+1] = ui_helper.createLabel(T"WAN Type", wan_proto_options_confirm[content["wan_proto"]] or "")

        if  (content["wan_proto"] == "pppoe" or content["wan_proto"] == "pppoa") then
            html[#html+1] = ui_helper.createLabel(T"Username", content["wan_ppp_user_name"])
            html[#html+1] = ui_helper.createLabel(T"Password", content["wan_ppp_password"])
            if  (wan_type == "adsl") then
                html[#html+1] = ui_helper.createLabel(T"VPI Number", content["wan_ppp_vpi_number"])
                html[#html+1] = ui_helper.createLabel(T"VCI Number", content["wan_ppp_vci_number"])
            end
        end

        if (content["wan_proto"] == "static") then
            html[#html+1] = ui_helper.createLabel(T"Static IP Address", content["wan_static_ipaddr"])
            html[#html+1] = ui_helper.createLabel(T"Static Subnet Mask", content["wan_static_submsk"])
            html[#html+1] = ui_helper.createLabel(T"Static Gateway", content["wan_static_gatewayip"])
            html[#html+1] = ui_helper.createLabel(T"Static Primary DNS", content["wan_static_pri_dns"])
            html[#html+1] = ui_helper.createLabel(T"Static Secondary DNS", content["wan_static_sec_dns"])
        end
        html[#html+1] = ui_helper.createLabel(T"Current Timezone", getTimeZoneName(timezones, true))
        ngx.print(html)
    %>
  </fieldset>
</div>
<script type="text/javascript">
$(document).ready(function () {
  var wan_type = $("select[name='wan_type']").val();
  if (wan_type != "adsl") {
    $('option[value="pppoa"]').hide();
  } else {
    $('option[value="pppoa"]').show();
    $('option[value="static"]').hide();
    $('option[value="dhcp"]').hide();
  }
})

$('select[name="wan_type"]').on("change", function() {
  var wan_type = $("select[name='wan_type']").val();
  if (wan_type == "adsl") {
    $('option[value="pppoa"]').show();
    $('option[value="static"]').hide();
    $('option[value="dhcp"]').hide();
  }
  else {
    $('option[value="pppoa"]').hide();
    $('option[value="static"]').show();
    $('option[value="dhcp"]').show();
    var wan_proto_el = $("select[name='wan_proto']")
    var wan_proto = wan_proto_el.val();
    if (wan_proto == "pppoa") {
        wan_proto_el.val("pppoe");
    }
  }
})
</script>
