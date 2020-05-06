#! /usr/bin/env lua

-- file: mod_dev_connected.lua

package.path = "/usr/share/ngwfdd/lib/?.lua;" .. package.path

local gwfd = require("gwfd-common")
local uloop = require("uloop")

-- UBUS connection and uploop timer

local _, ubus_conn
local timer
local interval = 3600 * 1000 -- Hourly

-- Absolute path to the fifo file

local fifo_file_path = arg[1]

-- Get the devices connected and send their data

local function get_connected_devices()
  local devices = ubus_conn:call("hostmanager.device", "get", {})
  local dev
  for k, v in pairs(devices) do
    if type(v) == "table" then
      dev = v
      dev["dev_id"] = k
      gwfd.write_msg_to_file(dev, fifo_file_path)
    end
  end
  timer:set(interval) -- reschedule on the uloop
end

-- Main code
uloop.init()

_, ubus_conn = gwfd.init("gwfd_dev_connected", 6, { return_ubus_conn = true })

timer = uloop.timer(get_connected_devices)
get_connected_devices()
xpcall(uloop.run, gwfd.errorhandler)
