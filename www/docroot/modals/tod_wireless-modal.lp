--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local match, format = string.match, string.format
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local wifitod_path = "rpc.wifitod."
local tod = require("parental_helper").getTodwifi()
local tod_columns, tod_default, tod_valid, tod_sort_func =
      tod.columns, tod.default, tod.valid, tod.sort_func

-- function that can be used to build table for wifi tod rule
-- @param #start_time have the start time of wifitod rule
-- @param #stop_time have the stop time of wifitod rule
-- @param #day have the weekday of wifitod rule
-- @return #table
local function buildTodRuleTable(start_time, stop_time, day)
   local rule = {}
   rule.start_time = start_time
   rule.stop_time = stop_time
   rule.weekday = day
   return rule
end

-- function to retrieve existing wifitod rules list
-- @return wifitod rules list
local  function getWifiTodRuleLists()
   local rulePath = content_helper.convertResultToObject(wifitod_path, proxy.get(wifitod_path))
   local oldTodRules = {}

   for _,rule in pairs(rulePath) do
      local weekdaysPath = format("rpc.wifitod.%s.weekdays.",rule.paramindex)
      local daysList = content_helper.convertResultToObject(weekdaysPath, proxy.get(weekdaysPath))
      --The DUT will block/allow all the time if none of the days are selected
      if (#daysList == 2) then
         oldTodRules[#oldTodRules + 1] = buildTodRuleTable(rule.start_time, rule.stop_time, "All")
      else
         for _,day in pairs(daysList) do
            if day.value ~= "" then
               oldTodRules[#oldTodRules + 1] = buildTodRuleTable(rule.start_time, rule.stop_time, day.value)
            end
         end
      end
   end
   return oldTodRules
end

local tod_options = {
    tableid     = "tod",
    basepath    = "rpc.wifitod.",
    createMsg   = T"Add New Rule",
    canAdd      = true,
    canDelete   = true,
    canApply    = true,
    canEdit     = true,
    --sorted      = tod_sort_func,
}

local function validateTime(value, object, key)
    local timepattern = "^(%d+):(%d+)$"
    local time = { string.match(value, timepattern) }
    if #time == 2 then
       local hour = tonumber(time[1])
       local min = tonumber(time[2])
       if hour < 0 or hour > 23 then
          return nil, T"Invalid hour, must be between 0 and 23"
       end
       if min < 0 or min > 59 then
          return nil, T"Invalid minutes, must be between 0 and 59"
       end
       return true
    else
       return nil, T"Invalid time (must be hh:mm)"
    end
end

-- function that can be used to validate if the wifitod rule is valid or duplicate or overlap
-- @param #oldTODRules have the rules list of existing wifitod
-- @param #newTODRule have the new rule which is going to be add in wifitod
-- @return #boolean or nil if the rule is duplicate or overlap
local function validateWifiTodRule(oldTODRules, newTODRule)
   local newStart, newEnd, newDay
   local oldStart, oldEnd, oldDay
   local overlap = false
   for _,newrule in ipairs(newTODRule) do
      newStart = newrule.start_time
      newEnd = newrule.stop_time
      newDay = newrule.weekday
      for _,oldrule in ipairs(oldTODRules) do
         oldStart = oldrule.start_time
         oldEnd = oldrule.stop_time
         oldDay = oldrule.weekday
         if(newDay == oldDay) or (newDay == "All") or (oldDay == "All") then
            if(newStart == oldStart and newEnd == oldEnd) then
               message_helper.pushMessage(T"Duplicate contents are not allowed", "error")
               return nil
            else
               -- Determine whether two time ranges overlap, considering the existing schedule time is "03:00~07:00"
               -- cond A: (start and end within range): schedule request examples 1)04:00~05:00 2)03:00~05:00 3)04:00~07:00
               if (newStart >= oldStart and newEnd <= oldEnd) then
                  overlap = true
                  break
               -- cond B: (start out of range): schedule request examples 1)02:00~05:00 2)01:00~03:00 3)02:00~07:00
               elseif (newStart <= oldStart and newEnd >= oldStart and newEnd <= oldEnd) then
                  overlap = true
                  break
               -- cond C: (end out of range): schedule request examples 1)02:00~08:00 2)03:00~09:00 3)01:00~07:00
               elseif (newStart <= oldStart and newEnd >= oldEnd) then
                  overlap = true
                  break
               -- cond D: (start and end out of range): schedule request examples 1)04:00~09:00 2)03:00~10:00 3)07:00~09:00
               elseif (newStart >= oldStart and newStart <= oldEnd and newEnd >= oldEnd) then
                  overlap = true
                  break
               end
            end
         end
      end
      if overlap == true then
         message_helper.pushMessage(T"Overlap contents are not allowed", "error")
         return nil
      end
   end
   return true
end

-- function that can be used to validate weekday
-- @param #value have the value of corresponding key
-- @param #object have the POST data
-- @param #key validation key name
-- @return #boolean or nil+error message
local function validateWeekday(value, object, key)
   local oldTODRules = getWifiTodRuleLists()
   -- adding first wifitod rule so, validation is not required
   if #oldTODRules == 0 then
      return true
   end

   local newTODRule = {}
   --The DUT will block/allow all the time if none of the days are selected
   if (#value == 2) then
      newTODRule[#newTODRule + 1] = buildTodRuleTable(object["start_time"], object["stop_time"], "All")
   else
      -- index start with 3 because userdata is reserved index 1 and 2
      for index = 3, #value do
         newTODRule[#newTODRule + 1] = buildTodRuleTable(object["start_time"], object["stop_time"], value[index])
      end
   end
   return validateWifiTodRule(oldTODRules, newTODRule)
end

tod_valid["start_time"] = validateTime
tod_valid["stop_time"] = validateTime
tod_valid["weekdays"] = validateWeekday

local tod_data, tod_helpmsg = post_helper.handleTableQuery(tod_columns, tod_options, nil, tod_default, tod_valid)
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Time of Day") ); ngx.print('\
');  ngx.print(ui_helper.createMessages(message_helper.popMessages()) ); ngx.print('\
\
<div class="modal-body update">\
\
');  
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-wireless.lp")
  ngx.print('\
\
  <form class="form-horizontal" method="post" action="/modals/tod_wireless-modal.lp">\
    <legend>');  ngx.print( T"Time of day wireless control" ); ngx.print('</legend>\
    ');  ngx.print(
      ui_helper.createTable(tod_columns, tod_data, tod_options, nil, tod_helpmsg)
    ); ngx.print('\
    ');  if ngx.var.request_method == "POST" and (ngx.req.get_post_args().action == "TABLE-NEW" or ngx.req.get_post_args().action == "TABLE-EDIT") then  ngx.print('\
      <script type="text/javascript">\
        var warning = \'<div class="control-group"><div style="padding-top: 12px;" class="controls"><span class="alert">\'\
                      +\'');  ngx.print( T"The Gateway will block/allow all the time if none of the days are selected" ); ngx.print('</span></div></div>\';\
        $(\'#stoptime\').parent().parent().after(warning);\
      </script>\
    ');  end  ngx.print('\
  </form>\
</div>\
\
<script type="text/javascript">\
    $(function () {\
        var opt = {\
            theme: \'android-ics light\',\
            display: \'bubble\',\
            mode: \'scroller\',\
            headerText: false,\
            timeFormat: \'HH:ii\',\
            stepMinute: 15\
        };\
        $("#starttime").mobiscroll().time(opt);\
        $("#stoptime").mobiscroll().time(opt);\
    });\
</script>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 