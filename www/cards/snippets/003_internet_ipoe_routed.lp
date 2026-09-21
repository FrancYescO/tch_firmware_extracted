--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")

local format = string.format

local session = ngx.ctx.session
local ipoe_ifname = "ipoe"
local basepath_ipoe_uci = format("uci.network.interface.@%s.", ipoe_ifname)
local basepath_ipoe_rpc = format("rpc.network.interface.@%s.", ipoe_ifname)
local content_uci_ipoe = {
  wan_proto = basepath_ipoe_uci .. "proto",
  wan_auto = basepath_ipoe_uci .. "auto",
}
content_helper.getExactContent(content_uci_ipoe)
local content_rpc_ipoe = {
  wan_state = basepath_ipoe_rpc .. "up",
  ipaddr = basepath_ipoe_rpc .. "ipaddr",
}
content_helper.getExactContent(content_rpc_ipoe)
local ipoe_state_map = {
    disabled = T"IPoE disabled",
    connected = T"IPoE connected",
    connecting = T"IPoE connecting",
}
setmetatable(ipoe_state_map, untaint_mt)
local ipoe_light_map = {
    disabled = "off",
    connecting = "orange",
    connected = "green",
}
setmetatable(ipoe_light_map, untaint_mt)
local ipoe_status
if content_uci_ipoe.wan_auto ~= "0" then
  -- ipoe enabled
  content_uci_ipoe.wan_auto = "1"
  ipoe_status = format("%s", content_rpc_ipoe.wan_state) -- untaint
  if ipoe_status == "1" then
    ipoe_status = "connected"
  else
    ipoe_status = "connecting"
  end
else
  -- ipoe disabled
  ipoe_status = "disabled"
end


  ngx.print('\
\
  ');  ngx.print( ui_helper.createSimpleLight(nil, ipoe_state_map[ipoe_status], { light = { class = ipoe_light_map[ipoe_status] } }) ); ngx.print('\
  <p class="subinfos">\
     ');  if ipoe_status == "connected" then
            ngx.print(format(T'IPoE IP is <strong>%s</strong>', content_rpc_ipoe["ipaddr"]))
        end
       ngx.print('\
  </p>\
'); 