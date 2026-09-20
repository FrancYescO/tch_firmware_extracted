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
-- luacheck: read globals conn
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
-- luacheck: globals gquic
-- luacheck: read globals dns
-- (ssdpcap exports no globals)

-- Overview: nf_lua match extension for hostname and user-agent extraction

gquic = {}

local function strtonum(tag)
    local num = 0
    for i = 1, tag:len() do num = (num << 8) + tag:byte(i) end
    return num
end

local checkversion do
    local Q, ZR = strtonum'Q', strtonum'0'
    local function todigit(val)
        val = (val & 0xFF) - ZR
        return val >= 0 and val <= 9 and val
    end
    function checkversion(ver, min, max)
        if ver >> 16 ~= (Q << 8) + ZR then return end
        local a, b = todigit(ver), todigit(ver >> 8)
        if not a or not b then return end
        ver = a + b * 10
        return ver >= min and ver <= max
    end
end

local parsepayload do
    -- https://docs.google.com/document/d/1WJvyZflAO2pq77yOLbp9NsGjC1CHetAXV8I0fQe-B_U/edit#heading=h.1gb5jlp7hwtd
    local frame, fsz = {
        str = {0, 1}, -- stream frame
        fin = {1, 1},
        dsz = {2, 1}, -- data length
        osz = {3, 3}, -- offset length
        ssz = {6, 2}, -- stream id length

        id  = {8, 8}, -- stream id, assuming 1 byte length
    }, 1 + 1 -- type, id
    -- https://docs.google.com/document/d/1g5nIXAIkN_Y-7XJW5K45IblHd_L2f5LTaDUDwvZ5L6g/edit#heading=h.zd5rmqegi5lw
    local msg, msz = {
        tag = {0, 32},
        len = {32, 16, 'number', 'little'},
    }, 4 + 2 + 2 -- tag, tnum, pad
    local tag, tsz = {
        type = {0, 32},
        off  = {32, 32, 'number', 'little'},
    }, 4 + 4 -- type, off
    local function optsz(sz) return sz == 0 and 0 or sz + 1 end
    local CHLO, SNI, UAID = strtonum'CHLO', strtonum'SNI\0', strtonum'UAID'
    function parsepayload(payload, offset)
        payload = payload:segment(12 + offset) -- skip authentication hash
        -- see `Initial Packet Null Encryption` at
        -- https://www.mobibrw.com/wp-content/uploads/2015/05/QUICWireLayoutSpecification.pdf
        if not payload or #payload < fsz then return end
        payload:layout(frame)
        if payload.str ~= 1 or payload.fin ~= 0 or payload.ssz ~= 0 then return end
        -- We assume ssz == 0: this is the smallest field size which can represent
        -- the id we are interested in, and quiche also follows this assumption
        -- See: https://quiche.googlesource.com/quiche/+/5843bfd652048b9961316a62dbf1cad68e7a55ac/quic/core/quic_framer.cc#4908
        --      https://quiche.googlesource.com/quiche/+/5843bfd652048b9961316a62dbf1cad68e7a55ac/quic/core/quic_framer.cc#694
        --      https://quiche.googlesource.com/quiche/+/5843bfd652048b9961316a62dbf1cad68e7a55ac/quic/core/quic_framer.cc#4869
        if payload.id ~= 1 then return end
        payload = payload:segment(fsz + optsz(payload.osz) + optsz(payload.dsz))
        if not payload or #payload < msz then return end
        payload:layout(msg)
        if payload.tag ~= CHLO then return end
        local msglen = payload.len
        local sdata = msz + msglen * tsz
        if #payload < sdata then return end
        local off, sni, ua = 0
        for i = 0, math.min(msglen, 16) - 1 do
            local type, next do
                local payload = payload:segment(msz + i * tsz, tsz)
                payload:layout(tag)
                type, next = payload.type, payload.off
            end
            if type == SNI or type == UAID then
                local val = payload:segment(sdata + off, next - off)
                if not val then return end
                val = tostring(val)
                if type == SNI then
                    sni = val
                else
                    ua = val
                end
                if sni and ua then break end
            end
            off = next
        end
        return sni, ua
    end
end

local parseQ043 do
    -- https://docs.google.com/document/d/1WJvyZflAO2pq77yOLbp9NsGjC1CHetAXV8I0fQe-B_U/edit#heading=h.qnqgv8t864a6
    local hdr, hminsz = data.layout{
        u = {0, 1}, -- unused
        p = {2, 2}, -- packet number length
        c = {4, 1}, -- connid present
        r = {6, 1}, -- reset
        v = {7, 1}, -- has version

        ver = {72, 32}, -- version
    }, 1 + 8 + 4 + 0 -- flag, cid, ver, pn (min size)
    function parseQ043(payload)
        if #payload < hminsz then return end
        payload:layout(hdr)
        if payload.u == 1 or payload.v == 0 or
           payload.r == 1 or payload.c == 0 then return end
        if not checkversion(payload.ver, 34, 43) then return end
        local p = payload.p
        return parsepayload(payload, hminsz + (p == 0 and 1 or p << 1))
    end
end

local parseQ046 do
    -- https://tools.ietf.org/html/draft-ietf-quic-transport-17#section-17.2
    local hdr, hminsz = data.layout{
        f = {0, 1}, -- header form
        t = {2, 2}, -- long packet type
        r = {4, 2}, -- reserved bits
        p = {6, 2}, -- packet number length

        ver  = {8, 32}, -- version
        dcil = {40, 4}, -- destination connid length
        scil = {44, 4}, -- source connid length
    }, 1 + 4 + 1 + 3 + 1 -- flag, ver, cil, dcid (min size), pnum (min size)
    function parseQ046(payload)
        if #payload < hminsz then return end
        payload:layout(hdr)
        if not checkversion(payload.ver, 44, 48) then return end
        if payload.f == 0 or payload.r ~= 0 or payload.t ~= 0 then return end
        local dcil = payload.dcil
        if dcil == 0 or payload.scil ~= 0 then return end
        return parsepayload(payload, hminsz + dcil + payload.p)
    end
end

local flags = data.layout{
    s = {1, 1}, -- reserved bit, was reserved for multipath until Q043
}
function gquic.parse(payload)
    if #payload < 1 then return end
    payload:layout(flags)
    if payload.s == 1 then
        return parseQ046(payload)
    else
        return parseQ043(payload)
    end
end
