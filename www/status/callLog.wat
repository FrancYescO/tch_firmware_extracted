local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local setmetatable = setmetatable
local string = string
local format, gsub, gmatch = string.format, string.gsub, string.gmatch
local basepath = "rpc.mmpbx.calllog.info."

local logTable = {}
local modf = math.modf
local function updateDuration (time)
  local days = modf(time /86400)
  local hours = modf(time / 3600)-(days * 24)
  local minutes = modf(time /60) - (days * 1440) - (hours * 60)
  local seconds = time
  return format("%02d", seconds)
end

local time_t = {}
local function convert2Sec(value)
  value = string.untaint(value)
  time_t.year, time_t.month, time_t.day, time_t.hour, time_t.min, time_t.sec = value:match("(%d+)-(%d+)-(%d+)%s+(%d+):(%d+):(%d+)")
  if time_t.year then
    return os.time(time_t)
  end
  return 0
end

local function getCallLogTable()
  local calllog_data = {}
  logTable = content_helper.convertResultToObject(basepath .. "@", proxy.get(basepath), "-startTime")
  calllog_data["total_num"] = tostring(#logTable)
  calllog_data["voice_log_available"] = #logTable ~= 0 and "1" or "0"
  if proxy.get("uci.system.config.iad_function")[1].value == "1" then
    calllog_data["voice_log_available"] = "1"
  end
  for k,v in ipairs(logTable) do
    calllog_data["log_"..(k-1).."_id"] = v.paramindex
    calllog_data["log_"..(k-1).."_date"] = gsub(v.startTime, " ", "T")
    calllog_data["log_"..(k-1).."_duration"] = v.connectedTime
    calllog_data["log_"..(k-1).."_phone"] =  v.Remoteparty

    if v.connectedTime ~= "0" then
      local connectedTime = convert2Sec(v.connectedTime)
      if v.endTime ~= '0' then
        local endTime = convert2Sec(v.endTime)
        calllog_data["log_"..(k-1).."_duration"] = updateDuration(endTime - connectedTime)
      else
        calllog_data["log_"..(k-1).."_duration"] = updateDuration(os.time() - connectedTime)
      end
    end

    if v.Direction == "2" then
        calllog_data["log_"..(k-1).."_type"] = "done"
    else
      if v.connectedTime == "0" then
        calllog_data["log_"..(k-1).."_type"] = "lost"
      else
        calllog_data["log_"..(k-1).."_type"] = "received"
      end
    end
  end
  calllog_data["voice_log"] = "end"
  return calllog_data
end

local service_voice_log_list =
{
  name = "voice_log",
  get  = getCallLogTable,
}

local service_voice_log_del =
{
  name = "voice_log_del",
}

-- Delete call log based on the log_id
service_voice_log_del.set = function(args)
  if(args == nil or num == 0) then
    return nil, "Invalid parameters in voice log set"
  end
  local id={}
  local num = tonumber(args["total_num"])
  for i in string.gmatch(args["id"], "%d+") do
    id[#id + 1] = tonumber(i)
  end
  if #id ~= num or #id > num  then
    return nil, "total_num not equals number of id "
  end
  for k,v in pairs(id) do
    local path = basepath.."@"..v.."."
    proxy.del(path)
  end
  return true
end

register(service_voice_log_list)
register(service_voice_log_del)
