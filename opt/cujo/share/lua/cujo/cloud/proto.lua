--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

local module = {}
cujo.cloud.apiversion = '1.0'

function module.status(channel, body)
	cujo.log:warn('agent status ', body.status)
	if body.status == 'ACTIVE' then cujo.cloud.send('resync', {}) end
end

local ispublicv = {
	ip4 = function (ip)
		local bytes = {string.match(ip, '(%d+).(%d+).(%d+).(%d+)')}
		for k, v in ipairs(bytes) do bytes[k] = tonumber(v) end
		return not (bytes[1] == 10 or -- class A
			(bytes[1] == 172 and bytes[2] >= 16 and bytes[2] <= 31) or -- class B
			(bytes[1] == 192 and bytes[2] == 168)) -- class C
			and ip
	end,
	ip6 = function (ip)
		local hextet = tonumber(string.match(ip, '(%w*):') or 0, 16)
		return not (hextet >= 0xfc00 and hextet <= 0xfdff) and ip
	end
}
local function ispublic(ip)
	return ip and (ispublicv[cujo.util.addrtype(ip)] or
		error'unknown address type')(ip)
end

local rules = {}

function module.access(channel, body)
	local ids = {}
	for _, rule in ipairs(body.add) do
		local id, src, dst = rule.id, rule.source.ip, rule.destination.ip
		if rules[id] then
			cujo.log:warn('access: id ', id, ' already added')
		else
			local ip = ispublic(src) or ispublic(dst)
			if ip then
				cujo.iotblock.set(ip, true)
				rules[id] = ip
				table.insert(ids, id)
			else
				cujo.log:warn('access: no public ip')
			end
		end
	end
	cujo.cloud.send('access', {rules = ids})

	for _, id in ipairs(body.remove) do
		local ip = rules[id]
		if ip then
			cujo.iotblock.set(ip, false)
			rules[id] = nil
		else
			cujo.log:warn('access: id ', id, ' not in set')
		end
	end
end

