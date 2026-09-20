local coroutine = require "coroutine"
local cocreate = coroutine.create
local coresume = coroutine.resume

local procstat = io.open("/proc/self/stat")

local function cputimes()
	-- This additional seek is needed on at least some platforms to make
	-- sure the read() below fetches up-to-date data instead of using an
	-- internal buffer.
	--
	-- Speculation about the reason: fseek() clears the end-of-file
	-- indicator on a FILE*, which forces the actual file to be checked for
	-- data so that EOF can be reached again. clearerr() is a typical way of
	-- doing this but fseek() has the same effect.
	procstat:seek("cur", 1)

	procstat:seek("set", 0)
	local stat = procstat:read()
	-- pid comm state ppid pgrp session tty_nr tpgid flags minflt cminflt majflt cmajflt (utime) (stime) (cutime) (cstime)
	local utime, stime, cutime, cstime = stat:match("^%S+ %b() %u %S+ %S+ %S+ %S+ %S+ %d+ %d+ %d+ %d+ %d+ (%d+) (%d+) (%S+) (%S+)")
	return tonumber(utime), tonumber(stime), tonumber(cutime), tonumber(cstime)
end

local module = {
	names = {},
	data = {},
}

local names = module.names
local data = module.data
local enabled = false

function module.create(f, name)
	assert(type(name) == "string", "bad argument #2 (string expected)")
	local t = cocreate(f)
	names[t] = name
	local datum = data[name]
	if datum == nil then
		data[name] = {0, 0, 0, 0, 0, 1}
	else
		datum[6] = datum[6] + 1
	end
	return t
end

function module.resume(co, ...)
	if not enabled then
		coresume(co, ...)
		return
	end
	local utime0, stime0, cutime0, cstime0 = cputimes()
	coresume(co, ...)
	if not utime0 then return end
	local utime1, stime1, cutime1, cstime1 = cputimes()
	local datum = data[names[co]]
	assert(datum ~= nil, "cannot resume coroutine that wasn't created here")
	datum[1] = datum[1] + utime1 - utime0
	datum[2] = datum[2] + stime1 - stime0
	datum[3] = datum[3] + cutime1 - cutime0
	datum[4] = datum[4] + cstime1 - cstime0
	datum[5] = datum[5] + 1
end

function module.enable(enable)
	enabled = enable
end

function module.get_timings()
	local results = {}
	for name, datum in pairs(data) do
		results[name] = {
			utime = datum[1],
			stime = datum[2],
			cutime = datum[3],
			cstime = datum[4],
			resumes = datum[5],
			instances = datum[6],
		}
	end
	return results
end

return module
