--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")
local json = require("dkjson")
local vdf_helper = require("vodafone_helper")
local ui_helper = require("vdf_ui_helper")
local validateTime, validateDays, validateOverlappingDays = post_helper.validateTime, vdf_helper.validateDays, vdf_helper.validateOverlappingDays
local string = string
local gmatch, format, find, match, upper = string.gmatch, string.format, string.find, string.match, string.upper
local untaint = string.untaint
local table, setmetatable = table, setmetatable
local next, pairs, ipairs = next, pairs, ipairs
local sort, concat = table.sort, table.concat
local tonumber = tonumber
local untaint_mt = require("web.taint").untaint_mt
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local TOD = {}
local validateMAC = post_helper.validateQTN
local validateBoolean = post_helper.validateBoolean
local validateLength = post_helper.getValidateStringLengthInRange(1,63)
local timerPath = "uci.tod.timer."

local dayTable = {
  ["Mon, Tue, Wed, Thu, Fri, Sat, Sun"] = { value = "Every Day",     text = T"Every Day"},
  ["Mon, Tue, Wed, Thu, Fri"]           = { value = "Every Workday", text = T"Every Workday"},
  ["Sat, Sun"]                          = { value = "All Weekend",   text = T"All Weekend"},
}

local dayTypesTable = setmetatable({
  ["Every Day"]     = {"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"},
  ["Every Workday"] = {"Mon", "Tue", "Wed", "Thu", "Fri"},
  ["All Weekend"]   = {"Sat", "Sun"}
}, untaint_mt)

local daysMap = setmetatable({
  Mon = { index = 1, text = T"Mon" },
  Tue = { index = 2, text = T"Tue" },
  Wed = { index = 3, text = T"Wed" },
  Thu = { index = 4, text = T"Thu" },
  Fri = { index = 5, text = T"Fri" },
  Sat = { index = 6, text = T"Sat" },
  Sun = { index = 7, text = T"Sun" }
}, untaint_mt)

local connectedHosts = content_helper.convertResultToObject("rpc.hosts.host.", proxy.get("rpc.hosts.host."))
local savedHosts = content_helper.convertResultToObject("uci.user_friendly_name.name.", proxy.get("uci.user_friendly_name.name."))

local hostTable = setmetatable({}, untaint_mt)

local function sortDays(daysTable)
  sort( daysTable , function (a, b)
    return daysMap[a].index < daysMap[b].index
  end)
  return daysTable
end

for _,host in pairs(connectedHosts) do
  hostTable[upper(host.MACAddress)] = (host.FriendlyName ~= "") and host.FriendlyName or "unknown-" .. host.MACAddress
end

for _,host in pairs(savedHosts) do
  if host.mac ~= "" and host.name ~= "" then
    hostTable[upper(host.mac)] = host.name
  end
end

-- Function to validate all the TOD rules coming from GUI
-- @function validateTODRules
-- @param #table postData All TOD details coming from each rows in GUI
-- @param #number rows Total number of rows
-- @return #boolean true if everything is valid, nil if anything is invalid
local function validateTODRules(postData, rows)
  for i = 1, rows do
    if postData["index" .. i] and not find(postData["index" .. i], "del.+") then
      local todData = {
        enable      = postData["enable" .. i],
        rule_name   = postData["rule_name" .. i],
        mac         = postData["mac" .. i],
        start_time  = postData["start_time" .. i],
        stop_time   = postData["stop_time" .. i],
        device_name = postData["device_name" .. i],
      }
      local todValidations = {
        enable      = validateBoolean,
        rule_name   = validateLength,
        mac         = validateMAC,
        start_time  = validateTime,
        stop_time   = validateTime,
        device_name = validateLength,
      }

      if not (content_helper.validateObject(todData, todValidations) and validateDays(postData["days" .. i], postData, "days".. i)) then
        return nil
      end
    end
  end

  for i = 1, rows do
    if not match(postData["index" .. i], "^del.+$") then
      if postData["start_time" .. i] >= postData["stop_time" .. i] then
        return nil
      end
      for j = i+1, rows do
        if postData["mac" .. i] == postData["mac" .. j] and  -- same device
           not match(postData["index" .. j], "^del.+$") then -- and not a delted row, so check further
          if not validateOverlappingDays(postData["days" .. i], postData["days" .. j]) and -- If days overlap
            postData["start_time" .. i] <= postData["stop_time" .. j] and
            postData["stop_time" .. i] >= postData["start_time" .. j] then -- time overlaps
            return nil
          end
        end
      end
    end
  end
  return true
