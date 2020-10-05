local M = {}

local function do_action(runtime, actionname, object)
  local cursor = runtime.uci.cursor()

  local action_fwd = "ACCEPT"

  cursor:set("firewall", "Guest", "forward", action_fwd)
  cursor:set("firewall", "defaultoutgoing_Guest", "target", action_fwd)
  cursor:commit("firewall")
  os.execute("/etc/init.d/firewall reload")

  cursor:set("wireless", "wl0_2", "state", "0")
  cursor:set("tod", actionname, "object", "all")
  cursor:commit("wireless")
  cursor:commit("tod")
  os.execute("/etc/init.d/hostapd reload; sleep 3")

  return true
end

-- runtime is a lua table contains {ubus = conn, uci = uci, uloop = uloop, logger = logger}
-- Routine invoked when "start_time" has been reached in scheduler
-- @param #table runtime: Lua table containing contexts: {ubus = conn, uci = uci, uloop = uloop, logger = logger}
-- @param #string actionname: UCI tod "action" section name to operate on
-- @param #string object: UCI "object" or mac address of one object
-- @return #boolean true to continue with state machine, false if error encountered (causes this script to exit)
function M.start(runtime, actionname, object)
  return do_action(runtime, actionname, object)
end

-- Routine invoked when "stop_time" has been reached in scheduler
-- @param #table runtime: Lua table containing contexts: {ubus = conn, uci = uci, uloop = uloop, logger = logger}
-- @param #string actionname: UCI tod "action" section name to operate on
-- @param #string object: UCI "object" or mac address of an object
-- @return #boolean true to continue with state machine, false if error encountered (causes this script to exit)

function M.stop(runtime, actionname, object)
  return true
end

return M
