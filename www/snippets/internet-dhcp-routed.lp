--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local ajax_helper = require("web.ajax_helper")
local tonumber = tonumber
local match, format = string.match, string.format
-- State data
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
local wanIntf = post_helper.getActiveInterface()
local wan6Intf = post_helper.getActiveInterface_v6()
local firewall_zone = proxy.get("uci.firewall.zone.")
local firewall_zone_path = content_helper.convertResultToObject("uci.firewall.zone.",firewall_zone)
local zonenum = ""
for _, v in ipairs(firewall_zone_path) do
  if (v["name"] == "wan") then
    zonenum = v["paramindex"]
    break
  end
end
local firewall_forwarding = proxy.get("uci.firewall.forwarding.")
local firewall_forwarding_path = content_helper.convertResultToObject("uci.firewall.forwarding.",firewall_forwarding)
local forwdnum = ""
for _, v in ipairs(firewall_forwarding_path) do
  if (v["src"] == "wan" and v["dest"] == "lan") then
    forwdnum = v["paramindex"]
    break
  end
end
local firewall_value = {["uci.firewall.forwarding.@"..forwdnum..".src"] = wanIntf,
                        ["uci.firewall.forwarding.@"..forwdnum..".dest"] = "lan",
                        ["uci.firewall.forwarding.@"..forwdnum..".name"] = "for_w2l"}
local function validateNat(value, object, key)
  return post_helper.validateNat(value, object, key, forwdnum, zonenum)
end

-- Configurable data
local mapParams = {
    uci_wan_auto = format("uci.network.interface.@%s.auto", wanIntf),
    uci_wan_masq = "uci.firewall.zone."..zonenum..".masq"
}

-- Shortcuts to validation helpers to make lines shorter
local vB = post_helper.validateBoolean

