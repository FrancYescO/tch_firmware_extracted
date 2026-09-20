--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

-- Standard luacheck globals stanza based on what NFLua preloads and
-- the order in which cujo.nf loads these scripts.
--
-- luacheck: read globals config data
-- luacheck: read globals base64 json timer
-- luacheck: read globals debug debug_logging
-- luacheck: read globals lru
-- luacheck: read globals nf
-- luacheck: read globals threat
-- luacheck: globals conn
-- luacheck: read globals safebro sbconfig
-- luacheck: read globals ssl
-- luacheck: read globals http
-- (caps exports no globals)
-- (tcptracker exports no globals)
-- (apptracker exports no globals)
-- luacheck: read globals p0f_httpsig p0f_tcpsig
-- (httpcap exports no globals)
-- (tcpcap exports no globals)
-- luacheck: read globals appblocker
-- luacheck: read globals gquic
-- luacheck: read globals dns
-- (ssdpcap exports no globals)

conn = {}

-- Connections that are processed by safe browsing. This is keyed by nf.connid()
-- and in practice only accessed from conn.getstate.
--
-- Each entry has various fields that are set and used varyingly from (at least)
-- here, http.lua and ssl.lua.
--
-- One important one is "_state", which is used mainly by conn.setstate and
-- conn.getstate. It has five possible values:
-- * "init": Set for new connections. Normally an HTTP(S) request should come
--           through after this, leading to the other states.
-- * "allow": Traffic is allowed to flow in both directions.
-- * "block": The blockpage has been sent and traffic is not allowed to flow.
-- * "blockpage": We're waiting for a response from the malicious upstream so
--                that we can send a blockpage.
-- * "pending": We're waiting for information from userspace to determine
--              whether to block or allow the traffic.
local conns = lru.new(config.conn.maxentries)

-- Mapping from domains to lists of connections for each domain.
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

-- Finalize our decision on what to do with the connection, setting its state as
-- appropriate based on the decision from safebro.filter.
--
-- Also, if there are any packets from the real upstream buffered, this sends
-- out the response, whether that's a block page or the original packets.
local function flush(connid)
    local state, entry = conn.getstate(connid)
    if state ~= 'pending' then return end

    timer.destroy(entry.timer)

    local action, reason =
        safebro.filter(entry.mac, entry.ip, entry.domain, entry.path)

    if action == 'block' then
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
        if action == 'miss' then
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

-- Called when a connection is eligible for blocking by safebro. We don't yet
-- know whether it should be blocked or allowed, but we have a domain to look up
-- and we know it's not whitelisted.
function conn.filter(mac, ip, domain, path, blockpage)
    local connid = nf.connid()
    local action, reason = safebro.filter(mac, ip, domain, path)
    if action == 'block' then
        if blockpage then pcall(nf.reply, 'tcp', blockpage(reason)) end
        conn.setstate(connid, 'block')
    elseif action == 'miss' then
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

-- Called when we expect safebro.filter to be able to produce a result for the
-- given domain immediately.
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

-- Called on packets being forwarded from the WAN to the LAN.
--
-- Returns true if the packet should be rejected.
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

    -- Either already used to send a block page ("blockpage") or we buffered
    -- it ("pending"), so tell netfilter to drop it.
    nf.hotdrop(true)
end
