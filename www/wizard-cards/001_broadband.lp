<%
-- Enable localization
gettext.textdomain('webui-wizard')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local wizard_helper = require("wizard")
local session = ngx.ctx.session
local vNES = post_helper.validateNonEmptyString
local vN = post_helper.validatePositiveNum
local gVIES = post_helper.getValidateInEnumSelect
local vSIP = post_helper.advancedIPValidation
local vIPv4MSK = post_helper.validateIPv4Netmask
local gmatch, format, lower = string.gmatch, string.format, string.lower
local untaint_mt = require("web.taint").untaint_mt
local setmetatable = setmetatable

local sw_flagParams = {
    sw_flag = "uci.env.var.ssid_prefix",
}
content_helper.getExactContent(sw_flagParams)
local InternodeUsername_pattern = "^[^@%.%s]+[^@%s]*@[^@%.%s]+[^@%s]*$"
local function validateStringIsInternodeUsername(value)
    if not value then
        return nil, T"Invalid input"
    end
    if not value:match(InternodeUsername_pattern) then
        return nil, T"Please insert your Internode broadband username in the format of username@internode.on.net"
    end
    return true
end

local isp_options = {}
if sw_flagParams["sw_flag"] == "Internode" then
    isp_options = {
        {"Internode", T"Internode"},
    }
else
    isp_options = {
        {"iiNet", T"iiNet"},
        {"Westnet", T"Westnet"},
        {"Transact", T"Transact"},
        {"Adam-Internet", T"Adam Internet"},
        {"Internode", T"Internode"},
    }
end

local nsp_link = setmetatable({
    ["Adam-Internet"] = "http://www.adam.com.au",
    ["Internode"] = "http://www.internode.on.net",
    ["Other"] = "http://www.internode.on.net"
}, untaint_mt)

local nsp_logo = setmetatable({
    ["Adam-Internet"] = "logo-adam.png",
    ["Internode"] = "internode-logo.svg",
    ["Other"] = "internode-logo.svg"
}, untaint_mt)

local wan_interface_options = {
    {"adsl", T"ADSL"},
    {"vdsl", T"VDSL"},
    {"eth",  T"Ethernet"},
}

local wan_proto_options = {
    {"pppoe",  T"PPP over Ethernet"},
    {"pppoa",  T"PPP over ATM"},
    {"dhcp",   T"Dynamic IP Address"},
    {"static", T"Static IP Address"},
}

local ifname2wantype = setmetatable({
    ["atm_ppp"] = "adsl",
    ["atm_ipoe"] = "adsl",
    ["vlan_ppp"] = "vdsl",
    ["ptm0"] = "vdsl",
    ["vlan_hfc"] = "eth",
    ["eth4"] = "eth",
}, untaint_mt)

local wan_atm_uci_path = "uci.xtm.atmdevice.@atm_ppp."
local wan_atm_uci_ipoe_path = "uci.xtm.atmdevice.@atm_ipoe."
local wan_interface_path = "uci.network.interface.@wan."
local video_interface_path = "uci.network.interface.@video."
local video2_interface_path = "uci.network.interface.@video2."
local static_dns_path = "rpc.network.interface.@wan.static_dns_servers"

