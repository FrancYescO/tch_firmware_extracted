--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

local mnl = require'cujo.mnl'
local luamnl = require'cujo.luamnl'

local trackedprotos = {
	[6] = 'tcp',
	[17] = 'udp',
}
local activemac = {}
local maxflows = cujo.config.traffic.maxflows
local maxpending = cujo.config.traffic.maxpending
local linespersecond = cujo.config.traffic.linespersecond
local interval = cujo.config.traffic.interval
local flows
local pending
local macs
local dnscache
local level = 'synonly'
local chains = {}

local pending_overflows = 0
local flows_overflows = 0

assert(cujo.config.traffic.conntracklines, "missing conntracklines function")

local function pendingoverflow()
	pending_overflows = pending_overflows + 1
end

local function flowsoverflow()
	flows_overflows = flows_overflows + 1
end

local function createtables()
	flows = lru.new(maxflows, nil, flowsoverflow)
	pending = lru.new(maxpending, nil, pendingoverflow)
	macs = lru.new(cujo.config.traffic.maccachesize)
	dnscache = lru.new(cujo.config.traffic.dnscachesize)
end

local function flowkey(flow)
	return flow.srcip .. ':' ..
	       flow.srcport .. ',' ..
	       flow.dstip .. ',' ..
	       flow.protonum
end

local function mackey(srcip, dstip)
	return srcip .. ',' .. dstip
end

local function normalizeip(ip)
	if cujo.util.addrtype(ip) == 'ip6' then
		ip = string.format('%x:%x:%x:%x:%x:%x:%x:%x',
			string.unpack('>I2I2I2I2I2I2I2I2', cujo.net.iptobin('ipv6', ip)))
	end
	return ip
end

local function hasappdata(flow)
	return flow.host or flow.target or flow['user-agent'] or flow.sni or flow.gquicua
end

local function updatepending()
	local tracked = 0
	local waiting = 0
	for k, f in pairs(pending) do
		if f.srcmac or f.dstmac then
			if (hasappdata(f) and (f.srcname or f.dstname)) or f.waiting then
				flows:set(k, f)
				pending:remove(k)
				f.waiting = nil
				tracked = tracked + 1
			else
				f.waiting = true
				waiting = waiting + 1
			end
			cujo.log:traffic(f.waiting and 'Waiting ' or 'Tracking ', f.srcip,
				':', f.srcport, ' -> ', f.dstip, ':', f.dstport, ' ',
				f.proto)
		end
	end
	if tracked ~= 0 or waiting ~= 0 then
		cujo.log:traffic('updatepending moved ', tracked,
			' flows to tracked and ', waiting,
			' flows set waiting')
	end
	if flows_overflows ~= 0 then
		cujo.log:traffic('updatepending caused ', flows_overflows, ' overflows to the flows queue')
		flows_overflows = 0
	end
end

local function intceil(n) 
	return n >= math.maxinteger and math.maxinteger or math.ceil(n)
end

local function incorporate_fastpath_data(entries)
	if cujo.config.traffic.get_fastpath_bytes == nil or #entries == 0 then
		return
	end
	local t0 = socket.gettime()
	local fast = cujo.config.traffic.get_fastpath_bytes(entries)
	for _, f in ipairs(fast) do
		local key, ipackets, ibytes, opackets, obytes = table.unpack(f)
		local entry = entries[key]
		local mac = entry.srcmac or entry.dstmac
		if mac then
			entry.isize = entry.isize + ibytes
			entry.osize = entry.osize + obytes
			entry.ipackets = entry.ipackets + ipackets
			entry.opackets = entry.opackets + opackets
			if not activemac[mac] then
				entry.isizeacc, entry.isize = entry.isize, 0
				entry.osizeacc, entry.osize = entry.osize, 0
				entry.ipacketsacc, entry.ipackets = entry.ipackets, 0
				entry.opacketsacc, entry.opackets = entry.opackets, 0
			end
		end
	end
	if cujo.log:flag('traffic') then
		local t1 = socket.gettime()
		cujo.log:traffic(
			'incorporate_fastpath_data got ',
			#fast, ' responses for ', #entries, ' flows in ',
			(t1 - t0) * 1000, ' ms')
	end
