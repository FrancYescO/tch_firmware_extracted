--pretranslated: do not change this file
 
--Enable localization
gettext.textdomain('webui-core')
local ngx = ngx
local proxy = require("datamodel")
local string = string
local format, match = string.format, string.match
local content_helper = require("web.content_helper")
local ipairs, os = ipairs, os
local json = require("dkjson")

if ngx.req.get_method() == "POST" then
  local postargs = ngx.req.get_post_args()
  local callLogList = json.decode(postargs.delete, 1)
  local success = true
  for _,callLogInstance in ipairs(callLogList) do
    if not proxy.del(format("rpc.mmpbx.calllog.info.%s.",callLogInstance)) then
      success = false
    end
  end
  if success then
    proxy.apply()
  end
end
local phoneBookData = {}
local userName = {}
local sipProfilePath = proxy.get("uci.mmpbxrvsipnet.profile.")
sipProfilePath = content_helper.convertResultToObject("uci.mmpbxrvsipnet.profile.",sipProfilePath)
for _,profileData in ipairs(sipProfilePath) do
  phoneBookData[profileData["uri"]] = true
  userName[profileData["uri"]] = profileData["display_name"]
end
local callLogInfo = {}
  local callLogGetData = proxy.get("rpc.mmpbx.calllog.info.")
  callLogGetData = content_helper.convertResultToObject("rpc.mmpbx.calllog.info.",callLogGetData)

if callLogGetData then
  for i,v in ipairs(callLogGetData) do
    callLogInfo[i] = {}
    callLogInfo[i]["FormatTime"] = string.untaint(v["startTime"]) -- yy-mm-dd hr:min:sec
    local year,month,day,time = match(v["startTime"],"(%d+)%-(%d+)%-(%d+)%s(%d+:%d+)")
    callLogInfo[i]["date"] = format("%02d.%02d.%d",day,month,year) -- dd.mm.yy
    callLogInfo[i]["paramindex"] = v.paramindex
    callLogInfo[i]["startTime"] = time
    callLogInfo[i]["Externalno"] = v["Remoteparty"]
    if phoneBookData[v["Localparty"]] then
      callLogInfo[i]["Myphoneno"] = userName[v["Localparty"]]
    else
      callLogInfo[i]["Myphoneno"] = v["Localparty"]
    end
    callLogInfo[i]["status"] = v["callState"]
    callLogInfo[i]["Connected_time"] = v["connectedTime"]
    callLogInfo[i]["End_time"] = v["endTime"]
    callLogInfo[i]["Call_direction"] = v["Direction"]
  end

  table.sort(callLogInfo,function(startTime1, startTime2)
    local year1, month1,day1,hr1,min1,sec1  = match(startTime1.FormatTime, "(%d+)-(%d+)-(%d+)%s(%d+):(%d+):(%d+)")
    local year2, month2, day2,hr2,min2,sec2 = match(startTime2.FormatTime, "(%d+)-(%d+)-(%d+)%s(%d+):(%d+):(%d+)")
    local time1 = os.time({year = year1, month = month1, day = day1, hour= hr1,min = min1,sec= sec1})
    local time2 = os.time({year = year2, month = month2, day = day2, hour= hr2,min = min2,sec= sec2})
    return time1 > time2
  end)
