local M = {}
-- Localization
gettext.textdomain('webui-core')

--local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local accesscontroltod_path = "uci.tod.host."
local untaint_mt = require("web.taint").untaint_mt
local format, find, match, gmatch, untaint, gsub  = string.format, string.find, string.match, string.gmatch, string.untaint, string.gsub
local concat, insert = table.concat, table.insert
local uinetwork = require("web.uinetwork_helper")
local string = string
local tonumber = tonumber
local r_hosts_ac
local ngx = ngx
local vQTN = post_helper.validateQTN
local gAV = post_helper.getAndValidation
local vLXC = post_helper.validateLXC
local overlapCheck = post_helper.overlapCheck
local validateTime = post_helper.validateTODTime
local mac_value
local variant_helper = require("variant_helper")
local variantHelperWireless = post_helper.getVariant(variant_helper, "Wireless", "wireless")
local isNewLayout = proxy.get("uci.env.var.em_new_ui_layout")
isNewLayout = isNewLayout and isNewLayout[1].value or "0"

local function setlanguage()
    gettext.language(ngx.header['Content-Language'])
end

local function hosts_ac_ip2mac(t)
  if not t then return nil end
  for k,v in pairs(t) do
      local mac = match(k, "%[%s*([%x:]+)%s*%]")
      if mac then
         t[k] = mac
      end
  end
  local new_mac = {}
    for k,v in pairs(t) do
      new_mac[#new_mac+1] = {v,k}
    end
  new_mac[#new_mac + 1] = {"custom", T"Custom"}
  return new_mac
end

local function revert_kv(t)
  local nt = {}
  if type(t) ~= "table" then return nt end
  for k,v in pairs(t) do
      nt[v] = k
  end
  return nt
end

function M.get_hosts_ac()
  -- convert auto-complete table from IP to MAC
  return hosts_ac_ip2mac(uinetwork.getAutocompleteHostsListIPv4())
end

local nextDays = { Mon = 'Tue', Tue = 'Wed', Wed = 'Thu', Thu = 'Fri', Fri = 'Sat', Sat = 'Sun', Sun = 'Mon' }

-- function that is used get the selected weekdays from check boxes and form it as a table of values
-- if content weekdays are empty then returns all weekday from Monday to Sunday like Mon,Tue,Wed,Thu,Fri,Sat,Sun
-- @param #content have the values posted from wifi tod table rule which includes the table of selected/empty weekdays
-- @return #table of formatted weekday(s) with proper indexing
function M.formatWeekdays(content)
  local tod = M.getTodwifi()
  if content and type(content.weekdays) ~= "table" then
    if content.weekdays == "" then
      content.weekdays = {}
      for _, v in ipairs(tod.days) do
        insert(content.weekdays, v[1])
      end
      content.start_time = "00:00"
      content.stop_time = "23:59"
    else
      content.weekdays = {untaint(content.weekdays)}
    end
  else
    for i, v in ipairs(content.weekdays) do
      content.weekdays[i] = untaint(v)
    end
  end
  return content.weekdays
end

-- function used get the selected weekdays from check boxes and provide the next days of the selected day(s)
-- if start time is greater than or equal to the stop time else provides the same weekday(s) selected from GUI
-- @param #startTime have the time value of the ToD rule posted from wifi tod table
-- @param #stopTime have the time value of the ToD rule posted from wifi tod table
-- @param day have the selected weekday(s) value
-- @return #list of stop days of the given weekday(s).
-- Example: Starttime 20:00 Stoptime:06:00 and day is Tue,Wed then output will be Wed,Thu
function M.calculateStopDay(startTime, stopTime, day)
  if startTime >= stopTime then
    local _, _, Mo, Tu, We, Th, Fr, Sa, Su, _ = find(day, "(%a*),?(%a*),?(%a*),?(%a*),?(%a*),?(%a*),?(%a*)")
    day = ""
    for _, w in ipairs({ Mo, Tu, We, Th, Fr, Sa, Su }) do
      if w ~= "" then
        day = day .. nextDays[w] .. ","
      end
    end
    day = day:gsub(',+', ','):gsub(',*$', '') -- remove the comma at the end in day after found the next day
  end

  if day == "" then
    day = "All"
  end
  return day
end

local dayMap = {
  ["Mon"] = "0",
  ["Tue"] = "1",
  ["Wed"] = "2",
  ["Thu"] = "3",
  ["Fri"] = "4",
  ["Sat"] = "5",
  ["Sun"] = "6"
}

-- function used to convert the day's time into corresponding minutes
-- @param #day have the value of weekday
-- @param #time have the value of start/stop time from wifi tod table rule
-- @return #minutes value of the given day and time
function M.convToMins(day, time)
  local dayIdx = dayMap[untaint(day)]
  local hrs, mins = match(time, "(%d+)%:(%d+)")
  return (1440 * tonumber(dayIdx) + (tonumber(hrs) * 60) + tonumber(mins))
end

-- function that can be used to compare and find whether the rule is duplicate or overlap
-- The Start and Stop time values of the days are converted into minutes for easy comparison of days time overlap
-- @param #index have the index value of adding or editing tod rule
-- @param #postData have the values posted from wifi tod table rule
-- @return #boolean or nil+error message if the rule is duplicate or overlap
function M.daysTimeOverlap(index, postData)
  local daySelect = concat(postData.weekdays, ",")
  local tod_timer_path = "uci.tod.timer."
  local todTimers = content_helper.convertResultToObject(tod_timer_path, proxy.get(tod_timer_path))
  for _, v in ipairs (todTimers) do
    if not match(v.paramindex, index) then
      -- parsing the start, stop day, time values that is added already in tod rule Start time as Mon,Tue:17:15 and
      -- stop time as Tue,Wed:02:45
      -- oldDay contains the rule start day(s) like Mon,Tue
      -- oldStartT contains the start time of added rule like 05:15
      -- oldStopT contains the stop time of added rule like 02:45

      if v.start_time ~= "" and v.stop_time ~= "" then
        local oldDay, oldStartT = match(v.start_time, "([^:]+)%:(%S+)$")
        local _, oldStopT = match(v.stop_time, "([^:]+)%:(%S+)$")
        for preDay in gmatch(oldDay, '([^,]+)') do
          local preStartTime =  M.convToMins(preDay, oldStartT)
          local preStopTime
          if oldStartT >= oldStopT then
            preStopTime = M.convToMins(nextDays[untaint(preDay)], oldStopT)
          else
            preStopTime = M.convToMins(preDay, oldStopT)
          end
          for curDay in gmatch(daySelect, '([^,]+)') do
            local curStartTime = M.convToMins(curDay, postData.start_time)
            local curStopTime
            if postData.start_time >= postData.stop_time then
              curStopTime = M.convToMins(nextDays[curDay], postData.stop_time)
            else
              curStopTime = M.convToMins(curDay, postData.stop_time)
            end
            if curStartTime == preStartTime and curStopTime == preStopTime then
              return nil, T"Duplicate contents are not allowed"
            end
            if (curStartTime >= preStartTime and curStartTime < preStopTime) or
              (curStartTime <= preStartTime and curStopTime > preStartTime) then
              return nil,T"Overlapping times are not allowed."
            end
          end
        end
      end
    end
  end
  return true
end

-- function that can be used to check whether the adding or editing wifi tod rule is an active rule
-- @param #index have the index value of adding or editing tod rule
-- @param #content have the values posted from wifi tod table rule
-- @return #boolean true if rule is an active rule or nil
function M.isRuleActive(content)
  local currDay, currTime = M.getCurrentDayAndTime()
  currTime = M.convToMins(currDay, currTime)
  local startTime, stopTime, nxtDay
  local weekDays = M.formatWeekdays(content)

  weekDays = concat(weekDays, ",")
  nxtDay = M.calculateStopDay(content.start_time, content.stop_time, weekDays)
  for startDay in gmatch(weekDays, '([^,]+)') do
    startTime = M.convToMins(startDay, content.start_time)
    if content.stop_time < content.start_time then
      stopTime = M.convToMins(nextDays[untaint(startDay)], content.stop_time)
    else
      stopTime = M.convToMins(startDay, content.stop_time)
    end
    -- the action should be stopped first to restore the object setting before applying a new object value while in a active timeslot
    if content.enabled == "1" and (match(weekDays, currDay) or match(nxtDay, currDay)) and currTime >= startTime and currTime <= stopTime then
      return true
    end
  end
  return nil
end

local gVIC = post_helper.getValidateInCheckboxgroup
local gVIES = post_helper.getValidateInEnumSelect
local vSIM = post_helper.validateStringIsMAC
local vB = post_helper.validateBoolean

local function theWeekdays()
    return {
      { "Mon", T"Mon." },
      { "Tue", T"Tue." },
      { "Wed", T"Wed." },
      { "Thu", T"Thu." },
      { "Fri", T"Fri." },
      { "Sat", T"Sat." },
      { "Sun", T"Sun." },
    }
end

local function getWeekDays(value, object, key)
    local getValidateWeekDays = gVIC(theWeekdays())
    local ok, msg = getValidateWeekDays(value, object, key)

    if not ok then
        return ok, msg
    end
    for i = #object[key], 1, -1 do
        if object[key][i] == "" then
            table.remove(object[key], i)
        end
    end
    return true
end

local function tod_sort_func(a, b)
  return a["id"] < b["id"]
end

function M.mac_to_hostname(mac)
  local hostname = ""

  if mac then
    local hosts = uinetwork.getHostsList()
    for i,v in ipairs(hosts) do
      if mac == v.MACAddress then
        hostname = v.FriendlyName
        break
      end
    end
    if hostname == "" then
      hostname = "Unknown-" .. mac
    end
  end

  return hostname
end

-- since tod_default.type is "mac", the "id" will be MAC, we try to convert it
-- to friendly name, otherwise, add "Unknown-" prefix.
local function tod_mac_to_hostname(tod_data)
  if type(tod_data) ~= "table" then
     return
  end
  for _,v in ipairs(tod_data) do
      -- index is '2' due to in tod_columns, the one header = "Hostname" is 2.
      v[2] = M.mac_to_hostname(untaint(v[2]))
  end
end

-- Determine the wireless ap for a given wifi-interface(or L2Interface) by searching
-- through the uci.wireless.wifi-ap.<ap_inst>.iface entries
function M.findMatchingAP(wliface)
    local apFound = ""
    local getRetTbl = proxy.get("uci.wireless.wifi-apNumberOfEntries") or ""
    local numAPs = getRetTbl[1].value
    for apinst = 0 , tonumber(numAPs)-1 do
        local test_val = proxy.get(format("uci.wireless.wifi-ap.@ap%s.iface", apinst))
        if test_val and test_val ~= "" and test_val[1].value == wliface then
            apFound = "ap" .. tostring(apinst)
            break
        end
    end
    return apFound
end

function M.getTod()
  setlanguage()
  mac_value = M.get_hosts_ac()

  local todmodes = {
    { "allow", T"Allow" },
    { "block", T"Block" },
  }

  -- ToD forwarding rules
  local tod_columns = {
    {
        header = T"Status",
        name = "enabled",
        param = "enabled",
        type = "light",
        readonly = true,
        attr = { input = { class="span1" } },
    }, --[1]
    {
        header = T"Hostname",
        name = "id",
        param = "id",
        type = "text",
        readonly = true,
        attr = { input = { class="span3" } },
    }, --[2]
    {
        header = T"Start Time",
        name = "start_time",
        param = "start_time",
        type = "text",
        readonly = true,
        attr = { input = { class="span2" } },
    }, --[3]
    {
        header = T"Stop Time",
        name = "stop_time",
        param = "stop_time",
        type = "text",
        readonly = true,
        attr = { input = { class="span2" } },
    }, --[4]
    {
        header = T"Mode",
        name = "mode",
        param = "mode",
        type = "text",
        readonly = true,
        attr = { input = { class="span2" } },
    }, --[5]
    {
        header = T"Day of week",
        name = "weekdays",
        param = "weekdays",
        values = theWeekdays(),
        type = "checkboxgroup",
        readonly = true,
        attr = { input = { class="span1" } },
    }, --[6]
    {   -- NOTE: don't foget update M.getTod() when change position
        header = "", --T"ToD",
        legend = T"Time of day access control",
        name = "timeofday",
        --param = "enabled",
        type = "aggregate",
        synthesis = nil, --tod_aggregate,
        subcolumns = {
            {
                header = T"Enabled",
                name = "enabled",
                param = "enabled",
                type = "switch",
                default = "1",
                attr = {switch = { class="inline" } },
            },
            {   -- NOTE: don't foget update M.getTod() when change position
                header = T"MAC address",
                name = "id",
                param = "id",
                type = "select",
                values = mac_value,
                attr = { select = { class="span2"}},
            },
            {
                header = T"Mode",
                name = "mode",
                param = "mode",
                type = "select",
                values = todmodes,
                default = "allow",
                attr = { select = { class="span2" } },
            },
            {
                header = T"Start Time",
                name = "start_time",
                param = "start_time",
                type = "text",
                default = "00:00",
                attr = { input = { class="span2", id="starttime", style="cursor:pointer; background-color:white" } },
            },
            {
                header = T"Stop Time",
                name = "stop_time",
                param = "stop_time",
                type = "text",
                default = "23:59",
                attr = { input = { class="span2", id="stoptime", style="cursor:pointer; background-color:white" } },
            },
            {
                header = T"Day of week",
                name = "weekdays",
                param = "weekdays",
                type = "checkboxgroup",
                values = theWeekdays(),
                attr = { checkbox = { class="inline" } },
            },
        }
    }, --[7]
  }

  local tod_valid = {
    ["mode"]        = gVIES(todmodes),
    ["start_time"]  = validateTime,
    ["stop_time"]   = validateTime,
    ["weekdays"]    = getWeekDays,
    ["enabled"]     = vB,
    ["id"]          = gAV(vSIM,vQTN,vLXC)
  }

  local tod_default = {
    ["type"] = "mac",
  }

  local host_ac = M.get_hosts_ac()
  -- hot-update hostname autocomplete list when refresh page each time
  tod_columns[7].subcolumns[2].attr.autocomplete = host_ac
--[[
example:
  r_hosts_ac = {
                 ["00:13:46:e7:4a:a4"] = "BJNGDRND00757 (10.0.0.78) [00:13:46:e7:4a:a4]",
                 ["d4:be:d9:92:99:51"] = "10.0.0.202 [d4:be:d9:92:99:51]",
               }
--]]
  r_hosts_ac = revert_kv(host_ac)

  return {
    columns = tod_columns,
    valid   = tod_valid,
    default = tod_default,
    sort_func = tod_sort_func,
    mac_to_hostname = tod_mac_to_hostname,
    host_values = host_ac,
  }
end

local availableInterfaces, availableCredentials = {}, {}
local function loadInterfaceCredList(gettype)
  local interfacesPath = "uci.web.network.@"..gettype..".intf."
  if proxy.getPN("uci.web.network.@"..gettype..".intf.", true) then
    availableInterfaces = content_helper.convertResultToObject(interfacesPath .. "@.", proxy.get(interfacesPath))
  end
  local credentials = "uci.web.network.@"..gettype..".cred."
  if proxy.getPN("uci.web.network.@"..gettype..".cred.", true) then
    availableCredentials = content_helper.convertResultToObject(credentials .. "@.", proxy.get(credentials))
  end
  return availableInterfaces, availableCredentials
end

local function generateInterfaceList(gettype)
  availableInterfaces, availableCredentials = loadInterfaceCredList(gettype)
  interface_list, credential_list = {}, {}
  local apList = "rpc.wireless.ap."
  apList = content_helper.convertResultToObject(apList .. "@.", proxy.get(apList))
  for _, intf in ipairs(availableInterfaces) do
    for _, apVal in ipairs(apList) do
      if intf.value == apVal.ssid then
        interface_list[#interface_list + 1] = intf.value
      end
    end
  end
  for _, cred in ipairs(availableCredentials) do
    credential_list[#credential_list + 1] = cred.value
  end
  return interface_list, credential_list
end

local interface_list, credential_list = {}, {}
local function loadAvailableInterface()
  local objPath = "uci.web.network."
  local objFound = proxy.getPN(objPath, true)
  local networktype = {}
  if objFound then
    for _, v in ipairs(objFound) do
      if v.path and v.path ~= "" then
        networktype[#networktype + 1] = v.path:match("%@(.*)%.")
      end
    end
  end
  for _, v in pairs(networktype) do
    if untaint(v) == "main" then
      interface_list, credential_list = generateInterfaceList("main")
    end
  end
end

--To check whether multiAP is enabled or not
local multiap_enabled = false
if post_helper.getVariantValue(variantHelperWireless, "multiAP") then
  local multiap_state = {
    agent = "uci.multiap.agent.enabled",
    controller = "uci.multiap.controller.enabled"
  }
  content_helper.getExactContent(multiap_state)
  multiap_enabled = multiap_state.agent == "1" and multiap_state.controller == "1"
end

local function checkSplitMode(credential_list)
  if (proxy.getPN("uci.multiap.controller_credentials.", true)) then
    local split_ssid = proxy.get("uci.multiap.controller_credentials.@"..credential_list[2]..".state")[1].value
    return split_ssid
  end
end

function M.getTodwifi()
  setlanguage()
  local splitssid
  local splitModeEMDisabled = proxy.get("uci.web.network.@main.splitssid")
  splitModeEMDisabled = splitModeEMDisabled and splitModeEMDisabled[1].value or "1"
  if isNewLayout == "1" then
    loadAvailableInterface()
    splitssid = multiap_enabled and checkSplitMode(credential_list) or splitModeEMDisabled
  end

  local wifimodes = {
    { "on", T"On" },
    { "off", T"Off" },
  }

  local radioNum = setmetatable({
     ["2G"] = T"2.4G",
     ["5G"] = T"5G",
     ["2"] = T"2",
  }, untaint_mt)

  local ssidListDrop = {{"all", T"All"},}
  local wifiIntf = proxy.get("uci.wireless.wifi-iface.") or ""
  wifiIntf = content_helper.convertResultToObject("uci.wireless.wifi-iface.",wifiIntf)
  local radioList = {}
  local radioVal = {}
  local wlIntf = {}
  if isNewLayout == "1" then
    for i, v in pairs(wifiIntf) do
      if splitssid == "1" then
        for intf, intfVal in ipairs(interface_list) do
          interfaceVal = string.match(wifiIntf[i].paramindex, "^@(%S+)")
          if intfVal == interfaceVal then
            if not string.match(wifiIntf[i].paramindex, "_(%S+)") then
              wlIntf[#wlIntf + 1] = string.match(wifiIntf[i].paramindex, "^@(%S+)")
              radioList[#radioList + 1] = v.device
              radioVal[#radioVal + 1] = string.match(radioList[i], "radio[_]?(%w+)")
              radioVal[i] = radioNum[radioVal[i]]
              ssidListDrop[#ssidListDrop + 1]  = {format("%s (%s)", v.ssid, radioVal[i]), format("%s (%s)", v.ssid, radioVal[i])}
            end
          end
        end
      else
        interfaceVal = string.match(wifiIntf[i].paramindex, "^@(%S+)")
        if interface_list[1] == interfaceVal then
          radioVal = radioNum["2G"] .. " and " ..radioNum["5G"]
          ssidListDrop[#ssidListDrop + 1]  = {format("%s (%s)", v.ssid, radioVal), format("%s (%s)", v.ssid, radioVal)}
        end
      end
    end
  else
    for i,v in pairs(wifiIntf) do
      if not string.match(wifiIntf[i].paramindex, "_(%S+)") then
        wlIntf[#wlIntf + 1] = string.match(wifiIntf[i].paramindex, "^@(%S+)")
        radioList[#radioList + 1] = v.device
        radioVal[#radioVal + 1] = string.match(radioList[i], "radio[_]?(%w+)")
        radioVal[i] = radioNum[radioVal[i]]
        ssidListDrop[#ssidListDrop + 1]  = {format("%s-%s", v.ssid, radioVal[i]), format("%s-%s", v.ssid, radioVal[i])}
      end
    end
  end

  -- ToD forwarding rules
  local tod_columns = {
    {
        header = T"Status",
        name = "enabled",
        param = "enabled",
        type = "light",
        readonly = true,
        attr = { input = { class="span1" } },
    }, --[1]
    {
        header = T"SSID",
        name = "ssid",
        param = "ssid",
        type = "text",
        readonly = true,
        attr = { input = { class="span3" } },
    }, --[2]
    {
        header = T"Start Time",
        name = "start_time",
        param = "start_time",
        type = "text",
        readonly = true,
        attr = { input = { class="span2" } },
    }, --[3]
    {
        header = T"Stop Time",
        name = "stop_time",
        param = "stop_time",
        type = "text",
        readonly = true,
        attr = { input = { class="span2" } },
    }, --[4]
    {
        header = T"AP Status",
        name = "mode",
        param = "mode",
        type = "text",
        readonly = true,
        attr = { input = { class="span2" } },
    }, --[5]
    {
        header = T"Day of week",
        name = "weekdays",
        param = "weekdays",
        values = theWeekdays(),
        type = "checkboxgroup",
        readonly = true,
        attr = { input = { class="span1" } },
    }, --[6]
    {   -- NOTE: don't foget update M.getTod() when change position
        header = "", --T"ToD",
        legend = T"Time of day wireless control",
        name = "timeofday",
        --param = "enabled",
        type = "aggregate",
        synthesis = nil, --tod_aggregate,
        subcolumns = {
            {
                header = T"Enabled",
                name = "enabled",
                param = "enabled",
                type = "switch",
                default = "1",
                attr = { switch= { class="inline" } },
            },
            {
                header = T"AP Status",
                name = "mode",
                param = "mode",
                type = "select",
                values = wifimodes,
                default = "on",
                attr = { select = { class="span2" } },
            },
            {
                header = T"SSID",
                name = "ssid",
                param = "ssid",
                type = "select",
                values = ssidListDrop,
                default = "all",
                attr = { select = { class="span2", id="ssidDrop" }, label = { id="ssidLabel" } },
            },
            {
                header = T"Start Time",
                name = "start_time",
                param = "start_time",
                type = "text",
                default = "00:00",
                attr = { input = { class="span2", id="starttime", style="cursor:pointer; background-color:white" } },
            },
            {
                header = T"Stop Time",
                name = "stop_time",
                param = "stop_time",
                type = "text",
                default = "23:59",
                attr = { input = { class="span2", id="stoptime", style="cursor:pointer; background-color:white" } },
            },
            {
                header = T"Day of week",
                name = "weekdays",
                param = "weekdays",
                type = "checkboxgroup",
                values = theWeekdays(),
                attr = { checkbox = { class="inline" } },
            },
        }
    }, --[7]
  }

  local tod_valid = {
    ["mode"]        = gVIES(wifimodes),
    ["start_time"]  = validateTime,
    ["stop_time"]   = validateTime,
    ["weekdays"]    = getWeekDays,
    ["enabled"]     = vB,
    --["id"]          = vSIM,
  }

--[[  local tod_default = {
    --["type"] = "mac",
  }]]--


  return {
    columns = tod_columns,
    valid   = tod_valid,
    days    = theWeekdays(),
    radionum = radioNum,
    --default = tod_default,
    --sort_func = tod_sort_func,
  }
end

-- Function to calculate next day in case of cross day scheduling
function calcNxtDay(day)
  local dayNext = {}
  for index, day_val in pairs(day) do
    day_val = string.untaint(day_val)
    dayNext[index] = nextDays[day_val];
  end
  return dayNext;
end

-- function that can be used to compare and find whether the rule is duplicate or overlap
-- @param #oldTODRules have the rules list of existing tod
-- @param #newTODRule have the new rule which is going to be add in tod
-- @return #boolean or nil+error message if the rule is duplicate or overlap
function M.compareTodRule(oldTODRules, newTODRule)
  local newStart, newStop, newDay
  local oldStart, oldStop, oldDay
  local isOverlapPass, tod_errMsg

  for _, newrule in ipairs(newTODRule) do
    newStart = newrule.start_time
    newStop = newrule.stop_time
    newDay = newrule.weekdays

    for _, oldrule in ipairs(oldTODRules) do
      oldStart = oldrule.start_time
      oldStop = oldrule.stop_time
      oldDay = oldrule.weekdays

      if newDay[1] == "All" then
        newDay = {"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"}
      end
      if oldDay[1] == "All" then
        oldDay = {"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"}
      end

       -- Overlap Checks for 4 different scenarios.
       --   1. Already Scheduled rule and new rule, both have cross day scheduling.
       --   2. Already Scheduled rule have cross day scheduling, but not the new one.
       --   3. Already Scheduled rule doesn't have cross scheduling, but the new one have.
       --   4. Already Scheduled rule and new rule, both doesnt' have cross day scheduling.

        if ((oldStart >= oldStop) and (newStart >= newStop)) then
          isOverlapPass, tod_errMsg = (
            overlapCheck(oldDay, oldStart, "24:00", newDay, newStart, "24:00") and
            overlapCheck(oldDay, oldStart, "24:00", calcNxtDay(newDay), "00:00", newStop) and
            overlapCheck(calcNxtDay(oldDay), "00:00", oldStop, newDay, newStart, "24:00") and
            overlapCheck(calcNxtDay(oldDay), "00:00", oldStop, calcNxtDay(newDay), "00:00", newStop)
          )
        elseif((oldStart >= oldStop) and (newStart < newStop)) then
          isOverlapPass, tod_errMsg = (
            overlapCheck(oldDay, oldStart, "24:00", newDay, newStart, newStop) and
            overlapCheck(calcNxtDay(oldDay), "00:00", oldStop, newDay, newStart, newStop)
          )
        elseif((oldStart < oldStop) and (newStart >= newStop)) then
          isOverlapPass, tod_errMsg = (
            overlapCheck(oldDay, oldStart, oldStop, newDay, newStart, "24:00") and
            overlapCheck(oldDay, oldStart, oldStop, calcNxtDay(newDay), "00:00", newStop)
          )
        else
          isOverlapPass, tod_errMsg = overlapCheck(oldDay, oldStart, oldStop, newDay, newStart, newStop)
        end
      end
    if not(isOverlapPass) then
      return nil, tod_errMsg
    end
  end
  return true
end

-- function to retrieve existing wifitod rules list
-- @return wifitod rules list
function M.getWifiTodRuleLists()
  local wifiToDRules = proxy.get("rpc.wifitod.")
  local wifiTodRuleList = content_helper.convertResultToObject("rpc.wifitod.", wifiToDRules)
  local oldTodRules = {}
  for _, rule in pairs(wifiTodRuleList) do
    oldTodRules[#oldTodRules + 1] = {}
    oldTodRules[#oldTodRules].rule_name = rule.name
    oldTodRules[#oldTodRules].start_time = rule.start_time
    oldTodRules[#oldTodRules].stop_time = rule.stop_time
    oldTodRules[#oldTodRules].enable = rule.mode
    oldTodRules[#oldTodRules].index = rule.paramindex
    oldTodRules[#oldTodRules].weekdays = {}
    local weekdaysPath = format("rpc.wifitod.%s.weekdays.",rule.paramindex)
    local daysList = proxy.get(weekdaysPath)
    daysList = content_helper.convertResultToObject(weekdaysPath, daysList)
    --The DUT will block/allow all the time if none of the days are selected
    for _,day in pairs(daysList) do
     if day.value ~= "" then
       oldTodRules[#oldTodRules].weekdays[#oldTodRules[#oldTodRules].weekdays+1] = day.value
     end
    end
    if (#oldTodRules[#oldTodRules].weekdays == 0) then
     oldTodRules[#oldTodRules].weekdays[#oldTodRules[#oldTodRules].weekdays+1] = "All"
    end
  end
  return oldTodRules
end

-- function to retrieve existing access control tod rules list
-- @param #mac_id have the mac name of new tod rule request
-- @return access control tod rules list
function M.getAccessControlTodRuleLists(mac_id, curIndex)
   local rulePath = content_helper.convertResultToObject(accesscontroltod_path, proxy.get(accesscontroltod_path))
   local oldTodRules = {}
   for _,rule in pairs(rulePath) do
     local editRuleIdx = curIndex and "@" .. curIndex
     if rule["id"] == mac_id and editRuleIdx ~= rule.paramindex then
       oldTodRules[#oldTodRules + 1] = {}
       oldTodRules[#oldTodRules].rule_name = rule.name
       oldTodRules[#oldTodRules].start_time = rule.start_time
       oldTodRules[#oldTodRules].stop_time = rule.stop_time
       oldTodRules[#oldTodRules].enable = rule.mode
       oldTodRules[#oldTodRules].index = rule.paramindex
       oldTodRules[#oldTodRules].weekdays = {}
       local weekdaysPath = format("uci.tod.host.%s.weekdays.",rule.paramindex)
       local daysList = content_helper.convertResultToObject(weekdaysPath, proxy.get(weekdaysPath))
       --The DUT will block/allow all the time if none of the days are selected
       for _,day in pairs(daysList) do
         if day.value ~= "" then
           oldTodRules[#oldTodRules].weekdays[#oldTodRules[#oldTodRules].weekdays+1] = day.value
         end
       end
       if (#oldTodRules[#oldTodRules].weekdays == 0) then
         oldTodRules[#oldTodRules].weekdays[#oldTodRules[#oldTodRules].weekdays+1] = "All"
       end
     end
   end
   return oldTodRules
end

-- function that can be used to validate tod rule
-- @param #value have the value of corresponding key
-- @param #object have the POST data
-- @param #key validation key name
-- @param #todRequest have the string value of request tod rule
-- @return #boolean or nil+error message
function M.validateTodRule(value, object, key, todRequest)
  local ok, msg = getWeekDays(value, object, key)
  if not ok then
    return ok, msg
  end
  local oldTODRules
  if todRequest == "Wireless" then
    oldTODRules = M.getWifiTodRuleLists(object["id"])
  elseif todRequest == "AccessControl" then
    oldTODRules = M.getAccessControlTodRuleLists(object["id"], object["index"])
  else
    return nil, T"Function input param is missing"
  end
  -- adding first access control tod rule so, validation is not required
  if #oldTODRules == 0 then
    return true
  end
  local newTODRule = {}
  newTODRule[#newTODRule + 1] = {}
  newTODRule[#newTODRule].rule_name = object["name"]
  newTODRule[#newTODRule].start_time = object["start_time"]
  newTODRule[#newTODRule].stop_time = object["stop_time"]
  newTODRule[#newTODRule].enable = object["mode"]
  newTODRule[#newTODRule].index = object["index"]
  newTODRule[#newTODRule].weekdays = {}
  --The DUT will block/allow all the time if none of the days are selected
  for _,v in pairs(object[key]) do
    if v ~= "" then
      newTODRule[#newTODRule].weekdays[#newTODRule[#newTODRule].weekdays+1] = v
    end
  end
  if (#newTODRule[#newTODRule].weekdays == 0) then
    newTODRule[#newTODRule].weekdays[#newTODRule[#newTODRule].weekdays+1] = "All"
  end
  return M.compareTodRule(oldTODRules, newTODRule)
end

-- function that can be used to get the current day(Ex: Mon, Tue) and current time(HH:MM)
-- @return #string current day and current time
function M.getCurrentDayAndTime()
  local currDate = os.date("%a %H:%M")
  return currDate:match("(%S+)%s(%S+)")
end

return M
