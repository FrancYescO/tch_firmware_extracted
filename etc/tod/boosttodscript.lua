local M = {}
local config_qos = "qos"
local config_tod = "tod"
local sectiontype = "classify"

-- @param #table runtime: Lua table containing contexts: {ubus = conn, uci = uci, uloop = uloop, logger = logger}
-- @param #string actionname: UCI tod "action" section name to operate on
-- @param #string object: "activate|mac" combination
-- @param #boolean start: true means M.start,  false means M.stop
local function boost_action(runtime, actionname, object, start)
  local logger = runtime.logger
  local cursor = runtime.uci.cursor()
  local conn = runtime.ubus

  local boostactivate, boostmacaddr
  if object then
    boostactivate, boostmacaddr = string.match(object, "^(%S+)|(%S+)$")
  end

  local routinename = string.gsub(actionname, "online", "routine")
  local boostroutine = cursor:get(config_tod, routinename, "activedaytime")
  local action = string.find(actionname, "routine") and "routine" or "online"
  local boost -- value is nil(do nothing) or "1"(boost activate) or "0"(boost deactivate)

  if start then
    boost = boostactivate
  elseif action == "routine" or
    boostactivate == "1" and not boostroutine or
    boostactivate == "0" and boostroutine  then
    boost = boostactivate == "1" and "0" or "1"
  end

  if boost ~= nil  then
    local boosted = false
    local section
    cursor:foreach(config_qos, sectiontype, function(s)
      if s["srcmac"] == boostmacaddr and s["target"] == "Boost" then
        boosted = true
        section = s[".name"]
        return false
      end
    end)
    --boost activate
    if not boosted and boost == "1" then
      section = cursor:add(config_qos, sectiontype)
      cursor:set(config_qos, section, "order",'5')
      cursor:set(config_qos, section, "srcmac", boostmacaddr)
      cursor:set(config_qos, section, "target", 'Boost')
      cursor:commit(config_qos)
      os.execute("/etc/init.d/qos  reload; sleep 1")
      logger:notice(actionname .. ": boost start now")

      --boost deactivate
    elseif boosted and boost == "0"  then
      cursor:delete(config_qos, section)
      cursor:commit(config_qos)
      os.execute("/etc/init.d/qos  reload; sleep 1")
      logger:notice(actionname .. ": boost stopped!")
    end
  end

end

-- runtime is a lua table contains {ubus = conn, uci = uci, uloop = uloop, logger = logger}
-- Routine invoked when "start_time" has been reached in scheduler
-- @param #table runtime: Lua table containing contexts: {ubus = conn, uci = uci, uloop = uloop, logger = logger}
-- @param #string actionname: UCI tod "action" section name to operate on
-- @param #string object: UCI "object" or mac address of one object
-- @return #boolean true to continue with state machine, false if error encountered (causes this script to exit)
function M.start(runtime, actionname, object)
  boost_action(runtime, actionname, object, true)
  return true
end

-- Routine invoked when "stop_time" has been reached in scheduler
-- @param #table runtime: Lua table containing contexts: {ubus = conn, uci = uci, uloop = uloop, logger = logger}
-- @param #string actionname: UCI tod "action" section name to operate on
-- @param #string object: UCI "object" or mac address of an object
-- @return #boolean true to continue with state machine, false if error encountered (causes this script to exit)
function M.stop(runtime, actionname, object)
  boost_action(runtime, actionname, object, false)
  return true
end

return M
