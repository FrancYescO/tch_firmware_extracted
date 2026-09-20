--pretranslated: do not change this file
 
--Enable Localization
gettext.textdomain('webui-core')

local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local vdf_helper = require("vodafone_helper")
local proxy = require("datamodel")
local string = string
local ipairs = ipairs
local ngx, table = ngx, table
local gmatch, format, untaint, match = string.gmatch, string.format, string.untaint, string.match
local untaint_mt = require("web.taint").untaint_mt
local sort = table.sort
local json = require("dkjson")
local gVIES = post_helper.getValidateInEnumSelect
local setTable = {}
local daysMap = vdf_helper.getDays
local dayTable = vdf_helper.getDayTable
local dayTypesTable = vdf_helper.getDayTypes
local validDays = vdf_helper.validDays
local timerPath = "uci.tod.timer."
local actionPath = "uci.tod.action."
local key = ("%02X"):rep(16)
local setmetatable = setmetatable
local NEXT_DAYS = { Mon = 'Tue', Tue = 'Wed', Wed = 'Thu', Thu = 'Fri', Fri = 'Sat', Sat = 'Sun', Sun = 'Mon' }

daysMap = daysMap()
dayTable = dayTable()
dayTypesTable = dayTypesTable()

local validateStatus = {
  {"enabled", "enabled"},
  {"disabled","disabled"},
}
local statusTranslated = {
  ["enabled"] =  T"enabled",
  ["disabled"] = T"disabled",
}

local existingRules = content_helper.convertResultToObject(timerPath, proxy.get(timerPath))
local offStateTimersList = content_helper.convertResultToObject(actionPath.."@wifischedactionOFF.timers.",proxy.get(actionPath.."@wifischedactionOFF.timers."))
local onStateTimersList = content_helper.convertResultToObject(actionPath.."@wifischedactionON.timers.",proxy.get(actionPath.."@wifischedactionON.timers."))
local todData = {}

--function to generate random for new rule
--@function generate_key
--@return 16 digit random key.
local function generate_key()
  local fd = assert(io.open("/dev/urandom", "r"))
  if fd then
    local bytes = fd:read(16)
    return key:format(bytes:byte(1,16))
  end
  fd:close()
end

