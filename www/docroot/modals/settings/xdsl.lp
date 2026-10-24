--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local contentHelper = require("web.content_helper")
local proxy = require("datamodel")
local match= string.match
local table = table
local sort = table.sort
local ipairs = ipairs
local tonumber = tonumber
local floor = math.floor
local untaint_mt = require("web.taint").untaint_mt
local setMetaTable = setmetatable
local ui_helper = require("vdf_ui_helper")
local vdf_helper = require("vodafone_helper")

local getParams = {
  sraParam = "uci.xdsl.xdsl.@dsl0.demod_cap_value", -- In hex format
}
contentHelper.getExactContent(getParams)

local SRABit, bitswapBit = 0, 0
if getParams["sraParam"] then
  local SRAInDec = tonumber(getParams["sraParam"])
  local bitPosition = 0
  while SRAInDec > 0 do
    if bitPosition == 14 then     -- The 14th bit value decides if bitswap is On or Off
      bitswapBit = floor(SRAInDec%2)
    elseif bitPosition == 23 then -- The 23rd bit value decides if SRA is On or Off
      SRABit = floor(SRAInDec%2)
      break
    end
    SRAInDec = floor(SRAInDec/2)
    bitPosition = bitPosition + 1
  end
end

local VDSLmodeNames = { "8a", "8b", "8c","8d","12a","12b", "17a"}
local ADSLmodeIndex = {"gdmt", "glite", "t1413", "adsl2", "adsl2plus","adsl2annexl","adsl2annexm"}
local ADSLmodeNames = setMetaTable({
  gdmt        = "G.Dmt",
  glite       = "G.lite",
  t1413       = "T1.413",
  adsl2       = "ADSL2",
  adsl2annexl = "AnnexL",
  adsl2plus   = "ADSL2+",
  adsl2annexm = "AnnexM",
}, untaint_mt)

if vdf_helper.getVariant() == "NZ" then
  ADSLmodeNames.vdsl2 = "VDSL2"
  ADSLmodeIndex[#ADSLmodeIndex + 1] = "vdsl2"
end

local XDSLmodeNames = setMetaTable({
   vdsl2       = "VDSL2"
}, untaint_mt)

-- Function to get the key given the value
function get_key_for_value( t, value )
  for k,v in pairs(t) do
    if v.value==value then return k end
  end
  return nil
end

local function sortByIndex(mode1, mode2)
  return tonumber(match(mode1.paramindex, "%d+")) < tonumber(match(mode2.paramindex, "%d+"))
end

local getVDSLModes = contentHelper.convertResultToObject("uci.xdsl.xdsl.@dsl0.profile.", proxy.get("uci.xdsl.xdsl.@dsl0.profile."))
local getADSLModes = contentHelper.convertResultToObject("uci.xdsl.xdsl.@dsl0.multimode.", proxy.get("uci.xdsl.xdsl.@dsl0.multimode."))
local uS0MASKVal   = proxy.get("sys.class.xdsl.@line0.US0MASK")
sort(getVDSLModes, sortByIndex)
sort(getADSLModes, sortByIndex)
  ngx.print('\
\
<div class="content-xdsl">\
  <h1><span>');  ngx.print(T"xDSL"); ngx.print('</span></h1>\
  ');  if vdf_helper.getVariant() == "VHA" then  ngx.print('\
    <h3><span>');  ngx.print(T"VDSL Profile"); ngx.print('</span></h3>\
  ');  else  ngx.print('\
    <h3><span>');  ngx.print(T"VDSL Mode"); ngx.print('</span></h3>\
  ');  end  ngx.print('\
  <div class="h3-content vdf-table mobile-padding-bottom-lg">\
    ');  
      if vdf_helper.getVariant() ~= "NZ" then
        for VDSLIndex, modeNames in ipairs(getVDSLModes) do
          local row = {
            label = modeNames.value,
            element = ui_helper.createOnlyText({ id = ("xdsl-lbl-vdsl-"..VDSLIndex)}, T"Enabled"),
          }
          ngx.print(ui_helper.createRow(row))
        end
      else
        for modeIndex, modeNames in ipairs(VDSLmodeNames) do
          local row = {
            label = modeNames,
          element = ui_helper.createOnlyText({ id = ("xdsl-lbl-vdsl-"..modeIndex)}, get_key_for_value(getVDSLModes,modeNames) and T"Enabled " or T"Disabled"),
          }
          ngx.print(ui_helper.createRow(row))
        end
      end

      local row = {
        label = "US0",
        element = ui_helper.createOnlyText({ id = "xdsl-lbl-vdsl-US0"}, (uS0MASKVal[1].value == '1') and T"Enabled" or T"Disabled"),
      }
      ngx.print(ui_helper.createRow(row))
      ngx.print('\
  </div>\
\
  ');  if vdf_helper.getVariant() == "VHA" then  ngx.print('\
    <h3><span>');  ngx.print(T"xDSL Mode"); ngx.print('</span></h3>\
  ');  else  ngx.print('\
    <h3><span>');  ngx.print(T"ADSL Mode"); ngx.print('</span></h3>\
  ');  end  ngx.print('\
  <div class="h3-content vdf-table mobile-padding-bottom-lg">\
    ');  
      if vdf_helper.getVariant() == "VHA" then
        row = {
          label = XDSLmodeNames.vdsl2,
          element = ui_helper.createOnlyText({ id = ("xdsl-lbl-adsl-"..8)}, T"Enabled"),
        }
        ngx.print(ui_helper.createRow(row))
      elseif vdf_helper.getVariant() == "NZ" then
        for modeIndex, modeNames in ipairs(ADSLmodeIndex) do
          local row = {
            label = modeNames or "",
          element = ui_helper.createOnlyText({ id = ("xdsl-lbl-vdsl-"..modeIndex)}, get_key_for_value(getADSLModes,modeNames) and T"Enabled " or T"Disabled"),
          }
          ngx.print(ui_helper.createRow(row))
        end
      else
        for ADSLIndex, modeNames in ipairs(getADSLModes) do
          if ADSLmodeNames[modeNames.value] then
            local row = {
              label = ADSLmodeNames[modeNames.value],
              element = ui_helper.createOnlyText({ id = ("xdsl-lbl-adsl-"..ADSLIndex)}, T"Enabled"),
            }
            ngx.print(ui_helper.createRow(row))
          end
        end
      end
      ngx.print('\
  </div>\
  ');  if vdf_helper.getVariant() == "VHA" then  ngx.print('\
    <h3><span>');  ngx.print(T"Capacity"); ngx.print('</span></h3>\
  ');  else  ngx.print('\
    <h3><span>');  ngx.print(T"VDSL and ADSL Capacity"); ngx.print('</span></h3>\
  ');  end
    local row = {
      {
        label = T"Bitswap",
        element = ui_helper.createOnlyText({ id = "xdsl-lbl-bitswap"}, (bitswapBit == 1) and T"Enabled" or T"Disabled")
      }, {
        label = T"SRA",
        element = ui_helper.createOnlyText({ id = "xdsl-lbl-sra"}, (SRABit == 1) and T"Enabled" or T"Disabled")
      }
    }
    ngx.print(ui_helper.createTable(row, "", "h3-content vdf-table mobile-padding-bottom-lg"))
    ngx.print('\
</div>\
<script src="js/global-min.js"></script>\
'); 