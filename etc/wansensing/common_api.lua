local M = {}

--Update hotspot NAS IP
function M.updateNasIp(runtime)
    local scripthelpers = runtime.scripth
    local conn = runtime.ubus
    local x = runtime.uci.cursor()
    local logger = runtime.logger

    local ipv4addr = scripthelpers.checkIfInterfaceHasIP("wan", false)
    local nas_wan_ip = x:get("wireless", "ap7", "nas_wan_ip")
    if ipv4addr and nas_wan_ip ~= ipv4addr then
        logger:notice("update nas ip to " .. ipv4addr)
        x:set("wireless", "ap7", "nas_wan_ip", ipv4addr)
        x:commit("wireless")
        conn:call("wireless", "reload", { })
    end
end

return M
