local M = {}
local Script = {}
local prefix = '/etc/tod/'

Script.__index = Script

function Script:name()
    return self.scriptname
end

function Script:start( runtime, action, ... )
    runtime.logger:notice("("  .. action .. ") runs " .. self.scriptname .. ".start(" .. M.parameters( ... ) .. ")" )
    status, return1 = pcall(self.scripthandle.start, runtime, action, ...)
    if not status then
       runtime.logger:error(self.scriptname .. ".start(" .. M.parameters( ... ) .. ") throws error :" .. tostring(return1) )
       runtime.logger:error("stopped due error in script" .. self.scriptname)
       assert(false)
    end
    return return1
end

function Script:stop( runtime, action, ... )
    runtime.logger:notice("("  .. action .. ") runs " .. self.scriptname .. ".stop(" .. M.parameters( ... ) .. ")" )
    status, return1 = pcall(self.scripthandle.stop, runtime, action, ...)
    if not status then
       runtime.logger:error(self.scriptname .. ".stop(" .. M.parameters( ... ) .. ") throws error :" .. tostring(return1) )
       runtime.logger:error("stopped due error in script" .. self.scriptname)
       assert(false)
    end    
    return return1
end

function M.load(script, runtime)
    local self = {}
    local f = loadfile(prefix .. script .. ".lua")
    if not f then
       runtime.logger:error("error in loading script(" .. prefix .. script .. ")")
       assert(false)
    end

    self.scriptname = script
    self.scripthandle = f()
    setmetatable(self, Script)
    return self
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

return M
