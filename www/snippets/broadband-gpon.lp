--pretranslated: do not change this file
 
-- Enable localization

gettext.textdomain('webui-core')

local format = string.format

local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")

local mapParams = {
    gpon_state = "rpc.optical.Interface.1.Status",
    optical_signal_level = "rpc.optical.Interface.1.OpticalSignalLevel",
    transmit_optical_level = "rpc.optical.Interface.1.TransmitOpticalLevel",
}
local mapValid = {
    gpon_state = function(value, object, key)
     return true
   end,
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

local gpon_state_map = {
    connected = T"Connected",
    connecting = T"Connecting",
}

local gpon_status = "connecting"
if content.gpon_state == "INIT" then
    gpon_state_map.connecting = T"Connecting: NoSignal"
elseif content.gpon_state == "OPERATION" then
    gpon_status = "connected"
end

local gpon_light_map = {
    connecting = "orange",
    connected = "green",
}

  ngx.print('\
\
<fieldset>\
  <legend>');  ngx.print( T"Physical link status" ); ngx.print('</legend>\
\
  ');  
    local html = {}
    -- Label that shows gpon status
    html[#html + 1] = ui_helper.createLight(T"Status",nil, gpon_state_map[gpon_status], { light = { class = gpon_light_map[gpon_status] } })
    html[#html + 1] = ui_helper.createLabel(T"OpticalSignalLevel",T(content["optical_signal_level"].." dBm"))
    html[#html + 1] = ui_helper.createLabel(T"TransmitOpticalLevel",T(content["transmit_optical_level"].." dBm"))
    ngx.print(html)
    ngx.print('\
</fieldset>\
'); 