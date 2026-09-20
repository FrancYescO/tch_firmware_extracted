--pretranslated: do not change this file
 -- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local string = string
local format, find, floor = string.format, string.find, math.floor
local math, tonumber = math, tonumber
if ngx.var.request_method == "POST" and ngx.req.get_post_args().reset then
   proxy.set({["sys.class.xdsl.@line0.Reset"]= "1"})
   proxy.apply()
end

local adslInfo = {
  adslMode               =   "sys.class.xdsl.@line0.ModulationType",
  adslUptime             =   "sys.class.xdsl.@line0.ShowtimeStart",
  lineCoding             =   "sys.class.xdsl.@line0.LineEncoding",
  adslStatus             =   "sys.class.xdsl.@line0.Status",
  numberOfCuts           =   "sys.class.xdsl.@line0.LinkRetrainTotal",
  powerState             =   "sys.class.xdsl.@line0.PowerManagementState",
  downStreamCurrRate     =   "sys.class.xdsl.@line0.DownstreamCurrRate",
  upStreamCurrRate       =   "sys.class.xdsl.@line0.UpstreamCurrRate",
  downStreamMaxRate      =   "sys.class.xdsl.@line0.DownstreamMaxRate",
  upStreamMaxRate        =   "sys.class.xdsl.@line0.UpstreamMaxRate",
  downStreamSigToNoise   =   "sys.class.xdsl.@line0.DownstreamNoiseMargin",
  upStreamSigToNoise     =   "sys.class.xdsl.@line0.UpstreamNoiseMargin",
  downStreamAttenuation  =   "sys.class.xdsl.@line0.DownstreamAttenuation",
  upStreamAttenuation    =   "sys.class.xdsl.@line0.UpstreamAttenuation",
  downStreamPower        =   "sys.class.xdsl.@line0.DownstreamPower",
  upStreamPower          =   "sys.class.xdsl.@line0.UpstreamPower",
  downStreamCRC          =   "sys.class.xdsl.@line0.DownstreamCRCTotal",
  upStreamCRC            =   "sys.class.xdsl.@line0.UpstreamCRCTotal",
  downStreamFramingR     =   "sys.class.xdsl.@line0.DownstreamFramingR",
  upStreamFramingR       =   "sys.class.xdsl.@line0.UpstreamFramingR",
  downStreamFramingS     =   "sys.class.xdsl.@line0.DownstreamFramingS",
  upStreamFramingS       =   "sys.class.xdsl.@line0.UpstreamFramingS",
  downStreamFramingD     =   "sys.class.xdsl.@line0.DownstreamFramingD",
  upStreamFramingD       =   "sys.class.xdsl.@line0.UpstreamFramingD",
  downStreamDelay        =   "sys.class.xdsl.@line0.DownstreamDelay",
  upStreamDelay          =   "sys.class.xdsl.@line0.UpstreamDelay",
  downStreamSFrames      =   "sys.class.xdsl.@line0.DownstreamSuperFrames",
  upStreamSFrames        =   "sys.class.xdsl.@line0.UpstreamSuperFrames",
  downStreamSFErrors     =   "sys.class.xdsl.@line0.DownstreamSuperFrameErrors",
  upStreamSFErrors       =   "sys.class.xdsl.@line0.UpstreamSuperFrameErrors",
  downStreamRSWords      =   "sys.class.xdsl.@line0.DownstreamRSWords",
  upStreamRSWords        =   "sys.class.xdsl.@line0.UpstreamRSWords",
  downStreamRSCErrors    =   "sys.class.xdsl.@line0.DownstreamRSCorrectableErrors",
  upStreamRSCErrors      =   "sys.class.xdsl.@line0.UpstreamRSCorrectableErrors",
  downStreamRSUCErrors   =   "sys.class.xdsl.@line0.DownstreamRSUncorrectableErrors",
  upStreamRSUCErrors     =   "sys.class.xdsl.@line0.UpstreamRSUncorrectableErrors",
  downstreamHECErrors    =   "sys.class.xdsl.@line0.DownstreamHECTotal",
  upstreamHECErrors      =   "sys.class.xdsl.@line0.UpstreamHECTotal",
  downStreamOCDErrors    =   "sys.class.xdsl.@line0.DownstreamOCDErrors",
  upStreamOCDErrors      =   "sys.class.xdsl.@line0.UpstreamOCDErrors",
  downStreamLCDErrors    =   "sys.class.xdsl.@line0.DownstreamLCDErrors",
  upStreamLCDErrors      =   "sys.class.xdsl.@line0.UpstreamLCDErrors",
  downStreamTotalCells   =   "sys.class.xdsl.@line0.DownstreamTotalCells",
  upStreamTotalCells     =   "sys.class.xdsl.@line0.UpstreamTotalCells",
  downStreamDataCells    =   "sys.class.xdsl.@line0.PacketsReceived",
  upStreamDataCells      =   "sys.class.xdsl.@line0.PacketsSent",
  downStreamBitErrors    =   "sys.class.xdsl.@line0.ErrorsReceived",
  upStreamBitErrors      =   "sys.class.xdsl.@line0.ErrorsSent",
  downStreamTotalES      =   "sys.class.xdsl.@line0.DownstreamESTotal",
  upStreamTotalES        =   "sys.class.xdsl.@line0.UpstreamESTotal",
  downStreamTotalSES     =   "sys.class.xdsl.@line0.DownstreamSESTotal",
  upStreamTotalSES       =   "sys.class.xdsl.@line0.UpstreamSESTotal",
  downStreamTotalUAS     =   "sys.class.xdsl.@line0.DownstreamUASTotal",
  upStreamTotalUAS       =   "sys.class.xdsl.@line0.UpstreamUASTotal",
  totalStart             =   "sys.class.xdsl.@line0.TotalStart",
  standardUsed           =   "sys.class.xdsl.@line0.StandardUsed",
  downStreamFramingK     =   "sys.class.xdsl.@line0.DownstreamFramingK",
  upStreamFramingK       =   "sys.class.xdsl.@line0.UpstreamFramingK"
}
content_helper.getExactContent(adslInfo)
local function getAdslStatus(value)
  if(adslInfo["adslStatus"] == "Up") then
    return value
  else
    return 0
  end
