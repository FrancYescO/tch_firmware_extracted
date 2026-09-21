#! /usr/bin/env lua

-- file: mod_syslog.lua

package.path = "/usr/share/ngwfdd/lib/?.lua;" .. package.path

local dkjson = require("dkjson")
local gwfd = require("gwfd-common")

-- Absolute path to the output fifo file
local fifo_file_path = arg[1]

local file = io.open(fifo_file_path, "w")

if file then
  -- Read the logs with logread to get all logs until now
  -- followed by logread -f to read any future log messages
  local logs = io.popen("logread && logread -f", 'r')
  if logs then
    local msg = {}
    local line = logs:read('*l')
    while line do
      local uptime = gwfd.get_uptime()
      msg["uptime"] = uptime
      msg["msg"] = gwfd.fixUTF8(line)
      local str = dkjson.encode(msg)
      file:write(str)
      file:write('\n')
      file:flush()
      line = logs:read('*l')
    end
    io.close(logs)
  end
  io.close(file)
end


