--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

sbconfig = {}

local default = {
	threshold = 25,
	ttl = 24 * 60 * 60,
	timeout = 350,
	profile = {domains = {}, categories = {}, default = true},
	trackerblock = {blockcategories = {}, suspendperiod = 10, suspendcategories = {}}
}

setmetatable(sbconfig, {__index = default})

local function frombytes(bytes)
	local n = 0
	for i, byte in ipairs(bytes) do
		byte = tonumber(byte, 16)
		n = (byte << (#bytes - i) * 8) | n
	end
	return n
end

local function toaccess(access)
	return string.lower(access) == 'allow' -- block by default
end

local function load_domains(filter, domains)
	for _, access in ipairs{'allow', 'block'} do
		local list = filter[access .. 'edDomains'] or {}
		for _, domain in ipairs(list) do
			local domain = string.lower(domain)
			domains[domain] = toaccess(access)
		end
	end
end

local function load_categories(filter, categories)
	for _, category in ipairs(filter.categories or {}) do
		categories[category] = filter.access
	end
end

local function load_devices(devices, profiles, profile)
	for _, device in ipairs(devices or {}) do
		local device = frombytes{string.match(device.mac,
			'(%x%x):(%x%x):(%x%x):(%x%x):(%x%x):(%x%x)')}
		profiles[device] = profile
	end
end

local function load_profiles(confs)
	local profiles = {}
	for _, conf in ipairs(confs) do
		local profile = {domains = {}, categories = {}}

		for _, filter in ipairs(conf.filters or {}) do
			load_domains(filter, profile.domains)
			filter.access = toaccess(filter.access)
			load_categories(filter, profile.categories)
		end

		local default = conf.defaultAccess or {}
		profile.default = toaccess(default.access)

		load_devices(conf.devices, profiles, profile)
	end
	return profiles
end

local function escape_url(url)
	return url:gsub("([-.])", "%%%1")
end

function sbconfig.set_profiles(profiles)
	sbconfig.profiles = load_profiles(profiles)
end

function sbconfig.load(settings)
	sbconfig.threshold = settings.threshold
	sbconfig.warnpage = settings.warnpage
	sbconfig.warnpage_pattern = sbconfig.warnpage and
	                            escape_url(sbconfig.warnpage) ..
	                            '%?url=http://([^/:]*)[^&]*&token=(%x*)'
	sbconfig.blockpage = settings.blockpage
	sbconfig.ttl = settings.ttl
	sbconfig.timeout = settings.timeout or sbconfig.timeout

	if settings.trackerBlock then
		sbconfig.trackerblock = {
			blockcategories = settings.trackerBlock.blockCategories or sbconfig.trackerblock.blockcategories,
			suspendperiod = settings.trackerBlock.suspendPeriod or sbconfig.trackerblock.suspendperiod,
			suspendcategories = settings.trackerBlock.suspendCategories or sbconfig.trackerblock.suspendcategories
		}
	end
end
