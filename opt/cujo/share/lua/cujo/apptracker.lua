--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo, globals cujo.apptracker

-- This module implements the "apptracker" feature. It does a lot of things:
--
-- * Each TCP/UDP connection is inspected for "application data". See
--   [hasappdata] for what counts. This is provided from the kernel side via
--   "apptracker" messages [apptrackerevent]. Mappings between MACs and IPs are
--   also saved here.
--
-- * Each TCP SYN packet captured by the "synlistener" (see tcptracker.lua) is
--   also used to track MAC-IP mappings [tcptrackerevent].
--
-- * Each DNS response is used to keep a cache of DNS entries [dnsevent].
--
-- * The kernel's conntrack table is constantly polled, to have an up-to-date
--   view of all connections, or "flows" [trafficpoll]. The main information of
--   interest is the source and destination as well as the amount of traffic
--   (bytes and packets) that has flowed in both directions.
--
-- * Flows are initially created in the "pending" LRU. When their MAC address
--   information is populated, they may be moved to the "flows" LRU. This will
--   happen if they have application data, or if it's been a while and it's
--   assumed that application data will not arrive. "Been a while" is controlled
--   by the "waiting" state, which is set when a flow has had a MAC address but
--   no application data on two consecutive iterations of conntrack polling.
--   [updatepending]
--
-- * Flows in "flows" that have had a non-zero amount of packet traffic since
--   the last poll of the conntrack table, or have zero traffic but new appdata,
--   are sent to the Agent Service.
--
-- In addition, the conntrack reading is rate-limited to avoid overwhelming
-- routers with weak CPUs.

local tabop = require 'loop.table'
local time = require 'coutil.time'

local log = require 'cujo.log'
local lru = require 'nf.lru'
local luamnl = require 'cujo.luamnl'
local mnl = require 'cujo.mnl'
local shims = require 'cujo.shims'
local util = require 'cujo.util'

-- Matches IPPROTO_TCP and IPPROTO_UDP in Linux.
local trackedprotos = {
    [6] = 'tcp',
    [17] = 'udp',
}
local activemac = {}
local maxflows
local maxpending
local linespersecond
local interval
local flows
local pending
local macips
local dnscache

local trafficpoll_iteration = 0

local pending_overflows = 0
local flows_overflows = 0
local macs_overflows = 0

local function pendingoverflow()
    pending_overflows = pending_overflows + 1
end

local function flowsoverflow()
    flows_overflows = flows_overflows + 1
end

local function print_queue_state(name, time_stamp, size)
    cujo.log:warn('#### ',name,' time : ',time_stamp,' size : ',size)
end

-- On overflow, undo the setting of cujo.apptracker.traffic[v][mac][ip] that took place in
-- setmaccache. Instead of making both cujo.apptracker.traffic[v] tables LRUs, we have this
-- one LRU that treats them as a single LRU as a whole.
--
-- But note that the end result is not LRU behaviour on cujo.apptracker.traffic[v]. When
-- the setting in setmaccache fails, the least recently used element in macips
-- is evicted. However, the evicted element is not the same one that was just
-- set, which is the one that gets passed to the overflow callback.
--
-- This means that on overflow, the cujo.apptracker.traffic tables diverge from macips.
local function macipsoverflow(ip, mac)
    macs_overflows = macs_overflows + 1

    local v = cujo.util.addrtype(ip)
    local traffic = cujo.apptracker.traffic[v]
    local mac_traffic = traffic[mac]
    mac_traffic[ip] = nil
    if next(mac_traffic) == nil then traffic[mac] = nil end
end
local function setmaccache(mac, ip)
    local v = cujo.util.addrtype(ip)
    cujo.apptracker.traffic[v][mac][ip] = true
    macips[ip] = mac
end

local function createtables()
    flows = lru.new(maxflows, nil, flowsoverflow, print_queue_state, 'flows')
    pending = lru.new(maxpending, nil, pendingoverflow, print_queue_state, 'pending')
    macips = lru.new(cujo.config.apptracker.maccachesize, nil, macipsoverflow, print_queue_state, 'macips')
    dnscache = lru.new(cujo.config.apptracker.dnscachesize, nil, nil, print_queue_state, 'dnscache')
end

-- Unique identifier for a flow. Note that the destination port is not used:
-- This is because we only look at one port per protocol, so the rest of the
-- information is sufficiently unique.
local function flowkey_raw(srcip, srcport, dstip, protonum)
    return srcip .. ':' ..
           srcport .. ',' ..
           dstip .. ',' ..
           protonum
end
local function flowkey(flow)
    return flowkey_raw(flow.srcip, flow.srcport, flow.dstip, flow.protonum)
