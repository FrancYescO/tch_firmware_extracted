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
        local uci = format("uci.web.assistance.@%s.interface", name)
        dm.set(uci, state.ifname)
        dm.apply()
    end
end

local function change_interface(name, interface, interface6)
    local assistant = assistance.getAssistant(name)
    if assistant then
        local state = assistance.loadState(name)
        local enabled = assistant:enabled()
        local flag = false
        if interface and interface ~= state.ifname then
            assistant._interface = interface
            if enabled then
                state.ifname = interface
                flag = true
            end
        end
        if interface6 and interface6 ~= state.ifname6 then
            assistant._interface6 = interface6
            if enabled then
                state.ifname6 = interface6
                flag = true
            end
        end
        if flag then
            writeState(name, state)
        end
    end
end

local function process()
    local getargs = ngx.req.get_uri_args()
    for k, v in pairs(getargs) do
        if v == "reload_interface" then
            local interface = dm.get(format("uci.web.assistance.@%s.interface",k))
            local interface6 = dm.get(format("uci.web.assistance.@%s.interface6",k))
            interface = interface and interface[1].value
            interface6 = interface6 and interface6[1].value
            if interface or interface6 then
                if interface == "" then
                    interface = "wan"
                end
                if interface6 == "" then
                    interface6 = "wan6"
                end
                change_interface(k, interface, interface6)
            end
        end
    end
    require("web.reload_assistance").reload(getargs)
end

M.change_interface = change_interface
M.process = process

return M
