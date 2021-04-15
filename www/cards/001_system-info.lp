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
local version = post_helper.getVariantValue(variantHelper, "version")
local serialNumber = post_helper.getVariantValue(variantHelper, "serialNumber")
local lastACSInform = post_helper.getVariantValue(variantHelper, "lastACSInform")
local upTime = post_helper.getVariantValue(variantHelper, "upTime")
local readOnlySystemInfo = post_helper.getVariantValue(variantHelper, "readOnlySystemInfo")

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
if serialNumber then
  content.serial_number = "uci.env.var.serial"
end
if lastACSInform then
  content.t_last_acs_inform = "Device.ManagementServer.X_000E50_LastConnectionTime"
end

content_helper.getExactContent(content)
local version_string
if activeBankInfo then
  version_string = content.sw_version
else
  version_string = content.marketing_name .. " (" .. content.version .. ")"
end

if upTime then
  uptime = post_helper.secondsToTime(content_helper.readfile("/proc/uptime", "number", floor))
end

if readOnlySystemInfo and usersValue ~= "assist" or not readOnlySystemInfo then
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
      ');  ngx.print( format( version, version_string));
      ngx.print('<br>');
      if serialNumber then
        ngx.print( format( T'<strong>Serial Number: </strong>%s', content.serial_number ));
        ngx.print('<br>');
      end
      if upTime then
        ngx.print( format( T'<strong>Uptime: </strong>%s', uptime ));
        ngx.print('<br>');
      end
      if lastACSInform then
        ngx.print( format( T'<strong>Last ACS Inform: </strong>%s', content.t_last_acs_inform ));
      end  ngx.print('\
      <div data-remote="modals/system-info-modal.lp" data-id="system-info-modal">\
        <img class="someInfos" href="#" rel="tooltip" data-placement="top" data-original-title="');  ngx.print( T"your gateway" ); ngx.print('" src="/img/gateway.png" alt="gateway">\
      </div>\
    </div>\
  </div>\
</div>\
'); 