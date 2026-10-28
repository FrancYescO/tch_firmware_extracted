#! /usr/bin/env lua

-- file: mod_dsl.lua

package.path = "/usr/share/ngwfdd/lib/?.lua;" .. package.path

local gwfd = require("gwfd-common")

-- Uloop and logger

local uloop = require("uloop")
local log

-- Uploop timer

local timer
local interval = 1800 * 1000 -- Every 30 minutes

-- Absolute path to the output fifo file

local fifo_file_path = arg[1]
local regex = "([^:]+):%s*(%d+)%s*kB"

local function send_meminfo()
  local msg = {}

  local file = io.open("/proc/meminfo", "r")
  local line = file:read("*l")
  while line do
    local name,value = line.match(line, regex)
    if name and value then
      msg[name] = tonumber(value)
    end
    line = file:read("*l")
  end

  file:close()

  gwfd.write_msg_to_file(msg, fifo_file_path)
  timer:set(interval) -- reschedule on the uloop
end


-- Main code
uloop.init()

log = gwfd.init("gwfd_meminfo", 6, { init_transformer = true })

timer = uloop.timer(send_meminfo)
send_meminfo()
xpcall(uloop.run, gwfd.errorhandler)