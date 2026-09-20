--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local table = table
local format = string.format
local floor = math.floor
local tonumber = tonumber
local untaint_mt = require("web.taint").untaint_mt
local setmetatable = setmetatable

local xdsl_rpc_path = "sys.class.xdsl.@line0."
local xdsl_BitLoading = xdsl_rpc_path.."BitLoading"
--Constract the new version for the time show style
local function ChangeToStandardTime(time)
  local timeM
  if ((time >= 0) and (time < 10) ) then
      timeM = 0 .. time
      return timeM
  else
      return time
  end
end
--Constract the new style of the standard changement from seconds to time
local function SecondsToTime(SecondsTime,mode)
  local days = floor(SecondsTime / 86400)
  local hours = floor(SecondsTime / 3600) % 24
  local hoursM = ChangeToStandardTime(hours)
  local minutes = floor(SecondsTime / 60) % 60
  local minutesM = ChangeToStandardTime(minutes)
  local seconds = SecondsTime % 60
  local  secondsM = ChangeToStandardTime(seconds)
  if  mode == "InstantTime"  then
     return format("%s:%s:%s", hoursM, minutesM, secondsM)
  elseif  mode == "HistoryTime"  then
     return format(T"%ddays, %s:%s:%s", days, hoursM, minutesM, secondsM)
  else
     return ""
  end
end
--Constract the name mapping for the ModulationType
local modemapping = setmetatable({
  ["ADSL_G.dmt"] = "G.DMT",
  ["ADSL_ANSI_T1.413"] = "T1.413",
  ["ADSL_G.lite"] = "G.lite",
  ["ADSL_G.dmt.bis"] =  "ADSL2",
  ["ADSL_2plus"] = "ADSL2+",
  ["ADSL_re-adsl"] = "RE-ADSL",
  ["VDSL2"] = "VDSL2",
  ["G.fast"] = "G.fast",
},untaint_mt)
local content = {
  dsl_modemtimeuptime = "rpc.system.uptime",
  dsl_currentdaystart = xdsl_rpc_path.."CurrentDayStart",
  dsl_standard = xdsl_rpc_path.."ModulationType",
  dsl_showtime = xdsl_rpc_path.."ShowtimeStart",
  dsl_max_bandwidth_down = xdsl_rpc_path.."DownstreamMaxRate",
  dsl_max_bandwidth_up = xdsl_rpc_path.."UpstreamMaxRate",
}
content_helper.getExactContent(content)
content["system_time"] = os.date("%a %b %d %Y %T %p",os.time())
local result = proxy.get(xdsl_BitLoading) or {}
local xdsl_BitLoading = result[1].value
local function GetLinkValueSYSclassXDSL(contentE,name)
      contentE[1] = xdsl_rpc_path.."LinkRetrain" .. name
      contentE[2] = xdsl_rpc_path.."UpstreamLOS" .. name
      contentE[3] = xdsl_rpc_path.."DownstreamLOS" .. name
      contentE[4] = xdsl_rpc_path.."UpstreamLOF" .. name
      contentE[5] = xdsl_rpc_path.."DownstreamLOF" .. name
      contentE[6] = xdsl_rpc_path.."UpstreamLOM" .. name
      contentE[7] = xdsl_rpc_path.."DownstreamLOM" ..name
      contentE[8] = xdsl_rpc_path.."UpstreamFEC" .. name
      contentE[9] = xdsl_rpc_path.."DownstreamFEC" .. name
      contentE[10] = xdsl_rpc_path.."UpstreamCRC" .. name
      contentE[11] = xdsl_rpc_path.."DownstreamCRC" .. name
      contentE[12] = xdsl_rpc_path.."UpstreamES" .. name
      contentE[13] = xdsl_rpc_path.."DownstreamES" .. name
      contentE[14] = xdsl_rpc_path.."UpstreamSES" .. name
      contentE[15] = xdsl_rpc_path.."DownstreamSES" .. name
      contentE[16] = xdsl_rpc_path.."UpstreamUAS" .. name
      contentE[17] = xdsl_rpc_path.."DownstreamUAS" .. name
      contentE[18] = xdsl_rpc_path.."UpstreamCurrRate"
      contentE[19] = xdsl_rpc_path.."DownstreamCurrRate"
   return contentE
end
local function GetTableFormatValue(InputTableNeed,value,m,n)
     InputTableNeed[1][m] = format("%s",value[1])
     local dslCurrRateUp = floor(value[18]/10)/100
     local dslCurrRateDown = floor(value[19]/10)/100
     if  n==1  then
         InputTableNeed[2][m] = format("%sM/%sM",dslCurrRateDown,dslCurrRateUp)
     else
         InputTableNeed[2][m] = format("-")
     end
     InputTableNeed[3][m] = format("%s/%s",value[2],value[3])
     InputTableNeed[4][m] = format("%s/%s",value[4],value[5])
     InputTableNeed[5][m] = format("%s/%s",value[6],value[7])
     InputTableNeed[6][m] = format("%s/%s",value[8],value[9])
     InputTableNeed[7][m] = format("%s/%s",value[10],value[11])
     InputTableNeed[8][m] = format("%s/%s",value[12],value[13])
     InputTableNeed[9][m] = format("%s/%s",value[14],value[15])
     InputTableNeed[10][m] = format("%s/%s",value[16],value[17])
   return InputTableNeed
end

