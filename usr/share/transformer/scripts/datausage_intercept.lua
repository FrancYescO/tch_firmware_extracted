#!/usr/bin/env lua
-- Copyright (c) 2017 Technicolor

local uci = require("uci")
local cursor = uci.cursor()
local ubus = require("ubus")
local conn = ubus.connect()

local disabled = "0"

local function enableIntercept()
  local status = cursor:get("intercept", "config", "enabled")
  if status == "0" then
    cursor:set("intercept", "config", "enabled", "1")
  end
end

local function removeIntercept()
  local last_exec = cursor:get("datausage_notifier", "datausage_limit_intercept", "last_executed")
  if last_exec == "limit_reached" then
    cursor:set("datausage_notifier", "datausage_limit_intercept", "last_executed", "")
    cursor:commit("datausage_notifier")
  end
  conn:call("intercept", "del_reason", { reason = "datausage_limit_reached" })
  os.execute("/etc/init.d/datausage_notifier reload")
end

local function checkLimit(limit,limit_unit,limit_used)
  local limit_allowed
  if limit_unit == "GB" then
    limit_allowed = ( limit * 1073741824 )
  elseif limit_unit == "MB" then
    limit_allowed = ( limit * 1048576 )
  end

  if limit_allowed > limit_used then
    removeIntercept()
  end
end

local function dataCheck()
  cursor:foreach("datausage", "interface", function(s)
    if s.enabled == "1" then
      enableIntercept()
      local total_bytes = s.tx_bytes_total + s.rx_bytes_total
      checkLimit(s.usage_limit, s.usage_limit_unit, total_bytes)
      disabled = "1"
    end
  end)
  if disabled == "0" then
    removeIntercept()
    cursor:set("intercept", "config", "enabled", "0")
  end
  cursor:commit("intercept")
  os.execute("/etc/init.d/intercept reload")
end

dataCheck()
