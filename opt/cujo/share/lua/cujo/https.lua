--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo

local http = require'socket.http'
local ltn12 = require'ltn12'
local multipart = require'multipart-post'
local oo = require 'loop.base'
local socket = require'coutil.socket.ssl'
local tabop = require 'loop.table'
local url = require'socket.url'

-- These errors are overridden with the string "timeout".
--
-- It seems like coutil should be making sure that we never see "wantread" or
-- "wantwrite" anyway, but it's not entirely clear.
local ssltimeout = {
    wantread = true,
    wantwrite = true,
    timeout = true,
}

local function failsock(self, err)
    self.sock:close()
    self.sock = nil
    self.host = nil
    self.port = nil
    return nil, err
end

local function fixerr(res, err, ...)
    if not res then return nil, ssltimeout[err] and 'timeout' or err end
    return res, err, ...
end

local function doresults(self, res, err, ...)
    if not res then
        failsock(self)
    end
    return fixerr(res, err, ...)
end

-- Socket wrapper used for long-lived TLS connections like the urlchecker ones.
--
-- Also remembers its host and port, though those features seem to be unused.
local TlsSock = oo.class()

function TlsSock:connect(host, port)
    if not self.sock then return nil, 'closed' end
    if self.host == host and self.port == port then
        return true
    end
    assert(not self.host, 'already connected to different host')
    local res, err = self.sock:connect(host, port)
    if not res then return failsock(self, err) end
    self.host, self.port = host, port

    -- Avoid send() ever blocking due to the socket buffer being full.
    --
    -- That shouldn't happen anyway because coutil ensures that we only send
    -- when the fd is ready, but this is an additional safety measure.
    assert(self.sock:setoption('tcp-nodelay', true))

    assert(self.sock:setoption('keepalive' , true))
    local config = self.config
    if config then
        config.mode = 'client'
        self.sock, err = socket.ssl(self.sock, config)
        if not self.sock then return failsock(self, err) end
        self.sock:sni(host)
        return doresults(self, self.sock:dohandshake())
    end
end

function TlsSock:send(...)
    if not self.sock then return nil, 'closed' end
    return doresults(self, self.sock:send(...))
end

function TlsSock:receive(...)
    if not self.sock then return nil, 'closed' end
    return doresults(self, self.sock:receive(...))
end

function TlsSock:settimeout(...)
    if not self.sock then return nil, 'closed' end
    return true -- ignore timeout update
end

function TlsSock:close()
    return true
end

local module = {connector = {}}

function module.connector.simple(config, timeout, source_address, source_port)
    return function()
        local sock = assert(socket.tcp())
        if source_address then
            assert(sock:bind(source_address, source_port or 0))
        end
        if timeout then assert(sock:settimeout(timeout, 't')) end
        return {
            sock = sock,
            connect = function(self, host, port)
                local res, err = self.sock:connect(host, port)
                if not res then return res, err end

                -- See rationale in TlsSock:connect.
                assert(self.sock:setoption('tcp-nodelay', true))

                if config then
                    config.mode = 'client'
                    self.sock = assert(socket.ssl(self.sock, config))
                    self.sock:sni(host)
                    return fixerr(self.sock:dohandshake())
                end
                return true
            end,
            close = function(self) return self.sock:close() end,
            send = function(self, ...) return fixerr(self.sock:send(...)) end,
            receive = function(self, ...) return fixerr(self.sock:receive(...)) end,
            settimeout = function() return true end
        }
    end
end

function module.connector.keepalive(config, timeout, source_address, source_port)
    local self = TlsSock{config = config}
    return function ()
        -- If we already have a socket, which by this point should
        -- always be luasec's TLS wrapper instead of a raw TCP socket,
        -- check if there's any data to receive. If there is, or we get
        -- an unexpected error, something has gone wrong so create the
        -- socket anew.
        if self.sock then
            assert(self.sock:settimeout(0, 't'))
            local res, err = self.sock:receive'*a'
            if res or not ssltimeout[err] then
                failsock(self)
            end
        end

        if not self.sock then
            local res, err = socket.tcp()
            if not res then return nil, err end
            self.sock = res
            if source_address then
                res, err = self.sock:bind(source_address, source_port or 0)
                if not res then return failsock(self, err) end
            end
        end
        assert(self.sock:settimeout(timeout, 't'))
        return self
    end
end

local schemeport = {
    http = 80,
    https = 443,
}

function module.parse(endpoint)
    local purl = url.parse(endpoint)
    if purl.port == nil then
        local port = schemeport[purl.scheme]
        if not port then return nil, 'invalid scheme' end
        purl.port = port
    end
    return purl
end

local function normurl(url)
    if type(url) == 'table' then return url end
    if type(url) == 'string' then return cujo.https.parse(url) end
    error'invalid url type'
end

-- HTTPS request helper.
--
-- params are mostly passed as-is to the LuaSocket http.request function.
-- Special cases are:
--
-- * on_done: The callback for the result. Depends on "sink", see below.
--
-- * multipart: This table is encoded as multipart form data in the body.
--              Overrides "headers", which cannot be used together with this.
--
-- * sink: If passed, it is called for each chunk in the body and "on_done" is
--         called with only a boolean and optional error code.
--
--         If not passed, "on_done" is called with the body as a string, the
--         HTTP code, and HTTP headers.
function module.request(params)
    local purl, err = normurl(params.url)
    if not purl then
        return params.on_done(nil, err)
    end
    params.url = url.build(purl)
    if params.multipart then
        assert(params.headers == nil)
        local req = multipart.gen_request(params.multipart)
        params.multipart = nil
        tabop.copy(req, params)
    end
    if params.sink == nil then
        local body = {}
        params.sink = ltn12.sink.table(body)
        local res, code, headers = http.request(params)
        if not res then
            return params.on_done(nil, code)
        end
        return params.on_done(table.concat(body), code, headers)
    end
    params.on_done(http.request(params))
end

return module
