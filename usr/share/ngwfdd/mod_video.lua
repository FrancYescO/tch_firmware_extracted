#! /usr/bin/env lua

-- file: mod_video.lua

package.path = "/usr/share/ngwfdd/lib/?.lua;" .. package.path

local gwfd = require("gwfd-common")
local uloop = require("uloop")

-- Ubus connection

local _, ubus_conn

-- Key video metrics to be collected.
-- These include igmp snooping and relevant video statistics for active wan multicast traffic

local bridge_keys = { "br-lan" }
local stats_keys = { "rx_dropped", "rx_crc_errors", "tx_dropped", "multicast" }

-- Video relevant paths

local igmp_snooping_path = "/proc/net/igmp_snooping"
local igmp_proxy_intf = "igmpproxy.interface"
local igmp_proc_path = "/proc/net/igmp"
local brlist_path = "/proc/fcache/brlist"

-- Absolute path to the output fifo file

local fifo_file_path = arg[1]

-- Timer used with the uloop

local timer
local interval = (tonumber(gwfd.get_uci_param("ngwfdd.interval.video")) or 1800) * 1000

-- Get the upstream interfaces available

local function get_upstream_intfs()

  local t = ubus_conn:call(igmp_proxy_intf, "dump", {})
  if t == nil then
    return
  end
  -- Internal function to search for a given element in nested tables
  local function find_upstream_intf_in_tables(e, result)
    result = result or {}
    if type(e) == "table" then
      for k, v in pairs(e) do -- for every element in the table
      if (k == "state" and v == "upstream") then
        table.insert(result, e["interface"])
      end
      find_upstream_intf_in_tables(v, result) -- recursively repeat the same procedure
      end
    end
    return result
  end

  local upst_inf = find_upstream_intf_in_tables(t)
  return upst_inf
end

-- Get device stats

local function get_dev_stats(dev)

  if dev == nil then
    return
  end

  local msg = {}
  local prefix = "sys.class.net.@"

  local stats = prefix .. dev .. ".statistics"
  local keys = {}

  for k, v in pairs(stats_keys) do
    keys[k] = stats .. "." .. v
  end

  if not gwfd.get_transformer_params(keys, msg) then
    return
  end

  return msg
end

-- Get the multicast wan device for a given interface

local function get_multicast_wan_dev(intf)

  if intf == nil then
    return
  end

  local result = io.popen("ifstatus " .. intf)
  local result_str = result:read("*a")
  local l3_dev_val = result_str:match('"l3_device": "([^"]*)"')
  result:close()

  return l3_dev_val
end

-- Get the multicast subscriptions for a given device

local function get_multicast_subs(wan_dev)

  if wan_dev == nil then
    return
  end

  local return_subs = {}

  local result = io.open(igmp_proc_path, "r")
  if result then
    local line = result:read("*l")
    while line do
      local tokens = line:gmatch("%S+")
      tokens() -- ignore first
      local wan_dev_match = tokens()

      if wan_dev_match == wan_dev then
        tokens() -- ignore third
        local num_subs = tokens()
        local i = tonumber(num_subs)
        return_subs["m_querier"] = tokens()
        return_subs["m_subs"] = {}
        while i > 0 do
          line = result:read("*l")

          local subscription_tokens = line:gmatch("%S+")
          local to_insert_subs = {}
          to_insert_subs["subscription"] = subscription_tokens()
          to_insert_subs["group"] = subscription_tokens()
          to_insert_subs["users_time"] = subscription_tokens()
          to_insert_subs["reporter"] = subscription_tokens()

          table.insert(return_subs["m_subs"], to_insert_subs)

          i = i - 1
        end
      end
      line = result:read("*l")
    end
  end
  result:close()
  return return_subs
end

-- Get the igmp snooping data

local function get_igmp_snooping()

  local igmp_snooping = io.open(igmp_snooping_path, "r")
  if igmp_snooping then
    local line = igmp_snooping:read("*l")
    local bridges, errmsg = gwfd.set(bridge_keys)
    assert(bridges, errmsg)

    local t = {}
    while line do
      local first = line:match("([^%s]+)") -- First field is the bridge name
      if bridges[first] then
        local entry = {}
        entry["timeout"] = tonumber(entry["timeout"]) -- only number
        table.insert(t, entry)
      end
      line = igmp_snooping:read("*l")
    end
    igmp_snooping:close()
    return t
  end
  return {}
end

-- Get HW/SW acceleration data

local function get_hw_sw_acc_data()

  local brlist = io.open(brlist_path, "r")
  local t = {}

  local all_lines = brlist:read("*a")

  local lines = all_lines:gmatch("([^\n]+)") -- break lines
  lines() --skip header
  lines() --skip another header

  for line in lines do
    local fo, swhits, swhittb, hwhits = line:match("(%S+)%s+%d+:+%s+%d+%s+(%d+):%s+(%d+)%s+%S+%s+(%d+)")
    local entry = {}
    entry["FlowObject"] = fo
    entry["SW_TotHits"] = swhits
    entry["SW_TotHits_TotalBytes"] = swhittb
    entry["HW_TotHits"] = hwhits
    table.insert(t, entry)
  end

  brlist:close()
  return t
end

-- Send all video related data

local function send_video_data()

  local up_intfs = get_upstream_intfs()
  if up_intfs then
    for _, intf in pairs(up_intfs) do
      local wan_dev = get_multicast_wan_dev(intf)
      local subs = get_multicast_subs(wan_dev)
      local m_subs = subs["m_subs"]
      local m_querier = subs["m_querier"]

      for _, v in pairs(m_subs) do

        local msg_sub = v

        msg_sub["m_querier"] = m_querier
        msg_sub["device"] = wan_dev
        msg_sub["name"] = intf
        msg_sub["suffix"] = "multicast_subs"

        gwfd.write_msg_to_file(msg_sub, fifo_file_path)
      end

      local msg_stats = get_dev_stats(wan_dev)
      msg_stats["device"] = wan_dev
      msg_stats["suffix"] = "stats"

      local msg_sw_hw_acc = get_hw_sw_acc_data()
      for _, v in pairs(msg_sw_hw_acc) do
        for k, v1 in pairs(v) do
          msg_stats[k] = v1
        end

        gwfd.write_msg_to_file(msg_stats, fifo_file_path)
      end
    end
  end

  local snooping = get_igmp_snooping()
  if snooping then
    for _, v in pairs(snooping) do
      local msg_snooping = v
      msg_snooping["suffix"] = "igmp_snooping"
      gwfd.write_msg_to_file(msg_snooping, fifo_file_path)
    end
  end
  timer:set(interval) -- reschedule on the uloop
end

-- Main

uloop.init()
_, ubus_conn = gwfd.init("gwfd_video", 6, { return_ubus_conn = true, init_transformer = true })

timer = uloop.timer(send_video_data)
send_video_data()
xpcall(uloop.run, gwfd.errorhandler)
