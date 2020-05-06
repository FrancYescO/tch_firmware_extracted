local M = {}
local config = "tod"
local sectiontype = "host"

function do_action(runtime, actionname, object, start)
  local logger = runtime.logger
  local cursor = runtime.uci.cursor()
  local activate, mac
  if object then
    activate, mac = object:match("^(%S+)|(%S+)$")
  end

  if not start then
    activate = activate == "1" and "0" or "1"
  end

  if mac and activate and actionname then
    local routinename, isroutine = actionname:gsub("online", "routine" )
    local hasroutine = cursor:get(config, routinename, "activedaytime")
    local section
    local enabled = "0"
    local reloadflag = false
    cursor:foreach(config, sectiontype, function(s)
      if s["id"] == mac then
        section = s['.name']
        enabled = s['enabled']
        return false
      end
    end)
    if not section then
      section = cursor:add(config, sectiontype)
      cursor:set(config, section, "id", mac)
      cursor:set(config, section, "type", 'mac')
      cursor:set(config, section, "mode", 'block')
      reloadflag = true
    end

    if enabled ~= activate and (start or isroutine or not hasroutine) then
      cursor:set(config, section, "enabled", activate)
      reloadflag = true
    end

    if reloadflag then
      cursor:commit(config)
      os.execute("/sbin/fw3 reload; sleep 1")
    end
  end
  return true
end

-- runtime is a lua table contains {ubus = conn, uci = uci, uloop = uloop, logger = logger}
-- Routine invoked when "start_time" has been reached in scheduler
-- @param #table runtime: Lua table containing contexts: {ubus = conn, uci = uci, uloop = uloop, logger = logger}
-- @param #string actionname: UCI tod "action" section name to operate on
-- @param #string object: UCI "object" or mac address of one object
-- @return #boolean true to continue with state machine, false if error encountered (causes this script to exit)
function M.start(runtime, actionname, object)
  return do_action(runtime, actionname, object, true)
end

-- Routine invoked when "stop_time" has been reached in scheduler
-- @param #table runtime: Lua table containing contexts: {ubus = conn, uci = uci, uloop = uloop, logger = logger}
-- @param #string actionname: UCI tod "action" section name to operate on
-- @param #string object: UCI "object" or mac address of an object
-- @return #boolean true to continue with state machine, false if error encountered (causes this script to exit)

function M.stop(runtime, actionname, object)
  return do_action(runtime, actionname, object, false)
end

return M
