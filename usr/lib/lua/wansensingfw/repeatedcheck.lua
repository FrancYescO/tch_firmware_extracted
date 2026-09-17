local M = {}

local runtime={}

local RepeatedCheck = {}
RepeatedCheck.__index = RepeatedCheck

--- redirect each call to the classname to the init constructor
setmetatable(RepeatedCheck, {
  __call = function (cls, ...)
    return M.init(...)
  end,
})

--- constructor for a repeatedly test a predicate and calls a function when it fails
-- @param intervalTable={900,30,10}  test every 900s, on fail tests after 30, 10 ,..
-- ending this table with a '-1' repeats the last value until stopped (never abort)
-- @param check_cb return true for successful test
-- @param abort_cb executed is after repeated tests failed
-- @return an 'object' with methods  start() and halt()
function M.init(intervals, check_cb, abort_cb)
   if type(intervals) ~= "table" or intervals[1] == nil then
      error("createRepeatedCheck arg1 has to be a table with at least 1 time")
   end
   if type(check_cb) ~= "function" then
      error("createRepeatedCheck arg2 (check_cb) has to be a boolean function")
   end
   if type(abort_cb) ~= "function" then
      error("createRepeatedCheck arg3 (abort_cb) has to be a function")
   end

   local self = {}
   setmetatable(self, RepeatedCheck)
   self.runFlag = false
   self.intervals = intervals
   self.check_cb = check_cb
   self.abort_cb = abort_cb
   self.timer = runtime.uloop.timer(function ()
				       self:timeout()
				    end)
   return self
end

--- internally called by the timer (consider as private)
-- no argument nor return
function RepeatedCheck:timeout()
   if not self.runFlag then
      return
   end
   if self.check_cb() then
      self.failcount = 0
   end
   if self.intervals[self.failcount+1] ~= -1 then
      self.failcount = self.failcount + 1
   end
   if self.intervals[self.failcount] == nil then
      self.runFlag=false
      self.abort_cb()
   else
      self.timer:set(self.intervals[self.failcount] *1000) -- times in sec, not ms
   end
end

--- public  start method
-- @return boolean only true when it was not running before
function RepeatedCheck:start()
   if self.runFlag then
      return false        -- make start operation 'idempotent'
   end
   self.failcount = 1  
   self.runFlag = true
   self.timer:set(self.intervals[1]*1000) -- times in sec, not ms
   return true
end

--- public stop method
-- @return only true when it was running before
function RepeatedCheck:stop()  -- explicitly request to stop before an abort occurs
   if not self.runFlag then
      return false
   end
   self.runFlag = false
   self.timer:cancel()
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
M.RepeatedCheck=RepeatedCheck

return M