end

local adslModeText, timeValue
local totalStartValue = tonumber(adslInfo["totalStart"])/60
totalStartValue = math.floor(totalStartValue)
local adslConnectionStat =  T"Disconnected"
if(adslInfo["adslStatus"] == "Up") then
   adslConnectionStat =  T"Connected"
end
if adslInfo["adslStatus"] == "Up" then
  if find(adslInfo["standardUsed"],"^G%.") then
    if find(adslInfo["adslMode"],"ADSL") then
      adslModeText = format("ITU-T %s (%s over POTS)", adslInfo["standardUsed"],adslInfo["adslMode"])
    else
      adslModeText = format("ITU-T %s (%s)", adslInfo["standardUsed"],adslInfo["adslMode"])
    end
  else
      adslModeText = format("%s (%s)",adslInfo["standardUsed"],adslInfo["adslMode"])
  end
end
local upTime = tonumber(adslInfo["adslUptime"])
local days = floor(upTime/(60 * 60 * 24))
local hour = floor(upTime/(60 * 60)) % 24
local min  = floor(upTime/60) % 60
local sec  = upTime % 60
local strDay = T"days"
local strHour = T"hours"
local strMin = T"minutes"
local strSec = T"seconds"
local strAnd = T"and"

if days > 0 then
  timeValue = format("%02d %s, %02d %s, %02d %s %s %02d %s",days, strDay, hour, strHour, min, strMin, strAnd, sec, strSec)
elseif hour > 0 then
  timeValue = format("%02d %s, %02d %s %s %02d %s",hour, strHour, min, strMin, strAnd, sec, strSec)
elseif min > 0 then
  timeValue = format("%02d %s %s %02d %s",min,strMin, strAnd, sec, strSec)
else
  timeValue = format("%02d %s",sec, strSec)
