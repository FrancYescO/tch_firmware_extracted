--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

threat = {}

threat.bypass    = {}
threat.known     = {}

local whitelist = lru.new(config.threat.whitelist.maxentries,
                          config.threat.whitelist.ttl)
local cache
local pending

local function extract_domain(uri)
	return uri and string.match(uri, "^https?://([^/]*).*$")
end

function threat.init()
	local warn = extract_domain(sbconfig.warnpage)
	local block = extract_domain(sbconfig.blockpage)

	cache   = lru.new(config.threat.cache.maxentries, sbconfig.ttl)
	pending = lru.new(config.threat.pending.maxentries, config.threat.pending.ttl)
	if warn then threat.known[warn] = true end
	if block then threat.known[block] = true end
end

local function makekey(mac, domain)
	return mac .. ':' .. domain
end

function threat.iswhitelisted(mac, domain)
	return whitelist[makekey(mac, domain)] ~= nil
end

function threat.addwhitelist(mac, domain)
	whitelist[makekey(mac, domain)] = true
end

function threat.lookup(domain, path)
	if threat.known[domain] then return math.maxinteger end

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
