--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

assert(cujo.config.getdevaddr, "missing porting defined getdevaddr function")
assert(cujo.config.ssdpbindport, "missing SSDP bind port configuration")

local socks = {}
do
	local chains = {}
	for net in pairs(cujo.config.nets) do
		local chain = cujo.iptables.new{
			net = net, table = cujo.config.chain_table, name = 'SSDP'}
		cujo.nf.addrule(net, 'locin', {target = chain})
		chains[net] = chain
	end

	local sockcons = {ip4 = 'udp', ip6 = 'udp6'}
	local socktype = {ip4 = 'ipv4', ip6 = 'ipv6'}
	local function helper(iface, net)
		local ip = cujo.config.getdevaddr(iface, socktype[net])
		if not ip then return end

		local sock, err = socket[sockcons[net]]()
		if not sock then error('creating socket: ' .. err) end

		local ok, err = sock:setsockname(ip, cujo.config.ssdpbindport)
		if not ok then error('binding socket: ' .. err) end

		local _, port = sock:getsockname()
		chains[net]:append{
			{'input', iface}, {'udp', dst = port},
			{'lua', func = 'nf_ssdp'}, target = 'drop'
		}
		return sock
	end
	for _, iface in pairs(cujo.config.lan_ifaces) do
		local set = {}
		for net in pairs(cujo.config.nets) do
			local sock = helper(iface, net)
			if sock ~= nil then
				set[net] = sock
			end
		end
		if next(set) then socks[iface] = set end
	end
end

cujo.ssdp = {reply = cujo.util.createpublisher()}

function cujo.ssdp.cancel() event.emitall(socks, true) end

cujo.jobs.spawn("ssdp-reader", function ()
	local remaining
	local function reply (msg)
		local payload = base64.encode(msg.payload)
		remaining = math.max(remaining - #payload, 0)
		cujo.log:scan('SSDP reply received from ', msg.ip, ' (', remaining,
			' bytes left)')
		cujo.ssdp.reply(msg.ip, msg.mac, payload)
		if remaining == 0 then cujo.ssdp.cancel() end
	end
	local timeout
	local active = false
	while true do
		local ev, cancel, to, ms = cujo.jobs.wait(timeout, socks)
		if ev == socks and not cancel then
			cujo.nf.subscribe('ssdp', reply)
			timeout, remaining = to, ms
			active = true
		else
			cujo.nf.unsubscribe('ssdp', reply)
			timeout, remaining = nil, nil
			if active then cujo.log:scan'done waiting SSDP replies' end
			active = false
		end
	end
end)

local addrs = {ip4 = '239.255.255.250', ip6 = 'ff02::c'}
local port = 1900
function cujo.ssdp.scan(timeout, maxsize)
	event.emitall(socks, false, timeout, maxsize)
	cujo.log:scan('sending SSDP request (timeout=', timeout, ')')
	for iface, set in pairs(socks) do
		for net, sock in pairs(set) do
			local addr = addrs[net]
			local host = net == 'ip4' and addr or '[' .. addr .. ']'
			local msg = 'M-SEARCH * HTTP/1.1\r\n' ..
				    'HOST: ' .. host .. ':' .. port .. '\r\n' ..
				    'MAN: "ssdp:discover"\r\n' ..
				    'MX: ' .. timeout .. '\r\n' ..
				    'ST: ssdp:all\r\n\r\n'
			assert(sock:sendto(msg, addr, port))
		end
	end
end
