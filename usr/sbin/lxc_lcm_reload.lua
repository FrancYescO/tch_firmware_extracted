#!/usr/bin/env lua
local process = require("tch.process")
local evloop_module = require("tch.socket.evloop")
local tch_timerfd = require("tch.timerfd")

local function create_timer_cb(trigger_file, timeout)
  if not trigger_file then
    return function(evloop)
      evloop:close()
    end
  end
  timeout = timeout and tonumber(timeout) or 60
  local count = 0
  return function(evloop, input_socket)
    local fd = io.open(trigger_file, "r")
    if fd then
      fd:close()
      process.execute("/etc/init.d/lcmd", {"reload_ee_packages"})
      evloop:close()
      return
    end
    local missed = tch_timerfd.read(input_socket)
    count = count + missed
    if count > timeout then
      evloop:close()
    end
  end
end

local function main(trigger_file, timeout)
  local evloop = evloop_module:evloop()
  local tfd = tch_timerfd.create()
  local real_fd = tch_timerfd.fd(tfd)
  evloop:add(real_fd, create_timer_cb(trigger_file, timeout))
  tch_timerfd.settime(tfd, 1)
  evloop:run()
end

main(...)
