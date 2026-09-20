#!/usr/bin/env lua

local dsl=require('transformer.shared.xdslctl')


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
  local status=value('status')
  print("Status: " .. status)
  print("Last Retrain Reason:\t" .. lrtr_to_number(value('lrtr')))
  print("Last initialization procedure status:\t" .. value('lips'))

  if ( status == "Showtime") then
    local rates=value('maxrate');
    print("Max:\tUpstream rate = " .. tostring(rates['us']) .. " Kbps, Downstream rate = " .. tostring(rates['ds']) .. " Kbps" )

    rates=dsl.infoValue('currentrate');
    print("Bearer:\t0, Upstream rate = " .. tostring(rates['us']) .. " Kbps, Downstream rate = " .. tostring(rates['ds']) .. " Kbps\n" )
  else
    print("")
  end
end


local function uprate()
  print(dsl.infoValue('currentrate')['us'])
end


local function downrate()
  print(dsl.infoValue('currentrate')['ds'])
end


local function status()
  print("Status: " .. dsl.infoValue('status'))
end


local function updownrate()
local us
local ds

  us = dsl.infoValue('currentrate')['us']
  ds = dsl.infoValue('currentrate')['ds']

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

