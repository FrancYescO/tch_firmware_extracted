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
local proxy = require("datamodel")

local M = {}

local function open_logfile(filename)
  local fd = io.open(filename, "a")
  if not fd then
     -- exception handle ... do not dangle the file description
     fd = io.stderr
  else
     fd:setvbuf("no")
  end
  fd:write("XXXXXXXXXXXXXXXXXXX luasyslog.lua started XXXXXXXXXXXXXXXXXXX")
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

local function init_buffer(bufCfg)
  assert(type(bufCfg) == "table")

  local logPath = string.format("%s/%s", bufCfg.tmpfs, bufCfg.logdir)
  local lpfd = io.open(logPath)
  if not lpfd then
     if not lfs.mkdir(logPath) then
        return nil,nil, "create "..logPath.." failed"
     end
   else
     lpfd:close()
   end

   local logBuffer = string.format("%s/%s", logPath, bufCfg.logname)
   local lbfd = io.open(logBuffer, "w+")
   if not lbfd then
      return nil,nil,"create "..logBuffer.." failed"
   else
      bufCfg.fd = lbfd
      bufCfg.file = logBuffer
      bufCfg.length = 0
      bufCfg.fd:setvbuf("no")
   end
  local timer_update = os.time()
  return bufCfg,timer_update
end

local function write_logfile(v,s)
  if v.enabled == "0" then return end
  if v.size == 0 then return end
  local timechkenabled = "0"
  local timeSet = "0"
  local rc
  rc = proxy.get("sys.log.EnableGWLogTimeValidation")
  if (rc and rc[1] and ((rc[1].value == "0") or (rc[1].value == "1"))) then
    timechkenabled = rc[1].value
  end
  rc = proxy.get("sys.log.ValidTimeSet")
  if (rc and rc[1] and ((rc[1].value == "0") or (rc[1].value == "1"))) then
    timeSet = rc[1].value
  end
  if timechkenabled  == "1" and timeSet == "0" then
     local replaceString = "0"
     rc = proxy.get("sys.log.InvalidTimeReplacemntString")
      if (rc and rc[1] and rc[1].value) then
        replaceString = rc[1].value
      end
     s = string.gsub(s,"%a%a%a(.-)%d%d%d%d%s" , replaceString)
  end
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

local function write_logfiles(s, rules)
  for _,v in ipairs(rules) do
      if v.fd ~=nil then
         -- xor to invert for blacklist/whitelist matching
         if (v.pattern and (v.isBlackList == not match_patterns(v.pattern,s)))
            or v.logall then
            write_logfile(v,s)
         end
      end
  end
end

local function copy_buffer_to_logfiles(buffer, rules)
  if buffer.size ~= 0 or buffer.size ~= nil then
    buffer.fd:seek("set")
    for s in buffer.fd:lines() do
       write_logfiles(s,rules)
    end
    buffer.fd:close()
    -- initialize buffer again
    local res,timer_update, errmsg = init_buffer(buffer)
    return timer_update
  end
end

function M.handle_message(s, rules, buffer, timer_start,timeout)
  local sLen = #s
  if buffer.size == 0 then
     -- have no period automatic sync
     -- buffer still have enough space to save string
     write_logfiles(s, rules)
     return 0
  elseif buffer.size ~=nil and buffer.size ~= 0 then
    if sLen < (buffer.size - 1 - buffer.length) then
      if timeout == 0 then
         buffer.fd:write(s.."\n")
         buffer.length = buffer.length + sLen + 1
      elseif timeout > 0 then
         local timer_end = os.time()
         local timer = timer_end - timer_start
         if (timer  < timeout) or (timer >= timeout and sLen ==0)then
             -- period not reach timeout
             -- or period reach timeout but nothing in the current buffer
             buffer.fd:write(s.."\n")
             buffer.length = buffer.length + sLen + 1
             local timer_update = 0
             return timer_update
         elseif timer >= timeout and sLen ~= 0 then
             local timer_update = copy_buffer_to_logfiles(buffer, rules)
             write_logfiles(s, rules)
             return timer_update
         end
      end
    elseif sLen > (buffer.size - 1) then
       -- in case long string over the buffer size
       -- copy buffer and write string to file directly
       copy_buffer_to_logfiles(buffer, rules)
       write_logfiles(s, rules)
    else
       -- buffer has not enough space to save string
       copy_buffer_to_logfiles(buffer, rules)
       buffer.fd:write(s.."\n")
       buffer.length = sLen + 1
    end
  end
end

function M.init_logfiles(rules, bufCfg)
 local res,timer_update,errmsg = {},{},{}
  if bufCfg.size == 0 then
     res,timer_update = 0,0
  elseif bufCfg.size ~= nil and bufCfg.size ~= 0 then
     res,timer_update, errmsg = init_buffer(bufCfg)
    if not res then
       return nil,nil, errmsg
   end
  end
  for _,v in ipairs(rules) do
      v.fd = open_logfile(v.file)
      local attrs = lfs.attributes(v.file)
      v.length = attrs and attrs.size or 0
  end
  if timer_update ~= nil and timer_update ~= 0 then
     local timer_start = timer_update
     return res,timer_start
  elseif timer_update == 0 then
     return res,0,nil
  end
end

function M.close_logfiles(rules)
  for _,v in ipairs(rules) do
      if v.fd then
         v.fd:close()
      end
  end
end


function M.buffer_uci_get(config, sectype)
  local c = require("uci").cursor()
  local buffers = {}
  local t = c:get_all(config, sectype)
  if t ~= nil then
      local size = tonumber(t.size)
      local timeout = tonumber (t.timeout)
      if t.logname and size and timeout then
         buffers.size = (size > 0) and size or 0
         buffers.timeout = (timeout > 0) and timeout or 0
         buffers.logname = t.logname
      end
  elseif t == nil then
         buffers.size = 0
         buffers.timeout = 0
         buffers.logname = defaut
  end
  c:close()
  return buffers
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
         r.enabled = t.enabled
         r.isBlackList = (t.isBlackList == "1")

         rules[#rules+1] = r
      end
    end
  )

  c:close()
  return rules
end

function M.sync_buffer_ifneed(sync_buffer_file, rules, buffer)
  local syncfd = io.open(sync_buffer_file)
  if syncfd and buffer.size ~= nil and buffer.size ~= 0 then
     local timer_update = copy_buffer_to_logfiles(buffer, rules)
     syncfd:close()
     os.remove(sync_buffer_file)
   end
   return timer_update
end

function M.sync_buffer_ifstop(rules, buffer)
  if buffer.size ~= nil and buffer.size ~= 0 then
     local timer_update = copy_buffer_to_logfiles(buffer, rules)
  end
  return timer_update
end

return M
