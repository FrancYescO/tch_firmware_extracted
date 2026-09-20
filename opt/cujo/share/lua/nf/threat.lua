--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2020 CUJO LLC. All rights reserved.
--

-- Standard luacheck globals stanza based on what NFLua preloads and
-- the order in which cujo.nf loads these scripts.
--
-- luacheck: read globals config data
-- luacheck: read globals base64 json timer
-- luacheck: read globals debug debug_logging
-- luacheck: read globals lru
-- luacheck: read globals nf
-- luacheck: globals threat
-- luacheck: read globals conn
-- luacheck: read globals safebro sbconfig
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

threat = {}

-- MAC addresses that should be disregarded by safe browsing.
threat.bypass = {}

-- Domains that we know ahead of time to be whitelisted. At the time of writing,
-- just the domains of our own block pages.
threat.known = {}

-- Domains that the user or whitelisting from cloud has unblocked,
-- keyed by a combination of the domain and the user's MAC address.
local whitelist

-- urlchecker lookup results.
local cache

-- Domains that are undergoing urlchecker lookups.
local pending

local function extract_domain(uri)
    return uri and string.match(uri, "^https?://([^/]*).*$")
end

function threat.init()
    local warn = extract_domain(sbconfig.warnpage)
    local block = extract_domain(sbconfig.blockpage)

    if warn then threat.known[warn] = true end
    if block then threat.known[block] = true end

    pending = lru.new(config.threat.pending.maxentries, config.threat.pending.ttl)
    cache   = lru.new(config.threat.cache.maxentries, sbconfig.ttl)
    whitelist = lru.new(math.min(sbconfig.whitelist_max_entries or math.maxinteger,
                                 config.threat.whitelist.maxentries))
end

local function makekey(mac, domain)
    return mac .. ':' .. domain
end

function threat.iswhitelisted(mac, domain)
    local key = makekey(mac, domain)
    local endtime = whitelist[key]
    if not endtime then return false end
    if os.time() <= endtime then
        return true
    end
    whitelist:remove(key)
    return false
end

function threat.addwhitelist(mac, domain, endtime)
    whitelist[makekey(mac, domain)] = endtime or os.time() + config.threat.whitelist.ttl
end

function threat.addwhitelistbatch(batch_data)
    for _, entry in pairs(batch_data) do
        threat.addwhitelist(table.unpack(entry))
    end
end

function threat.lookup(domain, path)
    if threat.known[domain] or not cache then return math.maxinteger end

    local entry = cache[domain]
    if not entry then
        if not pending[domain] then
            local ok, err = nf.send('lookup', {domain = domain, path = path})
            if ok then
                pending[domain] = true
            else
                debug("nflua: 'threat.lookup' failed to send netlink msg 'lookup': %s", err)
            end
        end
        return nil -- miss
    end

    return table.unpack(entry)
end

function threat.setresponse(domain, entry, cachedomain)
    cache[domain] = entry
    pending[domain] = nil
    conn.cacheupdated(domain)
    if not cachedomain then cache[domain] = nil end
end
