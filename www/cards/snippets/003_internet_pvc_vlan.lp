--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
local format = string.format
local content_helper = require("web.content_helper")
local session = ngx.ctx.session
local modal = nil

local interface_name = session:retrieve("network_interface_name") or "wan"

local mapParams = {
      network_interface     = format("rpc.network.interface.@%s.ppp.ll_dev",interface_name),
      network_protocol      = format("uci.network.interface.@%s.proto",interface_name),
      network_auto          = format("uci.network.interface.@%s.auto",interface_name),
}
content_helper.getExactContent(mapParams)
local net_intf = format("%s", mapParams.network_interface) -- untaint
local lower_layer
local lower_layer_string
if net_intf == "" then
   lower_layer_string = ""
else
   local map_pvc = {
     network_vpi = format("uci.xtm.atmdevice.@%s.vpi",net_intf),
     network_vci = format("uci.xtm.atmdevice.@%s.vci",net_intf),
   }
   content_helper.getExactContent(map_pvc)
   local map_vlan = {
     network_type = format("uci.network.device.@%s.type",net_intf),
     network_vid = format("uci.network.device.@%s.vid",net_intf),
   }
   content_helper.getExactContent(map_vlan)
   local vpi = format("%s",map_pvc.network_vpi)
   if map_vlan.network_type == "8021q" then
      lower_layer = "VLAN"
      lower_layer_string = format("VLAN: %s",map_vlan.network_vid)
   elseif vpi == "" then
      lower_layer = "Other"
      lower_layer_string = "No VLAN"
   else
      lower_layer = "ATM"
      lower_layer_string = format("PVC: %s/%s",map_pvc.network_vpi,map_pvc.network_vci)
   end
end
  ngx.print('\
\
          ');  ngx.print(format('<p class=\"subinfos\">%s&nbsp', lower_layer_string))   ngx.print('\
          ');  ngx.print(format('%s: %s</p>', T"Protocol", mapParams.network_protocol))   ngx.print('\
'); 