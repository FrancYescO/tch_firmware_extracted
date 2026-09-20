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

local getSRA = {
  sraParam = "uci.xdsl.xdsl.@dsl0.demod_cap_value", -- In hex format
}
contentHelper.getExactContent(getSRA)

local SRABit, bitswapBit = 0, 0
if getSRA["sraParam"] then
  local SRAInDec = tonumber(getSRA["sraParam"])
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

local VDSLmodeNames = {
  [1]  = "8a",
  [2]  = "8b",
  [3]  = "8c",
  [4]  = "8d",
  [5]  = "12a",
  [6]  = "12b",
  [7]  = "17a",
}

local ADSLmodeNames = {
  gdmt        = "G.Dmt",
  glite       = "G.lite",
  t1413       = "T1.413",
  adsl2       = "ADSL2",
  adsl2annexl = "AnnexL",
  adsl2plus   = "ADSL2+",
  vdsl2       = "VDSL2",
  adsl2annexm = "AnnexM",
}

local function sortByIndex(mode1, mode2)
  return tonumber(match(mode1.paramindex, "%d+")) < tonumber(match(mode2.paramindex, "%d+"))
end
-- Function to get the key given the value
function get_key_for_value( t, value )
  for k,v in pairs(t) do
    if v.value==value then return k end
  end
  return nil
end

local getVDSLModes = contentHelper.convertResultToObject("uci.xdsl.xdsl.@dsl0.profile.", proxy.get("uci.xdsl.xdsl.@dsl0.profile."))
local getADSLModes = contentHelper.convertResultToObject("uci.xdsl.xdsl.@dsl0.multimode.", proxy.get("uci.xdsl.xdsl.@dsl0.multimode."))
local uS0MASKVal   = proxy.get("sys.class.xdsl.@line0.US0MASK")
sort(getVDSLModes, sortByIndex)
sort(getADSLModes, sortByIndex)
  ngx.print('\r\
\r\
<div class="content-xdsl">\r\
	<h1><span>');  ngx.print(T"xDSL"); ngx.print('</span></h1>\r\
	<h3><span>');  ngx.print(T"VDSL Mode"); ngx.print('</span></h3>\r\
	<div class="h3-content vdf-table mobile-padding-bottom-lg">\r\
	  ');  for modeIndex, modeNames in ipairs(VDSLmodeNames) do  ngx.print('\r\
      <div class="vdf-row">\r\
        <div class="left">\r\
          <span>');  ngx.print(modeNames); ngx.print('</span>\r\
        </div>\r\
        <div class="right">\r\
          <span id="xdsl-lbl-vdsl-');  ngx.print(modeIndex); ngx.print('">');
            VDSLIndex = get_key_for_value(getVDSLModes,modeNames); 
            if VDSLIndex then ngx.print(T"Enabled"); else ngx.print(T"Disabled"); end ngx.print('</span>\
			</div>\r\
		</div>\r\
	  ');  end  ngx.print('\r\
    <div class="vdf-row">\r\
      <div class="left">\r\
        <span>US0</span>\r\
      </div>\r\
      <div class="right">\r\
        <span id="xdsl-lbl-vdsl-US0">');  ngx.print((uS0MASKVal[1].value == '1') and T"Enabled" or T"Disabled"); ngx.print('</span>\r\
      </div>\r\
    </div>\r\
	</div>\r\
	<h3><span>');  ngx.print(T"ADSL Mode"); ngx.print('</span></h3>\r\
	<div class="h3-content vdf-table mobile-padding-bottom-lg">\r\
	  ');  for modeIndex, modeNames in pairs(ADSLmodeNames) do  ngx.print('\r\
	    <div class="vdf-row">\r\
			  <div class="left">\r\
			    <span>');  ngx.print(modeNames); ngx.print('</span>\r\
			  </div>\r\
			  <div class="right">\r\
			    <span id="xdsl-lbl-adsl-');  ngx.print(modeIndex); ngx.print('">'); 
				ADSLIndex = get_key_for_value(getADSLModes,modeIndex);  
				if ADSLIndex then ngx.print(T"Enabled"); else ngx.print(T"Disabled"); end ngx.print('</span>\r\
			  </div>\r\
		  </div>\r\
	  ');  
      end  ngx.print('\r\
	</div>\r\
  <h3><span>');  ngx.print(T"VDSL and ADSL Capacity"); ngx.print('</span></h3>\r\
  <div class="h3-content vdf-table mobile-padding-bottom-lg">\r\
    <div class="vdf-row">\r\
      <div class="left">\r\
        <span>');  ngx.print(T"Bitswap"); ngx.print('</span>\r\
      </div>\r\
      <div class="right">\r\
        <span id="xdsl-lbl-bitswap">');  ngx.print((bitswapBit == 1) and T"Enabled" or T"Disabled"); ngx.print('</span>\r\
      </div>\r\
    </div>\r\
    <div class="vdf-row">\r\
      <div class="left">\r\
        <span>');  ngx.print(T"SRA"); ngx.print('</span>\r\
      </div>\r\
      <div class="right">\r\
        <span id="xdsl-lbl-sra">');  ngx.print((SRABit == 1) and T"Enabled" or T"Disabled"); ngx.print('</span>\r\
      </div>\r\
    </div>\r\
  </div>\r\
</div>\r\
<script src="js/global.js"></script>\r\
'); 