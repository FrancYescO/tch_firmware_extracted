--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

safebro = {}
safebro.reasons = {
	parental = 0,
	tracker = -1
}

safebro.status = {
	safebro = {
		enabled = false
	},
	trackerblock = {
		enabled = false
	}
}

local suspended = lru.new(config.trackerblock.maxentries)

local function islisted(domain, list)
	local pattern, replaces = '^[^.]+'
	repeat
		local access = list[domain]
		if access ~= nil then return true, access end
		domain, replaces = string.gsub(domain, pattern, '*')
		pattern = '^%*%.[^.]+'
	until replaces == 0
end

local function isbad(score)
	return score <= sbconfig.threshold
end

local function isallowed(profile, categories)
	for _, category in ipairs(categories or {}) do
		local access = profile.categories[category]
		if access ~= nil then return access end
	end

	return profile.default
end

local function hascategory(trackercategories, categories)
	for _, category in ipairs(categories or {}) do
		for _, trackercategory in ipairs(trackercategories) do
			if category == trackercategory then
				return true
			end
		end
	end
	return false
end

local function istracker(sbconfig, categories)
	local blockcategories = sbconfig.trackerblock.blockcategories
	return hascategory(blockcategories, categories)
end

local function iswhitelistedtracker(sbconfig, categories)
	local suspendcategories = sbconfig.trackerblock.suspendcategories
	return hascategory(suspendcategories, categories)
end

function safebro.config(settings)
	local conf = json.decode(settings)
	sbconfig.load(conf)
	threat.init()
end

function safebro.profiles(profiles)
	local conf = json.decode(profiles)
	sbconfig.set_profiles(conf)
end

local function suspendblocker(mac)
	suspended[mac] = os.time() + sbconfig.trackerblock.suspendperiod
end

function safebro.trackersallowed(mac)
	local time = suspended[mac]
	if not time then return false end
	if time < os.time() then
		suspended[mac] = nil
		return false
	end
	return true
end

function safebro.filter(mac, ip, domain, path)
	local allow = true
	local listed = false
	local profile = {}
	local threatcheck = safebro.status.safebro.enabled
	local blockerstatus = safebro.status.trackerblock
	local blockerallow = not blockerstatus.enabled or safebro.trackersallowed(mac)

	if threatcheck then
		profile = sbconfig.profiles[mac] or sbconfig.profile
		listed, allow = islisted(domain, profile.domains)
		if blockerallow and allow then return true end -- found, don't block
	end

	local score, reason, categories = threat.lookup(domain, path)
	if not score then -- cache miss and not blocked
		if threatcheck and listed and not allow then
			return false, safebro.reasons.parental
		else
			return false
		end
	end

	if threatcheck then
		if not listed and isallowed(profile, categories) then
			allow = not isbad(score)
		elseif not allow then
			allow, score, reason = false, 0, safebro.reasons.parental
		end
	end

	if not allow then
		local ok, err = nf.send('notify', {ip = nf.toip(ip), mac = nf.tomac(mac),
			uri = domain .. path, reason = reason, score = score,
			categories = categories})
		if not ok then
			debug("nflua: 'safebro.filter' failed to send netlink msg 'notify': %s", err)
		end
		return true, reason
	elseif not blockerallow then
		if iswhitelistedtracker(sbconfig, categories) then
			suspendblocker(mac)
			return true
		end

		if not istracker(sbconfig, categories) then
			return true
		end
		local ok, err = nf.send('trackerblock', {mac = nf.tomac(mac),
			uri = domain .. path, categories = categories})
		if not ok then
			debug("nflua: 'safebro.filter' failed to send netlink msg 'trackerblock': %s", err)
		end
		return true, safebro.reasons.tracker
	end

	return true
end