end

local function updateaccumulators()
	for _, f in pairs(flows) do
		f.osizeacc = f.osizeacc + f.osize
		f.isizeacc = f.isizeacc + f.isize
		f.opacketsacc = f.opacketsacc + f.opackets
		f.ipacketsacc = f.ipacketsacc + f.ipackets
	end
end

function cujo.log.custom:tune(start, lines)
    local elapsed = time.gettime() - start
    local message = string.format(
        'Processed %d lines in %5.4f seconds (%5.4f lines per second)',
        lines, elapsed, lines / elapsed)
    self.viewer.output:write(message)
end

local batch = {}
local batchlen = 0
local function ctcb_bylines(ev, id, l3proto,
		ol4protonum, osrcport, odstport, osrcip, odstip, opkts, obytes, -- orig
		rl4protonum, rsrcport, rdstport, rsrcip, rdstip, rpkts, rbytes) -- reply

	if not l3proto then return end

	local protonum = tonumber(ol4protonum)
	local proto = trackedprotos[protonum]
	if not proto then return end

	local srcip = normalizeip(mnl.bintoip(l3proto, osrcip))
	local dstip = normalizeip(mnl.bintoip(l3proto, rsrcip))
	local srcport = tonumber(osrcport)
	local dstport = tonumber(rsrcport)
	local x
	if batchlen < #batch then
		x = batch[batchlen + 1]
	else
		x = {}
		table.insert(batch, x)
	end
	batchlen = batchlen + 1
	x.proto = proto
	x.protonum = protonum
	x.srcip = srcip
	x.dstip = dstip
	x.srcport = srcport
	x.dstport = dstport
	x.osize = obytes or 0
	x.isize = rbytes or 0
	x.opackets = opkts or 0
	x.ipackets = rpkts or 0
end

local granularity = linespersecond * interval
local oldtime, readlines = time.gettime(), 0
local totallines, created
local function ctcb_bybatch()
	for i = 1, batchlen do
		local found = batch[i]
		local key = flowkey(found)
		local flow = flows[key] or pending[key]
		if not flow then
			created = created + 1
			flow = {
				proto = found.proto,
				protonum = found.protonum,
				srcip = found.srcip,
				dstip = found.dstip,
				srcport = found.srcport,
				dstport = found.dstport,
				osize = 0,
				isize = 0,
				opackets = 0,
				ipackets = 0,
				osizeacc = 0,
				isizeacc = 0,
				opacketsacc = 0,
				ipacketsacc = 0,
			}
		end
		local srcip = flow.srcip
		local dstip = flow.dstip
		flow.srcname = flow.srcname or dnscache[srcip]
		flow.dstname = flow.dstname or dnscache[dstip]
		flow.srcmac = flow.srcmac or macs[mackey(srcip, dstip)]
		flow.dstmac = flow.dstmac or macs[mackey(dstip, srcip)]
		local mac = flow.srcmac or flow.dstmac
		if mac then
			flow.osize = found.osize - flow.osizeacc
			flow.isize = found.isize - flow.isizeacc
			flow.opackets = found.opackets - flow.opacketsacc
			flow.ipackets = found.ipackets - flow.ipacketsacc
			if not activemac[mac] then
				flow.isizeacc, flow.isize = found.isize, 0
				flow.osizeacc, flow.osize = found.osize, 0
				flow.ipacketsacc, flow.ipackets = found.ipackets, 0
				flow.opacketsacc, flow.opackets = found.opackets, 0
			end
		end
		flow.updated = true
		if not flows[key] then
			flow.dstport = found.dstport
			pending:set(key, flow)
		end
		readlines = readlines + 1
		totallines = totallines + 1
	end
	batchlen = 0

	if readlines >= granularity then
		time.waituntil(oldtime + (readlines / linespersecond))
		readlines = 0
		oldtime = time.gettime()
	end
end