end
local adslStatusInfo = {
  {T"Line Coding" , "adslStat_info_lineCode" , adslInfo["lineCoding"]} ,
  {T"Status" , "adslStat_info_stat" , adslConnectionStat} ,
  {T"Number of Cuts" , "adslStat_info_cuts", adslInfo["numberOfCuts"]},
  {T"Link Power State" , "adslStat_info_power" , adslInfo["powerState"]} ,
}
local lineQuality1 ={
  {T"Super Frames" , "adslStat_info_dwnSuperFrames" , adslInfo["downStreamSFrames"] , "adslStat_info_upSuperFrames" , adslInfo["upStreamSFrames"] , "0" } ,
  {T"Super Frame Errors" , "adslStat_info_dwnSuperFrameErrors" , adslInfo["downStreamSFErrors"] , "adslStat_info_upSuperFrameErrors" , adslInfo["upStreamSFErrors"] , "0"} ,
  {T"RS Words" , "adslStat_info_dwnRS" , adslInfo["downStreamRSWords"] , "adslStat_info_upRS" , adslInfo["upStreamRSWords"] , "0"} ,
  {T"RS Correctable Errors" , "adslStat_info_dwnRSCorrectErrors" , adslInfo["downStreamRSCErrors"] , "adslStat_info_upRSCorrectErrors" , adslInfo["upStreamRSCErrors"] , "0"} ,
  {T"RS Uncorrectable Errors" , "adslStat-info_dwnRSUnCorrectErrors" , adslInfo["downStreamRSUCErrors"] , "adslStat_info_upRSUnCorrectErrors" , adslInfo["upStreamRSUCErrors"] , "0"} ,
}
local lineQuality2 ={
  {T"HEC Errors" , "adslStat_info_dwnHECErrors" , adslInfo["downstreamHECErrors"] , "adslStat_info_upHECErrors" , adslInfo["upstreamHECErrors"] ,"0"} ,
  {T"OCD Errors" , "adslStat_info_dwnOCDErrors" , adslInfo["downStreamOCDErrors"] , "adslStat_info_upOCDErrors" , adslInfo["upStreamOCDErrors"], "0"} ,
  {T"LCD Errors" , "adslStat_info_dwnLCDErrors" , adslInfo["downStreamLCDErrors"] , "adslStat_info_upLCDErrors" , adslInfo["upStreamLCDErrors"], "0"} ,
  {T"Total Cells" , "adslStat_info_dwnTotCells" , adslInfo["downStreamTotalCells"] , "adslStat_info_upTotCells" , adslInfo["upStreamTotalCells"], "0"} ,
  {T"Data Cells" , "adslStat_info_dwnDataCells" , adslInfo["downStreamDataCells"] , "adslStat_info_upDataCells" , adslInfo["upStreamDataCells"], "0"} ,
  {T"Bit Errors" , "adslStat_info_dwnBitErrors" , adslInfo["downStreamBitErrors"] , "adslStat_info_upBitErrors" , adslInfo["upStreamBitErrors"], "0"} ,
}
local lineQuality3 ={
  {T"Total ES" , "adslStat_info_dwnTotalES" , adslInfo["downStreamTotalES"] , "adslStat_info_upTotalES" , adslInfo["upStreamTotalES"] , "0"} ,
  {T"Total SES" , "adslStat_info_dwnTotalSES" , adslInfo["downStreamTotalSES"] , "adslStat_info_upTotalSES" , adslInfo["upStreamTotalSES"] , "0"} ,
  {T"Total UAS" , "adslStat_info_dwnTotalUAS" , adslInfo["downStreamTotalUAS"] , "adslStat_info_upTotalUAS" , adslInfo["upStreamTotalUAS"] , "0"} ,
}
  ngx.print('\
\
<script>\
    $(function() {\
        $(\'select\').chosen({\
            disable_search_threshold: 100000,\
            allow_single_deselect: true\
        });\
    });\
</script>\
        <h1><span>');  ngx.print(T"xDSL Status"); ngx.print('</span></h1>\
        <h3><span>');  ngx.print(T"xDSL"); ngx.print('</span></h3>\
\
<div class="h3-content mobile-padding-bottom-lg">\
    <div class="row padding-top-bottom-20 ">\
        <div class="col-md-3 col-sm-3 col-xs-6">\
            <span>');  ngx.print(T"xDSL Mode"); ngx.print('</span>\
        </div>\
        <div class="col-md-9 col-sm-9 col-xs-6">\
            <span class="pull-right" id="adslStat_info_mode">');  if(adslInfo["adslStatus"] == "Up") then  ngx.print(adslModeText); end  ngx.print('</span>\
        </div>\
    </div>\
    <div class="row not-flex-row">\
        <div class="col-md-12">\
            <hr/>\
        </div>\
    </div><div class="row padding-top-bottom-20 ">\
        <div class="col-md-3 col-sm-3 col-xs-6">\
            <span>');  ngx.print(T"xDSL Uptime"); ngx.print('</span>\
        </div>\
        <div class="col-md-9 col-sm-9 col-xs-6">\
            <span class="pull-right" id="adslStat_info_uptime">');  if(adslInfo["adslStatus"] == "Up") then  ngx.print(' ');  ngx.print(timeValue); else  ngx.print('0s');  end  ngx.print('</span>\
        </div>\
    </div>\
    <div class="row not-flex-row">\
        <div class="col-md-12">\
            <hr/>\
        </div>\
    </div>\
    ');  for i = 1, #adslStatusInfo do   ngx.print('\
    <div class="row padding-top-bottom-20 ">\
        <div class="col-md-6 col-sm-6 col-xs-6">\
            <span>');  ngx.print(adslStatusInfo[i][1]); ngx.print('</span>\
        </div>\
        <div class="col-md-6 col-sm-6 col-xs-6">\
            <span class="pull-right" id="');  ngx.print(adslStatusInfo[i][2]); ngx.print('">\
            ');  if(adslInfo["adslStatus"] == "Up") then   ngx.print(adslStatusInfo[i][3]); elseif(adslStatusInfo[i][3] ==  adslConnectionStat) then  ngx.print(adslConnectionStat); end  ngx.print('</span>\
        </div>\
    </div>\
  ');  if(i ~= #adslStatusInfo) then  ngx.print('\
    <div class="row not-flex-row">\
        <div class="col-md-12">\
            <hr/>\
        </div>\
    </div>\
  ');  end   ngx.print('\
    ');  end   ngx.print('\
