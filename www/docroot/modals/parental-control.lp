--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")
local json = require("dkjson")
local vdf_helper = require("vodafone_helper")
local validateTime, validateDays, validateOverlappingDays = vdf_helper.validateTime, vdf_helper.validateDays, vdf_helper.validateOverlappingDays
local string = string
local gmatch, format, find, match, upper = string.gmatch, string.format, string.find, string.match, string.upper
local table, setmetatable = table, setmetatable
local next, pairs, ipairs = next, pairs, ipairs
local sort, concat = table.sort, table.concat
local tonumber = tonumber
local untaint_mt = require("web.taint").untaint_mt
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local print = require("tch.tableprint")
local TOD = {}
local validateMAC = post_helper.validateStringIsMAC
local validateBoolean = post_helper.validateBoolean
local validateLength = post_helper.getValidateStringLengthInRange(1,63)

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
        local isDeletedRow =  tonumber(ToDTable["index" .. i]:match("del(%d*)"))
        if isDeletedRow then
          path = format("uci.tod.host.%s.", isDeletedRow)
          proxy.del(path)
        end
      end

      --  EDIT TOD RULE
      local index = tonumber(ToDTable["index" .. i]) or ""
      if find(index, "^%d+$") then
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
        local success = content_helper.setObject(todData, todParams, "uci.tod.host." .. index .. ".")
        if success then
          if not hostTable[ToDTable["mac" .. i]] then
            hostTable[ToDTable["mac" .. i]] = ToDTable["device_name" .. i]
            local deviceInstance = proxy.add("uci.user_friendly_name.name.")
            path = format("uci.user_friendly_name.name.%s.name" , deviceInstance)
            setTable[path] = ToDTable["device_name" .. i]
            path = format("uci.user_friendly_name.name.%s.mac" , deviceInstance)
            setTable[path] = ToDTable["mac" .. i]
          end
          if ToDTable["days" .. i] then
            path = format("uci.tod.host.%s.weekdays.",index)
            proxy.del(path)
            for j = 1, #ToDTable["days" .. i] do
              local weekdaysPath = format("uci.tod.host.%s.weekdays.", index)
              proxy.add(weekdaysPath)
              proxy.set({ [ format("%s@%s.value", weekdaysPath, j) ] = ToDTable["days" .. i][j] })
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
        local addedIndex = content_helper.addNewObject("uci.tod.host.", TOD_content, paramMap)
        if addedIndex then
          if not hostTable[ToDTable["mac" .. i]] then
            hostTable[ToDTable["mac" .. i]] = ToDTable["device_name" .. i]
            local deviceInstance = proxy.add("uci.user_friendly_name.name.")
            path = format("uci.user_friendly_name.name.%s.name" , deviceInstance)
            setTable[path] = ToDTable["device_name" .. i]
            path = format("uci.user_friendly_name.name.%s.mac" , deviceInstance)
            setTable[path] = ToDTable["mac" .. i]
          end
          for j = 1, #ToDTable["days" .. i] do
            local basepath = format("uci.tod.host.%s.weekdays.", addedIndex)
            local instance = proxy.add(basepath)
            proxy.set({ [ format("%s@%s.value", basepath, instance) ] = ToDTable["days" .. i][j] })
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
  return tonumber(a.index) < tonumber(b.index)
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
  <div class="row padding-top-bottom-20">\
    <div class="col-md-12 col-sm-12 col-lg-12 col-xs-12">\
      <span class="font-bold">');  ngx.print(T"Access Control"); ngx.print('</span>\
    </div>\
    <div class="col-md-6 col-sm-6 col-xs-6">\
      <div class=" pull-right">\
        <div id="tod-btn-enable" class="toggle-content-button button ');  if todEnable then   ngx.print('button-on');  else   ngx.print('button-off');  end   ngx.print('"></div>\
        <input type="hidden" id="global-enable" value="');  ngx.print(todEnable and "1" or "0"); ngx.print('">\
      </div>\
    </div>\
  </div>\
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
		<div class="vdf-table">\
          <div class="vdf-row">\
            <div class="left">\
              <label for="inputPassword">');  ngx.print(T"Rule Name"); ngx.print('</label>\
            </div>\
            <div class="right">\
              <input id="parental-txt-editRuleName" maxlength="63" type="text" class="add-parent-text">\
            </div>\
          </div>\
