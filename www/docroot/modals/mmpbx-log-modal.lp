<%
-- Enable localization
gettext.textdomain('webui-voice')

local proxy = require ("datamodel")
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local untaint_mt = require("web.taint").untaint_mt
local setmetatable = setmetatable
local format, gsub = string.format, string.gsub

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
        name = "DateTime",
    },
    {
        header = T"Call Type",
        name = "CallType",
    },
    {
        header = T"Profile Name",
        name = "LocalNumber",
    },
    {
        header = T"Remote Number",
        name = "RemoteNumber",
    },
    {
        header = T"Duration",
        name = "Duration",
    },
}

local calllog_options = {
    tableid = "calllog",
    canApply = false,
    canEdit = false,
    canAdd = false,
    canDelete = false,
}

-- Identify log table column number
local lcns = {
    ["DateTime"] = 1,
    ["CallType"] = 2,
    ["LocalNumber"] = 3,
    ["RemoteNumber"] = 4,
    ["Duration"] = 5,
}

local incoming_success_str = T"Incoming Successful"
local incoming_missed_str = T"Incoming Missed"
local outgoing_success_str = T"Outgoing Successful"
local outgoing_failed_str = T"Outgoing Failed"

local stats_columns = {
  {
    header = T"Profile Name",
    name = "profileName",
  },
  {
    header = incoming_success_str,
    name = "incoming_success",
  },
  {
    header = incoming_missed_str,
    name = "incoming_missed",
  },
  {
    header = outgoing_success_str,
    name = "outgoing_success",
  },
  {
    header = outgoing_failed_str,
    name = "outgoing_failed",
  },
}

local stats_options = {
    tableid = "stats",
    canApply = false,
    canEdit = false,
    canAdd = false,
    canDelete = false,
}

-- Identify stats table column number
local scns = {
    ["incoming_success"] = 2,
    ["incoming_missed"] = 3,
    ["outgoing_success"] = 4,
    ["outgoing_failed"] = 5,
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
        return format("%ddays,%02d:%02d:%02ds", days, hours, minutes, seconds)
    end
end

local function getProfileNames()
    local profilepattern = "([^%._@]+_profile_%d+)"
    local results, profile
    local mapProfileTable, stats_data, index = {}, {}, {}
    results = proxy.get("uci.mmpbxrvsipnet.profile.")
    if results then
        for _,v in ipairs(results) do
            if v.param == "uri" then
                profile = v.path:match(profilepattern)
                mapProfileTable[v.value] = profile
                local data = {}
                data[#data+1] = profile
                for k=1,4 do
                    data[#data+1] = 0
                end
                stats_data[#stats_data+1] = data
                index[v.value] = #stats_data
             end
        end
    end
    return setmetatable(mapProfileTable,untaint_mt), stats_data, setmetatable(index, untaint_mt)
end

local mapProfileTable, stats_data, index = getProfileNames()

local basepath = "rpc.mmpbx.calllog.info."
local logTable = content_helper.convertResultToObject(basepath .. "@", proxy.get(basepath))
table.sort(logTable, function(a,b)
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
    [5] = 0,
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

for k,v in ipairs(logTable) do
    local data = {}
    data[lcns.LocalNumber] = mapProfileTable[v.Localparty] or v.Localparty
    data[lcns.RemoteNumber] = v.Remoteparty
    data[lcns.DateTime] = v.startTime
    data[lcns.Duration] = v.connectedTime
    if v.connectedTime ~= "0" then
        local connectedTime = convert2Sec(v.connectedTime)
        if v.endTime ~= '0' then
            local endTime = convert2Sec(v.endTime)
            data[lcns.Duration] = updateDuration(endTime - connectedTime)
        else
            data[lcns.Duration] = updateDuration(os.time() - connectedTime)
        end
    end
    local stats
    if index[v.Localparty] then
        stats = stats_data[index[v.Localparty]]
    else
        stats = {}
        stats[#stats+1] = v.Localparty
        for k=1,4 do
            stats[#stats+1] = 0
        end
        stats_data[#stats_data+1] = stats
        index[format("%s",v.Localparty)] = #stats_data
    end
    if v.Direction == "2" then
        if v.connectedTime == "0" then
            data[lcns.CallType] = outgoing_failed_str
            if stats then
                stats[scns["outgoing_failed"]] = stats[scns["outgoing_failed"]] + 1
                total[scns["outgoing_failed"]] = total[scns["outgoing_failed"]] + 1
            end
        else
            data[lcns.CallType] = outgoing_success_str
            if stats then
                stats[scns["outgoing_success"]] = stats[scns["outgoing_success"]] + 1
                total[scns["outgoing_success"]] = total[scns["outgoing_success"]] + 1
            end
        end
    else
        if v.connectedTime == "0" then
            data[lcns.CallType] = incoming_missed_str
            if stats then
                stats[scns["incoming_missed"]] = stats[scns["incoming_missed"]] + 1
                total[scns["incoming_missed"]] = total[scns["incoming_missed"]] + 1
            end
        else
            data[lcns.CallType] = incoming_success_str
            if stats then
                stats[scns["incoming_success"]] = stats[scns["incoming_success"]] + 1
                total[scns["incoming_success"]] = total[scns["incoming_success"]] + 1
            end
        end
    end
    calllog_data[k] = data
end

table.sort(stats_data, function(a,b)
   if a[1] < b[1] then
        return true
    end
    return false
end)

stats_data[#stats_data + 1] = total

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
<div class="modal-body update">
  <%
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-voice.lp")
  %>
  <form class="form-horizontal" method="post" action="<%= uri %>">
        <fieldset>
            <legend><%= T"Call Log" %></legend>
            <%= ui_helper.createTable(calllog_columns, calllog_data, calllog_options) %>
        </fieldset>
        <fieldset>
            <center>
                <%= ui_helper.createSimpleButton(T"Clear call logs", "icon-bolt", clear_call_log)%>
            </center>
        <fieldset>
            <legend><%= T"Call Statistics" %></legend>
            <%= ui_helper.createTable(stats_columns, stats_data, stats_options) %>
        </fieldset>
        </fiedset>
   </form>
</div>
<%= ui_helper.createFooter() %>

