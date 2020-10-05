local content_helper = require("web.content_helper")
local dm = require("datamodel")

local open = io.open
local format = string.format
local match = string.match
local tonumber = tonumber

local var_log = "/etc/speedlog"

local speedlog_read = {
  name = "speedLog_read",
  get = function()
    local data = {}
    local count = 0
    local fd = open(var_log, "r")
    if fd then
      for l in fd:lines() do
        count = count + 1
        local time, us, ds = match(l, "^(.*) ([0-9]*) ([0-9]*)$")
        local timekey = format("date_info_%d", count)
        local uskey = format("linerate_us_%d", count)
        local dskey = format("linerate_ds_%d", count)
        data[timekey] = time
        data[uskey] = us
        data[dskey] = ds
      end
      fd:close()
    end
    data.counter = count
    data.speedLog_read = "end"
    return data
  end,
}
register(speedlog_read)

local autopath = "uci.web.connectionmgr.@speedlog.auto"
local timepath = "uci.web.connectionmgr.@speedlog.time"

local speedlog_set = {
  name = "speedLog_set",
  get = function()
    local data = {}
    local uciconf = {
      auto = autopath,
      time = timepath,
    }
    content_helper.getExactContent(uciconf)
    data.speedLog_enable = uciconf.auto or "0"
    data.speedLog_time = uciconf.time or "9999"
    data.speedLog_freq = "day"
    data.speedLog_fri = "0"
    data.speedLog_mon = "0"
    data.speedLog_sat = "0"
    data.speedLog_sun = "0"
    data.speedLog_thu = "0"
    data.speedLog_tue = "0"
    data.speedLog_wed = "0"
    data.speedLog_set = "end"
    return data
  end,
  set = function(args)
    local paths = {}
    paths[autopath] = args and args.speedLog_enable or "0"
    paths[timepath] = args and args.speedLog_time or "9999"
    dm.set(paths)
    dm.apply()
    return true
  end,
}
register(speedlog_set)

local speedlog_trigger = {
  name = "speedLog_trigger",
  set = function(args)
    if args and args.activate == "1" then
      dm.set("uci.web.connectionmgr.@speedlog.trigger", args.activate)
      dm.apply()
    end
    return true
  end,
}
register(speedlog_trigger)

