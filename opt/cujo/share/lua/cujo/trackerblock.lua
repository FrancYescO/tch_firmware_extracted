--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2019 CUJO LLC. All rights reserved.
--

local trackerblockstats = {
	starttime = 0,
	entries = 0,
	others = 0,
	bydevice = {}
}

local function collectstats(mac, uri, categories)
	local stats = trackerblockstats
	local max_entries = cujo.config.trackerblock.report_max_entries
	if stats.bydevice[mac] and (stats.bydevice[mac][uri] or
		stats.bydevice[mac]['other']) then
		local uri = stats.bydevice[mac][uri] and uri or 'other'
		local devstats = stats.bydevice[mac][uri]
		devstats.count = devstats.count + 1
		return
	end

	uri = stats.entries < max_entries and uri or 'other'

	if stats.entries < max_entries then
		stats.entries = stats.entries + 1
	elseif not stats.bydevice[mac] then
		stats.others = stats.others + 1
		return
	end

	stats.bydevice[mac] = stats.bydevice[mac] or {}
	stats.bydevice[mac][uri] = {
		categories = uri ~= 'other' and categories or nil,
		count = 1
	}
end

local function flushstats()
	trackerblockstats = {
		entries = 0,
		others = 0,
		bydevice = {},
		starttime = os.time()
	}
end

local function sendreport()
	local stats = trackerblockstats
	if next(stats.bydevice) == nil then
		return
	end
	if (os.time() - stats.starttime) <
		cujo.config.trackerblock.report_period then
		return
	end
	local report = {
		statsByDevice = {},
		others = stats.others > 0 and stats.others or nil,
		windowStartTime = stats.starttime,
		windowEndTime = os.time(),
	}
	for mac, devicestats in pairs(stats.bydevice) do
		report.statsByDevice[mac] = {}
		for uri, uristats in pairs(devicestats) do
			uristats.url = uri
			table.insert(report.statsByDevice[mac], uristats)
		end
	end

	cujo.cloud.send('tracker-block-stats', report)

	flushstats()
end

cujo.trackerblock.stats:subscribe(function (message)
	collectstats(message.mac, message.uri, message.categories)
end)

cujo.nf.subscribe('trackerblock', cujo.trackerblock.stats)

local connected = false
local wakereport = false
local cancel = {}

function cujo.trackerblock.onconnect()
	connected = true
end

function cujo.trackerblock.ondisconnect()
	cujo.trackerblock.configure(false)
	connected = false
end

function cujo.trackerblock.onhibernate()
	local config = cujo.safebro.getconfig()
	if cujo.trackerblock.enable.enabled and
		config and config.trackerBlock then
		wakereport = true
	end
end

function cujo.trackerblock.onwakeup()
	if not cujo.trackerblock.enable.enabled then
		wakereport = false
	end
end

cujo.cloud.onconnect:subscribe(cujo.trackerblock.onconnect)
cujo.cloud.ondisconnect:subscribe(cujo.trackerblock.ondisconnect)
cujo.cloud.onhibernate:subscribe(cujo.trackerblock.onhibernate)
cujo.cloud.onwakeup:subscribe(cujo.trackerblock.onwakeup)

local function report_handler(period)
	if wakereport then
		wakereport = false
		sendreport()
	end
	flushstats()
	while true do
		local ev = cujo.jobs.wait(period, cancel)
		if ev == cancel then
			return
		end
		sendreport()
	end
end

function cujo.trackerblock.configure(enabled, settings)
	if enabled and settings and settings.trackerBlock then
		if not connected then
			flushstats()
		else
			event.emitone(cancel)
			local period = cujo.config.trackerblock.report_period
			cujo.jobs.spawn('trackerblock-reporter', report_handler, period)
			cujo.log:trackerblock('reports will be sent every ', period, 's')
		end
	else
		event.emitone(cancel)
	end
end
