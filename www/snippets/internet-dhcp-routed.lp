--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local ajax_helper = require("web.ajax_helper")
local tonumber = tonumber
local format, upper = string.format, string.upper

local session = ngx.ctx.session
local tech = false
if session:getrole() == "superuser" or session:getrole() == "telia" then
   tech = true
end

-- Retrieving the interface name selected from drop down list or showing the wan interface by default for further operations
local intf_selected = session:retrieve("postedIntf_internet_modal") or "wan"

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

local ajax_attr = {
    span = {
      ["data-ajaxrefresh"] = "5",
    }
}
local ajax_attr_light = {
    light = {
        class = "",
	id = "DHCP_Status_LED"
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

-- Process POST query
local post_helper = require("web.post_helper")

-- Configurable data
local mapParams = {}
mapParams["uci_wan_auto"] = format("uci.network.interface.@%s.auto", intf_selected)

local vB = post_helper.validateBoolean
local mapValid = {
    uci_wan_auto = vB,
}

-- Shortcuts to validation helpers to make lines shorter

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
-- default value
if content["uci_wan_auto"] ~= "0" then
    content["uci_wan_auto"] = "1"
end

local wan_ppp_ll_intf = proxy.get(format("rpc.network.interface.@%s.ppp.ll_intf", intf_selected))[1].value
local wan_atm_uci_path = string.format("uci.xtm.atmdevice.@%s.", wan_ppp_ll_intf)
local wan_ppp_over_atm = proxy.get(wan_atm_uci_path) ~= nil
if wan_ppp_over_atm then
  local content_uci_xtm = {
    wan_atm_ulp = wan_atm_uci_path.."ulp",
  }
  content_uci_xtm["wan_vpi"] = format("uci.network.interface.@%s.vpi", intf_selected)
  content_uci_xtm["wan_vci"] = format("uci.network.interface.@%s.vci", intf_selected)
  content_helper.getExactContent(content_uci_xtm)

  local params = {}
  local setting = false
  if content_uci_xtm.wan_vpi ~= "" then
    params[format("uci.network.interface.@%s.vpi", intf_selected)] = ""
    setting = true
  end
  if content_uci_xtm.wan_vci ~= "" then
    params[format("uci.network.interface.@%s.vci", intf_selected)] = ""
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

-- Non-configurable data
local cs = {}
cs["ipaddr"] = format("rpc.network.interface.@%s.ipaddr", intf_selected)
cs["nexthop"] = format("rpc.network.interface.@%s.nexthop", intf_selected)
cs["dns"] = format("rpc.network.interface.@%s.dnsservers", intf_selected)

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
    }
    dhcp_lease["connect_time"] = format("uci.network.interface.@%s.connect_time", intf_selected)
    dhcp_lease["lease"] = format("uci.network.interface.@%s.lease", intf_selected)
    dhcp_lease["lease_expires"] = format("uci.network.interface.@%s.lease_expires", intf_selected)

    content_helper.getExactContent(dhcp_lease)

    cs["leaseobtained"] = os.date("%F %T", os.time() - (tonumber(dhcp_lease["uptime"]) - (tonumber(dhcp_lease["lease_expires"] ~="" and dhcp_lease["lease_expires"] or 0) - tonumber(dhcp_lease["lease"] ~="" and dhcp_lease["lease"] or 0))))
    cs["leaseexpires"] = os.date("%F %T", os.time() + (tonumber(dhcp_lease["lease_expires"] ~="" and dhcp_lease["lease_expires"] or 0) - tonumber(dhcp_lease["uptime"])))
end

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
    ajax_attr.span.id = "intf_selected"
    html[#html+1] = ui_helper.createLabel(T"Interface", upper(intf_selected), ajax_attr)
    ajax_attr_light.light.class = dhcp_light_map[dhcp_state]
    html[#html + 1] = ui_helper.createLight(T"Status", nil, dhcp_state_map[dhcp_state], ajax_attr_light)

if tech then
   html[#html+1] = ui_helper.createSwitch(T"Enabled", "uci_wan_auto", content["uci_wan_auto"])
end

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
<script>\
$("select#interface").change(function()\
{\
  var res = $(this).val().toUpperCase();\
  $("#intf_selected").text(res);\
});\
</script>\
'); 