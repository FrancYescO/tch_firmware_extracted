#! /usr/bin/env lua

local gwfd = require("gwfd.common")
local fifo_file_path
do
  local args = gwfd.parse_args(arg)
  fifo_file_path = args.fifo
end

local dkjson = require("dkjson")

-- Absolute path to the output fifo file
local file = assert(io.open(fifo_file_path, "w"))

-- Read the logs with logread to get all logs until now
-- followed by logread -f to read any future log messages
local logs = assert(io.popen("logread && logread -f", 'r'))

file:setvbuf("no")
for line in logs:lines() do
  local msg = {
    uptime = gwfd.get_uptime(),
    msg = gwfd.fixUTF8(line)
  }
  local json = dkjson.encode(msg)
  if not json or #json >= 4094 then
    return false
  end
  file:write(json..'\n')
  file:flush()
end

logs:close()
file:close()