local mapParams = {
    isp = "uci.mmpbxrvsipnet.network.@sip_net.isp",
    sip_state = "uci.mmpbxrvsipnet.network.@sip_net.primary_proxy",
    sip_registrar = "uci.mmpbxrvsipnet.network.@sip_net.primary_registrar",
    sip_domain = "uci.mmpbxrvsipnet.network.@sip_net.domain_name",
    nsplink = "uci.web.uiconfig.@uidefault.nsplink",
    nsplogo = "uci.web.uiconfig.@uidefault.nsplogo",
    wan_ifname = wan_interface_path .. "ifname",
    wan_proto = wan_interface_path .. "proto",
    wan_ppp_user_name = wan_interface_path .. "username",
    wan_ppp_password = wan_interface_path .. "password",
    wan_ppp_vpi_number = wan_atm_uci_path .. "vpi",
    wan_ppp_vci_number = wan_atm_uci_path .. "vci",
    wan_ppp_enc = wan_atm_uci_path .. "enc",
    wan_ppp_ulp = wan_atm_uci_path .. "ulp",
    wan_ppp_vpi_number_if = wan_interface_path .. "vpi",
    wan_ppp_vci_number_if = wan_interface_path .. "vci",
    wan_ppp_keepalive = wan_interface_path .. "keepalive",
    wan_ipoe_vpi_number = wan_atm_uci_ipoe_path .. "vpi",
    wan_ipoe_vci_number = wan_atm_uci_ipoe_path .. "vci",
    wan_static_ipaddr = wan_interface_path .. "ipaddr",
    wan_static_submsk = wan_interface_path .. "netmask",
    wan_static_gatewayip = wan_interface_path .. "gateway",
    wan_static_dns = static_dns_path,
    wan_metric = wan_interface_path .. "metric",
    wan_dhcp_reqopts = wan_interface_path .. "reqopts",
    wan_dhcp_neighreachabletime = wan_interface_path .. "neighreachabletime",
    wan_dhcp_neighgcstaletime = wan_interface_path .. "neighgcstaletime",
    ppp_username  = "uci.network.interface.@ppp.username",
    ppp_password = "uci.network.interface.@ppp.password",
    pppv_username  = "uci.network.interface.@pppv.username",
    pppv_password = "uci.network.interface.@pppv.password",
    wan_peerdns = wan_interface_path .. "peerdns",
    video_ifname = video_interface_path .. "ifname",
    video_auto = video_interface_path .. "auto",
    video2_ifname = video2_interface_path .. "ifname",
    video2_auto = video2_interface_path .. "auto",
    id_vlan_vdsl = "uci.network.device.@vlan_ppp.vid",
    id_vlan_eth = "uci.network.device.@vlan_hfc.vid",
    delegateRestriction = "uci.network.interface.@wan6.delegateRestriction",
    lan_ip6assign = "uci.network.interface.@lan.ip6assign",
    guest1_ip6assign = "uci.network.interface.@Guest1.ip6assign",
    Guest1_5GHz_ip6assign = "uci.network.interface.@Guest1_5GHz.ip6assign",
    VLAN1_ip6assign = "uci.network.interface.@VLAN1.ip6assign",
    VLAN2_ip6assign = "uci.network.interface.@VLAN2.ip6assign",
    VLAN3_ip6assign = "uci.network.interface.@VLAN3.ip6assign",
}

local mapParams_wans = {
    wansensing_enable = "uci.wansensing.global.enable",
    wansensing_l2type = "uci.wansensing.global.l2type",
    wansensing_l3type = "uci.wansensing.global.l3type",
    ppp_auto = "uci.network.interface.@ppp.auto",
    pppv_auto = "uci.network.interface.@pppv.auto",
    ipoe_auto = "uci.network.interface.@ipoe.auto",
    wan_auto = wan_interface_path .. "auto",
}

local function gVerifyIsp(options)
    return function(value, object, key)
       if value == "Other" then
            object[key] = "Internode"
            object["sip_state"] = "sip.internode.on.net"
            object["sip_registrar"] = object["sip_state"]
            object["sip_domain"] = object["sip_state"]
            return true
        end
        local success, msg = gVIES(options)(value)
        if success then
            if value == "Adam-Internet" then
                object[key] = "Adam Internet"
            end
            object["nsplink"] = nsp_link[value] or "http://www.iinet.net.au"
            object["nsplogo"] = nsp_logo[value] or "logo.gif"
            return true
        else
            return nil, msg
        end
    end
end

