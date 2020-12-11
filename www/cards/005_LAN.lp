<%
-- Enable localization
gettext.textdomain('webui-core')

local table = table
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local format, find, sub = string.format, string.find, string.sub
local tonumber = tonumber

print=log
local tprint=require("tch.tableprint")

local dhcpState_text = ""
local dhcpState

local mapParams = {
    dhcpState = "uci.dhcp.dhcp.@lan.ignore",
    localdevIP = "uci.network.interface.@lan.ipaddr",
    localdevmask = "uci.network.interface.@lan.netmask",
    localIPv6 = "uci.network.interface.@lan.ipv6",
}
content_helper.getExactContent(mapParams)
localIPv6Prefix = proxy.get("rpc.network.interface.@lan.ip6prefix_assignment")[1].value

if mapParams["dhcpState"] == "" or mapParams["dhcpState"] == "0" then
    dhcpState_text = T"DHCP enabled"
    dhcpState = "1"
else
    dhcpState_text = T"DHCP disabled"
    dhcpState = "0"
end
local LANv6 = "none"

if mapParams["localIPv6"] == "1" then
    LANv6 = "noprefix"
    if localIPv6Prefix ~= nil and localIPv6Prefix ~= "" then
        LANv6 = "prefix"
    end
end

local ipv6_state_map = {
    none = T"IPv6 Disabled",
    noprefix = T"IPv6 Not Assigned",
    prefix = T"IPv6 Assigned",
}

setmetatable(ipv6_state_map, untaint_mt)

local ipv6_light_map = {
    none = "off",
    noprefix = "orange",
    prefix = "green",
}
setmetatable(ipv6_light_map, untaint_mt)

local modalPath = nil
local switchName = nil
local session = ngx.ctx.session
if session:hasAccess("/modals/ethernet-modal.lp") then
    modalPath = "/modals/ethernet-modal.lp"
end
%>
<div class="span3">
  <div class="smallcard">

    <%= ui_helper.createCardHeader(T"Local Network", modalPath, switchName, nil) %>

    <div class="content">

      <%
        ngx.print(
            ui_helper.createSimpleLight(dhcpState, dhcpState_text, { light = { id =  "LAN_DHCP_LEDStatus" }, span = { id =  "LAN_DHCP_Status" } } ),
            '<p class="subinfos">',
            format(T'Gateway IP is <strong id="Gateway_Ip">%s</strong> and netmask is <strong id="Netmask_Ip">%s</strong>', mapParams["localdevIP"], mapParams["localdevmask"]),
            '</p>',
            ui_helper.createSimpleLight(nil, ipv6_state_map[LANv6] or T"Unknown", { light = { class = ipv6_light_map[LANv6] or "red" } })
        )
      %>

    </div>
  </div>
</div>