</div>\
\
\
    <h3><span>');  ngx.print(T"Line Quality"); ngx.print('</span></h3>\
\
<div class="h3-content adsl-table mobile-padding-bottom-lg">\
  <div class="table-responsive">\
    <table class="table no-margin-bottom">\
        <tbody>\
            <tr class="adsl-title-bdr">\
                <th></th>\
                <th><span>');  ngx.print(T"Downstream"); ngx.print('</span>\
                </th>\
                <th><span>');  ngx.print(T"Upstream"); ngx.print('</span>\
                </th>\
            </tr>\
            <tr>\
                <td><span>');  ngx.print(T"Current Rate"); ngx.print('</span>\
                </td>\
                <td id="adslStat_info_dwncurrentrate">');  ngx.print(getAdslStatus(adslInfo["downStreamCurrRate"])); ngx.print(' kbps</td>\
                <td id="adslStat_info_upcurrentrate">');  ngx.print(getAdslStatus(adslInfo["upStreamCurrRate"])); ngx.print(' kbps</td>\
            </tr>\
            <tr>\
                <td><span>');  ngx.print(T"Maximum Rate"); ngx.print('</span>\
                </td>\
                <td id="adslStat_info_dwnmaxrate">');  ngx.print(getAdslStatus(adslInfo["downStreamMaxRate"])); ngx.print(' kbps</td>\
                <td id="adslStat_info_upmaxrate">');  ngx.print(getAdslStatus(adslInfo["upStreamMaxRate"])); ngx.print(' kbps</td>\
            </tr>\
            <tr>\
                <td><span>');  ngx.print(T"Signal-to-Noise Ratio"); ngx.print('</span>\
                </td>\
                <td id="adslStat_info_dwnsnr">');  ngx.print(getAdslStatus(adslInfo["downStreamSigToNoise"])); ngx.print(' dB</td>\
                <td id="adslStat_info_upsnr">');  ngx.print(getAdslStatus(adslInfo["upStreamSigToNoise"])); ngx.print(' dB</td>\
            </tr>\
            <tr>\
                <td><span>');  ngx.print(T"Attenuation"); ngx.print('</span>\
                </td>\
                <td id="adslStat_info_dwnattenuation">');  ngx.print(getAdslStatus(adslInfo["downStreamAttenuation"])); ngx.print(' dB</td>\
                <td id="adslStat_info_upattenuation">');  ngx.print(getAdslStatus(adslInfo["upStreamAttenuation"])); ngx.print(' dB</td>\
            </tr>\
            <tr>\
                <td><span>');  ngx.print(T"Power"); ngx.print('</span>\
                </td>\
                <td id="adslStat_info_dwnpower">');  ngx.print(getAdslStatus(adslInfo["downStreamPower"])); ngx.print(' dBm</td>\
                <td id="adslStat_info_uppower">');  ngx.print(getAdslStatus(adslInfo["upStreamPower"])); ngx.print(' dBm</td>\
            </tr>\
            <tr>\
                <td><span>');  ngx.print(string.format(T"CRC Errors in last %s minute(s)", totalStartValue)); ngx.print('</span>\
                </td>\
                <td id="adslStat_info_dwnCRC">');  ngx.print(getAdslStatus(adslInfo["downStreamCRC"])); ngx.print('</td>\
                <td id="adslStat_info_upCRC">');  ngx.print(getAdslStatus(adslInfo["upStreamCRC"])); ngx.print('</td>\
            </tr>\
            <tr>\
                <td><span>');  ngx.print(T"K (number of bytes in DMT frame)"); ngx.print('</span>\
                </td>\
                <td id="adslStat_info_dwnkbytes">');  ngx.print(getAdslStatus(adslInfo["downStreamFramingK"])); ngx.print('</td>\
                <td id="adslStat_info_upkbytes">');  ngx.print(getAdslStatus(adslInfo["upStreamFramingK"])); ngx.print('</td>\
            </tr>\
            <tr>\
                <td><span>');  ngx.print(T"R (number of bytes in RS code word)"); ngx.print('</span>\
                </td>\
                <td id="adslStat_info_dwnFramingR">');  ngx.print(getAdslStatus(adslInfo["downStreamFramingR"])); ngx.print('</td>\
                <td id="adslStat_info_upFramingR">');  ngx.print(getAdslStatus(adslInfo["upStreamFramingR"])); ngx.print('</td>\
            </tr>\
            <tr>\
                <td><span>');  ngx.print(T"S (RS code word size in DMT frame)"); ngx.print('</span>\
                </td>\
                <td id="adslStat_info_dwnFramingS">');  ngx.print(getAdslStatus(adslInfo["downStreamFramingS"])); ngx.print('</td>\
                <td id="adslStat_info_upFramingS">');  ngx.print(getAdslStatus(adslInfo["upStreamFramingS"])); ngx.print('</td>\
            </tr>\
            <tr>\
                <td><span>');  ngx.print(T"D (interleaver depth)"); ngx.print('</span>\
                </td>\
                <td id="adslStat_info_dwnFramingD">');  ngx.print(getAdslStatus(adslInfo["downStreamFramingD"])); ngx.print('</td>\
                <td id="adslStat_info_upFramingD">');  ngx.print(getAdslStatus(adslInfo["upStreamFramingD"])); ngx.print('</td>\
            </tr>\
            <tr>\
                <td><span>');  ngx.print(T"Delay"); ngx.print('</span>\
                </td>\
                <td id="adslStat_info_dwnDelay">');  ngx.print(getAdslStatus(adslInfo["downStreamDelay"])); ngx.print(' ms</td>\
                <td id="adslStat_info_upDelay">');  ngx.print(getAdslStatus(adslInfo["upStreamDelay"])); ngx.print(' ms</td>\
            </tr>\
        </tbody>\
    </table>\
  </div>\
