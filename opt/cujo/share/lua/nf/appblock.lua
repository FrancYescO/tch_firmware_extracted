--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

appblock = {}
local blocked = {}

local portmap = {
	[nf.proto.tcp] = function(ip) return nf.tcp(ip).dport end,
	[nf.proto.udp] = function(ip) return nf.udp(ip).dport end,
}

function appblock.add(set, id) blocked[set][id] = true end
function appblock.del(set, id) blocked[set][id] = nil end
function appblock.flush(set)
	blocked[set] = lru.new(config.appblock.maxentries, config.appblock.ttl)
end

function nf_appblock(frame, packet)
	local ip = nf.ip(packet)
	local proto = ip.version == 4 and ip.protocol or ip.nh
	local map = portmap[proto]
	local port = map and map(ip) or 0
	local mac = nf.mac(frame).src
	local fmt = ip.version == 4 and 'I6Bc4I2' or 'I6Bc16I2'
	local id = string.pack(fmt, mac, proto, ip.dst, port)

	for k,_ in pairs(blocked) do
		if blocked[k][id] then return true end
	end
	return false
end
