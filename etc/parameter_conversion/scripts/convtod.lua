local uc = require("uciconv")
local oldConfig = uc.uci('old')
local newConfig = uc.uci('new')

oldConfig:foreach("tod", "action", function(s)
  local obj = s.object or ""
  -- Extract the hash from the s[".name"] and that unique hash should be used
  -- in all the sections(timer, ap, wifitod, action) for the particular rule.
  local unique = s[".name"]:match("^wifitodaction(.*)") or ""
  local timername = s.timer
  -- If list timers is present instead of option timer in action section
  if not timername then
    unique = s[".name"]:match("^action(.*)") or ""
    timername = s.timers[1]
  end
  local newtimer = "timer"..unique

  -- Creating the new action section with the old config.
  local actionname = "action"..unique
  newConfig:set("tod", actionname, "action")
  -- Replace "option timer" with "list timers".
  newConfig:set('tod', actionname, "timers", {newtimer})
  newConfig:set('tod', actionname, "object", "wifitod.wifitod"..unique)
  newConfig:set('tod', actionname, "script", s.script)
  newConfig:set('tod', actionname, "enabled", s.enabled)

  -- Creating the new wifitod section with the old config.
  local ap = oldConfig:get("tod", obj:match("%.(.*)$"), "ap")
  newConfig:set("tod", "wifitod"..unique, "wifitod")
  newConfig:set("tod", "wifitod"..unique, "ap", {"ap"..unique})

  -- Creating the new ap section with the old config.
  newConfig:set('tod', "ap"..unique, "ap")
  local apname = oldConfig:get("tod", ap[1], "ap")
  local state = oldConfig:get("tod", ap[1], "state")
  newConfig:set("tod", "ap"..unique, "ap", apname)
  newConfig:set("tod", "ap"..unique, "state", state)

  -- Creating the new timer section with the old config.
  newConfig:set("tod", newtimer, "timer")
  local start_time =  oldConfig:get("tod", timername, "start_time")
  local stop_time =  oldConfig:get("tod", timername, "stop_time")
  if s.timer then
    local days = oldConfig:get("tod", timername, "weekdays")
    days = table.concat(days,",")
    newConfig:set("tod", newtimer, "start_time", days..":"..start_time[1])
    newConfig:set("tod", newtimer, "stop_time", days..":"..stop_time[1])
  else
    newConfig:set("tod", newtimer, "start_time", start_time)
    newConfig:set("tod", newtimer, "stop_time", stop_time)
  end
  newConfig:commit("tod")
end)

newConfig:commit("tod")