</div>\
<div class="h3-content adsl-table mobile-padding-bottom-lg">\
  <div class="table-responsive">\
    <table class="table no-margin-bottom">\
        <tbody>\
            <tr class="adsl-title-bdr">\
                <th></th>\
                <th><span>');  ngx.print(T"Downstream"); ngx.print('</span>\
                </th>\
                <th><span>');  ngx.print(T"Upstream"); ngx.print('</span>\
                </th>\
            </tr>\
            ');  for i = 1 , #lineQuality1 do   ngx.print('\
            <tr>\
                <td><span>');  ngx.print(lineQuality1[i][1]); ngx.print('</span>\
                </td>\
                <td id="');  ngx.print(lineQuality1[i][2]); ngx.print('">');  if(adslInfo["adslStatus"] == "Up") then   ngx.print(lineQuality1[i][3]); ngx.print(' ');  else  ngx.print(' ');  ngx.print(lineQuality1[i][6]); ngx.print(' ');  end  ngx.print('</td>\
                <td id="');  ngx.print(lineQuality1[i][4]); ngx.print('">');  if(adslInfo["adslStatus"] == "Up") then   ngx.print(lineQuality1[i][5]); ngx.print(' ');  else  ngx.print(' ');  ngx.print(lineQuality1[i][6]); ngx.print(' ');  end  ngx.print('</td>\
            </tr>\
            ');  end  ngx.print('\
        </tbody>\
    </table>\
  </div>\
