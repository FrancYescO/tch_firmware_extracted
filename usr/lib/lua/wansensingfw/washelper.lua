local M = {}
local Script = {}
local prefix = '/etc/wansensing/'

Script.__index = Script

local function set (list)
    local k, v

    -- if list is already a string hash table, reuse it
    -- so that caller will have direct access to registered events,
    -- allowing script to dynamically (un)register events at runtime
    if type(list) == "table" and (type(list.timeout) == "boolean" or type(list.start) == "boolean") then
        local hashtable = true

        for k, v in pairs(list) do
            if type(k) ~= "string" or type(v) ~= "boolean" then
                hashtable = false
                break
            end
        end

        if hashtable then
            return list
        end
    end

    local set = { timeout = true } -- timeout events by default
    if list then
        for k, v in pairs(list) do set[v] = true end
    end

    return set
end

function Script:name()
    return self.scriptname
end

function Script:entry( requester, runtime, ... )
    runtime.logger:notice("("  .. requester .. ") runs " .. self.scriptname .. ".entry(" .. M.parameters( ... ) .. ")" )
    local status, return1, return2 = pcall(self.scripthandle.entry, runtime, ...)
    if not status or not return1 then
       runtime.logger:error(self.scriptname .. ".entry(" .. M.parameters( ... ) .. ") throws error :" .. tostring(return1) )
       runtime.logger:error("stopped due error in script" .. self.scriptname)
       assert(false)
    end
    return return1, return2
end

function Script:poll( requester, runtime, ... )
    runtime.logger:notice("("  .. requester .. ") runs " .. self.scriptname .. ".check(" .. M.parameters( ... ) .. ")" )
    local status, return1, return2 = pcall(self.scripthandle.check, runtime, ...)
    if not status then
       runtime.logger:error(self.scriptname .. ".check(" .. M.parameters( ... ) .. ") throws error :" .. tostring(return1) )
       runtime.logger:error("stopped due error in script" .. self.scriptname)
       assert(false)
    end

    if not return1 then
       return1 = requester
    end
    
    return return1, return2
end

function Script:exit( requester, runtime, ... )
    runtime.logger:notice("("  .. requester .. ") runs " .. self.scriptname .. ".exit(" .. M.parameters( ... ) .. ")" )
    local status, return1 = pcall(self.scripthandle.exit, runtime, ...)
    if not status or not return1 then
       runtime.logger:error(self.scriptname .. ".exit(" .. M.parameters( ... ) .. ") throws error :" .. tostring(return1) )
       runtime.logger:error("stopped due error in script" .. self.scriptname)
       assert(false)
    end
    return return1
end

function M.parameters( ... )
    local parameters = ""
    if ( arg.n )  then
        for i,v in ipairs(arg) do
            if ( i > 1 ) then
                parameters = parameters .. ","
            end
            parameters = parameters .. tostring(v)
        end
    end
    return parameters
end

function M.load(script, runtime)
    local self = {}
    local f = loadfile(prefix .. script .. ".lua")
    if not f then
       runtime.logger:error("error in loading script(" .. prefix .. script .. ")")
       assert(false)
    end

    self.scriptname=script
    self.scripthandle = f()
    setmetatable(self, Script)
    return self, set(self.scripthandle.SenseEventSet)
end

function M.initmode_save(x, mode)
    local config = "wansensing"
    x:load(config)
    x:set(config, "global", "initmode", mode)
    x:commit(config)
end

function M.l2type_save(x, l2type)
    local config = "wansensing"
    x:load(config)
    x:set(config, "global", "l2type", l2type)
    x:commit(config)
end

function M.l2type_get(x)
    local config = "wansensing"
    x:load(config)
    return x:get(config, "global", "l2type")
end

function M.l3type_save(x, l3type)
    local config = "wansensing"
    x:load(config)
    x:set(config, "global", "l3type", l3type)
    x:commit(config)
end

function M.l3type_get(x)
    local config = "wansensing"
    x:load(config)
    return x:get(config, "global", "l3type")
end

function M.open_state(uci)
   local config = "wansensing"
   local x = uci.cursor(UCI_CONFIG, "/var/state")
   x:load(config)
   x:revert("wansensing", "state")
   x:set("wansensing", "state", "state")
   x:save("wansensing")

end

function M.set_state(uci, state)
   local config = "wansensing"
   local x = uci.cursor(UCI_CONFIG, "/var/state")

   x:load(config)
   x:revert("wansensing", "state", "currState")
   x:set("wansensing", "state", "currState", state)
   x:save("wansensing")
end

return M