local contentM_Last_15_min ={}
GetLinkValueSYSclassXDSL(contentM_Last_15_min,"PreviousQuarter")
content_helper.getExactContent(contentM_Last_15_min)
local contentM_Currentday ={}
GetLinkValueSYSclassXDSL(contentM_Currentday,"CurrentDay")
content_helper.getExactContent(contentM_Currentday)
local contentM_Priorday ={}
GetLinkValueSYSclassXDSL(contentM_Priorday,"PreviousDay")
content_helper.getExactContent(contentM_Priorday)
local contentM_Showtime ={}
GetLinkValueSYSclassXDSL(contentM_Showtime,"SinceSync")
content_helper.getExactContent(contentM_Showtime)
local columnsM ={}
for i=1, 10 do
    columnsM[i]={}
end
columnsM[1][1] = T"Link Retrain Count"
columnsM[2][1] = T"Sync Bandwitdh(Down/Up)"
columnsM[3][1] = T"Loss of Sync,LOS(Local/Remote)"
columnsM[4][1] = T"Loss of Framming,LOF(Local/Remote)"
columnsM[5][1] = T"Loss of Margin,LOM(Local/Remote)"
columnsM[6][1] = T"Forward Error Correction,FEC"
columnsM[7][1] = T"Cyclic Redundancy Correction,CRC"
columnsM[8][1] = T"Errored Seconds,ES"
columnsM[9][1] = T"Severely Errored Seconds,SES"
columnsM[10][1] = T"Unavailable Seconds,UAS"
GetTableFormatValue(columnsM,contentM_Last_15_min,2,2)
GetTableFormatValue(columnsM,contentM_Currentday,3,2)
GetTableFormatValue(columnsM,contentM_Priorday,4,2)
GetTableFormatValue(columnsM,contentM_Showtime,5,1)
local datarowsM ={}
for i=1, 5 do
    datarowsM[i]={}
end
datarowsM[1]["header"] = T"Parameters"
datarowsM[2]["header"] = T"Last 15 min"
datarowsM[3]["header"] = T"Current Day"
datarowsM[4]["header"] = T"Prior Day"
datarowsM[5]["header"] = T"Showtime"

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. format("%s", uri:match("/([^/]+)%.lp")) }
if ngx.req.get_uri_args().entry == "bb" then
    help_link.href = help_link.href .. "-bb"
end
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader("Diagnostics DSL", false, true, nil, help_link)); ngx.print('\
\
<div class="modal-body update">\
');  
    local html = {}
    if ngx.req.get_uri_args().entry == "bb" then
    local tabs = {
            {
                desc = T"DSL link status",
                target = "modals/broadband-modal.lp",
            },
            {
                desc = T"Ethernet link status",
                target = "modals/broadband-eth-modal.lp",
            },
            {
                desc = T"DSL Diagnostics",
                active = "active",
                target = "modals/diagnostics-xdsl-modal.lp?entry=bb",
            },
        }
        table.insert (html, ui_helper.createModalTabs(tabs))
        ngx.print (html)
    else
        local lp = require("web.lp")
        lp.setpath("/www/snippets/")
        lp.include("tabs-diagnostics.lp")
    end
  ngx.print('\
\
    ');  
        -- dummy form so that refresh button knows which page to reload, keep it
      ngx.print('\
    <form class="form-horizontal" method="post" action="modals/diagnostics-xdsl-modal.lp">\
\
    <fieldset id="diagnostics-xdsl-tab">\
       <legend>DSL information</legend>\
       ');  
         local html = {}

         local attributes = { span = { class = "span4" } }
         local attributesAdvanced = { group = { class = "advanced hide" }, span = { class = "span4" } }
         html[#html + 1] = ui_helper.createLabel(T"Modem Time",SecondsToTime(content["dsl_modemtimeuptime"],"HistoryTime"), attributes)
         local dslCurrentDayStart = SecondsToTime(content["dsl_currentdaystart"],"InstantTime")
         local dslSystemTime = content["system_time"]
         html[#html + 1] = ui_helper.createLabel(T"Current Day Start",format("%s, %s ago",dslSystemTime,dslCurrentDayStart), attributesAdvanced)
         html[#html + 1] = ui_helper.createLabel(T"Showtime",SecondsToTime(content["dsl_showtime"],"HistoryTime"),attributes)
         local dslStandard = modemapping[content["dsl_standard"]] or content["dsl_standard"]
         html[#html + 1] = ui_helper.createLabel(T"DSL Standard", dslStandard, attributesAdvanced)
         local dslLineRateMaxDown = floor(content["dsl_max_bandwidth_down"]/10)/100
         local dslLineRateMaxUp = floor(content["dsl_max_bandwidth_up"]/10)/100
         html[#html + 1] = ui_helper.createLabel( T"Max Bandwidth Down", format("%sMbps",dslLineRateMaxDown),attributesAdvanced)
         html[#html + 1] = ui_helper.createLabel( T"Max Bandwidth Up", format("%sMbps",dslLineRateMaxUp),attributesAdvanced)
         ngx.print(html)
         ngx.print('\
    </fieldset>\
    </form>\
    <fieldset>\
    <legend>DSL stats</legend>\
    ');  
      local options = { tableid = "xdslstats", canEdit = false, editing = false, minEntries =7 , maxEntries =17, createMsg = "Create new", canAdd = false, canDelete = false, newList = true, errmsg = nil}
        -- table that shows the Statistics data
        ngx.print(ui_helper.createTable(datarowsM, columnsM, options))
     ngx.print('\
   </fieldset>\
    <fieldset>\
      <legend>DSL Bit Loading</legend>\
      <div style="max-width:880px;overflow-x:auto;">\
        <small>\
          ');  
            ngx.print( ui_helper.createBitLoadHistogram(xdsl_BitLoading) )
            ngx.print('\
        </small>\
      </div>\
  </fieldset>\
</div>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 