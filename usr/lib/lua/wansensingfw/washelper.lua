local M = {}
local Script = {}
local prefix = '/etc/wansensing/'

Script.__index = Script


-- when loading a worker, we use this table to prevent the registration of specific events, with an error message
forbidden_worker_events={
   ['timeout']="event not intended for worker"
}

-- this lenient version is used by scripts 'in the wild', therefore
-- we cannot always use the strict 'set2' alternative below.
local function set (list)
    local k, v

    -- if list is already a string hash table, reuse it
    -- so that caller will have direct access to registered events,
    -- allowing script to dynamically (un)register events at runtime
    if type(list) == "table" and (type(list.timeout) == "boolean" or type(list.start) == "boolean") then
	local hashtable = true

	for k, v in pairs(list) do
	    if type(k) ~= "string" or type(v) ~= "boolean" then
		hashtable = false
		break
	    end
	end

	if hashtable then
	    return list
	end
    end

    local set = { timeout = true } -- timeout events by default
    if list then
	for k, v in pairs(list) do set[v] = true end
    end

    return set
end

-- a new version of set (think about dup, dup2 and dup3  in unistd.h)
-- this version only accepts a table with events mapped to a boolean
-- @param runtime
-- @param list, the SenseEventSet table from a wansensing custo script
-- @param forbidden,  a hashable that maps event names to a boolean
local function set2 (runtime, list, forbidden)
    local k, v
    local hashtable = true
    -- if list is already a string hash table, reuse it
    -- so that caller will have direct access to registered events,
    -- allowing script to dynamically (un)register events at runtime
    if hashtable and type(list) ~= "table" then
       hashtable=false
	runtime.logger:error("SenseEventSet is not a table")
    end
    if (hashtable) then
       for k, v in pairs(list) do
	  if type(k) ~= "string" or type(v) ~= "boolean" then
	     hashtable = false
	     break
	  end
       end
       if not hashtable then
	   runtime.logger:error("Expected a table from string keys to boolean values as SenseEventSet ")
       end
    end
    if hashtable and type(forbidden) == 'table' then
       for k, v in pairs(list) do
	  if forbidden[k] ~= nil then
	     hashtable = false
	     local reason=''
	     if type(forbidden[k])=='string' then
		reason=' ('..forbidden[k]..')'
	     end
	      runtime.logger:error("SenseEventSet cannot contain '"..tostring(k).."'"..reason)
	  end
       end
    end
    if hashtable then
       return list
    else
       return nil
    end
end

function Script:name()
    return self.scriptname
end

function Script:entry( requester, runtime, ... )
    runtime.logger:notice("("  .. requester .. ") runs " .. self.scriptname .. ".entry(" .. M.parameters( ... ) .. ")" )
    local status, return1, return2 = pcall(self.scripthandle.entry, runtime, ...)
    if not status or not return1 then
       runtime.logger:error(self.scriptname .. ".entry(" .. M.parameters( ... ) .. ") throws error :" .. tostring(return1) )
       runtime.logger:error("stopped due error in script" .. self.scriptname)
       assert(false)
    end
    return return1, return2
end

function Script:poll( requester, runtime, ... )
    runtime.logger:notice("("  .. requester .. ") runs " .. self.scriptname .. ".check(" .. M.parameters( ... ) .. ")" )
    local status, return1, return2 = pcall(self.scripthandle.check, runtime, ...)
    if not status then
       runtime.logger:error(self.scriptname .. ".check(" .. M.parameters( ... ) .. ") throws error :" .. tostring(return1) )
       runtime.logger:error("stopped due error in script" .. self.scriptname)
       assert(false)
    end

    if not return1 then
       return1 = requester
    end

    return return1, return2
end

function Script:exit( requester, runtime, ... )
    runtime.logger:notice("("  .. requester .. ") runs " .. self.scriptname .. ".exit(" .. M.parameters( ... ) .. ")" )
    local status, return1 = pcall(self.scripthandle.exit, runtime, ...)
    if not status or not return1 then
       runtime.logger:error(self.scriptname .. ".exit(" .. M.parameters( ... ) .. ") throws error :" .. tostring(return1) )
       runtime.logger:error("stopped due error in script" .. self.scriptname)
       assert(false)
    end
    return return1
end

function M.parameters( ... )
    local parameters = ""
    if ( arg.n )  then
	for i,v in ipairs(arg) do
	    if ( i > 1 ) then
		parameters = parameters .. ","
	    end
	    parameters = parameters .. tostring(v)
	end
    end
    return parameters
end

-- loading a custo script, for some types of script additional tests can be enforced.
-- @param scriptname
-- @param runtime table
-- @param script_type is an optional string, currently supports: 'worker' (and nil)
function M.load(script, runtime, script_type)
    local self = {}
    local use_strict_set=false -- below some type of scripts enable this flag
    local f = loadfile(prefix .. script .. ".lua")
    if not f then
       runtime.logger:error("error in loading script(" .. prefix .. script .. ")")
       assert(false)
    end
    -- table forbidden maps invalid keys to the error message if they appear in SenseEventSet
    forbidden={}
    -- for now, we handle 'worker' scripts more strict.
    -- Later, we could cover more.
    if script_type=='worker' then
       forbidden=forbidden_worker_events -- use table defined above
       use_strict_set=true
    end

    self.scriptname=script
    self.scripthandle = f()
    setmetatable(self, Script)
    if use_strict_set then
       -- the new stricter implementation
       return self, set2(runtime,self.scripthandle.SenseEventSet,forbidden)
    else
       -- we assume many script rely upon this original (lenient) implementation
       return self, set(self.scripthandle.SenseEventSet)
    end
end

function M.initmode_save(x, mode)
    local config = "wansensing"
    x:load(config)
    x:set(config, "global", "initmode", mode)
    x:commit(config)
end

function M.l2type_save(x, l2type)
    local config = "wansensing"
    x:load(config)
    x:set(config, "global", "l2type", l2type)
    x:commit(config)
end

function M.l2type_get(x)
    local config = "wansensing"
    x:load(config)
    return x:get(config, "global", "l2type")
end

function M.l3type_save(x, l3type)
    local config = "wansensing"
    x:load(config)
    x:set(config, "global", "l3type", l3type)
    x:commit(config)
end

function M.l3type_get(x)
    local config = "wansensing"
    x:load(config)
    return x:get(config, "global", "l3type")
end

function M.open_state(uci)
   local config = "wansensing"
   local x = uci.cursor(UCI_CONFIG, "/var/state")
   x:load(config)
   x:revert("wansensing", "state")
   x:set("wansensing", "state", "state")
   x:save("wansensing")

end

function M.set_state(uci, state)
   local config = "wansensing"
   local x = uci.cursor(UCI_CONFIG, "/var/state")

   x:load(config)
   x:revert("wansensing", "state", "currState")
   x:set("wansensing", "state", "currState", state)
   x:save("wansensing")
end

return M
