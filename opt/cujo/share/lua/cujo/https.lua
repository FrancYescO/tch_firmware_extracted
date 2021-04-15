--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

local http = require'socket.http'
local socket = require'coutil.socket.ssl'
local url = require'socket.url'
local multipart = require'multipart-post'
local ltn12 = require'ltn12'

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

local function doresults(self, res, err, ...)
	if not res then
		return failsock(self, ssltimeout[err] and 'timeout' or err)
	end
	return res, err, ...
end

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

cujo.https = {connector = {}}

local function fixerr(res, err, ...)
	if not res then return nil, ssltimeout[err] and 'timeout' or err end
	return res, err, ...
end

function cujo.https.connector.simple(config, timeout, source_address, source_port)
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

function cujo.https.connector.keepalive(config, timeout, source_address, source_port)
	local self = TlsSock{config = config}
	return function ()
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

function cujo.https.parse(endpoint)
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

function cujo.https.request(params)
	local purl, err = normurl(params.url)
	if not purl then return nil, err end
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
		local res, code, headers, status =  http.request(params)
		if not res then return nil, code end
		return table.concat(body), code, headers, status
	end
	return http.request(params)
end
