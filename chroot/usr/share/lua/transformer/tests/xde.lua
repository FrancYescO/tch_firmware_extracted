--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local require, print, ipairs, tonumber = require, print, ipairs, tonumber
local format, gsub = string.format, string.gsub

local dkjson = require("dkjson")
local lunit = require("lunit")
local bit = require("bit")
module(... or "xde", lunit.testcase, package.seeall)

local assert_not_nil,       assert_true,       assert_equal,       assert_nil=
      lunit.assert_not_nil, lunit.assert_true, lunit.assert_equal, lunit.assert_nil
local assert_match =
      lunit.assert_match

local DEBUG = false

local function printf(fmt, ...)
  if DEBUG then
    print(format(fmt, ...))
  end
end

local proxy = require("datamodel-bck")
local unix = require("tch.socket.unix")
local msg = require("transformer.msg").new()

local subscriptions = {}
local uuid
local listener
local address

local function new_uuid()
  local uuid
  local fd = io.open("/proc/sys/kernel/random/uuid", "r")
  if fd then
    uuid = fd:read('*l')
    uuid = gsub(uuid,"-","")
    fd:close()
  end
  return uuid
end

local SUBTYPE_UPDATE = 1
local SUBTYPE_ADD = 2
local SUBTYPE_DEL = 3

local function get_value(uuid, path, display)
  display = (display==nil) and true or display
  local values, err = proxy.get(uuid, path)
  if not values then
    printf("error retrieving value of %s: %s", path, err)
    return
  end
  for _, entry in ipairs(values) do
    if display then
      printf("%s%s : %s = '%s'",
              entry.path,
              entry.param,
              entry.type,
              entry.value)
    end
  end
  if #values==1 then
    return values[1].value
  else
    return ""
  end
end

