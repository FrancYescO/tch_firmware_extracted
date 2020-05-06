#!/usr/bin/env lua

-- ************* COPYRIGHT AND CONFIDENTIALITY INFORMATION **********************
-- **                                                                          **
-- ** Copyright (c) 2017 Technicolor                                           **
-- ** All Rights Reserved                                                      **
-- **                                                                          **
-- ** This program contains proprietary information which is a trade           **
-- ** secret of TECHNICOLOR and/or its affiliates and also is protected as     **
-- ** an unpublished work under applicable Copyright laws. Recipient is        **
-- ** to retain this program in confidence and is not permitted to use or      **
-- ** make copies thereof other than as permitted in a written agreement       **
-- ** with TECHNICOLOR, UNLESS OTHERWISE EXPRESSLY ALLOWED BY APPLICABLE LAWS. **
-- **                                                                          **
-- ******************************************************************************
--- The faultmanagement event  helper helps you monitor default gateway status
-- @module faultmgmt_event_monitor
local M = {}
local ubus = require("ubus")
local logger = require('transformer.logger')
local log = logger.new("defaultGW", 6)

local match = string.match
local lower = string.lower
local error = error
local ipairs = ipairs
local pairs = pairs
local type = type
local pcall = pcall
local popen = io.popen

-- UBUS connection
local ubus_conn

-- all default gateways
local defaultGW_t = {}


-- Parse the every default gateway by ubus cmd "network.interface dump"
-- then update the defaultGW table
-- Parameter:
--  interface(string): if exist then only this interface to be updated;
--                     if nil, mean all the interfaces are to be updated.
local function update_default_gateways(interface)
  local x = ubus_conn:call("network.interface", "dump", {})
  if x and x.interface then
    for _,v in ipairs(x.interface) do
      if v["up"]  and v["available"]  and v['ipv4-address'] and v['device'] and (not interface or (v["interface"] == interface)) then
        if v["route"] then
          for _,r in ipairs(v["route"]) do
             if r["target"] == "0.0.0.0" and match(r["nexthop"], "%d+\.%d+\.%d+\.%d+") and r["nexthop"] ~= "0.0.0.0" then
               defaultGW_t[v['interface']] = {
                   device = v['device'],
                   defaultGW = r['nexthop'],
                   }
             else
               -- no default route in this interface, clear the defaultGW in this interface
               defaultGW_t[v['interface']] = {}
             end
          end --route loop end
        else
          -- no route table in this interface, clear the defaultGW in this interface
          defaultGW_t[v['interface']] = {}
        end
      end
    end --interface loop end
  end
end

-- Send out faultMgmt msg about deault gateway
-- parameters:
--   state: the state to be published like:
--       "Linke success"
--       "No respone"
--   ipaddress: default gateway ip address
local function ubus_publish_gateway_state(state, ipaddress)
  if not state or not ipaddress then
      return
  end
  local data = {
      Source = "defaultgw",
      EventType = "Default GW",
      ProbableCause = tostring(state),
      SpecificProblem = "",
      AdditionalInformation = tostring(ipaddress),
  }
  ubus_conn:send('FaultMgmt.Event', data)
end

-- Send out faultMgmt msg about wireless station
-- parameters:
--   cause  : the probable cause of the fault
--   ap     : the AP interface that the station connectes with
--   macaddr: the station's MAC address
--   secmode: the security mode applied in AP
local function ubus_publish_station_state(cause, ap, macaddr, secmode)
  if not cause or not ap or not macaddr or not secmode then
      return
  end

  local data = {
      Source                = "wireless",
      EventType             = "WiFi association",
      ProbableCause         = tostring(cause),
      SpecificProblem       = "",
      AdditionalText        = string.format("MAC=%s, AP=%s, SecMode=%s", macaddr, ap, secmode),
      AdditionalInformation = "",
  }

  ubus_conn:send('FaultMgmt.Event', data)
end

local function ubus_publish_xDSL(cause)
  -- xDSL statistics
  local dslStats = require("luabcm")
  local statsData
  local threshold_slot, threshold = 0, 0

  if not cause then
    return
  end

  statsData = dslStats.getAdslMib(0)
  local data = {
    Source = "xdsl",
    EventType = "xDSL",
    ProbableCause = tostring(cause),
    SpecificProblem = "",
    AdditionalText = string.format("Type=%s, threshold_slot=%d, threshold=%d, ses_error=%d, esdn_error=%d, linit_error=%d",
      statsData["Mode"], threshold_slot, threshold, statsData["TotalSeverelyErroredSecsDs"], statsData["TotalErroredSecsDs"], statsData["TotalRetrainCount"]),
    AdditionalInformation = "",
  }

  ubus_conn:send('FaultMgmt.Event', data)
