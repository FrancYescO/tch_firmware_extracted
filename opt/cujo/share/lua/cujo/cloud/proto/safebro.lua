--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2020 CUJO LLC. All rights reserved.
--

local module = {}

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

function module.getconfig(settings)
    local sbconfig = {}
    sbconfig.profiles = load_profiles(settings.profiles or {})
    sbconfig.threshold = settings.threshold
    sbconfig.warnpage = settings.warnpage
    sbconfig.warnpage_pattern = sbconfig.warnpage and
                                escape_url(sbconfig.warnpage) ..
                                '%?url=http://([^/:]*)[^&]*&token=(%x*)'
    sbconfig.blockpage = settings.blockpage
    sbconfig.ttl = settings.ttl
    sbconfig.timeout = settings.timeout
    sbconfig.cacheurl = settings.cacheurl
    sbconfig.cachettl = settings.cachettl
    sbconfig.token = settings.token
    sbconfig.endpoint = settings.endpoint
    sbconfig.whitelist_max_entries = settings.whitelistMaxEntries

    if settings.trackerBlock then
        sbconfig.trackerblock = {
            blockcategories = settings.trackerBlock.blockCategories or sbconfig.trackerblock.blockcategories,
            suspendperiod = settings.trackerBlock.suspendPeriod or sbconfig.trackerblock.suspendperiod,
            suspendcategories = settings.trackerBlock.suspendCategories or sbconfig.trackerblock.suspendcategories
        }
    end

    return sbconfig
end

function module.getprofiles(settings)
    return load_profiles(settings.profiles or {})
end

return module
