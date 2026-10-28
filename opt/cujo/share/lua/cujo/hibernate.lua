--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

cujo.hibernate = {}

local function wakeup(...) return event.emitall(wakeup, ...) end

local wakeevts = {
	[cujo.safebro.threat] = function () wakeup'safe browsing threat' end,
	[cujo.fingerprint.dhcp] = function () wakeup'DHCP request' end,
	[cujo.traffic.enable] = function (enabled)
		if enabled then wakeup'traffic enabled' end
	end,
}

local hibernation

local function onhibernate()
	cujo.cloud.onhibernate()
	cujo.cloud.ondisconnect:unsubscribe(onhibernate)
end

local function onwakeup()
	cujo.cloud.onwakeup()
	cujo.cloud.onconnect:unsubscribe(onwakeup)
end

local function reconfigure_fingerprinting(hibernate)
	if not cujo.fingerprint.enable:get() then
		return
	end
	cujo.fingerprint.enable:set(false)
	if hibernate then
		cujo.fingerprint.setrules('dhcp')
	else
		cujo.fingerprint.setrules('all')
	end
	cujo.fingerprint.enable:set(true)
end

cujo.jobs.spawn("hibernator", function ()
	while true do
		local ev, reason
		ev, reason, hibernation = cujo.jobs.wait(hibernation, wakeup)
		if ev == wakeup and reason == 'reset' then
			cujo.cloud.ondisconnect:subscribe(onhibernate)
			cujo.log:hibernate('hibernating for ', hibernation, ' seconds')
			reconfigure_fingerprinting(true)
			cujo.cloud.disconnect()
			for publisher, callback in pairs(wakeevts) do
				publisher:subscribe(callback)
			end
		else
			cujo.cloud.onconnect:subscribe(onwakeup)
			for publisher, callback in pairs(wakeevts) do
				publisher:unsubscribe(callback)
			end
			cujo.log:hibernate('hibernation ended due to ', reason or 'timeout')
			reconfigure_fingerprinting(false)
			cujo.cloud.connect()
		end
	end
end)

function cujo.hibernate.cancel()
	if hibernation then
		wakeup'cancel'
		return true
	end
	return false
end

function cujo.hibernate.start(duration)
	if cujo.traffic.enable:get() then
		cujo.log:hibernate'ignored hibernation because traffic monitoring is on'
		return 'traffic'
	end
	wakeup('reset', duration) -- TODO: hibernate request using reconnection?
end
