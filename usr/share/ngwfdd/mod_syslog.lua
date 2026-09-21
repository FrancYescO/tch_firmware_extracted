#! /usr/bin/env lua

-- file: mod_syslog.lua

package.path = "/usr/share/ngwfdd/lib/?.lua;" .. package.path

local dkjson = require("dkjson")
local gwfd = require("gwfd-common")

-- Absolute path to the output fifo file
local fifo_file_path = assert(arg[1])
local file = assert(io.open(fifo_file_path, "w"))

-- Read the logs with logread to get all logs until now
-- followed by logread -f to read any future log messages
local logs = assert(io.popen("logread && logread -f", 'r'))

for line in logs:lines() do
  local msg = {
    uptime = gwfd.get_uptime(),
    msg = gwfd.fixUTF8(line)
  }
  file:write(dkjson.encode(msg))
  file:write('\n')
  file:flush()
end

logs:close()
file:close()



