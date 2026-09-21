
local require = require
local tonumber = tonumber

local socket = require 'socket'
local ubus = require('ubus').connect()
local inet = require 'tch.inet'
local uci = require 'uci'
local json = require 'dkjson'

local wpsreq = require('wireless.generic_app.wpsrequest').WpsRequest()

local M = {}

local function getSerial()
  local cursor = uci.cursor()
  local serial = cursor:get("env", "var", "serial") or "unkown"
  cursor:close()
  return serial
end

local function retrieveConfig()
  return {
    interface = wpsreq:interface(),
    port = wpsreq:udpPort(),
    serial = getSerial(),
  }
end

local function destinationAddress(config)
  local ifstatus = ubus:call("network.interface."..config.interface, "status", {})
  if not ifstatus then
    return
  end
  local ipv4 = ifstatus["ipv4-address"]
  ipv4 = ipv4 and ipv4[1]
  if not ipv4 then
    return
  end
  local ip = ipv4.address
  local mask = tonumber(ipv4.mask)
  if not ip or not mask then
    return
  end
  return inet.ipv4BroadcastAddr(ip, mask)
end

local function createSocket()
  local sock = socket.udp()
  sock:setoption("broadcast", true)
  return sock
end

local function send_event(event, mac)
  local config = retrieveConfig()
  local destination = destinationAddress(config)
  if not destination then
    return
  end
  local sock = createSocket()
  if not sock then
    return
  end
  local data = json.encode{
    gen_id = config.serial,
    type = "WPSPairing",
    time = os.date('%Y-%m-%dT%H:%M:%S%z'),
    status = event,
    mac = mac
  }
  print("send: "..data)
  print("to: "..destination..":"..config.port)
  sock:sendto(data, destination, config.port)
end

M.send = send_event

return M
