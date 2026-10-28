--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

local function capture(frame, packet, channel)
	local mac = nf.mac(frame)
	local ip = nf.ip(packet)
	local udp, payload = nf.udp(ip)

	local srcmac = nf.tomac(mac.src)
	local dstmac = nf.tomac(mac.dst)

	if srcmac == dstmac then
		debug("nflua: 'capture' found same srcmac %s and dstmac %s for '%s'", srcmac, dstmac, channel)
		return false
	end

	local ok, err = nf.send(channel, {
		source = {
			port = udp.sport,
			mac = srcmac,
			ip = nf.toip(ip.src),
		},
		destination = {
			port = udp.dport,
			mac = dstmac,
			ip = nf.toip(ip.dst),
		},
		payload = base64.encode(tostring(payload)),
	})
	if not ok then
		debug("nflua: 'capture' failed to send netlink msg '%s': %s", channel, err)
	end
	return false
end

for name, proto in pairs{nf_dhcp = 'dhcp', nf_dns = 'dns', nf_mdns = 'mdns'} do
	_G[name] = function (frame, packet) return capture(frame, packet, proto) end
end
