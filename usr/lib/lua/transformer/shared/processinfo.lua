local M = {}
local io, math = io, math
local floor = math.floor
local open = io.open
local tostring = tostring
local process = require("tch.process")
local socket = require ('socket') --needed for a decent delay


-- Calculates CPU total cycles and idle cycles since boot from the /proc/stat file. Units are all in kernel jiffies but this isn't an issue 
-- as the final output is a percentage 
-- @function M.getCPUUsage
-- @return #string, returns the CPU usage value as a percentage of the total usage.
local function getCPUUsageTotals()
  local user, nice, sys, idle, ioWait, irq, softIrq, steal, guest, guestNice
  local data = open("/proc/stat")
  if data then
    local firstLine = data:read("*l")
    user, nice, sys, idle, ioWait, irq, softIrq, steal, guest, guestNice = firstLine:match("^cpu%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)")
    data:close()
  end
  if not user then
	return "0","100"
  end
  local cpuIdle = ioWait + idle
  local cpuNonIdle = user + nice + sys + irq + softIrq + steal + guest + guestNice
  local total = cpuIdle + cpuNonIdle
  return cpuIdle,total
end


-- Calculates CPU usage since boot from the /proc/stat file. This value is a ratio of the non-idle time to the total usage in "USER_HZ".
-- @function M.getCPUUsage
-- @return #string, returns the CPU usage value as a percentage of the total usage.
function M.getCPUUsage()
  local cpuIdleCycles,totalCycles
  cpuIdleCycles,totalCycles = getCPUUsageTotals()
  local cpuUsage= 100-(floor((cpuIdleCycles*100)/totalCycles))
  return tostring(cpuUsage) or "0"
end

-- Calculates Current cpu usage by getting total cycles and idle cycles waiting half a second getting the values again and subtracting them.
-- @funciton M.getCurrentCPUUsage
-- @return #string, returns the current CPU usage value.
function M.getCurrentCPUUsage()
  local cpuIdleStart,cpuIdleNow,cpuTotalStart,cpuTotalNow
  cpuIdleStart,cpuTotalStart=getCPUUsageTotals()
  socket.sleep(1.0)
  cpuIdleNow,cpuTotalNow=getCPUUsageTotals()
  local deltaIdleTime= cpuIdleNow-cpuIdleStart
  local deltaTotalTime=cpuTotalNow-cpuTotalStart
  local activePercent= 100-(floor((deltaIdleTime*100)/deltaTotalTime))
  return tostring(activePercent) or "0"
end

return M
