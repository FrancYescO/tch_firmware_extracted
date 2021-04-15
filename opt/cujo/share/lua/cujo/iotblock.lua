--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

local sets = {}
do
	local nets = {'mac'}
	for net in pairs(cujo.config.nets) do nets[#nets + 1] = net end
	for _, net in ipairs(nets) do
		sets[net] = cujo.ipset.new{name = 'iotblock_' .. net, type = net}
	end
	local rules = {
		{true , 'fwdin',  'dst'},
		{true , 'fwdout', 'src'},
		{false, 'fwdin',  'src'},
		{false, 'locin',  'src'},
	}
	for net in pairs(cujo.config.nets) do
		for _, rule in ipairs(rules) do
			local layer, chain, dir = table.unpack(rule)
			cujo.nf.addrule(net, chain, {
				{'conntrack', states = {'new'}},
				{'set', sets[layer and net or 'mac'], dir},
				target = 'reject',
			})
		end
	end
end

cujo.iotblock = {}

function cujo.iotblock.set(addr, add)
	local v = cujo.util.addrtype(addr)
	assert(v, 'invalid address')
	if not sets[v] then error('unsupported address type: ' .. v) end
	sets[v]:set(add, addr)
	if add then
		if v == 'mac' then
			for net in pairs(cujo.config.nets) do
				for ip in pairs(cujo.traffic[net][addr]) do
					cujo.config.connkill(net, nil, ip)
					cujo.config.connkill(net, ip, nil)
				end
			end
		else
			cujo.config.connkill(v, nil, addr)
			cujo.config.connkill(v, addr, nil)
		end
	end
end

function cujo.iotblock.flush()
	for _, set in pairs(sets) do set:flush() end
end
