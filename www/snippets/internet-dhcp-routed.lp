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
local dhcp_state = "Connecting"
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
      class = "span3",
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
local firewall_value = {["uci.firewall.forwarding.@"..forwdnum..".src"] = "wan",
                        ["uci.firewall.forwarding.@"..forwdnum..".dest"] = "lan",
                        ["uci.firewall.forwarding.@"..forwdnum..".name"] = "for_w2l"}
local function validateNat(value, object, key)
  local valid, msg = post_helper.validateBoolean(value, object, key)
  if valid and value ~= proxy.get("uci.firewall.zone.@wan.masq")[1].value then
    proxy.set("uci.firewall.zone.@wan.conntrack", "1")
    local key = "forwarding"..post_helper.getRandomKey()
    if value == "1" then
        proxy.set("uci.firewall.forwarding.@wan_lan.enabled", "0")
    else
        proxy.set("uci.firewall.forwarding.@wan_lan.enabled", "1")
    end
    proxy.apply()
  end
  return valid, msg
end


-- Configurable data
local mapParams = {
    uci_wan_auto = "uci.network.interface.@wan.auto",
    uci_wan_masq = "uci.firewall.zone.@wan.masq",
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

local wan_ppp_ll_intf = proxy.get("rpc.network.interface.@wan.ppp.ll_intf")[1].value
local wan_atm_uci_path = format("uci.xtm.atmdevice.@%s.", wan_ppp_ll_intf)
local wan_ppp_over_atm = proxy.get(wan_atm_uci_path) ~= nil
if wan_ppp_over_atm then
  local content_uci_xtm = {
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

-- Non-configurable data
local cs = {
    ipaddr = "rpc.network.interface.@wan.ipaddr",
    nexthop = "rpc.network.interface.@wan.nexthop",
    dns_wan = "rpc.network.interface.@wan.dnsservers",
    dhcp_uptime = "rpc.network.interface.@wan.ppp.uptime",
    dns_loopback = "rpc.network.interface.@loopback.dnsservers", -- Added to include static dns servers configured on loopback interface (for TI custo)
}

for i,v in ipairs(proxy.getPN("rpc.network.interface.", true)) do
    local intf = match(v.path, "rpc%.network%.interface%.@([^%.]+)%.")
    if intf then
        if intf == "6rd" then
            cs.ip6addr = "rpc.network.interface.@6rd.ip6addr"
      	    cs.ip6prefix = "rpc.network.interface.@6rd.ip6prefix"
      	    cs.dnsv6 = "rpc.network.interface.@6rd.dnsservers"
        elseif intf == "wan6" then
            cs.ip6addr = "rpc.network.interface.@wan6.ip6addr"
      	    cs.ip6prefix = "rpc.network.interface.@wan6.ip6prefix"
      	    cs.dnsv6 = "rpc.network.interface.@wan6.dnsservers"
            break
	 elseif intf == "wan" then
            cs.ip6addr = "rpc.network.interface.@wan.ip6addr"
            cs.ip6prefix = "rpc.network.interface.@wan.ip6prefix"
        end
    end
end

local route_sys_content = content_helper.getMatchedContent ("sys.class.iproutes.")
local GW = ""
for _, v in pairs (route_sys_content) do
   if (v["Destination"] == "default") then 
      GW = v["Gateway"]
   end
end
local function checklease(state)
  if state == "connected" then
    local dhcp_lease = {
        uptime = "rpc.system.uptime",
        connect_time = "uci.network.interface.@wan.connect_time",
        lease = "uci.network.interface.@wan.lease",
        lease_expires = "uci.network.interface.@wan.lease_expires",
        
    }

    content_helper.getExactContent(dhcp_lease)

    local lo = os.date("%F %T", os.time() - (tonumber(dhcp_lease["uptime"]) - (tonumber(dhcp_lease["lease_expires"]) - tonumber(dhcp_lease["lease"]))))
    local le = os.date("%F %T", os.time() + (tonumber(dhcp_lease["lease_expires"]) - tonumber(dhcp_lease["uptime"])))
    return lo,le
  end
  return "", ""
end




ajax_helper.handleAjaxQuery(cs, function(c)
    -- this will add the HTML for the light
    local ds = get_dhcp_state(content["uci_wan_auto"], c["ipaddr"])
    ajax_attr_light.light.class = dhcp_light_map[ds]
    c.wan_status = ui_helper.createSimpleLight(nil, dhcp_state_map[ds], ajax_attr_light)
    c.dhcp_uptime = post_helper.secondsToTime(tonumber(c.dhcp_uptime)) or ""
    -- dhcp lease data
  
    if ds == "connected" then
        local dhcp_lease = {
            uptime = "rpc.system.uptime",
            connect_time = "uci.network.interface.@wan.connect_time",
            lease = "uci.network.interface.@wan.lease",
            lease_expires = "uci.network.interface.@wan.lease_expires",
        }
    
        content_helper.getExactContent(dhcp_lease)
    
        c["leaseobtained"] = os.date("%F %T", os.time() - (tonumber(dhcp_lease["uptime"]) - (tonumber(dhcp_lease["lease_expires"] ~="" and dhcp_lease["lease_expires"] or 0) - tonumber(dhcp_lease["lease"] ~="" and dhcp_lease["lease"] or 0))))
        c["leaseexpires"] = os.date("%F %T", os.time() + (tonumber(dhcp_lease["lease_expires"] ~="" and dhcp_lease["lease_expires"] or 0) - tonumber(dhcp_lease["uptime"])))
    else
        c["leaseobtained"] = ""
        c["leaseexpires"] = ""
    end
end)



-- will stop in handleAjaxQuery if it is an actual AJAX query
content_helper.getExactContent(cs)

cs.dhcp_uptime = post_helper.secondsToTime(tonumber(cs["dhcp_uptime"])) or ""
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
    local dhcp_lease = {
        uptime = "rpc.system.uptime",
        connect_time = "uci.network.interface.@wan.connect_time",
        lease = "uci.network.interface.@wan.lease",
        lease_expires = "uci.network.interface.@wan.lease_expires",
    }

    content_helper.getExactContent(dhcp_lease)

    cs["leaseobtained"] = os.date("%F %T", os.time() - (tonumber(dhcp_lease["uptime"]) - (tonumber(dhcp_lease["lease_expires"] ~="" and dhcp_lease["lease_expires"] or 0) - tonumber(dhcp_lease["lease"] ~="" and dhcp_lease["lease"] or 0))))
    cs["leaseexpires"] = os.date("%F %T", os.time() + (tonumber(dhcp_lease["lease_expires"] ~="" and dhcp_lease["lease_expires"] or 0) - tonumber(dhcp_lease["uptime"])))
end

ngx.print('\
\
<fieldset>',
ui_helper.createMessages(message_helper.popMessages()), '\
<legend>', T"DHCP Connection", '</legend>');
    local html = {}
    ajax_attr_light.light.class = dhcp_light_map[dhcp_state]
    html[#html + 1] = ui_helper.createLight(T"Status", nil, dhcp_state_map[dhcp_state], ajax_attr_light)
    html[#html+1] = ui_helper.createSwitch(T"Enabled", "uci_wan_auto", content["uci_wan_auto"])
    html[#html + 1] = ui_helper.createSwitch(T"NAT", "uci_wan_masq", content.uci_wan_masq)
    ajax_attr.span.id = "dhcp_uptime"
    local uptime = T"NA"
    html[#html+1] = ui_helper.createLabel(T"Uptime", cs["dhcp_uptime"], ajax_attr)
    ajax_attr.span.id = "ipaddr"
    html[#html+1] = ui_helper.createLabel(T"IP address", cs["ipaddr"], ajax_attr)
    if cs["ip6addr"] and cs["ip6addr"]:len() > 0 then
        ajax_attr.span.id = "ip6addr"
        html[#html+1] = ui_helper.createLabel(T"IPv6 address", cs["ip6addr"], ajax_attr)
    end
    ajax_attr.span.id = "nexthop"
    html[#html+1] = ui_helper.createLabel(T"Gateway", cs["nexthop"], ajax_attr)
    ajax_attr.span.id = "dns_wan"
    html[#html+1] = ui_helper.createLabel(T"DNS servers", cs["dns_wan"], ajax_attr)
    ajax_attr.span.id = "leaseobtained"
    html[#html+1] = ui_helper.createLabel(T"Lease Obtained", cs["leaseobtained"], ajax_attr)
    ajax_attr.span.id = "leaseexpires"
    html[#html+1] = ui_helper.createLabel(T"Lease Expires", cs["leaseexpires"], ajax_attr)
        if cs["ip6addr"] and cs["ip6addr"]:len() > 0 then
        ajax_attr.span.id = "ip6addr"
        html[#html+1] = ui_helper.createLabel(T"IPv6 Address", cs["ip6addr"],ajax_attr)
    end
    if cs["ip6prefix"] and cs["ip6prefix"]:len() > 0 then
        ajax_attr.span.id = "ip6prefix"
        html[#html+1] = ui_helper.createLabel(T"IPv6 Prefix", cs["ip6prefix"],ajax_attr)
    end
    if cs["dnsv6"] and cs["dnsv6"]:len() > 0 then
        ajax_attr.span.id = "dnsv6"
        html[#html+1] = ui_helper.createLabel(T"IPv6 DNS", cs["dnsv6"],ajax_attr)
    end
    ngx.print(html, '\
</fieldset>');
