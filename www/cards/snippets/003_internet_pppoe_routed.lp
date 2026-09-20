--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")

local table = table
local format, upper = string.format, string.upper

local function getNetIntfPath(protocol)
	local uciPath = "uci.network.interface.@wan."
	local rpcPath = "rpc.network.interface.@wan."

	local content_wan = {
		wan_protype = "uci.network.interface.@wan.proto",
	}
	content_helper.getExactContent(content_wan)

	if content_wan.wan_protype ~= protocol then
		uciPath = "uci.network.interface.@wan2."
		rpcPath = "rpc.network.interface.@wan2."
	end

	return uciPath, rpcPath
end

local uciWanPath, rpcWanPath = getNetIntfPath("pppoe")

local content_uci = {
  wan_proto = uciWanPath .. "proto",
  wan_auto = uciWanPath .. "auto",
}
content_helper.getExactContent(content_uci)

-- Fetching all available wan interfaces
local firewall_zone = proxy.get("uci.firewall.zone.")
local firewall_zone_path = content_helper.convertResultToObject("uci.firewall.zone.",firewall_zone)
local all_intfs = {}
for _, v in ipairs(firewall_zone_path) do
  if v["wan"] == "1" and v["name"] ~= "mgmt" then
    all_intfs[v["name"]] = proxy.get("rpc.network.interface.@"..v["name"]..".ipaddr")
  end
end

local content_rpc = {
  wan_ppp_state = rpcWanPath .. "ppp.state",
  wan_ppp_error = rpcWanPath .. "ppp.error",
  ipaddr = rpcWanPath .. "ipaddr",
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

local switchName
local modalPath

local session = ngx.ctx.session
if session:hasAccess("/modals/internet-modal.lp") then
    switchName = "uci_wan_auto"
    modalPath = "/modals/internet-modal.lp"
end
  ngx.print('\
\
');  ngx.print( ui_helper.createCardHeader(T"Internet Access", modalPath, switchName, content_uci.wan_auto) ); ngx.print('\
<div class="content card_bg" data-bg-text="&#xf0ec;">\
  ');  ngx.print( ui_helper.createSimpleLight(nil, ppp_state_map[ppp_status], { light = { class = ppp_light_map[ppp_status] } }) ); ngx.print('\
  <p class="subinfos">\
     ');  for k,v in pairs(all_intfs) do
           if(v[1].value and v[1].value ~= "") then
              ngx.print(format(T'%s IP is <strong>%s</strong>', upper(k), v[1].value))  ngx.print('<br>');  
           end
        end
       ngx.print('\
  </p>\
</div>\
'); 