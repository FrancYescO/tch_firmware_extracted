--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local format = string.format
local session = ngx.ctx.session
local role = session:getrole()
local dyntab_helper = require("web.dyntab_helper")
local bmh = require("broadbandmode_helper")
local tabdata
if bmh.broadBandDetails then
  tabdata = dyntab_helper.process(bmh.broadBandDetails())
else
  tabdata = dyntab_helper.process(bmh)
end

local mode_current = tabdata.current.name
local mode_options = tabdata.options
local mode_current_val = mode_current

local wan = {
  iface = "uci.network.interface.@wan.ifname"
}
content_helper.getExactContent(wan)

-- Figure out interface state
local intf_state_map = {
  disabled = T"disabled",
  connected = T"connected",
  disconnected = T"not connected"
}

local intf_light_map = {
  disabled = "off",
  disconnected = "red",
  connected = "green"
}
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Broadband", true, true))   ngx.print('\
<div class="modal-body update">\
<form class="form-horizontal" method="post" action="modals/broadband-bridge-modal.lp">\
   ');  if mode_current_val == "ethernet" then   ngx.print('\
    <fieldset id="conn_mode" class="advanced hide">\
    <legend>');  ngx.print( T"Broadband type" ); ngx.print('</legend>\
    ');  local html = {}
      html[#html+1] = ui_helper.createLabel(T"Mode", mode_current_val)
      ngx.print(html)
       ngx.print('\
   </fieldset>\
<fieldset>\
  <legend>');  ngx.print( T"Physical link status" ); ngx.print('</legend>\
  ');  
    html = {}
    -- Label that shows Bridge status
    for intf in string.gmatch(wan.iface, "[^%s]+") do
      local intf_state = "disabled"
      -- Here we just try to remove the potential vlan id from the interface name.
      local iface = string.match(intf, "([^%.]+)") : untaint()
      local stats = {
        operstate = "sys.class.net.@" .. iface .. ".operstate",
        carrier = "sys.class.net.@" .. iface .. ".carrier"
      }
      content_helper.getExactContent(stats)

      if stats.operstate == "up" then
        intf_state = stats.carrier ~= "0" and "connected" or "disconnected"
      end
      local label = format(T"Interface %s ".. intf_state, intf)
       html[#html + 1] = ui_helper.createLight(T"Status", nil, label, {light = {class = intf_light_map[intf_state]}})
    end
    ngx.print(html)
    ngx.print('\
</fieldset>\
');  else   ngx.print('\
  <fieldset>\
    <legend>');  ngx.print( T"Broadband type" ); ngx.print('</legend>\
    ');  ngx.print(ui_helper.createLabel(T"Mode", mode_current_val))  ngx.print('\
  </fieldset>\
');  end   ngx.print('\
</form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
\
'); 