end

  ngx.print('\
\
<div id ="content" class="call-log-content">\
  <form id="call-log-form" class="form-horizontal" method="post" action="modals/call-log.lp">\
  <h1>');  ngx.print(T"Call Log"); ngx.print('</h1>\
\
  <div class="h3-content mobile-no-float vdf-table">\
    <div class="vdf-row">\
      <div class="left padding-bottom-mobile-10">\
        <span>');  ngx.print(T"Show calls for"); ngx.print('</span>\
      </div>\
      <div id="top-info-mode" class="right rel">\
        <select id = "call-log-select-logtype" class="dropdown" style="width: 165px;">\
        ');  ngx.print(format("<option>%s</option>",T"All Numbers"))
        for _,v in ipairs(sipProfilePath) do
        ngx.print(format("<option>%s</option>",v["display_name"]))
        end  ngx.print('\
        </select>\
      </div>\
    </div>\
  </div>\
\
  <div class="h3-table-content desktop">\
\
    <div class="tabs tabs-bg-4-1 clearfix desktop">\
        <div  class="tabs-all" data-id="all" data-class="tabs-bg-4-1">\
            <span>');  ngx.print(T"All"); ngx.print('</span>\
      </div>\
        <div class="tabs-dialled" data-id="dialled" data-class="tabs-bg-4-2">\
            <div class="cont1">\
                <img src="img/look_4/icons/outgoing.png" alt="outgoing">\
                <span><span>');  ngx.print(T"Dialled"); ngx.print('</span></span>\
            </div>\
        </div>\
        <div class="tabs-received" data-id="received" data-class="tabs-bg-4-3">\
            <div class="cont2">\
\
                <img src="img/look_4/icons/incoming.png" alt="incoming">\
                <span>');  ngx.print(T"Received"); ngx.print('</span></span>\
            </div>\
        </div>\
        <div class="tabs-missed" data-id="missed" data-class="tabs-bg-4-4">\
            <div class="cont3">\
                <img src="img/look_4/icons/missedcall.png" alt="missedcall">\
               <span><span>');  ngx.print(T"Missed"); ngx.print('</span></span>\
            </div>\
        </div>\
    </div>\
    <div class="grey-table-content">\
        <div class="table call-log more-columns">\
            <div class="table-row table-row-head numAll num_home num_office num_guest" style="display: table-row;">\
                <div class="table-col table-col1">&nbsp;</div>\
                <div class="table-col table-col2">\
                    <span>');  ngx.print(T"Date"); ngx.print('</span>\
          </div>\
                <div class="table-col table-col3">\
                    <span>');  ngx.print(T"Time"); ngx.print('</span>                </div>\
                <div class="table-col table-col4" style="width: 140px;">\
                    <span>');  ngx.print(T"External Number"); ngx.print('</span>                </div>\
                <div class="table-col table-col5" style="width: 135px;">\
                    <span>');  ngx.print(T"Your Phone Number"); ngx.print('</span>\
          </div>\
                <div class="table-col table-col6">\
                    <span>');  ngx.print(T"Duration"); ngx.print('</span>                </div>\
                <div class="table-col table-col7">&nbsp;</div>\
                <div class="table-col table-col8">\
                   <input type="checkbox" class="checkbox checkbox-unchecked" type="checkbox" id="call-log-chk-select">\
                    <label for="call-log-chk-select"></label>\
                </div>\
            </div>\
           <!-- Dynamic row  -->\
           <div class = "call-log" id="call-log-tbl-tbody" style="display: table-row-group;">\
            </div>\
        </div>\
    </div>\
\
    <div class="pagination no-margin-top-bottom">\
        <div class="pagination-arrows arrow-left" style="opacity: 0.3;" id="call-log-btn-prev">\
            <img src="img/look_4/icons/arrows/arrow-down.png" alt="">        </div>\
        <div class="pages" id="page"></div>\
        <div class="pagination-arrows arrow-right" style="opacity: 1;" id="call-log-btn-next">\
            <img src="img/look_4/icons/arrows/arrow-down.png" alt="">        </div>\
    </div>\
</div>\
    <div class="h3-table-content mobile">\
    <div class="tabs tabs-bg-4-1 clearfix hidden-sm hidden-md hidden-lg mobile">\
    <div class="tabs-arrow prev">\
      <img src="img/look_4/responsive/icon_down_arrow.png" alt=""></div>\
      <div class="tabs-all tabs-current" data-id="all" data-class="tabs-bg-4-1">');  ngx.print(T"All"); ngx.print('</div>\
        <div class="tabs-dialled tabs-next" data-id="dialled" data-class="tabs-bg-4-2">\
          <div class="cont1">');  ngx.print(T"Dialled"); ngx.print('</div>\
        </div>\
        <div class="tabs-received" data-id="received" data-class="tabs-bg-4-3">\
          <div class="cont2">');  ngx.print(T"Received"); ngx.print('</div>\
        </div>\
        <div class="tabs-missed" data-id="missed" data-class="tabs-bg-4-4">\
          <div class="cont3">');  ngx.print(T"Missed"); ngx.print('</div>\
        </div>\
\
        <div class="tabs-arrow next"><img src="../img/look_4/responsive/icon_down_arrow.png" alt=""></div>\
      </div>\
      <table class="table hidden-sm hidden-md hidden-lg call-log-mtable">\
      <thead></thead>\
      <tbody id="call-log-tbl-tbody-mobile"></tbody>\
      </table>\
      <table class="table hidden-sm hidden-md hidden-lg call-log-mtable" style="display:none">\
      <thead></thead>\
      <tbody id="call-log-tbl-tbody-mobile1"></tbody></table>\
       </div>\
      <div class="row pagination-mobile-view hidden-sm hidden-md hidden-lg">\
        <div class="col-xs-5 select-all-mobile padding">\
          <input type="checkbox" class="checkbox checkbox-unchecked" id="selectAll2"/>\
          <label for="call-log-chk-select">');  ngx.print(T"Select All"); ngx.print('</label>\
        </div>\
        <div class="col-xs-7">\
          <div class="pagination no-margin">\
            <div class="pagination-arrows arrow-left" id="call-log-btn-mobprev">\
              <img src="img/look_4/icons/arrows/responsive_down_arrow.png" alt="Down Arrow"/>\
            </div>\
            <div class="pages" id="mob-page"></div>\
              <div class="pagination-arrows arrow-right" id="call-log-btn-mobnext">\
                <img src="img/look_4/icons/arrows/responsive_down_arrow.png" alt="Down Arrow"/>\
              </div>\
            </div>\
          </div>\
        </div>\
        <div class="row">\
          <div class="col-md-12 col-sm-12 col-xs-12 pull-right text-right">\
            <input id = "call-log-btn-delete" class="button call-log-btn-delete mob-button-width table-button-faded" value="');  ngx.print(T"Delete"); ngx.print('" type="button" disabled="disabled">\
            <input id = "call-log-btn-refresh" class="button button-Refresh call-log-btn-refresh mob-button-width" value="');  ngx.print(T"Refresh"); ngx.print('" type="button">\
          </div>\
        </div>\
\
        <div class="row">\
        <!-- Modal -->\
        <div class="modal" id="delConfirm" role="dialog" data-keyboard="false" data-backdrop="static">\
          <div class="modal-dialog">\
            <!-- Modal content-->\
            <div class="modal-content">\
              <div class="modal-header hidden-md hidden-sm hidden-lg">\
                <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
             </div>\
              <div class="modal-body">\
                <p class="title">');  ngx.print(T"Are you sure you want to delete the selected records?"); ngx.print('</p>\
              </div>\
            <div class="modal-body">\
              <div class="apply-cancel">\
                <input id="call-log-btn-popupdelete" class="button button-apply " data-popup-hide="" value="');  ngx.print(T"Delete"); ngx.print('" type="button">\
                <input id="call-log-btn-popupcancel" class="button button-cancel " value="');  ngx.print(T"Cancel"); ngx.print('" type="button" data-dismiss="modal">\
              </div>\
            </div>\
          </div>\
        </div>\
      </div>\
    </div>\
  </div>\
</form>\
</div>\
<script>\
    var callLogInfo = ');  ngx.print(json.encode(callLogInfo)); ngx.print('\
    var T = {\
      "Today" : "');  ngx.print(T"Today"); ngx.print('",\
      "Yesterday" : "');  ngx.print(T"Yesterday"); ngx.print('",\
      "JANUARY" : "');  ngx.print(T"JANUARY"); ngx.print('",\
      "FEBRUARY" : "');  ngx.print(T"FEBRUARY"); ngx.print('",\
      "MARCH" : "');  ngx.print(T"MARCH"); ngx.print('",\
      "APRIL" : "');  ngx.print(T"APRIL"); ngx.print('",\
      "MAY" : "');  ngx.print(T"MAY"); ngx.print('",\
      "JUNE" : "');  ngx.print(T"JUNE"); ngx.print('",\
      "JULY" : "');  ngx.print(T"JULY"); ngx.print('",\
      "AUGUST" : "');  ngx.print(T"AUGUST"); ngx.print('",\
      "SEPTEMBER" : "');  ngx.print(T"SEPTEMBER"); ngx.print('",\
      "OCTOBER" : "');  ngx.print(T"OCTOBER"); ngx.print('",\
      "NOVEMBER" : "');  ngx.print(T"NOVEMBER"); ngx.print('",\
      "DECEMBER" : "');  ngx.print(T"DECEMBER"); ngx.print('"\
    };\
</script>\
<script src="js/call-log.js"></script>\
'); 