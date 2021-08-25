<%
-- Enable localization
gettext.textdomain('webui-voice')

local proxy = require ("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local untaint_mt = require("web.taint").untaint_mt
local setmetatable = setmetatable
local string = string
local session = ngx.ctx.session
local role = session:getrole()
local format, gsub, gmatch = string.format, string.gsub, string.gmatch

-- This code will be triggered by post of the button
local post_content
if ngx.var.request_method == "POST" then
  post_content = ngx.req.get_post_args()
  if post_content["operation"] == "RESET" then
    proxy.set("rpc.mmpbx.calllog.clear", "true")
  end
end

local calllog_columns = {
  {
    header = T"Time",
    name = "DateTime"
  },
  {
    header = T"Call Type",
    name = "CallType"
  },
  {
    header = T"Local Number",
    name = "LocalNumber"
  },
  {
    header =  T"Remote Number",
    name = "RemoteNumber"
  },
  {
    header = T"Duration",
    name = "Duration"
  },
  {
    header = T"Port",
    name = "DeviceName"
  }
}

local calllog_options = {
  tableid = "calllog",
  canApply = false,
  canEdit = false,
  canAdd = false,
  canDelete = false
}

-- Identify log table column number
local lcns = {
  ["DateTime"] = 1,
  ["CallType"] = 2,
  ["LocalNumber"] = 3,
  ["RemoteNumber"] = 4,
  ["Duration"] = 5,
  ["DeviceName"] = 6
}

local incoming_success_str = T"Incoming Successful"
local incoming_missed_str = T"Incoming Missed"
local outgoing_success_str =  T"Outgoing Successful"
local outgoing_failed_str = T"Outgoing Failed"

local stats_columns_device = {
  {
    header = T"Device Name",
    name = "deviceName"
  },
  {
    header = incoming_success_str,
    name = "incoming_success"
  },
  {
    header = incoming_missed_str,
    name = "incoming_missed"
  },
  {
    header = outgoing_success_str,
    name = "outgoing_success"
  },
  {
    header = outgoing_failed_str,
    name = "outgoing_failed"
  }
}

local stats_columns_profile = {
  {
    header = T"Profile Number",
    name = "localNumber"
  },
  {
    header = incoming_success_str,
    name = "incoming_success"
  },
  {
    header = incoming_missed_str,
    name = "incoming_missed"
  },
  {
    header = outgoing_success_str,
    name = "outgoing_success"
  },
  {
    header = outgoing_failed_str,
    name = "outgoing_failed"
  }
}

local stats_options = {
  tableid = "stats",
  canApply = false,
  canEdit = false,
  canAdd = false,
  canDelete = false
}

-- Identify stats table column number
local scns = {
  ["incoming_success"] = 2,
  ["incoming_missed"] = 3,
  ["outgoing_success"] = 4,
  ["outgoing_failed"] = 5
}

local modf = math.modf
local function updateDuration (time)
  local days = modf(time /86400)
  local hours = modf(time / 3600)-(days * 24)
  local minutes = modf(time /60) - (days * 1440) - (hours * 60)
  local seconds = time - (minutes * 60) - (hours * 3600) - (days * 86400)
  if days == 0 then
    return format("%02d:%02d:%02ds", hours, minutes, seconds)
  else
    return format("%ddays, %02d:%02d:%02ds", days, hours, minutes, seconds)
  end
end

local dev_config = {
  ["fxs"] = "mmpbxbrcmfxsdev",
  ["dect"] = "mmpbxbrcmdectdev",
  ["sipdev"] = "mmpbxrvsipdev"
}


local profile_config = {
  ["sipnet"] = "mmpbxrvsipnet"
}

local function getDeviceFriendlyNames()
  local devpattern = "([^%._@]+_dev_%d+)"
  local results, dev
  local mapTable, device_stats_data, dev_index = {}, {}, {}
  for _, devConfigValue in pairs(dev_config) do
    results = proxy.get("uci." .. devConfigValue .. ".device.")
    if results then
      for _, resultValue in ipairs(results) do
        if resultValue.param == "user_friendly_name" then
          dev = resultValue.path:match(devpattern)
          if dev then
            mapTable[dev] = resultValue.value
            device_stats_data[#device_stats_data+1] = { dev, 0, 0, 0, 0 }
            dev_index[dev] = #device_stats_data
          end
        end
      end
    end
  end
  return setmetatable(mapTable, untaint_mt), device_stats_data, setmetatable(dev_index, untaint_mt)
end

local function getProfileFriendlyNames()
  local profilepattern = "([^%._@]+_profile_%d+)"
  local results, profile
  local mapTable1, profile_stats_data, profile_index = {}, {}, {}
  for _, profileValue in pairs(profile_config) do
    results = proxy.get("uci." .. profileValue .. ".profile.")
    if results then
      for _, profileResult in ipairs(results) do
        if profileResult.param == "uri" then
          profile = profileResult.path:match(profilepattern)
	  mapTable1[profile] = profileResult.value
          profile_stats_data[#profile_stats_data+1] = {profile, 0, 0, 0, 0}
          profile_index[profile] = #profile_stats_data
        end
      end
    end
  end
  return setmetatable(mapTable1, untaint_mt), profile_stats_data, setmetatable(profile_index, untaint_mt)
end

local mapTable, device_stats_data, dev_index = getDeviceFriendlyNames()
local mapTable1, profile_stats_data, profile_index = getProfileFriendlyNames()

local basepath = "rpc.mmpbx.calllog.info."
local logTable = content_helper.convertResultToObject(basepath .. "@", proxy.get(basepath))

table.sort(logTable, function(a, b)
  if tonumber(a.paramindex) < tonumber(b.paramindex) then
    return false
  else
    return true
  end
end)
local calllog_data = {}

local total = {
  [1] = T"Total",
  [2] = 0,
  [3] = 0,
  [4] = 0,
  [5] = 0
}

local time_t = {}
local function convert2Sec(value)
  value = string.untaint(value)
  time_t.year, time_t.month, time_t.day, time_t.hour, time_t.min, time_t.sec = value:match("(%d+)-(%d+)-(%d+)%s+(%d+):(%d+):(%d+)")
  if time_t.year then
    return os.time(time_t)
  end
  return 0
end

-- It will check the given URI/NUMBER is present in config.
-- Return true if it is present, false if it is deleted.
local function isLocalPartyValid(localParty)
  for _, uri in pairs(mapTable1) do
    if uri == localParty then
      return true
    end
  end
  return false
end

for log_table, logValue in ipairs(logTable) do
  local data = {}
  if isLocalPartyValid(logValue.Localparty) then
    data[lcns.LocalNumber] = logValue.Localparty
  else
    data[lcns.LocalNumber] = "NA"
  end
  data[lcns.RemoteNumber] = logValue.Remoteparty
  data[lcns.DateTime] = logValue.startTime
  data[lcns.Duration] = logValue.connectedTime
  if logValue.connectedTime ~= "0" then
    local connectedTime = convert2Sec(logValue.connectedTime)
    if logValue.endTime ~= '0' then
      local endTime = convert2Sec(logValue.endTime)
      data[lcns.Duration] = updateDuration(endTime - connectedTime)
    else
      data[lcns.Duration] = updateDuration(os.time() - connectedTime)
    end
  else
    data[lcns.Duration] = "00:00:00"
  end
  data[lcns.DeviceName] = gsub(logValue.deviceName, "([^%,]+)", mapTable)
  for deviceName in gmatch(logValue.deviceName, "([^%,]+)") do
    if logValue.Direction == "2" then
      data[lcns.CallType] = logValue.connectedTime == "0" and outgoing_failed_str or outgoing_success_str
    else
      data[lcns.CallType] = logValue.connectedTime == "0" and incoming_missed_str or incoming_success_str
    end
  end
  if logValue.deviceName == "" then
    data[lcns.DeviceName] = "-"
    local reason = logValue.terminationReason
    if reason == "NO_DEVICE_MAPPED" or reason == "NO_DEVICE_AVAILABLE" then
      data[lcns.CallType] = incoming_missed_str
    end
    if reason == "CALL_FORWARDING_UNCONDITIONAL" or reason == "CALL_FORWARDING_ON_BUSY_SUBSCRIBER" then
      data[lcns.CallType] = incoming_success_str
    end
    if reason == "DO_NOT_DISTURB" then
      data[lcns.CallType] = incoming_missed_str
    end
  end
  calllog_data[log_table] = data
end

basepath = "rpc.mmpbx.devicestatistics."
local devStatsTable = content_helper.convertResultToObject(basepath .. "@", proxy.get(basepath))
local stats

for _, devStatsValue in ipairs(devStatsTable) do
  if dev_index[devStatsValue.device] then
    stats = device_stats_data[dev_index[devStatsValue.device]]
    stats[scns["incoming_missed"]] = tonumber(devStatsValue.incomingCallsFailed)
    stats[scns["incoming_success"]] = tonumber(devStatsValue.incomingCallsConnected)
    stats[scns["outgoing_failed"]] = tonumber(devStatsValue.outgoingCallsFailed)
    stats[scns["outgoing_success"]] = tonumber(devStatsValue.outgoingCallsConnected)
  end
end

basepath = "rpc.mmpbx.profilestatistics."
local profileStatsTable = content_helper.convertResultToObject(basepath .. "@", proxy.get(basepath))

for _, profileStatsTableValue in ipairs(profileStatsTable) do
  local profile
  local profileNumber = content_helper.convertResultToObject("rpc.mmpbx.sip_profile.", proxy.get("rpc.mmpbx.sip_profile."))
  for _, profile_number in pairs(profileNumber) do
    if profile_number.uri == profileStatsTableValue.profile then
      profile = string.sub(profile_number.paramindex, 2)
    end
  end
  if profile_index[profile] then
    stats = profile_stats_data[profile_index[profile]]
    stats[scns["incoming_missed"]] = tonumber(profileStatsTableValue.IncomingCallsFailed)
    stats[scns["incoming_success"]] = tonumber(profileStatsTableValue.IncomingCallsConnected)
    stats[scns["outgoing_failed"]] = tonumber(profileStatsTableValue.OutgoingCallsFailed)
    stats[scns["outgoing_success"]] = tonumber(profileStatsTableValue.OutgoingCallsConnected)

    total[scns["incoming_missed"]] = total[scns["incoming_missed"]] + stats[scns["incoming_missed"]]
    total[scns["incoming_success"]] = total[scns["incoming_success"]] + stats[scns["incoming_success"]]
    total[scns["outgoing_failed"]] = total[scns["outgoing_failed"]] + stats[scns["outgoing_failed"]]
    total[scns["outgoing_success"]] = total[scns["outgoing_success"]] + stats[scns["outgoing_success"]]
  end
end

local order = {
  f = 1,
  d = 2,
  s = 3
}

table.sort(device_stats_data, function(a, b)
  local order_a = order[a[1]:sub(1,1)]
  local order_b = order[b[1]:sub(1,1)]
  if order_a < order_b or (order_a == order_b and a[1] < b[1]) then
    return true
  else
    return false
  end
end)

for _, deviceStatsValue in pairs(device_stats_data) do
  deviceStatsValue[1] = mapTable[deviceStatsValue[1]] or deviceStatsValue[1]
end

table.sort(profile_stats_data, function(a, b)
  local profilepattern = "(profile_(%d+))"
  local _, a_num = a[1]:match(profilepattern)
  local _, b_num = b[1]:match(profilepattern)
  if tonumber(a_num) < tonumber(b_num) then
    return true
  else
    return false
  end
end)

for _, profileStatsValue in pairs(profile_stats_data) do
  profileStatsValue[1] = mapTable1[profileStatsValue[1]] or profileStatsValue[1]
end

--add total row at end
profile_stats_data[#profile_stats_data + 1] = total

-- clear call log button
local clear_call_log = {
  controls = {
    class = "clear_call_log"
  },
  button = {
    ["data-name"] = "operation",
    ["data-value"] = "RESET"
  }
}

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
  uri = uri .. "?" .. ngx.var.args
end
%>

<%= ui_helper.createHeader(T"Telephony", false, true) %>
<div class = "modal-body update">
  <%
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-voice.lp")
  %>
  <form class = "form-horizontal" method = "post" action = "<%= uri %>">
    <fieldset>
      <legend><%=  T"Call Log" %></legend>
      <%= ui_helper.createTable(calllog_columns, calllog_data, calllog_options) %>
    </fieldset>
    <fieldset>
      <center>
        <%= ui_helper.createSimpleButton(T"Clear call logs", "icon-bolt", clear_call_log)%>
      </center>
      <fieldset>
        <legend><%= T"Call Statistics" %></legend>
        <%= ui_helper.createTable(stats_columns_device, device_stats_data, stats_options) %>
        <%= ui_helper.createTable(stats_columns_profile, profile_stats_data, stats_options) %>
      </fieldset>
    </fiedset>
   </form>
</div>
<%= ui_helper.createFooter() %>
