#! /usr/bin/env lua

-- file: mod_voice.lua

package.path = "/usr/share/ngwfdd/lib/?.lua;" .. package.path

local gwfd = require("gwfd-common")
local uloop = require("uloop")

-- Logger

local log

-- Absolute path to the fifo file

local fifo_file_path = arg[1]

-- UBUS connection

local ubus_conn

-- Key call quality metrics
-- They are the ONLY ones collected from the "mmpbx.callQualityLogUpdate" event

local call_quality_metrics = {
  ["mmpbx.callQualityLogUpdate"] = {
    "key", "mosLQ", "mosCQ", "remoteMosLQ", "remoteMosCQ",
    "rFactor", "externalRFactor", "remoteRFactor",
    "remoteExternalRFactor", "rxJitter", "remoteRxJitter"
  }
}

-- An Enum representation of the SIP registration status

local registered_status = {}
registered_status["Unregistered"] = 1
registered_status["Registering"] = 2
registered_status["RE-Registering"] = 3
registered_status["Registered"] = 4

-- Event handlers

-- Handle call quality metrics collection
-- Event : mmpbx.callQualityLogUpdate

local function handle_call_quality_log_update(msg)
  local key_ms, errmsg = gwfd.set(call_quality_metrics["mmpbx.callQualityLogUpdate"])
  assert(key_ms, errmsg)

  local data = {}

  for k, v in pairs(msg) do
    if (key_ms[k]) then
      data[k] = v
    end
  end

  if next(data) then
    data.suffix = "quality"
    gwfd.timed_write_msg_to_file(data, fifo_file_path)
  end
end

-- Handle SIP profile change msg
-- Event : mmpbx.profile.status

local function handle_profile_status_change(msg)
  local data = msg

  if next(data) then
    if type(data.sip) == "table" then
      if data.sip[1].registered and data.sip.newest.registered and data.sip.oldest.registered then
        data.sip[1].regVal = registered_status[data.sip[1].registered]
        data.sip.newest.regVal = registered_status[data.sip.newest.registered]
        data.sip.oldest.regVal = registered_status[data.sip.oldest.registered]
        data.suffix = "reg_status"
        gwfd.timed_write_msg_to_file(data, fifo_file_path)
      end
    end
  end
end

-- End of handlers

-- Ubus getters

-- Get the statistics per profile
-- E.g., incoming/outgoing failed calls, etc.
-- Topic: mmpbx.profile.stats

local function get_profile_stats()

  --Not implemented on the GW
end

-- Get the statistics per device
-- E.g., incoming/outgoing failed calls, etc.
-- Topic: mmpbx.device.stats

local function get_device_stats()

  -- Not implemented on the GW
end

-- Handlers for the events

local mmpbx_events = {}
mmpbx_events["mmpbx.profile.status"] = handle_profile_status_change
mmpbx_events["mmpbx.callQualityLogUpdate"] = handle_call_quality_log_update

-- Register an event listener with ubus

local function monitor_ubus_event(event)
  local handler = mmpbx_events[event]
  if nil == handler then
    return
  end
  ubus_conn:listen({ [event] = handler })
end

-- Main code
uloop.init()

log, ubus_conn = gwfd.init("gwfd_voice", 6, { return_ubus_conn = true })

monitor_ubus_event("mmpbx.profile.status")
monitor_ubus_event("mmpbx.callQualityLogUpdate")

xpcall(uloop.run, gwfd.errorhandler)
