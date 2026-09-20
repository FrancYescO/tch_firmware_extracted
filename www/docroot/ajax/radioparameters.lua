-- Enable localization
gettext.textdomain('webui-mobiled')

local content_helper = require("web.content_helper")
local utils = require("web.lte-utils")
local proxy = require("datamodel")
local json = require("dkjson")

local post_data = ngx.req.get_post_args()

local max_age = tonumber(post_data.max_age) or 5
local dev_idx = tonumber(post_data.dev_idx) or 1
local since_uptime = tonumber(post_data.since_uptime)

local function setfield(t, f, v)
	for w, d in string.gmatch(f, "([%w_]+)(.?)") do
		if d == "." then
			t[w] = t[w] or {}
			t = t[w]
		else
			t[w] = v
		end
	end
end

local function convert_to_object(data, basepath, output)
	if not output then output = {} end
	if data and basepath then
		for _, entry in pairs(data) do
			local additional_path = entry.path:gsub(basepath, '')
			if additional_path and additional_path ~= '' then
				setfield(output, additional_path .. entry.param, entry.value)
			else
				output[entry.param] = entry.value
			end
		end
	end
	return output
end

if not post_data.data_period then
	utils.sendResponse({'{ error : "Invalid data_period" }'})
	return
end

local path = string.format("rpc.ltedoctor.signal_quality.@%s.", post_data.data_period)
local uptime_info = {
	period_seconds = path .. 'period_seconds',
	current_uptime = path .. 'current_uptime'
}
content_helper.getExactContent(uptime_info)
local period_seconds = tonumber(uptime_info.period_seconds)
local current_uptime = tonumber(uptime_info.current_uptime)

if since_uptime then
	path = "rpc.ltedoctor.signal_quality.@diff."
	proxy.set(path .. "since_uptime", tostring(since_uptime))
	proxy.apply()
end

local starting_uptime = 0
if current_uptime > period_seconds then
	starting_uptime = current_uptime - period_seconds
end

path = path .. 'entries.'
local history = content_helper.convertResultToObject(path, proxy.get(path))

local current_data = {}

local base_path = string.format('rpc.mobiled.device.@%d.', dev_idx)

proxy.set(base_path .. 'radio.signal_quality.max_age', tostring(max_age))
path = base_path .. 'radio.signal_quality.'
local signal_quality = proxy.get(path)
convert_to_object(signal_quality, path, current_data)

path = base_path .. 'radio.signal_quality.additional_carriers.'
current_data.additional_carriers = content_helper.convertResultToObject(path, proxy.get(path))

proxy.set(base_path .. 'network.serving_system.max_age', tostring(max_age))
path = base_path .. 'network.serving_system.'
local serving_system = proxy.get(path)
convert_to_object(serving_system, path, current_data)

path = base_path .. 'leds.bars'
local leds = proxy.get(path)
current_data['bars'] = leds[1].value

local filter = {
	"AdditionalCarriersNumberOfEntries",
	"NeighbourCellsNumberOfEntries"
}
for _, f in pairs(filter) do
	current_data[f] = nil
end

local data = {
	history = {
		period_seconds = period_seconds,
		current_uptime = current_uptime,
		starting_uptime = starting_uptime,
		data = history
	},
	current = current_data
}

local buffer = {}
local success = json.encode (data, { indent = false, buffer = buffer })
if success and buffer then
	utils.sendResponse(buffer)
end

utils.sendResponse({'{ error : "Failed to encode data" }'})
