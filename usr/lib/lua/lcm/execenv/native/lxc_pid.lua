local require = require
local open = io.open

local lfs = require 'lfs'
local process = require 'tch.process'

local function container_PID_namespace(containerName)
  local ns
  local f = process.popen("/usr/bin/lxc-attach", {"-n", containerName, "readlink", "/proc/self/ns/pid"})
  if f then
    ns = f:read('*l')
    f:close()
  end
  return ns
end

local function process_PID_namespace(processID)
  local ns
  local f = process.popen("/usr/bin/readlink", {("/proc/%s/ns/pid"):format(processID)})
  if f then
    ns = f:read("*l")
    f:close()
  end
  return ns
end

local function processes_for_namespace(namespaceId)
  local processes = {}
  for p in lfs.dir("/proc") do
    if p:match("^%d+$") and process_PID_namespace(p)==namespaceId then
      processes[#processes+1] = p
    end
  end
  return processes
end

local function NSpid_info(pid)
  local f = open( ("/proc/%s/status"):format(pid), "r")
  if not f then
    return
  end

  local info
  for line in f:lines() do
    if line:match("^NSpid:") then
      info = line
      break
    end
  end
  f:close()
  return info
end

local function all_pids(hostPid)
  local info = NSpid_info(hostPid)
  if not info then
    return
  end

  local pids = {}
  for pid in info:gmatch("%d+") do
    pids[#pids+1] = pid
  end
  return pids
end

local function container_pid(hostPid)
  local pids = all_pids(hostPid)
  if pids then
    return pids[#pids]
  end
end

local function host_pid(containerName, containerPid)
  local namespaceId = container_PID_namespace(containerName)
  if not namespaceId then
    return nil, "no such namespace"
  end

  for _, pid in ipairs(processes_for_namespace(namespaceId)) do
    if container_pid(pid)==containerPid then
      return pid
    end
  end
  return nil, "no such pid"
end

return {
  host_pid = host_pid,
}
