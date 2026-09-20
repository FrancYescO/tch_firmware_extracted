--pretranslated: do not change this file
 

-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local format, match = string.format, string.match
local status

local securityStatus = "NotInstalled"
local totalExecutionUnit = proxy.get("sys.SoftwareModules.ExecutionUnitNumberOfEntries")
totalExecutionUnit = totalExecutionUnit and totalExecutionUnit[1].value or "0"
if tonumber(totalExecutionUnit) ~= 0 then
  local euPath = "sys.SoftwareModules.ExecutionUnit."
  local euData = content_helper.convertResultToObject(euPath, proxy.get(euPath))
  local paramIndex
  for _, euEntries in pairs (euData) do
    if euEntries["Name"] == "shgw" then
      paramIndex = euEntries["paramindex"]
    end
    break
  end
  local provisioningStatus = proxy.get(format("sys.SoftwareModules.ExecutionUnit.%s.Extensions.ProvisioningStatus", paramIndex))
  provisioningStatus = provisioningStatus and provisioningStatus[1].value or ""
  if provisioningStatus == "Activated" then
    securityStatus = "Activated"
  elseif provisioningStatus:match("Error") then
    securityStatus = "Error"
  else
    securityStatus = "NotActivated"
  end
end

if securityStatus == "Activated" then
  status = "light green"
elseif securityStatus:match("Error") then
  status = "light red"
else
  status = "light off"
end  ngx.print('\
\
<div class="span3">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeaderNoIcon(T"Device Security") ); ngx.print('\
    <div class="content">\
      <div class="');  ngx.print(status); ngx.print('"></div>\
      <p><strong> ');  ngx.print( securityStatus); ngx.print('</strong></p>\
    </div>\
  </div>\
</div>\
'); 