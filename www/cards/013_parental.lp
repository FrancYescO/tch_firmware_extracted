--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-parental')

local format = string.format
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local uniqueKey = post_helper.getRandomKey()
local proxy = require("datamodel")
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "GatewayPage", "gateway")
local hideAccessControlInParentalCard = post_helper.getVariantValue(variantHelper, "hideAccessControlInParentalCard")

local contentParental = {
  blockstate = "uci.parental.general.enable",
  controlstate = "uci.tod.global.enabled"
}
content_helper.getExactContent(contentParental)

local uciParentalpath = "uci.parental.URLfilter.@."

local parentalColumns = {
  {
    header = T"Site",
    name = "site",
    param = "site",
    type = "text",
    attr = { input = { class="span2" } }
  },
  {
    header = T"Device",
    name = "device",
    param = "device",
    type = "text",
    attr = { input = { class="span2"} }
  },
}

local parentalOptions = {
  tableid         = "urlfilter",
  basepath        = uciParentalpath,
  objectName      = uniqueKey,
  addNamedObject  = true
}

-- get an initial read from UCI
local parentalData = post_helper.handleTableQuery(parentalColumns, parentalOptions)
local sbRulecount = 0
local acRulecount = 0

-- Parental Control data
function updateParentalTableData ()
  local data = parentalData
  local urlCount = 0

  -- just looking for a count of entries to return for now
  for id, val in ipairs (data) do
    urlCount = id
  end
  return data, urlCount
end

local acData = content_helper.convertResultToObject("uci.tod.host.", proxy.get("uci.tod.host."))

parentalData, sbRulecount = updateParentalTableData()
acRulecount = #acData

local blockenabled = true
local controlenabled = true
local sbSwitchtext, acSwitchtext
local nBlockrules, nControlrules

if (contentParental.blockstate == '1') then
  sbSwitchtext = T"Site blocking enabled"
  blockenabled = "1"
else
  sbSwitchtext = T"Site blocking disabled"
  blockenabled = "0"
end

if (contentParental.controlstate == '1') then
  acSwitchtext = T"Access control enabled"
  controlenabled = "1"
else
  acSwitchtext = T"Access control disabled"
  controlenabled = "0"
end

nBlockrules = tonumber(sbRulecount)
nControlrules = tonumber(acRulecount)

local modalPath = nil
local switchName = nil
local modalLink = ""
local todLink = ""
local session = ngx.ctx.session
local role = session:getrole()
if session:hasAccess("/modals/parental-modal.lp") then
  modalPath = "/modals/parental-modal.lp"
  modalLink = 'class="modal-link" id = "Site_Blocking_Count" data-toggle="modal" data-remote="modals/parental-modal.lp" data-id="parental-modal"'
  todLink = 'class="modal-link" id = "Tod_Rule_Count" data-toggle="modal" data-remote="modals/tod-modal.lp" data-id="parental-modal"'
elseif not session:isdefaultuser() then
  return
end
  ngx.print('\
');  
  local html = {}
  html[#html + 1] = '<div class="span3">'
  html[#html + 1] = '<div class="smallcard">'
  html[#html + 1] = ui_helper.createCardHeader(T"Parental Controls", modalPath, switchName, nil)

  html[#html + 1] = not post_helper.isFeatureEnabled("style", role) and '<div class="content card_bg" data-bg-text="&#xf010;">' or '<div class="content style="position: relative;bottom: 12px;"">'
  html[#html + 1] = ui_helper.createSimpleLight(blockenabled, sbSwitchtext, { light = { id =  "Site_BlockingStatus_Led" }, span = { id = "Site_Blocking_Status" } })

  html[#html + 1] = not post_helper.isFeatureEnabled("style", role) and '<p>' or '<p class="subinfos" style="position: relative;margin-bottom: 0px;">'

  html[#html + 1] = format( N("<strong %s>%d site blocking</strong> rule is defined", "<strong %s>%d site blocking</strong> rules are defined", nBlockrules), modalLink, nBlockrules)
  html[#html + 1] = '</p>'
  if not hideAccessControlInParentalCard or (hideAccessControlInParentalCard and session:hasAccess(modal) and not session:isdefaultuser()) then
    html[#html + 1] = ui_helper.createSimpleLight(controlenabled, acSwitchtext, {light = { id =  "Access_ControlStatus_Led" }, span = { id =  "Access_Control_Status" } })

    html[#html + 1] = not post_helper.isFeatureEnabled("style", role) and '<p class="subinfos">' or '<p class="subinfos" style="position: relative;bottom: 0px;">'

    html[#html + 1] = format( N("<strong %s>%d TOD</strong> rule is created", "<strong %s>%d TOD</strong> rules are created", nControlrules), todLink, nControlrules)
    html[#html + 1] = '</p>'
  end
  html[#html + 1] = '</div></div></div>'
  ngx.print(html)
  ngx.print('\
'); 