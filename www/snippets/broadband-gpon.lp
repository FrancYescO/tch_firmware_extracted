--pretranslated: do not change this file

--NG-100650 Set 4th Ethernet Port as WAN or LAN Port on GUI
-- Enable localization

gettext.textdomain('webui-core')

local format = string.format

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

local mapParams = {
    gpon_state = "rpc.optical.Interface.1.Status",
    optical_signal_level = "rpc.optical.Interface.1.OpticalSignalLevel",
    transmit_optical_level = "rpc.optical.Interface.1.TransmitOpticalLevel",
}
content_helper.getExactContent(mapParams)

local gpon_state_map = {
    connected = T"Connected",
    connecting = T"Connecting",
}

local gpon_status = "connecting"
if mapParams.gpon_state == "INIT" then
    gpon_state_map.connecting = T"Connecting: NoSignal"
elseif mapParams.gpon_state == "OPERATION" then
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
    html[#html + 1] = ui_helper.createLabel(T"OpticalSignalLevel",T(mapParams["optical_signal_level"].." dBm"))
    html[#html + 1] = ui_helper.createLabel(T"TransmitOpticalLevel",T(mapParams["transmit_optical_level"].." dBm"))
    ngx.print(html)
    ngx.print('\
</fieldset>\
'); 