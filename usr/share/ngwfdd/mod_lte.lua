#! /usr/bin/env lua

-- file: mod_lte.lua

package.path = "/usr/share/ngwfdd/lib/?.lua;" .. package.path

local gwfd = require("gwfd-common")

-- Uloop and logger

local uloop = require("uloop")
local log

-- Uploop timer

local timer
local interval = 1800 * 1000 -- Every 30 minutes

-- Absolute path to the output fifo file

local fifo_file_path = arg[1]

-- LTE related metrics to be fetched from transformer

local lte_transformer_data = {
  "rpc.mobiled.device.@1.radio.signal_quality.lte_ul_bandwidth",
  "rpc.mobiled.device.@1.radio.signal_quality.rsrp",
  "rpc.mobiled.device.@1.radio.signal_quality.snr",
  "rpc.mobiled.device.@1.radio.signal_quality.rssi",
  "rpc.mobiled.device.@1.radio.signal_quality.dl_earfcn",
  "rpc.mobiled.device.@1.radio.signal_quality.lte_band",
  "rpc.mobiled.device.@1.radio.signal_quality.rsrq",
  "rpc.mobiled.device.@1.radio.signal_quality.dl_uarfcn",
  "rpc.mobiled.device.@1.radio.signal_quality.bler_main",
  "rpc.mobiled.device.@1.radio.signal_quality.lte_ul_freq",
  "rpc.mobiled.device.@1.radio.signal_quality.ecio",
  "rpc.mobiled.device.@1.radio.signal_quality.lte_dl_bandwidth",
  "rpc.mobiled.device.@1.radio.signal_quality.dl_arfcn",
  "rpc.mobiled.device.@1.radio.signal_quality.bler_total",
  "rpc.mobiled.device.@1.radio.signal_quality.ul_earfcn",
  "rpc.mobiled.device.@1.radio.signal_quality.radio_interface",
  "rpc.mobiled.device.@1.radio.signal_quality.tx_power",
  "rpc.mobiled.device.@1.radio.signal_quality.ul_arfcn",
  "rpc.mobiled.device.@1.radio.signal_quality.bler_div",
  "rpc.mobiled.device.@1.radio.signal_quality.ul_uarfcn",
  "rpc.mobiled.device.@1.radio.signal_quality.bars",
  "rpc.mobiled.device.@1.radio.signal_quality.lte_dl_freq",
  "rpc.mobiled.device.@1.radio.signal_quality.phy_cell_id",
  "rpc.mobiled.device.@1.network.serving_system.cell_id",
  "rpc.mobiled.device.@1.network.serving_system.mcc",
  "rpc.mobiled.device.@1.network.serving_system.tracking_area_code",
  "rpc.mobiled.device.@1.network.serving_system.roaming_state",
  "rpc.mobiled.device.@1.network.serving_system.cell_id_hex",
  "rpc.mobiled.device.@1.network.serving_system.ps_state",
  "rpc.mobiled.device.@1.network.serving_system.cs_state",
  "rpc.mobiled.device.@1.network.serving_system.mnc",
  "rpc.mobiled.device.@1.network.serving_system.network_desc",
  "rpc.mobiled.device.@1.network.serving_system.nas_state",
  "rpc.mobiled.device.@1.info.hardware_version",
  "rpc.mobiled.device.@1.info.software_version",
  "rpc.mobiled.device.@1.info.temperature",
  "rpc.mobiled.device.@1.info.vid",
  "rpc.mobiled.device.@1.info.model",
  "rpc.mobiled.device.@1.info.pid",
  "rpc.mobiled.device.@1.info.manufacturer",
  "rpc.mobiled.device.@1.info.imei",
  "rpc.mobiled.device.@1.info.power_mode",
  "rpc.mobiled.device.@1.sim.imsi",
  "rpc.mobiled.device.@1.sim.iccid"
}

-- Send the LTE data

local function send_lte_data()
  local msg = {}
  local rv, errmsg = gwfd.get_transformer_params(lte_transformer_data, msg)
  if not rv then
    if errmsg then
      log:error(errmsg)
    end
    uloop.cancel()
  end

  gwfd.write_msg_to_file(msg, fifo_file_path)
  timer:set(interval) -- reschedule on the uloop
end

-- Main code
uloop.init()

log = gwfd.init("gwfd_lte", 6, { init_transformer = true })

timer = uloop.timer(send_lte_data)
send_lte_data()
xpcall(uloop.run, gwfd.errorhandler)