local function validateVlanID(value, object, key)
    if object["wan_type"] ~= "vdsl" and object["wan_type"] ~= "eth" or object["vlan_enabled"] == "0" or object["wan_proto"] ~= "pppoe" then
        object["id_vlan_eth"] = nil
        object["id_vlan_vdsl"] = nil
        return true
    else
        if object["wan_type"] == "vdsl" and "id_vlan_vdsl" ~= key or object["wan_type"] == "eth" and "id_vlan_eth" ~= key then
            object[key] = nil
            return true
        end
    end

    local pattern = "^(%d+)$"
    local number = { string.match(value, pattern) }
    if #number ~= 1 or tonumber(number[1]) < 2 or tonumber(number[1]) > 4094 then
        return nil, T"Invalid VLAN ID, it must be a number on the range 2-4094"
    end
    return vN(value)
end

local function validateWanIfName(value, object, key)
    if object["wan_type"] == "adsl" then
        if "pppoe" == object["wan_proto"] or "pppoa" == object["wan_proto"] or object["isp"] == "Internode" or object["isp"] == "Other" then
            object["wan_ifname"] = "atm_ppp"
        elseif "dhcp" == object["wan_proto"] or "static" == object["wan_proto"] then
            object["wan_ifname"] = "atm_ipoe"
        end
    end
    if object["wan_type"] == "vdsl" then
        object["wan_ifname"] = "ptm0"
        if object["isp"] ~= "Internode" and object["isp"] ~= "Other" and "pppoe" == object["wan_proto"] and object["vlan_enabled"] == "1" then
            object["wan_ifname"] = "vlan_ppp"
        end
    end
    if object["wan_type"] == "eth" then
        object["wan_ifname"] = "eth4"
        if object["isp"] ~= "Internode" and object["isp"] ~= "Other" and "pppoe" == object["wan_proto"] and object["vlan_enabled"] == "1" then
            object["wan_ifname"] = "vlan_hfc"
        end
    end
    return true
end

local function validateWanIfProto(value, object, key)
    if object["wan_type"] == "adsl" then
        if object["wan_proto"] == "pppoe" then
            object["wan_ppp_ulp"] = "eth"
            object["wan_ppp_enc"] = "llc"
        end

        if object["wan_proto"] == "pppoa" then
            object["wan_ppp_ulp"] = "ppp"
            object["wan_ppp_enc"] = "vcmux"
        end
    end

    if object["wan_proto"] == "pppoe" or object["wan_proto"] == "pppoa" then
        object["wan_metric"] = "10"
        object["wan_ppp_keepalive"] = "4,20"
    else
        object["wan_metric"] = "1"
        object["wan_ppp_keepalive"] = ""
    end

    if object["wan_proto"] == "dhcp" then
        object["wan_dhcp_reqopts"] = "1 3 6 43 51 58 59"
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
    object["wan_peerdns"] = ""

    return true
end

local function validateWanPPPUsername(value, object, key)
    if (object["wan_proto"] == "pppoe" or object["wan_proto"] == "pppoa")  then
        object["ppp_username"] = object[key]
        object["pppv_username"] = object[key]
        if object["isp"] == "Internode" or object["isp"] == "Other" then
		    object["delegateRestriction"] = "Dynamic"
            if string.find(object[key],"@dynamic") then
                object["lan_ip6assign"] = "64"
				object["guest1_ip6assign"] = ""
				object["Guest1_5GHz_ip6assign"] = ""
				object["VLAN1_ip6assign"] = ""
				object["VLAN2_ip6assign"] = ""
				object["VLAN3_ip6assign"] = ""
			else
				object["lan_ip6assign"] = "64"
				object["guest1_ip6assign"] = "64"
				object["Guest1_5GHz_ip6assign"] = "64"
				object["VLAN1_ip6assign"] = "64"
				object["VLAN2_ip6assign"] = "64"
				object["VLAN3_ip6assign"] = "64"
			end
            return validateStringIsInternodeUsername(value)
        else
		    object["delegateRestriction"] = "Off"
			object["lan_ip6assign"] = "64"
			object["guest1_ip6assign"] = "64"
			object["Guest1_5GHz_ip6assign"] = "64"
			object["VLAN1_ip6assign"] = "64"
			object["VLAN2_ip6assign"] = "64"
			object["VLAN3_ip6assign"] = "64"
            return vNES(value)
        end
    end
    object[key] = ""
    return true
