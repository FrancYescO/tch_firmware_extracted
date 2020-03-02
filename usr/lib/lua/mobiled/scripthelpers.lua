---------------------------------
--! @file
--! @brief The scripthelpers module containing functions reused throughout Mobiled, mappings and webui
---------------------------------

local bit = require("bit")
local band, bxor = bit.band, bit.bxor
local string, pairs, tostring, type, setmetatable, io, table, tonumber = string, pairs, tostring, type, setmetatable, io, table, tonumber

local M = {}

local function empty()
	return ""
end
local empty_mt = { __index = empty }

function M.getopt(args, ostr)
	local arg, place = nil, 0;
	return function ()
		if place == 0 then -- update scanning pointer
			place = 1
			if #args == 0 or args[1]:sub(1, 1) ~= '-' then place = 0; return nil end
			if #args[1] >= 2 then
				place = place + 1
				if args[1]:sub(2, 2) == '-' then -- found "--"
					place = 0
					table.remove(args, 1);
					return nil;
				end
			end
		end
		local optopt = args[1]:sub(place, place);
		place = place + 1;
		local oli = ostr:find(optopt);
		if optopt == ':' or oli == nil then -- unknown option
			if optopt == '-' then return nil end
			if place > #args[1] then
				table.remove(args, 1);
				place = 0;
			end
			return '?';
		end
		oli = oli + 1;
		if ostr:sub(oli, oli) ~= ':' then -- do not need argument
			arg = nil;
			if place > #args[1] then
				table.remove(args, 1);
				place = 0;
			end
		else -- need an argument
			if place <= #args[1] then  -- no white space
				arg = args[1]:sub(place);
			else
				table.remove(args, 1);
				if #args == 0 then -- an option requiring argument is the last one
					place = 0;
					if ostr:sub(1, 1) == ':' then return ':' end
					return '?';
				else arg = args[1] end
			end
			table.remove(args, 1);
			place = 0;
		end
		return optopt, arg;
	end
end

function M.startswith(String, Start)
	return string.sub(String, 1, string.len(Start)) == Start
end

function M.sanitize(data)
	local sanitizedData = {}
	for k, v in pairs(data) do
		if type(v) == "table" then
			sanitizedData[k] = M.sanitize(v)
		else
			sanitizedData[k] = tostring(v)
		end
	end
	return sanitizedData
end

function M.getUbusData(conn, facility, func, params)
	local data = conn:call(facility, func, params) or {}
	local result = M.sanitize(data)
	setmetatable(result, empty_mt)
	return result
end

-- Print anything - including nested tables
local function tprint (tt, output, indent, done)
	done = done or {}
	indent = indent or 0
	if type(tt) == "table" then
		for key, value in pairs (tt) do
			table.insert(output, string.rep (" ", indent)) -- indent it
			if type (value) == "table" and not done [value] then
				done [value] = true
				table.insert(output, string.format("[%s] => table\n", tostring (key)));
				table.insert(output, string.rep (" ", indent+4)) -- indent it
				table.insert(output, "(\n");
				tprint (value, output, indent + 7, done)
				table.insert(output, string.rep (" ", indent+4)) -- indent it
				table.insert(output, ")\n");
			else
				table.insert(output, string.format("[%s] => %s\n", tostring (key), tostring(value)))
			end
		end
	else
		if tt then table.insert(output, tostring(tt) .. "\n") end
	end
end

function M.twrite(tt, f, append)
	local output = {}
	tprint(tt, output)
	local file
	if not append then
		file = io.open(f, "w")
	else
		file = io.open(f, "a")
	end
	for _, line in pairs(output) do
		file:write(line)
	end
	file:close()
end

function M.tprint(tt)
	local output = {}
	tprint(tt, output)
	for _, line in pairs(output) do
		io.write(line)
	end
end

function M.tablelength(tbl)
	local count = 0
	for _ in pairs(tbl) do count = count + 1 end
	return count
end

function M.sleep(n)
	os.execute("sleep " .. tonumber(n))
end

function M.split(data, delimiter)
	local result = {}
	if not data then return result end
	local from  = 1
	local delim_from, delim_to = string.find(data, delimiter, from)
	while delim_from do
		table.insert(result, string.sub(data, from , delim_from-1 ))
		from  = delim_to + 1
		delim_from, delim_to = string.find(data, delimiter, from)
	end
	local str = string.sub(data, from)
	if str and #str > 0 then
		table.insert(result, str)
	end
	return result
