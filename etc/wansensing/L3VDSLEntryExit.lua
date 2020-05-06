---
-- Module L3 EntryExit.
-- Module Specifies the entry and exit functions of a L3 wansensing state
-- @module modulename
local M = {}

---
-- Entry function called if a wansensing L3 state is entered.
--
-- @function [parent=M] 
-- @param #1 runtime table holding the wansensing context (async/ubus/uci/logger/scripthelper)
-- @param #2 string specifying the sensed L2 type (see L2Main.lua example)
-- @return #1 boolean indicates if the entry actions are executed/not executed
function M.entry(runtime, l2type)
   if l2type == "VDSL" then
		local uci = runtime.uci
		local x = uci.cursor()local wan_if = x:get("env", "custovar", "wan_if")
		x:set("network", wan_if, "ifname", "ptm0")
		x:set("network", "wantag", "auto", "1")
		x:commit("network")
		x:set("cwmpd", "cwmpd_config", "state", "0")
		x:commit("cwmpd")
		os.execute("/etc/init.d/cwmpd reload")
		os.execute("ifup wantag")
   end
   return true
end

---
-- Entry function called if a wansensing L3 state is entered.
--
---
-- Exit function called if a wansensing L3 state is exited.
--
-- @function [parent=M] 
-- @param #1 runtime table holding the wansensing context (async/ubus/uci/logger/scripthelper)
-- @param #2 string specifying the sensed L2 type (see L2Main.lua example)
-- @param #3 string specifying the next state
-- @return #1 boolean indicates if the exit actions are executed/not executed
function M.exit(runtime, l2type, transition)
	local uci = runtime.uci
	local x = uci.cursor()
	local wan_if = x:get("env", "custovar", "wan_if")
	x:set("network", wan_if, "ifname", "ptm0")
	x:set("network", "wantag", "auto", "0")
	x:set("cwmpd", "cwmpd_config", "state", "1")
	x:commit("cwmpd")
	os.execute("/etc/init.d/cwmpd reload")
	x:commit("network")

	os.execute("ifdown wantag")
	return true
end

return M