--Populating existing TOD Rules in todData table
local function todRules(timerStateList, apState)
 for _, timer in ipairs(timerStateList) do
  for _,rule in ipairs (existingRules) do
    local scheduledDays, scheduledStartTime = match(rule["start_time"],"([%w%,]+)%:([%d%:]+)")
    local _, scheduledStopTime = match(rule["stop_time"],"([%w%,]+)%:([%d%:]+)")
    local daysTranslated = {}
    local selectedDays = {}
    -- selectedDays table will have non translated strings for days.
    -- selectedDays will have values which will be saved in config, so translation should not be done.
    -- daysTranslated table will have translated strings for days. These strings will be shown in spanish in GUI if translated
    if not scheduledDays then
	return nil
    end
    for day in string.gmatch(scheduledDays,"([%w]+)") do
      if validDays[day] then
        selectedDays[#selectedDays+1] = string.untaint(day)
        daysTranslated[#daysTranslated+1] = daysMap[day].text
      end
    end
    if #selectedDays > 0 and #daysTranslated > 0 then
      selectedDays = table.concat(selectedDays, ", ")
      daysTranslated = table.concat(daysTranslated, ", ")
      if "@"..timer["value"] == rule["paramindex"] then
        todData[#todData +1 ] = {}
        todData[#todData].ruleIndex = timer["value"]
        todData[#todData].ruleName = rule["name"]
        todData[#todData].status = statusTranslated[apState]
        todData[#todData].startTime = scheduledStartTime
        todData[#todData].stopTime =  scheduledStopTime
        todData[#todData].dayType = {value = dayTable[selectedDays] and dayTable[selectedDays].value or selectedDays,
        text = dayTable[selectedDays] and dayTable[selectedDays].text or daysTranslated}
        todData[#todData].weekdays = selectedDays
        todData[#todData].paramIndex = match(timer["paramindex"], "%d+")
      end
    end
  end
 end
end

--Retriving Offstate schedule timers list
todRules(offStateTimersList, "disabled")

--Retriving Onstate schedule timers list
todRules(onStateTimersList, "enabled")

--sorting todDate based on timer name
sort(todData , function (a, b) return a.ruleName < b.ruleName end)

--function validate time will validate number should contain only digit and colon.
local function validTimeString(timeValue, postData)
  if timeValue then
    local isValidTime = post_helper.validTimeString(timeValue)
    if isValidTime ~= true then
      return nil
    end
    return true
  end
end

--validation function for Post Data.
local function validateTODRules(postData)
  local todContent = {
    rule_name   = postData["name"],
    start_time  = postData["starttime"],
    stop_time   = postData["stoptime"],
    day         = postData["days"],
    status      = postData["status"]
   }
   local todValidations = {
    rule_name   = vdf_helper.validateScheduleName,
    day         = vdf_helper.validateDays,
    start_time  = vdf_helper.validateTime,
    stop_time   = vdf_helper.validateTime,
    status      = gVIES(validateStatus),
   }
   if  not (content_helper.validateObject(todContent, todValidations)) then
    return nil
   end
  return true
end

--Overlap check for value within newly adding entry.
--@data contain post values of add and edit
--@description within postdata check for if there is any overlap between days,
-- then time overlap will be checked.
--@return #boolean
local function overlapWithinNewEntry(data)
  if  #data > 1 then
    local dayMatch = false
    for _, firstEntry in ipairs(data) do
      for _, secondEntry in ipairs(data) do
        if firstEntry.index ~= secondEntry.index then
          local firstDay = dayTypesTable[firstEntry.days]
          if not firstDay then
            -- iterate over individualDays and formed in table
            firstDay = {}
            for day in gmatch(firstEntry.days, "[^,%s]+") do
              firstDay[#firstDay +1] = true
            end
          end
          local secondDay = dayTypesTable[firstEntry.days]
          if not secondDay then
            secondDay = {}
            -- iterate over individualDays and formed in table
            for day in gmatch(secondEntry.days, "[^,%s]+") do
              secondDay[#secondDay +1] = true
            end
          end
          firstDay = setmetatable(firstDay, untaint_mt)
          secondDay = setmetatable(secondDay, untaint_mt)
          -- Check for day Match between two entries
          for _, day1 in ipairs(firstDay) do
            for _, day2 in ipairs(secondDay) do
              if day1 == day2 then
                dayMatch = true
                break
              end
            end
            if dayMatch then break end
          end
          if dayMatch then
            -- If DayMatch exist check for time overlap between two entries
            local starta = untaint(firstEntry.starttime)
            local enda = untaint(firstEntry.stoptime)
            local startb = untaint(secondEntry.starttime)
            local endb = untaint(secondEntry.stoptime)
            local overlap = vdf_helper.overlapCheck(starta, enda, startb, endb)
            if not overlap then
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
--@data contain post values of add and edit
--@description within postdata check for if there is any overlap between days,
-- then time overlap will be checked.
--@return #boolean
local function overlapWithExistingEntry(data)
  local dayMatch = false
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
        if setIndex ~= time.ruleIndex then
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
   return true
  end
end

-- function to calculate stop time(stop_time would be taken as next day's time), when the given stop_time is less than or equal to start_time.
local function calculateStopTime(starttime, stoptime, day)
  if starttime >= stoptime then
    _, _, Mo, Tu, We, Th, Fr, Sa, Su, _ = string.find(day, "(%a*),?(%a*),?(%a*),?(%a*),?(%a*),?(%a*),?(%a*)")
    day = ""
    for _, w in ipairs({ Mo, Tu, We, Th, Fr, Sa, Su }) do
      if w ~= "" then
        day = day .. NEXT_DAYS[w] .. ","
      end
    end
    day = day:gsub("^,*", ""):gsub(',+', ','):gsub(',*$', '')
  end

  if day == "" then
    day = "All"
  end
  return day
end

-- Common function for adding new timer and action value in TOD config.
local function newTODRules(data)
  local genKey = generate_key()
  if genKey then
    local ruleIndex = "timer"..genKey
    local addedIndex  = proxy.add(timerPath, ruleIndex)
    local day = vdf_helper.completeDays(data["days"])
    day = table.concat(day,",")
    setTable[format("%s@%s.start_time",timerPath, addedIndex)] = day..":"..data.starttime

    day = calculateStopTime(data.starttime, data.stoptime, day)
    setTable[format("%s@%s.stop_time",timerPath, addedIndex)] = day..":"..data.stoptime
    setTable[format("%s@%s.name",timerPath, addedIndex)] = data.name
    if data.status == "enabled" then
      local actionIndex = proxy.add(actionPath.."@wifischedactionON.timers.")
      proxy.set(format("%s@wifischedactionON.timers.@%s.value",actionPath, actionIndex), ruleIndex)
    end
    if data.status == "disabled" then
      local actionIndex = proxy.add(actionPath.."@wifischedactionOFF.timers.")
      proxy.set(format("%s@wifischedactionOFF.timers.@%s.value",actionPath, actionIndex), ruleIndex)
    end
  end
end

-- Common function to update todRules based on status of rule.
local function updateTODRules(data, currentObj, status, removetimer, addtimer)
  for _, index in ipairs(currentObj) do
    if index.value == data.index then
      local day = vdf_helper.completeDays(data["days"])
      day = table.concat(day,",")
      setTable[format("%s@%s.start_time",timerPath, data.index)] = day..":"..data.starttime

      day = calculateStopTime(data.starttime, data.stoptime, day)
      setTable[format("%s@%s.stop_time",timerPath, data.index)] = day..":"..data.stoptime
      setTable[format("%s@%s.name",timerPath, data.index)] = data.name
      if status ~= data.status then
        proxy.del(format("%s@%s.timers.%s.",actionPath, removetimer, index.paramindex))
        local actionIndex = proxy.add(actionPath.."@"..addtimer..".timers.")
        proxy.set(format("%s@%s.timers.@%s.value",actionPath, addtimer, actionIndex), data.index)
      end
      return true
    end
  end
  return nil
end

-- Function to handle all post action.
local function handleTODPostData(addList, updateList, deleteList, psmStatus)

  -- Validation for Power saving mode Schedule function button.
  if not post_helper.validateBoolean(psmStatus) then
    return nil
  end

  local validateNewData = {}
  for index in ipairs(addList) do
    validateNewData[#validateNewData + 1] = addList[index]
  end
  for index in ipairs(updateList) do
    validateNewData[#validateNewData + 1] = updateList[index]
  end

  if not overlapWithinNewEntry(validateNewData)  then
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
  for _,j in ipairs(deleteList) do
    proxy.del(format(timerPath.."@%s.", j.index))
    if j.status == "disabled" then
      for _, index in ipairs(offStateTimersList) do
        if index.value == j.index then
          proxy.del(format("uci.tod.action.@wifischedactionOFF.timers.%s.",index.paramindex))
        end
      end
    else
      for _, index in ipairs(onStateTimersList) do
        if index.value == j.index then
          proxy.del(format("uci.tod.action.@wifischedactionON.timers.%s.",index.paramindex))
        end
      end
    end
  end

  --Update schedule entry in tod config
  for _, data in ipairs(updateList) do
    if not updateTODRules(data, offStateTimersList, "disabled", "wifischedactionOFF", "wifischedactionON") then
      updateTODRules(data, onStateTimersList, "enabled", "wifischedactionON", "wifischedactionOFF" )
   end
  end

  --Add schedule entry in tod config
  for _, data in ipairs(addList) do
    newTODRules(data)
  end

  setTable[actionPath.."@wifischedactionON.enabled"] = psmStatus
  setTable[actionPath.."@wifischedactionOFF.enabled"] = psmStatus
  proxy.set(setTable)
  proxy.apply()
  return true
end

if ngx.req.get_method() == "POST" then
  ngx.header.content_type = "application/json"
  local postArgs = ngx.req.get_post_args()
  local psmStatus = postArgs.status
  local tableList = json.decode(untaint(postArgs.tableRequest), 1, nil)
  tableList = setmetatable(tableList, untaint_mt)
  local deleteList = tableList.DELETE
  local addList = tableList.ADD
  local updateList = tableList.UPDATE
  local postResult = handleTODPostData(addList, updateList, deleteList, psmStatus)
  if postResult then
    ngx.print('{"status":"success"}')
  else
    ngx.print('{"status":"error"}')
  end
  ngx.exit(ngx.HTTP_OK)
end

-- Get operation of Schedule Function button
local scheduleGet ={
   onAction = "uci.tod.action.@wifischedactionON.enabled",
   offAction = "uci.tod.action.@wifischedactionOFF.enabled",
}content_helper.getExactContent(scheduleGet)

  local lp = require("web.lp")
  lp.setpath("/www/docroot/")
  lp.include("reset-wrap.lp")
  ngx.print('\
<h1><span>');  ngx.print(T"Power Saving Mode"); ngx.print('</span></h1>\
<h2>\
  <span >');  ngx.print(T"Schedule the times when you want the WiFi of your router to be turned on or off. When it is turned back on, you return to your chosen WiFi settings."); ngx.print('</span></h2>\
<div class="h3-content ">\
  <div class="vdf-table">\
    <div class="vdf-row">\
      <div class="left">\
        <span>');  ngx.print(T"Schedule Function"); ngx.print('</span>\
      </div>\
      <div class="right">\
        <div class="button ');  if scheduleGet["onAction"] == "0" and scheduleGet["onAction"] == "0" then  ngx.print('button-off');  else  ngx.print('button-on');  end  ngx.print('" id="psm-btn-enablestatus"></div>\
      </div>\
    </div>\
  </div>\
</div>\
\
<div class="scheduleOnOff shadowProblem">\
    <h3><span >');  ngx.print(T"Schedule"); ngx.print('</span></h3>\
\
    <div class="h3-content mobile-no-padding">\
\
        <table class="table-three-columns schedule-off desktop-table" id="psm-tbl-desschedule">\
            <thead>\
                <tr>\
                  <th style="width: 123px;"><span>');  ngx.print(T"Day"); ngx.print('</span></th>\
                  <th style="width: 132px;"><span>');  ngx.print(T"Time"); ngx.print('</span></th>\
                  <th style="width: 110px;"><span>');  ngx.print(T"Status"); ngx.print('</span></th>\
                  <th style="width: 55px;"><span>');  ngx.print(T"Name"); ngx.print('</span></th>\
                  <th style="width: 40px;">&nbsp;</th>\
                  <th style="width: 50px;">&nbsp;</th>\
                </tr>\
            </thead>\
            <tbody>\
              <tr class="noEntryTD ">\
                <td colspan="4"  id="des-no-rule" class="noEntryTD" style="text-align: center;">\
                  <div style="font-style:italic"><span>');  ngx.print(T"No Wi-Fi Schedule set"); ngx.print('</span></div>\
                </td>\
              </tr>\
              ');  for i, v in ipairs(todData) do  ngx.print('\
                <tr class="cloned" style="display: table-row;">\
                  <input type="hidden" class="RowIndex" value="');  ngx.print(v.paramIndex); ngx.print('"/>\
                  <input type="hidden" class="dayType" value="');  ngx.print(v.dayType.value or ""); ngx.print('">\
                  <td class="day"><span>');  ngx.print((v.dayType.value ~= "Individual Days") and v.dayType.text or v.weekdays); ngx.print('</span></td>\
                  <td class="time"><span>');  ngx.print(T"from"); ngx.print('&nbsp;</span>');  ngx.print(v.startTime); ngx.print('<span>&nbsp;');  ngx.print(T"to"); ngx.print('&nbsp;</span>');  ngx.print(v.stopTime); ngx.print('</td>\
                  <td class="enable status" style=""><span>');  ngx.print(v.status); ngx.print('</span></td>\
                  <td class="name" >');  ngx.print(v.ruleName); ngx.print('</td>\
                  <td class="tL"><input class="button button-edit" id="psm-btn-edit" value="" type="button" data-toggle="modal" data-target="#psm-editPopup" data-value="');  ngx.print(v.ruleIndex); ngx.print('" onclick="copyEditableFields(this)" ></td>\
                  <td class="tL" style="text-align:right"><input class="button button-delete" id="psm-btn-delete" value=""  data-value="');  ngx.print(v.ruleIndex); ngx.print('" type="button"></td>\
                </tr>\
              ');  end   ngx.print('\
              <tr class="addCont" id="tod-row-last">\
                <td>&nbsp;</td>\
                <td>&nbsp;</td>\
                <td>&nbsp;</td>\
                <td>&nbsp;</td>\
                <td>&nbsp;</td>\
                <td style="float:right;">\
                  <input class="button button-add popup-add" id="psm-btn-add" type="button" value="" data-toggle="modal" data-target="#psm-div-addmodal">\
                </td>\
              </tr>\
            </tbody>\
        </table>\
        <table class="mobile-table schedule-off mobile-schedule-table" id="psm-tbl-mobschedule">\
            <tbody>\
                <tr class="noEntryTD " id="mob-no-rule">\
                    <td colspan="4" class="noEntryTD">\
                        <div style="font-style:italic"><span>');  ngx.print(T"No Wi-Fi Schedule set"); ngx.print('</span>\
                        </div>\
                    </td>\
                </tr>\
                ');  for i, v in ipairs(todData) do   ngx.print('\
                  <tr class="mob-cloned">\
                    <input type="hidden" class="RowIndex" value="');  ngx.print(v.paramIndex); ngx.print('"/>\
                    <td>\
                      <table class="mobile-table">\
                        <tbody>\
                          <tr class="template-row-1 row-1" >\
                              <td class= "time"><span>');  ngx.print(T"from"); ngx.print('&nbsp;</span>');  ngx.print(v.startTime); ngx.print('<span>&nbsp;');  ngx.print(T"to"); ngx.print('&nbsp;</span>');  ngx.print(v.stopTime); ngx.print('\
                              </td>\
                              <td class="enable right-td status" style=""><span>');  ngx.print(v.status); ngx.print('</span>\
                              </td>\
                          </tr>\
                          <tr class="template-row-2 row-2" >\
                              <td class = "day"><span>');  ngx.print((v.dayType.value ~= "Individual Days") and v.dayType.text or v.weekdays); ngx.print('</span>\
                              </td>\
                          </tr>\
                          <tr class="template-row-3 name-row row-3" >\
                              <td class= "name">');  ngx.print(v.ruleName); ngx.print('</td>\
                          </tr>\
                          <tr class="template-row-4 edit-row row-4">\
                              <td class="tL">\
                                  <input class="button button-edit"  id="psm-btn-mobedit" data-value="');  ngx.print(v.ruleIndex); ngx.print('" type="button" value="">\
                              </td>\
                              <td class="tL right-td">\
                                  <input class="button button-delete" id="psm-btn-mobdelete" data-value="');  ngx.print(v.ruleIndex); ngx.print('"type="button" value="">\
                              </td>\
                          </tr>\
                        </tbody>\
                      </table>\
                    </td>\
                  </tr>\
                ');  end   ngx.print('\
                <tr class="addCont" id="tod-row-moblast">\
                  <td colspan="100%">\
                    <input class="button button-add popup-add" id="psm-btn-mobadd" type="button" value="" data-toggle="modal" data-target="#psm-div-addmodal">\
                  </td>\
                </tr>\
            </tbody>\
        </table>\
        <div class="tR" style="height: 35px; padding-top: 6px;">\
        </div>\
    </div>\
</div>\
\
<!-- Add Power Saving Mode Popup Modal-->\
<div class="modal fade psmaddPopup" id="psm-div-addmodal" role="dialog" data-backdrop="static">\
    <div class="modal-dialog">\
        <!-- Modal content-->\
        <div class="modal-content">\
            <div class="modal-header hidden-sm hidden-md hidden-lg">\
                <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
            </div>\
            <div class="modal-body no-padding">\
                <form class="form-horizontal">\
                    <div class="form-group">\
                        <div class="col-sm-12">\
                            <p class="title tL">');  ngx.print(T"Add a new Wi-Fi Schedule"); ngx.print('</p>\
                        </div>\
                    </div>\
                    ');  
                      local daysOptions = {
                        {"Every Day", T"Every Day"},
                        {"Every Workday", T"Every Workday"},
                        {"All Weekend", T"All Weekend"},
                        {"Individual Days", T"Individual Days"}
                      }
                      local row = {
                          label = T"Time Frame",
                          colLeftClass = "left time-frame",
                          colRightClass = "right rel",
                          colRightId = "top-info-mode",
                          element = format('%s', vdf_helper.createDropDown(
                          {
                            id = "psm-sel-day"
                          }, daysOptions, "Individual Days"))
                        }
                      ngx.print(vdf_helper.createRow(row))
                      ngx.print('\
                    <div id="psm-div-desaddays">\
                        <div class="mobile indiviudalDays-mobile hide" id="psm-div-mobaddinddays" >\
                            <div class="vdf-row">\
                                <span>');  ngx.print(T"Select Individual Days"); ngx.print('</span>\
                            </div>\
                            <div class="vdf-row">\
                                <div class="checkbox-left">\
                                    <input id="MobMon" class="checkbox checkbox-unchecked ch23" data-id="23" type="checkbox">\
                                    <label for="MobMon"></label>\
                                </div>\
                                <div class="text-right">\
                                    <span>');  ngx.print(T"Monday"); ngx.print('</span>\
                                </div>\
                            </div>\
                            <div class="vdf-row">\
                                <div class="checkbox-left">\
                                    <input id="MobTue" class="checkbox checkbox-unchecked ch25" data-id="25" type="checkbox">\
                                    <label for="MobTue"></label>\
                                </div>\
                                <div class="text-right">\
                                    <span>');  ngx.print(T"Tuesday"); ngx.print('</span>\
                                </div>\
                            </div>\
                            <div class="vdf-row">\
                                <div class="checkbox-left">\
                                    <input id="MobWed" class="checkbox checkbox-unchecked ch26" data-id="26" type="checkbox">\
                                    <label for="MobWed"></label>\
                                </div>\
                                <div class="text-right">\
                                    <span>');  ngx.print(T"Wednesday"); ngx.print('</span>\
                                </div>\
                            </div>\
                            <div class="vdf-row">\
                                <div class="checkbox-left">\
                                    <input id="MobThu" class="checkbox checkbox-unchecked ch27" data-id="27" type="checkbox">\
                                    <label for="MobThu"></label>\
                                </div>\
                                <div class="text-right">\
                                    <span>');  ngx.print(T"Thursday"); ngx.print('</span>\
                                </div>\
                            </div>\
                            <div class="vdf-row">\
                                <div class="checkbox-left">\
                                    <input id="MobFri" class="checkbox checkbox-unchecked ch28" data-id="28" type="checkbox">\
                                    <label for="MobFri"></label>\
                                </div>\
                                <div class="text-right">\
                                    <span>');  ngx.print(T"Friday"); ngx.print('</span>\
                                </div>\
                            </div>\
                            <div class="vdf-row">\
                                <div class="checkbox-left">\
                                    <input id="MobSat" class="checkbox checkbox-unchecked ch21" data-id="21" type="checkbox">\
                                    <label for="MobSat"></label>\
                                </div>\
                                <div class="text-right">\
                                    <span>');  ngx.print(T"Saturday"); ngx.print('</span>\
                                </div>\
                            </div>\
                            <div class="vdf-row">\
                                <div class="checkbox-left">\
                                    <input id="MobSun" class="checkbox checkbox-unchecked ch23" data-id="23" type="checkbox">\
                                    <label for="MobSun"></label>\
                                </div>\
                                <div class="text-right">\
                                    <span>');  ngx.print(T"Sunday"); ngx.print('</span> </div>\
                            </div>\
                        </div>\
                        <div class="no-mobile vdf-row  psm-div-desaddinddays">\
                            <div class="left space-right" style="width:61%;">\
                                <span>');  ngx.print(T"Select Individual Days"); ngx.print('</span>\
                            </div>\
                            <div class="right no-text-align" style="width: 25%;">\
                                <input id="Mon" class="checkbox checkbox-unchecked ch2" type="checkbox">\
                                <label for="Mon"></label>\
                                <span>');  ngx.print(T"Monday"); ngx.print('</span>\
                            </div>\
                            <div class="right no-text-align" style="width: 25%;">\
                                <input id="Sat" class="checkbox checkbox-unchecked ch1" type="checkbox">\
                                <label for="Sat"></label>\
                                <span>');  ngx.print(T"Saturday"); ngx.print('</span>\
                            </div>\
                        </div>\
                        <div class="no-mobile vdf-row psm-div-desaddinddays">\
                            <div class="left">\
                            </div>\
                            <div class="right no-text-align">\
                                <input id="Tue" class="checkbox checkbox-unchecked ch4" type="checkbox">\
                                <label for="Tue"></label>\
                                <span>');  ngx.print(T"Tuesday"); ngx.print('</span>\
                            </div>\
                            <div class="right no-text-align">\
                                <input id="Sun" class="checkbox checkbox-unchecked ch3" type="checkbox">\
                                <label for="Sun"></label>\
                                <span>');  ngx.print(T"Sunday"); ngx.print('</span>\
                            </div>\
                        </div>\
                        <div class="no-mobile vdf-row psm-div-desaddinddays" >\
                            <div class="left">\
                            </div>\
                            <div class="right no-text-align">\
                                <input id="Wed" class="checkbox checkbox-unchecked ch5" type="checkbox">\
                                <label for="Wed"></label>\
                                <span>');  ngx.print(T"Wednesday"); ngx.print('</span>\
                            </div>\
                            <div class="right no-text-align">\
                            </div>\
                        </div>\
                        <div class="no-mobile vdf-row psm-div-desaddinddays">\
                            <div class="left">\
                            </div>\
                            <div class="right no-text-align">\
                                <input id="Thu" class="checkbox checkbox-unchecked ch6" type="checkbox">\
                                <label for="Thu"></label>\
                                <span>');  ngx.print(T"Thursday"); ngx.print('</span>\
                            </div>\
                            <div class="right no-text-align">\
                            </div>\
                        </div>\
                        <div class="no-mobile vdf-row psm-div-desaddinddays">\
                            <div class="left">\
                            </div>\
                            <div class="right no-text-align">\
                                <input id="Fri" class="checkbox checkbox-unchecked ch7" type="checkbox">\
                                <label for="Fri"></label>\
                                <span>');  ngx.print(T"Friday"); ngx.print('</span>\
                            </div>\
                            <div class="right no-text-align">\
                            </div>\
                        </div>\
                    </div>\
                    ');  
                      local statusOptions = {
                        {"enabled", T"enabled"},
                        {"disabled", T"disabled"}
                      }
                      local row = {
                        label = T"Status",
                        colLeftClass = "left status",
                        colRightClass = "right rel",
                        colRightId = "top-info-mode",
                        element = format('%s', vdf_helper.createDropDown(
                        {
                          id = "psm-sel-service"
                        }, statusOptions, "enabled"))
                      }
                      ngx.print(vdf_helper.createRow(row))

                      local row = {
                        label = T"Name",
                        element = vdf_helper.createTextField({
                          id = "psm-txt-rulename",
                          type = "text",
                          style = "width:230px;"
                        })
                      }
                      ngx.print(vdf_helper.createRow(row))
                      ngx.print('\
                    <div class="vdf-row">\
                        <div class="left" style="width: 52%;">\
                            <span>');  ngx.print(T"Time"); ngx.print('</span>\
                        </div>\
                        <div class="mobile-popup right">\
                            <div class="mobile-wrap-from-to mobile clearfix">\
                                <div class="mobile-wrap-from">\
                                    <span>');  ngx.print(T"from"); ngx.print('</span>\
                                    <input style="width: 70px;" value="" maxlength="5" type="text" id="psm-txt-mobstart">\
                                </div>\
                                <div class="mobile-wrap-to">\
                                    <span>');  ngx.print(T"to"); ngx.print('</span>\
                                    <input style="width: 70px;" value="" maxlength="5" type="text" id="psm-txt-mobstop">\
                                </div>\
                            </div>\
                            <span class="no-mobile-psm" style="padding-right: 4px;"><span>');  ngx.print(T"from"); ngx.print('</span></span>\
                            <input class="no-mobile-psm" style="width: 70px;" value="" maxlength="5" type="text" id="psm-txt-start">\
                            <span class="no-mobile-psm" style="padding-right: 10px; padding-left: 10px;"><span>');  ngx.print(T"to"); ngx.print('</span></span>\
                            <input class="no-mobile-psm" style="width: 70px;" value="" maxlength="5" type="text" id="psm-txt-stop">\
                        </div>\
                    </div>\
                    <div class="apply-cancel">\
                        <input value=');  ngx.print(T"Save"); ngx.print(' class="button button-apply mob-button-width" id = "psm-btn-save" type="button">\
                        <input value=');  ngx.print(T"Cancel"); ngx.print(' class="button button-cancel mob-button-width mob-apply-cancel" id="cancelButton" type="button" data-dismiss="modal">\
                    </div>\
            </div>\
            </form>\
        </div>\
    </div>\
</div>\
\
<!-- Edit Power Saving Mode Popup Modal-->\
<div class="modal fade psmeditPopup" id="psm-editPopup" role="dialog" data-backdrop="static">\
    <div class="modal-dialog">\
        <!-- Modal content-->\
        <div class="modal-content">\
            <div class="modal-header hidden-sm hidden-md hidden-lg">\
                <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
            </div>\
            <div class="modal-body no-padding">\
                <form class="form-horizontal">\
                    <div class="form-group">\
                        <div class="col-sm-12">\
                            <p class="title tL">');  ngx.print(T"Edit Wi-Fi Schedule"); ngx.print('</p>\
                        </div>\
                    </div>\
                    ');  
                      local daysOptions = {
                        {"Every Day", T"Every Day"},
                        {"Every Workday", T"Every Workday"},
                        {"All Weekend", T"All Weekend"},
                        {"Individual Days", T"Individual Days"}
                      }
                      local row = {
                          label = T"Time Frame",
                          colLeftClass = "left time-frame",
                          colRightClass = "right rel",
                          colRightId = "top-info-mode",
                          element = format('%s', vdf_helper.createDropDown(
                          {
                            id = "psm-sel-editdays"
                          }, daysOptions))
                        }
                      ngx.print(vdf_helper.createRow(row))
                      ngx.print('\
                    <div id="psm-sel-deseditdays">\
                        <div class="mobile indiviudalDays-mobile hide " id="psm-sel-mobeditinddays">\
                            <div class="vdf-row">\
                                <span>');  ngx.print(T"Select Individual Days"); ngx.print('</span> </div>\
                            <div class="vdf-row">\
                                <div class="checkbox-left">\
                                    <input id="editMobMon" class="checkbox checkbox-unchecked ch23" data-id="23" type="checkbox">\
                                    <label for="editMobMon"></label>\
                                </div>\
                                <div class="text-right">\
                                    <span>');  ngx.print(T"Monday"); ngx.print('</span> </div>\
                            </div>\
                            <div class="vdf-row">\
                                <div class="checkbox-left">\
                                    <input id="editMobTue" class="checkbox checkbox-unchecked ch25" data-id="25" type="checkbox">\
                                    <label for="editMobTue"></label>\
                                </div>\
                                <div class="text-right">\
                                    <span>');  ngx.print(T"Tuesday"); ngx.print('</span> </div>\
                            </div>\
                            <div class="vdf-row">\
                                <div class="checkbox-left">\
                                    <input id="editMobWed" class="checkbox checkbox-unchecked ch26" data-id="26" type="checkbox">\
                                    <label for="editMobWed"></label>\
                                </div>\
                                <div class="text-right">\
                                    <span>');  ngx.print(T"Wednesday"); ngx.print('</span> </div>\
                            </div>\
                            <div class="vdf-row">\
                                <div class="checkbox-left">\
                                    <input id="editMobThu" class="checkbox checkbox-unchecked ch27" data-id="27" type="checkbox">\
                                    <label for="editMobThu"></label>\
                                </div>\
                                <div class="text-right">\
                                    <span>');  ngx.print(T"Thursday"); ngx.print('</span> </div>\
                            </div>\
                            <div class="vdf-row">\
                                <div class="checkbox-left">\
                                    <input id="editMobFri" class="checkbox checkbox-unchecked ch28" data-id="28" type="checkbox">\
                                    <label for="editMobFri"></label>\
                                </div>\
                                <div class="text-right">\
                                    <span>');  ngx.print(T"Friday"); ngx.print('</span> </div>\
                            </div>\
                            <div class="vdf-row">\
                                <div class="checkbox-left">\
                                    <input id="editMobSat" class="checkbox checkbox-unchecked ch21" data-id="21" type="checkbox">\
                                    <label for="editMobSat"></label>\
                                </div>\
                                <div class="text-right">\
                                    <span>');  ngx.print(T"Saturday"); ngx.print('</span> </div>\
                            </div>\
                            <div class="vdf-row">\
                                <div class="checkbox-left">\
                                    <input id="editMobSun" class="checkbox checkbox-unchecked ch23" data-id="23" type="checkbox">\
                                    <label for="editMobSun"></label>\
                                </div>\
                                <div class="text-right">\
                                    <span>');  ngx.print(T"Sunday"); ngx.print('</span> </div>\
                            </div>\
                        </div>\
                        <div class="no-mobile vdf-row psm-sel-deseditinddays">\
                            <div class="left space-right" style="width:61%;">\
                                <span>');  ngx.print(T"Select Individual Days"); ngx.print('</span> </div>\
                            <div class="right no-text-align" style="width: 25%;">\
                                <input id="editDesMon" class="checkbox checkbox-unchecked ch2" type="checkbox">\
                                <label for="editDesMon"></label>\
                                <span>');  ngx.print(T"Monday"); ngx.print('</span> </div>\
                            <div class="right no-text-align" style="width: 25%;">\
                                <input id="editDesSat" class="checkbox checkbox-unchecked ch1" type="checkbox">\
                                <label for="editDesSat"></label>\
                                <span>');  ngx.print(T"Saturday"); ngx.print('</span> </div>\
                        </div>\
                        <div class="no-mobile vdf-row psm-sel-deseditinddays">\
                            <div class="left">\
                            </div>\
                            <div class="right no-text-align">\
                                <input id="editDesTue" class="checkbox checkbox-unchecked ch4" type="checkbox">\
                                <label for="editDesTue"></label>\
                                <span>');  ngx.print(T"Tuesday"); ngx.print('</span> </div>\
                            <div class="right no-text-align">\
                                <input id="editDesSun" class="checkbox checkbox-unchecked ch3" type="checkbox">\
                                <label for="editDesSun"></label>\
                                <span>');  ngx.print(T"Sunday"); ngx.print('</span> </div>\
                        </div>\
                        <div class="no-mobile vdf-row psm-sel-deseditinddays">\
                            <div class="left">\
                            </div>\
                            <div class="right no-text-align">\
                                <input id="editDesWed" class="checkbox checkbox-unchecked ch5" type="checkbox">\
                                <label for="editDesWed"></label>\
                                <span>');  ngx.print(T"Wednesday"); ngx.print('</span> </div>\
                            <div class="right no-text-align">\
                            </div>\
                        </div>\
                        <div class="no-mobile vdf-row psm-sel-deseditinddays">\
                            <div class="left">\
                            </div>\
                            <div class="right no-text-align">\
                                <input id="editDesThu" class="checkbox checkbox-unchecked ch6" type="checkbox">\
                                <label for="editDesThu"></label>\
                                <span>');  ngx.print(T"Thursday"); ngx.print('</span> </div>\
                            <div class="right no-text-align">\
                            </div>\
                        </div>\
                        <div class="no-mobile vdf-row psm-sel-deseditinddays">\
                            <div class="left">\
                            </div>\
                            <div class="right no-text-align">\
                                <input id="editDesFri" class="checkbox checkbox-unchecked ch7" type="checkbox">\
                                <label for="editDesFri"></label>\
                                <span>');  ngx.print(T"Friday"); ngx.print('</span> </div>\
                            <div class="right no-text-align">\
                            </div>\
                        </div>\
                    </div>\
\
                    ');  
                      local statusOptions = {
                        {"enabled", T"enabled"},
                        {"disabled", T"disabled"}
                      }
                      local row = {
                          label = T"Status",
                          colLeftClass = "left status",
                          colRightClass = "right rel",
                          colRightId = "top-info-mode",
                          element = format('%s', vdf_helper.createDropDown(
                          {
                            id = "psm-sel-editservice"
                          }, statusOptions))
                        }
                      ngx.print(vdf_helper.createRow(row))

                      local row = {
                          label = T"Name",
                          element = vdf_helper.createTextField({
                            id = "psm-text-editname",
                            type = "text",
                            style = "width:230px;"
                          })
                        }
                      ngx.print(vdf_helper.createRow(row))
                      ngx.print('\
                    <div class="vdf-row">\
                        <div class="left" style="width: 52%;">\
                            <span>');  ngx.print(T"Time"); ngx.print('</span> </div>\
                        <div class="mobile-popup right">\
                            <div class="mobile-wrap-from-to mobile clearfix">\
                                <div class="mobile-wrap-from">\
                                    <span>');  ngx.print(T"from"); ngx.print('</span>\
                                    <input style="width: 70px;" value="" maxlength="5" type="text" id ="psm-txt-mobeditstart" >\
                                </div>\
                                <div class="mobile-wrap-to">\
                                    <span>');  ngx.print(T"to"); ngx.print('</span>\
                                    <input style="width: 70px;" value="" maxlength="5" type="text" id ="psm-txt-mobeditstop">\
                                </div>\
                            </div>\
                            <span class="no-mobile-psm" style="padding-right: 4px;"><span>');  ngx.print(T"from"); ngx.print('</span></span>\
                            <input class="no-mobile-psm" style="width: 70px;" value="" maxlength="5" type="text" id ="psm-txt-editstart">\
                            <span class="no-mobile-psm" style="padding-right: 10px; padding-left: 10px;"><span>');  ngx.print(T"to"); ngx.print('</span></span>\
                            <input class="no-mobile-psm" style="width: 70px;" value="" maxlength="5" type="text"id ="psm-txt-editstop">\
                        </div>\
                    </div>\
                    <div class="apply-cancel">\
                        <input value=');  ngx.print(T"Save"); ngx.print(' class="button button-apply mob-button-width" id="psm-btn-editsave" type="button">\
                        <input value=');  ngx.print("Cancel"); ngx.print(' class="button button-cancel mob-button-width mob-apply-cancel" id="psm-btn-editcancel" type="button" data-dismiss="modal">\
                    </div>\
            </div>\
            </form>\
        </div>\
    </div>\
</div>\
<div class="blackBackground" style="display: none;">\
    &nbsp;\
</div>\
');  
  lp.include("apply-cancel.lp")
  lp.include("reset-wrap-mobile.lp")
  ngx.print('\
<script src="js/global.js"></script>\
<script>\
  var T = {\
    "Mon" : "');  ngx.print(T"Mon"); ngx.print('",\
    "Tue" : "');  ngx.print(T"Tue"); ngx.print('",\
    "Wed" : "');  ngx.print(T"Wed"); ngx.print('",\
    "Thu" : "');  ngx.print(T"Thu"); ngx.print('",\
    "Fri" : "');  ngx.print(T"Fri"); ngx.print('",\
    "Sat" : "');  ngx.print(T"Sat"); ngx.print('",\
    "Sun" : "');  ngx.print(T"Sun"); ngx.print('",\
    "Individual Days" : "');  ngx.print(T"Individual Days"); ngx.print('",\
    "enabled" : "');  ngx.print(T"enabled"); ngx.print('",\
    "disabled": "');  ngx.print(T"disabled"); ngx.print('",\
    "from" : "');  ngx.print(T"from"); ngx.print('",\
    "to" : "');  ngx.print(T"to"); ngx.print('"\
    }\
  var tokenCSRF = "');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('";\
</script>\
<script src="js/schedule.js"></script>\
'); 