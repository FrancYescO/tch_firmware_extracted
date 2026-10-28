local require = require
local ipairs = ipairs
local pairs = pairs
local type = type
local match = string.match
local print = print
local concat = table.concat
local setmetatable = setmetatable
local tonumber = tonumber

-- this require is not strictly needed, but simplifies the unit testing
local os = require 'os'

local M = {}

local function printf(print_function, fmt, ...)
	print_function = print_function or print
	print_function(fmt:format(...))
end

local Config = {}
Config.__index = Config

local function newConfig(sections)
	return setmetatable({sections=sections}, Config)
end

--- retrieve a single named section from the config
-- @param secname [#string] the section name
-- @return the section with the given name or nil if no such section
function Config:byname(secname)
	for _, s in ipairs(self.sections) do
		if s['.name']==secname then
			return s
		end
	end
end

local INDEXED = true
local MAPPED = false
M.INDEXED = INDEXED
M.MAPPED = MAPPED

--- retrieve all sections of a given type
-- @param sectype [#string] the reqeusrted section type
-- @param indexed [#boolean] when true the resulting table is an array
--     otherwise it is a map (keyed on section name (.name property)
--     The default is false.
--     To make the call more readable the module defines the constants
--     INDEXED and MAPPED (false and true respectively)
-- @returns a table with the matching sections
function Config:bysection(sectype, indexed)
	local sections = {}
	for _, s in ipairs(self.sections) do
		if s['.type']==sectype then
			if indexed then
				sections[#sections+1] = s
			else
				sections[s['.name']] = s
			end
		end
	end
	return sections
end

--- loop over all sections in the config
-- @param fn [#function] the function to call
-- @param state [#any] extra parameter passed to fn
--
-- The function is passed a section object and the given state.
-- When the return value from the function is false (explicitly false, not nil)
-- the iteration is stopped.
function Config:each(fn, state)
	for _, section in ipairs(self.sections) do
		local r = fn(section, state)
		if r==false then --need explicit false to stop
			return
		end
	end
end

--- add a section to the config
-- @param ... the section(s) object to add
function Config:add(...)
	local s = self.sections
	for _, section in ipairs({...}) do
		s[#s+1] = section
	end
end

local function table_copy(t)
	if t then
		local r = {}
		for k, v in pairs(t) do
			r[k] = v
		end
		return r
	end
end

--- clone a section
-- @param section the section object to clone
-- @param option, ... on optional list of options to include. If none are given
--     all options will be cloned
--     The dot properties (like .name and .type) are always copied
-- @return the cloned section
function Config:copy_section(section, option, ...)
	local s = {}
	if option then
		-- copy only selected options
		s['.config'] = section['.config']
		s['.type'] = section['.type']
		s['.name'] = section['.name']
		s['.anonymous'] = table_copy(section['.anonymous'])
		s['.locator'] = section['.locator']
		for _, opt in ipairs({option, ...}) do
			s[opt] = section[opt]
		end
	else
		-- copy all options
		for opt, value in pairs(section) do
			if type(value) == 'table' then
				-- it is a list option, so an array
				local nv = {}
				for _, v in ipairs(value) do
					nv[#nv+1] = v
				end
				value = nv
			end
			s[opt] = value
		end
	end
	return s
end

local ucilist = {
	old = {env='OLD_UCI_CONFIG', default='/etc/config', savedir='/tmp/.olduci'},
	new = {env='NEW_UCI_CONFIG'},
	current = {}
}

--- retrieve a uci cursor
-- @param old_or_new [#string]
--     old: use config in $OLD_UCI_CONFIG or /etc/config
--     new: use config in $NEW_UCI_CONFIG or /etc/config
--     current: use current uci config
-- @return a uci cursor object. Repeated calls for the same config will return
--     the sdame cursor object
function M.uci(old_or_new)
	old_or_new = old_or_new or 'current'
	local m = ucilist[old_or_new]
	if not m then
		return nil, "invalid parameter"
	end

	local uci = m.uci
	if not uci then
		local confdir = m.env and os.getenv(m.env) or m.default
		local savedir = m.savedir
		uci = require('uci').alt_cursor(confdir, savedir)
		m.uci = uci
	end
	return uci
end

--- create a new empty config object
-- @return a config object with an empty sections list
function M.Config()
	return newConfig({})
end

--- load a uci config			print("get "..varname.." = "..(os.env[varname] or '!'))
--
-- @param uci [#uci] The uci cursor to use
-- @param config [#string] the name of the config
-- @param section, ... [#string] an optional list of sections identifications
--     either:
--         - sectionname  selects the section with this name
--         - @sectype[n] selects the n-th section if the given type
--         - @sectype     selects all sections with the given type, this is an
--                        extension of the uci syntax
-- @return a config object, all the sections will have the .config option set
--   to the given config
function M.load(uci, config, section, ...)
	local data = {}
	local sections
	if section then
		sections = {section, ...}
	end

	local cfg = newConfig({})
	uci:foreach(config, function(s)
		cfg.sections[#cfg.sections+1] = s
		if not sections then
			-- use all
			s['.config'] = config
		end
	end)

	if sections then
		for _, s in ipairs(sections) do
			local at, name = s:match("^(@?)(.*)")
			if at == '@' then
				local stype, index = name:match("^(.*)%[(.*)%]")
				if stype then
					--indexed access
					local index = tonumber(index)
					local indexed
					if index then
						local all = cfg:bysection(stype, INDEXED)
						if index>=0 then
							indexed = all[index+1]
						else
							indexed = all[#all+1+index]
						end
						if indexed then
							indexed['.config'] = config
						end
					end
				else
					for _, s in pairs(cfg:bysection(name)) do
						s['.config'] = config
					end
				end
			else
				local named = cfg:byname(name)
				if named then
					-- use this
					named['.config'] = config
				end
			end
		end
		local selected = {}
		for _, s in ipairs(cfg.sections) do
			if s['.config'] then
				selected[#selected+1] = s
			end
		end
		cfg = newConfig(selected)
	end

	return cfg
end

--- get the name of the section
-- @param uci [#uic] the uci cursor to use
-- @param section [#section] the section object
-- @return name, present, anonymous with
--   name the name of the section, or nil if not found
--   present true if section is present, false if not
--   and anonymous indicates if the returned name is
--   anonymous one or not
-- note:
--   if section contains a locator, the actual section
--   is not used.
--   In that case the name returned can be anonymous.
-- locator: a table that maps option names to values.
--   A section matches the locator if the values for the
--   options in the locator are equal to the values of
--   the corresponding option in the section.
local function get_section_name(uci, section)
	local sname, present, anonymous
	local locator = section['.locator']
	if locator then
		-- find the section using the locator
		uci:foreach(section['.config'], section['.type'], function(s)
			for k, v in pairs(locator) do
				if s[k]~=v then
					return --no a match
				end
			end
			-- all options match
			sname = section['.name']
			anonymous = section['.anonymous']
			present = true
			return false --stop looping over all sections
		end)
	elseif not section['.anonymous'] then
		--locate section using the name
		sname = section['.name']
		uci:foreach(section['.config'], section['.type'], function(s)
			if s['.name']==sname then
				present = true
				anonymous = s['.anonymous']
				return false --break the loop
			end
		end)
	end
	return sname, present, anonymous
end

--- write a section back to uci
-- @param uci [#uci] the uci cursor to use
-- @param section [#section] the section object to write. It must have the
--   .config option set to the config name to use.
-- @return the name of the updated config or
--    nil, errmsg in case of error
-- This function will create the config if it does not exist.
local function write_section(uci, section)
	local config = section['.config']
	if not config then
		return nil, "missing .config entry"
	end

	uci:ensure_config_file(config)
	-- create the target section if needed
	local sname, present, anonymous = get_section_name(uci, section)
	if sname then
		-- only create a named section if it is not present
		if not present then
			uci:set(config, sname, section['.type'])
		end
	else
		sname = uci:add(config, section['.type'])
	end
	-- the actual name of the section is not preserved
	-- explicitly. If the section was found by locator
	-- it is not relevant, if it was found by name the
	-- name is already correct and if it is anoymous it
	-- does not matter.
	for option, value in pairs(section) do
		if not option:match('^%.') then
			uci:set(config, sname, option, value)
		end
	end
	return config
end
M.write_section = write_section

--- write a whole config back to uci
-- @param uci [#uci] the uci cursor to use
-- @param config the config object
-- @return the given uci cursor and a table(map) of all updated configs
--     (the config names are the keys, the value is true)
-- If the config file is missing, it will be created.
function M.save(uci, config)
	local configs = {}
	config:each(function(section)
		local cname = write_section(uci, section)
		if cname then
			configs[cname] = true
		end
	end)
	for config in pairs(configs) do
		uci:save(config)
	end
	return uci, configs
end

--- commit to uci
-- @param uci [#uci] the uci cursor to use
-- @param config [#table] a map keyed of config name
--
-- convenience function. intended use is:
--     uciconv.commit(uciconv.save(uci, config))
function M.commit(uci, configs)
	for config in pairs(configs) do
		uci:commit(config)
	end
end

--- print out a section
-- @param section the section to print
-- @print_function optional function taking a single string argument. This
--     defaults to the print function
local function print_section(section, print_function)
	local config = section['.config'] or '%%config%%'
	local sname = section['.name']
	printf(print_function, "%s.%s=%s", config, sname, section['.type'])
	for name, value in pairs(section) do
		if not name:match('^%.') then
			if type(value) == 'table' then
				value=concat(value, ' ')
			end
			printf(print_function, "%s.%s.%s=%s", config, sname, name, value)
		end
	end
end
M.print_section = print_section

--- debug function to print a complete config
-- @param config the config to print
function M.print_config(config)
	config:each(function(section)
		print_section(section)
	end)
end

return M