end

--- Helper function to check that the arguments that are passed to dnsget / ping do not contain special characters that make
-- the call turn into an exploit
-- @param str The string to check
-- @return true if the string does not contain an apparent exploit, false otherwise
local function check_for_exploit(str)
    if str then
    -- try to make sure the string is not an exploit in disguise
    -- it is about to be concatenated to a command so ...
      return match(str,"^[^<>%s%*%(%)%|&;~!?\\$]+$") and not (match(str,"^-") or match(str,"-$"))
    else
      return false
    end
end


-- function that performs the actual arping
-- is pcalled from arping
-- @param address The address / fqdn to arping to
-- @param src_intf The source interface to use, may be set to nil (eth0 will be used).
-- @param src_address The source address to use, may be set to nil (routing table will select best source).
-- @param count The number of arping requests to send.
-- @param broadcast Sent only broadcasts on MAC level, if not set the utility will switch to unicast once a reply is received.
-- @return successes The number of successfull arpings
-- @return failures The number of failed pings
local function run_arping(address, src_intf, src_address, count, broadcast)
   if not address or not check_for_exploit(address) or (src_intf and not check_for_exploit(src_intf)) or (src_address and not check_for_exploit(src_address)) then
      error("Invalid parameters, address = '" .. tostring(address) .. "', src_intf = '" .. tostring(src_intf) .. "', src_address = '" .. tostring(src_address) .. "'")
   end

   if not count then
      count = 1
   end

   --compose the command
   local cmd = 'arping '
   if broadcast then
      cmd = cmd .. '-b -f '
   end
   if src_intf and type(src_intf) == 'string' then
      cmd = cmd .. '-I ' .. src_intf .. ' '
   end
   if src_address and type(src_address) == 'string' then
      cmd = cmd .. '-s ' .. src_address .. ' '
   end

   if count and type(count) == 'number' then
      cmd = cmd .. '-c ' .. count .. ' '
   end

   cmd = cmd .. address .. ' 2>/dev/null'

   local pipe = popen(cmd,'r')
   if pipe then
      local transmitted, received
      for line in pipe:lines() do
        if not transmitted then
          transmitted = match(line,"^Sent (%d+)")
        end
        if not received then
          received = match(line,"^Received (%d+)")
        end
        if transmitted and received then
          pipe:close()
          return tonumber(received),tonumber(transmitted)-tonumber(received)
        end
      end
        pipe:close()
        error( tostring(cmd) .. ' failed')
    else
        error( tostring(cmd) .. ' can not be launched')
    end
end

-- Active probe the host(eg:default gateway) by arping
-- if cmd launch succeed, then send out  "FaultMgmt.Event" accordingly
-- else log error
local function active_probe(address, src_intf, src_address, count, broadcast)
    if count and tonumber(count) == nil then
      return false,"Parameter '" .. tostring(count) .. "' is not a number"
    end

    local status,successes_or_error,failures = pcall(run_arping, address, src_intf, src_address, count, broadcast)
    if status then
      if type(successes_or_error) == "number" and failures == 0 then
        ubus_publish_gateway_state("Link success", address)
      else
        ubus_publish_gateway_state("No response", address)
      end
    elseif type(successes_or_error) == "string" then
      log:error("active probe default gateway return error:" .. successes_or_error)
    end
end


-- Handles an interface up/down event on UBUS
-- When interface up, check if new gateway is set and do active probe
-- Parameters:
--  msg: [table] the UBUS message
local function handle_interface_event(msg)
  -- Reject bad events
  if (type(msg) =="table" and msg['action'] =="ifup"  and  type(msg['interface'])=="string" and msg['interface'] ~= "lan") then

  --check default gateway and probe it if exist
    local interface = msg['interface']
    update_default_gateways(interface)
    local device, defaultGW
    --ipv6 and 6rd is not include so far
    if  defaultGW_t[interface] then
      device, defaultGW = defaultGW_t[interface].device, defaultGW_t[interface].defaultGW
    end
    if device and defaultGW then
      log:debug("get interface %s and defaultGW %s", device, defaultGW)
      active_probe(defaultGW, device, nil, 3, 1)
    end
  end