end

if ngx.req.get_method() == "POST" then
  local postargs = ngx.req.get_post_args()
  local totalRows = tonumber(postargs.total_rows) or 0
  local ToDTable = json.decode(postargs.todObj)
  local path
  local setTable = {}
  local ToDParams = {"index", "enable", "rule_name", "mac", "device_name", "days", "start_time", "stop_time"};

  -- Assign keys to all elements inside ToDTable
  for row = 1, totalRows do
    for index = 1, #ToDParams do
      local key = ToDParams[index] .. row
      local value = ToDTable[row][index]
      ToDTable[key] = value
    end
    ToDTable[row] = nil
  end

  local validated = validateTODRules(ToDTable, totalRows) and validateBoolean(postargs.global_enable)
  if validated then
    setTable["rpc.tod.macfilter_enable"] = postargs.global_enable
    for i = 1, totalRows do
      --  DELETE TOD RULE
      if ToDTable["index" .. i] then
        local isDeletedRow = ToDTable["index" .. i]:match("del(.*)")
        if isDeletedRow then
          path = format("uci.tod.host.%s.", isDeletedRow)
          proxy.del(path)
          local pathtimer = format("%s%s_parental_hours.",timerPath, isDeletedRow)
          proxy.del(pathtimer)
        end
      end

      --  EDIT TOD RULE
      local index = ToDTable["index" .. i] or ""
      if index ~= "" then
        local todData = {
          enable      = ToDTable["enable" .. i],
          rule_name   = ToDTable["rule_name" .. i],
          mac         = ToDTable["mac" .. i],
          start_time  = ToDTable["start_time" .. i],
          stop_time   = ToDTable["stop_time" .. i],
          mode        = "block",
        }
        local todParams = {
          enable      = "enabled",
          start_time  = "start_time",
          stop_time   = "stop_time",
          rule_name   = "rule_name",
          mac         = "id",
          mode        = "mode",
        }
       local success = content_helper.setObject(todData, todParams, "uci.tod.host." .. untaint(index) .. ".")

        if success then
          if not hostTable[ToDTable["mac" .. i]] then
            hostTable[ToDTable["mac" .. i]] = ToDTable["device_name" .. i]
            local deviceInstance = proxy.add("uci.user_friendly_name.name.", post_helper.getRandomKey())
            path = format("uci.user_friendly_name.name.@%s.name" , deviceInstance)
            setTable[path] = ToDTable["device_name" .. i]
            path = format("uci.user_friendly_name.name.@%s.mac" , deviceInstance)
            setTable[path] = ToDTable["mac" .. i]
          end
          if ToDTable["days" .. i] then
            path = format("uci.tod.host.%s.weekdays.",index)
            proxy.del(path)
            local t = {}
            local num_days
            for j = 1, #ToDTable["days" .. i] do
              local weekdaysPath = format("uci.tod.host.%s.weekdays.", index)
              proxy.add(weekdaysPath)
              proxy.set({ [ format("%s@%s.value", weekdaysPath, j) ] = ToDTable["days" .. i][j] })
              table.insert(t, ToDTable["days" .. i][j])
              numdays=j
            end
            if(numdays == 7) then
              proxy.set({ [ format("uci.tod.timer.%s_parental_hours.start_time",index) ] = "All"..":"..ToDTable["start_time" .. i] })
              proxy.set({ [ format("uci.tod.timer.%s_parental_hours.stop_time",index) ] = "All"..":"..ToDTable["stop_time" .. i] })
            else
              local a = table.concat(t, ", ")
              proxy.set({ [ format("uci.tod.timer.%s_parental_hours.start_time",index) ] = a..":"..ToDTable["start_time" .. i] })
              proxy.set({ [ format("uci.tod.timer.%s_parental_hours.stop_time",index) ] = a..":"..ToDTable["stop_time" .. i] })
            end
          end
        end
      end

      --  ADD TOD RULE
      if ToDTable["index" .. i] == "new" then
        local paramMap = {
          ["ENABLED"] = "enabled",
          ["RULE"] = "rule_name",
          ["TYPE"] = "type",
          ["START_TIME"] = "start_time",
          ["STOP_TIME"] = "stop_time",
          ["ID"] = "id",
          ["MODE"] = "mode",
        }
        local TOD_content = {
          ["ENABLED"] = ToDTable["enable" .. i],
          ["RULE"] = ToDTable["rule_name" .. i],
          ["TYPE"] = "mac",
          ["START_TIME"] = ToDTable["start_time" .. i],
          ["STOP_TIME"] = ToDTable["stop_time" .. i],
          ["ID"] = ToDTable["mac" .. i],
          ["MODE"] = "block",
        }
        local uniqueKey = post_helper.getRandomKey()
        local addedIndex = content_helper.addNewObject("uci.tod.host.@.", TOD_content, paramMap, nil, uniqueKey)
        local t = {}
        local num_days
        if addedIndex then
          proxy.set("uci.tod.host.@" .. addedIndex .. ".script", "parentalscript")
          local uniquetimer = uniqueKey.."_parental_hours"
          local path_timer = format("uci.tod.host.@%s.timers.", addedIndex)
          local instance1 = proxy.add(path_timer)
          proxy.set({ [ format("%s@%s.value", path_timer, instance1) ] = uniquetimer })
          local instance2 = proxy.add(timerPath, uniquetimer)
          if not hostTable[ToDTable["mac" .. i]] then
            hostTable[ToDTable["mac" .. i]] = ToDTable["device_name" .. i]
            local deviceInstance = proxy.add("uci.user_friendly_name.name.", post_helper.getRandomKey())
            path = format("uci.user_friendly_name.name.@%s.name" , deviceInstance)
            setTable[path] = ToDTable["device_name" .. i]
            path = format("uci.user_friendly_name.name.@%s.mac" , deviceInstance)
            setTable[path] = ToDTable["mac" .. i]
          end
          for j = 1, #ToDTable["days" .. i] do
            local basepath = format("uci.tod.host.@%s.weekdays.", addedIndex)
            local instance = proxy.add(basepath)
            proxy.set({ [ format("%s@%s.value", basepath, instance) ] = ToDTable["days" .. i][j] })
            table.insert(t, ToDTable["days" .. i][j])
            numdays=j
          end
          if(numdays == 7) then
            proxy.set({ [ format("uci.tod.timer.@%s.start_time",uniquetimer) ] = "All"..":"..ToDTable["start_time" .. i] })
            proxy.set({ [ format("uci.tod.timer.@%s.stop_time",uniquetimer) ] = "All"..":"..ToDTable["stop_time" .. i] })
          else
            local a = table.concat(t, ", ")
            proxy.set({ [ format("uci.tod.timer.@%s.start_time",uniquetimer) ] = a..":"..ToDTable["start_time" .. i] })
            proxy.set({ [ format("uci.tod.timer.@%s.stop_time",uniquetimer) ] = a..":"..ToDTable["stop_time" .. i] })
          end
        end
      end
    end
  end

  ngx.header.content_type = "application/json"
  if not validated then
    ngx.print('{ "status":"error" }')
  else
    if next(setTable) then
      local success = proxy.set(setTable)
      if success then
        proxy.apply()
        ngx.print('{ "status":"success" }')
      else
        ngx.print('{ "status":"error" }')
      end
      ngx.exit(ngx.HTTP_OK)
    end
    proxy.apply()
    ngx.print('{ "status":"success" }')
  end
  ngx.exit(ngx.HTTP_OK)