local conntrackevents = nil
local function readconntrack()
	if #flows ~= 0 or #pending ~= 0 then
		cujo.log:traffic(#flows, ' flows tracked and ',
			#pending, ' flows pending')
	end

	created, totallines = 0, 0
	conntrackevents:readall()
	local removedflows = 0
	local removedpending = 0
	for k, f in pairs(flows) do
		if not f.updated then
			flows:remove(k)
			removedflows = removedflows + 1
		else
			f.updated = false
		end
	end
	for k, f in pairs(pending) do
		if not f.updated and not f.waiting then
			pending:remove(k)
			removedpending = removedpending + 1
		else
			f.updated = false
		end
	end
	if created ~= 0 or removedflows ~= 0 or removedpending ~= 0 then
		cujo.log:traffic('readconntrack created ', created,
			' pending flows; removed ', removedflows,
			' tracked flows and ', removedpending,
			' pending flows')
	end
	-- check the number of pending overflows and log
	-- we don't need to check flow_overflows since that's not updated
	-- in this loop
	if pending_overflows ~= 0 then
		cujo.log:traffic('readconntrack caused ', pending_overflows, ' overflows to the pending queue')
		pending_overflows = 0
	end
end

local pollactive = false
local startsec
local function trafficpoll()
	conntrackevents = luamnl.create{
		bus = 'netfilter',
		bylines = ctcb_bylines,
		bybatch = ctcb_bybatch,
		groups = 'd',
	}
	readconntrack()

	incorporate_fastpath_data(pending)
	for _, flow in pairs(pending) do
		flow.osizeacc = flow.osize
		flow.isizeacc = flow.isize
		flow.opacketsacc = flow.opackets
		flow.ipacketsacc = flow.ipackets
	end

	while pollactive do
		local oldtime = time.gettime()

		readconntrack()

		incorporate_fastpath_data(flows)
		updatepending()
		updateaccumulators()
		local endsec = os.time()
		local pack = {
			flows = flows,
			startsec = startsec,
			startmsec = 0,
			endsec = endsec,
			endmsec = 0,
		}
		startsec = endsec
		cujo.traffic.flows(pack)
		cujo.log:tune(oldtime, totallines)
		time.waituntil(oldtime + cujo.config.traffic.timeout)
	end
	conntrackevents:close()
	-- Required not only for our own book-keeping but also to make
	-- sure that the GC will close the underlying socket.
	conntrackevents = nil
end

local macips = lru.new(cujo.config.traffic.maccachesize, function (ip, mac)
	local v = cujo.util.addrtype(ip)
	local t = cujo.traffic[v]
	local l = t[mac]
	l[ip] = nil
	if next(l) == nil then t[mac] = nil end
end)
local function setmaccache(mac, ip)
	local v = cujo.util.addrtype(ip)
	cujo.traffic[v][mac][ip], macips[ip] = true, mac
end

local function trafficevent(message)
	for i = 2, #message do
		local msg = message[i]
		local mac, dstip, srcip = msg[2], msg[3], msg[5]
		macs[mackey(srcip, dstip)] = mac
		setmaccache(mac, srcip)
	end
end

local appdatafields = {'host', 'target', 'user-agent', 'sni', 'gquicua'}
local function appdataevent(message)
	-- Can happen when Rabid is restarted and there's data from the previous
	-- instance coming in.
	if not flows then return end

	local created = 0
	local updatedflows = 0
	local updatedpending = 0
	for _, m in ipairs(message) do
		setmaccache(m.mac, m.srcip)
		local srcip = m.srcip
		local dstip = m.dstip
		local key = flowkey(m)
		local flow = flows[key]
		if flow then
			updatedflows = updatedflows + 1
		else
			flow = pending[key]
			if flow then
				updatedpending = updatedpending + 1
			else
				flow = {
					proto = trackedprotos[m.protonum],
					protonum = m.protonum,
					srcip = m.srcip,
					dstip = m.dstip,
					srcport = m.srcport,
					osizeacc = 0,
					isizeacc = 0,
					opacketsacc = 0,
					ipacketsacc = 0,
					osize = 0,
					isize = 0,
					opackets = 0,
					ipackets = 0,
				}
				created = created + 1
			end
		end
		for _, k in ipairs(appdatafields) do
			flow[k] = m[k]
		end
		flow.updated = true
		macs[mackey(srcip, dstip)] = m.mac

		if flows[key] then
			flows:set(key, flow)
		else
			pending:set(key, flow)
		end
	end
	if created ~= 0 or updatedflows ~= 0 or updatedpending ~= 0 then
		cujo.log:traffic('appdataevent created ', created,
			' pending flows, updated ', updatedflows,
			' tracked flows and ', updatedpending, ' pending flows')
	end
	if pending_overflows ~= 0 then
		cujo.log:traffic('appdataevent caused ', pending_overflows, ' overflows to the pending queue')
		pending_overflows = 0
	end
	if flows_overflows ~= 0 then
		cujo.log:traffic('appdataevent caused ', flows_overflows, ' overflows to the flows queue')
		flows_overflows = 0
	end
end

local function dnsevent(message)
	-- Can happen when Rabid is restarted and there's data from the previous
	-- instance coming in.
	if not dnscache then return end

	local domain, hosts = message.domain, message.hosts
	for _, h in ipairs(hosts) do
		dnscache[h] = domain
	end
end

local function enableappdata(chain)
	for _, proto in ipairs{'tcp', 'udp'} do
		chain['APPDATA']:append{
			{proto},
			{'conntrack', states = {'new'}},
			{'lua', func = 'nf_appdata_new_' .. proto},
			target = 'return',
		}
	end
	chain['APPDATA']:append{{'tcp'}, {'lua', func = 'nf_appdata_tcp',
		payload = true}}
	chain['APPDATA']:append{{'udp'}, {'lua', func = 'nf_appdata_udp'}}
	chain['DNSCACHE']:append{{'udp', src = 53}, {'lua',
		func = 'nf_appdata_dns'}}

	if not pollactive then
		pollactive = true
		cujo.jobs.spawn('appdata-poller', trafficpoll)
	end
end

local function disableappdata(chain)
	chain['APPDATA']:flush()
	chain['DNSCACHE']:flush()

	if pollactive then
		pollactive = false
	end
end

local function setlevel(newlevel)
	if not cujo.traffic.enable:get() then return end
	if newlevel == 'synonly' then
		cujo.traffic.conns:unsubscribe(trafficevent)
	else
		createtables()
		cujo.traffic.conns:subscribe(trafficevent)
	end
	for net in pairs(cujo.config.nets) do
		local chain = chains[net]
		if newlevel == 'synonly' then
			disableappdata(chain)
		else
			enableappdata(chain)
		end
	end
end

for net in pairs(cujo.config.nets) do
	chains[net] = {}
	for name, entries in pairs{
		DNSCACHE = {'locout', 'fwdout'},
		APPDATA = {'fwdin'},
		TRAFFIC = {'fwdin'},
	} do
		local chain = cujo.iptables.new{net = net,
			table = cujo.config.chain_table, name = name}
		chains[net][name] = chain
		for _, mainchain in ipairs(entries) do
			cujo.nf.addrule(net, mainchain, {target = chain})
		end
	end
end

cujo.traffic = {
	conns = cujo.util.createpublisher(),
	flows = cujo.util.createpublisher(),
	enable = cujo.util.createenabler('traffic', function (self, enable)
		self.enabled = enable
		for net in pairs(cujo.config.nets) do
			local chain = chains[net]
			if enable then
				chain['TRAFFIC']:append{{'tcp', flags = {syn = true}},
					{'lua', func = 'nf_traffic'}}
				startsec = os.time()
			else
				disableappdata(chain)
				chain['TRAFFIC']:flush()
			end
		end
		setlevel(level)
	end),
}
for net in pairs(cujo.config.nets) do
	cujo.traffic[net] = tabop.memoize(function() return {} end)
end


function cujo.traffic.setlevel(newlevel)
	assert(newlevel == 'synonly' or newlevel == 'appdata')
	if level == newlevel then return end
	level = newlevel
	setlevel(newlevel)
end

function cujo.traffic.getlevel()
	return level
end

function cujo.traffic.enablemac(mac)
	activemac[mac] = true
	cujo.nf.enablemac('activemac', mac, true)
end

function cujo.traffic.disablemac(mac)
	activemac[mac] = nil
	cujo.nf.enablemac('activemac', mac, false)
end

cujo.nf.subscribe('appdata', appdataevent)
cujo.nf.subscribe('dnscache', dnsevent)
cujo.nf.subscribe('traffic', cujo.traffic.conns)
