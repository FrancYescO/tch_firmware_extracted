--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local parental_helper = require("parental_helper")
local proxy = require("datamodel")

local ngx = ngx
local string, table = string, table
local concat, insert = table.concat, table.insert
local ipairs = ipairs
local tonumber = tonumber
local match, gmatch, format, find, untaint = string.match, string.gmatch, string.format, string.find, string.untaint

local tod = parental_helper.getTodwifi()
local tod_columns = tod.columns
local untaint_mt = require("web.taint").untaint_mt
local session = ngx.ctx.session
local telstra_helper = require("telstra_helper")
local symbolv1 = telstra_helper.symbolnamev1

local validDays = post_helper.getValidateInEnumSelect(tod.days)
local validateBoolean = post_helper.validateBoolean
local validMode = post_helper.getValidateInEnumSelect({{"on"}, {"off"}})
local optionallyValidate = post_helper.getOptionalValidation
local getRandomKey = post_helper.getRandomKey

local ap_status_map = setmetatable({
  ["0"] = T"Off",
  ["1"] = T"On"
}, untaint_mt)

local tod_timer_path = "uci.tod.timer."
local tod_action_path = "uci.tod.action."
local tod_wifitod_path = "uci.tod.wifitod."
local tod_ap_path = "uci.tod.ap."

local function validateTime(value, object, key)
    local timepattern = "^(%d+):(%d+)$"
    local time = { match(value, timepattern) }
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

-- validates days (Mon...Sun)
-- @param #table value have the value of corresponding key
-- @return #boolean or nil+error message
local function validateWeekdays(value)
  if not value then
    return nil, T"Invalid day"
  end
  for i, v in ipairs(value) do
    if not validDays(v) then
      return nil, T"Invalid day"
    end
  end
  return true
end

local tod_options = {
    tableid     = "tod",
    basepath    = "uci.tod.action.",
    createMsg   = T"Add New Rule",
    canAdd      = true,
    canDelete   = true,
    canApply    = true,
    canEdit     = true,
    objectName  = "action"..getRandomKey(),
    addNamedObject  = true
}

local function validate_wifitod(index, postcontent, timer_data)
  local todData = {
    enable      = postcontent.enable,
    mode        = postcontent.mode,
    start_time  = postcontent.start_time,
    stop_time   = postcontent.stop_time,
    weekdays    = postcontent.weekdays,
  }
  local todValidations = {
    enable      = validateBoolean,
    mode        = validMode,
    start_time  = validateTime,
    stop_time   = validateTime,
    weekdays    = optionallyValidate(validateWeekdays), -- weekdays can be empty if user didn't select any day
  }

  local success, errmsg = content_helper.validateObject(todData, todValidations)
  if not success then
    return nil, errmsg
  end

  -- day/time overlap validation
  for i, v in ipairs(timer_data) do
    if i ~= postcontent.index then
      local isOverlap, errMsg = parental_helper.daysTimeOverlap(index, postcontent)
      if not isOverlap then
        return nil, errMsg
      end
    end
  end

  return true
end

-- function to add a tod rule and apply the rule
-- @param #success have the index value of the adding tod action
-- @param #content have the posted values which contains ToD table data
-- @param #onModify has the boolean value,false by default, true in rule modification state
-- @param #onActive has the boolean value,false by default, true in active TOD rule modification state
-- if active rule is edited the new action index will be added with its corresponding timers, wifitod, ap paths and finally
-- applied if no overlap or duplicate error found with old rule. old edited rule will be deleted in onModify function
local function onAdd(success, content, onModify, onActive)
  local weekDays
  local index = success:match("action(.+)")
  local setObject = {}

  content.weekdays = parental_helper.formatWeekdays(content)

  local valid, errmsg = validate_wifitod(index, content, session:retrieve("timer_data"))
  if not valid then
    tod_options.errmsg = errmsg
    return nil
  end

  if onActive then
    success = proxy.add(tod_action_path, tod_options.objectName)
    index = success:match("action(.+)")
  end

  content.weekdays = concat(content.weekdays, ",")

  if not onModify then
    proxy.add(tod_action_path .. "@" .. success .. ".timers.")
    proxy.add(tod_timer_path, "timer"..index)
    proxy.add(tod_wifitod_path, "wifitod"..index)
    proxy.add(tod_wifitod_path .. "@wifitod"..index..".ap.")
    proxy.add(tod_ap_path, "ap"..index)
  end

  if content.start_time >= content.stop_time then
    weekDays = parental_helper.calculateStopDay(content.start_time, content.stop_time, content.weekdays)
    content.stop_time = format("%s:%s", weekDays, content.stop_time)
  else
    content.stop_time = format("%s:%s", content.weekdays, content.stop_time)
  end
  content.start_time = format("%s:%s", content.weekdays, content.start_time)

  setObject[format("%s@action%s.timers.@1.value", tod_action_path, index)] = "timer"..index
  setObject[format("%s@action%s.enabled", tod_action_path, index)] = content.enabled
  setObject[format("%s@action%s.script", tod_action_path, index)] = "wifitodscript"
  setObject[format("%s@action%s.object", tod_action_path, index)] = "wifitod.wifitod"..index

  setObject[format("%s@timer%s.start_time", tod_timer_path, index)] = content.start_time
  setObject[format("%s@timer%s.stop_time", tod_timer_path, index)] = content.stop_time

  setObject[format("%s@wifitod%s.ap.@1.value", tod_wifitod_path, index)] = "ap"..index

  setObject[format("%s@ap%s.state", tod_ap_path, index)] = content.mode == "on" and "1" or "0"
  setObject[format("%s@ap%s.ap", tod_ap_path, index)] = "all"
  proxy.set(setObject)
  return true
