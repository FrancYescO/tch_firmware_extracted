#! /usr/bin/env lua

-- file: mod_dsl.lua

package.path = "/usr/share/ngwfdd/lib/?.lua;" .. package.path

local gwfd = require("gwfd-common")

-- Uloop and logger

local uloop = require("uloop")
local log

-- Uploop timer

local timer
local interval = 1800 * 1000 -- Every 30 minutes

-- Absolute path to the output fifo file

local fifo_file_path = arg[1]

-- DSL related metrics to be fetched from transformer

local dsl_transformer_data = {
  "sys.class.xdsl.@line0.UpstreamMaxRate",
  "sys.class.xdsl.@line0.DownstreamMaxRate",
  "sys.class.xdsl.@line0.UpstreamCurrRate",
  "sys.class.xdsl.@line0.DownstreamCurrRate",
  "sys.class.xdsl.@line0.UpstreamNoiseMargin",
  "sys.class.xdsl.@line0.DownstreamNoiseMargin",
  "sys.class.xdsl.@line0.UpstreamAttenuation",
  "sys.class.xdsl.@line0.DownstreamAttenuation",
  "sys.class.xdsl.@line0.UpstreamPower",
  "sys.class.xdsl.@line0.DownstreamPower",
  "sys.class.xdsl.@line0.XTURVendor",
  "sys.class.xdsl.@line0.XTURCountry",
  "sys.class.xdsl.@line0.XTURANSIStd",
  "sys.class.xdsl.@line0.XTURANSIRev",
  "sys.class.xdsl.@line0.XTUCVendor",
  "sys.class.xdsl.@line0.XTUCCountry",
  "sys.class.xdsl.@line0.XTUCANSIStd",
  "sys.class.xdsl.@line0.XTUCANSIRev",
  "sys.class.xdsl.@line0.UpstreamSESLastShowtime",
  "sys.class.xdsl.@line0.DownstreamSESLastShowtime",
  "sys.class.xdsl.@line0.UpstreamESLastShowtime",
  "sys.class.xdsl.@line0.DownstreamESLastShowtime",
  "sys.class.xdsl.@line0.UpstreamSESCurrentDay",
  "sys.class.xdsl.@line0.DownstreamSESCurrentDay",
  "sys.class.xdsl.@line0.UpstreamESCurrentDay",
  "sys.class.xdsl.@line0.DownstreamESCurrentDay",
  "sys.class.xdsl.@line0.UpstreamSESCurrentQuarter",
  "sys.class.xdsl.@line0.DownstreamSESCurrentQuarter",
  "sys.class.xdsl.@line0.UpstreamESCurrentQuarter",
  "sys.class.xdsl.@line0.DownstreamESCurrentQuarter",
  "sys.class.xdsl.@line0.UpstreamSESTotal",
  "sys.class.xdsl.@line0.DownstreamSESTotal",
  "sys.class.xdsl.@line0.UpstreamESTotal",
  "sys.class.xdsl.@line0.DownstreamESTotal",
  "sys.class.xdsl.@line0.DownstreamCRCLastShowtime",
  "sys.class.xdsl.@line0.UpstreamCRCLastShowtime",
  "sys.class.xdsl.@line0.DownstreamCRCTotal",
  "sys.class.xdsl.@line0.UpstreamCRCTotal",
  "sys.class.xdsl.@line0.DownstreamCRCSinceSync",
  "sys.class.xdsl.@line0.UpstreamCRCSinceSync"
}

-- Send the DSL data

local function send_dsl_data()
  local msg = {}
  local rv, errmsg = gwfd.get_transformer_params(dsl_transformer_data, msg)
  if not rv then
    log:error(errmsg)
    uloop.cancel()
  end

  gwfd.write_msg_to_file(msg, fifo_file_path)
  timer:set(interval) -- reschedule on the uloop
end

-- Main code
uloop.init()

log = gwfd.init("gwfd_dsl", 6, { init_transformer = true })

timer = uloop.timer(send_dsl_data)
send_dsl_data()
xpcall(uloop.run, gwfd.errorhandler)