--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

activemac = {}
local tim = false

local dropped = 0
local entries = {}

local evicted = 0
local cache = lru.new(config.appdata.maxentries, function()
	evicted = evicted + 1 end)

local tmpfields = {'previous', 'method', 'referer', 'stage', 'notssl'}
local httpfields = {'host', 'target', 'user-agent'}

local parsers = {
	function (entry, payload)
		if entry.notssl then return end
		local segpayload = payload:layout(ssl.layout)
		if ssl.is_client_hello(segpayload) then
			entry.sni = ssl.extract_hostname(segpayload)
			if entry.sni then return 'ssl' end
		end
		entry.notssl = true
	end,
	function (entry, payload)
		if entry.stage == 'done' or entry.stage == 'error' then return end
		local info = http.headerinfo(entry, tostring(payload))
		return (info == 'done' and entry.method == 'GET' and entry.host) and
			'http' or info == 'notdone'
	end,
}
local function parsetcp(entry, payload)
	local done = true
	for _, f in ipairs(parsers) do
		local status = f(entry, payload)
		if type(status) == 'string' then return status end
		if status then done = false end
	end
	return done
end

local function send()
	if dropped > 0 or evicted > 0 then
		debug('appdata dropped:%s evicted:%s', dropped, evicted)
		dropped = 0
		evicted = 0
	end
	local ok, err = nf.send('appdata', entries)
	if not ok then
		debug("nflua: 'send' failed to send netlink msg 'appdata': %s", err)
	end
	tim = false
	entries = {}
end

local function extractl4andlower(proto, packet)
	local ip = nf.ip(packet)
	return ip, nf[proto](ip)
end

local function submit(entry, proto, frame, ip, l4data)
	entry.srcip = nf.toip(ip.src)
	entry.dstip = nf.toip(ip.dst)
	entry.protonum = nf.proto[proto]
	entry.mac = nf.tomac(nf.mac(frame).src)
	entry.srcport = l4data.sport
	entries[#entries + 1] = entry
	tim = tim or timer.create(config.appdata.timeout * 1000, send)
end

local function regflow(id, entry, frame, packet)
	local ip, l4data, payload = extractl4andlower('tcp', packet)
	if not payload then return end
	local status = parsetcp(entry, payload)
	if status ~= false then cache[id] = nil end
	if type(status) ~= 'string' then return end
	if #entries >= config.appdata.maxentries then
		dropped = dropped + 1
		return
	end

	for _, f in ipairs(tmpfields) do entry[f] = nil end
	if status ~= 'http' then
		for _, f in ipairs(httpfields) do entry[f] = nil end
	end
	submit(entry, 'tcp', frame, ip, l4data)
end

function nf_appdata_new_tcp(frame, packet)
	local id = nf.connid()
	local mac = nf.mac(frame).src
	if not activemac[mac] then
		cache[id] = nil
		return true
	end
	local entry = {}
	cache[id] = entry
	regflow(id, entry, frame, packet)
	return true
end

function nf_appdata_tcp(frame, packet)
	local mac = nf.mac(frame).src
	if not activemac[mac] then return end
	local id = nf.connid()
	local entry = cache[id]
	if entry then regflow(id, entry, frame, packet) end
end

function nf_appdata_new_udp(frame, packet)
	local id = nf.connid()
	local mac = nf.mac(frame).src
	if not activemac[mac] then
		cache[id] = nil
		return true
	end
	if #entries >= config.appdata.maxentries then
		dropped = dropped + 1
		cache[id] = true
		return true
	end
	local ip, l4data, payload = extractl4andlower('udp', packet)
	local entry = {}
	if payload then entry.sni, entry.gquicua = gquic.parse(payload) end
	submit(entry, 'udp', frame, ip, l4data)
	cache[id] = not (entry.sni or entry.gquicua) or nil
	return true
end

function nf_appdata_udp(frame, packet)
	local id = nf.connid()
	if cache[id] == nil then return end
	if #entries >= config.appdata.maxentries then
		dropped = dropped + 1
		return
	end

	local ip, l4data, payload = extractl4andlower('udp', packet)
	if not payload then return end
	local entry = {}
	entry.sni, entry.gquicua = gquic.parse(payload)
	if not entry.sni and not entry.gquicua then return end
	submit(entry, 'udp', frame, ip, l4data)
	cache[id] = nil
end

function nf_appdata_dns(_, packet)
	local _, _, payload = extractl4andlower('udp', packet)
	if not payload then return end
	local domain, hosts = dns.parse(payload)
	if domain and #hosts > 0 then
		for i, ip in ipairs(hosts) do
			hosts[i] = nf.toip(ip)
		end
		local ok, err = nf.send('dnscache', {domain = domain, hosts = hosts})
		if not ok then
			debug("nflua: 'nf_appdata_dns' failed to send netlink msg 'dnscache': %s", err)
		end
	end
end
