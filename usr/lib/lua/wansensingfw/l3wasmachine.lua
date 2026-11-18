local washelper = require('wansensingfw.washelper')
local load = washelper.load
local runtime = {}

local L3WasMachine = {}
L3WasMachine.__index = L3WasMachine

function L3WasMachine:entry()
    --report the current state
    washelper.set_state(runtime.uci, self.name)

    self.l2type = washelper.l2type_get(runtime.uci.cursor())

    local _, timeout = self.entrys:entry(self.name, runtime, self.l2type)

    -- lets persist the l3type if the exit script was running without problems
    washelper.l3type_save(runtime.uci.cursor(), self.name)

    -- schedule a timeout event, use 5 seconds if entry() didn't return a timeout
    runtime.async.timerstart((timeout or 5) * 1000)
end

function L3WasMachine:sense(event)
    --lets call the check script
    return self.mains:poll(self.name, runtime, self.l2type, event)
end

function L3WasMachine:exit(transition)
    self.exits:exit(self.name, runtime, self.l2type, transition)

    -- lets cancel the timeout timer, we are done
    runtime.async.timerstop()
end

function L3WasMachine:update(event)
    local nextState, fast
    local timeout = self.timeout * 1000

    if not self.l2type then
        self.l2type = washelper.l2type_get(runtime.uci.cursor())
    end

    -- event can be handled in this state
    if self.events[event] ~= nil then

        nextState, fast = self:sense(event)

        if fast then
            timeout = self.fasttimeout * 1000
        end

        -- leaving current state?
        if nextState ~= self.name then
            self:exit(nextState)
        else
           -- we keep in the same state
           -- in case of a timeout event, lets rearm the timer
           if event == 'timeout' then
              runtime.async.timerstart(timeout)
           end
        end
    else
        -- event can't be handled in this state
        return self.name
    end
    return nextState
end

--- Name access function
function L3WasMachine:getName()
   return self.name
end

local M = {}

--- init
-- Constructor of the L3 Object
-- @param name = name of sensing state
-- @param values = configuration values of this sensing state
-- @return object
function M.init(name , values)
    local self = { name = name, timeout = 60 }

    if values.timeout ~= nil then
        self.timeout = values.timeout
    end

    if values.fasttimeout ~= nil then
        self.fasttimeout = values.fasttimeout
    else
        self.fasttimeout = self.timeout
    end

    if ( values.entryexits ~= nil and values.entryexits ~= "" ) then
        self.exits = load(values.entryexits, runtime)
        self.entrys = self.exits
    end
    if ( values.mains ~= nil and values.mains ~= "" ) then
        self.mains, self.events = load(values.mains, runtime)
    end

    return setmetatable(self, L3WasMachine)

end

function M.setruntime(rt)
   runtime = rt
end

return M