local mapValid = {
    uci_wan_auto = vB,
    uci_wan_masq = validateNat,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
-- default value
if content["uci_wan_auto"] ~= "0" then
    content["uci_wan_auto"] = "1"
end

local wan_ppp_ll_intf = proxy.get(format("rpc.network.interface.@%s.ppp.ll_intf", wanIntf))[1].value
local wan_atm_uci_path = format("uci.xtm.atmdevice.@%s.", wan_ppp_ll_intf)
local wan_ppp_over_atm = proxy.get(wan_atm_uci_path) ~= nil
if wan_ppp_over_atm then
  local content_uci_xtm = {
    wan_atm_ulp = wan_atm_uci_path.."ulp",
    wan_vpi = format("uci.network.interface.@%s.vpi", wanIntf),
    wan_vci = format("uci.network.interface.@%s.vci", wanIntf),
  }
  content_helper.getExactContent(content_uci_xtm)

  local params = {}
  local setting = false
  if content_uci_xtm.wan_vpi ~= "" then
    params[format("uci.network.interface.@%s.vpi", wanIntf)] = ""
    setting = true
  end
  if content_uci_xtm.wan_vci ~= "" then
    params[format("uci.network.interface.@%s.vci", wanIntf)] = ""
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
local cs = {
    ipaddr = format("rpc.network.interface.@%s.ipaddr", wanIntf),
    nexthop = format("rpc.network.interface.@%s.nexthop", wanIntf),
    dns_wan = format("rpc.network.interface.@%s.dnsservers", wanIntf),
    ipv6_gua = format("rpc.network.interface.@%s.ipv6uniqueglobaladdr", wan6Intf),
    dns_loopback = "rpc.network.interface.@loopback.dnsservers", -- Added to include static dns servers configured on loopback interface (for TI custo)
}

for i,v in ipairs(proxy.getPN("rpc.network.interface.", true)) do
    local intf = match(v.path, "rpc%.network%.interface%.@([^%.]+)%.")
    if intf then
        if intf == "6rd" then
            cs.ip6addr = "rpc.network.interface.@6rd.ip6addr"
	    cs.ip6prefix = "rpc.network.interface.@6rd.ip6prefix"
	    cs.dnsv6 = "rpc.network.interface.@6rd.dnsservers"
        elseif intf == wan6Intf then
            cs.ip6addr = "rpc.network.interface.@"..wan6Intf..".ip6addr"
	    cs.ip6prefix = "rpc.network.interface.@"..wan6Intf..".ip6prefix"
	    cs.dnsv6 = "rpc.network.interface.@"..wan6Intf..".dnsservers"
            break
        elseif intf == "wan" or intf == "titan" then
              cs.ip6addr = format("rpc.network.interface.@%s.ip6addr", wanIntf)
              cs.ip6prefix = format("rpc.network.interface.@%s.ip6prefix" , wanIntf)
        end
    end
end

local dhcp_lease = {
        uptime = "rpc.system.uptime",
        connect_time = format("uci.network.interface.@%s.connect_time", wanIntf),
        lease = format("uci.network.interface.@%s.lease", wanIntf),
        lease_expires = format("uci.network.interface.@%s.lease_expires", wanIntf),
}

function getLeaseTime(uptime, lease, expires)
    local leaseobtained = os.date("%F %T", os.time() - (tonumber(uptime) - (tonumber(expires ~="" and expires or 0) - tonumber(lease ~="" and lease or 0))))
    local leaseexpires = os.date("%F %T", os.time() + (tonumber(expires ~="" and expires or 0) - tonumber(uptime)))
    return leaseobtained, leaseexpires
end

ajax_helper.handleAjaxQuery(cs, function(c)
    -- this will add the HTML for the light
    local ds = get_dhcp_state(content["uci_wan_auto"], c["ipaddr"])
    ajax_attr_light.light.class = dhcp_light_map[ds]
    c.wan_status = ui_helper.createSimpleLight(nil, dhcp_state_map[ds], ajax_attr_light)
    if ds == "connected" then
        content_helper.getExactContent(dhcp_lease)
        c["leaseobtained"], c["leaseexpires"] = getLeaseTime(dhcp_lease["uptime"],  dhcp_lease["lease"], dhcp_lease["lease_expires"])
    end
end)
-- will stop in handleAjaxQuery if it is an actual AJAX query
content_helper.getExactContent(cs)

cs.dns = content_helper.getMergedList(cs.dns_wan, cs.dns_loopback)

-- account for inconsistencies in DNS display format by removing extra spaces
if cs["dns"] and cs["dns"]:len() > 0 then
    cs["dns"] = cs["dns"]:gsub("%s+", "")
end
if cs["dnsv6"] and cs["dnsv6"]:len() > 0 then
    cs["dnsv6"] = cs["dnsv6"]:gsub("%s+", "")
end

dhcp_state = get_dhcp_state(content["uci_wan_auto"], cs["ipaddr"])

-- dhcp lease data
cs["leaseobtained"] = ""
cs["leaseexpires"] = ""
if dhcp_state == "connected" then
    content_helper.getExactContent(dhcp_lease)
    cs["leaseobtained"],  cs["leaseexpires"] = getLeaseTime(dhcp_lease["uptime"],  dhcp_lease["lease"], dhcp_lease["lease_expires"])
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
    ajax_attr_light.light.class = dhcp_light_map[dhcp_state]
    html[#html + 1] = ui_helper.createLight(T"Status", nil, dhcp_state_map[dhcp_state], ajax_attr_light)
    html[#html+1] = ui_helper.createSwitch(T"Enabled", "uci_wan_auto", content["uci_wan_auto"])
    html[#html + 1] = ui_helper.createSwitch(T"NAT", "uci_wan_masq", content.uci_wan_masq)
    ajax_attr.span.id = "ipaddr"
    html[#html+1] = ui_helper.createLabel(T"IPv4 address", cs["ipaddr"], ajax_attr)
    ajax_attr.span.id = "nexthop"
    html[#html+1] = ui_helper.createLabel(T"Gateway", cs["nexthop"], ajax_attr)
    ajax_attr.span.id = "dns"
    html[#html+1] = ui_helper.createLabel(T"DNS servers", cs["dns"],ajax_attr)
    if cs["ip6addr"] and cs["ip6addr"]:len() > 0 then
    ajax_attr.span.id = "ip6addr"
    html[#html+1] = ui_helper.createLabel(T"IPv6 address", cs["ip6addr"], ajax_attr)
    end
    if cs["ipv6_gua"] and cs["ipv6_gua"]:len() > 0 then
    ajax_attr.span.id = "ipv6gua"
    html[#html+1] = ui_helper.createLabel(T"IPv6 GUA", cs["ipv6_gua"],ajax_attr)
    end
    if cs["ip6prefix"] and cs["ip6prefix"]:len() > 0 then
    ajax_attr.span.id = "ip6prefix"
    html[#html+1] = ui_helper.createLabel(T"IPv6 Prefix", cs["ip6prefix"], ajax_attr)
    end
    if cs["dnsv6"] and cs["dnsv6"]:len() > 0 then
    -- make sure auto-refresh updates control with ONLY DNSv6 servers
    ajax_attr.span.id = "dnsv6"
    html[#html+1] = ui_helper.createLabel(T"IPv6 DNS", cs["dnsv6"], ajax_attr)
    end
    ajax_attr.span.id = "leaseobtained"
    html[#html+1] = ui_helper.createLabel(T"Lease obtained", cs["leaseobtained"], ajax_attr)
    ajax_attr.span.id = "leaseexpires"
    html[#html+1] = ui_helper.createLabel(T"Lease expires", cs["leaseexpires"], ajax_attr)

    ngx.print(html)
  ngx.print('\
\
</fieldset>\
'); 