--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2015-2019 CUJO LLC. All rights reserved.
--

local process = require'process'
local Queue = require'loop.collection.Queue'
local cospawn = require'coutil.spawn'

cujo.jobs = {}

local evqueue = oo.class()

function evqueue:enqueue(val)
	self.queue:enqueue(val)
	event.emitone(self.queue)
end

function evqueue:dequeue()
	while true do
		local val = self.queue:dequeue()
		if val ~= nil then return val end
		event.awaitany(self.queue)
	end
end

function cujo.jobs.createqueue() return evqueue{queue = Queue()} end

local function errhandler(err)
	cujo.log:error('unhandled Lua error: ', debug.traceback(err))
end

function cujo.jobs.spawn(name, f, ...) cospawn.catch(errhandler, name, f, ...) end

function cujo.jobs.wait(t, ...)
	if t ~= nil then return time.sleep(t, ...) end
	return event.awaitany(...)
end

do
	local insideof = setmetatable({}, {__mode = 'k'})
	local function unlock(m, ...)
		insideof[m] = nil
		event.emitone(m)
		return ...
	end
	function cujo.jobs.lockedcall(m, f, ...)
		local thread = coroutine.running()
		local inside = insideof[m]
		if inside == thread then error('nested lock', 2) end
		if inside ~= nil then event.await(m) end
		insideof[m] = thread
		return unlock(m, f(...))
	end
end

function cujo.jobs.exec(cmd, args)
	local args_str = table.concat(args, " ")
	cujo.log:jobs("starting '", cmd, ' ', args_str, "'")
	local proc, err = process.create{
		execfile = assert(cmd, 'missing command'),
		arguments = args,
	}
	if not proc then
		cujo.log:error("failed to run '", cmd, ' ', args_str, "' (", err, ')')
		return nil, err
	end
	local finish = os.time() + cujo.config.job.timeout
	repeat
		time.sleep(cujo.config.job.pollingtime)
		local exitval, err = process.exitval(proc)
		if exitval == 0 then
			cujo.log:jobs("command '", cmd, " ", args_str, "' executed successfully")
			return true
		end
		if exitval then
			cujo.log:warn("command '", cmd, " ", args_str, "' exit with error ", exitval)
			return nil, exitval
		end
		if err ~= 'unfulfilled' then
			cujo.log:error("error running command '", cmd, " ", args_str, "' (", err, ')')
			return nil, err
		end
	until os.time() >= finish
	cujo.log:warn("command '", cmd, " ", args_str, "' is taking too long")
	return nil, 'timeout'
end