end

local function normalizeip(ip)
    if cujo.util.addrtype(ip) == 'ip6' then
        ip = string.format('%x:%x:%x:%x:%x:%x:%x:%x',
            string.unpack('>I2I2I2I2I2I2I2I2', cujo.net.iptobin('ipv6', ip)))
    end
    return ip
end

-- [hasappdata]
local function hasappdata(flow)
    return flow.host or flow.target or flow['user-agent'] or flow.sni or flow.gquicua
end

-- [updatepending]
local function updatepending()
    local tracked = 0
    local waiting = 0
    local ignored = 0
    for k, f in pairs(pending) do
        -- If the conntrack read we just did is where we first saw this
        -- flow, check whether the MAC was also activated recently. If
        -- the flow was first seen within one conntrack read from when
        -- the MAC was activated, then we don't know whether this
        -- connection was there before the activation or not. In that
        -- case we also don't know whether the sizes and packet counts
        -- are correct or not, so we have to keep it as pending.
        --
        -- Regarding the relationships between FSA (f.first_seen_at) and
        -- MAA (mac_activated_at):
        --
        -- * FSA < MAA should never happen.
        --
        -- * FSA == MAA + 1 is the typical case for a newly activated
        --   MAC: The flows for the MAC are seen on the next conntrack
        --   read after the activation.
        --
        -- * FSA == MAA is possible if the MAC was activated in the
        --   midst of us reading conntrack.
        --
        -- * FSA > MAA + 1 is normal for new connections.
        --
        -- Since FSA < MAA should be impossible, we use FSA <= MAA + 1
        -- as an abbreviation for (FSA == MAA or FSA == MAA + 1).
        local flow_is_new = f.first_seen_at == trafficpoll_iteration
        local flow_and_mac_are_new = false
        if flow_is_new then
            local mac_activated_at = activemac[f.srcmac or f.dstmac]
            flow_and_mac_are_new = f.first_seen_at <= mac_activated_at + 1
        end

        if flow_and_mac_are_new then
            ignored = ignored + 1
        else
            if (hasappdata(f) and (f.srcname or f.dstname)) or f.waiting then
                flows:set(k, f)
                pending:remove(k)
                f.waiting = nil
                tracked = tracked + 1
            else
                f.waiting = true
                waiting = waiting + 1
            end
            cujo.log:apptracker(f.waiting and 'Waiting ' or 'Tracking ', f.srcip,
                ':', f.srcport, ' -> ', f.dstip, ':', f.dstport, ' ',
                f.proto)
        end
    end

    if tracked ~= 0 or waiting ~= 0 or ignored ~= 0 then
        cujo.log:apptracker('updatepending: ',
            tracked, ' moved to flows, ',
            waiting, ' set waiting, ',
            ignored, ' ignored for newly activated MACs')
    end
    if flows_overflows ~= 0 then
        cujo.log:warn('updatepending caused ', flows_overflows, ' overflows to the flows queue')
        flows_overflows = 0
    end
end


local function incorporate_fastpath_data(entries)
    if cujo.config.apptracker.get_fastpath_bytes == nil or #entries == 0 then
        return
    end
    local t0 = shims.gettime()
    local fast = cujo.config.apptracker.get_fastpath_bytes(entries)
    for _, f in ipairs(fast) do
        local key, ipackets, ibytes, opackets, obytes = table.unpack(f)
        local entry = entries[key]
        entry.isize = entry.isize + ibytes
        entry.osize = entry.osize + obytes
        entry.ipackets = entry.ipackets + ipackets
        entry.opackets = entry.opackets + opackets
    end
    if cujo.log:flag('apptracker') then
        local t1 = shims.gettime()
        cujo.log:apptracker(
            'incorporate_fastpath_data got ',
            #fast, ' responses for ', #entries, ' flows in ',
            (t1 - t0) * 1000, ' ms')
    end
end

local function updateaccumulators()
    for _, f in pairs(flows) do
        f.osizeacc = f.osizeacc + f.osize
        f.isizeacc = f.isizeacc + f.isize
        f.opacketsacc = f.opacketsacc + f.opackets
        f.ipacketsacc = f.ipacketsacc + f.ipackets
    end
end

function log.custom:tune(start, lines)
    local elapsed = shims.gettime() - start
    local message = string.format(
        'Processed %d lines in %5.4f seconds (%5.4f lines per second)',
        lines, elapsed, lines / elapsed)
    self.viewer.output:write(message)
end

