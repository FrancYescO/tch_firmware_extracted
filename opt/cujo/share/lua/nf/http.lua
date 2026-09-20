--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

-- HTTP support for safebro. Much of this is a tailor-made HTTP parser,
-- implemented as a state machine that supports getting the data we need even
-- when it's arbitrarily fragmented between the packets we come across.

local maxsize = {
    method = 7,
    target = 512,
    version = 8,
    hdrname = 0, -- calculated below
    hdrval = 512,
}

local salts = lru.new(config.http.maxentries, config.http.ttl)

local stages = {}

local function consume(name, pattern, once, nextstage, field)
    local stage
    if type(nextstage) == 'string' then stage = nextstage end
    stages[name] = function (self, value, pos, previous)
        local _, last = string.find(value, pattern, pos)
        if last ~= nil then
            if field ~= nil then
                local length = 1 + last - pos
                local current = self[field] or ''
                local left = maxsize[field] - #current
                local last = (length > left) and (pos + left - 1) or last
                self[field] = current .. string.sub(value, pos, last)
            end
            pos = last + 1
            return pos, (once or pos < #value) and (stage or nextstage(self)) or name
        end
        if previous ~= name then return #value + 1, 'invalid' .. name end
        return pos, stage or nextstage(self)
    end
end

local function choice(name, pattern, truestage, falsestage)
    stages[name] = function (self, value, pos, previous)
        local _, last = string.find(value, pattern, pos)
        if last ~= nil then
            return last + 1, truestage
        end
        return pos, falsestage
    end
end

local headers = {
    host = true,
    referer = true,
    ['user-agent'] = true,
}

for name in pairs(headers) do
    maxsize.hdrname = math.max(maxsize.hdrname, #name)
end

local function checkheader(self)
    if self.hdrname == nil then return 'invalidhdrnameval' end
    local header = string.lower(self.hdrname)
    if headers[header] then
        self.hdrname = header
        return 'hdrvalval'
    end
    self.hdrname = nil
    return 'hdrskipval'
end

local function saveheader(self)
    self[self.hdrname] = string.match(self.hdrval, '^%s*(.-)%s*$')
    self.hdrname = nil
    self.hdrval = nil
    return 'bodystartCR'
end

consume('methodval'   , '^%u+'                 , false, 'methodsep', 'method')
consume('methodsep'   , '^ '                   , true , 'targetval')
consume('targetval'   , '^%S+'                 , false, 'targetsep', 'target')
consume('targetsep'   , '^ '                   , true , 'versionval')
consume('versionval'  , '^[^\r]+'              , false, 'versionCR')
consume('versionCR'   , '^\r'                  , true , 'versionLN')
consume('versionLN'   , '^\n'                  , true , 'bodystartCR')
choice ('bodystartCR' , '^\r'                  , 'bodystartLN', 'hdrnameval')
consume('bodystartLN' , '^\n'                  , true, 'done')
consume('hdrnameval'  , "^[!#$%&'*+-.^_`|~%w]+", false, 'hdrnamesep', 'hdrname')
consume('hdrnamesep'  , "^:"                   , true , checkheader)
consume('hdrvalval'   , "^[^\r]+"              , false, 'hdrvalsepCR', 'hdrval')
consume('hdrvalsepCR' , "^\r"                  , true , 'hdrvalsepLN')
consume('hdrvalsepLN' , "^\n"                  , true , saveheader)
consume('hdrskipval'  , "^[^\r]+"              , false, 'hdrskipsepCR')
consume('hdrskipsepCR', "^\r"                  , true , 'hdrskipsepLN')
consume('hdrskipsepLN', "^\n"                  , true , 'bodystartCR')

http = {}

-- Entry point into the HTTP header parser. Keeps track of the parser state
-- inside the provided connection entry.
function http.headerinfo(entry, stream)
    local pos = 1
    local stage, previous = entry.stage or 'methodval', entry.previous
    while pos <= #stream and stage ~= 'done' do
        previous, pos, stage = stage, stages[stage](entry, stream, pos, previous)
    end
    entry.stage, entry.previous = stage, previous
    return stages[stage] ~= nil and 'notdone' or
        (stage == 'done' and 'done' or 'error')
end

-- Handle requests in which the user has chosen to ignore the safebro warning
-- page. We rely on the HTTP referer for this.
local function unblock(mac, host, entry)
    local referer = entry.referer
    if referer and sbconfig.warnpage_pattern then
        local rhost, salt = string.match(referer, sbconfig.warnpage_pattern)
        if rhost == host and salts[mac .. rhost] == tonumber(salt, 16) then
            threat.addwhitelist(mac, host)
            salts[mac .. host] = nil
            return true
        end
    end
end

local blockredirect = 'HTTP/1.1 302 Found\r\n' ..
    'Location: %s?url=http://%s\r\n' ..
    'Connection: close\r\n' ..
    'Content-Length: 0\r\n\r\n'

local blocktracker = 'HTTP/1.1 204 No Content\r\n' ..
    'Connection: close\r\n\r\n'

local warnredirect = string.format(blockredirect, '%s', '%s&token=%08x')

local function makeblockpage(uri, mac, host)
    return function (reason)
        if reason == safebro.reasons.tracker then
            return blocktracker
        elseif reason == safebro.reasons.parental then
            return string.format(blockredirect, sbconfig.blockpage, uri)
        else
            local salt = math.random()
            salts[mac .. host] = salt
            return string.format(warnredirect, sbconfig.warnpage, uri, salt)
        end
    end
end

function nf_http(frame, packet)
    local id = nf.connid()
    local state, entry = conn.getstate(id)
    if state ~= 'init' then return end

    local ip = nf.ip(packet)
    local tcp, payload = nf.tcp(ip)

    local status = http.headerinfo(entry, tostring(payload))
    if status ~= 'done' then
        if status ~= 'notdone' then conn.setstate(id, 'allow') end
        return
    end
    local host = entry.host

    local mac = nf.mac(frame).src
    if not host or threat.iswhitelisted(mac, host) or
        unblock(mac, host, entry) then
        conn.setstate(id, 'allow')
    else
        local uri = host .. entry.target
        local blockpage = sbconfig.blockpage and makeblockpage(uri, mac, host)
        conn.filter(mac, ip.src, host, entry.target, blockpage)
    end
end
