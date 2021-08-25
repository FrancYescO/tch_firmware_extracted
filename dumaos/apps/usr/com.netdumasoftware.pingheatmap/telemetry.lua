--[[
  (C) 2020 NETDUMA Software
  Adrian Frances <adrian.frances@netduma.com>

  Telemetry interface for Ping Heatmap
--]]





require("libos")
local telemetry_api = require("telemetrylua")

local M = {}

local function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

local function round_ping_values(iptable)
  for k, val in pairs(iptable) do
    iptable[k] = round(val * 1000)
  end
end

local function order_table (t, n)
  local a = {}
  local retvalue = {}

  for k in pairs(t) do
    table.insert(a, k)
  end

  local function f(ip1, ip2)
    if t[ip1] < t[ip2] then
      return true
    end
    return false
  end
  table.sort(a, f)

  if n > 1 then
    for i=1, n do
      local new_entry = {}
      new_entry["server_ip"] = a[i]
      new_entry["ping"] = t[a[i]]
      table.insert(retvalue.pings, new_entry)
    end
  else
    retvalue.server_ip = a[1]
    retvalue.ping = t[a[1]]
  end

  return retvalue
end

local function get_public_ip()
  local config_call = [[ubus call com.netdumasoftware.config rpc '{"proc":"get","1":"DumaOS_Public_IP"}']]

  local result = os.get_cmd_output(config_call)
  if result then
    local status, result_decoded = pcall(json.decode, result)
    if status then
      local retvalue = nil
      for _, val in pairs(result_decoded.result) do
        retvalue = val
      end
      return retvalue
    end
  end
  return nil
end

function M.send_minimum_pings(ping_data, category, number_pings)
  local data_to_send = {}
  number_pings = number_pings or 1

  round_ping_values(ping_data)
  local minimum_pings = order_table(ping_data, number_pings)
  if type(category) == "string" then
    minimum_pings["category"] = category
  end
  local unix_timestamp = os.time()
  minimum_pings["timestamp"] = os.date("!%Y-%m-%dT%TZ", unix_timestamp)







  local telemetry_to_send = json.encode(minimum_pings)
  telemetry_api.send_message("com.netdumasoftware.pingheatmap", "closest_pings", telemetry_to_send)
end

return M