local batch = {}
local batchlen = 0
local function ctcb_bylines(ev, id, l3proto,
        ol4protonum, osrcport, odstport, osrcip, odstip, opkts, obytes, -- orig
        rl4protonum, rsrcport, rdstport, rsrcip, rdstip, rpkts, rbytes) -- reply

    if not l3proto then return end

    local protonum = tonumber(ol4protonum)
    local proto = trackedprotos[protonum]
    if not proto then return end

    local srcip = normalizeip(mnl.bintoip(l3proto, osrcip))
    local dstip = normalizeip(mnl.bintoip(l3proto, rsrcip))

    if not (activemac[macips[srcip]] or activemac[macips[dstip]]) then return end

    local srcport = tonumber(osrcport)
    local dstport = tonumber(rsrcport)
    local x
    if batchlen < #batch then
        x = batch[batchlen + 1]
    else
        x = {}
        table.insert(batch, x)
    end
    batchlen = batchlen + 1
    x.proto = proto
    x.protonum = protonum
    x.srcip = srcip
    x.dstip = dstip
    x.srcport = srcport
    x.dstport = dstport
    x.osize = obytes or 0
    x.isize = rbytes or 0
    x.opackets = opkts or 0
    x.ipackets = rpkts or 0
end

local granularity
local oldtime, readlines
local totallines
local function ctcb_bybatch()
    local created = 0
    for i = 1, batchlen do
        local found = batch[i]
        local key = flowkey(found)
        local flow = flows[key] or pending[key]
        if not flow then
            created = created + 1
            local srcip = found.srcip
            local dstip = found.dstip
            flow = {
                proto = found.proto,
                protonum = found.protonum,
                srcip = srcip,
                dstip = dstip,
                srcport = found.srcport,
                -- Don't init dstport, it's handled separately
                -- below.
                srcmac = macips[srcip],
                dstmac = macips[dstip],
                osize = 0,
                isize = 0,
                opackets = 0,
                ipackets = 0,

                -- conntrack reports the amount of bytes and
                -- packets over the full lifetime of a
                -- connection, but we want to know the amount
                -- between polls, so keep track of accumulators.
                osizeacc = 0,
                isizeacc = 0,
                opacketsacc = 0,
                ipacketsacc = 0,
            }
        end
        if flow.first_seen_at == nil then
            flow.first_seen_at = trafficpoll_iteration
        end
        flow.srcname = flow.srcname or dnscache[flow.srcip]
        flow.dstname = flow.dstname or dnscache[flow.dstip]
        flow.osize = found.osize - flow.osizeacc
        flow.isize = found.isize - flow.isizeacc
        flow.opackets = found.opackets - flow.opacketsacc
        flow.ipackets = found.ipackets - flow.ipacketsacc
        if flow.opackets > 0 then
            flow.osend_at = trafficpoll_iteration
        end
        if flow.ipackets > 0 then
            flow.isend_at = trafficpoll_iteration
        end
        flow.updated = true
        if not flows[key] then
            -- If it was created by apptrackerevent, it doesn't have
            -- a dstport yet, so set it here.
            flow.dstport = found.dstport

            pending:set(key, flow)
        end
        readlines = readlines + 1
        totallines = totallines + 1
    end
    batchlen = 0

    if created ~= 0 then
        cujo.log:apptracker('ctcb_bybatch created ', created, ' pending flows')
    end

    -- check the number of pending overflows and log
    -- we don't need to check flow_overflows since that's not updated
    -- in this loop
    if pending_overflows ~= 0 then
        cujo.log:warn('ctcb_bybatch caused ', pending_overflows, ' overflows to the pending queue')
        pending_overflows = 0
    end

    if readlines >= granularity then
        local delay_until = oldtime + (readlines / linespersecond)
        readlines = 0
        oldtime = shims.gettime()
        return delay_until
    end
end

