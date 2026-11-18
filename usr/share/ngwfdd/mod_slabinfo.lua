#! /usr/bin/env lua

-- file: mod_slabinfo.lua

package.path = "/usr/share/ngwfdd/lib/?.lua;" .. package.path

local gwfd = require("gwfd-common")

-- Uloop and logger

local uloop = require("uloop")

-- Uploop timer

local timer

-- Get interval from UCI
local interval = (tonumber(gwfd.get_uci_param("ngwfdd.interval.slabinfo")) or 300) * 1000

-- Absolute path to the output fifo file

local fifo_file_path = arg[1]
local regex = "^([^%s]+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+:.*:%s+slabdata%s+%d+%s+(%d+)%s+%d+"

local function send_slabinfo()
  local file = io.open("/proc/slabinfo", "r")

  local line = file:read("*l")
  while line do
    local name, nr_active_objs, nr_objs, obj_size, objs_per_slab, pages_per_slab, nr_slabs  = line:match(regex)
    if name and nr_active_objs and nr_objs and obj_size
       and objs_per_slab and pages_per_slab and nr_slabs then
      local msg = {}
      msg.name = name
      msg.objects = tonumber(nr_objs)
      msg.active_objects = tonumber(nr_active_objs)
      msg.object_size = tonumber(obj_size)
      msg.objects_per_slab = tonumber(objs_per_slab)
      msg.pages_per_slab = tonumber(pages_per_slab)
      msg.slabs = tonumber(nr_slabs)
      gwfd.write_msg_to_file(msg, fifo_file_path)
    end
    line = file:read("*l")
  end

  file:close()

  timer:set(interval) -- reschedule on the uloop
end


-- Main code
uloop.init()

gwfd.init("gwfd_slabinfo", 6, { init_transformer = true })

timer = uloop.timer(send_slabinfo)
send_slabinfo()
xpcall(uloop.run, gwfd.errorhandler)