</div>\
<div class="h3-content adsl-table mobile-padding-bottom-lg">\
  <div class="table-responsive">\
    <table class="table no-margin-bottom">\
        <tbody>\
            <tr class="adsl-title-bdr">\
                <th></th>\
                <th><span>');  ngx.print(T"Downstream"); ngx.print('</span>\
                </th>\
                <th><span>');  ngx.print(T"Upstream"); ngx.print('</span>\
                </th>\
            </tr>\
            ');  for i = 1 , #lineQuality2 do   ngx.print('\
            <tr>\
                <td><span>');  ngx.print(lineQuality2[i][1]); ngx.print('</span>\
                </td>\
                <td id="');  ngx.print(lineQuality2[i][2]); ngx.print('">');  if(adslInfo["adslStatus"] == "Up") then   ngx.print(lineQuality2[i][3]); ngx.print(' ');  else  ngx.print(' ');  ngx.print(lineQuality2[i][6]); ngx.print(' ');  end  ngx.print('</td>\
                <td id="');  ngx.print(lineQuality2[i][4]); ngx.print('">');  if(adslInfo["adslStatus"] == "Up") then   ngx.print(lineQuality2[i][5]); ngx.print(' ');  else  ngx.print(' ');  ngx.print(lineQuality2[i][6]); ngx.print(' ');  end  ngx.print('</td>\
            </tr>\
            ');  end  ngx.print('\
        </tbody>\
    </table>\
  </div>\
</div>\
<div class="h3-content adsl-table mobile-padding-bottom-lg">\
  <div class="table-responsive">\
    <table class="table no-margin-bottom">\
        <tbody>\
            <tr class="adsl-title-bdr">\
                <th></th>\
                <th><span>');  ngx.print(T"Downstream"); ngx.print('</span>\
                </th>\
                <th><span>');  ngx.print(T"Upstream"); ngx.print('</span>\
                </th>\
            </tr>\
            ');  for i = 1 , #lineQuality3 do   ngx.print('\
            <tr>\
                <td><span>');  ngx.print(lineQuality3[i][1]); ngx.print('</span>\
                </td>\
                <td id="');  ngx.print(lineQuality3[i][2]); ngx.print('">');  if(adslInfo["adslStatus"] == "Up") then   ngx.print(lineQuality3[i][3]); ngx.print(' ');  else  ngx.print(' ');  ngx.print(lineQuality3[i][6]); ngx.print(' ');  end  ngx.print('</td>\
                <td id="');  ngx.print(lineQuality3[i][4]); ngx.print('">');  if(adslInfo["adslStatus"] == "Up") then   ngx.print(lineQuality3[i][5]); ngx.print(' ');  else  ngx.print(' ');  ngx.print(lineQuality3[i][6]); ngx.print(' ');  end  ngx.print('</td>\
            </tr>\
            ');  end  ngx.print('\
        </tbody>\
    </table>\
  </div>\
</div>\
<form id="adslStatus_form" class="form-horizontal" method="post" action="modals/adslStatus.lp">\
  <input type="hidden" name= "CSRFtoken" id= "CSRFtoken" value = "');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('"></input>\
  <input type="hidden" name= "reset" id= "reset" value = "resetStat"></input>\
<div class="h3-content">\
    <div class="row">\
        <div class="col-md-12 col-xs-12 col-sm-12 text-right">\
          <input class="button" id="adslStat-btn-resetstat" value="');  ngx.print(T"Reset Statistics"); ngx.print('" type="button">\
        </div>\
    </div>\
</div>\
</form>\
<script>\
$(function(){\
  $("#adslStat-btn-resetstat").click(function(){\
    $("#adslStat-btn-resetstat").attr("disabled",true)\
    $("#adslStat-btn-resetstat").addClass("table-button-faded");\
    var target = "/modals/adslStatus.lp";\
    var form = $("#adslStatus_form");\
    var params = form.serializeArray();\
    $("#content").load(target, params);\
});\
});\
\
</script>\
'); 