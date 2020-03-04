--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local ajax_helper = require("web.ajax_helper")
local post_helper = require("web.post_helper")
local tonumber = tonumber
local untaint = string.untaint

-- State data
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

local cvtBoolean = {
    ["0"] = "1",
    ["1"] = "0",
}

local ajax_attr = {
    span = {
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

function get_dhcp_state(wan_auto, ipaddr)
    -- Figure out interface state
    if wan_auto ~= "0" then
        if ipaddr:len() > 0 then
            return "connected"
        else
            return "connecting"
        end
    else
        return "disabled"
    end
end

-- Shortcuts to validation helpers to make lines shorter
local vB = post_helper.validateBoolean

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

-- Configurable data
local mapParams = {
    uci_wan_auto = "uci.network.interface.@wan.auto",
    uci_wan_peerdns = "uci.network.interface.@wan.peerdns",
    uci_wan_username = "uci.network.interface.@ppp.username",
    uci_wan_password = "uci.network.interface.@ppp.password",
    uci_pppv_username = "uci.network.interface.@pppv.username",
    uci_pppv_password = "uci.network.interface.@pppv.password",
}

local content_params = {
    variant = "uci.env.var.iinet_variant",
}
content_helper.getExactContent(content_params)
if content_params.variant == "novas" then
    mapParams.uci_pppv_username = "uci.network.interface.@pppv.username"
    mapParams.uci_pppv_password = "uci.network.interface.@pppv.password"
end

-- Shortcuts to validation helpers to make lines shorter
local vNES = post_helper.validateNonEmptyString
local gVP = post_helper.getValidationPassword

local mapValid = {
    uci_wan_auto = vB,
    uci_wan_peerdns = validPeerdns,
    uci_wan_username = function(value, object, key)
        local ok, msg = vNES(value)
        if ok then
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
            object["uci_pppv_password"] = object["uci_wan_password"]
            return true
        else
            return ok, msg
        end
    end,
    uci_pppv_username = function(value,object)
      return true
    end,
    uci_pppv_password = function(value,object)
      return true
    end,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

-- default value
if content["uci_wan_auto"] ~= "0" then
    content["uci_wan_auto"] = "1"
end
if content["uci_wan_peerdns"] ~= "0" then
    content["uci_wan_peerdns"] = "1"
end

-- Non-configurable data
local cs = {
    ipaddr = "rpc.network.interface.@wan.ipaddr",
    nexthop = "rpc.network.interface.@wan.nexthop",
    dns = "rpc.network.interface.@wan.dnsservers",
}

for i,v in ipairs(proxy.getPN("rpc.network.interface.", true)) do
    local intf = string.match(v.path, "rpc%.network%.interface%.@([^%.]+)%.")
    if intf then
        if intf == "6rd" then
            cs.ip6addr = "rpc.network.interface.@6rd.ip6addr"
        elseif intf == "wan6" then
            cs.ip6addr = "rpc.network.interface.@wan6.ip6addr"
        end
    end
end

ajax_helper.handleAjaxQuery(cs, function(c)
    -- this will add the HTML for the light
    local ds = get_dhcp_state(content["uci_wan_auto"], c["ipaddr"])
    ajax_attr_light.light.class = dhcp_light_map[ds]
    c.wan_status = ui_helper.createSimpleLight(nil, dhcp_state_map[ds], ajax_attr_light)
end)
-- will stop in handleAjaxQuery if it is an actual AJAX query
content_helper.getExactContent(cs)

dhcp_state = get_dhcp_state(content["uci_wan_auto"], cs["ipaddr"])

-- dhcp lease data
cs["leaseobtained"] = ""
cs["leaseexpires"] = ""
if dhcp_state == "connected" then
    local dhcp_lease = {
        uptime = "rpc.system.uptime",
        connect_time = "uci.network.interface.@wan.connect_time",
        lease = "uci.network.interface.@wan.lease",
        lease_expires = "uci.network.interface.@wan.lease_expires",
    }

    content_helper.getExactContent(dhcp_lease)

    cs["leaseobtained"] = os.date("%F %T", os.time() - (tonumber(dhcp_lease["uptime"]) - (tonumber(dhcp_lease["lease_expires"]) - tonumber(dhcp_lease["lease"]))))
    cs["leaseexpires"] = os.date("%F %T", os.time() + (tonumber(dhcp_lease["lease_expires"]) - tonumber(dhcp_lease["uptime"])))
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
<legend>');  ngx.print( T"DHCP connection" ); ngx.print('</legend>\
\
');  
    local html = {}
    ajax_attr_light.light.class = dhcp_light_map[dhcp_state]
    html[#html + 1] = ui_helper.createLight(T"Status", nil, dhcp_state_map[dhcp_state], ajax_attr_light)
    local attr
    local uci_wans_enable = proxy.get("uci.wansensing.global.enable")[1].value
    if uci_wans_enable == "1" then
        attr = { group = { class = "hide" } }
    end
    html[#html+1] = ui_helper.createSwitch(T"Enabled", "uci_wan_auto", content["uci_wan_auto"], attr)

    ajax_attr.span.id = "ipaddr"
    html[#html+1] = ui_helper.createLabel(T"IP address", cs["ipaddr"], ajax_attr)
if cs["ip6addr"] and cs["ip6addr"]:len() > 0 then
    ajax_attr.span.id = "ip6addr"
    html[#html+1] = ui_helper.createLabel(T"IPv6 address", cs["ip6addr"], ajax_attr)
end
    ajax_attr.span.id = "nexthop"
    html[#html+1] = ui_helper.createLabel(T"Gateway", cs["nexthop"], ajax_attr)
    ajax_attr.span.id = "dns"
    html[#html+1] = ui_helper.createLabel(T"DNS servers", cs["dns"], ajax_attr)
    html[#html+1] = ui_helper.createLabel(T"Lease obtained", cs["leaseobtained"])
    html[#html+1] = ui_helper.createLabel(T"Lease expires", cs["leaseexpires"])

    ngx.print(html)
  ngx.print('\
\
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