--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

local function get_headers(req)
	local headers = {}

	-- name: [value] CRLF
	for name, value in string.gmatch(req, '([%w-_]+):%s*([^%c]*)%c+') do
		headers[name] = value
	end

	return headers
end

local function compose_sig(version, headers)
	local user_agent = headers['User-Agent']
	return user_agent and p0f_httpsig(version, user_agent) or nil
end

function nf_httpcap(frame, packet)
	local mac = nf.mac(frame)
	local ip = nf.ip(packet)

	if mac.src ~= 0 then
		local tcp, payload = nf.tcp(ip)

		if payload then
			local request = tostring(payload)

			-- Method SP Uri SP HTTP-1.x [headers] CRLF [body]
			local method, version, hdrs = string.match(request,
				'([A-Z]+).*HTTP/1%.(%d)%c+(.*)')

			if version and method == 'HEAD' or method == 'GET' then
				local sig = compose_sig(version, get_headers(hdrs))
				if sig then
					nf.sendsig('http', mac, ip, sig)
				end
			end
		end
	end

	return false -- ALLOW
end
