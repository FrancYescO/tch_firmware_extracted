local M = {}

function M.entry(runtime, l2type)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger
    local scripthelpers = runtime.scripth

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3 DHCP Sense entry script is configuring DHCP on l2type interface " .. tostring(l2type))

    -- copy wan interfaces release renew
    local x = uci.cursor()
    local auto=x:get("network", "wan", "auto")
    if auto ~= "0" then -- only do a release renew if the user has not disabled dhcp
        x:set("network", "wan", "auto", "0")
        x:commit("network")
        conn:call("network", "reload", { })
        os.execute("sleep 2")
        x:delete("network", "wan", "auto")
        x:commit("network")
        conn:call("network", "reload", { })
    end
    return true
end

function M.exit(runtime,l2type, transition)
    local uci = runtime.uci
    local conn = runtime.ubus
    local logger = runtime.logger

    if not uci or not conn or not logger then
        return false
    end

    logger:notice("The L3 DHCP Sense exit script is using transition " .. transition .. " using l2type " .. tostring(l2type))

    return true
end

return M
