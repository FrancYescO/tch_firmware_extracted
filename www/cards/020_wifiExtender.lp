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
local showEasyMeshConfig = postHelper.getVariantValue(variantHelper, "easymeshConfig")
local readOnlyEasymeshCard = postHelper.getVariantValue(variantHelper, "readOnlyEasymeshCard")

local content = {
  count = "rpc.multiap.ExtenderNumberOfEntries",
  agentState = "uci.multiap.agent.enabled",
  controllerState = "uci.multiap.controller.enabled"
}
content_helper.getExactContent(content)
local getState = content.agentState == "1" and true or false
local getControllerState = content.controllerState == "1" and true or false

if not postHelper.getVariantValue(variantHelper, "isExtender") and postHelper.getVariantValue(variantHelper, "extenderInfo") and not postHelper.getVariantValue(variantHelper, "controlSelectionEnabled") then
  getState = content.agentState == "1" and content.controllerState == "1" and true or false
end

local easyMeshState = getState and T"Enabled" or T"Disabled"
local statusLed = getState and "light green" or "light off"
local nExt = 0
local modalPath = nil
local switchName = nil
local modal_link = ""
local session = ngx.ctx.session
local showEMConfigPage = postHelper.getVariantValue(variantHelper, "showEMConfigPage")
local isTelus = content.controllerState == "0" and postHelper.getVariantValue(variantHelper, "ShowTopologyWithoutHostManager")
local isNewLayout = proxy.get("uci.env.var.em_new_ui_layout")
isNewLayout = isNewLayout and isNewLayout ~= "" and isNewLayout[1].value or "0"
local linkConfig = "/modals/easy-mesh-configuration.lp"
local linkTopology  = "/modals/wifi-extender-status.lp"
local smartWifiStatus = proxy.get("rpc.wireless.SmartWiFi.Active")
local path = "rpc.multiap.device."
local data = content_helper.convertResultToObject(path, proxy.get(path))

for _, value in pairs(data) do
  if value.backhaul_interface_type ~= "Unknown" then
    nExt = nExt + 1
  end
end

smartWifiStatus = smartWifiStatus and smartWifiStatus[1] and smartWifiStatus[1].value or ""

if smartWifiStatus ~= "1" then
  if isNewLayout == "1" then
    linkConfig = "/modals/easymesh-configuration-modal-newEM.lp"
    linkTopology = "/modals/easymesh-topology-modal-newEM.lp"
  end
  if not readOnlyEasymeshCard then
    if session:hasAccess(linkConfig) and not getState and (showEMConfigPage and smartWifiStatus == "") or isTelus then
      modalPath = linkConfig
      modal_link ='class="modal-link" data-toggle="modal" data-remote="' .. linkConfig .. '" data-id="device-modal"'
    elseif session:hasAccess(linkTopology) and getState and showEMConfigPage or not showEMConfigPage then
      modalPath = linkTopology
      modal_link ='class="modal-link" data-toggle="modal" data-remote="' .. linkTopology .. '" data-id="device-modal"'
    elseif not session:isdefaultuser() then
      return
    end
  end
    ngx.print('\
\
  <div class="span3">\
    <div class="smallcard">\
      ');  ngx.print( ui_helper.createCardHeader(T"EasyMesh", modalPath, switchName, nil) ); ngx.print('\
       ');  if postHelper.isFeatureEnabled("noCardBackgroundIcons", role) then   ngx.print('\
         <div class="content">\
       ');  else   ngx.print('\
         <div class="content card_bg" data-bg-text="&#xf0e8;">\
       ');  end   ngx.print('\
         <div id=\'easy_mesh\'>\
           <div class="');  ngx.print(statusLed); ngx.print('">\
           </div>\
           <p class="easy_mesh">EasyMesh ');  ngx.print(easyMeshState and easyMeshState or ""); ngx.print('<p>\
           ');  if getState and getControllerState then
             ngx.print(
             '<p class="subinfos">',
                format( N('<strong id="Ext_Count" %1$s>%2$d Extender</strong> connected',
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
');  end   ngx.print('\
'); 