\
          <div class="vdf-row">\
            <div class="left">\
              <label for="inputPassword">');  ngx.print(T"Device"); ngx.print('</label>\
            </div>\
              <div id="top-info-mode" class="right rel">\
                <select id="parental-sel-editDevice">\
                  <option value="newDevice">');  ngx.print(T"Choose new device"); ngx.print('</option>\
                  ');  
                    for i,v in pairs(hostTable) do
                      ngx.print(format("<option value='%s'>%s</option>",i,v))
                    end
                    ngx.print('\
                </select>\
			  </div>\
          </div>\
\
          <div id="parental-div-editNewName" class="vdf-row clearboth">\
            <div class="left">\
              <label for="inputPassword">');  ngx.print(T"Name"); ngx.print('</label>\
            </div>\
            <div class="right">\
              <input id="parental-txt-editNewDeviceName" type="text" class="add-parent-text">\
            </div>\
          </div>\
\
          <div id="parental-div-editNewMAC" class="vdf-row">\
            <div class="left">\
              <label for="inputPassword2">');  ngx.print(T"MAC Address"); ngx.print('</label>\
            </div>\
		    <div class="right halfWidth no-important" id="parental-div-EditMAC">\
			  <input id="parental-txt-editMAC1" maxlength="2" class="max2 editMAC parent-max2 alphanum" type="text" /><span>:</span>\
			  <input id="parental-txt-editMAC2" maxlength="2" class="max2 editMAC parent-max2 alphanum" type="text" /><span>:</span>\
			  <input id="parental-txt-editMAC3" maxlength="2" class="max2 editMAC parent-max2 alphanum" type="text" /><span>:</span>\
			  <input id="parental-txt-editMAC4" maxlength="2" class="max2 editMAC parent-max2 alphanum" type="text" /><span>:</span>\
			  <input id="parental-txt-editMAC5" maxlength="2" class="max2 editMAC parent-max2 alphanum" type="text" /><span>:</span>\
			  <input id="parental-txt-editMAC6" maxlength="2" class="max2 editMAC parent-max2 alphanum" type="text" />\
		    </div>\
          </div>\
\
          <div id="parental-div-editOldMAC" class="vdf-row" style="display:hide">\
            <div class="left">\
              <label for="inputPassword">');  ngx.print(T"MAC Address"); ngx.print('</label>\
            </div>\
            <div class="right">\
              <span id="parental-info-editOldMAC"></span>\
            </div>\
          </div>\
\
\
          <div class="vdf-row">\
            <div class="left">\
              <label for="portSingle">');  ngx.print(T"Days Of Week"); ngx.print('</label>\
            </div>\
              <div id="top-info-mode" class="rel right">\
                <select id="parental-sel-editDays">\
                  <option value="Every Day">');  ngx.print(T"Every Day"); ngx.print('</option>\
                  <option value="Every Workday">');  ngx.print(T"Every Workday"); ngx.print('</option>\
                  <option value="All Weekend">');  ngx.print(T"All Weekend"); ngx.print('</option>\
                  <option value="Individual Days">');  ngx.print(T"Individual Days"); ngx.print('</option>\
                </select>\
              </div>\
          </div>\
          <div id="parental-div-editIndividualDays" class="vdf-row">\
            <div class="left">\
              <label for="portSingle">');  ngx.print(T"Select Individual Days"); ngx.print('</label>\
            </div>\
            <div class="right">\
              <div class="col-md-6 col-sm-6 modal-padding-lrt-none btn-wrap-mobile no-padding">\
                <div class="individual-days-day">\
                  <div class="individual-days-checkbox">\
                    <input id="parental-chk-editDay1" class="checkbox checkbox-unchecked show-hide-pw" data-id="1" type="checkbox">\
                    <label for="parental-chk-editDay1"></label>\
                  </div>\
                  <div class="individual-days-day-wrap">\
                    <span>');  ngx.print(T"Monday"); ngx.print('</span>\
                  </div>\
                </div>\
\
                <div class="individual-days-day">\
                  <div class="individual-days-checkbox">\
                    <input id="parental-chk-editDay2" class="checkbox checkbox-unchecked show-hide-pw" data-id="2" type="checkbox">\
                    <label for="parental-chk-editDay2"></label>\
                  </div>\
                  <div class="individual-days-day-wrap">\
                    <span>');  ngx.print(T"Tuesday"); ngx.print('</span>\
                  </div>\
                </div>\
\
                <div class="individual-days-day">\
                  <div class="individual-days-checkbox">\
                    <input id="parental-chk-editDay3" class="checkbox checkbox-unchecked show-hide-pw" data-id="3" type="checkbox">\
                    <label for="parental-chk-editDay3"></label>\
                  </div>\
                  <div class="individual-days-day-wrap">\
                    <span>');  ngx.print(T"Wednesday"); ngx.print('</span>\
                  </div>\
                </div>\
\
                <div class="individual-days-day">\
                  <div class="individual-days-checkbox">\
                    <input id="parental-chk-editDay4" class="checkbox checkbox-unchecked show-hide-pw" data-id="4" type="checkbox">\
                    <label for="parental-chk-editDay4"></label>\
                  </div>\
                  <div class="individual-days-day-wrap">\
                    <span>');  ngx.print(T"Thursday"); ngx.print('</span>\
                  </div>\
                </div>\
\
                <div class="individual-days-day">\
                  <div class="individual-days-checkbox">\
                    <input id="parental-chk-editDay5" class="checkbox checkbox-unchecked show-hide-pw" data-id="5" type="checkbox">\
                    <label for="parental-chk-editDay5"></label>\
                  </div>\
                  <div class="individual-days-day-wrap">\
                    <span>');  ngx.print(T"Friday"); ngx.print('</span>\
                  </div>\
                </div>\
              </div>\
              <div class="col-md-6 col-sm-6 modal-padding-lrt-none btn-wrap-mobile no-padding">\
                <div class="individual-days-day">\
                  <div class="individual-days-checkbox">\
                    <input id="parental-chk-editDay6" class="checkbox checkbox-unchecked show-hide-pw" data-id="6" type="checkbox">\
                    <label for="parental-chk-editDay6"></label>\
                  </div>\
                  <div class="individual-days-day-wrap">\
                    <span>');  ngx.print(T"Saturday"); ngx.print('</span>\
                  </div>\
                </div>\
                <div class="individual-days-day">\
                  <div class="individual-days-checkbox">\
                    <input id="parental-chk-editDay7" class="checkbox checkbox-unchecked show-hide-pw" data-id="7" type="checkbox">\
                    <label for="parental-chk-editDay7"></label>\
                  </div>\
                  <div class="individual-days-day-wrap">\
                    <span>');  ngx.print(T"Sunday"); ngx.print('</span>\
                  </div>\
                </div>\
              </div>\
            </div>\
          </div>\
          <div class="vdf-row clearboth">\
            <div class="left">\
              <label for="inputPassword2">');  ngx.print(T"Time"); ngx.print('</label>\
            </div>\
         <div class="right">\
          <div class="halfWidth no-important no-padding-left-right from-to-textbox" id="parental-div-editStart">\
            <span>');  ngx.print(T"From"); ngx.print('</span> <input maxlength="5" id="parental-txt-editStartTime" class="max5 max5-range parent-max5 time" placeholder="HH:MM" type="text" />\
          </div>\
          <div class="halfWidth no-important no-padding-left-right from-to-textbox" id="parental-div-editStop">\
            <span>');  ngx.print(T"To"); ngx.print('</span> <input maxlength="5" id="parental-txt-editEndTime" class="max5 max5-range parent-max5 time" placeholder="HH:MM" type="text" />\
          </div>\
        </div>\
       </div>\
       </div>\
       <div class="form-group">\
         <div class="col-sm-12">\
           <div class="modal-footer">\
             <input class="button button-apply save mob-button-width" value="');  ngx.print(T"Apply"); ngx.print('" id="parental-btn-editSave" data-dismiss="modal" type="button" />\
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
		  <div class="vdf-table">\
          <div class="vdf-row">\
            <div class="left">\
              <label for="inputPassword">');  ngx.print(T"Rule Name"); ngx.print('</label>\
            </div>\
            <div class="right">\
              <input id="parental-txt-AddRuleName" maxlength="63" type="text" class="add-parent-text">\
            </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <label for="inputPassword">');  ngx.print(T"Device"); ngx.print('</label>\
            </div>\
              <div id="top-info-mode" class="right rel">\
                <select id="parental-sel-addDevice">\
                  <option value="newDevice">');  ngx.print(T"Add new device"); ngx.print('</option>\
                  ');  
                    for i,v in pairs(hostTable) do
                      ngx.print(format("<option value='%s'>%s</option>",i,v))
                    end
                    ngx.print('\
                </select>\
              </div>\
          </div>\
\
          <div id="parental-div-addNewName" class="vdf-row clearboth">\
            <div class="left">\
              <label for="inputPassword">');  ngx.print(T"Name"); ngx.print('</label>\
            </div>\
            <div class="right">\
              <input id="parental-txt-addNewDeviceName" type="text" class="add-parent-text">\
            </div>\
          </div>\
\
          <div id="parental-div-addNewMAC" class="vdf-row">\
            <div class="left">\
              <label for="inputPassword2">');  ngx.print(T"MAC Address"); ngx.print('</label>\
            </div>\
              <div class="right halfWidth no-important" id="parental-div-addMAC">\
                <input id="parental-txt-addMAC1" maxlength="2" class="max2 newmac parent-max2 alphanum" type="text" /><span>:</span>\
                <input id="parental-txt-addMAC2" maxlength="2" class="max2 newmac parent-max2 alphanum" type="text" /><span>:</span>\
                <input id="parental-txt-addMAC3" maxlength="2" class="max2 newmac parent-max2 alphanum" type="text" /><span>:</span>\
                <input id="parental-txt-addMAC4" maxlength="2" class="max2 newmac parent-max2 alphanum" type="text" /><span>:</span>\
                <input id="parental-txt-addMAC5" maxlength="2" class="max2 newmac parent-max2 alphanum" type="text" /><span>:</span>\
                <input id="parental-txt-addMAC6" maxlength="2" class="max2 newmac parent-max2 alphanum" type="text" />\
              </div>\
          </div>\
\
          <div id="parental-div-addOldMAC" class="vdf-row" style="display:hide">\
            <div class="left">\
              <label for="inputPassword">');  ngx.print(T"MAC Address"); ngx.print('</label>\
            </div>\
            <div class="right">\
              <span id="parental-info-addOldMAC"></span>\
            </div>\
          </div>\
\
          <div class="vdf-row">\
            <div class="left">\
              <label for="portSingle">');  ngx.print(T"Days Of Week"); ngx.print('</label>\
            </div>\
              <div id="top-info-mode" class="right rel">\
                <select id="parental-sel-addDays">\
                  <option value="Every Day">');  ngx.print(T"Every Day"); ngx.print('</option>\
                  <option value="Every Workday">');  ngx.print(T"Every Workday"); ngx.print('</option>\
                  <option value="All Weekend">');  ngx.print(T"All Weekend"); ngx.print('</option>\
                  <option value="Individual Days">');  ngx.print(T"Individual Days"); ngx.print('</option>\
                </select>\
              </div>\
          </div>\
          <div id="parental-div-addIndividualDays" class="vdf-row" style="display:hide">\
            <div class="left">\
              <label for="portSingle">');  ngx.print(T"Select Individual Days"); ngx.print('</label>\
            </div>\
            <div class="right">\
              <div class="col-md-6 col-sm-6 modal-padding-lrt-none btn-wrap-mobile no-padding">\
                <div class="individual-days-day">\
                  <div class="individual-days-checkbox">\
                    <input id="parental-chk-addDay1" class="checkbox checkbox-unchecked show-hide-pw" data-id="1" type="checkbox">\
                    <label for="parental-chk-addDay1"></label>\
                  </div>\
                  <div class="individual-days-day-wrap">\
                    <span>');  ngx.print(T"Monday"); ngx.print('</span>\
                  </div>\
                </div>\
\
                <div class="individual-days-day">\
                  <div class="individual-days-checkbox">\
                    <input id="parental-chk-addDay2" class="checkbox checkbox-unchecked show-hide-pw" data-id="2" type="checkbox">\
                    <label for="parental-chk-addDay2"></label>\
                  </div>\
                  <div class="individual-days-day-wrap">\
                    <span>');  ngx.print(T"Tuesday"); ngx.print('</span>\
                  </div>\
                </div>\
\
                <div class="individual-days-day">\
                  <div class="individual-days-checkbox">\
                    <input id="parental-chk-addDay3" class="checkbox checkbox-unchecked show-hide-pw" data-id="3" type="checkbox">\
                    <label for="parental-chk-addDay3"></label>\
                  </div>\
                  <div class="individual-days-day-wrap">\
                    <span>');  ngx.print(T"Wednesday"); ngx.print('</span>\
                  </div>\
                </div>\
\
                <div class="individual-days-day">\
                  <div class="individual-days-checkbox">\
                    <input id="parental-chk-addDay4" class="checkbox checkbox-unchecked show-hide-pw" data-id="4" type="checkbox">\
                    <label for="parental-chk-addDay4"></label>\
                  </div>\
                  <div class="individual-days-day-wrap">\
                    <span>');  ngx.print(T"Thursday"); ngx.print('</span>\
                  </div>\
                </div>\
\
                <div class="individual-days-day">\
                  <div class="individual-days-checkbox">\
                    <input id="parental-chk-addDay5" class="checkbox checkbox-unchecked show-hide-pw" data-id="5" type="checkbox">\
                    <label for="parental-chk-addDay5"></label>\
                  </div>\
                  <div class="individual-days-day-wrap">\
                    <span>');  ngx.print(T"Friday"); ngx.print('</span>\
                  </div>\
                </div>\
              </div>\
\
              <div class="col-md-6 col-sm-6 modal-padding-lrt-none btn-wrap-mobile no-padding">\
                <div class="individual-days-day">\
                  <div class="individual-days-checkbox">\
                    <input id="parental-chk-addDay6" class="checkbox checkbox-unchecked show-hide-pw" data-id="6" type="checkbox">\
                    <label for="parental-chk-addDay6"></label>\
                  </div>\
                  <div class="individual-days-day-wrap">\
                    <span>');  ngx.print(T"Saturday"); ngx.print('</span>\
                  </div>\
                </div>\
\
                <div class="individual-days-day">\
                  <div class="individual-days-checkbox">\
                    <input id="parental-chk-addDay7" class="checkbox checkbox-unchecked show-hide-pw" data-id="7" type="checkbox">\
                    <label for="parental-chk-addDay7"></label>\
                  </div>\
                  <div class="individual-days-day-wrap">\
                    <span>');  ngx.print(T"Sunday"); ngx.print('</span>\
                  </div>\
                </div>\
              </div>\
            </div>\
          </div>\
          <div class="vdf-row clearboth">\
            <div class="left">\
              <label for="inputPassword2">');  ngx.print(T"Time"); ngx.print('</label>\
            </div>\
			<div class="right">\
				<div class="halfWidth no-important no-padding-left-right from-to-textbox" id="parental-div-addStart">\
					<span>');  ngx.print(T"From"); ngx.print('</span> <input maxlength="5" id="parental-txt-addStartTime" class="max5 max5-range parent-max5 time" placeholder="HH:MM" type="text" />\
				</div>\
				<div class="halfWidth no-important no-padding-left-right from-to-textbox" id="parental-div-addStop">\
					<span>');  ngx.print(T"To"); ngx.print('</span> <input maxlength="5" id="parental-txt-addEndTime" class="max5 max5-range parent-max5 time" placeholder="HH:MM" type="text" />\
				</div>\
			</div>\
          </div>\
\
		  </div>\
          <div class="form-group">\
            <div class="col-sm-12">\
              <div class="modal-footer">\
                <input id="parental-btn-newSave" class="button button-apply save mob-button-width" value="');  ngx.print(T"Apply"); ngx.print('" data-dismiss="modal" type="button" />\
                <input class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" data-dismiss="modal" value="');  ngx.print(T"Cancel"); ngx.print('" type="button" id="parental-btn-newCancel" />\
              </div>\
            </div>\
          </div>\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
<script src="js/global.js"></script>\
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
<script src="js/parental-control.js"></script>\
'); 