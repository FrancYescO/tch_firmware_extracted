#! /usr/bin/env lua

local gwfd = require("gwfd.common")
local fifo_file_path
local interval
do
  local args = gwfd.parse_args(arg, {interval=1800})
  fifo_file_path = args.fifo
  interval = args.interval
end

-- Library to read DSL parameters

local status, bcm = pcall(require, 'luabcm')
if not status then
  os.exit(0)
end

-- Ubus Connection

local ubus_conn

-- Uloop and logger

local uloop = require("uloop")
local log

-- Uploop timer

local timer

-- XDSL Ubus Path

local xdsl_path = "xdsl"

-- DSL related metrics to be fetched from transformer

local dsl_transformer_data = {
  "sys.class.xdsl.@line0.UpstreamMaxRate",
  "sys.class.xdsl.@line0.DownstreamMaxRate",
  "sys.class.xdsl.@line0.UpstreamCurrRate",
  "sys.class.xdsl.@line0.DownstreamCurrRate",
  "sys.class.xdsl.@line0.UpstreamNoiseMargin",
  "sys.class.xdsl.@line0.DownstreamNoiseMargin",
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

-- Get overall Attenuation

local function add_attenuation_data(msg)
  local stats = bcm.getAdslMib(0)

  local usAttenuation = tonumber(stats.UpstreamAttenuation)
  if usAttenuation then
    msg.UpstreamAttenuation = usAttenuation
  end

  local dsAttenuation = tonumber(stats.DownstreamAttenuation)
  if dsAttenuation then
    msg.DownstreamAttenuation = dsAttenuation
  end
end

-- Send the DSL data

local delta_params = gwfd.set {
  "DownstreamCRCLastShowtime", "UpstreamCRCLastShowtime",
  "UpstreamSESLastShowtime", "DownstreamSESLastShowtime"
}

local cache = {}

local function send_dsl_data()
  local msg = {}
  local rv, errmsg = gwfd.get_transformer_params(dsl_transformer_data, msg)
  if not rv then
    log:error(errmsg or "mod_dsl.lua: Failed to get dsl_transformer_data")
    uloop.cancel()
  end

  add_attenuation_data(msg)

  -- Calculate deltas
  for k, v in pairs(msg) do
    if delta_params[k] then
      if cache[k] then
        msg[k .. "Delta"] = v - cache[k]
        cache[k] = v
      else -- Initial
        msg[k .. "Delta"] = 0
        cache[k] = v
      end
    end
  end

  local status_reply = ubus_conn:call(xdsl_path, "status", {})
  local data = {}
  data.suffix = "status"
  if nil ~= status_reply then
    data.status = status_reply.status
  else
    data.status = "Unknown"
  end

  gwfd.write_msg_to_file(data, fifo_file_path)
  gwfd.write_msg_to_file(msg, fifo_file_path)

  timer:set(interval) -- reschedule on the uloop
end

-- Handler functions

--[[ Handle xdsl status change
-- Event : xdsl
-- Example message:  { "status": "Idle", "statuscode": 0 }
-- Meaning:
-- Idle 0
-- G.994 Training 1
-- G.992 Started 2
-- G.922 Channel Analysis 3
-- G.992 Message Exchange 4
-- Showtime 5
-- G.993 Started 6
-- G.993 Channel Analysis 7
-- G.993 Message Exchange 8
--]]

local function handle_dsl_status_change(msg)
  if next(msg) then
    local data = {}
    data.suffix = "status"
    data.status = msg.status
    gwfd.timed_write_msg_to_file(data, fifo_file_path)
  end
end

-- Map of event handlers

local dsl_events = {}
dsl_events[xdsl_path] = handle_dsl_status_change

-- Register an event listener with ubus

local function monitor_ubus_event(event)
  local handler = dsl_events[event]
  if nil == handler then
    return
  end
  ubus_conn:listen({ [event] = handler })
end

-- Main code
uloop.init()

log, ubus_conn = gwfd.init("gwfd_dsl", 6, { return_ubus_conn = true, init_transformer = true })

monitor_ubus_event(xdsl_path)

timer = uloop.timer(send_dsl_data)
send_dsl_data()

xpcall(uloop.run, gwfd.errorhandler)