end

-- Handles an neighbour add/del event on UBUS
-- Parameters:
--  msg: [table] the UBUS message
local function handle_neigh_event(msg)
  --Do not handle neighbor event if no default gateway
  if next(defaultGW_t) == nil then
     log:error("no default gateway now!")
     return
  end

  if (type(msg)~="table" or
    type(msg['mac-address'])~="string" or
    (not match(msg['mac-address'], "%x%x:%x%x:%x%x:%x%x:%x%x:%x%x")) or
    (msg['action']~='add' and msg['action']~='delete') or
    type(msg['interface'])~="string" or
    (not ((type(msg['ipv4-address'])=="table") and type(msg['ipv4-address'].address)=="string" and match(msg['ipv4-address'].address, "%d+\.%d+\.%d+\.%d+")))
    ) then
    log:error("Ignoring improper event")
    return
  end

  local mac = lower(msg['mac-address'])
  local ip = msg['ipv4-address'].address
  local intf = msg['interface']
  local action = msg['action']
  local changed = false
  -- Filter out default gateway state change
  local device, defaultGW
  for _,v in pairs(defaultGW_t) do
    device, defaultGW = v["device"], v["defaultGW"]
    if intf == device and ip == defaultGW  then
      if action == "add" then
        ubus_publish_gateway_state("Link success", ip)
      elseif action == "delete" then
        active_probe(ip, intf, nil, 3, 1)
      end
      break
    end
  end
end

-- Handles an wifi station's auth event on UBUS
-- Parameters:
--  msg: [table] the UBUS message
local function handle_wireless_station_event(msg)
  if (type(msg) ~= "table" or
    msg["ap_name"] == nil or
    msg["macaddr"] == nil) then
    return
  end

  if (msg["state"] ~= "Disconnected" and msg["state"] ~= "Authorized") then
    return -- other states will be ignored
  end

  -- Here only 2 states can reach:
  --     All "disconnected" states including authen-fail, leave, AP down, etc.
  --     Connection built, including auth and non-secret
  -- Then, double check the state details around secret check

  local sta = ubus_conn:call("wireless.accesspoint.station", "get", {})
  if sta == nil then
    return
  end

  local apname   = msg["ap_name"]
  local stations = sta[apname]
  if (stations == nil) then
    return
  end

  local macaddr = msg["macaddr"]
  local stainfo = stations[macaddr]
  if (stainfo == nil) then
    return
  end

  if (stainfo.state == "Disconnected" and stainfo.last_disconnect_reason == "AuthInvalid") then
    -- secret check failure
    ubus_publish_station_state("Authentication failure", apname, macaddr, stainfo.last_authentication)
  elseif (stainfo.state == "Authenticated Associated Authorized") then
    -- passed secret check
    ubus_publish_station_state("Authentication success", apname, macaddr, stainfo.last_authentication)
  end

end

-- Handles the DSL event on UBUS
-- Parameters:
--  msg: [table] the UBUS message
local function handle_dsl_event(msg)
  if (type(msg) ~= "table" or
    msg["status"] == nil) then
      return
  end

  if (msg["status"] == "Showtime") then
    ubus_publish_xDSL("xDSL success")
    return
  end
  if (msg["status"] == "Idle") then
    ubus_publish_xDSL("xDSL error")
    return
  end
end

-- create defaultGW monitor, which will check and monitor the default gateway status,
-- and send out expected ubus event 'FaultMgmt.Event'
function M.create_defaultGW_monitor()
  ubus_conn = ubus.connect()
  if not ubus_conn then
    log:error("Failed to connect to ubus")
  end

  --get default gateways and probe them if exist
  update_default_gateways()
  local device, defaultGW
  for _,v in pairs(defaultGW_t) do
    device, defaultGW = v["device"], v["defaultGW"]
    if device and defaultGW then
      log:debug("get interface %s and defaultGW %s", device, defaultGW)
      active_probe(defaultGW, device, nil, 3, 1)
    end
  end

  --listen to network.interface up/down msg
  ubus_conn:listen({ ['network.interface'] = handle_interface_event} )
  --listen to neighbor monitor event
  ubus_conn:listen({ ['network.neigh'] = handle_neigh_event} )
  --listen to wifi station's auth event
  ubus_conn:listen({ ['wireless.accesspoint.station'] = handle_wireless_station_event} )
  --listen to dsl event
  ubus_conn:listen({ ['xdsl'] = handle_dsl_event} )
end

return M
