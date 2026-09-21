#! /usr/bin/env lua

-- file: mod_process.lua

package.path = "/usr/share/ngwfdd/lib/?.lua;" .. package.path

local gwfd = require("gwfd-common")
local lfs = require("lfs")
local uloop = require("uloop")

-- Uloop timer and the required interval

local timer

-- Get interval from UCI
local interval_config = gwfd.get_uci_param("ngwfdd.config.process_interval") or 300
local interval = tonumber(interval_config) * 1000

-- Absolute path to the output fifo file

-- Internal cache

local cache = {}

local function get_process_name(info)
  local file = io.open("/proc/" .. info.pid .. "/comm", "r")
  if not file then
    return
  end

  local name = file:read("*l")
  file:close()
  if not name then
    return
  end

  info.name = name
end

local function get_process_memory(info)
  local file = io.open("/proc/" .. info.pid .. "/status", "r")
  if not file then
    return
  end

  local status = file:read("*all")
  file:close()
  if not status then
    return
  end

  local vmhwm_exp = "VmHWM:%s*(%d+)%s*kB"
  local vmhwm = string.match(status, vmhwm_exp)
  if (not vmhwm) then
    return
  end

  local vmrss_exp = "VmRSS:%s*(%d+)%s*kB"
  local vmrss = string.match(status, vmrss_exp)

  local vmdata_exp = "VmData:%s*(%d+)%s*kB"
  local vmdata = string.match(status, vmdata_exp)

  info.vmhwm = tonumber(vmhwm)
  info.vmrss = tonumber(vmrss)
  info.vmdata = tonumber(vmdata)

  local prev = cache[info.pid]

  if not prev then
    cache[info.pid] = {}
    prev = cache[info.pid]
  end

  if not prev.vmrss_min then
    prev.vmrss_min = info.vmrss
  end

  info.vmrss_min = prev.vmrss_min
  info.vmrss_delta_min = info.vmrss - prev.vmrss_min
  prev.vmrss_min = math.min(info.vmrss, prev.vmrss_min)

  prev.hit = true
end

local function mark_cache(c)
  for _, entry in pairs(c) do
    entry.hit = false
  end
end

local function sweep_cache(c)
  for key, entry in pairs(c) do
    if (not entry.hit) then
      c[key] = nil
    end
  end
end

local function get_total_cpu()
  local file = io.open("/proc/stat", "r")
  local line = file:read("*l")
  file:close()

  line = string.sub(line, 4) -- strip cpu

  local total = 0

  for token in string.gmatch(line, "([^ ]+)") do
    total = total + token
  end

  return total
end

local function get_process_cpu(info)
  local file = io.open("/proc/" .. info.pid .. "/stat", "r")
  if not file then
    return
  end

  local stat = file:read("*l")
  file:close()
  if not stat then
    return
  end

  local exp = "%d+ %([^%)]+%) . %d+ %d+ %d+ %d+ %-?%d+ %d+ %d+ %d+ %d+ %d+ (%d+) (%d+) (%d+) (%d+)"
  local utime, stime, cutime, cstime = string.match(stat, exp)
  if not (utime and stime and cutime and cstime) then
    return
  end

  local total = get_total_cpu()
  local prev = cache[info.pid]

  -- compute CPU usage
  if prev and prev.utime then
    local user = 100 * ((utime - prev.utime) + (cutime - prev.cutime)) / (total - prev.total)
    local kernel = 100 * ((stime - prev.stime) + (cstime - prev.cstime)) / (total - prev.total)

    if (user > 0 or kernel > 0) then
      info.cpu_user = user
      info.cpu_kernel = kernel
      info.cpu = user + kernel
    end
  end

  -- update cache
  if not prev then
    cache[info.pid] = {}
    prev = cache[info.pid]
  end

  prev.utime = utime
  prev.utime = utime
  prev.stime = stime
  prev.cutime = cutime
  prev.cstime = cstime
  prev.total = total
  prev.hit = true
end

local function get_process_cmdline(info)
  local file = io.open("/proc/" .. info.pid .. "/cmdline", "r")
  if not file then
    return
  end

  local cmdline = file:read("*a")
  file:close()
  if not cmdline then
    return
  end

  -- replace zero characters in cmdline
  cmdline = string.gsub(cmdline, "%z", " ")

  info.cmdline = cmdline
end

local function get_process_info()
  local pid_exp = "^[0-9]+$"

  mark_cache(cache)

  for fname in lfs.dir("/proc/") do
    local pid = string.match(fname, pid_exp)
    if pid then
      local info = {}
      info.pid = tonumber(fname)

      get_process_memory(info)
      get_process_cpu(info)

      get_process_name(info)
      get_process_cmdline(info)

      gwfd.write_msg_to_file(info, arg[1])
    end
  end

  sweep_cache(cache)
  timer:set(interval) -- reschedule on the uloop
end

-- Main

uloop.init()

gwfd.init("gwfd_process", 6, {})

timer = uloop.timer(get_process_info)
get_process_info()
xpcall(uloop.run, gwfd.errorhandler)