end

local todRules = proxy.get("uci.tod.host.")
local todRuleList = content_helper.convertResultToObject("uci.tod.host.", todRules)
local todEnable = (proxy.get("rpc.tod.macfilter_enable")[1].value) == "1"

for _, rule in pairs(todRuleList) do
  TOD[#TOD+1] = {}
  TOD[#TOD].rule_name = rule.rule_name
  TOD[#TOD].enabled = rule.enabled == "1"
  TOD[#TOD].stop_time = rule.stop_time
  TOD[#TOD].mac = rule.id
  TOD[#TOD].device_name = hostTable[rule.id] or "unknown-" .. rule.id
  TOD[#TOD].index = rule.paramindex
  TOD[#TOD].start_time = rule.start_time
  local weekdays = {}
  local weekdaysTranslated = {}
  local weekdaysPath = format("uci.tod.host.%s.weekdays.",rule.paramindex)
  local daysList = proxy.get(weekdaysPath)
  daysList = content_helper.convertResultToObject(weekdaysPath, daysList)
  for _, day in ipairs(daysList) do
    day.value = string.untaint(day.value)
    weekdays[#weekdays+1] = day.value
    weekdaysTranslated[#weekdaysTranslated+1] = daysMap[day.value].text
  end
  -- all days from datamodel needs to be sorted from Mon .. Sun
  -- also translate each days in the sorted table and have it in seprate
  -- table to show them in GUI as a comma seperated value
  local daysOfWeek = sortDays(weekdays)
  local daysOfWeekTranslated = {}
  for _, day in ipairs(daysOfWeek) do
    daysOfWeekTranslated[#daysOfWeekTranslated+1] = daysMap[day].text
  end
  daysOfWeekTranslated = table.concat(daysOfWeekTranslated, ", ")
  daysOfWeek = table.concat(daysOfWeek, ", ")
  TOD[#TOD].dayType = {
    value = dayTable[daysOfWeek] and dayTable[daysOfWeek].value or daysOfWeek,
    text = dayTable[daysOfWeek] and dayTable[daysOfWeek].text or daysOfWeekTranslated
  }
end

-- We cannot guarantee transformer to return table in the same order ever time
-- So, Sort the table by param index to display in same order ever time in GUI
sort(TOD, function(a,b)
    return a.index < b.index
end)
local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")

  ngx.print('\
\
<h1>');  ngx.print(T"Parental Control"); ngx.print('</h1>\
<h2>');  ngx.print(T"Block access of LAN Computers at given times, according to their MACs"); ngx.print('</h2>\
<h3>');  ngx.print(T"Access Control"); ngx.print('</h3>\
<div class="h3-content h3-content-mobile">\
  ');  
    local hiddenFields = {
      ui_helper.createHiddenField("global-enable", "", todEnable and "1" or "0"),
    }
    ngx.print(table.concat(hiddenFields, "\n"))
    local row = {
        label = T"Access Control",
        element = format('<div class="pull-right">%s</div>',ui_helper.createButton({id = "tod-btn-enable", class = todEnable and "toggle-content-button button button-on" or "toggle-content-button button button-off"})),
        rowClass = "row padding-top-bottom-20",
        colLeftClass = "col-md-12 col-sm-12 col-lg-12 col-xs-6",
        colRightClass = "col-md-6 col-sm-6 col-xs-6",
        labelClass = "font-bold"
    }
    ngx.print(ui_helper.createRow(row))
    ngx.print('\
\
  <!-- TABLE STARTS HERE -->\
\
  ');  local tableStyle = (not todEnable) and "display:none" or "display:block"   ngx.print('\
  <div id="tod_table" class="toggle-table-content" style="');  ngx.print(tableStyle); ngx.print('">\
    <!-- Desktop VIEW -->\
    <div id="parental-tbl-desktop">\
      <div class="table parental-control desktop h3-content">\
        <div class="table-row table-row-head" id="parental-thead-desktop">\
          <div class="table-col">\
            <span>');  ngx.print(T"Rule Name"); ngx.print('</span>\
          </div>\
          <div class="table-col">\
            <span>');  ngx.print(T"Device"); ngx.print('</span>\
          </div>\
          <div class="table-col">\
            <span>');  ngx.print(T"Days Of Week"); ngx.print('</span>\
          </div>\
          <div class="table-col">\
            <span>');  ngx.print(T"From"); ngx.print('</span>\
          </div>\
          <div class="table-col">\
            <span>');  ngx.print(T"To"); ngx.print('</span>\
          </div>\
          <div class="table-col">&nbsp;</div>\
          <div class="table-col">&nbsp;</div>\
          <div class="table-col">&nbsp;</div>\
        </div>\
\
        ');  for i, v in ipairs(TOD) do  ngx.print('\
          <div class="table-row parental-row-desktop ');  ngx.print(not v.enabled and "op40" or ""); ngx.print('">\
            <input type="hidden" class="row-index" value="');  ngx.print(v.index); ngx.print('">\
            <input type="hidden" class="enable" value="');  ngx.print(v.enabled and "1" or "0"); ngx.print('">\
            <div class="table-col">\
              <span class="rule-name">');  ngx.print(v.rule_name); ngx.print('</span>\
            </div>\
            <div class="table-col">\
              <input type="hidden" class="mac" value="');  ngx.print(v.mac); ngx.print('"/>\
              <span class="device-name">');  ngx.print(v.device_name); ngx.print('</span>\
            </div>\
            <div class="table-col">\
              <input type="hidden" class="dayType" value="');  ngx.print(v.dayType.value or ""); ngx.print('">\
              <span class="days">');  ngx.print(v.dayType.text); ngx.print('</span>\
            </div>\
            <div class="table-col">\
              <span class="start-time">');  ngx.print(v.start_time); ngx.print('</span>\
            </div>\
            <div class="table-col">\
              <span class="stop-time">');  ngx.print(v.stop_time); ngx.print('</span>\
            </div>\
            <div class="table-col">\
              <input class="button button-edit" type="button" onclick="copyData(this)" data-toggle="modal" data-target="#parental-popup-edit">\
            </div>\
            <div class="table-col">\
              <input class="button button-delete" type="button">\
            </div>\
            <div class="table-col fR tR">\
              <div class="toggle-row-enable button ');  if v.enabled then   ngx.print('button-on');  else   ngx.print('button-off');  end   ngx.print('"></div>\
            </div>\
          </div>\
        ');  end   ngx.print('\
        <div id="parental-row-Desktoplast" class="table-row">\
          <div class="table-col">&nbsp;</div>\
          <div class="table-col">&nbsp;</div>\
          <div class="table-col">&nbsp;</div>\
          <div class="table-col">&nbsp;</div>\
          <div class="table-col">&nbsp;</div>\
          <div class="table-col">&nbsp;</div>\
          <div class="table-col">&nbsp;</div>\
          <div class="table-col fR tR">\
            <input id="parental-img-add" class="toggle-row-enable button button-add" value="" type="button" data-toggle="modal" data-target="#addAccessControlModal" />\
          </div>\
        </div>\
      </div>\
    </div>\
\
    <!-- Mobile VIEW -->\
    <div class="mobile-table-big with-on-off mobile parental-control table" id="parental-tbl-mobile">\
      ');  for i, v in ipairs(TOD) do  ngx.print('\
        <div class="mobile-entry parental-row-mobile ');  ngx.print(not v.enabled and "op50" or ""); ngx.print('">\
          <div class="on-off-wrap">\
            <div class="toggle-row-enable button ');  if v.enabled then   ngx.print('button-on');  else   ngx.print('button-off');  end   ngx.print('">\
            </div>\
          </div>\
          <div class="mobile-table-big-content">\
            <div class="mobile-subtitle">\
              <span>');  ngx.print(T"Rule Name"); ngx.print('</span>\
            </div>\
            <div class="mobile-content">\
              <span class="rule-name">');  ngx.print(v.rule_name); ngx.print('</span>\
            </div>\
            <div class="mobile-subtitle">\
              <span>');  ngx.print(T"Device"); ngx.print('</span>\
            </div>\
            <div class="mobile-content">\
              <span class="device-name">');  ngx.print(v.device_name); ngx.print('</span>\
            </div>\
            <div class="mobile-subtitle">\
              <span>');  ngx.print(T"Days Of Week"); ngx.print('</span>\
            </div>\
            <div class="mobile-content">\
              <span class="days">');  ngx.print(v.dayType.text); ngx.print('</span>\
            </div>\
            <div class="mobile-subtitle">\
              <span>');  ngx.print(T"From"); ngx.print('</span>\
            </div>\
            <div class="mobile-content">\
              <span class="start-time">');  ngx.print(v.start_time); ngx.print('</span>\
            </div>\
            <div class="mobile-subtitle">\
              <span>');  ngx.print(T"To"); ngx.print('</span>\
            </div>\
            <div class="mobile-content">\
              <span class="stop-time">');  ngx.print(v.stop_time); ngx.print('</span>\
            </div>\
          </div>\
          <div class="buttons-wrap-edit-delete">\
            <input class="button button-edit" type="button">\
            <input class="button button-delete" type="button">\
          </div>\
        </div>\
      ');  end   ngx.print('\
      <div class="buttons-wrap-add" id="parental-row-mobileLast">\
        <input class="button button-add" id="parental-img-mobileAdd" type="button">\
      </div>\
    </div>\
  </div>\
  <!-- TOD TABLE ENDS -->\
</div>\
\
');  
  lp.include("apply-cancel.lp")
  lp.include("reset-wrap-mobile.lp")
  ngx.print('\
\
<!-- Edit Popup Modal-->\
<div class="modal fade" id="parental-popup-edit" role="dialog" data-backdrop="static">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content parental-control-content">\
      <div class="modal-header hidden-sm hidden-md hidden-lg">\
        <div class="mobile-cancel-popup button-cancel"></div>\
      </div>\
      <div class="modal-body no-padding">\
        <form class="form-horizontal">\
          <div class="form-group">\
            <div class="col-sm-12">\
              <p class="title tL">\
                ');  ngx.print(T"Edit Access Control Rule"); ngx.print('\
              </p>\
            </div>\
          </div>\
        ');  
          local options = {}
          for i, v in pairs(hostTable) do
            options[#options+1] = {i, v}
          end
          local daysOptions = {
            {"Every Day", T"Every Day"},
            {"Every Workday", T"Every Workday"},
            {"All Weekend", T"All Weekend"},
            {"Individual Days", T"Individual Days"}
          }
          local row = {
              {
                  label = T"Rule Name",
                  element = ui_helper.createTextField({id = "parental-txt-editRuleName", maxlength = "63", type = "text", class = "add-parent-text"})

              },
              {
                  label = T"Device",
                  element = format('<div id="top-info-mode" class="right rel">%s</div>', ui_helper.createDropDown({id = "parental-sel-editDevice"}, options, nil, {{"newDevice", T"Choose new device"}}))
              },
              {
                  label = T"Name",
                  element = ui_helper.createTextField({id = "parental-txt-editNewDeviceName", type = "text", class = "add-parent-text"})
              },
              {
                  rowId = "parental-div-editNewMAC",
                  colRightClass = "right halfWidth no-important",
                  colRightId = "parental-div-EditMAC",
                  label = T"MAC Address",
                  element = ui_helper.createMACAddressFields("parental-txt-editMAC", "editMAC parent-max2")
              },
              {
                  rowId = "parental-div-editOldMAC",
                  label = T"MAC Address",
                  element = ui_helper.createOnlyText({id = "parental-info-editOldMAC"},"")
              },
              {
                  label = T"Days Of Week",
                  element = format('<div id="top-info-mode" class="right rel">%s</div>', ui_helper.createDropDown({id = "parental-sel-editDays"}, daysOptions))
              },
              {
                  rowId = "parental-div-editIndividualDays",
                  label = T"Select Individual Days",
                  element = ui_helper.createDaysCheckbox("individual-days-day", "individual-days-checkbox", "parental-chk-editDay")
              },
              {
                  rowClass = "vdf-row clearboth",
                  label = T"Time",
                  element = ui_helper.createTimeField("parental-div-editStart", "parental-txt-editStartTime", "parental-div-editStop", "parental-txt-editEndTime"),
              }
          }
          ngx.print(ui_helper.createTable(row, "", "vdf-table"))
          ngx.print('\
       <div class="form-group">\
         <div class="col-sm-12">\
           <div class="modal-footer">\
             <input class="button button-apply save mob-button-width" value="');  ngx.print(T"Save"); ngx.print('" id="parental-btn-editSave" data-dismiss="modal" type="button" />\
             <input class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" data-dismiss="modal" value="');  ngx.print(T"Cancel"); ngx.print('" type="button" id="parental-btn-editCancel" />\
           </div>\
         </div>\
       </div>\
      </form>\
      </div>\
    </div>\
  </div>\
</div>\
\
<!-- ADD Popup Modal-->\
<div class="modal fade" id="addAccessControlModal" role="dialog" data-backdrop="static">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content parental-control-content">\
    <div class="modal-header hidden-sm hidden-md hidden-lg">\
        <div class="mobile-cancel-popup button-cancel"></div>\
      </div>\
      <div class="modal-body no-padding">\
        <form class="form-horizontal">\
          <div class="form-group">\
            <div class="col-sm-12">\
              <p class="title tL">\
                ');  ngx.print(T"Add Access Control Rule"); ngx.print('\
              </p>\
            </div>\
          </div>\
\
        ');  
          local options = {}
          for i, v in pairs(hostTable) do
            options[#options+1] = {i, v}
          end
          local daysOptions = {
            {"Every Day", T"Every Day"},
            {"Every Workday", T"Every Workday"},
            {"All Weekend", T"All Weekend"},
            {"Individual Days", T"Individual Days"}
          }
          local row = {
              {
                  label = T"Rule Name",
                  element = ui_helper.createTextField({id = "parental-txt-AddRuleName", maxlength = "63", type = "text", class="add-parent-text"})
              },
              {
                  label = T"Device",
                  element = format('<div id="top-info-mode" class="right rel">%s</div>', ui_helper.createDropDown({id = "parental-sel-addDevice"}, options, nil, {{"newDevice", T"Add new device"}}))
              },
              {
                  label = T"Name",
                  element = ui_helper.createTextField({id = "parental-txt-addNewDeviceName", type = "text", class = "add-parent-text"})
              },
              {
                  rowId = "parental-div-addNewMAC",
                  colRightClass = "right halfWidth no-important",
                  colRightId = "parental-div-addMAC",
                  label = T"MAC Address",
                  element = ui_helper.createMACAddressFields("parental-div-addMAC", "newmac parent-max2")
              },
              {
                  rowId = "parental-div-addOldMAC",
                  label = T"MAC Address",
                  element = ui_helper.createOnlyText({id = "parental-info-addOldMAC"},"")
              },
              {
                  label = T"Days Of Week",
                  element = format('<div id="top-info-mode" class="right rel">%s</div>', ui_helper.createDropDown({id = "parental-sel-addDays"}, daysOptions))
              },
              {
                  rowId = "parental-div-addIndividualDays",
                  label = T"Select Individual Days",
                  element = ui_helper.createDaysCheckbox("individual-days-day", "individual-days-checkbox", "parental-chk-addDay")
              },
              {
                  rowClass = "vdf-row clearboth",
                  label = T"Time",
                  element = ui_helper.createTimeField("parental-div-addStart", "parental-txt-addStartTime", "parental-div-addStop","parental-txt-addEndTime"),
              }
          }
          ngx.print(ui_helper.createTable(row, "", "vdf-table"))
          ngx.print('\
\
          <div class="form-group">\
            <div class="col-sm-12">\
              <div class="modal-footer">\
                <input id="parental-btn-newSave" class="button button-apply save mob-button-width" value="');  ngx.print(T"Save"); ngx.print('" data-dismiss="modal" type="button" />\
                <input class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" data-dismiss="modal" value="');  ngx.print(T"Cancel"); ngx.print('" type="button" id="parental-btn-newCancel" />\
              </div>\
            </div>\
          </div>\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
<script src="js/global-min.js"></script>\
<script>\
  var connectedDevices = [];\
  ');  for i in pairs(hostTable) do  ngx.print('\
    connectedDevices.push("');  ngx.print(i); ngx.print('".toUpperCase());\
  ');  end  ngx.print('\
  var T = {\
    "Mon" : "');  ngx.print(T"Mon"); ngx.print('",\
    "Tue" : "');  ngx.print(T"Tue"); ngx.print('",\
    "Wed" : "');  ngx.print(T"Wed"); ngx.print('",\
    "Thu" : "');  ngx.print(T"Thu"); ngx.print('",\
    "Fri" : "');  ngx.print(T"Fri"); ngx.print('",\
    "Sat" : "');  ngx.print(T"Sat"); ngx.print('",\
    "Sun" : "');  ngx.print(T"Sun"); ngx.print('",\
    "Rule Name" : "');  ngx.print(T"Rule Name"); ngx.print('",\
    "Device" : "');  ngx.print(T"Device"); ngx.print('",\
    "Days Of Week" : "');  ngx.print(T"Days Of Week"); ngx.print('",\
    "From" : "');  ngx.print(T"From"); ngx.print('",\
    "To" : "');  ngx.print(T"To"); ngx.print('"\
  }\
</script>\
<script src="js/internet/parentalControl.js"></script>\
'); 