cujo.traffic.conns:subscribe(function (message)
	local lost = message[1]
	if lost ~= 0 then
		cujo.log:warn('traffic ', lost, ' connections lost')
	end
	local flows = {}
	for i = 2, #message do
		local out, mac, sip, dport, dip, time, count = table.unpack(message[i])
		local flow = {
			ipProtocol = 6, tcpInitiator = 1,
			start = math.floor(time / 1000), startMsec = time % 1000,
			source = {}, destination = {port = dport},
			packets = count, size = count * 40,
		}
		if out == 'o' then
			flow.source.mac, flow.source.ip = mac, dip
			flow.destination.ip = sip
		else
			flow.source.ip = sip
			flow.destination.mac, flow.destination.ip = mac, dip
		end
		flows[#flows + 1] = flow
	end
	cujo.cloud.send('traffic-messages', flows)
end)

local flows = {}
local flowslen = 0
cujo.traffic.flows:subscribe(function (message)
	flowslen = 0
	local startsec = message.startsec
	local startmsec = message.startmsec
	local endsec = message.endsec
	local endmsec = message.endmsec
	for _, v in pairs(message.flows) do
		local ipackets = v.ipackets
		local opackets = v.opackets
		if ipackets > 0 or opackets > 0 then
			local protonum = v.protonum
			local gquicua = v.gquicua
			local sni = v.sni
			local host = v.host
			local target = v.target
			local useragent = v['user-agent']
			local function addflow()
				local f
				if flowslen < #flows then
					f = flows[flowslen + 1]
				else
					f = {
						source = {},
						destination = {},
						tcpInitiator = 0,
					}
					flows[#flows + 1] = f
				end
				flowslen = flowslen + 1

				f.start = startsec
				f.startMsec = startmsec
				f['end'] = endsec
				f.endMsec = endmsec
				f.ipProtocol = protonum
				f.quicUa = gquicua
				f.sslSni = sni
				if host or target then
					if host and target then
						f.httpUrl = host .. target
					elseif host then
						f.httpUrl = host
					else
						f.httpUrl = target
					end
				else
					-- In case it's a recycled object, make
					-- sure we don't re-use an old value.
					f.httpUrl = nil
				end
				f.httpUserAgent = useragent
				return f
			end
			local srcip = v.srcip
			local srcmac = v.srcmac
			local srcport = v.srcport
			local srcname = v.srcname
			local dstip = v.dstip
			local dstmac = v.dstmac
			local dstport = v.dstport
			local dstname = v.dstname
			local osize = v.osize
			local isize = v.isize
			if opackets > 0 then
				local f = addflow()
				f.source.ip = srcip
				f.source.mac = srcmac
				f.source.port = srcport
				f.source.name = srcname
				f.destination.ip = dstip
				f.destination.mac = dstmac
				f.destination.port = dstport
				f.destination.name = dstname
				f.packets = opackets
				f.size = osize
			end
			if ipackets > 0 then
				local f = addflow()
				f.destination.ip = srcip
				f.destination.mac = srcmac
				f.destination.port = srcport
				f.destination.name = srcname
				f.source.ip = dstip
				f.source.mac = dstmac
				f.source.port = dstport
				f.source.name = dstname
				f.packets = ipackets
				f.size = isize
			end
			if flowslen >= cujo.config.traffic.msgflows then
				cujo.cloud.send('traffic-messages', table.move(flows, 1, flowslen, 1, {}))
				flowslen = 0
				collectgarbage()
			end
		end
	end
	if flowslen > 0 then
		cujo.cloud.send('traffic-messages', table.move(flows, 1, flowslen, 1, {}))
		collectgarbage()
	end
end)

module['safebro-config'] = function (channel, body)
	cujo.safebro.configure(body)
end

module['parental-config'] = function (channel, body)
	cujo.safebro.setprofiles(body.profiles)
end

cujo.safebro.threat:subscribe(function (message)
	cujo.cloud.send('threat', message)
end)

function module.scan(channel, body)
	if body.protocol ~= 'ssdp' then
		return cujo.log:error('invalid device scan protocol: ', body.protocol)
	end
	local err = cujo.ssdp.scan(body.timeout or 180,
		body.maxsize or 16 * 4096)
	if err then return cujo.log:error('SSDP scan error: ', err) end
end

cujo.ssdp.reply:subscribe(function (ip, mac, payload)
	cujo.cloud.send('scan', {
		protocol = 'ssdp', payload = payload, ip = ip, mac = mac
	})
end)

function module.hibernate(channel, body)
	cujo.hibernate.start(body.duration * 60)
end

function module.status_update(channel, body)
	cujo.log:status_update('mac=', body.mac,
			       ' status=', body.active,
			       ' monitored=', body.monitored,
			       ' secured=', body.secured,
			       ' safebro=', body.safe_browsing,
			       ' fingerprint=', body.fingerprint)
	if not body.mac:match('^%x%x:%x%x:%x%x:%x%x:%x%x:%x%x$') then
		cujo.log:warn('status_update: ignoring invalid mac address ', body.mac)
		return
	end
	if body.mac == '00:00:00:00:00:00' then
		return cujo.log:warn('status_update: ignoring null mac')
	end
	cujo.safebro.setbypass(body.mac, not body.safe_browsing)
	cujo.iotblock.set(body.mac, body.active)
	cujo.fingerprint.setbypass(body.mac, not body.fingerprint)
end

local deviceenable = {}
function deviceenable.dp(mac, enable)
	action = enable and 'enablemac' or 'disablemac'
	cujo.traffic[action](mac)
end

 module['device-status-update'] = function (channel, body)
	local activator = deviceenable[body.name]
	if not activator then
		return cujo.log:warn('invalid device status update feature: ', body.name)
	end
	for _, mac in ipairs(body.macs) do
		activator(mac:upper(), body.enabled)
	end
end

function module.http_fetch(channel, body)
	local data, status, httphdrs = cujo.https.request{
		url = body.url,
		redirect = true,
		create = cujo.https.connector.simple()
	}
	if not data then
		return cujo.log:warn('http request failed: ', body.url,
			', responded with code ', status, "'")
	end
	body.payload = base64.encode(data)
	body.mimetype = httphdrs['content-type'] or ''
	body.context = body.context or {}
	cujo.cloud.send('http_response', body)
end

module['app-block'] = function (channel, body)
	if not cujo.appblock.enable:get() then
		cujo.log:stomp('ignoring app-block message as appblock is disabled')
		return
	end
	for _, add in ipairs{true, false} do
		for _, v in ipairs(body[add and 'add' or 'del'] or {}) do
			cujo.appblock[v.expires and 'timed' or 'main'].set(
				body.mac:upper(), v.ip, v.protocol, v.port, add)
		end
	end
end

module['app-block-reset'] = function (channel, body)
	assert(body.expirationDelay >= 0,
		'invalid expirationDelay, must be non negative.')
	cujo.appblock.main.flush()
	cujo.appblock.timed.reset(body.expirationDelay, body.expirationPeriod)
end

for pub, tap in pairs{
	dhcp = 'dhcp', dns = 'dns', mdns = 'mdns', http = 'httpsig', tcp = 'tcpsig',
} do
	cujo.fingerprint[pub]:subscribe(function (msg) cujo.cloud.send(tap, msg) end)
end

cujo.cloud.onconnect:subscribe(function ()
	rules = {}
	cujo.iotblock.flush()
	cujo.appblock.main.flush()
	cujo.appblock.timed.reset()
	cujo.fingerprint.flush()
	cujo.safebro.configure(nil)
	cujo.safebro.setprofiles{}
	cujo.ssdp.cancel()
end)

return module
