#! /usr/bin/env lua

local gwfd = require("gwfd.common")
local fifo_file_path
local interval
do
  local args = gwfd.parse_args(arg, {interval=1800})
  fifo_file_path = args.fifo
  interval = args.interval
end
local uloop = require("uloop")
local uci = require("uci")

-- Ubus connection

local _, ubus_conn

local uci_cur = uci.cursor()

-- Timer used with the uloop

local timer

-- Collects Ubus data for the given device

local function get_ubus_device_info(msg, deviceName)
  local map = {}
  map["name"] = deviceName
  local t = ubus_conn:call("network.device", "status", map)
  if t then
    msg["up"] = t["up"]
    msg["macaddr"] = t["macaddr"]
    if type(t["statistics"]) == "table" then
      msg["statistics"] = t["statistics"]
    end
    if t["multicast"] then
      msg["is_multicast"] = t["multicast"]
    else
      msg["is_multicast"] = false
    end
  else
    msg["up"] = false
    msg["is_multicast"] = false
    local file = io.open("/sys/class/net/" .. deviceName .. "/address", "r")
    if file then
      msg["macaddr"] = file:read("*l")
      file:close()
    end
  end
end

-- Helper functions

local function get_ip_address(msg, data, need_empty)
  if data["ipv4-address"] then
    for _, v in ipairs(data["ipv4-address"]) do
      if type(v) == "table" and v["address"] then
        msg["ipaddress"] = v["address"]
        return
      end
    end
  end
  if data["ipv6-address"] then
    for _, v in ipairs(data["ipv6-address"]) do
      if type(v) == "table" and v["address"] then
        msg["ipaddress"] = v["address"]
        return
      end
    end
  end

  if need_empty then
    msg["ipaddress"] = ""
  end
end

-- Collects Ubus data for the given device

local function get_ubus_interface_info(msg, interface)
  msg["ipaddress"] = ""
  if interface then
    msg["ifname"] = interface
    local t = ubus_conn:call("network.interface." .. interface, "status", {})
    if t then
      msg["ifuptime"] = t["uptime"]
      msg["proto"]  = t["proto"]
      msg["dnsservers"] = t["dns-server"]
      get_ip_address(msg, t, false)
      if t["data"] and type(t["data"]) == "table" then
        local data = t["data"]
        msg["leasetime"] = data["leasetime"]
        msg["ntpserver"] = data["ntpserver"]
      else
        msg["leasetime"] = 0
        msg["ntpserver"] = ""
      end
      return
    end
  end
  msg["ifname"] = ""
  msg["ifuptime"] = 0
  msg["proto"]  = ""
  msg["dnsservers"] = {}
  msg["leasetime"] = 0
  msg["ntpserver"] = ""
end

-- Collects data from device and send message

local function send_device_message(deviceName, deviceType)
  local interface = nil
  local cur = uci.cursor()
  cur:foreach("network", "interface", function(s)
    if s['ifname'] == deviceName then
      interface = s['.name']
    end
  end)
  local msg = {}
  msg["name"] = deviceName
  msg["type"] = deviceType

  get_ubus_device_info(msg, deviceName)
  get_ubus_interface_info(msg, interface)
  gwfd.write_msg_to_file(msg, fifo_file_path)
end

-- Get data from DSL wan devices

local function send_wan_dsl()
  uci_cur:foreach("xtm", "ptmdevice", function(s)
    send_device_message(s['.name'], "ptmdevice")
  end)
  uci_cur:foreach("xtm", "atmdevice", function(s)
    send_device_message(s['.name'], "atmdevice")
  end)
end

-- Get data from ethernet wan devices

local function send_wan_eth()
  uci_cur:foreach("ethernet", "port", function(s)
    if s['wan'] == "1" then
      send_device_message(s['.name'], "ethernetdevice")
    end
  end)
end

-- Send all wan related data

local function send_wan_data()
  send_wan_eth()
  send_wan_dsl()
  timer:set(interval) -- reschedule on the uloop
end

local function is_wan_device(deviceName)
  local is_wan = false

  if not deviceName then
    return false
  end

  -- Remove alias prefix from device name
  deviceName = deviceName:match("@?(.*)")

  -- Find the device name beneath VLAN interface
  local tmp = gwfd.get_uci_param("network." .. deviceName .. ".ifname")
  while tmp do
    deviceName = tmp
    tmp = gwfd.get_uci_param("network." .. deviceName .. ".ifname")
  end
  _, _, tmp = string.find(deviceName, "^(.*)[.]%d+$")
  if tmp then
    deviceName = tmp
  end

  uci_cur:foreach("ethernet", "port", function(s)
    if s['.name'] == deviceName and s['wan'] == "1" then
      is_wan = true
    end
  end)
  if is_wan then
    return true
  end
  uci_cur:foreach("xtm", "ptmdevice", function(s)
    if s['.name'] == deviceName then
      is_wan = true
    end
  end)
  if is_wan then
    return true
  end
  uci_cur:foreach("xtm", "atmdevice", function(s)
    if s['.name'] == deviceName then
      is_wan = true
    end
  end)
  return is_wan
end

-- Interface eventHandler

local function handle_interface_event(event)
 if next(event) then
   local msg = {}

   local deviceName = gwfd.get_uci_param("network." .. event["interface"] .. ".ifname")
   if not is_wan_device(deviceName) then
     return
   end

   msg["suffix"] = "event"
   msg["ifname"] = event["interface"]
   msg["name"] = deviceName
   if event["action"] then
     msg["event"] = event["action"]
     msg["ipaddress"] = ""
   else
     get_ip_address(msg, event, true)
     msg["event"] = "addr_change"
   end

   gwfd.write_msg_to_file(msg, fifo_file_path)
 end
end
-- Main
-- tune the lua garbage collector to be more aggressive and reclaim memory sooner
-- default value of setpause is 200, set it to 100
collectgarbage("setpause",100)
collectgarbage("collect")
collectgarbage("restart")

uloop.init()
_, ubus_conn = gwfd.init("gwfd_wan", 6, { return_ubus_conn = true })
ubus_conn:listen({["network.interface"] = handle_interface_event})

timer = uloop.timer(send_wan_data)
send_wan_data()
xpcall(uloop.run, gwfd.errorhandler)
