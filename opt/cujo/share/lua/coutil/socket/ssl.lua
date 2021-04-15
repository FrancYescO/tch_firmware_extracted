local _G = require "_G"
local assert = _G.assert
local ipairs = _G.ipairs
local setmetatable = _G.setmetatable
local type = _G.type

local array = require "table"
local concat = array.concat

local table = require "loop.table"
local copy = table.copy

local event = require "coutil.event"
local awaitany = event.awaitany

local cosocket = require "coutil.socket"
local selectsockets = cosocket.select

local sockwrap = require "coutil.socket.wrap"
local newclass = sockwrap.newclass
local wrapsocket = sockwrap.wrapsocket
local setupevents = sockwrap.setupevents
local cancelevents = sockwrap.cancelevents

local ssl = require "ssl"
local newctxt = ssl.newcontext
local sslwrap = ssl.wrap

local CoSSL = newclass()

function CoSSL:dohandshake()
	local socket = self.__object
	local result, errmsg = socket:dohandshake()
	while not result do
		local write
		if errmsg == "wantwrite" then
			write = self
		elseif errmsg ~= "wantread" then
			if not errmsg then
				local verif_result
				verif_result, errmsg = socket:getpeerverification()
				if verif_result then
					errmsg = "unknown handshake error"
				else
					errmsg = "TLS certificate invalid: " .. errmsg
				end
			end
			socket:close()
			break
		end
		local event, deadline = setupevents(socket, write, self)
		if event ~= nil then
			awaitany(event, deadline)
			cancelevents(socket, write, deadline)
			result, errmsg = socket:dohandshake()
		else
			result, errmsg = nil, "timeout"
			break
		end
	end
	if result then
		result = self
		self.sslhandshake = true
	end

	if not result and errmsg == "Bad file descriptor" then
		errmsg = "closed"
	end

	return result, errmsg
end

do
	local err2wrtevt = {
		timeout = true,
		wantread = false,
		wantwrite = true,
	}
	function CoSSL:send(data, i, j)
		if self.sslhandshake == nil then
			local result, errmsg = self:dohandshake()
			if not result then
				return nil, errmsg, i==nil and 0 or i-1, 0
			end
		end
		local socket = self.__object
		local result, errmsg, lastbyte, elapsed = socket:send(data, i, j)

		-- check if the job has not yet been completed
		local wantwrite = err2wrtevt[errmsg]
		if not result and wantwrite ~= nil then
			errmsg = "timeout"
			local write = wantwrite and self or nil
			local event, deadline = setupevents(socket, write, self)
			if event ~= nil then
				-- wait for more space on the socket or a timeout
				while awaitany(event, deadline) == event do
					-- fill any space free on the socket one last time
					local extra
					result, errmsg, lastbyte, extra = socket:send(data, lastbyte+1, j)
					if extra then elapsed = elapsed + extra end
					local newwant = err2wrtevt[errmsg]
					if result or newwant == nil then
						break
					else
						errmsg = "timeout"
						if newwant ~= wantwrite then
							wantwrite = newwant
							cancelevents(socket, write, nil)
							write = wantwrite and self or nil
							event, deadline = setupevents(socket, write, self)
							if event == nil then break end
						end
					end
				end
				cancelevents(socket, write, deadline)
			end
		end

		if not result and errmsg == "Broken pipe" then
			errmsg = "closed"
		end

		return result, errmsg, lastbyte, elapsed
	end
end

do
	local err2wrtevt = {
		timeout = false,
		wantread = false,
		wantwrite = true,
	}
	function CoSSL:receive(pattern, ...)
		if self.sslhandshake == nil then
			local result, errmsg = self:dohandshake()
			if not result then
				return nil, errmsg, "", 0
			end
		end
		local socket = self.__object
		local result, errmsg, partial, elapsed = socket:receive(pattern, ...)

		-- check if the job has not yet been completed
		local wantwrite = err2wrtevt[errmsg]
		if not result and wantwrite ~= nil then
			errmsg = "timeout"
			local write = wantwrite and self or nil
			local event, deadline = setupevents(socket, write, self)
			if event ~= nil then
				-- initialize data read buffer with data already read
				local buffer = { partial }
				
				-- register socket for network event watch
				while awaitany(event, deadline) == event do -- otherwise it was a timeout
					-- reduce the number of required bytes
					if type(pattern) == "number" then
						pattern = pattern - #partial
					end
					-- read any data left on the socket one last time
					local extra
					result, errmsg, partial, extra = socket:receive(pattern)
					if extra then elapsed = elapsed + extra end
					if result then
						buffer[#buffer+1] = result
						break
					else
						buffer[#buffer+1] = partial
						local newwant = err2wrtevt[errmsg]
						if newwant == nil then
							break
						else
							errmsg = "timeout"
							if newwant ~= wantwrite then
								wantwrite = newwant
								cancelevents(socket, write, nil)
								write = wantwrite and self or nil
								event, deadline = setupevents(socket, write, self)
								if event == nil then break end
							end
						end
					end
				end
				
				-- concat buffered data
				if result then
					result = concat(buffer)
				else
					partial = concat(buffer)
				end

				cancelevents(socket, write, deadline)
			end
		end

		return result, errmsg, partial, elapsed
	end
end

--------------------------------------------------------------------------------
-- Wrapped Lua Socket API ------------------------------------------------------
--------------------------------------------------------------------------------

local sockets = setmetatable({}, {__index = cosocket})

function sockets.sslcontext(...)
	return newctxt(...)
end

function sockets.ssl(socket, context)
	local result, errmsg = sslwrap(socket.__object, context)
	if result ~= nil then
		return wrapsocket(CoSSL, result)
	end
	return result, errmsg
end

function sockets.select(recvt, sendt, timeout)
	-- collect sockets and check for concurrent use
	local defset, switched = {}, {}
	local recv, send
	if recvt ~= nil then
		recv = {}
		defset[recvt] = recv
	end
	if sendt ~= nil then
		send = {}
		defset[sendt] = send
	end
	local want2set = {
		read = recv,
		write = send,
	}
	for input, output in pairs(defset) do
		for _, socket in ipairs(input) do
			if socket.want ~= nil then
				local newset = want2set[socket:want()]
				if newset ~= output then
					switched[socket] = true
					output = newset
				end
			end
			output[#output+1] = socket
		end
	end

	-- collect any ready socket
	local readok, writeok, errmsg = selectsockets(recv, send, timeout)

	-- replace sockets for the corresponding cosocket wrapper
	local readres, writeres = {}, {}
	local out2res = {
		[false] = readres,
		[true] = writeres,
	}
	for key, result in pairs(out2res) do
		for _, socket in ipairs(key and writeok or readok) do
			if switched[socket] ~= nil then
				result = out2res[not key]
			end
			result[result+1] = socket
			result[socket] = true
		end
	end
	
	return readok, writeok, errmsg
end

return sockets
