local _G = require "_G"
local error = _G.error

local table = require "table"
local pack = table.pack
local unpack = table.unpack

local vararg = require "vararg"
local countargs = vararg.len
local vaconcat = vararg.concat
local varemove = vararg.remove

local coevent = require "coutil.event"
local await = coevent.await
local awaitall = coevent.awaitall
local awaitany = coevent.awaitany
local awaiteach = coevent.awaiteach

local nextof = setmetatable({}, { __mode = "k" })

local function enqueue(event, item)
	local tail = nextof[event]
	if tail == nil then
		nextof[item] = item
	else
		nextof[item] = nextof[tail]
		nextof[tail] = item
	end
	nextof[event] = item
end

local function dequeue(event)
	local tail = nextof[event]
	if tail ~= nil then
		local head = nextof[tail]
		if head == tail then
			nextof[event] = nil
		else
			nextof[tail] = nextof[head]
		end
		nextof[head] = nil
		return head
	end
end

local module = {
	version = "1.0 alpha",
	pending = coevent.pending,
}

for _, name in _G.ipairs{ "emitone", "emitall" } do
	local emit = coevent[name]
	module[name] = function (event, ...)
		if emit(event, ...) then
			return true
		elseif event ~= nil then
			enqueue(event, pack(...))
		end
		return false
	end
end

function module.queued(event)
	return nextof[event] ~= nil
end

function module.await(event)
	local values = dequeue(event)
	if values ~= nil then
		return unpack(values)
	end
	return await(event)
end

do
	local function onlypending(events, count, event, ...)
		if count > 0 then
			if event ~= nil then
				if events[event] == nil and dequeue(event) == nil then
					events[event] = true
					return event, onlypending(events, count-1, ...)
				end
				events[event] = true
			end
			return onlypending(events, count-1, ...)
		end
	end

	function module.awaitall(...)
		return awaitall(onlypending({}, countargs(...), ...))
	end
end

function module.awaitany(...)
	for index = 1, countargs(...) do
		local event = select(index, ...)
		local values = dequeue(event)
		if values ~= nil  then
			return event, unpack(values)
		end
	end
	return awaitany(...)
end

do
	local function packres(success, ...)
		if not success then
			return false, ...
		elseif countargs(...) > 0 then
			return true, pack(...)
		end
	end

	local function doqueued(callback, events, i, j, ...)
		if i <= j then
			local event = select(i, ...)
			if event ~= nil then
				local values = events[event]
				if values == nil then
					values = dequeue(event)
					if values == nil  then
						events[event] = false
						return doqueued(callback, events, i+1, j, ...)
					end
					local ok, result = packres(pcall(callback, event, unpack(values)))
					if ok == true then
						return false, unpack(result) -- don't await and return these values
					elseif ok == false then
						return error(result)
					end
					events[event] = values
				end
			end
			return doqueued(callback, events, i, j-1, varemove(i, ...))
		end
		return true, ... -- await each of the events '...'
	end

	local function doawait(callback, await, ...)
		if await then -- '...' are non-queued events, else are 'callback' results
			return awaiteach(callback, ...)
		end
		return ...
	end

	function module.awaiteach(callback, ...)
		return doawait(callback, doqueued(callback, {}, 1, countargs(...), ...))
	end
end

return module
