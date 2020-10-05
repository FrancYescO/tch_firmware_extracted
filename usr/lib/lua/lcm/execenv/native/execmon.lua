local require = require
local setmetatable = setmetatable

local posix = require 'tch.posix'

local RUNNING
do
  local state_machine = require "lcm.state_machine"
  RUNNING = state_machine.s_stable_states.RUNNING
end

local ExecutionMonitor = {}
ExecutionMonitor.__index = ExecutionMonitor

local function createMonitor(env, pid_files)
  local pid_info
  if #pid_files > 0 then
    pid_info = {}
    for _, f in ipairs(pid_files) do
      pid_info[f] = {}
    end
  end
  return {
    env = env,
    pids = pid_info
  }
end

local function read_pid(pidfile)
  local f = io.open(pidfile, "rb")
  if f then
    local pid = f:read("*l")
    f:close()
    return pid
  end
end

local function update_pid_info(self, pidfile)
  local info = self.pids[pidfile]
  local target_pid = read_pid(pidfile)
  if target_pid ~= info.pid then
    info.pid = target_pid
    info.host_pid = self.env:nativePID(target_pid)
  end
  return info.host_pid
end

local function is_pid_executing(pid)
  pid = tonumber(pid)
  if pid then
    return posix.kill(pid, 0)==0
  end
  return false
end

local function pid_executing(self, pidfile)
  local pid = update_pid_info(self, pidfile)
  return is_pid_executing(pid)
end

local function any_process_executing(self)
  for pidfile in pairs(self.pids) do
    if pid_executing(self, pidfile) then
      return true
    end
  end
  return false
end

function ExecutionMonitor:executing(pkg_state)
  if not self.pids then
    return pkg_state == RUNNING
  end
  return any_process_executing(self)
end


return {
  ExecutionMonitor = function(env, pid_files)
    return setmetatable(createMonitor(env, pid_files), ExecutionMonitor)
  end
}