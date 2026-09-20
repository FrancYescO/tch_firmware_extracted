local M = {}

M.SenseEventSet = {
}

function M.check(runtime, event)
    local uci = runtime.uci
    if not uci then
        return nil
    end

    local cursor = uci.cursor()
    if not cursor then
        return nil
    end

    local primary_wan_mode = cursor:get("wansensing", "global", "primarywanmode")
    if primary_wan_mode and primary_wan_mode:upper() == "MOBILE" then
        return "Mobile"
    end

    return "L2Sense"
end

return M
