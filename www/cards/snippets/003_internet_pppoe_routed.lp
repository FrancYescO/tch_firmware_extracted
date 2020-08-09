--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")

local table = table
local format = string.format

local content_uci = {
  wan_proto = "uci.network.interface.@wan.proto",
  wan_auto = "uci.network.interface.@wan.auto",
}
content_helper.getExactContent(content_uci)

local content_rpc = {
  wan_ppp_state = "rpc.network.interface.@wan.ppp.state",
  wan_ppp_error = "rpc.network.interface.@wan.ppp.error",
  ipaddr = "rpc.network.interface.@wan.ipaddr",
}
content_helper.getExactContent(content_rpc)

local ppp_state_map = {
    disabled = T"PPP disabled",
    disconnecting = T"PPP disconnecting",
    connected = T"PPP connected",
    connecting = T"PPP connecting",
    disconnected = T"PPP disconnected",
    error = T"PPP error",
    AUTH_TOPEER_FAILED = T"PPP authentication failed",
    NEGOTIATION_FAILED = T"PPP negotiation failed",
}

local untaint_mt = require("web.taint").untaint_mt
setmetatable(ppp_state_map, untaint_mt)

local ppp_light_map = {
    disabled = "off",
    disconnected = "red",
    disconnecting = "orange",
    connecting = "orange",
    connected = "green",
    error = "red",
    AUTH_TOPEER_FAILED = "red",
    NEGOTIATION_FAILED = "red",
}

setmetatable(ppp_light_map, untaint_mt)

local ppp_status
if content_uci.wan_auto ~= "0" then
  -- WAN enabled
  content_uci.wan_auto = "1"
  ppp_status = format("%s", content_rpc.wan_ppp_state) -- untaint
  if ppp_status == "" or ppp_status == "authenticating" then
    ppp_status = "connecting"
  end

  if not (content_rpc.wan_ppp_error == "" or content_rpc.wan_ppp_error == "USER_REQUEST") then
    if ppp_state_map[content_rpc.wan_ppp_error] then
        ppp_status = content_rpc.wan_ppp_error
    else
        ppp_status = "error"
    end
  end
else
  -- WAN disabled
  ppp_status = "disabled"
end

local modalPath = nil

local session = ngx.ctx.session
if session:hasAccess("/modals/internet-modal.lp") then
    modalPath = "/modals/internet-modal.lp"
end
  ngx.print('\
\
  ');  ngx.print( ui_helper.createSimpleLight(nil, ppp_state_map[ppp_status], { light = { class = ppp_light_map[ppp_status] } }) ); ngx.print('\
  ');  
    if ppp_status == "connected" then
        ngx.print('<p class="subinfos">',
          format(T'WAN IP is <strong>%s</strong>', content_rpc["ipaddr"]),
          '</p>'
        )
    end
    ngx.print('\
'); 