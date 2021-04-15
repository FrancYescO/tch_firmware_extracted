--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

conn = {}

local conns = lru.new(config.conn.maxentries)
local pending = setmetatable({}, {__mode = 'v'})

function conn.setstate(id, state)
	if state == 'allow' then
		conns[id] = nil
	else
		local entry = conns[id]
		entry._state = state
		return entry
	end
end

function conn.getstate(id)
	local entry = conns[id]
	return entry and entry._state or 'allow', entry
end

local function flush(connid)
	local state, entry = conn.getstate(connid)
	if state ~= 'pending' then return end

	timer.destroy(entry.timer)

	local found, reason =
		safebro.filter(entry.mac, entry.ip, entry.domain, entry.path)

	if reason then
		if entry.blockpage then
			local reply = entry.blockpage(reason)
			if #entry.packets == 0 then
				entry.reply = reply
				conn.setstate(connid, 'blockpage')
			else
				entry.packets[1]:send(reply)
				conn.setstate(connid, 'block')
			end
		end
	else
		if not found then
			-- Technically this can also happen if the cache in
			-- threat.lua is being written to so quickly that the
			-- result drops out of the cache before
			-- conn.cacheupdated finishes flushing all the
			-- connections, but that seems unlikely.
			if debug_logging then
				nf.log('safebro lookup timed out on "', entry.domain, '"')
			else
				nf.log('safebro lookup timed out on "', entry.domain:sub(0, 5), '..."')
			end
		end

		for _, packet in ipairs(entry.packets) do
			packet:send()
		end
		conn.setstate(connid, 'allow')
	end
end

function conn.filter(mac, ip, domain, path, blockpage)
	local connid = nf.connid()
	local found, reason = safebro.filter(mac, ip, domain, path)
	if reason then
		if blockpage then pcall(nf.reply, 'tcp', blockpage(reason)) end
		conn.setstate(connid, 'block')
	elseif not found then
		local pendingref = pending[domain] or {}
		pending[domain] = pendingref
		table.insert(pendingref, connid)
		local entry = conn.setstate(connid, 'pending')
		entry.mac = mac
		entry.ip = ip
		entry.domain = domain
		entry.path = path
		entry.blockpage = blockpage
		entry.pendingref = pendingref
		entry.packets = {}
		entry.timer = timer.create(sbconfig.timeout, function() flush(connid) end)
	else
		conn.setstate(connid, 'allow')
	end
end

function conn.cacheupdated(domain)
	local connids = pending[domain]
	if connids then
		for _, connid in ipairs(connids) do
			flush(connid)
		end
	end
end

function nf_conn_new(frame)
	local mac = nf.mac(frame)
	local connid = nf.connid()
	if (safebro.status.trackerblock.enabled and not safebro.trackersallowed(mac.src))
		or not threat.bypass[mac.src] then
		conns[connid] = {_state = 'init'}
	else
		conns[connid] = nil
	end
end

function nf_reset_response(frame, packet)
	local connid = nf.connid()
	local state, data = conn.getstate(connid)
	if state == 'init' or state == 'allow' then return false end

	if state == 'blockpage' then
		nf.getpacket():send(data.reply)
		conn.setstate(connid, 'block')
	elseif state == 'pending' then
		if #data.packets < 2 then
			table.insert(data.packets, nf.getpacket())
		end
	elseif state == 'block' then
		return true
	end

	nf.hotdrop(true)
end
