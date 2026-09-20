--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local tonumber = tonumber

-- Process POST query
local post_helper = require("web.post_helper")

-- Configurable data
local mapParams = {
    uci_wan_username = "uci.network.interface.@ppp.username",
    uci_wan_password = "uci.network.interface.@ppp.password",
}

-- Shortcuts to validation helpers to make lines shorter
local vNES = post_helper.validateNonEmptyString
local gVP = post_helper.getValidationPassword

local mapValid = {
    uci_wan_username = vNES,
    uci_wan_password = gVP(vNES),
}


local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

local content_uci = {
  wan_proto = "uci.network.interface.@wan.proto",
  wan_domain = "uci.network.interface.@ppp.domain",
  wan_auto = "uci.network.interface.@wan.auto",
}
content_helper.getExactContent(content_uci)

-- Non-configurable data
local cs = {
    ipaddr = "rpc.network.interface.@wan.ipaddr",
    nexthop = "rpc.network.interface.@wan.nexthop",
    ipv6addr = "rpc.network.interface.@wan6.ip6addr",
    dns = "rpc.network.interface.@wan.dnsservers",
    ipv6prefix = "rpc.network.interface.@wan6.ip6prefix",
    dnsv6 = "rpc.network.interface.@wan6.dnsservers",
}

content_helper.getExactContent(cs)

-- Figure out interface state
local dhcp_state = "connecting"
local dhcp_state_map = {
    disabled = T"disabled",
    connected = T"connected",
    connecting = T"connecting",
}

local dhcp_light_map = {
  disabled = "off",
  connecting = "orange",
  connected = "green",
}

if content_uci["wan_auto"] ~= "0" then
    content_uci["wan_auto"] = "1"
    if cs["ipaddr"]:len() > 0 then
        dhcp_state = "connected"
    else
        dhcp_state = "connecting"
    end
else
    dhcp_state = "disabled"
end

-- dhcp lease data
cs["leaseobtained"] = ""
cs["leaseexpires"] = ""
if dhcp_state == "connected" then
    local dhcp_lease = {
        uptime = "rpc.system.uptime",
        lease = "uci.network.interface.@wan.lease",
        lease_expires = "uci.network.interface.@wan.lease_expires",
    }

    content_helper.getExactContent(dhcp_lease)
    dhcp_lease.uptime = tonumber(dhcp_lease["uptime"])
    dhcp_lease.lease = tonumber(dhcp_lease["lease"])
    dhcp_lease.lease_expires = tonumber(dhcp_lease["lease_expires"])
    if dhcp_lease.uptime and dhcp_lease.lease and dhcp_lease.lease_expires then
        cs["leaseobtained"] = os.date("%F %T", os.time() - (dhcp_lease["uptime"] - (dhcp_lease["lease_expires"] - dhcp_lease["lease"])))
    else
        cs["leaseobtained"] = ""
    end
    if dhcp_lease.uptime and dhcp_lease.lease_expires then
        cs["leaseexpires"] = os.date("%F %T", os.time() + (dhcp_lease["lease_expires"] - dhcp_lease["uptime"]))
    else
        cs["leaseexpires"] = ""
    end
end

  ngx.print('\
\
<fieldset>\
<legend>');  ngx.print( T"DHCP connection" ); ngx.print('</legend>\
\
');  
    local html = {}
    html[#html + 1] = ui_helper.createLight(T"Status", nil, dhcp_state_map[dhcp_state], { light = { class = dhcp_light_map[dhcp_state] } })

    --html[#html+1] = ui_helper.createSwitch(T"Enabled", "uci_wan_auto", content["uci_wan_auto"])

    html[#html+1] = ui_helper.createLabel(T"IP address", cs["ipaddr"])
    html[#html+1] = ui_helper.createLabel(T"Gateway", cs["nexthop"])
    html[#html+1] = ui_helper.createLabel(T"DNS servers", cs["dns"])
    html[#html+1] = ui_helper.createLabel(T"IPv6 address", cs["ipv6addr"])
    html[#html+1] = ui_helper.createLabel(T"IPv6 Prefix", cs["ipv6prefix"])
    html[#html+1] = ui_helper.createLabel(T"IPv6 DNS", cs["dnsv6"])
    html[#html+1] = ui_helper.createLabel(T"Lease obtained", cs["leaseobtained"])
    html[#html+1] = ui_helper.createLabel(T"Lease expires", cs["leaseexpires"])

    ngx.print(html)
  ngx.print('\
\
</fieldset>\
\
<fieldset>\
');  
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.print('\
<legend>');  ngx.print( T"PPP Credential Setting" ); ngx.print('</legend>\
\
');  
    local html = {}

    -- PPP username
    local class_username = {
      input = {
        maxlength= "128",
        class = "span6",
      }
    }

    html[#html + 1] = "<div class='control-group'><label class='control-label'>" .. T"Username" .. "</label><div class='controls'>"
    html[#html + 1] = ui_helper.createSimpleInputText("uci_wan_username", content["uci_wan_username"], class_username, helpmsg["uci_wan_username"])
    html[#html + 1] = "</div></div>"

    -- PPP password
    local class_password = class_username
    html[#html + 1] = ui_helper.createInputPassword(T"Password", "uci_wan_password", content["uci_wan_password"], class_username, helpmsg["uci_wan_password"])
    ngx.print(html)
  ngx.print('\
\
</fieldset>\
'); 