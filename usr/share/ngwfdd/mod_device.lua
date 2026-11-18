#! /usr/bin/env lua

local gwfd = require("gwfd.common")
local fifo_file_path
local interval
do
  local args = gwfd.parse_args(arg, {interval=3600})
  fifo_file_path = args.fifo
  interval = args.interval
end

local uloop = require("uloop")

-- Logger

local log

-- Uloop timer

local timer

-- Needed UCI parameters to be collected

local device_plain_uci_params = {
  "env.var.prod_number",
  "env.var.prod_friendly_name",
  "env.rip.eth_mac",
  "env.rip.wifi_mac",
  "ngwfdd.config.ngwfdd_version"
}

-- Needed indexed UCI parameters to be collected

local device_indexed_uci_params = {
  version = {
    type = "version",
    index = 0,
    params = {
      "product",
      "marketing_version",
      "marketing_name",
      "version"
    }
  }
}

local function send_device_data()
  local msg, errmsg = gwfd.get_uci_params(device_plain_uci_params)
  if not msg then
    log:error(errmsg)
    uloop.cancel()
  end

  local msg2, errmsg2 = gwfd.get_uci_params_indexedtype(device_indexed_uci_params)
  if not msg2 then
    log:error(errmsg2)
    uloop.cancel()
  end

  for k, v in pairs(msg2) do
    if k == "version" then
      msg["full_version"] = v -- avoid collision with version field added by daemon
    else
      msg[k] = v
    end
  end

  if next(msg) == nil then
    uloop.cancel()
  end

  gwfd.write_msg_to_file(msg, fifo_file_path)
  timer:set(interval) -- reschedule on the uloop
end

-- Main code
uloop.init()

log = gwfd.init("gwfd_device", 6, {})

timer = uloop.timer(send_device_data)
send_device_data()
xpcall(uloop.run, gwfd.errorhandler)
