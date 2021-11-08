local setmetatable = setmetatable
local format, gsub, gmatch = string.format, string.gsub, string.gmatch
local untaint = string.untaint
local time = os.time
local dm = require("datamodel")
local content_helper = require("web.content_helper")
local api = require("fwapihelper")

local cl_path = "rpc.mmpbx.calllog.info."

-- timedate: string, the format is "yyyy-mm-dd hh:mm:ss"
local function get_seconds(timedate)
  local t = {}
  t.year, t.month, t.day, t.hour, t.min, t.sec = timedate:match("(%d+)-(%d+)-(%d+)%s+(%d+):(%d+):(%d+)")
  if t.day then
    return time(t)
  end
  return 0
end

local CallLog = {
  id = "CalllogID",
  phone =  "Remoteparty",
  date = "date",
  type = "type",
  duration = "duration",
}

local function get_voice_log()
  local data = {
    voice_log_available = "uci.system.config.iad_function",
  }
  content_helper.getExactContent(data)
  local logs = api.GetObjects(cl_path, "-startTime")
  for k,v in ipairs(logs) do
    v.date = untaint(v.startTime):gsub(" ","T")
    v.type = "received"
    if v.Direction == "2" then
      v.type = "done"
    else
      if v.connectedTime == "0" then
        v.type = "lost"
      end
    end
    local start = get_seconds(untaint(v.connectedTime))
    if start == 0 then
      v.duration = 0
    else
      local stop = get_seconds(untaint(v.endTime))
      if stop == 0 then
        stop = time()
      else
        v.duration = stop - start
      end
    end

    for key,item in pairs(CallLog) do
      local path = format("log_%d_%s", k-1, key)
      data[path] = v[item]
    end
  end
  data["total_num"] = #logs
  data["voice_log"] = "end"
  return data
end


local service_voice_log_list =
{
  name = "voice_log",
  get  = get_voice_log,
}

local service_voice_log_del =
{
  name = "voice_log_del",
  set = function(args)
    local id = untaint(args.id)
    for i in id:gmatch("%d+") do
      local path = format("%s@%s.", cl_path, i)
      dm.del(path)
    end
    return true
  end
}

register(service_voice_log_list)
register(service_voice_log_del)
