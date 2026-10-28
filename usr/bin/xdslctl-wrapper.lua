#!/usr/bin/env lua

local luabcm=require('luabcm')
local dsl=luabcm.getMinimalDSLStatistics(0)

local function lrtr_to_number(lrtr)
  if lrtr == "LOS Detector" then
    return 0
  elseif lrtr == "RDI Detector" then
    return 1
  end
  return lrtr
end


local function usage()
  io.stderr:write("Usage: xdslctl-wrapper.lua\n")
  io.stderr:write("       xdslctl-wrapper.lua info\n")
  io.stderr:write("       xdslctl-wrapper.lua status\n")
  io.stderr:write("       xdslctl-wrapper.lua uprate\n")
  io.stderr:write("       xdslctl-wrapper.lua downrate\n")
  io.stderr:write("       xdslctl-wrapper.lua updownrate\n")
  io.stderr:write("       xdslctl-wrapper.lua --help\n")
end


local function info()
  local value=dsl.infoValue

  print("xdslctl: ADSL driver and PHY status")
  local status=dsl['status']
  print("Status: " .. status)
  print("Last Retrain Reason:\t" .. lrtr_to_number(dsl['LastRetrainReason']))
  print("Last initialization procedure status:\t" .. dsl['LastInitializationProcedureStatus'])

  if ( status == "Showtime") then
    print("Max:\tUpstream rate = " .. tostring(dsl['UpstreamMaxBitRate']) .. " Kbps, Downstream rate = " .. tostring(dsl['DownstreamMaxBitRate']) .. " Kbps" )
    print("Bearer:\t0, Upstream rate = " .. tostring(dsl['UpstreamCurrRate']) .. " Kbps, Downstream rate = " .. tostring(dsl['DownstreamCurrRate']) .. " Kbps\n" )
  else
    print("")
  end
end


local function uprate()
  print(dsl['UpstreamCurrRate'])
end


local function downrate()
  print(dsl['DownstreamCurrRate'])
end


local function status()
  print("Status: " .. dsl['status'])
end


local function updownrate()
local us
local ds

  us = dsl['UpstreamCurrRate']
  ds = dsl['DownstreamCurrRate']

  print(us .. " " .. ds)
  -- returns (just the values):
  -- <upstram rate> <downstream rate>
  -- expressed in kbit/s
end


if not arg[1] or arg[1] == '--help' then
  usage()
elseif arg[1] == 'info' then
  info()
elseif arg[1] == 'uprate' then
  uprate()
elseif arg[1] == 'downrate' then
  downrate()
elseif arg[1] == 'status' then
  status()
elseif arg[1] == 'updownrate' then
  updownrate()
else
  usage()
end

