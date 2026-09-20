--pretranslated: do not change this file
 -- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local content_helper = require("web.content_helper")
local untaint_mt = require("web.taint").untaint_mt
local setmetatable = setmetatable
local ui_helper = require("vdf_ui_helper")
local fibreStatusInfo = {
  status     = "sys.class.net.@eth4.operstate",
  MaxBitRate = "sys.class.net.@eth4.speed",
  DuplexMode = "sys.class.net.@eth4.duplex"
}
local fiberStatus = setmetatable({
  ["NoLink"] = T"Down",
  ["down"]   = T"Down",
  ["up"]     = T"Up"
}, untaint_mt)

local maxBitRate = setmetatable({
    ["Auto"] = T"0 Mbps",
    [""]    = T"0 Mbps"
}, untaint_mt)

local duplexMode = setmetatable({
   [""] =  T"Half",
   ["half"] = T"Half",
   ["full"] = T"Full"
}, untaint_mt)

content_helper.getExactContent(fibreStatusInfo)
fibreStatusInfo.status = fiberStatus[fibreStatusInfo.status] or fibreStatusInfo.status
fibreStatusInfo.MaxBitRate = maxBitRate[fibreStatusInfo.MaxBitRate] or (fibreStatusInfo.MaxBitRate.." Mbps")
fibreStatusInfo.DuplexMode = duplexMode[fibreStatusInfo.DuplexMode] or fibreStatusInfo.DuplexMode
  ngx.print('\
\
<div class="content-fibre-status">\
  <h1><span>');  ngx.print(T"Fibre Status"); ngx.print('</span></h1>\
  <h3><span>');  ngx.print(T"Fibre Status Information"); ngx.print('</span></h3>\
  ');  
  local row = {
  {
    label   = T"Status",
    colRightClass = "right mobile-border-bottom",
    colLeftClass = "left mobile-border-bottom",
    element = ui_helper.createOnlyText({}, fibreStatusInfo.status)
  },
  {
    label   = T"MaxBitRate",
    colRightClass = "right mobile-border-bottom",
    colLeftClass = "left mobile-border-bottom",
    element = ui_helper.createOnlyText({}, fibreStatusInfo.MaxBitRate)
  },
  {
    label   = T"DuplexMode",
    element = ui_helper.createOnlyText({}, fibreStatusInfo.DuplexMode)
  }
  }
  ngx.print(ui_helper.createTable(row, "", "h3-content vdf-table"))
    ngx.print('\
</div>\
'); 