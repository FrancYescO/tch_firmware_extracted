#! /usr/bin/env lua

-- file: mod_conntrack.lua

package.path = "/usr/share/ngwfdd/lib/?.lua;" .. package.path

local gwfd = require("gwfd-common")
local uloop = require("uloop")
local uci = require("uci")
local cursor = uci.cursor()

local IPTABLES_CMDS = { "iptables", "ip6tables" }

-- Uloop timer

local timer
local interval = (tonumber(gwfd.get_uci_param("ngwfdd.interval.conntrack")) or 1800) * 1000

-- Absolute path to the output fifo file

local fifo_file_path = arg[1]
local conntrack_cache

local REGEX_CONNTRACK_STAT = "(%x+)%s+%x+%s+%x+%s+(%x+)%s+%x+%s+%x+%s+%x+%s+%x+%s+%x+%s+%x+%s+(%x+)%s+(%x+)%s+%x+%s+(%x+)"
local function parse_conntrack_stat()
  local state = {}
  local file = io.open("/proc/net/stat/nf_conntrack", "r")

  local line = file:read("*l")
  while line do
    local conntracks, new, drop, early_drop, expect_new = line:match(REGEX_CONNTRACK_STAT)
    if conntracks and new and drop and early_drop and expect_new then
      state.conntracks = tonumber(conntracks, 16)
      state.new_conntracks = (state.new_conntracks or 0) + tonumber(new, 16)
      state.dropped_conntracks = (state.dropped_conntracks or 0) + tonumber(drop, 16)
      state.early_dropped_conntracks = (state.early_dropped_conntracks or 0) + tonumber(early_drop, 16)
      state.expected_new_conntracks = (state.expected_new_conntracks or 0) + tonumber(expect_new, 16)
    end
    line = file:read("*l")
  end

  file:close()

  return state
end

local REGEX_HELPERS_PACKETS = "^%s*(%d+)%s+.*CT helper (%a[%w_-]+)"
local HELPERS_CHAINS = { "helper_binds", "output_helper_binds" }
local function parse_helpers_counters(state)
  for _, cmd in ipairs(IPTABLES_CMDS) do
    for _, chain in ipairs(HELPERS_CHAINS) do
      local file = io.popen(cmd .. " -t raw -vxL " .. chain, "r")
      local line = file:read("*l")

      while line do
        local counter, helper = line:match(REGEX_HELPERS_PACKETS)
        if counter and helper then
          helper = helper .. "_helper_packets"
          state[helper] = (state[helper] or 0) + counter
        end
        line = file:read("*l")
      end

      file:close()
    end
  end
end

local REGEX_PPPOE_RELAY_PACKETS="-p%s+PPP_.*%spcnt%s*=%s*(%d+)%s"
local PPPOE_TABLES = { "filter", "broute" }
local function parse_ebtables_counters(state)
  state.pppoe_relay_packets = 0

  for _, t in ipairs(PPPOE_TABLES) do
    local file = io.popen("ebtables -t " .. t .. " -L ppprelay --Lc", "r")
    local line = file:read("*l")

    while line do
      local counter = line:match(REGEX_PPPOE_RELAY_PACKETS)
      if counter then
        state.pppoe_relay_packets = state.pppoe_relay_packets + counter
      end
      line = file:read("*l")
    end

    file:close()
  end
end

local REGEX_UPNP_REDIRECT="^-A.*%s-j%s+DNAT%s"
local function parse_upnp_redirects(state)
  local file = io.popen("iptables -t nat -S MINIUPNPD", "r")
  local line = file:read("*l")

  state.upnp_redirects = 0
  while line do
    local upnp_redirect = line:match(REGEX_UPNP_REDIRECT)
    if upnp_redirect then
      state.upnp_redirects = state.upnp_redirects + 1
    end
    line = file:read("*l")
  end

  file:close()
end

local function parse_uci(state)
  local config = "firewall"
  local counter

  local function increment_counter()
    counter = counter + 1
  end

  cursor:load(config)

  counter = 0
  cursor:foreach(config, "userredirect", increment_counter)
  state.user_redirects = counter

  counter = 0
  cursor:foreach(config, "pinholerule", increment_counter)
  state.user_pinholes = counter

  cursor:unload(config)
end

local REGEX_BCM_HWACCEL_HITS = "^[%p%w]+%s+%d+%s*:%s*%d+%s+%d+%s*:%s*%d+%s+[%p%w]+%s+(%d+)%s"
local BCM_ACCEL_FLOWS = { ucast = "nflist" , mcast = "brlist" }
local function parse_accel_stat(state)
  for t, fname in pairs(BCM_ACCEL_FLOWS) do
    local file = io.open("/proc/fcache/" .. fname, "r")

    if file then
      local name = t .. "_flows"
      local accel_name = "accel_" .. t .. "_flows"

      state[name] = 0
      state[accel_name] = 0

      local line = file:read("*l")
      while line do
        local hits = tonumber(line:match(REGEX_BCM_HWACCEL_HITS))
        if hits then
          state[name] = state[name] + 1
          if hits > 0 then
            state[accel_name] = state[accel_name] + 1
          end
        end
        line = file:read("*l")
      end

      file:close()
    end
  end
end

local function read_cached_values()
  local new_conntrack_cache = parse_conntrack_stat()
  parse_helpers_counters(new_conntrack_cache)
  parse_ebtables_counters(new_conntrack_cache)
  return new_conntrack_cache
end

local function send_conntrack_data()
  local msg = {}

  -- Some values are cached because we're interested in their delta variations (e.g. packet counters)
  local new_conntrack_cache = read_cached_values()
  for k, v in pairs(new_conntrack_cache) do
    if k == "conntracks" then
      msg[k] = v
    elseif conntrack_cache[k] and v >= conntrack_cache[k] then
      msg[k] = v - conntrack_cache[k]
    else -- counter overflow
      msg[k] = v
    end
  end
  conntrack_cache = new_conntrack_cache

  parse_upnp_redirects(msg)
  parse_uci(msg)
  parse_accel_stat(msg)

  gwfd.write_msg_to_file(msg, fifo_file_path)
  timer:set(interval) -- reschedule on the uloop
end

-- Main code
uloop.init()

gwfd.init("gwfd_conntrack", 6, { init_transformer = true })

conntrack_cache = read_cached_values()

timer = uloop.timer(send_conntrack_data)
timer:set(interval)

xpcall(uloop.run, gwfd.errorhandler)
