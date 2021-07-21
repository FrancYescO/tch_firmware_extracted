--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local parental_helper = require("parental_helper")
local proxy = require("datamodel")
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "Wireless", "tod")
local variantHelperWireless = post_helper.getVariant(variant_helper, "Wireless", "wireless")
local ngx = ngx
local string, table = string, table
local concat, insert = table.concat, table.insert
local ipairs = ipairs
local tonumber = tonumber
local match, gmatch, format, untaint = string.match, string.gmatch, string.format, string.untaint
local tod = parental_helper.getTodwifi()
local tod_columns = tod.columns
local radioNum = tod.radionum
local untaint_mt = require("web.taint").untaint_mt
local session = ngx.ctx.session
local validateTime = post_helper.validateTime
local validDays = post_helper.getValidateInEnumSelect(tod.days)
local validateBoolean = post_helper.validateBoolean
local validMode = post_helper.getValidateInEnumSelect({{"on"}, {"off"}})
local optionallyValidate = post_helper.getOptionalValidation
local getRandomKey = post_helper.getRandomKey


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

local ap_status_map = setmetatable({
  ["0"] = T"Off",
  ["1"] = T"On"
}, untaint_mt)

local tod_timer_path = "uci.tod.timer."
local tod_action_path = "uci.tod.action."
local tod_wifitod_path = "uci.tod.wifitod."
local tod_ap_path = "uci.tod.ap."
local tod_helpmsg = ""

-- validates days (Mon...Sun)
-- @param #table value have the value of corresponding key
-- @return #boolean or nil+error message
local function validateWeekdays(value)
  if not value then
    return nil, T"Invalid day"
  end
  for _, days in ipairs(value) do
    if not validDays(days) then
      return nil,  T"Invalid day"
    end
  end
  return true
end

