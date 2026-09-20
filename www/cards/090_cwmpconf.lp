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
  }

  content_helper.getExactContent(content)

  local switchName = "cwmp_state"
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

  local headerAttr = {
    icon = {
      class = "icon-info-sign"
    },
    input = {
      id = "cwmp_card_state"
    }
  }
    ngx.print('\
  <div class="span3">\
    <div class="smallcard">\
        ');  ngx.print(ui_helper.createCardHeaderNoIcon(T"CWMP", modalPath, switchName, content.cwmp_state, headerAttr))   ngx.print('\
        <div class="content">\
        ');  ngx.print( ui_helper.createSimpleLight(nil, state, { light = { class = light, id = "cwmpconfcard_cwmpstatusled"}, span = { id = "cwmpconfcard_cwmpstatus" } }) ); ngx.print('\
        <p class="subinfos">\
          ');  ngx.print(format(T"ACS URL: <strong id=\"cwmpconfcard_acsurl\">%s</strong>", url ))   ngx.print('\
        </p>\
        <p class="subinfos">\
          ');  ngx.print(format(T"Periodic: <strong id=\"cwmpconfcard_periodicinterval\">%s</strong>", content.cwmp_periodic ))   ngx.print('\
        </p>\
      </div>\
    </div>\
  </div>\
');  end   ngx.print('\
'); 