-- custo NG-155433/GHG-3810/NG-155973

local uc = require("uciconv")
local oldConfig = uc.uci('old')
local newConfig = uc.uci('new')

oldConfig:foreach("tod", "host", function(s)
  newConfig:set('tod', s[".name"], "host")
  for k,v in pairs(s) do
    if not k:find("^%.") then
      newConfig:set("tod", s[".name"], k, v)
    end
  end
end)

oldConfig:foreach("tod", "action", function(s)
  local obj = s.object or ""
  -- Extract the hash from the s[".name"] and that unique hash should be used
  -- in all the sections(timer, ap, wifitod, action) for the particular rule.
  local unique = s[".name"]:match("^wifitodaction(.*)") or ""
  local timername = s.timer
  -- If list timers is present instead of option timer in action section
  if not timername then
    unique = s[".name"]:match("action(.*)") or ""
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
  newConfig:set("tod", "wifitod"..unique, "ap", {"ap0"..unique, "ap1"..unique}) -- custo NG-155433/GHG-3810

  -- setting wifi ap state before time sync.
  local sec_name = s[".name"]
  if next(s.activedaytime) then
    local orig_state_0 = oldConfig:get("tod", "ap0" .. unique, sec_name .. "_orig_state")
    local orig_state_1 = oldConfig:get("tod", "ap1".. unique, sec_name .. "_orig_state")
    newConfig:set("wireless", "ap0", "state", orig_state_0)
    newConfig:set("wireless", "ap1", "state", orig_state_1)
  end
  newConfig:commit("wireless")

  -- Creating the new ap section with the old config.
  newConfig:set('tod', "ap0"..unique, "ap")            -- custo NG-155433/GHG-3810/NG-155973
  local state = oldConfig:get("tod", ap[1], "state")
  newConfig:set("tod", "ap0"..unique, "ap", "ap0")     -- custo NG-155433/GHG-3810
  newConfig:set("tod", "ap0"..unique, "state", state)  -- custo NG-155433/GHG-3810
  newConfig:set('tod', "ap1"..unique, "ap")            -- custo NG-155433/GHG-3810
  newConfig:set("tod", "ap1"..unique, "ap", "ap1")     -- custo NG-155433/GHG-3810
  newConfig:set("tod", "ap1"..unique, "state", state)  -- custo NG-155433/GHG-3810

  -- Creating the new timer section with the old config.
  newConfig:set("tod", newtimer, "timer")
  local start_time =  oldConfig:get("tod", timername, "start_time")
  local stop_time =  oldConfig:get("tod", timername, "stop_time")
  local name = oldConfig:get("tod", timername, "name")
  if name then
    newConfig:set("tod", newtimer, "name", name)
  end
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