local tod_options = {
  tableid     = "tod",
  createMsg   = T"Add New Rule",
  canAdd      = true,
  canDelete   = true,
  canApply    = true,
  canEdit     = true,
  objectName  = "action"..getRandomKey(),
  addNamedObject  = true
}
local basepath = post_helper.getVariantValue(variantHelper, "todPath") and "wifitod." or "action."
tod_options["basepath"] = "uci.tod.".. basepath

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

  if post_helper.getVariantValue(variantHelper, "ssidBasedTod") then
    todData["ssid"] = postcontent.ssid
  end
  local success, errmsg = content_helper.validateObject(todData, todValidations)
  if not success then
    return nil, errmsg
  end

  if post_helper.getVariantValue(variantHelper, "todTime") then
    if postcontent.start_time >= postcontent.stop_time then
       return nil, T"Stop time should be greater Start time."
    end
  end

  -- day/time overlap validation
  for indexVal, days in ipairs(timer_data) do
    if indexVal ~= postcontent.index then
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
  if post_helper.getVariantValue(variantHelper, "onAdd") then
    if onModify or onActive then
      index = success:match("wifitod(.+)")
    end
  end
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
    if post_helper.getVariantValue(variantHelper, "onAdd") then
      proxy.add(tod_ap_path, "ap"..index)
    else
      proxy.add(tod_wifitod_path .. "@wifitod"..index..".ap.")
      proxy.add(tod_ap_path, "ap0"..index)
      proxy.add(tod_ap_path, "ap1"..index)
    end
  end

  if not post_helper.getVariantValue(variantHelper, "todTime") and content.start_time >= content.stop_time then
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
  if post_helper.getVariantValue(variantHelper, "onAdd") then
    setObject[format("%s@timer%s.name", tod_timer_path, index)] = "wifitod"
    setObject[format("%s@wifitod%s.ap.@1.value", tod_wifitod_path, index)] = "ap"..index
    setObject[format("%s@ap%s.state", tod_ap_path, index)] = content.mode == "on" and "1" or "0"
    -- Getting available list of SSID's
    local radioList = {}
    local radioVal = {}
    local apVal = {}
    local wlIntf = {}
    local ssidMainList = {}
    local wifiMainIntf = {}
    local wifiIntf = proxy.get("uci.wireless.wifi-iface.") or ""
    wifiIntf = content_helper.convertResultToObject("uci.wireless.wifi-iface.", wifiIntf)

    -- Getting list of WLAN Main interfaces and SSID's only except guest network
    for indexVal, intf in pairs(wifiIntf) do
      if not match(wifiIntf[indexVal].paramindex, "_(%S+)") then
        wlIntf[#wlIntf + 1] = string.match(wifiIntf[indexVal].paramindex, "^@(%S+)")
        radioList[#radioList + 1] = intf.device
        radioVal[#radioVal + 1] = string.match(radioList[indexVal], "radio[_]?(%w+)")
        apVal[#apVal + 1] = parental_helper.findMatchingAP(wlIntf[indexVal])
        radioVal[indexVal] = radioNum[radioVal[indexVal]]
        ssidMainList[#ssidMainList + 1] = {format("%s-%s", intf.ssid, radioVal[indexVal])}
        wifiMainIntf[#wifiMainIntf + 1] = wifiIntf[indexVal]
      end
    end

    -- Setting the config option for ap and ssid
    for indexVal, intf in ipairs(wifiMainIntf) do
      if content.ssid == "all" then
        setObject[format("%s@ap%s.ap", tod_ap_path, index)] = "all"
        setObject[format("%s@ap%s.ssid", tod_ap_path, index)] = content.ssid
      elseif content.ssid == ssidMainList[indexVal][1] then
        local iface = match(intf.paramindex, "^@(%S+)")
        local ap_val = parental_helper.findMatchingAP(iface)
        setObject[format("%s@ap%s.ap", tod_ap_path, index)] = ap_val
        setObject[format("%s@ap%s.ssid", tod_ap_path, index)] = ssidMainList[indexVal][1]
      end
    end
  else
    setObject[format("%s@wifitod%s.ap.@1.value", tod_wifitod_path, index)] = "ap0"..index
    setObject[format("%s@wifitod%s.ap.@2.value", tod_wifitod_path, index)] = "ap1"..index
    setObject[format("%s@ap0%s.state", tod_ap_path, index)] = content.mode == "on" and "1" or "0"
    setObject[format("%s@ap0%s.ap", tod_ap_path, index)] = "ap0"
    setObject[format("%s@ap1%s.state", tod_ap_path, index)] = content.mode == "on" and "1" or "0"
    setObject[format("%s@ap1%s.ap", tod_ap_path, index)] = "ap1"
  end
  proxy.set(setObject)
  return true
end

-- function to delete the tod rule
-- @param #success is the index to be deleted
local function onDelete(success)
  if post_helper.getVariantValue(variantHelper, "onDelete") then
    local index = success:match("wifitod(.+)")
    --As per the TOD functionality Ap state will revert only when the remaining configuration is present in the tod config.
    --Only the timer list value defined in the action section has been modified as empty and the timer section has been deleted in the config.
    proxy.set(format("%s@action%s.timers.@1.value", tod_action_path, index),"")
    proxy.del(format("uci.tod.timer.@timer%s.", index))
  else
    local index = success:match("action(.+)")
    proxy.del(format("uci.tod.ap.@ap0%s.", index))
    proxy.del(format("uci.tod.ap.@ap1%s.", index))
    proxy.del(format("uci.tod.action.@action%s.", index))
    proxy.del(format("uci.tod.timer.@timer%s.", index))
    proxy.del(format("uci.tod.wifitod.@wifitod%s.", index))
  end
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
local action_list = content_helper.convertResultToObject(tod_action_path, proxy.get(tod_action_path))
local ap_list = content_helper.convertResultToObject(tod_ap_path, proxy.get(tod_ap_path))

if post_helper.getVariantValue(variantHelper, "ssidBasedTod") then
  local dnd_val = 0
  local newlist_index = {}
  for  index, action in ipairs(action_list) do
    local param_index = action["paramindex"]:match("action(.+)")
    dnd_val = action["paramindex"]:match("dnd(.+)") and dnd_val+1 or dnd_val
    if param_index then
      if action["timers.@1.value"] == "" then
        newlist_index[#newlist_index + 1] = index-dnd_val
      end
    end
  end

  --Section to remove the TOD rule displaying in GUI which doesn't have timer section in config.

  for index = #newlist_index , 1 , -1 do
    table.remove(tod_index, newlist_index[index])
    table.remove(ap_list, newlist_index[index])
    table.remove(tod_data, newlist_index[index])
  end
end

local tablesessionindexes = tod_options.tableid .. ".allowedindexes"
session:store(tablesessionindexes, tod_index)

local timer_list = content_helper.convertResultToObject(tod_timer_path, proxy.get(tod_timer_path))
local wifitod_list = content_helper.convertResultToObject(tod_wifitod_path, proxy.get(tod_wifitod_path))
local timer_data = {}
local wifi_action = {}
local wifitod_timer = {}
if post_helper.getVariantValue(variantHelper, "ssidBasedTod") then
  --To filter out timer section created by WiFi Tod rule
  for index, timer in ipairs(timer_list) do
    if timer_list[index].name == "" or timer_list[index].name == "wifitod" then
      wifitod_timer[#wifitod_timer+1] = timer_list[index]
    end
  end

  --To filter out action section created by ringing schedule rule
  for index, action in ipairs(action_list) do
    if action_list[index].script == "wifitodscript" then
      wifi_action[#wifi_action+1] = action_list[index]
    end
  end
  timer_list = wifitod_timer
end

for index, rule in ipairs(tod_data) do
  local days, start_time = timer_list[index].start_time:match("^(.-):(.+)$")
  rule[3] = start_time -- start_time
  rule[4] = timer_list[index].stop_time:match("^.-:(.+)$") -- stop_time
  rule[5] = ap_status_map[ap_list[index].state] -- apStatus
  rule[6] = {} -- days
  for day in gmatch(days, "[^,]+") do
    insert(rule[6], untaint(day))
  end
  if post_helper.getVariantValue(variantHelper, "ssidBasedTod") then
    rule[1] = wifi_action[index].enabled -- status
    rule[2] = ap_list[index].ssid -- ssid
    rule[7] = {
      [1] = rule[1], -- status
    [2] = ap_list[index].state == "1" and "on" or "off", -- apStatus
    [3] = rule[2], -- ssid
    [4] = rule[3], -- start_time
    [5] = rule[4], -- stop_time
    [6] = rule[6] -- days
    }
  else
    rule[1] = rule[1] -- status
    rule[2] = "all" -- ap   custo NG-155433/GHG-3810
    -- Sub Columns
    rule[7] = {
      [1] = rule[1], -- status
      [2] = ap_list[index].state == "1" and "on" or "off", -- apStatus
      [4] = rule[3], -- start_time
      [5] = rule[4], -- stop_time
      [6] = rule[6] -- days
    }
  end
  timer_data[index] = {
    start_time = rule[3],
    stop_time = rule[4],
    days = rule[6]
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
    ');  if multiap_enabled then
      local multiap_warning = {
        alert = {
          class = "alert-warning monitor-default-show"
        }
      }
      ngx.print(ui_helper.createAlertBlock(T"Disabling wireless will disable the EasyMesh network", multiap_warning))
    end  ngx.print('\
    ');  ngx.print(ui_helper.createTable(tod_columns, tod_data, tod_options, nil, tod_helpmsg)); ngx.print('\
    ');  if ngx.var.request_method == "POST" and (ngx.req.get_post_args().action == "TABLE-NEW" or ngx.req.get_post_args().action == "TABLE-EDIT") then  ngx.print('\
      <script type="text/javascript">\
        var warning = \'<div class="control-group"><div style="padding-top: 12px;" class="controls"><span class="alert">');  ngx.print( T"The Gateway will block/allow all the time if none of the days are selected" ); ngx.print('</span></div></div>\';\
        $(\'#stoptime\').parent().parent().after(warning);\
      </script>\
    ');  end  ngx.print('\
  </form>\
</div>\
\
<script>\
  var ssidBasedTod = ');  ngx.print(post_helper.getVariantValue(variantHelper, "ssidBasedTod")); ngx.print(';\
</script>\
<script src="/js/tod_wireless-modal.js"></script>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 