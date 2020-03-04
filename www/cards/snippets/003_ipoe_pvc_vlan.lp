<%
-- Enable localization
gettext.textdomain('webui-core')
local format = string.format
local content_helper = require("web.content_helper")
local session = ngx.ctx.session
local modal = nil

local ipoe_ifname = "ipoe"
local mapIPoEParams = {
      network_interface     = format("rpc.network.interface.@%s.ppp.ll_dev",ipoe_ifname),
      network_protocol      = format("uci.network.interface.@%s.proto",ipoe_ifname),
      network_auto          = format("uci.network.interface.@%s.auto",ipoe_ifname),
}
content_helper.getExactContent(mapIPoEParams)
local ipoe_intf = format("%s", mapIPoEParams.network_interface) -- untaint
local ipoe_lower_layer
local ipoe_lower_layer_string
if ipoe_intf == "" then
   ipoe_lower_layer_string = ""
else
   local map_ipoe_pvc = {
     network_vpi = format("uci.xtm.atmdevice.@%s.vpi",ipoe_intf),
     network_vci = format("uci.xtm.atmdevice.@%s.vci",ipoe_intf),
   }
   content_helper.getExactContent(map_ipoe_pvc)
   local map_ipoe_vlan = {
     network_type = format("uci.network.device.@%s.type",ipoe_intf),
     network_vid = format("uci.network.device.@%s.vid",ipoe_intf),
   }
   content_helper.getExactContent(map_ipoe_vlan)
   local ipoe_vpi = format("%s",map_ipoe_pvc.network_vpi)
   if map_ipoe_vlan.network_type == "8021q" then
      ipoe_lower_layer = "VLAN"
      ipoe_lower_layer_string = format("VLAN: %s",map_ipoe_vlan.network_vid)
   elseif ipoe_vpi == "" then
      ipoe_lower_layer = "Other"
      ipoe_lower_layer_string = "No VLAN"
   else
      ipoe_lower_layer = "ATM"
      ipoe_lower_layer_string = format("PVC: %s/%s",map_ipoe_pvc.network_vpi,map_ipoe_pvc.network_vci)
   end
end
%>

          <% ngx.print(format('<p class=\"subinfos\">%s&nbsp', ipoe_lower_layer_string)) %>
          <% ngx.print(format('%s: %s</p>', T"Protocol", mapIPoEParams.network_protocol)) %>
