--pretranslated: do not change this file
 
--Enable Localization
gettext.textdomain('webui-core')

local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local vdf_helper = require("vodafone_helper")
local proxy = require("datamodel")
local string = string
local ipairs = ipairs
local gmatch, format, untaint, match = string.gmatch, string.format, string.untaint, string.match
local untaint_mt = require("web.taint").untaint_mt
local sort = table.sort
local session = ngx.ctx.session
local json = require("dkjson")
local validateLength = post_helper.getValidateStringLengthInRange(1,63)
local gVIES = post_helper.getValidateInEnumSelect
local setTable = {}
local todData = {}
local profileList, validProfile = {}, {}
local daysMap = vdf_helper.getDays()
local dayTable = vdf_helper.getDayTable()
local dayTypesTable = vdf_helper.getDayTypes()
local timerPath = "uci.tod.timer."
local actionPath = "uci.tod.action."
local key = ("%02X"):rep(16)
local fd = assert(io.open("/dev/urandom", "r"))
local rngshdContent, rngshdmsg

local validStatus = {
  {"on", T"enabled"},
  {"off", T"disabled"},
}

local profileTable = {
  ["All"] = T"All",
}
local sipProfileNumber = content_helper.convertResultToObject("uci.mmpbxrvsipnet.profile.",proxy.get("uci.mmpbxrvsipnet.profile."))

if sipProfileNumber then
  profileList = setmetatable({
    [untaint(sipProfileNumber[1].uri)] = "dnd_profile1",
    [untaint(sipProfileNumber[2].uri)] = "dnd_profile2",
    ["All"]                   = "dnd_all_profiles",
  }, untaint_mt)

  validProfile = setmetatable({
    {untaint(sipProfileNumber[1].uri), untaint(sipProfileNumber[1].uri)},
    {untaint(sipProfileNumber[2].uri), untaint(sipProfileNumber[2].uri)},
    {"All",     T"All"},
  }, untaint_mt)
end

local existingRules = content_helper.convertResultToObject("uci.tod.timer.", proxy.get("uci.tod.timer."))
local profile1TimersList = content_helper.convertResultToObject("uci.tod.action.@dnd_profile1.timers.",proxy.get("uci.tod.action.@dnd_profile1.timers."))
local profile2TimersList = content_helper.convertResultToObject("uci.tod.action.@dnd_profile2.timers.",proxy.get("uci.tod.action.@dnd_profile2.timers."))
local allProfileTimersList = content_helper.convertResultToObject("uci.tod.action.@dnd_all_profiles.timers.",proxy.get("uci.tod.action.@dnd_all_profiles.timers."))

rngshdContent = {
  profileStatus = "uci.tod.voicednd.ringing",
  todStatus = "uci.tod.voicednd.enabled",
}content_helper.getExactContent(rngshdContent)

