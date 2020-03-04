--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")

local find, sub = string.find, string.sub
local floor, ipairs = math.floor, ipairs
local format = string.format

-- Non-configurable data
local content = {
  software_name = "uci.version.version.@version[0].marketing_name",
  software_version = "uci.version.version.@version[0].marketing_version",
  factory_id = "uci.env.rip.factory_id",
  serial_number = "uci.env.rip.serial",
}

content_helper.getExactContent(content)

content["uptime"] = content_helper.readfile("/proc/uptime","number",floor)

local session = ngx.ctx.session
if session:hasAccess("/modals/gateway-modal.lp") then

local headerAttr = {
    icon = {
        class = "icon-info-sign"
    }
}

  ngx.print('\
<div class="span3">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"Gateway", "modals/gateway-modal.lp", nil, nil, headerAttr) ); ngx.print('\
    <div class="content">\
      <div class="light green"></div>\
      <p><strong>');  ngx.print( T"Version" ); ngx.print(' ');  ngx.print( content.software_name .. " (" .. content.software_version .. ")" ); ngx.print('</strong></p>\
      <p class="subinfos">');  ngx.print( T"Serial number: " ); ngx.print(' ');  ngx.print( content.factory_id .. content.serial_number  ); ngx.print('</p>\
      <p class="subinfos">');  ngx.print( T"Uptime: " ); ngx.print(' ');  ngx.print( post_helper.secondsToTime(content["uptime"]) ); ngx.print('</p>\
    </div>\
  </div>\
</div>\
');  
end
  ngx.print('\
'); 