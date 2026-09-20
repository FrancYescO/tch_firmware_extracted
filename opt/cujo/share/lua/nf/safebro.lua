--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

-- Standard luacheck globals stanza based on what NFLua preloads and
-- the order in which cujo.nf loads these scripts.
--
-- luacheck: read globals config data
-- luacheck: read globals base64 json timer
-- luacheck: read globals debug debug_logging
-- luacheck: read globals lru
-- luacheck: read globals nf
-- luacheck: read globals threat
-- luacheck: read globals conn
-- luacheck: globals safebro sbconfig
-- luacheck: read globals ssl
-- luacheck: read globals http
-- (caps exports no globals)
-- (tcptracker exports no globals)
-- (apptracker exports no globals)
-- luacheck: read globals p0f_httpsig p0f_tcpsig
-- (httpcap exports no globals)
-- (tcpcap exports no globals)
-- luacheck: read globals appblocker
-- luacheck: read globals gquic
-- luacheck: read globals dns
-- (ssdpcap exports no globals)

safebro = {}
safebro.reasons = {
    parental = 0,
    tracker = -1
}

safebro.status = {
    profiles = {
        enabled = false
    },
    reputation = {
        enabled = false
    },
    trackerblock = {
        enabled = false
    }
}

local suspended = lru.new(config.trackerblock.maxentries)

sbconfig = {}
local profiles = {}

local default_cfgmeta = {
    __index = {
        threshold = 25,
        ttl = 24 * 60 * 60,
        timeout = 350,
        profile = {domains = {}, categories = {}, default = true},
    }
}

-- Searches for a wildcard domain match in the given table. For example, given
-- "foo.bar.baz.org", this returns the first value found for the following keys:
--
--     foo.bar.baz.org
--     *.bar.baz.org
--     *.baz.org
--     *.org
--     *
--
-- Returning nil if none of the above are found.
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

local function notify(mac, ip, domain, path, reason, score, categories)
    return nf.send('notify', {ip = nf.toip(ip), mac = nf.tomac(mac),
        uri = domain .. path, reason = reason, score = score,
        categories = categories})
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

local function profilesfilter(mac, ip, domain, path, categories)
    local profile = profiles and profiles[mac] or sbconfig.profile
    local listed, allow = islisted(domain, profile.domains)

    if not listed and isallowed(profile, categories) then
        -- Domain is whitelisted by a profile and we're not
        -- checking for trackers.
        return 'continue'
    elseif not allow then
        -- Domain is blacklisted by a profile.
        local score, reason = 0, safebro.reasons.parental
        local ok, err = notify(mac, ip, domain, path, reason, score, categories)
        if not ok then
            debug("nflua: 'profilesfilter' failed to send netlink msg 'notify': %s", err)
        end
        return 'block', reason
    end

    return 'continue'
end

local function reputationfilter(mac, ip, domain, path, score, reason, categories)
    if isbad(score) then
        -- urlchecker score is too low.
        local ok, err = notify(mac, ip, domain, path, reason, score, categories)
        if not ok then
            debug("nflua: 'reputationfilter' failed to send netlink msg 'notify': %s", err)
        end
        return 'block', reason
    end

    return 'continue'
end

local function trackerblockfilter(mac, ip, domain, path, categories)
    if safebro.trackersallowed(mac) then
        -- Tracker blocking is suspended.
        return 'continue'
    end

    if iswhitelistedtracker(sbconfig, categories) then
        -- Matches a known tracker blocking suspension category.
        suspendblocker(mac)
        return 'allow'
    end

    if istracker(sbconfig, categories) then
        -- Matches a known tracker category.
        local ok, err = nf.send('trackerblock', {mac = nf.tomac(mac),
            uri = domain .. path, categories = categories})
        if not ok then
            debug("nflua: 'safebro.filter' failed to send netlink msg 'trackerblock': %s", err)
        end
        -- Matches a known tracker category.
        return 'block', safebro.reasons.tracker
    end

    return 'continue'
end

function safebro.config(settings)
    sbconfig = setmetatable(settings, default_cfgmeta)
    safebro.status.profiles.enabled = sbconfig.features and sbconfig.features.profiles == true
    safebro.status.reputation.enabled = sbconfig.features and sbconfig.features.reputation == true
    safebro.status.trackerblock.enabled = sbconfig.features and
        sbconfig.features.trackerblock == true and sbconfig.trackerblock
    threat.init()
end

function safebro.setprofiles(newprofiles)
    profiles = newprofiles
end

-- Determines whether a connection should be blocked and why. Potentially makes
-- a request for userspace to ask urlchecker (via threat.lookup). Sends messages
-- to userspace when appropriate:
--
-- * Threat notifications ("notify")
-- * Tracker notifications ("trackerblock")
--
-- There are various possible reasons to (not) block a connection. In order of
-- descending priority:
--
-- 1. Matches a known tracker category (privacy)
-- 2. Domain is whitelisted/blacklisted by a profile (parental controls)
-- 3. Category is blacklisted by a profile (parental controls)
-- 4. urlchecker score is too low (threat)
--
-- In addition, if the connection is not to be blocked and its category matches
-- a tracker blocking suspension category (privacy whitelist), tracker blocking
-- is suspended for the originating MAC address for some time.
--
-- Returns a pair: whether the urlchecker result is available or not (if false,
-- we are waiting on userspace to perform the urlchecker lookup) and what the
-- reason for blocking is. The caller should block the connection iff a non-nil
-- reason is returned.
--
-- Note that in the case where the reason is known to be that the domain is
-- blacklisted by a profile, we can return false together with a reason.
function safebro.filter(mac, ip, domain, path)
    if not safebro.status.reputation.enabled and
        not safebro.status.profiles.enabled and
        not safebro.status.trackerblock.enabled then
        return 'allow'
    end

    local action

    local score, reason, categories = threat.lookup(domain, path)
    if not score then
        -- No urlchecker result yet.
        return 'miss'
    end

    if safebro.status.reputation.enabled then
        action, reason = reputationfilter(mac, ip, domain, path, score, reason, categories)
        if action ~= 'continue' then return action, reason end
    end
    if safebro.status.profiles.enabled then
        action, reason = profilesfilter(mac, ip, domain, path, categories)
        if action ~= 'continue' then return action, reason end
    end
    if safebro.status.trackerblock.enabled then
        action, reason = trackerblockfilter(mac, ip, domain, path, categories)
        if action ~= 'continue' then return action, reason end
    end
    return 'allow'
end
