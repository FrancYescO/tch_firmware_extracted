
local require = require

local ubus = require('ubus').connect()
local WpsState = require('wireless.generic_app.wpsstate').connect(ubus)
local WpsRequest = require('wireless.generic_app.wpsrequest').WpsRequest
local sender = require('wireless.generic_app.sender')

local uloop

local function updateState(enable)
  local state = WpsState()
  state:enable(enable)
end

local function setupEventLoop()
  if not uloop then
    uloop = require 'uloop'
    uloop.init()
  end
end

local function handleEvents()
  if uloop then
    uloop.run()
  end
end

local wps_end_event = {
  error = true, -- no device actually paired
  success = true, -- pairing completed successfully
  idle = true, -- pairing disabled
}

local function wpsled_event(data)
  if data.wps_state == "inprogress" then
    sender.send("started")
  elseif data.wps_state == "session_overlap" then
    sender.send("overlap")
  elseif wps_end_event[data.wps_state] then
    sender.send("end")
    uloop.cancel()
  end
end

local function station_event(data)
  if data.state == "Associated" then
    sender.send("success", data.macaddr)
    uloop.cancel()
  end
end

local function listenForEvents()
  setupEventLoop()
  ubus:listen{
    ["wireless.wps_led"] = wpsled_event,
    ["wireless.accesspoint.station"] = station_event,
  }
end

local function doStateTransition(enable)
  if enable then
    listenForEvents()
  end
  updateState(enable)
  handleEvents()
end

local function main()
  local req = WpsRequest()
  local requested = req:requested()
  if requested then
    doStateTransition(requested=='1')
    req:request('')
    req:save()
  end
  req:close()
end

return {
  main = main
}
