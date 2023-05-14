local washelper = require('wansensingfw.washelper')
local load = washelper.load
local runtime = {}

local L2WasMachine = {}
L2WasMachine.__index = L2WasMachine

function L2WasMachine:entry()
    --report the current state
    washelper.set_state(runtime.uci, self.name)

    local _, timeout = self.entrys:entry(self.name, runtime)

    -- schedule a timeout event, use 5 seconds if entry() didn't return a timeout
    runtime.async.timerstart((timeout or 5) * 1000)
end

function L2WasMachine:sense(event)
    --lets call the check script
    return self.mains:poll(self.name, runtime, event)
end

function L2WasMachine:exit(transition)
    self.exits:exit(self.name, runtime, self.l2type, transition)

    -- lets persist the l2type if set and the exit script was running without problems
    if self.l2type then
        washelper.l2type_save(runtime.uci.cursor(), self.l2type)
    end

    -- lets cancel the timeout timer, we are done
    runtime.async.timerstop()
end

function L2WasMachine:update(event)
    local nextState, fast
    local timeout = self.timeout * 1000
    -- event can be handled in this state
    if self.events[event] then

        nextState, self.l2type, fast = self:sense(event)

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
function L2WasMachine:getName()
   return self.name
end

local M = {}

--- init
-- Constructor of the L2 Object
-- @param name = name of sensing state
-- @param values = configuration values of this sensing state
-- @return object
function M.init(name , values)
    local self = { name = name, timeout = 60}

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

    setmetatable(self, L2WasMachine)

    return self
end

function M.setruntime(rt)
   runtime = rt
end

return M

