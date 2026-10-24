--pretranslated: do not change this file
 -- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local vdf_ui_helper = require("vdf_ui_helper")
local post_helper = require("web.post_helper")
local populateAttenuation = post_helper.populateAttenuation
local string = string
local math, tonumber = math, tonumber
local vdf_helper =require("vodafone_helper")
local format, find, floor = string.format, string.find, math.floor
if ngx.var.request_method == "POST" and ngx.req.get_post_args().reset then
   proxy.set({["sys.class.xdsl.@line0.Reset"]= "1"})
   proxy.apply()
end

local getvariant = {
  vfvariant = "uci.env.var.vodafone_variant"
}
content_helper.getExactContent(getvariant)
local DSLName = "VDSL"
if getvariant.vfvariant == "NZ" then
  DSLName = "xDSL"
end
if getvariant.vfvariant == "VF-UK" then
  DSLName = "DSL"
end

local dslInfo = {
  ModulationType         =   "sys.class.xdsl.@line0.ModulationType",
  dslUptime             =   "sys.class.xdsl.@line0.ShowtimeStart",
  lineCoding             =   "sys.class.xdsl.@line0.LineEncoding",
  adslStatus             =   "sys.class.xdsl.@line0.LinkStatus",
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
content_helper.getExactContent(dslInfo)

--Only for vodafone variant = VHA
local vdslInfo
if getvariant.vfvariant == "VHA" then
  vdslInfo = {
    upStreamR              =   "sys.class.xdsl.@line0.UpstreamFramingR",
    downStreamR            =   "sys.class.xdsl.@line0.DownstreamFramingR",
    upStreamS              =   "sys.class.xdsl.@line0.UpstreamFramingS",
    downStreamS            =   "sys.class.xdsl.@line0.DownstreamFramingS",
    upStreamD              =   "sys.class.xdsl.@line0.UpstreamFramingD",
    downStreamD            =   "sys.class.xdsl.@line0.DownstreamFramingD",
    upStreamL              =   "sys.class.xdsl.@line0.UpstreamFramingL",
    downStreamL            =   "sys.class.xdsl.@line0.DownstreamFramingL",
    upStreamN              =   "sys.class.xdsl.@line0.UpstreamFramingN",
    downStreamN            =   "sys.class.xdsl.@line0.DownstreamFramingN",
    upStreamOR             =   "sys.class.xdsl.@line0.UpstreamOR",
    downStreamOR           =   "sys.class.xdsl.@line0.DownstreamOR",
    upStreamINP            =   "sys.class.xdsl.@line0.UpstreamINP",
    downStreamINP          =   "sys.class.xdsl.@line0.DownstreamINP",
    upStreamDelay          =   "sys.class.xdsl.@line0.UpstreamDelay",
    downStreamDelay        =   "sys.class.xdsl.@line0.DownstreamDelay",
    upStreamTrellis        =   "sys.class.xdsl.@line0.UpstreamTrellis",
    downStreamTrellis      =   "sys.class.xdsl.@line0.DownstreamTrellis",
    downStreamRxQueue      =   "sys.class.xdsl.@line0.DownstreamGINPRxQueue",
    upStreamRxQueue        =   "sys.class.xdsl.@line0.UpstreamGINPRxQueue",
    downStreamTxQueue      =   "sys.class.xdsl.@line0.DownstreamGINPTxQueue",
    upStreamTxQueue        =   "sys.class.xdsl.@line0.UpstreamGINPTxQueue",
    downStreamLookBack     =   "sys.class.xdsl.@line0.DownstreamGINPLookBack",
    upStreamLookBack       =   "sys.class.xdsl.@line0.UpstreamGINPLookBack",
    downStreamRRCBits      =   "sys.class.xdsl.@line0.DownstreamGINPRRCBits",
    upStreamRRCBits        =   "sys.class.xdsl.@line0.UpstreamGINPRRCBits",
    downStreamRTxTx        =   "sys.class.xdsl.@line0.DownstreamGINPRTxTx",
    upStreamRTxTx          =   "sys.class.xdsl.@line0.UpstreamGINPRTxTx",
    downStreamRTxC         =   "sys.class.xdsl.@line0.DownstreamGINPRTxC",
    upStreamRTxC           =   "sys.class.xdsl.@line0.UpstreamGINPRTxC",
    downStreamRTxUC        =   "sys.class.xdsl.@line0.DownstreamGINPRTxUC",
    upStreamRTxUC          =   "sys.class.xdsl.@line0.UpstreamGINPRTxUC",
    downStreamLEFTRS       =   "sys.class.xdsl.@line0.DownstreamGINPLEFTRS",
    upStreamLEFTRS         =   "sys.class.xdsl.@line0.UpstreamGINPLEFTRS",
    downStreamMinEFTR      =   "sys.class.xdsl.@line0.DownstreamGINPMinEFTR",
    upStreamMinEFTR        =   "sys.class.xdsl.@line0.UpstreamGINPMinEFTR",
    downStreamErrFreeBits  =   "sys.class.xdsl.@line0.DownstreamGINPErrFreeBits",
    upStreamErrFreeBits    =   "sys.class.xdsl.@line0.UpstreamGINPErrFreeBits",
    GINPStatus             =   "sys.class.xdsl.@line0.GINPStatus",
    DirectionMode          =   "sys.class.xdsl.@line0.VectoringDirectionMode",
    RxBitSwapMode          =   "sys.class.xdsl.@line0.VectoringRxBitSwapMode",
    DisableVNMode          =   "sys.class.xdsl.@line0.VectoringDisableVNMode",
    VceAddress             =   "sys.class.xdsl.@line0.VectoringVceAddress",
    CntESPktSend           =   "sys.class.xdsl.@line0.VectoringCntESPktSend",
    CntESPktDrop           =   "sys.class.xdsl.@line0.VectoringCntESPktDrop",
    CntESStatSend          =   "sys.class.xdsl.@line0.VectoringCntESStatSend",
    CntESStatDrop          =   "sys.class.xdsl.@line0.VectoringCntESStatDrop",
  }
  content_helper.getExactContent(vdslInfo)
end

local function getAdslStatus(value)
  if(dslInfo["adslStatus"] == "Showtime") then
    return value
  else
    return 0
  end
end

local dslModeType, timeValue
local totalStartValue = tonumber(dslInfo["totalStart"])/60
totalStartValue = math.floor(totalStartValue)
local adslConnectionStat = dslInfo.adslStatus
if adslConnectionStat == "Showtime" then
  adslConnectionStat =  T"Connected"
elseif adslConnectionStat == "Idle" then
  adslConnectionStat =  T"Disconnected"
end
if dslInfo["adslStatus"] == "Showtime" then
  if find(dslInfo["standardUsed"],"^G%.") then
    if find(dslInfo["ModulationType"],"ADSL") then
      dslModeType = format("ITU-T %s (%s over POTS)", dslInfo["standardUsed"],dslInfo["ModulationType"])
    elseif getvariant.vfvariant == "VF-UK" and dslInfo["ModulationType"] == "G.fast" then
      dslModeType = format("%s", dslInfo["ModulationType"])
    else
      dslModeType = format("ITU-T %s (%s)", dslInfo["standardUsed"],dslInfo["ModulationType"])
    end
  else
      dslModeType = format("%s (%s)",dslInfo["standardUsed"],dslInfo["ModulationType"])
  end
end
local upTime = tonumber(dslInfo["dslUptime"])
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
  {T"Line Coding" , "adslStat_info_lineCode" , dslInfo["lineCoding"]} ,
  {T"Status" , "adslStat_info_stat" , adslConnectionStat} ,
  {T"Number of Cuts" , "adslStat_info_cuts", dslInfo["numberOfCuts"]},
  {T"Link Power State" , "adslStat_info_power" , dslInfo["powerState"]} ,
}
local lineQuality1 ={
  {T"Super Frames" , "adslStat_info_dwnSuperFrames" , dslInfo["downStreamSFrames"] , "adslStat_info_upSuperFrames" , dslInfo["upStreamSFrames"] , "0" } ,
  {T"Super Frame Errors" , "adslStat_info_dwnSuperFrameErrors" , dslInfo["downStreamSFErrors"] , "adslStat_info_upSuperFrameErrors" , dslInfo["upStreamSFErrors"] , "0"} ,
  {T"RS Words" , "adslStat_info_dwnRS" , dslInfo["downStreamRSWords"] , "adslStat_info_upRS" , dslInfo["upStreamRSWords"] , "0"} ,
  {T"RS Correctable Errors" , "adslStat_info_dwnRSCorrectErrors" , dslInfo["downStreamRSCErrors"] , "adslStat_info_upRSCorrectErrors" , dslInfo["upStreamRSCErrors"] , "0"} ,
  {T"RS Uncorrectable Errors" , "adslStat-info_dwnRSUnCorrectErrors" , dslInfo["downStreamRSUCErrors"] , "adslStat_info_upRSUnCorrectErrors" , dslInfo["upStreamRSUCErrors"] , "0"} ,
}
local lineQuality2 ={
  {T"HEC Errors" , "adslStat_info_dwnHECErrors" , dslInfo["downstreamHECErrors"] , "adslStat_info_upHECErrors" , dslInfo["upstreamHECErrors"] ,"0"} ,
  {T"OCD Errors" , "adslStat_info_dwnOCDErrors" , dslInfo["downStreamOCDErrors"] , "adslStat_info_upOCDErrors" , dslInfo["upStreamOCDErrors"], "0"} ,
  {T"LCD Errors" , "adslStat_info_dwnLCDErrors" , dslInfo["downStreamLCDErrors"] , "adslStat_info_upLCDErrors" , dslInfo["upStreamLCDErrors"], "0"} ,
  {T"Total Cells" , "adslStat_info_dwnTotCells" , dslInfo["downStreamTotalCells"] , "adslStat_info_upTotCells" , dslInfo["upStreamTotalCells"], "0"} ,
  {T"Data Cells" , "adslStat_info_dwnDataCells" , dslInfo["downStreamDataCells"] , "adslStat_info_upDataCells" , dslInfo["upStreamDataCells"], "0"} ,
  {T"Bit Errors" , "adslStat_info_dwnBitErrors" , dslInfo["downStreamBitErrors"] , "adslStat_info_upBitErrors" , dslInfo["upStreamBitErrors"], "0"} ,
}
local lineQuality3 ={
  {T"Total ES" , "adslStat_info_dwnTotalES" , dslInfo["downStreamTotalES"] , "adslStat_info_upTotalES" , dslInfo["upStreamTotalES"] , "0"} ,
  {T"Total SES" , "adslStat_info_dwnTotalSES" , dslInfo["downStreamTotalSES"] , "adslStat_info_upTotalSES" , dslInfo["upStreamTotalSES"] , "0"} ,
  {T"Total UAS" , "adslStat_info_dwnTotalUAS" , dslInfo["downStreamTotalUAS"] , "adslStat_info_upTotalUAS" , dslInfo["upStreamTotalUAS"] , "0"} ,
}

