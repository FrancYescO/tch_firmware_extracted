local M = {}

local runtime={}

local TimedEvent = {}
TimedEvent.__index = TimedEvent

--- redirect each call to the classname to the init constructor
setmetatable(TimedEvent, {
  __call = function (cls, ...)
    return M.init(...)
  end,
})

--- constructor for a TimeEvent that waits a number of seconds before
-- emiting an event and repeats this a number of time (0 means infinite)
-- @param timeout_sec
-- @param event_name
-- @param count  (0 repeat forever)
-- @return an 'object' with methods  start() and stop()
function M.init(event_name, timeout_sec, count)
   if type(event_name) ~= "string" then
      error("TimedEvent expects second argument to be a string as name of the event")
   end
   if type(timeout_sec) ~= "number" then
      error("TimedEvent expects first argument to be the number of seconds")
   end
   if type(count) ~= "number" then
      error("TimedEvent expects third argument to be the number of iterations, 0 to keep running")
   end

   local self = {}
   setmetatable(self, TimedEvent)
   self['runFlag'] = false
   self['timeout_sec'] = timeout_sec
   self['event_name'] = event_name
   self['count'] = count

   local todo=''
   if count==1 then
      todo=' once'
   elseif count~=0 then
      todo=" "..tostring(count).." times"
   elseif count==0 then
      todo=" forever"
   end
   self['asString']="'"..event_name.."',"..todo..", "..tostring(timeout_sec).."s"
   runtime.logger:notice("TimedEvent("..self['asString']..") created")
   return self
end

--- internally called by the timer (consider as private)
-- no argument nor return
function TimedEvent:timeout()
   local iterations=self:iterations_to_do()

   if iterations>1 then
      iterations=iterations-1
      self['count']=iterations
   elseif iterations<0 then
      return self:stop() -- abort
   elseif iterations==1 then
      iterations=-1
      self:stop() -- no return, still needs to emit event_name
   end

   local to_do=''
   if iterations<0 then
      to_do=": done"
   elseif iterations==1 then
      to_do=", "..self['count'].." time to go"
   elseif iterations>1 then
      to_do=", "..self['count'].." times to go"
   elseif iterations==0 then
      to_do=", repeat"
   end

   if iterations>=0 then
      self['timer']:set(self['timeout_sec'] *1000) -- times in sec, not ms
   end

   runtime.logger:notice("TimedEvent(" ..self['asString'].. ") fires"..to_do)
   runtime.event_cb(self['event_name'])
end


--- public iterations_to_do method
-- @return { -1 : not running, 0 : infinite iterations, >0 : iterations to complete}
function TimedEvent:iterations_to_do()
   if not self['runFlag'] or self['count']<0 then
      return -1
   end
   return self['count']
end

--- public  start method, can continue after a 'stop'
-- @return boolean only true when it was not running before
function TimedEvent:start()
   if self['runFlag'] then
      return false        -- make start operation 'idempotent'
   end

   runtime.logger:notice("TimedEvent(".. self['asString']..") starts")
   self['runFlag'] = true
   self['timer'] = runtime.uloop.timer(function ()
                                          self:timeout()
                                       end)
   self['timer']:set(self['timeout_sec']*1000) -- times in sec, not ms
   return true
end

--- public stop method, can be used to pause and start again
-- @return only true when it was running before
function TimedEvent:stop()  -- request to stop, even before completing the requested iterations
   if not self['runFlag'] then
      return false
   end
   self['runFlag'] = false
   self['timer']:cancel() -- remove the timer for the GC
   self['timer']=nil
   runtime.logger:notice("TimedEvent(".. self['asString']..") stops")
   return true
end

--- set the runtime of the library
-- @param runtime table
function M.setruntime(rt)
    for rt_key, rt_value in pairs(rt) do
       runtime[rt_key] = rt_value
    end
end

-- expose the local class as a member of M, to use as a constructor
M.TimedEvent=TimedEvent

return M
