--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local modalPath = nil
local session = ngx.ctx.session
local usersValue = session:getusername()
local post_helper = require("web.post_helper")
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "SystemInfo", "card")
local format = string.format

local activeBankInfo  = post_helper.getVariantValue(variantHelper, "activeBankInfo")

local cardHelper = post_helper.getVariant(variant_helper, "CardView", "card")
local cardViewGFR = post_helper.getVariantValue(cardHelper, "cardViewGFR")
local content = {}
local uptime = 0

if activeBankInfo then
  content = {
    sw_version = "uci.env.var.friendly_sw_version_activebank"
  }
else
  content = {
    version = "uci.version.version.@version[0].marketing_version",
    marketing_name = "uci.version.version.@version[0].marketing_name"
  }
end
if cardViewGFR then
  content.serial_number = "uci.env.var.serial"
  content.t_last_acs_inform = "Device.ManagementServer.X_000E50_LastConnectionTime"
end

content_helper.getExactContent(content)
local version_string

if activeBankInfo then
  version_string = T"Release" .. " " .. content.sw_version .. ""
else
  version_string = T"Version" .. " " .. content.marketing_name .. " (" .. content.version .. ")"
end

if cardViewGFR then
  uptime = post_helper.secondsToTime(content_helper.readfile("/proc/uptime", "number", floor))
  version_string = content.marketing_name .. " (" .. content.version .. ")"
end

if cardViewGFR and usersValue ~= "assist" or not cardViewGFR then
  if session:hasAccess("/modals/system-info-modal.lp") then
    modalPath = "/modals/system-info-modal.lp"
  elseif not session:isdefaultuser() then
    return
  end
end
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"System Info", modalPath) ); ngx.print('\
    <div class="content">\
      ');  if cardViewGFR then
        ngx.print( format( T'<strong>Version: </strong>%s', version_string ));
        ngx.print('<br>');
        ngx.print( format( T'<strong>Serial Number: </strong>%s', content.serial_number ));
        ngx.print('<br>');
        ngx.print( format( T'<strong>Uptime: </strong>%s', uptime ));
        ngx.print('<br>');
        ngx.print( format( T'<strong>Last ACS Inform: </strong>%s', content.t_last_acs_inform ));
      else  ngx.print('\
      <p><strong id = "cardSystemVersion">');  ngx.print( version_string ); ngx.print('</strong></p>\
      ');  end  ngx.print('\
      <div data-remote="modals/system-info-modal.lp" data-id="system-info-modal">\
        <img class="someInfos" href="#" rel="tooltip" data-placement="top" data-original-title="');  ngx.print( T"your gateway" ); ngx.print('" src="/img/gateway.png" alt="gateway">\
      </div>\
    </div>\
  </div>\
</div>\
'); 