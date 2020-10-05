#! /usr/bin/env lua

-- file: mod_cpustats.lua

package.path = "/usr/share/ngwfdd/lib/?.lua;" .. package.path

local gwfd = require("gwfd-common")
local uloop = require("uloop")

-- Uloop timer

local timer
local interval = (tonumber(gwfd.get_uci_param("ngwfdd.interval.cpustats")) or 600) * 1000

-- Absolute path to the output fifo file

local fifo_file_path = arg[1]

-- CPU statistics

local cpu_stats

local function parse_proc_stat_entry(l)
  local result = {}

  local work = 0
  local total = 0
  local i = 1

  for token in l:gmatch("([^ ]+)") do
    -- only first three fields (user/nice/system) are counted as effective usage
    if (i < 4) then
      work = work + token
    end
    total = total + token
    i = i + 1
  end
  result["work"] = work
  result["total"] = total
  return result
end

local function parse_proc_stat_file()
  local result = {}

  local file = io.open("/proc/stat", "r")
  local line = file:read("*l")

  local cpu_exp = "cpu[0-9]*"

  while line do
    local cpu = line:match(cpu_exp)
    if cpu then
      local stats = string.sub(line, string.len(cpu) + 1)
      local sums = parse_proc_stat_entry(stats)
      result[cpu] = sums
    end
    line = file:read("*l")
  end

  file:close()
  return result
end

local function get_cpu_params(t1, msg)
  local t2 = parse_proc_stat_file()

  for cpu, s in pairs(t1) do
    local usage = (t2[cpu]["work"] - s["work"]) / (t2[cpu]["total"] - s["total"]) * 100
    msg[cpu] = usage
  end

  return t2
end

local function send_cpustats_data()
  local msg = {}
  local new_cpu_stats = get_cpu_params(cpu_stats, msg)
  cpu_stats = new_cpu_stats

  gwfd.write_msg_to_file(msg, fifo_file_path)
  timer:set(interval) -- reschedule on the uloop
end

-- Main code
uloop.init()

gwfd.init("gwfd_cpustats", 6, { init_transformer = true })

cpu_stats = parse_proc_stat_file()

timer = uloop.timer(send_cpustats_data)
timer:set(interval)

xpcall(uloop.run, gwfd.errorhandler)
