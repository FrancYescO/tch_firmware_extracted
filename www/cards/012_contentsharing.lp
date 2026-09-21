--pretranslated: do not change this file
 

-- Enable localization
gettext.textdomain('webui-contentsharing')

local tinsert = table.insert
local uiHelper = require("web.ui_helper")
local attributes = { light = { } , span = { class = "span4" } }
local contentHelper = require("web.content_helper")
local postHelper = require("web.post_helper")
local match, sub, format = string.match, string.sub, string.format
local session = ngx.ctx.session
local role = session:getrole()
local modalPath = nil
if session:hasAccess("/modals/contentsharing-modal.lp") then
  modalPath = "/modals/contentsharing-modal.lp"
elseif not session:isdefaultuser() then
  return
end


local content = {}

if postHelper.isFeatureEnabled("printerEnable", role) then
  content["printersharingEnabled"] = "uci.printersharing.config.enabled"
  content["sambasharingEnabled"] = "uci.samba.sambashare.@printers.enabled"
end

-- Check availability of file, return true if found, else false
local function fileCheck(fileName)
  if not io.open(fileName,"r") then
    return false
  else
    return true
  end
end

local sambaAvailable = fileCheck("/etc/init.d/samba")
if sambaAvailable then
  local sambaMapParams = {
    sambaFilesharing = "uci.samba.samba.filesharing",
    sambaName        = "uci.samba.samba.name"
  }
  for sambaIndex, sambaValue in pairs(sambaMapParams) do
    content[sambaIndex] = sambaValue
  end
end

local dlnaAvailable = fileCheck("/etc/init.d/dlnad")
if dlnaAvailable then
  local dlnaMapParams = {
    dlnaEnabled	= "uci.dlnad.config.enabled",
    dlnaName	= "uci.dlnad.config.friendly_name"
  }
  for dlnaIndex, dlnaValue in pairs(dlnaMapParams) do
    content[dlnaIndex] = dlnaValue
  end
end
if sambaAvailable or dlnaAvailable then
  contentHelper.getExactContent(content)
end
local sambastate, dlnastate

if sambaAvailable then
  sambastate = content.sambaFilesharing ~= "0" and format(T"%s %s", T"Samba Filesharing", T"enabled") or format(T"%s %s", T"Samba Filesharing", T"disabled")
end
if dlnaAvailable then
  dlnastate = content.dlnaEnabled == "1" and format(T"%s %s", T"DLNA", T"enabled") or format(T"%s %s", T"DLNA", T"disabled")
end

local printersharingState
if postHelper.isFeatureEnabled("printerEnable", role) then
  printersharingState  = (content.printersharingEnabled == "1" and content.sambasharingEnabled == "1") and format(T"%s %s", T"Printer sharing", T"enabled") or format(T"%s %s", T"Printer sharing", T"disabled")
end

  ngx.print('\
\
<div class = "span3">\
  <div class = "smallcard">\
    ');  ngx.print( uiHelper.createCardHeader(T"Sharing", modalPath, nil, nil) ); ngx.print('\
      ');  if not postHelper.isFeatureEnabled("style", role) then   ngx.print('\
        <div class = "content card_bg" data-bg-text = "&#xf045;">\
      ');  else   ngx.print('\
        <div class = "content">\
      ');  end   ngx.print('\
      ');  
        local html = {}
	if sambaAvailable then
	  attributes.light.id = "Samba_Filesharing_Enabled_Led"
	  attributes.span.id = "Samba_Filesharing_Enabled"
	  tinsert(html, uiHelper.createSimpleLight((content.sambaFilesharing ~= '0' and "1" or "0"), sambastate, attributes))
	end
	if dlnaAvailable then
	  attributes.light.id = "Dlna_Enabled_Led"
	  attributes.span.id = "Dlna_Enabled"
	  tinsert(html, uiHelper.createSimpleLight(content.dlnaEnabled, dlnastate, attributes))
	end
        if postHelper.isFeatureEnabled("printerEnable", role) then
          attributes.light.id = "Printer_Enabled_Led"
          attributes.span.id = "Printer_Enabled"
          tinsert(html, uiHelper.createSimpleLight(((content.printersharingEnabled ~= '0' and content.sambasharingEnabled ~= '0') and "1" or "0"), printersharingState, attributes))
        end
        ngx.print(html)
        ngx.print('\
    </div>\
  </div>\
</div>\
\
'); 