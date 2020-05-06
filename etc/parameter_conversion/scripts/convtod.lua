local format = string.format
local uc = require("uciconv")
local oldConfig = uc.uci('old')
local newConfig = uc.uci('new')

local function get_routine(mac)
  local boostname = format("boost_action_routine_%s", mac)
  local stopname  = format("stop_action_routine_%s", mac)
  local boostenabled = oldConfig:get("tod", boostname, "enabled")
  local stopenabled  = oldConfig:get("tod", stopname, "enabled")
  if (boostenabled == "1" or stopenabled == "1") then
    return "1"
  else
    return "0"
  end
end

local Frequency ={
  ["Sat,Sun"] = "Weekends",
  ["Mon,Tue,Wed,Thu,Fri"] = "Working days",
  ["All"] = "Daily",
}

local function set_elements(timername)
  local frequency
  local lease
  local start
  local start_time =  oldConfig:get("tod", timername, "start_time")
  local stop_time =  oldConfig:get("tod", timername, "stop_time")
  if start_time and start_time ~= "" and stop_time and stop_time ~= "" then
    local f1, h1, m1 = start_time:match("([^:]*):(%d*):(%d*)")
    local f2, h2, m2 = stop_time:match("([^:]*):(%d*):(%d*)")
    local h, m
    if tonumber(m2) < tonumber(m1) then
      m = m2+60-m1
      h2 = h2-1
    else
      m = m2-m1
    end
    if tonumber(h2) < tonumber(h1) then
      h = h2+24-h1
    else
      h = h2-h1
    end
    frequency = Frequency[f1]
    start = format("%s:%s", h1, m1)
    lease = format("%dh %02d'", h, m)
    newConfig:set('tod', timername, "start", start)
    newConfig:set('tod', timername, "lease", lease)
    if frequency then
      newConfig:set('tod', timername, "frequency", frequency)
    else
      newConfig:set('tod', timername, "start_time", stop_time)
      newConfig:set('tod', timername, "periodic", "0")
      newConfig:delete('tod', timername, "stop_time")
      local actionname = timername:gsub("online", "action_online")
      newConfig:delete('tod', actionname, "activedaytime")
      local object = oldConfig:get("tod", actionname, "object")
      local newobject = object:gsub("%d|", "0|")
      newConfig:set('tod', actionname, "object", newobject)
    end
  end
end

oldConfig:foreach("tod", "timer", function(s)
  local flag = s[".name"]:match("^boost_.*") or s[".name"]:match("^stop_.*")
  if flag then
    local timername  = s[".name"]
    local routine = "0"
    if timername:find("routine") then
      local mac = timername:match(".*_routine_(.*)")
      routine = get_routine(mac)
    end
    newConfig:set('tod', timername, "routine", routine)
    set_elements(timername)
  end
end)

newConfig:commit("tod")
