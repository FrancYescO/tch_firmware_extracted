local washelper = require('wansensingfw.washelper')
local load = washelper.load
local runtime = {}

local WasWorker = {}
WasWorker.__index = WasWorker

function WasWorker:update(event)
    --lets call the check script
    -- event can be handled in this state
    if self.events[event] then
       return self.mains:poll(self.name, runtime, event)
    end
end

function WasWorker:start()
    --lets call the check script
    return self:update("start")
end

--- Name access function
function WasWorker:getName()
   return self.name
end

local M = {}

--- init
-- Constructor of the Worker Object
-- @param name = name of worker
-- @param values = configuration values of this worker
-- @return object
function M.init(name , values)
    local self = { name = name }

    if ( values.mains ~= nil and values.mains ~= "" ) then
        self.mains, self.events = load(values.mains, runtime)
    end

    setmetatable(self, WasWorker)

    return self
end

function M.setruntime(rt)
   runtime = rt
end

return M