local function getIndividualDays(days)
  local individualDays = {}
  for day in string.gmatch(days,"([%w]+)") do
    individualDays[#individualDays +1] = untaint(daysMap[day].text)
  end
  return table.concat(individualDays, ", ")
end

--Populating existing TOD Rules in todData table
--@function todRules
--@param #timerStateList. #profile contain data of each profile.
--@return table contain set of tod rules.
local function todRules(timerStateList, profile)
 for _, timer in ipairs(timerStateList) do
  for _,rule in ipairs (existingRules) do
    local scheduledDays, scheduledStartTime = match(rule["start_time"],"([%w%,]+)%:([%d%:]+)")
    local _, scheduledStopTime = match(rule["stop_time"],"([%w%,]+)%:([%d%:]+)")
    local dayList = {}
    for day in string.gmatch(scheduledDays,"([%w]+)") do
      dayList[#dayList +1] = untaint(day)
    end
    local daysOfWeek = table.concat(vdf_helper.sortDays(dayList), ", ")
    if "@"..timer["value"] == rule["paramindex"] then
      todData[#todData +1 ] = {}
      todData[#todData].profileText = profile
      todData[#todData].profileName = profileTable[profile] and profileTable[profile] or profile
      todData[#todData].status = rngshdContent["profileStatus"]
      todData[#todData].startTime = scheduledStartTime
      todData[#todData].stopTime =  scheduledStopTime
      todData[#todData].index = timer["value"]
      todData[#todData].dayType = {
        value = dayTable[daysOfWeek] and dayTable[daysOfWeek].value or "Individual Days",
        text = dayTable[daysOfWeek] and dayTable[daysOfWeek].text or T"Individual Days"
      }
      todData[#todData].weekdays = daysOfWeek
    end
  end
 end
end
--retrieving  profile1 scheduled timer list
todRules(profile1TimersList, sipProfileNumber[1].uri )

--retrieving  profile2 scheduled timer list
todRules(profile2TimersList,sipProfileNumber[2].uri)

--retrieving  profile1 scheduled timer list
todRules(allProfileTimersList,"All")

--sorting todDate based on timer name
sort(todData , function (a, b) return a.index < b.index end)

--function to generate random for new rule
--@function generate_key
--@return 16 digit random key.
function generate_key()
  local bytes = fd:read(16)
  return key:format(bytes:byte(1,16))
end

--function validate time will validate number should contain only digit and colon.
--@function validateTime
--@param #value #postData, #key contains value and postdata and key to which validation needs to occur.
--@return boolean.
local function validateTime(value, postData, key)
  if value then
    if postData["start_time"] == postData["stop_time"] then
      return nil
    end
    local isValidTime = vdf_helper.validateTime(value)
    if isValidTime ~= true then
      return nil
    end
    return true
  end
end

--validation function for Post Data.
--@function validateTODRules
--@param #postData contain entire post data
--@return boolean
local function validateTODRules(postData)
  local todContent = {
    profile     = postData["profile"],
    start_time  = postData["starttime"],
    stop_time   = postData["stoptime"],
    day         = postData["days"],
   }
   local todValidations = {
    profile     = gVIES(validProfile),
    day         = vdf_helper.validateDays,
    start_time  = validateTime,
    stop_time   = validateTime,
   }
  if  not (content_helper.validateObject(todContent, todValidations)) then
    return nil
   end
  return true
end

--Overlap check for value within newly adding entry.
--@function overlapWithinNewEntry
--@data contain post values of add and edit
--@description within postdata check for if there is any overlap between days,
-- then time overlap will be checked.
--@return #boolean
local function overlapWithinNewEntry(data)
  if  #data > 1 then
    -- firstDay have days list of first entry in postArgs,
    -- @data[1].days have values (Every Day, Every Workday, All Weekend or some individualDays)
    local firstDay = dayTypesTable[data[1].days]
    if not firstDay then
      -- iterate over individualDays and formed in table
      firstDay = {}
      for day in gmatch(data[1].days, "[^,%s]+") do
        firstDay[#firstDay+1] = day
      end
    end
    local newDays ={}
    for _, day in ipairs(firstDay) do
      newDays[day]= true
    end
    for index, value in ipairs(data) do
      if index >= 2 then
        -- currentDay have days list of other entry in postArgs,
        -- @value.days have values (Every Day, Every Workday, All Weekend or some individualDays)
        local currentDay = dayTypesTable[value.days]
        local currentDay = dayTypesTable[value.days]
        if not currentDay then
          -- iterate over individualDays and formed in table
          currentDay = {}
          for day in gmatch(value.days, "[^,%s]+") do
            currentDay[#currentDay+1] = day
          end
        end
        for _,day in ipairs(currentDay) do
          if newDays[day] and  value.profile == data[1].profile or data[1].profile == "All" or value.profileName == "All" then
            local starta = untaint(data[1].starttime)
            local enda = untaint(data[1].stoptime)
            local startb = untaint(value.starttime)
            local endb = untaint(value.stoptime)
            local overlap = vdf_helper.overlapCheck(starta, enda, startb, endb)
            if overlap ~= true  then
             return nil
            end
          end
        end
      end
    end
  end
  return true
end

--Overlap check for new entry with existing entry.
--@function overlapWithExistingEntry
--@data contain post values of add and edit
--@description within postdata check for if there is any overlap between days,
-- then time overlap will be checked.
--@return #boolean
local function overlapWithExistingEntry(data)
  local dayMatch = false
  local overlap  = false
  local setIndex
  if data then
    local oldTOD = todData
    setIndex = data.index or 0
    -- newDayValue have days list of add entry in postArgs,
    -- @data.days have values (Every Day, Every Workday, All Weekend or some individualDays)
    local newDayValue = dayTypesTable[data.days]
    if not newDayValue then
       -- iterate over individualDays and formed in table
       newDayValue = {}
      for day in gmatch(data.days, "[^,%s]+") do
        newDayValue[#newDayValue+1] = day
      end
    end
   local newDays ={}
    for _, day in ipairs(newDayValue) do
      newDays[day]= true
    end
    -- Check with existing oldTOD data, to find any overlap in days.
    for _, day in ipairs(oldTOD) do
      for val in gmatch(day.weekdays, "[^,%s]+") do
        if newDays[val]  then
          dayMatch = true
          break
        end
      end
      if dayMatch then
        break
      end
    end
    --if overlap in day found then time overlap will be checked.
    if dayMatch then
      for _, time in ipairs(oldTOD) do
        if setIndex ~= time.index then
          if time.profileName == data.profile or data.profile == "All" or time.profileName == "All" then
            for val in gmatch(time.weekdays, "[^,%s]+") do
              if newDays[val]  then
                local starta = untaint(data.starttime)
                local enda = untaint(data.stoptime)
                local startb = untaint(time.startTime)
                local endb = untaint(time.stopTime)
                local overlap = vdf_helper.overlapCheck(starta, enda, startb, endb)
                if overlap ~= true  then
                  return nil
                end
              end
            end
          end
        end
      end
    end
   return true
  end
end

-- Common function for adding new timer and action value in TOD config.
--@function newTODRules
--@param #data contain new tod rules to be added in config.
local function newTODRules(data)
  local index = "timer"..generate_key()
  local addedIndex  = proxy.add(timerPath, index)
  local day = vdf_helper.completeDays(data["days"])
  day = table.concat(day,",")
  setTable[format("%s@%s.start_time",timerPath, addedIndex)] = day..":"..data.starttime
  setTable[format("%s@%s.stop_time",timerPath,addedIndex)] = day..":"..data.stoptime
  local actionIndex = proxy.add(format("%s@%s.timers.", actionPath, profileList[data.profile]))
  proxy.set(format("%s@%s.timers.@%s.value",actionPath, profileList[data.profile], actionIndex), index)
end


--Common function to update todRules based on status of rule.
--@function #updateTODRules
--@param #updateList contain tod rules to be updated in config.
local function updateTODRules(updateList)
  for _, data in ipairs(updateList) do
    local existingProfile
    local existingIndex
    for _, index in ipairs(profile1TimersList) do
      if index.value == data.index then
        existingIndex = index.paramindex
        existingProfile = sipProfileNumber[1].uri
      end
    end
    for _, index in ipairs(profile2TimersList) do
      if index.value == data.index then
        existingIndex = index.paramindex
        existingProfile = sipProfileNumber[2].uri
      end
    end
    for _, index in ipairs(allProfileTimersList) do
      if index.value == data.index then
        existingIndex = index.paramindex
        existingProfile = "All"
      end
    end
    local day = vdf_helper.completeDays(data["days"])
    day = table.concat(day,",")
    if existingProfile == data.profileName then
      setTable[format("%s@%s.start_time", timerPath, data.index)] = day..":"..data.starttime
      setTable[format("%s@%s.stop_time",timerPath, data.index)] = day..":"..data.stoptime
    else
      proxy.del(format("%s@%s.timers.%s.",actionPath, profileList[untaint(existingProfile)], existingIndex))
      proxy.get(actionPath)
      setTable[format("%s@%s.start_time",timerPath, data.index)] = day..":"..data.starttime
      setTable[format("%s@%s.stop_time",timerPath, data.index)] = day..":"..data.stoptime
      local actionIndex = proxy.add(format("%s@%s.timers.",actionPath, profileList[data.profile]))
      proxy.set(format("%s@%s.timers.@%s.value",actionPath, profileList[data.profile], actionIndex),data.index)
    end
  end
end

--Common function to handle all post action.
--@function #handleTODPostData
--@params #addList, #updateList, #deleteList contain post data of add, update and delete.
--@param actionModified contains flag whether tod status or profile status is modified.
--@return boolean.
function handleTODPostData(addList, updateList, deleteList, actionModified)
  local validateNewData = {}

  --overlap vlaidations for new value
  for index in ipairs(addList) do
    validateNewData[#validateNewData + 1] = addList[index]
  end
  for index in ipairs(updateList) do
    validateNewData[#validateNewData + 1] = updateList[index]
  end
  if  not overlapWithinNewEntry(validateNewData)  then
    return nil
  end

  -- validation for update entry
  for _, data in ipairs(updateList) do
    if not(validateTODRules(data) and overlapWithExistingEntry(data)) then
       return nil
    end
  end

  -- validation for add entry
  for _, data in ipairs(addList) do
    if not(validateTODRules(data) and overlapWithExistingEntry(data)) then
       return nil
    end
  end

  -- Delete schedule entry  from tod config
  local profiletoDelete
  local deleteIndex
  for _, data in ipairs(deleteList) do
    proxy.del(format("%s@%s.",timerPath, data.index))
    for _, index in ipairs(profile1TimersList) do
      if index.value == data.index then
        profiletoDelete = sipProfileNumber[1].uri
        deleteIndex = index.paramindex
      end
    end
    for _, index in ipairs(profile2TimersList) do
      if index.value == data.index then
        profiletoDelete = sipProfileNumber[2].uri
        deleteIndex = index.paramindex
      end
    end
    for _, index in ipairs(allProfileTimersList) do
      if index.value == data.index then
        profiletoDelete = "All"
        deleteIndex = index.paramindex
      end
    end
    proxy.del(format("%s@%s.timers.%s.",actionPath, profileList[untaint(profiletoDelete)], deleteIndex))
  end

  --Update schedule entry in tod config
  updateTODRules(updateList)

  --Add schedule entry in tod config
  for _, data in ipairs(addList) do
    newTODRules(data)
  end
  --If any one timers and action modified together
  if ((actionModified == "true") and ((#updateList > 0) or (#addList > 0) or (#deleteList > 0))) then
     setTable["uci.tod.voicednd.timerandactionmodified"] = "1"
  end
  proxy.set(setTable)
  proxy.apply()
  return true
end
local resetringingschedule = {
  reset_ringinsschedule_enable = "uci.uci-defaults.ringingschedule.ringinsschedule_enable",
  reset_duringthistime = "uci.uci-defaults.ringingschedule.duringthistime",
}
content_helper.getExactContent(resetringingschedule)

if ngx.req.get_method() == "POST" then
  ngx.header.content_type = "application/json"
  local postArgs = ngx.req.get_post_args()
  local tableList = json.decode(untaint(postArgs.tableRequest), 1, nil)
  tableList = setmetatable(tableList, untaint_mt)
  local deleteList = tableList.DELETE
  local addList = tableList.ADD
  local updateList = tableList.UPDATE
  local postResult = handleTODPostData(addList, updateList, deleteList, postArgs.actionModified)
  if postResult then
    local params = {
      profileStatus = "uci.tod.voicednd.ringing",
      todStatus = "uci.tod.voicednd.enabled",
    }
    local validations = {
      profileStatus = gVIES(validStatus),
      todStatus =   post_helper.validateBoolean,
    }
    rngshdContent, rngshdmsg = post_helper.handleQuery(params, validations)
    if next(rngshdmsg) then
      ngx.print('{"status":"error"}')
    else
      ngx.print('{"status":"success"}')
    end
  else
    ngx.print('{"status":"error"}')
  end
  ngx.exit(ngx.HTTP_OK)
end
local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")
  ngx.print('\
\
\
<h1><span>');  ngx.print(T"Ringing Schedule "); ngx.print('</span></h1>\
<h2><span>');  ngx.print(T"Define schedules when your phones should or should not ring."); ngx.print('</span></h2>\
<div class="ringingScheduleContent">\
    <div class="h3-content no-padding-bottom vdf-table">\
        <div class="vdf-row mobile-row-half">\
            <div class="left">\
                <span>');  ngx.print(T"Ringing Schedule "); ngx.print('</span>           </div>\
            <div class="right">\
                <input type = "hidden" name="todStatus" id= "rngshd-hid-todstatus" value = "');  ngx.print(rngshdContent["todStatus"]); ngx.print('"></input>\
                <div class="button ');  if rngshdContent["todStatus"] == "1" then   ngx.print(' button-on ');  else   ngx.print(' button-off ');  end  ngx.print('" id="rngshd-btn-todstatus"></div>\
            </div>\
        </div>\
    </div>\
    <div class="level-3 hide-all shadowProblem">\
        <div class="h3-content vdf-table">\
            <div class="vdf-row assign-row">\
                <div class="left">\
                    <span>');  ngx.print(T"During this time ringing is"); ngx.print('</span>                </div>\
                    <div id="top-info-mode" class="right rel">\
                        <select id="rngshd-select-status">\
                          ');  for _, status in ipairs(validStatus) do
                            if rngshdContent and rngshdContent.profileStatus == status[1] then
                               ngx.print(format("<option selected='selected' value='%s'>%s</option>", status[1], status[2]))
                             else
                               ngx.print(format("<option value='%s'>%s</option>", status[1], status[2]))
                            end
                          end   ngx.print('\
                        </select>\
                    </div>\
            </div>\
        </div>\
        <div class="h3-content vdf-table">\
            <div class="mobile mobile-table" id="rngshd-tbl-mobschedule">\
               ');  for  _, rules in ipairs (todData) do   ngx.print('\
                <div class="mobile-table-row">\
                    <div class="vdf-row mobile-row-half">\
                        <div class="left time">\
                            <span>');  ngx.print(T"from"); ngx.print('&nbsp;</span>');  ngx.print(rules.startTime); ngx.print('<span>&nbsp;');  ngx.print(T"to"); ngx.print('&nbsp;</span>');  ngx.print(rules.stopTime); ngx.print('\
                        </div>\
                        <div class="right">\
                            <div class="schedule-on status"><span>');  if rules.status == "off" then  ngx.print(T"disabled"); else  ngx.print(T"enabled"); end  ngx.print('</span></div>\
                        </div>\
                    </div>\
                    <div class="vdf-row">\
                        <div class="left">\
                            <input type="hidden" class="dayType" value="');  ngx.print(rules.dayType.value); ngx.print('">\
                            <input type="hidden" class="days" value="');  ngx.print(rules.weekdays); ngx.print('">\
                            <span class="weekday">');  ngx.print(rules.dayType.value == "Individual Days" and getIndividualDays(rules.weekdays) or rules.dayType.text); ngx.print('</span>\
                        </div>\
                    </div>\
                    <div class="vdf-row number-row">\
                        <div class="left profile">\
                            <span>');  ngx.print(rules.profileName); ngx.print('</span></div>\
                    </div>\
                    <div class="vdf-row mobile-row-half mobile-button-row">\
                        <div class="left">\
                            <input class="button button-edit" value="" type="button">\
                        </div>\
                        <div class="right">\
                            <input class="button button-delete" value="" type="button">\
                        </div>\
                    </div>\
                </div>\
              ');  end  ngx.print('\
                <div class="mobile-table-row noEntryTD tC italic" id="mob-no-rule">\
                    <span>');  ngx.print(T"No Ringing Schedule defined"); ngx.print('</span>                </div>\
                <div class="mobile-table-row btnAdd" id ="mob-last-row">\
                    <input class="button button-add right popup-add" id="rngshd-btn-mobadd" value="" type="button" data-toggle="modal" data-target="#ringing-schedule-popup-add">\
                </div>\
            </div>\
            <table class="table-three-columns schedule-off" id="schedule-table">\
                <thead>\
                    <tr>\
                    <th style="width: 133px;"><span>');  ngx.print(T"Day"); ngx.print('</span></th>\
                    <th style="width: 159px;"><span>');  ngx.print(T"Time"); ngx.print('</span></th>\
                    <th style="width: 99px;"><span>');  ngx.print(T"Number"); ngx.print('</span></th>\
                    <th style="width: 75px;"><span>');  ngx.print(T"Status"); ngx.print('</span></th>\
                    <th style="width: 40px;">&nbsp;</th>\
                    <th style="width: 50px;">&nbsp;</th>\
                    </tr>\
                </thead>\
                <tbody>\
                <tr>\
                    <td colspan="6" class="noEntryTD tC italic" id="des-no-rule">\
                        <span>');  ngx.print(T"No Ringing Schedule defined"); ngx.print('</span>                    </td>\
                </tr>\
                ');  for  _, rules in ipairs (todData) do   ngx.print('\
                <tr class="cloned">\
                    <td>\
                      <input type="hidden" class="dayType" value="');  ngx.print(rules.dayType.value); ngx.print('">\
                      <input type="hidden" class="days" value="');  ngx.print(rules.weekdays); ngx.print('">\
                      <span class="weekday">');  ngx.print(rules.dayType.value == "Individual Days" and getIndividualDays(rules.weekdays) or rules.dayType.text); ngx.print('</span>\
                    </td>\
                    <td class = "time"><span>');  ngx.print(T"from"); ngx.print('&nbsp;</span>');  ngx.print(rules["startTime"]); ngx.print('<span>&nbsp;');  ngx.print(T"to"); ngx.print('&nbsp;</span>');  ngx.print(rules["stopTime"]); ngx.print('</td>\
	              <td class = "profile" data-profile = "');  ngx.print(rules["profileText"]); ngx.print('"> <span>');  ngx.print(rules["profileName"]); ngx.print('</span></td>\
                    <td>\
                        <div class="schedule-on status"><span>');  if rules.status == "off" then  ngx.print(T"disabled"); else  ngx.print(T"enabled"); end  ngx.print('</span></div>\
                    </td>\
                    <td><input class="button button-edit" value="" type="button" data-toggle="modal" data-target="#ringing-schedule-popup-edit" onclick="copyEditableFields(this)" data-value=');  ngx.print(rules["index"]); ngx.print('></td>\
                    <td><input class="button button-delete" value="" type="button" data-value=');  ngx.print(rules["index"]); ngx.print('></td>\
                </tr>\
                ');  end   ngx.print('\
                <tr class="btnAdd" id = "last-row">\
                <td>&nbsp;</td>\
                <td>&nbsp;</td>\
                <td>&nbsp;</td>\
                <td>&nbsp;</td>\
                <td>&nbsp;</td>\
                <td>\
                    <input class="button button-add right popup-add" id="rngshd-btn-add" value="" type="button" data-toggle="modal" data-target="#ringing-schedule-popup-add">\
                </td>\
                </tr>\
                </tbody>\
            </table>\
        </div>\
    </div>\
</div>\
');  
  lp.include("apply-cancel.lp")
  lp.include("reset-wrap-mobile.lp")
  ngx.print('\
\
\
<!-- Add Ringing Schedule Popup Modal-->\
<div class="ringingSchedule modal fade" id="ringing-schedule-popup-add" role="dialog" data-backdrop="static">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
    <div class="modal-header hidden-sm hidden-md hidden-lg">\
        <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
    </div>\
      <div class="modal-body no-padding">\
        <form class="form-horizontal">\
                <p class="title">');  ngx.print(T"Add a new Ringing Schedule"); ngx.print('</p>\
                <div class="vdf-row assign-row14">\
                    <div class="left" style="padding-right: 70px; width: 54%;">\
                        <span>');  ngx.print(T"Assign to these numbers"); ngx.print('</span>:\
                    </div>\
                    <div class="right">\
                        <div id="top-info-mode" class="rel">\
                            <select id = "rngshd-select-profile">\
                                <option value="All">');  ngx.print(T"All"); ngx.print('</option>\
                                  ');  for index, profile in ipairs(sipProfileNumber) do
                                      ngx.print(format("<option value='%s'>%s</option>", profile["uri"], profile["uri"]))
                                  end   ngx.print('\
                            </select>\
                        </div>\
                    </div>\
                </div>\
                <div class="vdf-row">\
                    <div class="left" style="width: 54%;">\
                        <span>');  ngx.print(T"Time Frame"); ngx.print('</span>     </div>\
                        <div class="right">\
                            <div id="top-info-mode" class="rel">\
                                <select id="rngshd-select-day">\
                                    <option value="Individual Days">');  ngx.print(T"Individual Days"); ngx.print('</option>\
                                    <option value="Every Day">');  ngx.print(T"Every Day"); ngx.print('</option>\
                                    <option selected="selected" value="Every Workday">');  ngx.print(T"Every Workday"); ngx.print('</option>\
                                    <option value="All Weekend">');  ngx.print(T"All Weekend"); ngx.print('</option>\
                                </select>\
                            </div>\
                        </div>\
                </div>\
\
                <style type="text/css">\
                    .individual-left, .individual-right {\
                        float: left;\
                        width: 150px;\
                    }\
                    #individualDays2 .right {\
                        display: block;\
                        width: 300px;\
                    }\
\
                    #individualDays2 .left {\
                        vertical-align: top;\
                    }\
                </style>\
                <div id="individualDays2">\
                    <div class="mobile vdf-row" id="rngshd-div-mobinddays">\
                        <div class="right no-text-align">\
                            <input id="MobMon" data-index="1" class="checkbox checkbox-unchecked ch2" type="checkbox">\
                            <label for="MobMon"></label>\
                            <span>');  ngx.print(T"Monday"); ngx.print('</span></div>\
                        <div class="right no-text-align">\
                            <input id="MobTue" data-index="2" class="checkbox checkbox-unchecked ch4" type="checkbox">\
                            <label for="MobTue"></label>\
                            <span>');  ngx.print(T"Tuesday"); ngx.print('</span></div>\
                        <div class="right no-text-align">\
                            <input id="MobWed" data-index="3" class="checkbox checkbox-unchecked ch5" type="checkbox">\
                            <label for="MobWed"></label>\
                            <span>');  ngx.print(T"Wednesday"); ngx.print('</span></div>\
                        <div class="right no-text-align">\
                            <input id="MobThu" data-index="4"  class="checkbox checkbox-unchecked ch6" type="checkbox">\
                            <label for="MobThu"></label>\
                            <span>');  ngx.print(T"Thursday"); ngx.print('</span></div>\
                        <div class="right no-text-align">\
                            <input id="MobFri" data-index="5" class="checkbox checkbox-unchecked ch7" type="checkbox">\
                            <label for="MobFri"></label>\
                            <span>');  ngx.print(T"Friday"); ngx.print('</span></div>\
                        <div class="right no-text-align">\
                            <input id="MobSat" data-index="6" class="checkbox checkbox-unchecked ch1" type="checkbox">\
                            <label for="MobSat"></label>\
                            <span>');  ngx.print(T"Saturday"); ngx.print('</span></div>\
                        <div class="right no-text-align">\
                            <input id="MobSun" data-index="7" class="checkbox checkbox-unchecked ch3" type="checkbox">\
                            <label for="MobSun"></label>\
                            <span>');  ngx.print(T"Sunday"); ngx.print('</span></div>\
                    </div>\
                    <div class="no-mobile vdf-row rngshd-div-inddays">\
                      <div class="left space-right" style="width:53%;">\
                            <span>');  ngx.print(T"Select Individual Days"); ngx.print('</span>       </div>\
                      <div class="right no-text-align" style="width: 24%;">\
                        <input id="Mon" data-index="1" class="checkbox checkbox-unchecked ch2" type="checkbox">\
                        <label for="Mon"></label>\
                        <span>');  ngx.print(T"Monday"); ngx.print('</span></div>\
                      <div class="right no-text-align" style="width: 23%;">\
                        <input id="Sat" data-index="6" class="checkbox checkbox-unchecked ch1" type="checkbox">\
                        <label for="Sat"></label>\
                       <span>');  ngx.print(T"Saturday"); ngx.print('</span></div>\
                    </div>\
                    <div class="no-mobile vdf-row rngshd-div-inddays">\
                      <div class="left">\
                      </div>\
                      <div class="right no-text-align">\
                        <input id="Tue" data-index="2" class="checkbox checkbox-unchecked ch4" type="checkbox">\
                        <label for="Tue"></label>\
                        <span>');  ngx.print(T"Tuesday"); ngx.print('</span></div>\
                      <div class="right no-text-align">\
                        <input id="Sun" data-index="7" class="checkbox checkbox-unchecked ch3" type="checkbox">\
                        <label for="Sun"></label>\
                        <span>');  ngx.print(T"Sunday"); ngx.print('</span></div>\
                    </div>\
                    <div class="no-mobile vdf-row rngshd-div-inddays">\
                      <div class="left">\
                      </div>\
                      <div class="right no-text-align">\
                        <input id="Wed" data-index="3" class="checkbox checkbox-unchecked ch5" type="checkbox">\
                        <label for="Wed"></label>\
                        <span>');  ngx.print(T"Wednesday"); ngx.print('</span></div>\
                      <div class="right no-text-align">\
                      </div>\
                    </div>\
                    <div class="no-mobile vdf-row rngshd-div-inddays">\
                      <div class="left">\
                      </div>\
                      <div class="right no-text-align">\
                        <input id="Thu" data-index="4" class="checkbox checkbox-unchecked ch6" type="checkbox">\
                        <label for="Thu"></label>\
                        <span>');  ngx.print(T"Thursday"); ngx.print('</span></div>\
                      <div class="right no-text-align">\
                      </div>\
                    </div>\
                    <div class="no-mobile vdf-row rngshd-div-inddays">\
                      <div class="left">\
                      </div>\
                      <div class="right no-text-align">\
                        <input id="Fri" data-index="5" class="checkbox checkbox-unchecked ch7" type="checkbox">\
                        <label for="Fri"></label>\
                        <span>');  ngx.print(T"Friday"); ngx.print('</span>       </div>\
                      <div class="right no-text-align">\
                      </div>\
                    </div>\
                 </div>\
\
                <div class="vdf-row">\
                    <div class="left" style="width: 54%;">\
                        <span>');  ngx.print(T"Time"); ngx.print('</span>       </div>\
                    <div class="mobile-popup right">\
                       <div class="mobile-wrap-from-to mobile clearfix">\
                            <div class="mobile-wrap-from">\
                                <span>');  ngx.print(T"from"); ngx.print('</span><input style="width: 70px;" id = "rngshd-txt-mobstart" value="" maxlength="5" type="text">\
                            </div>\
                            <div class="mobile-wrap-to">\
                                <span>');  ngx.print(T"to"); ngx.print('</span><input style="width: 70px;" id = "rngshd-txt-mobstop" value="" maxlength="5" type="text">\
                            </div>\
                        </div>\
                        <span class="no-mobile-ring" style="padding-right: 4px;"><span>');  ngx.print(T"from"); ngx.print('</span></span>\
                        <input class="no-mobile-ring"  id = "rngshd-txt-start" style="width: 70px;" value="" maxlength="5" type="text">\
                        <span class="no-mobile-ring" style="padding-right: 12px; padding-left: 10px;"><span>');  ngx.print(T"to"); ngx.print('</span></span>\
                        <input class="no-mobile-ring"   id = "rngshd-txt-stop" style="width: 70px;" value="" maxlength="5" type="text">\
                    </div>\
                </div>\
                <div class="apply-cancel">\
                    <input value="');  ngx.print(T"Save"); ngx.print('" class="button button-apply mob-button-width" id="rngshd-btn-addsave" type="button">\
                    <input value="');  ngx.print(T"Cancel"); ngx.print('" class="button button-cancel mob-button-width mob-apply-cancel" id="rngshd-btn-addcancel" type="button" data-dismiss="modal">\
                </div>\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
\
\
\
<!-- Edit Ringing Schedule Popup Modal-->\
<div class="ringingSchedule modal fade" id="ringing-schedule-popup-edit" role="dialog" data-backdrop="static">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
    <div class="modal-header hidden-sm hidden-md hidden-lg">\
        <div class="mobile-cancel-popup button-cancel"></div>\
    </div>\
      <div class="modal-body no-padding">\
        <form class="form-horizontal">\
                <p class="title">');  ngx.print(T"Edit Ringing Schedule"); ngx.print('</p>\
                <div class="vdf-row assign-row14">\
                    <div class="left" style="padding-right: 70px;width: 54%;">\
                        <span>');  ngx.print(T"Assign to these numbers"); ngx.print('</span>:\
                    </div>\
                    <div class="right">\
                        <div id="top-info-mode" class="rel">\
                            <select id="rngshd-select-editprofile">\
                                <option value= "All">');  ngx.print(T"All"); ngx.print('</option>\
                                ');  for index, profile in ipairs(sipProfileNumber) do
                                   ngx.print(format("<option value='%s'>%s</option>", profile["uri"], profile["uri"]))
                                end   ngx.print('\
                            </select>\
                        </div>\
                    </div>\
                </div>\
                <div class="vdf-row">\
                    <div class="left" style="width: 54%;">\
                        <span>');  ngx.print(T"Time Frame"); ngx.print('</span>     </div>\
                        <div class="right">\
                            <div id="top-info-mode" class="rel">\
                                <select id="rngshd-select-editday">\
                                    <option value="Individual Days">');  ngx.print(T"Individual Days"); ngx.print('</option>\
                                    <option value="Every Day">');  ngx.print(T"Every Day"); ngx.print('</option>\
                                    <option selected="selected" value="Every Workday">');  ngx.print(T"Every Workday"); ngx.print('</option>\
                                    <option value="All Weekend">');  ngx.print(T"All Weekend"); ngx.print('</option>\
                                </select>\
                            </div>\
                        </div>\
                </div>\
\
                <style type="text/css">\
                    .individual-left, .individual-right {\
                        float: left;\
                        width: 150px;\
                    }\
                    #individualDays2 .right {\
                        display: block;\
                        width: 300px;\
                    }\
\
                    #individualDays2 .left {\
                        vertical-align: top;\
                    }\
                </style>\
\
\
                <div id="individualDays2" >\
                    <div class="mobile vdf-row" id="rngshd-div-mobeditinddays">\
                        <div class="right no-text-align">\
                            <input id="editMobMon" data-index="1" class="checkbox checkbox-unchecked ch2" type="checkbox">\
                            <label for="editMobMon"></label>\
                            <span>');  ngx.print(T"Monday"); ngx.print('</span>            </div>\
                        <div class="right no-text-align">\
                            <input id="editMobTue" data-index="2" class="checkbox checkbox-unchecked ch4" type="checkbox">\
                            <label for="editMobTue"></label>\
                            <span>');  ngx.print(T"Tuesday"); ngx.print('</span>            </div>\
                        <div class="right no-text-align">\
                            <input id="editMobWed"  data-index="3" class="checkbox checkbox-unchecked ch5" type="checkbox">\
                            <label for="editMobWed"></label>\
                            <span>');  ngx.print(T"Wednesday"); ngx.print('</span>            </div>\
                        <div class="right no-text-align">\
                            <input id="editMobThu" data-index="4" class="checkbox checkbox-unchecked ch6" type="checkbox">\
                            <label for="editMobThu"></label>\
                            <span>');  ngx.print(T"Thursday"); ngx.print('</span>            </div>\
                        <div class="right no-text-align">\
                            <input id="editMobFri" data-index="5" class="checkbox checkbox-unchecked ch7" type="checkbox">\
                            <label for="editMobFri"></label>\
                            <span>');  ngx.print(T"Friday"); ngx.print('</span>            </div>\
                        <div class="right no-text-align">\
                            <input id="editMobSat" data-index="6" class="checkbox checkbox-unchecked ch1" type="checkbox">\
                            <label for="editMobSat"></label>\
                            <span>');  ngx.print(T"Saturday"); ngx.print('</span>            </div>\
                        <div class="right no-text-align">\
                            <input id="editMobSun" data-index="7" class="checkbox checkbox-unchecked ch3" type="checkbox">\
                            <label for="editMobSun"></label>\
                            <span>');  ngx.print(T"Sunday"); ngx.print('</span>            </div>\
                    </div>\
                    <div class="no-mobile vdf-row rngshd-div-editinddays">\
                      <div class="left space-right">\
                            <span>');  ngx.print(T"Select Individual Days"); ngx.print('</span>       </div>\
                      <div class="right no-text-align" style="width: 25%;">\
                        <input id="editMon" data-index="1" class="checkbox checkbox-unchecked ch2" type="checkbox">\
                        <label for="editMon"></label>\
                        <span>');  ngx.print(T"Monday"); ngx.print('</span>       </div>\
                      <div class="right no-text-align" style="width: 25%;">\
                        <input id="editSat" data-index="6" class="checkbox checkbox-unchecked ch1" type="checkbox">\
                        <label for="editSat"></label>\
                       <span>');  ngx.print(T"Saturday"); ngx.print('</span>          </div>\
                    </div>\
                    <div class="no-mobile vdf-row rngshd-div-editinddays">\
                      <div class="left">\
                      </div>\
                      <div class="right no-text-align">\
                        <input id="editTue" data-index="2" class="checkbox checkbox-unchecked ch4" type="checkbox">\
                        <label for="editTue"></label>\
                        <span>');  ngx.print(T"Tuesday"); ngx.print('</span>          </div>\
                      <div class="right no-text-align">\
                        <input id="editSun" data-index="7" class="checkbox checkbox-unchecked ch3" type="checkbox">\
                        <label for="editSun"></label>\
                        <span>');  ngx.print(T"Sunday"); ngx.print('</span>       </div>\
                    </div>\
                    <div class="no-mobile vdf-row rngshd-div-editinddays">\
                      <div class="left">\
                      </div>\
                      <div class="right no-text-align">\
                        <input id="editWed" data-index="3" class="checkbox checkbox-unchecked ch5" type="checkbox">\
                        <label for="editWed"></label>\
                        <span>');  ngx.print(T"Wednesday"); ngx.print('</span>        </div>\
                      <div class="right no-text-align">\
                      </div>\
                    </div>\
                    <div class="no-mobile vdf-row rngshd-div-editinddays">\
                      <div class="left">\
                      </div>\
                      <div class="right no-text-align">\
                        <input id="editThu" data-index="4" class="checkbox checkbox-unchecked ch6" type="checkbox">\
                        <label for="editThu"></label>\
                        <span>');  ngx.print(T"Thursday"); ngx.print('</span>         </div>\
                      <div class="right no-text-align">\
                      </div>\
                    </div>\
                    <div class="no-mobile vdf-row rngshd-div-editinddays">\
                      <div class="left">\
                      </div>\
                      <div class="right no-text-align">\
                        <input id="editFri" data-index="5" class="checkbox checkbox-unchecked ch7" type="checkbox">\
                        <label for="editFri"></label>\
                        <span>');  ngx.print(T"Friday"); ngx.print('</span>       </div>\
                      <div class="right no-text-align">\
                      </div>\
                    </div>\
                 </div>\
\
                <div class="vdf-row">\
                    <div class="left" style="width: 54%;">\
                        <span>');  ngx.print(T"Time"); ngx.print('</span>       </div>\
                    <div class="mobile-popup right">\
                       <div class="mobile-wrap-from-to mobile clearfix">\
                            <div class="mobile-wrap-from">\
                                <span>');  ngx.print(T"from"); ngx.print('</span><input style="width: 70px;" id="rngshd-txt-mobeditstart" value="" maxlength="5" type="text">\
                            </div>\
                            <div class="mobile-wrap-to">\
                                <span>');  ngx.print(T"to"); ngx.print('</span><input style="width: 70px;" id="rngshd-txt-mobeditstop" value="" maxlength="5" type="text">\
                            </div>\
                        </div>\
                        <span class="no-mobile-ring" style="padding-right: 4px;"><span>');  ngx.print(T"from"); ngx.print('</span></span>\
                        <input class="no-mobile-ring" style="width: 70px;" value="" maxlength="5" type="text" id="rngshd-txt-editstart" >\
                        <span  class="no-mobile-ring" style="padding-right: 10px; padding-left: 10px;"><span>');  ngx.print(T"to"); ngx.print('</span></span>\
                        <input class="no-mobile-ring" style="width: 70px;" value="" maxlength="5" type="text" id="rngshd-txt-editstop">\
                    </div>\
                </div>\
                <div class="apply-cancel">\
                    <input value=');  ngx.print(T"Save"); ngx.print(' class="button button-apply" id="rngshd-btn-editsave" type="button">\
                    <input value=');  ngx.print(T"Cancel"); ngx.print(' class="button button-cancel" id="rngshd-btn-editcancel" type="button" data-dismiss="modal">\
                </div>\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
\
<script>\
var T = {\
  "Mon" : "');  ngx.print(T"Mon"); ngx.print('",\
  "Tue" : "');  ngx.print(T"Tue"); ngx.print('",\
  "Wed" : "');  ngx.print(T"Wed"); ngx.print('",\
  "Thu" : "');  ngx.print(T"Thu"); ngx.print('",\
  "Fri" : "');  ngx.print(T"Fri"); ngx.print('",\
  "Sat" : "');  ngx.print(T"Sat"); ngx.print('",\
  "Sun" : "');  ngx.print(T"Sun"); ngx.print('",\
  "Every Workday" : "');  ngx.print(T"Every Workday"); ngx.print('",\
  "enabled" : "');  ngx.print(T"enabled"); ngx.print('",\
  "disabled": "');  ngx.print(T"disabled"); ngx.print('",\
  "from" : "');  ngx.print(T"from"); ngx.print('",\
  "to" : "');  ngx.print(T"to"); ngx.print('",\
  "All" : "');  ngx.print(T"All"); ngx.print('",\
}\
var dayTypesTable = ');  ngx.print(json.encode(dayTypesTable)); ngx.print(';\
var status = "');  ngx.print(rngshdContent["profileStatus"]); ngx.print('";\
var serviceClass\
if (status == "off"){\
  serviceClass = T["disabled"]\
}else {\
  serviceClass = T["enabled"]\
}\
$(function(){\
if ($("#rngshd-btn-todstatus").hasClass("button-on")){\
          $("#rngshd-btn-todstatus").closest("div.h3-content").next("div.hide-all").slideDown();\
    }else if ($("#rngshd-btn-todstatus").hasClass("button-off")){\
\
        $("#rngshd-btn-todstatus").closest("div.h3-content").next("div.hide-all").hide();\
    }\
	});\
var resetringschedule_ringinsschedule_enable = "');  ngx.print(resetringingschedule["reset_ringinsschedule_enable"]); ngx.print('";\
var resetringschedule_duringthistime = "');  ngx.print(resetringingschedule["reset_duringthistime"]); ngx.print('";\
\
</script>\
<script src="js/global.js"></script>\
<script src="js/ringing-schedule.js"></script>\
'); 