--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local session = ngx.ctx.session
local format = string.format
local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local modalPath = "/modals/system-modal.lp"
if session:hasAccess(modalPath) then
syslog_present = "Disabled"

local Syslog = proxy.get("uci.system.system.@system[0].log_ip", "uci.system.system.@system[0].log_filter_ip")
if Syslog and (Syslog[1].value ~= "" or Syslog[2].value ~= "") then
    syslog_present = "Enabled"
end

local state_map = {
    Disabled = T"Syslog Disabled",
    Enabled = T"Syslog Enabled",
}

local light_map = {
  Disabled = "off",
  Enabled = "green",
}
ngx.print('\
\
  <div class="span3">\
      <div class="smallcard">',
          ui_helper.createCardHeader(T"System Extras", modalPath), '\
          <div class="content card_bg" data-bg-text="&#xf0ad;">\
          <div class="divtable">',
              ui_helper.createSimpleLight(nil, state_map[syslog_present], { light = { class = light_map[syslog_present] } }), '\
           </div>\
           </div>\
      </div>\
  </div>');
end
