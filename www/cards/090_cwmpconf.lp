--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local session = ngx.ctx.session
local modalPath = "/modals/cwmpconf-modal.lp"
local session = ngx.ctx.session
local role = session:getrole()

--Allow to access GUI page as read only, without to login for default user.
if session:hasAccess(modalPath) and not session:isdefaultuser() then
  local content = {
    cwmp_url              = "uci.cwmpd.cwmpd_config.acs_url",
    cwmp_state            = "uci.cwmpd.cwmpd_config.state",
    cwmp_periodic         = "uci.cwmpd.cwmpd_config.periodicinform_interval",
    cwmp_acs_username     = "uci.cwmpd.cwmpd_config.acs_user",
    cwmp_cr_username      = "uci.cwmpd.cwmpd_config.connectionrequest_username",
    cwmp_cr_password      = "uci.cwmpd.cwmpd_config.connectionrequest_password",
  }
  content_helper.getExactContent(content)

  local switchName = "cwmpState"
  local disableSwitch = (not content.cwmp_acs_username or content.cwmp_acs_username == "" or not content.cwmp_cr_username or content.cwmp_cr_username == "" or not content.cwmp_cr_password or content.cwmp_cr_password == "") and 1 or 0
  local url = content.cwmp_url
  if url == "" then
    url = T"Not Set"
  end

  local state, light
  if content.cwmp_state == "1" then
    state = T"Enabled"
    light = "green"
  else
    state = T"Disabled"
    light = "off"
  end

    ngx.print('\
  <div class="span3">\
    <div class="smallcard">\
      ');  if not post_helper.isFeatureEnabled("cwmpstate", role) then
           ngx.print(ui_helper.createCardHeader(T"CWMP", modalPath))
         else
           ngx.print(ui_helper.createCardHeader(T"CWMP", modalPath, switchName, content.cwmp_state, {input = {id = "cwmp_card_state"}, switch = {id = "switch_cwmp_state"}}))
         end
        ngx.print('\
      ');  if not post_helper.isFeatureEnabled("style", role) then   ngx.print('\
        <div class="content card_bg" data-bg-text="&#xf074;">\
      ');  else   ngx.print('\
        <div class="content">\
      ');  end   ngx.print('\
        ');  ngx.print( ui_helper.createSimpleLight(nil, state, { light = { class = light, id = "cwmpconfcard_cwmpstatusled"}, span = { id = "cwmpconfcard_cwmpstatus" } }) ); ngx.print('\
        <p class="subinfos">\
          ');  if post_helper.isFeatureEnabled("acsUrl", role) then
            ngx.print(format(T"ACS URL: %s", url))
          else
            ngx.print(format(T"ACS URL: <strong id=\"cwmpconfcard_acsurl\">%s</strong>", url ))
          end   ngx.print('\
        </p>\
        <p class="subinfos">\
          ');  if post_helper.isFeatureEnabled("periodic", role) then
               ngx.print(format(T"Periodic: %s", content.cwmp_periodic))
             else
               ngx.print(format(T"Periodic: <strong id=\"cwmpconfcard_periodicinterval\">%s</strong>", content["cwmp_periodic"] ))
             end   ngx.print('\
        </p>\
      </div>\
    </div>\
  </div>\
     <script>\
        var switch_val = ');  ngx.print(disableSwitch); ngx.print(';\
        if (switch_val == "1") {\
          $("#switch_cwmp_state").addClass("hide");\
        } else {\
          $("#switch_cwmp_state").removeClass("hide");\
        }\
     </script>\
');  end   ngx.print('\
'); 