local function subscribe(uuid, path, subtype, options)
  options = options or 0
  local id, nonevented = proxy.subscribe(uuid, path, address, subtype, options)
  if not id then
    return nil, nonevented
  end
  local sub = {
    uuid = uuid,
    id = id,
    nonevented = nonevented
  }
  subscriptions[#subscriptions+1] = sub
  return sub
end

local function receive_event()
  local events = {}
  local is_last = false
  while not is_last do
    local data, from = listener:recvfrom()
    if not data then
      printf("error while receiving: %s", from)
      return
    end
    local tag
    local uuid
    tag, is_last, uuid = msg:init_decode(data)
    if tag == msg.tags.EVENT then
      local event = msg:decode()
      printf("EVENT subscription=%d, path=%s, event=%d",
                event.id,
                event.path,
                event.eventmask)
      events[#events+1] = event
    end
  end
  return events
end

local function unsubscribe_all(subscriptions)
  for _, sub in ipairs(subscriptions) do
    proxy.unsubscribe(uuid, sub.id)
  end
end

local function sleep(n)
  os.execute("sleep " .. tonumber(n))
end

local function check_id(ids, id)
  if ids[id] ~= nil then
    ids[id] = nil
  else 
    assert_not_nil(ids[id])
  end
end

function setup()
  uuid = uuid or new_uuid()
  subscriptions = {}

  listener = unix.dgram(bit.bor(unix.SOCK_NONBLOCK, unix.SOCK_CLOEXEC))
  address = 'listener-'..uuid
  local ok, err = listener:bind(address)
  assert_true(ok ~= nil)
end

function teardown()
  unsubscribe_all(subscriptions)
  subscriptions = {}
  uuid = nil
  listener:close()
end

local function getUCIPath(subpath, value)
  -- get the subtree
  local subtree, err = proxy.get(uuid, subpath)
  assert_true(subtree ~= nil)

  -- search for the requested value and return path
  for _, entry in ipairs(subtree) do
    if entry.value == value then
      return entry.path .. entry.param
    end
  end

  return nil
end

function test_check_xde_single_event()
  local results
  local path = "InternetGatewayDevice.LANDevice.1.WLANConfiguration.1.SSID"
  local ucipath

  -- get the original ssid
  local ssid, err = proxy.get(uuid, path)
  assert_true(ssid ~= nil)
  assert_equal(1, #ssid)

  -- get the corresponding uci path
  ucipath = getUCIPath("uci.wireless.wifi-iface.", ssid[1].value)
  assert_true(ucipath ~= nil)

  local sub, err = subscribe(uuid, path, SUBTYPE_UPDATE, 1)
  assert_not_nil(sub, err)

  -- wireless.wl0.ssid=TNCAPC59D0D
  -- results, err = proxy.set(uuid, "Puppet.XDEPath", "uci.wireless.wifi-iface.@wl1.ssid")
  results, err = proxy.set(uuid, "Puppet.XDEPath", ucipath)
  assert_true(results)
  results, err = proxy.set(uuid, "Puppet.XDEValue", "TESTSSID_1")
  assert_true(results)
  results, err = proxy.set(uuid, "Puppet.TriggerXDE", "true")
  assert_true(results)

  -- sleep so events can come in
  sleep(10)

  -- receive the event
  local events = receive_event()
  assert_not_nil(events)
  assert_equal(1, (events and #events) or 0)
  assert_equal(path, events[1].path)

  -- no more events should be waiting
  events = receive_event()
  assert_true(events == nil, format("Still %d events waiting. Event 1: %s", (events and #events) or 0, (events and events[1] and events[1].path) or "Unknown event"))

  -- unsubscribe all events
  unsubscribe_all(subscriptions)

  -- put the ssid back to orig value
  results, err = proxy.set(uuid, path, ssid[1].value)
  assert_true(results)
end

function test_check_xde_multiple_events()
  local results
  local path = "InternetGatewayDevice.LANDevice.1.WLANConfiguration.1.SSID"
  local ucipath
  local ids = {}

  -- get the original ssid
  local ssid, err = proxy.get(uuid, path)
  assert_true(ssid ~= nil)
  assert_equal(1, #ssid)

    -- get the corresponding uci path
  ucipath = getUCIPath("uci.wireless.wifi-iface.", ssid[1].value)
  assert_true(ucipath ~= nil)

  -- put three subscriptions in place
  local sub1, err = subscribe(uuid, path, SUBTYPE_UPDATE, 1)
  assert_not_nil(sub1, err)
  ids[sub1.id] = sub1.id

  local sub2, err = subscribe(uuid, path, SUBTYPE_UPDATE, 1)
  assert_not_nil(sub2, err)
  ids[sub2.id] = sub2.id

  local sub3, err = subscribe(uuid, path, SUBTYPE_UPDATE, 1)
  assert_not_nil(sub3, err)
  ids[sub3.id] = sub3.id

  -- trigger a change on uci via the Puppet test mapping
  results, err = proxy.set(uuid, "Puppet.XDEPath", ucipath)
  assert_true(results)
  results, err = proxy.set(uuid, "Puppet.XDEValue", "TESTSSID_2")
  assert_true(results)
  results, err = proxy.set(uuid, "Puppet.TriggerXDE", "true")
  assert_true(results)

  -- sleep so events can come in
  sleep(10)

  -- receive the events -- should be three
  local events = receive_event()
  assert_equal(1, (events and #events) or 0)
  assert_equal(path, events[1].path)
  check_id(ids, events[1].id)

  events = receive_event()
  assert_equal(1, (events and #events) or 0)
  assert_equal(path, events[1].path)
  check_id(ids, events[1].id)

  events = receive_event()
  assert_equal(1, (events and #events) or 0)
  assert_equal(path, events[1].path)
  check_id(ids, events[1].id)

  -- no more events should be waiting
  events = receive_event()
  assert_true(events == nil)

  -- unsubscribe all events
  unsubscribe_all(subscriptions)

  -- put the ssid back to orig value
  results, err = proxy.set(uuid, path, ssid[1].value)
  assert_true(results)
end

function test_check_xde_filter_own_events()
  local results
  local path = "InternetGatewayDevice.LANDevice.1.WLANConfiguration.1.SSID"

  -- get the original ssid
  local ssid, err = proxy.get(uuid, path)
  assert_true(ssid ~= nil)
  assert_equal(1, #ssid)

     -- get the corresponding uci path
  local xdepath = getUCIPath("uci.wireless.wifi-iface.", ssid[1].value)
  assert_true(xdepath ~= nil)

  -- put a subscriptions in place
  local sub1, err = subscribe(uuid, path, SUBTYPE_UPDATE, 1)
  assert_not_nil(sub1, err)

  -- trigger a change on uci via the Puppet test mapping
  results, err = proxy.set(uuid, xdepath, "TESTSSID_3")
  assert_true(results)

  -- sleep so events can come in
  sleep(5)

  -- no more events should be waiting
  local events = receive_event()
  assert_nil(events)

  -- unsubscribe all events
  unsubscribe_all(subscriptions)

  -- put the ssid back to orig value
  results, err = proxy.set(uuid, path, ssid[1].value)
  assert_true(results)
end

function test_check_xde_multiple_addwatches_singleevent()
  local results
  local xdepath = "Tests.XDE."
  local usernamepath = "Users.User.1.Username"

  -- do a get to sync otherwise on firstboot (no db yet) the firing of events does not work
  proxy.get(uuid, xdepath)

  -- get the original username
  local username, err = proxy.get(uuid, usernamepath)
  assert_true(username ~= nil)
  assert_equal(1, #username)

  -- put a subscriptions in place on xde path that has two watches:
  --     uci_evsrc.watch(mapping, { set = translate_cb }, "users", "user", nil, nil)
  --     uci_evsrc.watch(mapping, { set = translate_cb }, "users", "user", nil, "username")
  local sub1, err = subscribe(uuid, xdepath, SUBTYPE_UPDATE, 0)
  assert_not_nil(sub1, err)

  -- trigger a cross datamodel change on Username, two watches will be evaluated msut only result in one event
  results, err = proxy.set(uuid, usernamepath, "TESTUSERNAME")
  assert_true(results)

  -- sleep so events can come in
  sleep(5)

  -- receive the event
  local events = receive_event()
  assert_not_nil(events)
  assert_equal(1, (events and #events) or 0)
  assert_match(xdepath, events[1].path)

  -- no more events should be waiting
  events = receive_event()
  assert_nil(events)

  -- unsubscribe all events
  unsubscribe_all(subscriptions)

  -- put the Username back to orig value
  results, err = proxy.set(uuid, usernamepath, username[1].value)
  assert_true(results)
end

function test_check_ubus_single_event()
  -- make sure the entries are added to the DB
  local path = "InternetGatewayDevice.LANDevice.1.LANHostConfigManagement.IPInterface.1.IPInterfaceIPAddress"
  local results, err = proxy.get(uuid, path)
  assert_not_nil(results, err)
  -- subscribe
  local sub
  sub, err = subscribe(uuid, path, SUBTYPE_UPDATE)
  assert_not_nil(sub, err)
  -- trigger ubus event
  results, err = proxy.set(uuid, "Puppet.UbusEventID", "network.interface")
  assert_true(results)
  local data = dkjson.encode({
    interface = "lan",
    ["ipv4-address"] = { "10.11.12.13" }
  })
  results, err = proxy.set(uuid, "Puppet.UbusEventData", data)
  assert_true(results, err)
  results, err = proxy.set(uuid, "Puppet.TriggerUbusEvent", "1")
  assert_true(results, err)
  -- sleep so events can come in
  sleep(3)
  -- receive the event
  local events = receive_event()
  assert_not_nil(events)
  assert_equal(1, (events and #events) or 0)
  assert_match(path, events[1].path)
  -- no more events should be waiting
  events = receive_event()
  assert_nil(events)
end

function test_check_ubus_multiple_events()
  -- make sure the entries are added to the DB
  local path = "InternetGatewayDevice.LANDevice.1.LANHostConfigManagement.IPInterface.1.IPInterfaceIPAddress"
  local results, err = proxy.get(uuid, path)
  assert_not_nil(results, err)
  -- subscribe three times
  local ids = {}
  local sub1, sub2, sub3
  sub1, err = subscribe(uuid, path, SUBTYPE_UPDATE)
  assert_not_nil(sub1, err)
  ids[sub1.id] = sub1.id
  sub2, err = subscribe(uuid, path, SUBTYPE_UPDATE)
  assert_not_nil(sub2, err)
  ids[sub2.id] = sub2.id
  sub3, err = subscribe(uuid, path, SUBTYPE_UPDATE)
  assert_not_nil(sub3, err)
  ids[sub3.id] = sub3.id
  -- trigger ubus event
  results, err = proxy.set(uuid, "Puppet.UbusEventID", "network.interface")
  assert_true(results)
  local data = dkjson.encode({
    interface = "lan",
    ["ipv4-address"] = { "10.11.12.14" }
  })
  results, err = proxy.set(uuid, "Puppet.UbusEventData", data)
  assert_true(results, err)
  results, err = proxy.set(uuid, "Puppet.TriggerUbusEvent", "1")
  assert_true(results, err)
  -- sleep so events can come in
  sleep(3)
  -- receive the events; should be three
  local events = receive_event()
  assert_not_nil(events)
  assert_equal(1, (events and #events) or 0)
  assert_match(path, events[1].path)
  check_id(ids, events[1].id)
  events = receive_event()
  assert_not_nil(events)
  assert_equal(1, (events and #events) or 0)
  assert_match(path, events[1].path)
  check_id(ids, events[1].id)
  events = receive_event()
  assert_not_nil(events)
  assert_equal(1, (events and #events) or 0)
  assert_match(path, events[1].path)
  check_id(ids, events[1].id)
  -- no more events should be waiting
  events = receive_event()
  assert_nil(events)
end