local conntrackevents = nil
local function readconntrack(callback)
    if #flows ~= 0 or #pending ~= 0 then
        cujo.log:apptracker(#flows, ' flows tracked and ', #pending, ' flows pending')
    end

    totallines = 0
    readlines = 0
    oldtime = shims.gettime()
    return conntrackevents:readall(function()
        -- Remove flows that we didn't come across in conntrack.
        local removedflows = 0
        local removedpending = 0
        for k, f in pairs(flows) do
            if not f.updated then
                flows:remove(k)
                removedflows = removedflows + 1
            else
                f.updated = false
            end
        end
        for k, f in pairs(pending) do
            if not f.updated and not f.waiting then
                pending:remove(k)
                removedpending = removedpending + 1
            else
                f.updated = false
            end
        end

        if removedflows ~= 0 or removedpending ~= 0 then
            cujo.log:apptracker('readconntrack removed ', removedflows,
                ' tracked flows and ', removedpending,
                ' pending flows')
        end

        return callback()
    end)
end

-- [tcptrackerevent]
local function tcptrackerevent(message)
    for i = 2, #message do
        local msg = message[i]
        local mac, srcip = msg[2], msg[5]
        setmaccache(mac, srcip)
    end
    if macs_overflows ~= 0 then
        cujo.log:warn('tcptrackerevent caused ', macs_overflows, ' overflows to the MAC cache')
        macs_overflows = 0
    end
end

-- [apptrackerevent]
local function apptrackerevent(data)
    -- Can happen when Rabid is restarted and there's data from the previous
    -- instance coming in.
    if not flows then return end

    local message_count, data_idx = string.unpack("I4", data)
    cujo.log:apptracker('processing ', message_count, ' apptracker events from kernel')

    local created = 0
    local updatedflows = 0
    local updatedpending = 0
    for msg_idx = 1, message_count do
        local ip_version, i = string.unpack("I1", data, data_idx)
        local srcip, dstip
        if ip_version == 4 then
            srcip = cujo.net.bintoip("ipv4", string.sub(data, i, i + 3))
            i = i + 4
            dstip = cujo.net.bintoip("ipv4", string.sub(data, i, i + 3))
            i = i + 4
        else
            srcip = normalizeip(cujo.net.bintoip("ipv6", string.sub(data, i, i + 15)))
            i = i + 16
            dstip = normalizeip(cujo.net.bintoip("ipv6", string.sub(data, i, i + 15)))
            i = i + 16
        end

        local protonum, srcport, mac, host, target, user_agent, sni, gquicua, j =
            string.unpack("I1I2I6sssss", data, i)
        data_idx = j

        mac = util.bintomac(mac)

        cujo.log:apptracker(
            msg_idx, ': proto=' , protonum,
            ' src=' , srcip, ':' , srcport, ' dst=', dstip, ' mac=' , mac,
            ' host=', host, ' target=' , target, ' ua=' , user_agent,
            ' sni=' , sni,
            ' gquicua=' , gquicua,
            ' i=' , data_idx)

        setmaccache(mac, srcip)
        local key = flowkey_raw(srcip, srcport, dstip, protonum)
        local flow = flows[key]
        if flow then
            updatedflows = updatedflows + 1
        else
            flow = pending[key]
            if flow then
                updatedpending = updatedpending + 1
            else
                flow = {
                    proto = trackedprotos[protonum],
                    protonum = protonum,
                    srcip = srcip,
                    dstip = dstip,
                    srcport = srcport,
                    srcmac = mac,
                    osizeacc = 0,
                    isizeacc = 0,
                    opacketsacc = 0,
                    ipacketsacc = 0,
                    osize = 0,
                    isize = 0,
                    opackets = 0,
                    ipackets = 0,
                }
                created = created + 1
            end
        end
        if host ~= '' then flow.host = host end
        if target ~= '' then flow.target = target end
        if user_agent ~= '' then flow['user-agent'] = user_agent end
        if sni ~= '' then flow.sni = sni end
        if gquicua ~= '' then flow.gquicua = gquicua end
        flow.updated = true

        -- Assume that some new data was added i.e. at least one of the appdata
        -- fields was non-empty, and that we don't receive the same appdata
        -- twice for any flow.
        flow.isend_at = trafficpoll_iteration
        flow.osend_at = trafficpoll_iteration

        if flows[key] then
            flows:set(key, flow)
        else
            pending:set(key, flow)
        end
    end
    if created ~= 0 or updatedflows ~= 0 or updatedpending ~= 0 then
        cujo.log:apptracker('apptrackerevent created ', created,
            ' pending flows, updated ', updatedflows,
            ' tracked flows and ', updatedpending, ' pending flows')
    end
    if pending_overflows ~= 0 then
        cujo.log:warn('apptrackerevent caused ', pending_overflows, ' overflows to the pending queue')
        pending_overflows = 0
    end
    if flows_overflows ~= 0 then
        cujo.log:warn('apptrackerevent caused ', flows_overflows, ' overflows to the flows queue')
        flows_overflows = 0
    end
    if macs_overflows ~= 0 then
        cujo.log:warn('apptrackerevent caused ', macs_overflows, ' overflows to the MAC cache')
        macs_overflows = 0
    end
end

-- [dnsevent]
local function dnsevent(message)
    -- Can happen when Rabid is restarted and there's data from the previous
    -- instance coming in.
    if not dnscache then return end

    local domain, hosts = message.domain, message.hosts
    for _, h in ipairs(hosts) do
        dnscache[h] = domain
    end
end

-- Forward-declare to make reading from trafficpoll_start a bit easier.
local trafficpoll_repeatedly

-- [trafficpoll]
local pollactive = false
local function trafficpoll_start()
    conntrackevents = luamnl.create{
        bus = 'netfilter',
        bylines = ctcb_bylines,
        bybatch = ctcb_bybatch,
        groups = 'd',
    }
    createtables()

    cujo.nf.subscribe('tcptracker', tcptrackerevent)
    cujo.nf.subscribe('apptracker', apptrackerevent)
    cujo.nf.subscribe('dnscache', dnsevent)

    -- 0 is used as a sentinel "before all possible real values" value, so
    -- initialize to 1 instead.
    trafficpoll_iteration = 1

    return trafficpoll_repeatedly(os.time(), function()
        conntrackevents:close()

        -- Required not only for our own book-keeping but also to make
        -- sure that the GC will close the underlying socket.
        conntrackevents = nil

        cujo.nf.unsubscribe('dnscache', dnsevent)
        cujo.nf.unsubscribe('apptracker', apptrackerevent)
        cujo.nf.unsubscribe('tcptracker', tcptrackerevent)
    end)
end

function trafficpoll_repeatedly(startsec, on_done)
    if not cujo.apptracker.enable.wanted then
        return on_done()
    end

    local oldtime = shims.gettime()

    return readconntrack(function()
        updatepending()
        incorporate_fastpath_data(flows)
        updateaccumulators()
        local endsec = os.time()
        local pack = {
            flows = flows,
            startsec = startsec,
            startmsec = 0,
            endsec = endsec,
            endmsec = 0,
        }
        cujo.apptracker.flows(pack, trafficpoll_iteration)
        cujo.log:tune(oldtime, totallines)

        -- Increment before going to sleep, so that any apptrackerevents
        -- received during the sleep use the new iteration value.
        trafficpoll_iteration = trafficpoll_iteration + 1

        time.waituntil(oldtime + cujo.config.apptracker.timeout)
        return trafficpoll_repeatedly(endsec, on_done)
    end)
end

local module = {
    conns = util.createpublisher(),
    flows = util.createpublisher(),
    traffic = {},
    enable = util.createenabler('apptracker', function (_, enable, callback)
        if enable then
            if not pollactive then
                pollactive = true

                -- Treat all MACs as having just been activated. We could do
                -- better by comparing to the old trafficpoll_iteration but in
                -- most cases this is equivalent anyway.
                for mac, _ in pairs(activemac) do
                    activemac[mac] = 0
                end

                trafficpoll_start()
            end
            cujo.tcptracker.synlistener.enable(function()
                cujo.nfrules.set('apptracker', function()
                    cujo.nfrules.check('apptracker', callback)
                end)
            end)
        else
            pollactive = false
            cujo.tcptracker.synlistener.disable(function()
                cujo.nfrules.clear('apptracker', function()
                    cujo.nfrules.check_absent('apptracker', callback)
                end)
            end)
        end
    end),
}

function module.enablemac(mac)
    if not activemac[mac] then
        activemac[mac] = trafficpoll_iteration
    end
    cujo.nf.enablemac('activemac', mac, true)
    if cujo.config.apptracker.activemac_callback then
        cujo.config.apptracker.activemac_callback(activemac)
    end
end

function module.disablemac(mac)
    activemac[mac] = nil
    cujo.nf.enablemac('activemac', mac, false)
    if cujo.config.apptracker.activemac_callback then
        cujo.config.apptracker.activemac_callback(activemac)
    end
end

function module.enable_queues_debug()
    flows:enable_debug()
    pending:enable_debug()
    macips:enable_debug()
    dnscache:enable_debug()
end

function module.disable_queues_debug()
    flows:disable_debug()
    pending:disable_debug()
    macips:disable_debug()
    dnscache:disable_debug()
end

function module.initialize()
    maxflows = cujo.config.apptracker.maxflows
    maxpending = cujo.config.apptracker.maxpending
    linespersecond = cujo.config.apptracker.linespersecond
    interval = cujo.config.apptracker.interval

    granularity = linespersecond * interval

    -- Creates cujo.apptracker.traffic.ip4 and/or
    -- cujo.apptracker.traffic.ip6, which are used to track ongoing
    -- connections that may need to be killed in appblock or iotblock. Both
    -- are mappings from MAC addresses to sets of IP addresses.
    for net in pairs(cujo.config.nets) do
        module.traffic[net] = tabop.memoize(function() return {} end)
    end
end

return module