end

-- function to delete the tod rule
-- @param #success is the index to be deleted
local function onDelete(success)
  local index = success:match("action(.+)")
  proxy.del(format("uci.tod.ap.@ap%s.", index))
  proxy.del(format("uci.tod.action.@action%s.", index))
  proxy.del(format("uci.tod.timer.@timer%s.", index))
  proxy.del(format("uci.tod.wifitod.@wifitod%s.", index))
  return true
end

-- function to edit/modify the existing ToD rule
-- @param #index has the index of rule to be edited
-- @param #content has the posted ToD table data
-- if editing rule is an active rule(currently ongoing) then add a new tod action and its corresponding wifi tod, timer and
-- ap sections, set it. If any error found against the rule already added then delete the newly added action. Else delete the edited
-- rule and apply the newly added rule which avoids the tod restart happens twice
local function onModify(index, content)
  local isActive, isAdd
  isActive = parental_helper.isRuleActive(content)

  if isActive then
    isAdd = onAdd(index, content, false, true)
    if not isAdd then
      proxy.del(tod_action_path .. "@" .. tod_options.objectName .. ".")
      tod_options.editing = -1
    else
      onDelete(index)
    end
  else
    isAdd = onAdd(index, content, true)
    if not isAdd then
      proxy.del(tod_action_path .. "@" .. tod_options.objectName .. ".")
      tod_options.editing = -1
    end
  end
  proxy.apply()
end

if ngx.var.request_method == "POST" then
  local postargs = ngx.req.get_post_args()
  postargs.index = tonumber(postargs.index) or -1
  local current_index = postargs.index
  local allowedIndexes = session:retrieve(tod_options.tableid .. ".allowedindexes") or {}
  current_index = allowedIndexes[current_index] and allowedIndexes[current_index].paramindex or -1

  if postargs.action == "TABLE-NEW" then
    tod_options.editing = -1
  elseif postargs.action == "TABLE-EDIT" then
    tod_options.editing = postargs.index
  elseif postargs.action == "TABLE-ADD" then
    current_index = proxy.add(tod_action_path, tod_options.objectName)
    local success = onAdd(current_index, postargs)
    if not success then
      proxy.del(tod_action_path .. "@" .. tod_options.objectName .. ".")
      tod_options.editing = -1
    end
    proxy.apply()
  elseif postargs.action == "TABLE-MODIFY" then
    onModify(current_index, postargs)
  elseif postargs.action == "TABLE-DELETE" then
    onDelete(current_index)
    proxy.apply()
  end
end

local tod_data, tod_index = content_helper.loadTableData(tod_options.basepath, tod_columns)

local tablesessionindexes = tod_options.tableid .. ".allowedindexes"
session:store(tablesessionindexes, tod_index)

local action_list = content_helper.convertResultToObject(tod_action_path, proxy.get(tod_action_path))
local timer_list = content_helper.convertResultToObject(tod_timer_path, proxy.get(tod_timer_path))
local wifitod_list = content_helper.convertResultToObject(tod_wifitod_path, proxy.get(tod_wifitod_path))
local ap_list = content_helper.convertResultToObject(tod_ap_path, proxy.get(tod_ap_path))
local timer_data = {}

for i, v in ipairs(tod_data) do
  v[1] = v[1] -- status
  v[2] = ap_list[i].ap -- ap
  local days, start_time = timer_list[i].start_time:match("^(.-):(.+)$")
  v[3] = start_time -- start_time
  v[4] = timer_list[i].stop_time:match("^.-:(.+)$") -- stop_time
  v[5] = ap_status_map[ap_list[i].state] -- apState
  v[6] = {} -- days
  for day in gmatch(days, "[^,]+") do
    insert(v[6], untaint(day))
  end
  -- Sub Columns
  v[7] = {
    [1] = v[1], -- status
    [2] = ap_list[i].state == "1" and "on" or "off", -- apState
    [3] = v[3], -- start_time
    [4] = v[4], -- stop_time
    [5] = v[6] -- days
  }
  timer_data[i] = {
    start_time = v[3],
    stop_time = v[4],
    days = v[6]
  }
end

session:store("timer_data", timer_data)

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
    ');  ngx.print(ui_helper.createTable(tod_columns, tod_data, tod_options, nil, tod_helpmsg)); ngx.print('\
    ');  if ngx.var.request_method == "POST" and (ngx.req.get_post_args().action == "TABLE-NEW" or ngx.req.get_post_args().action == "TABLE-EDIT") then  ngx.print('\
      <script type="text/javascript">\
        var warning = \'<div class="control-group"><div style="padding-top: 12px;" class="controls"><span class="alert">\'\
                      +\'');  ngx.print( T("The " .. symbolv1 .. " will block/allow all the time if none of the days are selected") ); ngx.print('</span></div></div>\';\
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
    $(".btn-table-add, .btn-table-modify").click(function() {\
        // ui_helper adds dummy hidden checkbox if no checkboxes are checked. we don\'t need that.\
        if ($("form .additional-edit input[name=weekdays]:visible:checked").length > 0) {\
          $("form input[name=weekdays]:hidden").removeAttr("name");\
        } else {\
          // we need one checkbox when no checkboxes are checked.\
          $("form input[name=weekdays]:hidden").removeAttr("name");\
          $("form input[type=checkbox]:hidden:last").attr("name", "weekdays");\
        }\
    });\
</script>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 