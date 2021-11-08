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
    local logger = runtime.logger

    if not logger then
        return false
    end

    runtime.entry_l3 = true

    logger:notice("The L3 entry script is end!")
    return true
end

---
-- Exit function called if a wansensing L3 state is exited.
--
-- @function [parent=M]
-- @param #1 runtime table holding the wansensing context (async/ubus/uci/logger/scripthelper)
-- @param #2 string specifying the sensed L2 type (see L2Main.lua example)
-- @param #3 string specifying the next state
-- @return #1 boolean indicates if the exit actions are executed/not executed
function M.exit(runtime, l2type, transition)
    local logger = runtime.logger

    if not logger then
        return false
    end

    logger:notice("The L3 exit script is end!")
    return true
end

return M
