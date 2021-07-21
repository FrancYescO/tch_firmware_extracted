--pretranslated: do not change this file
 
  -- Enable localization
  gettext.textdomain('webui-core')
  local ui_helper = require("web.ui_helper")
  local content_helper = require("web.content_helper")
  local modalPath = "/modals/smarthome-modal.lp"

  local getParams = {
    ifaceState = "uci.wireless.wifi-iface.@wl0_2.state",
    apState = "uci.wireless.wifi-ap.@ap6.state",
    ssid = "uci.wireless.wifi-iface.@wl0_2.ssid"
  }
  content_helper.getExactContent(getParams)

  local status_led = getParams.ifaceState == "1" and getParams.apState == "1" and "light green" or" light off"
  ngx.print('\
\
<div class = "span3">\
  <div class = "smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"Smart Home", modalPath, nil, nil) ); ngx.print('\
    <div class="content">\
      <div class = "');  ngx.print(status_led); ngx.print('"></div>\
      <p class="wifi-card"><strong>');  ngx.print(getParams.ssid); ngx.print('</strong></p>\
    </div>\
  </div>\
</div>'); 