end

local function validateWanPPPPassword(value, object, key)
    if (object["wan_proto"] == "pppoe" or object["wan_proto"] == "pppoa") then
        if value == "********" then
            object[key] = session:retrieve("network_password")
            object["ppp_password"] = object[key]
            object["pppv_password"] = object[key]
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
    if object["wan_type"] == "adsl" then
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
        return vSIP(value, object, key)
    end
    object[key] = ""
    return true
end

local dns_errors = {}
local function validateDnsServers(value, object, key)
    if object["wan_proto"] == "static" then
        local ret1, msg1 = vSIP(object["wan_static_pri_dns"], object, key)
        local ret2, msg2 = vSIP(object["wan_static_sec_dns"], object, key)
        if ret1 and ret2 then
            object["wan_static_dns"] = object["wan_static_pri_dns"] .. "," .. object["wan_static_sec_dns"]
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
            ppp_ifname = "uci.network.interface.@ppp.ifname",
        }
        content_helper.getExactContent(content)
        if object["wan_type"] ~= ifname2wantype[content["wan_ifname"]] or content["wan_proto"] ~= object["wan_proto"] then
            object[key] = "0"
            object["wansensing_l2type"] = ""
            object["wansensing_l3type"] = ""
            object["ppp_auto"] = "0"
            object["pppv_auto"] = "0"
            object["ipoe_auto"] = "0"
            object["wan_auto"] = "1"
            return true
        end
    end
    object[key] = nil
    object["wansensing_l2type"] = nil
    object["wansensing_l3type"] = nil
    object["ppp_auto"] = nil
    object["pppv_auto"] = nil
    object["ipoe_auto"] = nil
    object["wan_auto"] = nil
    return true
end

local function getVideoConfig(value, object, key)
    if object['wan_type'] == 'adsl' then
        object[key] = 'atm_video'
        object['video_auto'] = '1'
        object['video2_ifname'] = 'atm_video2'
        object['video2_auto'] = '1'
    elseif object['wan_type'] == 'vdsl' then
        object[key] = 'vlan_video'
        object['video_auto'] = '1'
        object['video2_ifname'] = ''
        object['video2_auto'] = '0'
    else
        object[key] = ''
        object['video_auto'] = '0'
        object['video2_ifname'] = ''
        object['video2_auto'] = '0'
    end
    return true
end

local function getWanType(content, content_wans)
    local wansensing_l2type = lower(content_wans["wansensing_l2type"])
    if wansensing_l2type == "" then wansensing_l2type = "adsl" end
    return content["wan_type"] or ifname2wantype[content["wan_ifname"]] or wansensing_l2type
end

local mapValid = {
    isp = gVerifyIsp(isp_options),
    wan_ifname = validateWanIfName,
    wan_proto = validateWanIfProto,
    wan_ppp_user_name = validateWanPPPUsername,
    wan_ppp_password = validateWanPPPPassword,
    wan_ppp_vpi_number = validateVpiAndVciNum,
    wan_ppp_vci_number = validateVpiAndVciNum,
    wan_ipoe_vpi_number = validateVpiAndVciNum,
    wan_ipoe_vci_number = validateVpiAndVciNum,
    wan_static_ipaddr = validateWanStaticIpAddr,
    wan_static_submsk = validateWanStaticIpNetMask,
    wan_static_dns = validateDnsServers,
    wan_static_gatewayip = validateWanStaticIpAddr,
    video_ifname = getVideoConfig,
    id_vlan_vdsl = validateVlanID,
    id_vlan_eth = validateVlanID,
}

local mapValid_wans = {
    wansensing_enable = validateWansensing,
}
local content_wans, helpmsg_wans = wizard_helper.handleQuery(mapParams_wans, mapValid_wans)
local content, helpmsg = wizard_helper.handleQuery(mapParams, mapValid)

-- to be backward compatibility
if content["isp"] == "Adam Internet" then content["isp"] = "Adam-Internet" end

