--[[
The structure of rules would be like this:
local rules = {
  {
    file = '/tmp/log/messages.log',
    size = 512,
    rotate = 9,
    logall = true, -- log all messages into files without pattern
    length = 0,    -- a field to indicate current size of log file
  },
  {
    file = '/tmp/log/kernel.log',
    size = 512,
    rotate = 3,
    pattern = { " kernel:" },
    length = 0,    -- a field to indicate current size of log file
  },
  {
    file = '/tmp/log/xinetd.log',
    size = 512,
    rotate = 5,
    pattern = { " xinetd%[" },
    length = 0,    -- a field to indicate current size of log file
  },
}
]]--

local string, io, os = string, io, os
local ipairs, next = ipairs, next
local lfs = require("lfs")

local M = {}

local function open_logfile(filename)
  local fd = io.open(filename, "a")
  if not fd then
     -- exception handle ... do not dangle the file description
     fd = io.stderr
  else
     fd:setvbuf("no")
  end
  return fd
end

local function rotate_files(v)
  if v.rotate >= 1 then
     local i = v.rotate - 1
     -- rotate files: f.8 -> f.9; f.7 -> f.8; ...
     while i > 0 do
           local newFile = string.format("%s.%d", v.file, i)
           i = i - 1
           local oldFile = string.format("%s.%d", v.file, i)
           os.rename(oldFile, newFile)  -- ignore errors - file might be missing
     end
     os.rename(v.file, string.format("%s.0", v.file))
  end
  v.fd:close()
  os.remove(v.file)
  v.fd = open_logfile(v.file)
  v.length = 0
end

local function match_patterns(patterns, s)
  for _,p in ipairs(patterns) do
      if s:match(p) then
         return true
      end
  end
  return false
end

local function write_logfile(v,s)
  if v.size == 0 then return end
  local sLen = #s
  if (sLen + v.length) >= v.size then
     local remainLen = sLen + v.length - v.size
     v.fd:write(s:sub(1, sLen - remainLen))
     rotate_files(v)
     if remainLen ~= 0 then
        -- still remains string need to be written
        write_logfile(v, s:sub(-remainLen))
     else
        -- just meet the bound of file
        v.fd:write("\n")
        v.length = v.length + 1
     end
  else
     v.fd:write(s.."\n")
     v.length = v.length + sLen + 1
  end
end

function M.handle_message(s, rules)
  for _,v in ipairs(rules) do
      if v.fd ~=nil then
         if (v.pattern and next(v.pattern) ~= nil and match_patterns(v.pattern,s))
            or v.logall then
            write_logfile(v,s)
         end
      end
  end
end

function M.init_logfiles(rules)
  for _,v in ipairs(rules) do
      v.fd = open_logfile(v.file)
      local attrs = lfs.attributes(v.file)
      v.length = attrs and attrs.size or 0
  end
end

function M.close_logfiles(rules)
  for _,v in ipairs(rules) do
      if v.fd then
         v.fd:close()
      end
  end
end

function M.parse_uci(config, sectype)
  local c = require("uci").cursor()
  local rules = {}

  c:foreach(config, sectype,
    function (t)
      local r = {}

      local size = tonumber(t.size)
      local rotate = tonumber (t.rotate)
      if t.path and size and rotate then
         r.file = t.path
         r.size = (size > 0) and size or 0
         r.rotate = (rotate > 0) and rotate or 0
         r.pattern = t.pattern
         r.logall = t.logall and true or false

         rules[#rules+1] = r
      end
    end
  )

  c:close()
  return rules
end

return M
