#! /usr/bin/env lua

local gwfd = require("gwfd.common")
local fifo_file_path
local interval
do
  local args = gwfd.parse_args(arg, {interval=300})
  fifo_file_path = args.fifo
  interval = args.interval
end
local uloop = require("uloop")

local timer

local strip_params = {
	"disable",
	"login_required",
	"device_config_parameter",
	"unblock",
	"unlock",
	"change",
	"initialized",
	"cell_id_hex"
}

local skip_conversion = {
	imei = true,
	imeisv = true,
	imsi = true,
	iccid = true,
	mcc = true,
	mnc = true,
	tracking_area_code = true,
	location_area_code = true,
	phy_cell_id = true,
	cell_id = true
}

local function sanitize_data(msg)
	if type(msg) == "table" then
		for _, v in pairs(strip_params) do
			msg[v] = nil
		end
		for k in pairs(msg) do
			if msg[k] == "" then
				msg[k] = nil
			end
		end
	end
end

local function send_lte_data()
	local msg = {}
	local rv = gwfd.get_transformer_param("rpc.mobiled.device.@1.radio.signal_quality.", msg, skip_conversion)
	if rv then
		rv = gwfd.get_transformer_param("rpc.mobiled.device.@1.network.serving_system.", msg, skip_conversion)
		if rv then
			rv = gwfd.get_transformer_param("rpc.mobiled.device.@1.info.", msg, skip_conversion)
			if rv then
				rv = gwfd.get_transformer_param("rpc.mobiled.device.@1.sim.", msg, skip_conversion)
				if rv then
					sanitize_data(msg)
					gwfd.write_msg_to_file(msg, fifo_file_path)
				end
			end
		end
	end
	timer:set(interval) -- reschedule on the uloop
end

-- Main code
uloop.init()

gwfd.init("gwfd_lte", 6, { init_transformer = true })

timer = uloop.timer(send_lte_data)
send_lte_data()
xpcall(uloop.run, gwfd.errorhandler)
