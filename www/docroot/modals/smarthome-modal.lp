--pretranslated: do not change this file
 
  -- Enable localization
  gettext.textdomain('webui-core')

  local ngx = ngx
  local ui_helper = require("web.ui_helper")
  local post_helper = require("web.post_helper")
  local validateBoolean = post_helper.validateBoolean
  local proxy = require("datamodel")

  local mapParams = {
    ifaceState = "uci.wireless.wifi-iface.@wl0_2.state",
    apState = "uci.wireless.wifi-ap.@ap6.state"
  }
  local mapValid = {
    ifaceState = validateBoolean,
    apState = validateBoolean
  }
  local params = post_helper.handleQuery(mapParams, mapValid)

  if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "wps_pbc" then
    proxy.set("uci.wireless.wifi-ap.@ap6.wps_state","1")
    proxy.set("uci.wireless.wifi-ap.@ap6.public","1")
    proxy.apply()
    proxy.set("rpc.wireless.ap.@ap6.wps.enrollee_pbc","1")
    proxy.apply()
  end

  ngx.print(ui_helper.createHeader(T"Smart Home", false, true))
  ngx.print('\
\
<div class = "modal-body update">\
  <form class = "form-horizontal" method = "post" action = "modals/smarthome-modal.lp">\
    <fieldset>\
      <legend>');  ngx.print( T"Smart Home" ); ngx.print('</legend>\
      ');  
        local html = {}
        html[#html + 1] = ui_helper.createSwitch(T"SSID Enabled", "ssidEnabled", ((params.ifaceState == "1" and params.apState == "1") and "1" or "0"))

        local iface_enable_class = {
          group = {
            class = "hide"
          },
          input = {
            class= "span4",
            id = "ifaceState"
          }
        }
        html[#html+1] = ui_helper.createInputText(T"", "ifaceState", params.ifaceState, iface_enable_class)

        local ap_enable_class = {
          group = {
            class = "hide"
          },
          input = {
            class= "span4",
            id = "apState"
          }
        }
        html[#html+1] = ui_helper.createInputText(T"", "apState", params.apState,   ap_enable_class)

        local wps_class = {
          group = {
            class = "monitor-security monitor-none monitor-wpa2-psk monitor-wpa-wpa2-psk monitor-ap_broadcast_ssid monitor-1"
          },
          button = {
            ["data-name"] = "action",
            ["data-value"] = "wps_pbc"
          }
        }
        html[#html + 1] = ui_helper.createButton(T"WPS PBC", T"Trigger", "icon-refresh", wps_class)
        ngx.print(html)
        ngx.print('\
    </fieldset>\
  </form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
\
<script>\
  $(".switch").click(function() {\
    if ($("#ssidEnabled").val() == "1") {\
      $("#ifaceState").val("0")\
      $("#apState").val("0")\
    } else if($("#ssidEnabled").val() == "0") {\
      $("#ifaceState").val("1")\
      $("#apState").val("1")\
    }\
  });\
</script>\
\
\
'); 