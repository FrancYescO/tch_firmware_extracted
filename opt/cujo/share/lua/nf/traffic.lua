--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

local conns = {0}
for i = 1, config.traffic.maxentries do
	conns[i + 1] = {nil, nil, nil, nil, nil, nil, nil}
end
local aggrs = setmetatable({}, {__mode = 'v'})
local numconns = 1
local tim = false

local function send()
	local pack = {}
	table.move(conns, 1, numconns, 1, pack)
	if nf.send('traffic', pack) then
		conns[1] = 0
	else
		-- Don't print the usual "failed to send netlink msg" here,
		-- since this branch is commonly hit in heavy traffic scenarios
		-- like DoS attacks and we want to avoid having to do any extra
		-- work here.
		for i = 2, numconns do
			conns[1] = conns[1] + conns[i][7]
		end
	end
	for k in pairs(aggrs) do aggrs[k] = nil end
	numconns = 1
	tim = false
end

local kf = {nil, nil, nil, nil}
function nf_traffic(frame, packet)
	if not tim then tim = timer.create(config.traffic.pollinterval * 1000, send) end
	if numconns >= #conns then
		conns[1] = conns[1] + 1
		return
	end

	local ip = nf.ip(packet)
	local tcp = nf.tcp(ip)
	local dir = tcp.ack == 0 and 'o' or 'i'
	local dev, host, port = nf.mac(frame).src, ip.dst,
		tcp[dir == 'o' and 'dport' or 'sport']

	kf[1], kf[2], kf[3], kf[4] = dir, dev, host, port
	local key = table.concat(kf)
	local t = aggrs[key]
	if not t then
		numconns = numconns + 1
		t = conns[numconns]
		aggrs[key] = t
		local sec, msec = nf.time()
		t[1], t[2], t[3], t[4] = dir, nf.tomac(dev), nf.toip(host), port
		t[5], t[6], t[7]       = nf.toip(ip.src), sec * 1000 + msec, 0
	end
	t[7] = t[7] + 1
end