local ui_helper = require("web.ui_helper")
local getargs = ngx.req.get_uri_args()
if getargs.action == "GET_BITS" then
  local xdsl_BitLoading = "sys.class.xdsl.@line0.BitLoading"
  local bvalue = proxy.get(xdsl_BitLoading)
  xdsl_BitLoading = bvalue[1] and bvalue[1].value or {}
  local html = {}
  html[#html+1] ='<div id="dsl-bit-load" style="max-width:880px;overflow-x:auto"><small>'
  html[#html+1] =ui_helper.createBitLoadHistogram(xdsl_BitLoading)
  html[#html+1] ="</small></div>"
  ngx.print(html)
  ngx.exit(ngx.HTTP_OK)
end
  ngx.print('\
\
<h1><span>');  ngx.print(T(DSLName .. " Status")); ngx.print('</span></h1>\
');  if vdf_helper.getVariant() == "VF-UK" then   ngx.print('\
<h2><span>');  ngx.print(("This status page shows technical parameters of your data connection.")); ngx.print('</span></h2>\
');  end   ngx.print('\
<h3><span>');  ngx.print(T(DSLName)); ngx.print('</span></h3>\
\
<div class="h3-content mobile-padding-bottom-lg">\
  ');  
    row = {
      label = T(DSLName .. " Mode"),
      element = vdf_ui_helper.createOnlyText({id = "adslStat_info_mode", class = "pull-right"}, dslInfo.adslStatus == "Showtime" and dslModeType or ""),
      colLeftClass = "col-md-3 col-sm-3 col-xs-6",
      colRightClass = "col-md-9 col-sm-9 col-xs-6",
      rowClass = "row padding-top-bottom-20"
    }
    ngx.print(vdf_ui_helper.createRow(row))
    ngx.print('\
  <div class="row not-flex-row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  ');  
    row = {
      label   = T(DSLName .. " Uptime"),
      element = vdf_ui_helper.createOnlyText({id = "adslStat_info_uptime", class = "pull-right"}, dslInfo["adslStatus"] == "Showtime" and timeValue or "0s"),
      colLeftClass = "col-md-3 col-sm-3 col-xs-6",
      colRightClass = "col-md-9 col-sm-9 col-xs-6",
      rowClass = "row padding-top-bottom-20"
    }
    ngx.print(vdf_ui_helper.createRow(row))
    ngx.print('\
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
            ');  if(dslInfo["adslStatus"] == "Showtime") then   ngx.print(adslStatusInfo[i][3]); elseif(adslStatusInfo[i][3] ==  adslConnectionStat) then  ngx.print(adslConnectionStat); end  ngx.print('</span>\
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
<h3><span>');  ngx.print(T"Line Quality"); ngx.print('</span></h3>\
');  
local columns_LineQuality = {""}
local classInfo_LineQuality = {
  outerDivClass = "h3-content adsl-table mobile-padding-bottom-lg",
  outerId = "",
  innerDivClass = "table-responsive",
  innerId = "",
  tableClass = "table no-margin-bottom",
  tableId = "",
  tbodyClass = "vdsl-tbl",
}
local dataLineQuality = {
  {
    T"Current Rate", (getAdslStatus(dslInfo["downStreamCurrRate"]).. T" kbps"), (getAdslStatus(dslInfo["upStreamCurrRate"])..  T" kbps")
  },
  {
    T"Maximum Rate", (getAdslStatus(dslInfo["downStreamMaxRate"]).. T" kbps"), (getAdslStatus(dslInfo["upStreamMaxRate"]).. T" kbps")
  },
  {
    T"Signal-to-Noise Ratio", (getAdslStatus(dslInfo["downStreamSigToNoise"]).. T" dB"), (getAdslStatus(dslInfo["upStreamSigToNoise"]).. T" dB")
  },
  {
    T"Attenuation", populateAttenuation(getAdslStatus(dslInfo.downStreamAttenuation), T"DS"), populateAttenuation(getAdslStatus(dslInfo.upStreamAttenuation), T"US")
  },
  {
    T"Power", (getAdslStatus(dslInfo["downStreamPower"]).. T" dBm"), (getAdslStatus(dslInfo["upStreamPower"]).. T" dBm")
  },
  {
    string.format(T"CRC Errors in last %s minute(s)", totalStartValue), getAdslStatus(dslInfo["downStreamCRC"]), getAdslStatus(dslInfo["upStreamCRC"])
  },
  {
    T"K (number of bytes in DMT frame)", getAdslStatus(dslInfo["downStreamFramingK"]), getAdslStatus(dslInfo["upStreamFramingK"])
  },
  {
    T"R (number of bytes in RS code word)", getAdslStatus(dslInfo["downStreamFramingR"]), getAdslStatus(dslInfo["upStreamFramingR"])
  },
  {
    T"S (RS code word size in DMT frame)", getAdslStatus(dslInfo["downStreamFramingS"]), getAdslStatus(dslInfo["upStreamFramingS"])
  },
  {
    T"D (interleaver depth)", getAdslStatus(dslInfo["downStreamFramingD"]), getAdslStatus(dslInfo["upStreamFramingD"])
  },
  {
    T"Delay", (getAdslStatus(dslInfo["downStreamDelay"]).. T" ms"), (getAdslStatus(dslInfo["upStreamDelay"]).. T" ms")
  }
}
ngx.print(vdf_ui_helper.createTrTable(classInfo_LineQuality, columns_LineQuality, dataLineQuality))
  ngx.print('\
\
<div class="h3-content adsl-table mobile-padding-bottom-lg">\
  <div class="table-responsive">\
    <table class="table no-margin-bottom">\
        <tbody class="vdsl-tbl">\
            ');  for i = 1 , #lineQuality1 do   ngx.print('\
            <tr>\
                <td><span>');  ngx.print(lineQuality1[i][1]); ngx.print('</span>\
                </td>\
                <td id="');  ngx.print(lineQuality1[i][2]); ngx.print('">');  if(dslInfo["adslStatus"] == "Showtime") then   ngx.print(lineQuality1[i][3]); ngx.print(' ');  else  ngx.print(' ');  ngx.print(lineQuality1[i][6]); ngx.print(' ');  end  ngx.print('</td>\
                <td id="');  ngx.print(lineQuality1[i][4]); ngx.print('">');  if(dslInfo["adslStatus"] == "Showtime") then   ngx.print(lineQuality1[i][5]); ngx.print(' ');  else  ngx.print(' ');  ngx.print(lineQuality1[i][6]); ngx.print(' ');  end  ngx.print('</td>\
            </tr>\
            ');  end  ngx.print('\
        </tbody>\
    </table>\
  </div>\
</div>\
<div class="h3-content adsl-table mobile-padding-bottom-lg">\
  <div class="table-responsive">\
    <table class="table no-margin-bottom">\
        <tbody class="vdsl-tbl">\
            ');  for i = 1 , #lineQuality2 do   ngx.print('\
            <tr>\
                <td><span>');  ngx.print(lineQuality2[i][1]); ngx.print('</span>\
                </td>\
                <td id="');  ngx.print(lineQuality2[i][2]); ngx.print('">');  if(dslInfo["adslStatus"] == "Showtime") then   ngx.print(lineQuality2[i][3]); ngx.print(' ');  else  ngx.print(' ');  ngx.print(lineQuality2[i][6]); ngx.print(' ');  end  ngx.print('</td>\
                <td id="');  ngx.print(lineQuality2[i][4]); ngx.print('">');  if(dslInfo["adslStatus"] == "Showtime") then   ngx.print(lineQuality2[i][5]); ngx.print(' ');  else  ngx.print(' ');  ngx.print(lineQuality2[i][6]); ngx.print(' ');  end  ngx.print('</td>\
            </tr>\
            ');  end  ngx.print('\
        </tbody>\
    </table>\
  </div>\
</div>\
<div class="h3-content adsl-table mobile-padding-bottom-lg">\
  <div class="table-responsive">\
    <table class="table no-margin-bottom">\
        <tbody class="vdsl-tbl">\
            ');  for i = 1 , #lineQuality3 do   ngx.print('\
            <tr>\
                <td><span>');  ngx.print(lineQuality3[i][1]); ngx.print('</span>\
                </td>\
                <td id="');  ngx.print(lineQuality3[i][2]); ngx.print('">');  if(dslInfo["adslStatus"] == "Showtime") then   ngx.print(lineQuality3[i][3]); ngx.print(' ');  else  ngx.print(' ');  ngx.print(lineQuality3[i][6]); ngx.print(' ');  end  ngx.print('</td>\
                <td id="');  ngx.print(lineQuality3[i][4]); ngx.print('">');  if(dslInfo["adslStatus"] == "Showtime") then   ngx.print(lineQuality3[i][5]); ngx.print(' ');  else  ngx.print(' ');  ngx.print(lineQuality3[i][6]); ngx.print(' ');  end  ngx.print('</td>\
            </tr>\
            ');  end  ngx.print('\
        </tbody>\
    </table>\
  </div>\
</div>\
<!--Framing parameters, G.INP stats, Vectoring stats and DSL bit loading are only for vodafone variant = VHA -->\
');  if getvariant.vfvariant == "VHA" then   ngx.print('\
  <h3><span>Framing Parameters</span></h3>\
  <div class="h3-content framing-param-table mobile-padding-bottom-lg">\
    <div class="table-responsive">\
      <table class="table no-margin-bottom">\
          <tbody class="vdsl-tbl">\
              <tr>\
                  <td>R</td>\
                  <td id="vdslstat-dwnr">');  ngx.print(vdslInfo["downStreamR"]); ngx.print('</td>\
                  <td id="vdslstat-upr">');  ngx.print(vdslInfo["upStreamR"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>S</td>\
                  <td id="vdslstat-dwns">');  ngx.print(vdslInfo["downStreamS"]); ngx.print('</td>\
                  <td id="vdslstat-ups">');  ngx.print(vdslInfo["upStreamS"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>D</td>\
                  <td id="vdslstat-dwnd">');  ngx.print(vdslInfo["downStreamD"]); ngx.print('</td>\
                  <td id="vdslstat-upd">');  ngx.print(vdslInfo["upStreamD"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>L</td>\
                  <td id="vdslstat-dwnl">');  ngx.print(vdslInfo["downStreamL"]); ngx.print('</td>\
                  <td id="vdslstat-upl">');  ngx.print(vdslInfo["upStreamL"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>N</td>\
                  <td id="vdslstat-dwnn">');  ngx.print(vdslInfo["downStreamN"]); ngx.print('</td>\
                  <td id="vdslstat-upn">');  ngx.print(vdslInfo["upStreamN"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>OR</td>\
                  <td id="vdslstat-dwnor">');  ngx.print(vdslInfo["downStreamOR"]); ngx.print('</td>\
                  <td id="vdslstat-upor">');  ngx.print(vdslInfo["upStreamOR"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>INP</td>\
                  <td id="vdslstat-dwninp">');  ngx.print(vdslInfo["downStreamINP"]); ngx.print('</td>\
                  <td id="vdslstat-upinp">');  ngx.print(vdslInfo["upStreamINP"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>Delay</td>\
                  <td id="vdslstat-dwndelay">');  ngx.print(vdslInfo["downStreamDelay"]); ngx.print('</td>\
                  <td id="vdslstat-updelay">');  ngx.print(vdslInfo["upStreamDelay"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>Trellis</td>\
                  <td id="vdslstat-dwntrellis">');  if vdslInfo["downStreamTrellis"] then  ngx.print('On');  else  ngx.print('Off');  end  ngx.print('</td>\
                  <td id="vdslstat-uptrellis">');  if vdslInfo["upStreamTrellis"] then  ngx.print('On');  else  ngx.print('Off');  end  ngx.print('</td>\
              </tr>\
          </tbody>\
      </table>\
    </div>\
  </div>\
\
  <h3><span>G.INP Stats</span></h3>\
  <div class="h3-content inp-stats-table mobile-padding-bottom-lg">\
    <div class="table-responsive">\
      <table class="table no-margin-bottom">\
          <tr>\
              <td>Status</td>\
                  <td id="vdslstat-dwnginpstatus">');  if vdslInfo["GINPStatus"] == "1" then  ngx.print('Up');  else  ngx.print('Down');  end  ngx.print('</td>\
          </tr>\
          <tbody class="vdsl-tbl">\
              <tr>\
                  <td>ReXmt</td>\
                  <td id="vdslstat-dwnrtxtx">');  ngx.print(vdslInfo["downStreamRTxTx"]); ngx.print('</td>\
                  <td id="vdslstat-uprtxtx">');  ngx.print(vdslInfo["upStreamRTxTx"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>ReXmtCor</td>\
                  <td id="vdslstat-dwnrtxc">');  ngx.print(vdslInfo["downStreamRTxC"]); ngx.print('</td>\
                  <td id="vdslstat-uprtxc">');  ngx.print(vdslInfo["upStreamRTxC"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>ReXmtUnc</td>\
                  <td id="vdslstat-dwnrtxuc">');  ngx.print(vdslInfo["downStreamRTxUC"]); ngx.print('</td>\
                  <td id="vdslstat-uprtxuc">');  ngx.print(vdslInfo["upStreamRTxUC"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>RxQueue</td>\
                  <td id="vdslstat-dwnrxqueue">');  ngx.print(vdslInfo["downStreamRxQueue"]); ngx.print('</td>\
                  <td id="vdslstat-uprxqueue">');  ngx.print(vdslInfo["upStreamRxQueue"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>TxQueue</td>\
                  <td id="vdslstat-dwntxqueue">');  ngx.print(vdslInfo["downStreamTxQueue"]); ngx.print('</td>\
                  <td id="vdslstat-uptxqueue">');  ngx.print(vdslInfo["upStreamTxQueue"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>LookBack</td>\
                  <td id="vdslstat-dwnlookback">');  ngx.print(vdslInfo["downStreamLookBack"]); ngx.print('</td>\
                  <td id="vdslstat-uplookback">');  ngx.print(vdslInfo["upStreamLookBack"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>RRCBits</td>\
                  <td id="vdslstat-dwnrrcbits">');  ngx.print(vdslInfo["downStreamRRCBits"]); ngx.print('</td>\
                  <td id="vdslstat-uprrcbits">');  ngx.print(vdslInfo["upStreamRRCBits"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>LEFTRS</td>\
                  <td id="vdslstat-dwnleftrs">');  ngx.print(vdslInfo["downStreamLEFTRS"]); ngx.print('</td>\
                  <td id="vdslstat-upleftrs">');  ngx.print(vdslInfo["upStreamLEFTRS"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>miniEFTR</td>\
                  <td id="vdslstat-dwnmineftr">');  ngx.print(vdslInfo["downStreamMinEFTR"]); ngx.print('</td>\
                  <td id="vdslstat-upmineftr">');  ngx.print(vdslInfo["upStreamMinEFTR"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>ErrFreeBits</td>\
                  <td id="vdslstat-dwnerrfreebits">');  ngx.print(vdslInfo["downStreamErrFreeBits"]); ngx.print('</td>\
                  <td id="vdslstat-uperrfreebits">');  ngx.print(vdslInfo["upStreamErrFreeBits"]); ngx.print('</td>\
              </tr>\
          </tbody>\
      </table>\
    </div>\
  </div>\
\
  <h3><span>Vectoring Stats</span></h3>\
  <div class="h3-content vector-stats-table mobile-padding-bottom-lg">\
    <div class="table-responsive">\
      <table class="table no-margin-bottom">\
          <tbody>\
              <tr>\
                  <td>ErrS Packet Send</td>\
                  <td id="vdslstat-errspacketsend">');  ngx.print(vdslInfo["CntESPktSend"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>ErrS Packet Drop</td>\
                  <td id="vdslstat-errspacketdrop">');  ngx.print(vdslInfo["CntESPktDrop"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>ErrS Stat Send</td>\
                  <td id="vdslstat-eersstatsend">');  ngx.print(vdslInfo["CntESStatSend"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>ErrS Stat Drop</td>\
                  <td id="vdslstat-eersstatdrop">');  ngx.print(vdslInfo["CntESStatDrop"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>Direction Mode</td>\
                  <td id="vdslstat-directionmode">');  ngx.print(vdslInfo["DirectionMode"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>Rx BitSwap Mode</td>\
                  <td id="vdslstat-rxbitswapmode">');  ngx.print(vdslInfo["RxBitSwapMode"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>Disable VN Mode</td>\
                  <td id="vdslstat-disablevnmode">');  ngx.print(vdslInfo["DisableVNMode"]); ngx.print('</td>\
              </tr>\
              <tr>\
                  <td>VCE Address</td>\
                  <td id="vdslstat-vceaddress">');  ngx.print(vdslInfo["VceAddress"]); ngx.print('</td>\
              </tr>\
          </tbody>\
      </table>\
    </div>\
  </div>\
\
  <h3><span>DSL Bit Loading</span></h3>\
  <div id="dsl_bit_chart" style="max-width:880px;overflow-x:auto">\
  </div>\
');  end  ngx.print('<!--this is only for vodafone variant = VHA-->\
\
<form id="adslStatus_form" class="form-horizontal" method="post" action="modals/status-support/vdslStatus.lp">\
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
    var target = "/modals/status-support/vdslStatus.lp";\
    var form = $("#adslStatus_form");\
    var params = form.serializeArray();\
    $("#content").load(target, params);\
});\
  $(".vdsl-tbl").before(\'<tr class="adsl-title-bdr"><th></th><th><span>');  ngx.print(T"Downstream"); ngx.print('</span></th><th><span>');  ngx.print(T"Upstream"); ngx.print('</span></th></tr>\');\
});\
\
$.get("/modals/status-support/vdslStatus.lp?action=GET_BITS", function (data) {\
  $(\'#dsl_bit_chart\').replaceWith(data);\
});\
\
</script>\
\
'); 