end

function M.lines(str)
	local t = {}
	if str then
		local function h(line) if #line > 0 then table.insert(t, line) end return "" end
		h((str:gsub("(.-)\r?\n", h)))
	end
	return t
end

function M.subrange(t, first, last)
	local sub = {}
	for i=first,last do
		sub[#sub + 1] = t[i]
	end
	return sub
end

function M.file_exists(name)
	local f = io.open(name, "r")
	if f~=nil then io.close(f) return true else return false end
end

function M.read_file(name)
	local content = nil
	local f = io.open(name, "rb")
	if f then
		content = f:read("*all")
		f:close()
	end
	return content
end

function M.capture_cmd(cmd)
	local f = io.popen(cmd, 'r')
	if not f then return "" end
	local s = f:read('*a')
	f:close()
	return s
end

function M.basename(str)
	local name = string.gsub(str, "(.*/)(.*)", "%2")
	return name
end

function M.table_contains(tbl, value)
	for k,v in pairs(tbl) do
		if value == v then
			return true
		end
	end
	return false
end

function M.merge_tables(t1, t2)
	if type(t1) == "table" and type(t2) == "table" then
		for k,v in pairs(t2) do
			if type(v) == "table" then
				if type(t1[k] or false) == "table" then
					M.merge_tables(t1[k] or {}, t2[k] or {})
				else
					t1[k] = v
				end
			else
				t1[k] = v
			end
		end
	end
	return t1
end

function M.table_eq(table1, table2)
	local avoid_loops = {}
	local function recurse(t1, t2)
		-- compare value types
		if type(t1) ~= type(t2) then return false end
		-- Base case: compare simple values
		if type(t1) ~= "table" then return t1 == t2 end
		-- Now, on to tables.
		-- First, let's avoid looping forever.
		if avoid_loops[t1] then return avoid_loops[t1] == t2 end
		avoid_loops[t1] = t2
		-- Copy keys from t2
		local t2keys = {}
		local t2tablekeys = {}
		for k, _ in pairs(t2) do
			if type(k) == "table" then table.insert(t2tablekeys, k) end
			t2keys[k] = true
		end
		-- Let's iterate keys from t1
		for k1, v1 in pairs(t1) do
			local v2 = t2[k1]
			if type(k1) == "table" then
				-- if key is a table, we need to find an equivalent one.
				local ok = false
				for i, tk in ipairs(t2tablekeys) do
					if M.table_eq(k1, tk) and recurse(v1, t2[tk]) then
						table.remove(t2tablekeys, i)
						t2keys[tk] = nil
						ok = true
						break
					end
				end
				if not ok then return false end
			else
				-- t1 has a key which t2 doesn't have, fail.
				if v2 == nil then return false end
				t2keys[k1] = nil
				if not recurse(v1, v2) then return false end
			end
		end
		-- if t2 has a key which t1 doesn't have, fail.
		if next(t2keys) then return false end
		return true
	end
	return recurse(table1, table2)
end

function M.luhn_checksum(data)
	if type(data) ~= "string" then return false end
	local num = 0
	local nDigits = #data
	local odd = band(nDigits, 1)
	for count = 0,nDigits-1 do
		local digit = tonumber(string.sub(data, count+1,count+1))
		if not digit then return false end
		if (bxor(band(count, 1),odd)) == 0 then
			digit = digit * 2
		end
		if digit > 9 then
			digit = digit - 9
		end
		num = num + digit
	end
	return ((num % 10) == 0)
end

function M.isnumeric(data)
	if type(data) ~= "string" then return nil end
	for i = 1, #data do
		local c = data:sub(i,i)
		if not tonumber(c) then return nil end
	end
	return true
end

function M.swap(data)
	if type(data) ~= "string" then return nil end
	local t = {}
	for i = 1, #data, 2 do
		local a = data:sub(i,i)
		local b = data:sub(i+1,i+1)
		if b then table.insert(t, b) end
		table.insert(t, a)
	end
	return table.concat(t, "")
end

function M.uptime()
	local f = io.open("/proc/uptime")
	local line = f:read("*line")
	f:close()
	return math.floor(tonumber(line:match("[%d%.]+")))
end

return M
