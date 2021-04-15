--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

local Viewer = require'loop.debug.Viewer'

local netlink = assert(socket.netlink(cujo.config.nf.netlink.family))
assert(netlink:bind(cujo.config.nf.netlink.port))

cujo.nf = {}

local scripts = {
	'nf.debug',
	'nf.lru',
	'nf.nf',
	'nf.sbconfig',
	'nf.threat',
	'nf.conn',
	'nf.safebro',
	'nf.ssl',
	'nf.http',
	'nf.caps',
	'nf.traffic',
	'nf.appdata',
	'nf.p0f',
	'nf.httpcap',
	'nf.tcpcap',
	'nf.appblock',
	'nf.gquic',
	'nf.dns',
	'nf.ssdpcap',
}
local mainchains = {}
local channels = tabop.memoize(cujo.util.createpublisher)

function cujo.nf.subscribe(channel, handler) channels[channel]:subscribe(handler) end
function cujo.nf.unsubscribe(channel, handler) channels[channel]:unsubscribe(handler) end

function cujo.nf.enablemac(tablename, mac, add)
	cujo.nf.dostring(string.format('%s[%d] = %s',
		tablename, tonumber(string.gsub(mac, ':', ''), 16), add and true or nil))
end

function cujo.nf.dostring(script, path)
	local payload = script
	if path ~= nil then payload = '@' .. path .. '\0' .. script end
	local ok, err = netlink:sendto(payload, 0)
	if not ok then
		if path == nil then path = string.sub(script, 1, 20) end
		cujo.log:error("unable to send script '", path, "' to NFLua (", err, ')')
	end
end

function cujo.nf.addrule(net, chain, rule) mainchains[chain][net]:append(rule) end

local serializer = Viewer{
	linebreak = false,
	nolabels = true,
	nofields = true,
	noarrays = true,
}
local config_nf = serializer:tostring(cujo.config.nf)
cujo.nf.dostring(string.format([[
	nf._ENV = {}
	setmetatable(_G, {__index = nf._ENV, __newindex = nf._ENV})
	debug_logging = %s
	config = %s]],
	cujo.log:flag('nflua_debug'),
	config_nf))
cujo.nf.initialized = true
cujo.nf.subscribe('log', function(msg) cujo.log:warn(table.unpack(msg)) end)

for _, script in ipairs(scripts) do
	local path, err = package.searchpath(script, package.path)
	if not path then
		error("unable to find NFLua script '" .. script .. "' " .. err)
	end
	cujo.log:nflua('send script ', path)
	cujo.nf.dostring(assert(cujo.filesys.readfrom(path, 'a')), path)
end

cujo.jobs.spawn("nflua-reader", function ()
	while true do
		local ok, payload = netlink:receivefrom()
		if not ok then
			cujo.log:error('unable to receive payload from NFLua: ', payload)
			goto continue
		end
		cujo.log:nflua('got message ', payload)
		local channel, args = payload:match('(%w+) (.*)')
		local ok, message = pcall(json.decode, args)
		if not ok then
			cujo.log:error('unable to decode json from NFLua: ', message)
			goto continue
		end
		channels[channel](message)
		::continue::
	end
end)

local entrychains = {}
for k, name in pairs{input = 'INPUT', output = 'OUTPUT', forward = 'FORWARD'} do
	entrychains[k] = {}
	for net in pairs(cujo.config.nets) do
		entrychains[k][net] = cujo.iptables.new(
			{net = net, table = cujo.config.chain_table, name = name}, true)
	end
end

local otherdir = {output = 'input', input = 'output'}
local mainprefix = 'MAIN_'
for mainchain, v in pairs{
	locin  = {'LOCIN' , 'input'  , 'input' },
	locout = {'LOCOUT', 'output' , 'output'},
	fwdin  = {'FWDIN' , 'forward', 'input' },
	fwdout = {'FWDOUT', 'forward', 'output'},
} do
	local name, entry, dir = table.unpack(v)
	local params = {table = cujo.config.chain_table, name = mainprefix .. name}
	local chains = {}
	for net in pairs(cujo.config.nets) do
		local chain = cujo.iptables.new(tabop.copy(params, {net = net}))
		for _, iface in ipairs(cujo.config.lan_ifaces) do
			if entry == 'forward' then
				for _, wanface in ipairs(cujo.config.wan_ifaces) do
					local rule = {{dir, iface}, {otherdir[dir], wanface}, target = chain}
					entrychains[entry][net]:append(rule)
				end
			else
				local rule = {{dir, iface}, target = chain}
				entrychains[entry][net]:append(rule)
			end
		end
		chains[net] = chain
	end
	mainchains[mainchain] = chains
end

local params = {table = cujo.config.chain_table,
	name = mainprefix .. 'LANTOLAN'}
mainchains.lantolan = {}
for net in pairs(cujo.config.nets) do
	local chain = cujo.iptables.new(tabop.copy(params, {net = net}))
	for _, i in ipairs(cujo.config.lan_ifaces) do
		for _, o in ipairs(cujo.config.lan_ifaces) do
			entrychains.forward[net]:append{
				{'input', i}, {'output', o}, target = chain,
			}
		end
	end
	mainchains.lantolan[net] = chain
end
