--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")
local string, table = string, table
local format, untaint, next = string.format, string.untaint, next
local concat = table.concat
local gAV = post_helper.getAndValidation
local gOV = post_helper.getOrValidation
local QTN = post_helper.validateQTN
local advancedIPValidation = post_helper.advancedIPValidation
local validateStringIsIPv6 = post_helper.validateStringIsIPv6
local rIPV = post_helper.reservedIPValidation
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local ordinalNumbers = {T"1st", T"2nd", T"3rd", T"4th", T"5th"}
local errorMessages
local ui_helper = require("vdf_ui_helper")

---
-- Funtion to validate NTP Server
-- If It is IP then it will apply Advanced IPv4 or IPv6 Validation
-- If not, it will apply Domain Name Validation
-- @function validateNTPServer
-- @param value, postObject, key
-- @return #function validator function
local function validateNTPServer(value, object, key)
  if post_helper.validateStringIsIP(value) then
    local IPValidation = gAV(gAV(rIPV, QTN), gOV(advancedIPValidation, validateStringIsIPv6))
    return IPValidation(value, object, key)
  else
    return post_helper.validateStringIsDomainName(value)
  end
end

local NTPParameters  = {
  syncStatus         = "uci.system.ntp.use_dhcp",
  zoneName           = "uci.system.system.@system[0].zonename",
  timeZone           = "uci.system.system.@system[0].timezone",
}
local NTPValidations = {
   syncStatus         = post_helper.validateBoolean,
}

local zoneNames = {}
local timeZones = {}

local supportedTimeZones = require("tz_helper")
local basepath = "uci.system.ntp.server."

local NTPServerPaths = proxy.getPN(basepath, true)

for i = 1, 5 do
  if NTPServerPaths[i] then
    NTPParameters["server" .. i]  = format("%s@%s.value", basepath, i)
    NTPValidations["server" .. i] = post_helper.getOptionalValidation(validateNTPServer)
  end
end

for i = 1, #supportedTimeZones do
  zoneNames[i] = {supportedTimeZones[i].zonename}
  timeZones[i] = {supportedTimeZones[i].timezone}
end

NTPValidations.zoneName = post_helper.getValidateInEnumSelect(zoneNames)
NTPValidations.timeZone = post_helper.getValidateInEnumSelect(timeZones)


local NTPDetails = post_helper.handleQuery(NTPParameters, NTPValidations)
local resetinternettime = {
  reset_timezone = "uci.uci-defaults.internettime.timezone",
  reset_sync_with_internet_time_server = "uci.uci-defaults.internettime.sync_with_internet_time_server",
  reset_1st_ntp_time_server = "uci.uci-defaults.internettime.1st_ntp_time_server",
  reset_2nd_ntp_time_server = "uci.uci-defaults.internettime.2nd_ntp_time_server",
  reset_3rd_ntp_time_server = "uci.uci-defaults.internettime.3rd_ntp_time_server",
  reset_4th_ntp_time_server = "uci.uci-defaults.internettime.4th_ntp_time_server",
  reset_5th_ntp_time_server = "uci.uci-defaults.internettime.5th_ntp_time_server"
}
content_helper.getExactContent(resetinternettime)

if ngx.req.get_method() == "POST" then
  local postargs = ngx.req.get_post_args()
  local ntpValues = {}
  -- While sync status is off add the ntp servers to disabled server list and make ntp server list empty
  if (postargs.syncStatus == "0") then
    for i = 1, 5 do
      if postargs["server" .. i] ~= "" then
        table.insert(ntpValues, untaint(postargs["server" .. i]))
        local serverPath = content_helper.getMatchedContent("uci.system.ntp.server.", { value = untaint(postargs["server" .. i])})
        if next(serverPath) and serverPath[1].path then
          proxy.del(serverPath[1].path)
        end
      end
    end
    if next(ntpValues) then
      local ntpServerList = concat(ntpValues, ",")
      proxy.set({["uci.system.ntp.disabled_servers"] = ntpServerList})
    end
  -- While sync status is on add the disabled server list to ntp server and make disabled server list empty
  elseif(postargs.syncStatus == "1") then
    for i = 1, 5 do
      if postargs["server" .. i] ~= "" and not proxy.getPN(format("%s@%s.", basepath, i), true) then
        proxy.add(basepath)
        NTPParameters["server" .. i]  = format("%s@%s.value", basepath, i)
        NTPValidations["server" .. i] = post_helper.getOptionalValidation(validateNTPServer)
      end
    end
    proxy.set({["uci.system.ntp.disabled_servers"] = ""})
 end
  proxy.apply()
  NTPDetails, errorMessages = post_helper.handleQuery(NTPParameters, NTPValidations)
  if not next(errorMessages) then
    ngx.print('<input type="hidden" id="post_status" value="success">')
  else
    ngx.print('<input type="hidden" id="post_status" value="error">')
  end
