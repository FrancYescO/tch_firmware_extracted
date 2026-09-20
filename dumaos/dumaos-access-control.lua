#!/usr/bin/lua

--[[
  (C) 2018 NETDUMA Software
  Kian Cross <kian.cross@netduma.com>
  Iain Fraser <iain.fraser@netduma.com>
--]]

package.path = package.path .. ";/dumaos/api/?.lua;/dumaos/api/libs/?.lua"
require "ubus"
json = require "json"

local device_manager_package_id = "com.netdumasoftware.devicemanager"
local conn = ubus.connect()

function process_device(device, interface)
  return {
    wireless = interface.wifi == 1,
    name = interface.ghost,
    mac = interface.mac,
    id = device.devid,
    blocked = device.block and true or false
  }
end

function case_insensetive_compare(arg1, arg2)
  return string.lower(arg1) == string.lower(arg2)
end

function rpc_call(package, method, arguments)
  arguments = arguments or {}

  local processed_arguments = { proc = method }

  for i, argument in ipairs(arguments) do
    processed_arguments[tostring(i)] = argument
  end

  local status = conn:call(package, "rpc", processed_arguments)

  if status.eid then
    return false
  else
    return true, status.result
  end
end

function get_all_devices()
  local status, result = rpc_call(device_manager_package_id, "get_all_devices")

  assert(status, "Error fetching devices")

  local devices = {}

  for _, device in ipairs(result[1]) do
    for _, interface in ipairs(device.interfaces) do
      table.insert(devices, process_device(device, interface))
    end
  end

  return devices
end

function get_blocked_devices()
  local devices = get_all_devices()

  local blocked_devices = {}

  for _, device in ipairs(devices) do

    if device.blocked then
      table.insert(blocked_devices, device)
    end

  end

  return blocked_devices
end

function get_allowed_devices()
  local devices = get_all_devices()

  local allowed_devices = {}

  for _, device in ipairs(devices) do

    if not device.blocked then
      table.insert(allowed_devices, device)
    end

  end

  return allowed_devices
end

function is_device_blocked(mac_address)
  local blocked_devices = get_blocked_devices()

  for _, device in ipairs(blocked_devices) do
    if case_insensetive_compare(device.mac, mac_address) then
      return true
    end
  end

  return false
end

function change_device_blocked_status(mac_address, block)
  local devices = get_all_devices()

  for _, device in ipairs(devices) do

    if case_insensetive_compare(device.mac, mac_address) then

      return rpc_call(device_manager_package_id, "block_device", {
        device.id, block and "true" or "false"
      })

    end
  end

  return false
end

function block_device(mac_address)
  return change_device_blocked_status(mac_address, true) and "1" or "0"
end

function allow_device(mac_address)
  return change_device_blocked_status(mac_address, false) and "1" or "0"
end

function allow_all_devices()
  local blocked_devices = get_blocked_devices()

  local success = true

  for _, device in ipairs(blocked_devices) do
    local status, result = rpc_call(device_manager_package_id, "block_device", {
      device.id, "false"
    })

    success = success and status
  end

  return success
end

function stringify_devices(devices)
  local output = tostring(#devices)

  for i, device in ipairs(devices) do
    output = output .. string.format(
      "@%s;%s;%s;%s", i - 1, device.mac, device.name,
      device.wireless and "wireless" or "wired"
    )
  end

  return output
end


local function empty_string( x )
  x = x or ""

  if( string.match( x, "^%s+$" ) ) then
    return true
  end

  return x == ""
end

require "libtable"

local function select_nonempty_string( ... )
  local strings = { ... }

  for _,s in pairs( strings ) do
    if( not empty_string( s ) ) then
      return s
    end
  end

  return ""
end

local function process_device( d, online_interfaces )
  assert( #d.interfaces == 1 )
  local i = d.interfaces[1]

  local out = {
    name = select_nonempty_string( d.uhost, i.dhost, i.ghost ),
    type = select_nonempty_string( d.utype, i.dtype, i.gtype ),
    id = d.devid,
    mac = i.mac,
    connectType = i.wifi == 0 and "wired" or "wireless",
    status = d.block and "Block" or "Allow",
    online = false -- default to false
  }

  for _,inf in pairs( online_interfaces ) do
    if( string.lower( inf.mac ) == string.lower( i.mac ) ) then
      out.ips = inf.ips
      out.online = ( #inf.ips ) > 0
      out.ssid = inf.ssid
      out.wireless_speed = inf.freq
      break
    end
  end

  return out
end

-- Get attached device information according to DNI spec
local function get_all_attached_devices()
  local status, result, devices, online_interfaces
  local out = {}

  status, result = rpc_call(device_manager_package_id, "get_all_devices")
  assert(status, "Error fetching devices")
  devices = result[1]

  status, result = rpc_call(device_manager_package_id, "get_online_interfaces")
  assert(status, "Error fetching online interfaces")
  online_interfaces = result[1]

  for _, device in pairs( devices ) do
    table.insert( out, process_device( device, online_interfaces ) )
  end

  return out
end

function get_handler(arg1)
  if arg1 == "all-block" then

    return stringify_devices(get_blocked_devices())

  elseif arg1 == "all-allow" then

    return stringify_devices(get_allowed_devices())

  elseif arg1 == "attachDevice" then

    return json.encode( get_all_attached_devices() )
  else
    if is_device_blocked(arg1) then
      return "block"
    else
      return "allow"
    end
  end
end

local command_map = {
  { command = "get", handler = get_handler },
  { command = "block", handler = block_device },
  { command = "allow", handler = allow_device },
  { command = "delete-all-block", handler = allow_all_devices }
}

for _, command_handler in ipairs(command_map) do
  if command_handler.command == arg[1] then

    local arguments = {}

    for i = 2, #arg do
      table.insert(arguments, arg[i])
    end

    print(command_handler.handler(unpack(arguments)))
    return
  end
end

print("0")
