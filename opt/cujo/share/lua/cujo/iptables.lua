--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

cujo.iptables = {meta = oo.class()}

local function iptables(net, args)
	if cujo.config.external_nf_rules then
		cujo.log:warn("NOT running: '" .. cujo.config.nets[net].iptables ..
						" -w " .. table.concat(args, " ") .. "'")
	else
		assert(cujo.jobs.exec(cujo.config.nets[net].iptables,
				cujo.util.join({'-w'}, args)))
	end
end

function cujo.iptables.new(params, persisted)
	local name = cujo.config.chain_prefix .. params.name
	local chain = cujo.iptables.meta{
		net = params.net, table = params.table, name = name}
	if persisted then
		chain:flush()
	else
		iptables(params.net, {'-t', params.table, '-N', name})
	end
	return chain
end

local function markmask(v) return table.concat({assert(v.val), v.msk}, '/') end

local targets = {
	connmark   = {'CONNMARK'},
	drop       = {'DROP'},
	['return'] = {'RETURN'},
	reject     = {'REJECT'},
}
function targets.connmark.setxmark(v) return {'--set-xmark', markmask(v)} end
function targets.reject.with(v) return {'--reject-with', v} end

local udpopts = {}
function udpopts.src(v) return {'--sport', v} end
function udpopts.dst(v) return {'--dport', v} end

local tcpopts = setmetatable({}, {__index = udpopts})
local tcpflags = {syn = 'SYN', ack = 'ACK', fin = 'FIN',
                  rst = 'RST', urg = 'URG', psh = 'PSH'}
function tcpopts.flags(v)
	local vpars, mpars = {}, {}
	for flag, val in pairs(v) do
		local flagpar = assert(tcpflags[flag])
		table.insert(mpars, flagpar)
		if val then table.insert(vpars, flagpar) end
	end
	return {'--tcp-flags', table.concat(mpars, ','), table.concat(vpars, ',')}
end

local function namedopts(args, opts, handlers)
	if not handlers then return args end
	for k, v in pairs(opts) do
		if type(k) == 'string' then
			cujo.util.join(args, assert(handlers[k])(v))
		end
	end
	return args
end

local matches = {}
for match, flag in pairs{input = '-i', output = '-o', src = '-s', dst = '-d'} do
	matches[match] = function (self, v) return v[2] and {flag, v[2]} or {} end
end
for proto, handlers in pairs{
	tcp = tcpopts, udp = udpopts, icmp = false, icmpv6 = false} do
	matches[proto] = function (self, opts)
		return namedopts({'-p', proto, '-m', proto}, opts, handlers)
	end
end
function matches:set(v)
	local set = v[2]
	assert(getmetatable(set) == cujo.ipset.meta)
	return {'-m', 'set', '--match-set', set.name,
		table.concat(v, ',', 3)}
end
function matches:lua(v)
	local args = {'-m', 'lua'}
	if v.func then cujo.util.append(args, '--function', v.func) end
	if v.payload then cujo.util.append(args, '--tcp-payload') end
	return args
end
function matches:connmark(v)
	return {'-m', 'connmark', '--mark', markmask(v)}
end

local ctstate = {
	invalid = 'INVALID', new = 'NEW', established = 'ESTABLISHED',
	related = 'RELATED', untracked = 'UNTRACKED', snat = 'SNAT', dnat = 'DNAT',
}
local function toctstate(state) return assert(ctstate[state]) end
function matches:conntrack(v)
	local args = {'-m', 'conntrack'}
	if v.states then
		local states = {vararg.map(toctstate, table.unpack(v.states))}
		cujo.util.append(args, '--ctstate', table.concat(states, ','))
	end
	return args
end

function cujo.iptables.meta:append(params)
	local args = {'-t', self.table, '-A', self.name}
	for _, v in ipairs(params) do
		local mod = assert(v[1])
		cujo.util.join(args, assert(matches[mod])(self, v))
	end
	local target = params.target
	if target then
		if getmetatable(target) == cujo.iptables.meta then
			assert(target.net == self.net)
			assert(target.table == self.table)
			cujo.util.append(args, '-j', target.name)
		else
			if type(target) == 'string' then target = {target} end
			local t = assert(target[1])
			cujo.util.append(args, '-j', assert(targets[t])[1])
			namedopts(args, target, targets[t])
		end
	end
	iptables(self.net, args)
end

function cujo.iptables.meta:flush()
	iptables(self.net, {'-t', self.table, '-F', self.name})
end
