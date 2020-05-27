--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local tonumber = tonumber
local table = table
local ui_helper = require("web.ui_helper")
local postHelper = require("web.post_helper")
local content_helper = require("web.content_helper")
local variant_helper = require("variant_helper")
local variantHelper = postHelper.getVariant(variant_helper, "ExtenderPage", "extenderConfig")
local proxy = require("datamodel")
local format, find, sub, match = string.format, string.find, string.sub, string.match

local content = {
  count = "rpc.multiap.ExtenderNumberOfEntries",
  agentState = "uci.multiap.agent.enabled",
  controllerState = "uci.multiap.controller.enabled"
}
content_helper.getExactContent(content)
local easyMeshState
if postHelper.getVariantValue(variantHelper, "extenderInfo") then
  easyMeshState = content.agentState == "1" and content.controllerState == "1" and T"Enabled" or T"Disabled"
else
  easyMeshState = content.agentState == "1" and T"Enabled" or T"Disabled"
end
local statusLed = easyMeshState and easyMeshState == "Enabled" and "light green" or "light off"
local nExt = tonumber(content["count"]) or 0
local modalPath = nil
local switchName = nil
local modal_link = ""
local session = ngx.ctx.session
if session:hasAccess("/modals/easy-mesh-configuration.lp") then
  modalPath = "/modals/easy-mesh-configuration.lp"
  modal_link='class="modal-link" data-toggle="modal" data-remote="modals/easy-mesh-configuration.lp" data-id="device-modal"'
elseif not session:isdefaultuser() then
  return
end
  ngx.print('\
\
<div class="span3">\
  <div class="smallcard">\
    ');  ngx.print( ui_helper.createCardHeader(T"EasyMesh", modalPath, switchName, nil) ); ngx.print('\
    <div class="content">\
      <div id=\'easy_mesh\'>\
        <div class="');  ngx.print(statusLed); ngx.print('">\
        </div>\
        <p class="easy_mesh">EasyMesh ');  ngx.print(easyMeshState and easyMeshState or ""); ngx.print('<p>\
        ');  if easyMeshState and easyMeshState == "Enabled" then
          ngx.print(
          '<p class="subinfos">',
          format( N('<strong id="Ext_Count" %1$s>%2$d Extenders</strong> connected',
                    '<strong id="Ext_Count" %1$s>%2$d Extenders</strong> connected', nExt),
                    modal_link, nExt),
          '</p>'
          )
           end
          ngx.print('\
      </div>\
    </div>\
  </div>\
</div>\
'); 