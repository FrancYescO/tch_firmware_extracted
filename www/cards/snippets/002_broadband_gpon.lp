--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format, match = string.format, string.match
local floor = math.floor
local tonumber = tonumber

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")

local gpon_state = proxy.get("rpc.optical.Interface.1.Status") and proxy.get("rpc.optical.Interface.1.Status")[1].value or ""

local gpon_status = gpon_state and gpon_state == "Up" and "connected" or "connecting"
local gpon_light_map = {
  connecting = "orange",
  connected = "green"
}

local session = ngx.ctx.session
local modalPath

if session:hasAccess("/modals/broadband-modal.lp") then
  modalPath = "modals/broadband-modal.lp"
end
  ngx.print('\
\
');  ngx.print( ui_helper.createCardHeader(T"Broadband", modalPath) ); ngx.print('\
<div class="content">\
');  
  local html = {}
  html[#html + 1] = ui_helper.createSimpleLight(nil, T(gpon_state), { light = { class = gpon_light_map[gpon_status] } })
  ngx.print(html)
  ngx.print('\
</div>\
'); 