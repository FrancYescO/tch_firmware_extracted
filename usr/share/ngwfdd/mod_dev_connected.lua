#! /usr/bin/env lua

-- file: mod_dev_connected.lua

package.path = "/usr/share/ngwfdd/lib/?.lua;" .. package.path

local gwfd = require("gwfd-common")
local uloop = require("uloop")

-- UBUS connection and uploop timer

local _, ubus_conn
local timer
local interval = (tonumber(gwfd.get_uci_param("ngwfdd.interval.devices")) or 3600) * 1000

-- Absolute path to the fifo file

local fifo_file_path = arg[1]

-- Get the devices connected and send their data
-- limit number of ip entries per device to 5, to keep the message length within acceptable bounds
-- to avoid fragmentation when writing to the fifo
local function get_connected_devices()
  local devices = ubus_conn:call("hostmanager.device", "get", {})
  local dev
  for _, v in pairs(devices) do
    if type(v) == "table" then
      dev = v
      for key,value in pairs(v) do 
        if key:match("ipv[46]") then 
          for ip_key,ip_value in pairs(value) do
            ip_idx=tonumber(ip_key:match("ip(%d+)"))
            if ip_idx and ip_idx >= 5 then
              dev[key][ip_key]=nil
            end
          end
        end
      end
      dev["dev_id"] = dev["mac-address"]
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
