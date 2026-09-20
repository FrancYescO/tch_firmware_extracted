--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")

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

-- Construct an uptime string from the number of seconds
local function secondsToTime(uptime)
  local days =  floor(uptime / 86400)
  local hours =  floor(uptime / 3600) % 24
  local minutes = floor(uptime / 60) % 60
  local seconds = uptime % 60
  if (days > 0) then
    return format(T"%ddays %dhours %dmin %dsec", days, hours, minutes, seconds)
  elseif (hours > 0) then
    return format(T"%dhours %dmin %dsec", hours, minutes, seconds)
  elseif (minutes > 0) then
    return format(T"%dmin %dsec", minutes, seconds)
  else
    return format(T"%dsec", seconds)
  end
end

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
    ');  ngx.print( ui_helper.createCardHeaderNoIcon(T"Gateway", "modals/gateway-modal.lp", nil, nil, headerAttr) ); ngx.print('\
    <div class="content">\
      <div class="light green"></div>\
      <p><strong>');  ngx.print( T"Version" ); ngx.print(' ');  ngx.print( content.software_name .. " (" .. content.software_version .. ")" ); ngx.print('</strong></p>\
      <p class="subinfos">');  ngx.print( T"Serial number: " ); ngx.print(' ');  ngx.print( content.factory_id .. content.serial_number  ); ngx.print('</p>\
      <p class="subinfos">');  ngx.print( T"Uptime: " ); ngx.print(' ');  ngx.print( secondsToTime(content["uptime"]) ); ngx.print('</p>\
      <div data-toggle="modal" data-remote="modals/gateway-modal.lp" data-id="gateway-modal">\
      </div>\
    </div>\
  </div>\
</div>\
');  
end
  ngx.print('\
'); 