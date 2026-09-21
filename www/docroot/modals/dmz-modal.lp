--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")


local qry_params = {
    DMZ_enabled = "rpc.network.dmz.enabled",
}

local qry_valid = {
    DMZ_enabled = post_helper.validateBoolean,
}

local qry_data, qry_helpmsg = post_helper.handleQuery(qry_params, qry_valid)


if ngx.var.request_method == "POST" then
    local content = ngx.req.get_post_args()
    if content then
        local action = content["action"]
        local DMZ_flag = content["DMZ_flag"]
        if action == "SAVE" and DMZ_flag == "1"  then
            ngx.header.content_type = "application/json"
            ngx.print('{ "success":"true" }')
            ngx.timer.at(0, function()
                proxy.set("rpc.system.reboot" , "GUI")
                proxy.apply()
            end)
            ngx.exit(ngx.HTTP_OK)
        end
    end
end


  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Bridge ETH port 4", false, false))   ngx.print('\
\
<div class="modal-body update">\
  <form class="form-horizontal" method="post" action="modals/dmz-modal.lp">\
    ');  
        ngx.print(ui_helper.createMessages(message_helper.popMessages()))
      ngx.print('\
\
    <fieldset>\
      <legend>');  ngx.print( T"Bridge on ETH port 4" ); ngx.print('</legend>\
\
  <text style="margin-left: 110px;">\
    ');  ngx.print( T"A bridge is an external interface to the internet, providing a public IP address to a File Server or other customer equipment" ); ngx.print('<br>\
  </text>\
  <text style="margin-left: 110px;">\
    ');  ngx.print( T"Since this equipment is exposed to the internet, there are security risks taken when this function is enabled." ); ngx.print('<br><br>\
  </text>\
\
\
      ');  
        local dmz = {
          switch = {
            id = "switch-dmz"
          },
          switcher = {
            id = "switcher-dmz"
          },
          input = {
            id = "input-dmz"
          }
        }
        local rebooting = {
          alert = {
            class = "alert-warning hide",
            id = "rebooting-msg"
          }
        }
        local flagattr = {
          input = {
            class = "hide",
            id = "dmz-flag"
          }
        }
        ngx.print(ui_helper.createSwitch(T"Enabled", "DMZ_enabled", qry_data["DMZ_enabled"], dmz, qry_helpmsg["DMZ_enabled"]),
        ui_helper.createAlertBlock(T"Restarting, please wait...", rebooting),
        ui_helper.createSimpleInputText("DMZ_flag", "0", flagattr),
        '<div class="loading-wrapper hide"><img src="/img/spinner.gif" /></div>')
        ngx.print('\
\
      <text style="margin-left: 110px;">\
        ');  ngx.print( T"When the bridge is initiated the MediaAccess Gateway will re-start" ); ngx.print('<br>\
      </text>\
\
</fieldset>\
  </form>\
</div>\
');  ngx.print(string.format([[
<div class="modal-footer">
  <div id="modal-no-change">
    <div id="close-config" class="btn btn-primary btn-large" data-dismiss="modal">%s</div>
  </div>
  <div id="modal-changes" class="hide">
    <div id="cancel-config" class="btn btn-large" data-dismiss="modal">%s</div>
    <div id="save-dmz-config" class="btn btn-primary btn-large">%s</div>
  </div>
</div>
]], T"Close", T"Cancel", T"Save")); ngx.print('\
\
<script src="/js/dmz-modal.js"></script>\
'); 