-- for Internode variant setup wizard will force isp to be Internode
if content["isp"] == "Other" then content["isp"] = "Internode" end
local vlan_is_on = content["vlan_enabled"]
if vlan_is_on == nil then
    if content["wan_ifname"] ~= nil then
        if string.find(content["wan_ifname"], "^vlan_") ~= nil and content["isp"] ~= "Internode" then
            vlan_is_on = "1"
        else
            vlan_is_on = "0"
        end
    else
        if content["isp"] == "Transact" then
            vlan_is_on = "1"
        else
            vlan_is_on = "0"
        end
    end
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
}, untaint_mt)

%>
<div class='wizard-card'>
   <fieldset>
     <%
        local html = {}
        -- The reserved legend to be filled automatically when loading
        html[#html+1] =  "<legend></legend>"
        html[#html+1] = ui_helper.createMessages(message_helper.popMessages())

        local isp_class = {
            select = {
                class = "monitor-changes",
            },
        }
        html[#html+1] = ui_helper.createInputSelect(T"Internet Service Provider", "isp", isp_options, content["isp"], isp_class)
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

        html[#html+1] = ui_helper.createInputSelect(T"WAN Type:", "wan_proto", wan_proto_options, content["wan_proto"], wan_proto_class)

        local wan_vlan_class = {
            group = {
                class = "monitor-wan_type monitor-vdsl monitor-eth monitor-wan_proto monitor-pppoe monitor-isp monitor-iiNet monitor-Westnet monitor-Adam-Internet monitor-Transact",
            },
            input = {
                class = "monitor-changes",
            },
        }
        html[#html+1] = ui_helper.createSwitch(T"VLAN Enabled","vlan_enabled", vlan_is_on, wan_vlan_class)

        local wan_vlanid_vdsl_class = {
            group = {
                class = "monitor-wan_type monitor-vdsl monitor-wan_proto monitor-pppoe monitor-vlan_enabled monitor-1",
            },
            input = {
                class = "monitor-changes",
            },
        }
        local wan_vlanid_eth_class = {
            group = {
                class = "monitor-wan_type monitor-eth monitor-wan_proto monitor-pppoe monitor-vlan_enabled monitor-1",
            },
            input = {
                class = "monitor-changes",
            },
        }
        html[#html+1] = ui_helper.createInputText(T"VLAN ID", "id_vlan_vdsl", content["id_vlan_vdsl"], wan_vlanid_vdsl_class, helpmsg["id_vlan_vdsl"])
        html[#html+1] = ui_helper.createInputText(T"VLAN ID", "id_vlan_eth", content["id_vlan_eth"], wan_vlanid_eth_class, helpmsg["id_vlan_eth"])
        local wan_pppoa_class = {
            group = {
                class = "monitor-wan_type monitor-adsl monitor-wan_proto monitor-pppoe monitor-pppoa",
            },
            input = {
                class= "span4",
            },
        }
        local wan_ipoe_class = {
            group = {
                class = "monitor-wan_type monitor-adsl monitor-wan_proto monitor-static monitor-dhcp",
            },
            input = {
                class= "span4",
            },
        }
        local wan_ppp_class = {
            group = {
                class = "monitor-wan_proto monitor-pppoe monitor-pppoa",
            },
            input = {
                class= "span4",
            },
        }
        html[#html+1] = ui_helper.createInputText(T"Username: ", "wan_ppp_user_name", content["wan_ppp_user_name"], wan_ppp_class, helpmsg["wan_ppp_user_name"])
        html[#html+1] = ui_helper.createInputPassword(T"Password:", "wan_ppp_password", content["wan_ppp_password"], wan_ppp_class, helpmsg["wan_ppp_password"])
        html[#html+1] = ui_helper.createInputText(T"VPI Number: ", "wan_ppp_vpi_number", content["wan_ppp_vpi_number"], wan_pppoa_class, helpmsg["wan_ppp_vpi_number"])
        html[#html+1] = ui_helper.createInputText(T"VPI Number: ", "wan_ipoe_vpi_number", content["wan_ipoe_vpi_number"], wan_ipoe_class, helpmsg["wan_ipoe_vpi_number"])
        html[#html+1] = ui_helper.createInputText(T"VCI Number: ", "wan_ppp_vci_number", content["wan_ppp_vci_number"], wan_pppoa_class, helpmsg["wan_ppp_vci_number"])
        html[#html+1] = ui_helper.createInputText(T"VCI Number: ", "wan_ipoe_vci_number", content["wan_ipoe_vci_number"], wan_ipoe_class, helpmsg["wan_ipoe_vci_number"])

        local wan_static_class = {
            group = {
               class ="monitor-wan_proto monitor-static",
            },
        }
        html[#html+1] = ui_helper.createInputText(T"Static IP Address:", "wan_static_ipaddr", content["wan_static_ipaddr"], wan_static_class, helpmsg["wan_static_ipaddr"])
        html[#html+1] = ui_helper.createInputText(T"Static Subnet Mask:", "wan_static_submsk", content["wan_static_submsk"], wan_static_class, helpmsg["wan_static_submsk"])
        html[#html+1] = ui_helper.createInputText(T"Static Gateway:", "wan_static_gatewayip", content["wan_static_gatewayip"], wan_static_class, helpmsg["wan_static_gatewayip"])
        html[#html+1] = ui_helper.createInputText(T"Static Primary DNS: ",  "wan_static_pri_dns", content["wan_static_pri_dns"], wan_static_class, dns_errors["wan_static_pri_dns"] and helpmsg["wan_static_dns"])
        html[#html+1] = ui_helper.createInputText(T"Static Secondary DNS: ", "wan_static_sec_dns", content["wan_static_sec_dns"], wan_static_class, dns_errors["wan_static_sec_dns"] and helpmsg["wan_static_dns"])

        ngx.print(html)
    %>
  </fieldset>
</div>

<div class='wizard-confirm'>
  <fieldset>
    <%
        local html = {}
        local notice_confirm_attr = {
          alert = {
              class = "alert-info monitor-fw_level monitor-normal"
          },
        }
        -- The reserved legend to be filled automatically when loading
        html[#html+1] =  "<legend></legend>"
        html[#html+1] =  "<h4>Router Installation is Complete</h4>"
        html[#html+1] = ui_helper.createAlertBlock(T"Please review your settings and click finish.<br/>Your Router will reset and settings will be saved.", notice_confirm_attr)
        html[#html+1] = ui_helper.createLabel(T"Internet Service Provider:", content["isp"])
        html[#html+1] = ui_helper.createLabel(T"WAN Interfaces:", wan_interface_options_confirm[wan_type] or "")
        html[#html+1] = ui_helper.createLabel(T"WAN Type:", wan_proto_options_confirm[content["wan_proto"]] or "")

        if  (content["wan_proto"] == "pppoe" or content["wan_proto"] == "pppoa") then
            html[#html+1] = ui_helper.createLabel(T"Username: ", content["wan_ppp_user_name"])
            html[#html+1] = ui_helper.createLabel(T"Password:", content["wan_ppp_password"])
        end

        if (content["wan_proto"] == "static") then
            html[#html+1] = ui_helper.createLabel(T"Static IP Address:", content["wan_static_ipaddr"])
            html[#html+1] = ui_helper.createLabel(T"Static Subnet Mask:", content["wan_static_submsk"])
            html[#html+1] = ui_helper.createLabel(T"Static Gateway:", content["wan_static_gatewayip"])
            html[#html+1] = ui_helper.createLabel(T"Static Primary DNS: ", content["wan_static_pri_dns"])
            html[#html+1] = ui_helper.createLabel(T"Static Secondary DNS: ", content["wan_static_sec_dns"])
        end
        if  (wan_type == "adsl") then
            if (content["wan_proto"] == "pppoe" or content["wan_proto"] == "pppoa") then
                html[#html+1] = ui_helper.createLabel(T"VPI Number: ", content["wan_ppp_vpi_number"])
                html[#html+1] = ui_helper.createLabel(T"VCI Number: ", content["wan_ppp_vci_number"])
            else
                html[#html+1] = ui_helper.createLabel(T"VPI Number: ", content["wan_ipoe_vpi_number"])
                html[#html+1] = ui_helper.createLabel(T"VCI Number: ", content["wan_ipoe_vci_number"])
            end
        end
        if (content["wan_proto"] == "pppoe" and content["vlan_enabled"] == "1") then
            if (wan_type == "vdsl") then
                html[#html+1] = ui_helper.createLabel(T"VLAN ID: ", content["id_vlan_vdsl"])
            end
            if (wan_type == "eth") then
                html[#html+1] = ui_helper.createLabel(T"VLAN ID: ", content["id_vlan_eth"])
            end
        end
        ngx.print(html)
    %>
  </fieldset>
</div>
<script type="text/javascript">
var old_isp = $("select[name='isp']").val();
var old_vlan = $("input[name='vlan_enabled']").val();
var old_vlanid_eth = $("input[name='id_vlan_eth']").val();
var old_vlanid_vdsl = $("input[name='id_vlan_vdsl']").val();
$(document).ready(function () {
  var wan_type = $("select[name='wan_type']").val();
  var isp = $("select[name='isp']").val();
  if (wan_type != "adsl") {
    $('option[value="pppoa"]').hide();
  }
  if (!isp || (isp == "Internode")) {
    $('option[value="pppoa"]').hide();
    $('option[value="dhcp"]').hide();
    $('option[value="static"]').hide();
    if ($("select[name='wan_proto']").val() != "pppoe") {
        $("select[name='wan_proto']").val("pppoe");
        $("select[name='wan_proto']").trigger("change");
    }
  }
})

$('select[name="wan_type"]').on("change", function() {
  var wan_type = $("select[name='wan_type']").val();
  var isp = $("select[name='isp']").val();
  if ((wan_type == "adsl") && isp && (isp != "Internode")) {
    $('option[value="pppoa"]').show();
  } else {
    $('option[value="pppoa"]').hide();
    var wan_proto_el = $("select[name='wan_proto']")
    var wan_proto = wan_proto_el.val();
    if (wan_proto == "pppoa") {
        wan_proto_el.val("pppoe");
    }
  }
})

$('select[name="isp"]').on("change", function() {
  var wan_type = $("select[name='wan_type']").val();
  var isp = $("select[name='isp']").val();
  var new_vlan = $("input[name='vlan_enabled']").val();
  if (isp == "Internode") {
    $('option[value="pppoa"]').hide();
    $('option[value="dhcp"]').hide();
    $('option[value="static"]').hide();
    if ($("select[name='wan_proto']").val() != "pppoe") {
      $("select[name='wan_proto']").val("pppoe");
      $("select[name='wan_proto']").trigger("change");
    }
    if (new_vlan != 0) {
      $("input[name='vlan_enabled']").click();
    }
    $("input[name='wan_ppp_user_name']").val("@internode.on.net");
    $("input[name='wan_ppp_password']").val("default");
  } else {
    if (wan_type == "adsl"){$('option[value="pppoa"]').show();}
    $('option[value="dhcp"]').show();
    $('option[value="static"]').show();
    $("input[name='wan_ppp_user_name']").val("default@iinet.net.au");
    $("input[name='wan_ppp_password']").val("default");
    if (old_isp == isp) {
      if (old_vlan != new_vlan) {
        $("input[name='vlan_enabled']").click();
      }
      $("input[name='id_vlan_vdsl']").val(old_vlanid_vdsl);
      $("input[name='id_vlan_eth']").val(old_vlanid_eth);
    } else {
      if (isp == "Transact") {
        if (new_vlan != 1) {
          $("input[name='vlan_enabled']").click();
        }
      } else {
        if (new_vlan != 0) {
          $("input[name='vlan_enabled']").click();
        }
      }
      $("input[name='id_vlan_eth']").val(2);
      $("input[name='id_vlan_vdsl']").val(2);
    }
  }
})
</script>
