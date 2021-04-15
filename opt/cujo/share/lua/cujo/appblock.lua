--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

local chains = {}
for net in pairs(cujo.config.nets) do
	local chain = cujo.iptables.new{
		net = net, table = cujo.config.chain_table, name = 'APPBLOCK',
	}
	for _, mainchain in ipairs{'fwdin', 'fwdout'} do
		cujo.nf.addrule(net, mainchain, {target = chain})
	end
	chains[net] = chain
end

local prototoint = {tcp = 6, udp = 17}
local packfmt = {ip4 = 'I6Bc4I2', ip6 = 'I6Bc16I2'}

local function set(name, mac, ip, proto, port, add)
	assert(cujo.appblock.enable:get() == true, 'feature not enabled')
	local ipv, ipb = cujo.util.addrtype(ip)
	local id = string.pack(packfmt[ipv], tonumber(mac:gsub(':', ''), 16),
		prototoint[proto], ipb, port)
	local action = add and 'add' or 'del'
	cujo.nf.dostring(string.format('appblock[%q](%q, %q)', action, name, id))
	if add then
		for sip in pairs(cujo.traffic[ipv][mac]) do
			cujo.config.connkill(ipv, sip, ip, proto, port)
		end
	end
	cujo.log:appblock(action, ' ', mac, ', ', ip, ', ', proto, ', ', port,
		" in set '", name, "'")
end

local function flush(name)
	cujo.nf.dostring(string.format('appblock.flush(%q)', name))
	cujo.log:appblock("flush set '", name, "'")
end

local sets = {'main', 'timed'}
cujo.appblock = {
	enable = cujo.util.createenabler('appblock', function (self, enable)
		for _, name in pairs(sets) do flush(name) end
		for _, chain in pairs(chains) do
			chain:flush()
			if enable then
				chain:append{
					{'conntrack', states = {'new'}},
					{'lua', func = 'nf_appblock'},
					target = 'reject'
				}
			end
		end
		self.enabled = enable
	end),
}

for _, name in ipairs(sets) do
	local methods = {}
	for method, func in pairs{set = set, flush = flush} do
		methods[method]  = function (...) return func(name, ...) end
	end
	cujo.appblock[name] = methods
	flush(name)
end

local timedreset = {}
function cujo.appblock.timed.reset(delay, period)
	event.emitone(timedreset, delay, period)
end

cujo.jobs.spawn("appblock-flush-timer", function()
	local delay, period
	while true do
		local ev, newdelay, newperiod = cujo.jobs.wait(delay, timedreset)
		if ev == timedreset then
			delay, period = newdelay, newperiod
			cujo.log:appblock('reset next timed flush in ', delay, 's',
			                  ' then, every ', period, 's')
		else
			delay = period
		end
		cujo.jobs.spawn("appblock-flusher", cujo.appblock.timed.flush)
	end
end)
