#! /usr/bin/env lua

-- file: mod_voice.lua

package.path = "/usr/share/ngwfdd/lib/?.lua;" .. package.path

local gwfd = require("gwfd-common")
local uloop = require("uloop")

-- Absolute path to the fifo file

local fifo_file_path = arg[1]

-- UBUS connection

local _, ubus_conn

-- Key call quality / state metrics
-- They are the ONLY ones collected from the "mmpbx.X" event(s)

local call_metrics = {
  ["mmpbx.callQualityLogUpdate"] = {
    "key",
    "mosLQ",
    "mosCQ",
    "remoteMosLQ",
    "remoteMosCQ",
    "rFactor",
    "externalRFactor",
    "remoteRFactor",
    "remoteExternalRFactor",
    "rxJitter",
    "remoteRxJitter"
  },
  ["mmpbx.callstate"] = {
    "callState",
    "device",
    "direction",
    "key",
    "oldState",
    "profile",
    "profileType",
    "reason"
  }
}

-- An Enum representation of the SIP registration status

local registered_status = {}
registered_status["Unregistered"] = 1
registered_status["Registering"] = 2
registered_status["RE-Registering"] = 3
registered_status["Registered"] = 4

-- An Enum representation of the call state

local call_state = {}
call_state[0] = "IDLE"
call_state[1] = "DIALING"
call_state[2] = "DELIVERED"
call_state[3] = "ALERTING"
call_state[4] = "DISCONNECTED"
call_state[5] = "CONNECTED"
call_state[6] = "UNKNOWN"

-- Cache for the call start time.
-- This is filled in upon a call connected state.
-- E.g., call_start_time["call_key"] = start_time

local call_start_time = {}

-- Ubus getter(s)

-- Get and send the statistics per profile
-- E.g., incoming/outgoing failed calls, etc.
-- Topic: mmdbd.profile.statistics

local function send_profile_stats()
  local stats_per_profile = ubus_conn:call("mmdbd.profile.statistics", "get", {})
  if type(stats_per_profile) == "table" then
    local profile_stat
    for _, v in pairs(stats_per_profile) do
      if type(v) == "table" then
        profile_stat = v
        profile_stat.suffix = "profile_stats"
        gwfd.write_msg_to_file(profile_stat, fifo_file_path)
      end
    end
  end
end

-- Event handlers

-- Handle call state metrics collection
-- Event : mmpbx.callstate
local key_ms_call_state

local function handle_call_state(msg)
  if next(msg) then
    local data = {}

    if call_state[msg.callState] == "CONNECTED" then
      call_start_time[msg.key] = gwfd.get_uptime()
    elseif call_state[msg.callState] == "DISCONNECTED" then

      local start_time = call_start_time[msg.key]
      if start_time then
        data["duration"] = gwfd.get_uptime() - start_time
        call_start_time[msg.key] = nil
      else
        data["duration"] = -1
      end

      for k, v in pairs(msg) do
        if (key_ms_call_state[k]) then
          if k == "callState" or k == "oldState" then
            data[k] = call_state[v]
          else
            data[k] = v
          end
        end
      end

      if next(data) then
        data.suffix = "call_state"
        gwfd.timed_write_msg_to_file(data, fifo_file_path)
      end
    end
  end
end

-- Handle call quality metrics collection
-- Event : mmpbx.callQualityLogUpdate
local key_ms_call_quality_log

local function handle_call_quality_log_update(msg)
  if next(msg) then
    local data = {}

    for k, v in pairs(msg) do
      if (key_ms_call_quality_log[k]) then
        data[k] = v
      end
    end

    if next(data) then
      data.suffix = "quality"
      gwfd.timed_write_msg_to_file(data, fifo_file_path)
    end
  end
  send_profile_stats()
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

-- Handlers for the events

local mmpbx_events = {}
mmpbx_events["mmpbx.profile.status"] = handle_profile_status_change
mmpbx_events["mmpbx.callQualityLogUpdate"] = handle_call_quality_log_update
mmpbx_events["mmpbx.callstate"] = handle_call_state


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

local errmsg
key_ms_call_state, errmsg = gwfd.set(call_metrics["mmpbx.callstate"])
assert(key_ms_call_state, errmsg)

key_ms_call_quality_log, errmsg = gwfd.set(call_metrics["mmpbx.callQualityLogUpdate"])
assert(key_ms_call_quality_log, errmsg)

_, ubus_conn = gwfd.init("gwfd_voice", 6, { return_ubus_conn = true })

monitor_ubus_event("mmpbx.callstate")
monitor_ubus_event("mmpbx.profile.status")
monitor_ubus_event("mmpbx.callQualityLogUpdate")

xpcall(uloop.run, gwfd.errorhandler)