end

local syncStatusGet = {
  syncStat = "uci.system.ntp.use_dhcp"
}
content_helper.getExactContent(syncStatusGet)
local getStatus = {
  disabledServers = "uci.system.ntp.disabled_servers"
}
content_helper.getExactContent(getStatus)
local disabledServerList = {}
for server in string.gmatch(getStatus["disabledServers"], '([^,]+)') do
  table.insert(disabledServerList,server)
end
local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")
  ngx.print('\
\
<div class="row">\
  <div class="col-md-12">\
    <h1><span>');  ngx.print(T"Internet Time"); ngx.print('</span></h1>\
  </div>\
</div>\
\
<form id="internet-time-form">\
  <input type="hidden" name="CSRFtoken" id="CSRFtoken" value="');  ngx.print(CSRFtoken); ngx.print('"></input>\
  <input type="hidden" name="action" id="action" value="SAVE"></input>\
  <input type="hidden" name="syncStatus" id="syncStatus" value="');  ngx.print(syncStatusGet.syncStat); ngx.print('" />\
  <h3><span>');  ngx.print(T"Internet Time Settings"); ngx.print('</span></h3>\
  <div class="h3-content mobile-no-float">\
   <div class="vdf-table">\
    <div class="vdf-row">\
      <div class="left mobile-padding-bottom-10">\
        <span>');  ngx.print(T"Time Zone"); ngx.print('</span>\
      </div>\
        <div id="top-info-mode" class="rel right">\
          <input type="hidden" name="zoneName" id="zoneName" value="');  ngx.print(NTPDetails.zoneName); ngx.print('" />\
          <input type="hidden" name="timeZone" id="timeZone" value="');  ngx.print(NTPDetails.timeZone); ngx.print('" />\
          <select class="dropdown" id="internetTime-sel-timezone" style="width: 165px;">\
            ');  for i = 1, #supportedTimeZones do
              ngx.print(format('<option data-timezone="%s" value="%s">%s</option>', timeZones[i][1], zoneNames[i][1], supportedTimeZones[i].text))
            end  ngx.print('\
          </select>\
        </div>\
    </div>\
   </div>\
  </div>\
\
  <div class="h3-content mobile-padding-bottom-lg internet-time-border">\
  <div class="vdf-table">\
  ');  
    row = {
      label = T"Synchronize with Internet Time Server",
      element =ui_helper.createButton({id = "internetTime-btn-syncStatus", class = (syncStatusGet.syncStat == "1" or syncStatusGet.syncStat == "") and "button button-on" or "button button-off"}),
      rowClass = "vdf-row padding-top-bottom-20 internet-time"
    }
    ngx.print(ui_helper.createRow(row))
    ngx.print('\
\
    <!-- TODO - No lower layer support for Update Period and Retry Interval\
    <div class="row padding-top-bottom-20">\
      <div class="col-md-6 col-sm-6 col-xs-12 mobile-padding-bottom-10">\
        <span>');  ngx.print(T"Update Period"); ngx.print('</span>\
      </div>\
      <div class="col-md-6 col-sm-6 col-xs-12 text-right">\
        <input class="full-width" value="" type="text">\
      </div>\
    </div>\
    <div class="row">\
      <div class="col-md-12">\
        <hr/>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20">\
      <div class="col-md-6 col-sm-6 col-xs-12 mobile-padding-bottom-10">\
        <span>');  ngx.print(T"Retry Interval"); ngx.print('</span>\
      </div>\
      <div class="col-md-6 col-sm-6 col-xs-12 text-right">\
        <input class="full-width" value="" type="text">\
      </div>\
    </div>\
    -->\
  \
   ');  
   for i = 1, 5 do
     local ntpValue
     if syncStatusGet["syncStat"] == "1" or syncStatusGet["syncStat"] == "" then
       ntpValue= NTPDetails["server" .. i]
     elseif syncStatusGet["syncStat"] == "0" then
       ntpValue=disabledServerList[i]
     end
     row = {
       label   = format("%s %s", ordinalNumbers[i], T"NTP Time Server"),
       element = ui_helper.createTextField({name= "server"..i, class = "full-width", id = "internetTime-txt-server"..i, type = "text", value = ntpValue or ""}),
       colLeftClass = "left mobile-padding-bottom-10",
       rowClass = "vdf-row internet-time"
     }
     ngx.print(ui_helper.createRow(row))
   end  ngx.print('\
  </div>\
  </div>\
</form>\
\
');  
  lp.include("apply-cancel.lp")
  lp.include("reset-wrap-mobile.lp")
  ngx.print('\
\
<script src="js/global-min.js"></script>\
<script>\
\
  var elements = {\
    NTPServers: "[name*=server]"\
  }\
  var validations = {\
    NTPServers: function(value) { return value == "" || validateDomain(value) }\
  }\
\
  $(function () {\
    $(\'select\').chosen({\
      disable_search_threshold: 100000,\
      allow_single_deselect: true\
    });\
\
    $("#internetTime-sel-timezone").val("');  ngx.print(untaint(NTPDetails.zoneName)); ngx.print('").trigger("chosen:updated");\
\
    $("#internetTime-btn-syncStatus").click(function() {\
      btn_on_off($(this));\
    });\
\
    $("#internetTime-sel-timezone").change(function() {\
      $("#zoneName").val($(this).val());\
      $("#timeZone").val($(this).find("option:selected").data("timezone"));\
    });\
\
    // TODO - Remove this function and have it globally once.\
    $("#global-apply, #modal-apply").click(function() {\
      if(!validateElements(elements, validations)) return false;\
      $("#syncStatus").val($("#internetTime-btn-syncStatus").hasClass("button-on") ? "1" : "0");\
      postHandler("/modals/settings/internetTime.lp", $("#internet-time-form").serializeArray());\
    });\
  });\
\
    $("#resetR, .resetR").click(function() {\
      $("#internetTime-sel-timezone").val("');  ngx.print(untaint(resetinternettime["reset_timezone"])); ngx.print('").trigger("chosen:updated");\
      $("#zoneName").val($("#internetTime-sel-timezone").val());\
      $("#timeZone").val($("#internetTime-sel-timezone option:selected").data("timezone"));\
      $("#internetTime-btn-syncStatus").val("');  ngx.print(resetinternettime["reset_sync_with_internet_time_server"]); ngx.print('");\
      if ("');  ngx.print(resetinternettime["reset_sync_with_internet_time_server"]); ngx.print('" == "1") {\
        $(\'#internetTime-btn-syncStatus\').addClass(\'button-on\').removeClass(\'button-off\');\
      }\
      else\
      {\
        $(\'#internetTime-btn-syncStatus\').addClass(\'button-off\').removeClass(\'button-on\');\
      }\
      $("#internetTime-txt-server1").val("');  ngx.print(resetinternettime["reset_1st_ntp_time_server"]); ngx.print('");\
      $("#internetTime-txt-server2").val("');  ngx.print(resetinternettime["reset_2nd_ntp_time_server"]); ngx.print('");\
      $("#internetTime-txt-server3").val("');  ngx.print(resetinternettime["reset_3rd_ntp_time_server"]); ngx.print('");\
      $("#internetTime-txt-server4").val("');  ngx.print(resetinternettime["reset_4th_ntp_time_server"]); ngx.print('");\
      $("#internetTime-txt-server5").val("');  ngx.print(resetinternettime["reset_5th_ntp_time_server"]); ngx.print('");\
    });\
</script>\
'); 