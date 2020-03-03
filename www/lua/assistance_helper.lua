local M = {}
local assistance = require("web.assistance")
local dm = require("datamodel")
local format = string.format

local stateFile = "/var/run/assistance/%s"
local function writeState(name, state)
    local f = io.open(stateFile:format(name), 'w')
    if f then
        for key, value in pairs(state) do
            f:write(format("%s=%s\n", key, value))
        end
        f:close()
        local uci = format("uci.web.assistance.@%s.active", name)
        dm.set(uci, state.enabled or "trigger")
        dm.apply()
    end
end

local function change_interface(name, interface)
    local assistant = assistance.getAssistant(name)
    if assistant then
        local state = assistance.loadState(name)
        if interface ~= state.ifname then
            assistant._interface = interface
            if assistant:enabled() then
                state.ifname = interface
                writeState(name, state)
            end
        end
    end
end

local function process()
    local getargs = ngx.req.get_uri_args()
    for k, v in pairs(getargs) do
        local enable, mode, pwdcfg, pwd = string.match(string.untaint(v), "(.*)_(.*)_(.*)_(.*)")
        if enable then
            local assistant = assistance.getAssistant(k)
            if pwdcfg == "random" then
                pwd=nil
            elseif pwdcfg == "keep" then
                pwd=false
            end
            if enable == "on" then
                assistant:enable(true, mode=="permanent", pwd)
            elseif enable == "off" then
                assistant:enable(false, mode=="permanent", pwd)
            end
        elseif v == "reload_interface" then
            local interface = dm.get(format("uci.web.assistance.@%s.interface",k))
            interface = interface and interface[1].value
            if interface then
                if interface == "" then
                    interface = "wan"
                end
                change_interface(k, interface)
            end
        end
    end
end

M.change_interface = change_interface
M.process = process

return M
