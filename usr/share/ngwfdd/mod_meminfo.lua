#! /usr/bin/env lua

local gwfd = require("gwfd.common")
local fifo_file_path
local interval
do
  local args = gwfd.parse_args(arg, {interval=300})
  fifo_file_path = args.fifo
  interval = args.interval
end

-- Uloop and logger

local uloop = require("uloop")

-- Uploop timer

local timer

local regex = "([^:]+):%s*(%d+)%s*kB"

local function send_meminfo()
  local msg = {}

  local file = io.open("/proc/meminfo", "r")
  local line = file:read("*l")
  while line do
    local name,value = line:match(regex)
    if name and value then
      msg[name] = tonumber(value)
    end
    line = file:read("*l")
  end

  file:close()

  gwfd.get_transformer_param("sys.mem.", msg)

  gwfd.write_msg_to_file(msg, fifo_file_path)
  timer:set(interval) -- reschedule on the uloop
end


-- Main code
uloop.init()

gwfd.init("gwfd_meminfo", 6, { init_transformer = true })

-- tune the lua garbage collector to be more aggressive and reclaim memory sooner
-- default value of setpause is 200, set it to 100
collectgarbage("setpause",100)
collectgarbage("collect")
collectgarbage("restart")

timer = uloop.timer(send_meminfo)
send_meminfo()
xpcall(uloop.run, gwfd.errorhandler)
