local require = require
local type = type
local error = error
local loadfile = loadfile
local setfenv = setfenv
local setmetatable = setmetatable
local pcall = pcall
local pairs = pairs
local tostring = tostring
local find = string.find
local format = string.format
local untaint = string.untaint
local ngx = ngx
local untaint_mt = require("web.taint").untaint_mt
local lfs = require("lfs")
local json = require("dkjson")

local mappings = {}
setmetatable(mappings, untaint_mt)

-- check a whole bunch of properties of a mapping and throw an
-- error if we find something wrong with it.
-- @return
--   true if the mapping validated
--   nil + reason otherwise.
local function validate_mapping(mapping)
  local name = mapping.name
  if type(name) ~= "string" then
    return nil, "Service name not a string"
  end
  local command = mapping.command
  if command and type(command) ~= "string" then
    return nil, "Command not a string"
  end
  local get = mapping.get
  local type_get = type(get)
  if get and (type_get~="table" and type_get~="function") then
    return nil, "Get must be a table or function if supplied"
  end
  local set = mapping.set
  if set and type(set)~='function' then
    return nil, "Set must be a function if supplied"
  end
  return true
end

local function create_map_env()
  -- The environment available to a mapping.
  -- All these functions can throw an error.
  local function register(mapping)
    local ok, reason = validate_mapping(mapping)
    if ok then
      local key = mapping.name
      if mapping.command then
        key = format("%s_%s", key, mapping.command)
      end
      mappings[key] = mapping
    else
      ngx.log(ngx.INFO, reason)
    end
  end
  local map_env = {
    register = register,
  }
  -- in your map you can access everything but you're
  -- not allowed to create new global variables
  setmetatable(map_env, {
    __index = _G,
    __newindex = function()
      error("global variables are evil", 2)
    end
  })
  return map_env
end

-- Load the map pointed to by 'file' using the provided environment.
local function load_map(map_env, file)
  local mapping, errmsg = loadfile(file)
  if not mapping then
    -- file not found or syntax error in map
    return nil, errmsg
  end
  setfenv(mapping, map_env)
  local rc, errormsg = pcall(mapping)
  if not rc then
    -- map didn't load; probably because it didn't validate
    return nil, errormsg
  end
  return true
end

-- Load all the maps on the specified path recursively and store them in
-- the provided map environment.
local function load_maps_recursively(map_env, mappath)
  -- if 'mappath' points to a file then load that file
  if lfs.attributes(mappath, 'mode') == 'file' then
    -- only consider files with the '.wat' extension
    if find(mappath, "%.wat$") then
      local rc, errormsg = load_map(map_env, mappath)
      -- currently we just ignore maps that fail to load
      if not rc then
        ngx.log(ngx.ERR, format("%s ignored (%s) ", mappath, errormsg))
      end
    end
    -- if 'mappath' points to a directory load it recursively
  elseif lfs.attributes(mappath, 'mode') == 'directory' then
    for file in lfs.dir(mappath) do
      if file ~= "." and file ~= ".." then
        load_maps_recursively(map_env, mappath.."/"..file)
      end
    end
  end
end

-- Load all the maps in 'mappath' and store them in mappings.
local function load_all_maps(mappath)
  local map_env = create_map_env()
  -- a single mapping file is provided
  if lfs.attributes(mappath, 'mode') == 'file' then
    local rc, errmsg = load_map(map_env, mappath)
    if not rc then
      return nil, errmsg
    end
    -- a directory with mapping files is provided
  else
    load_maps_recursively(map_env, mappath)
  end
  return true
end

local function do_get(map, uri)
  local get = map.get
  local data = {}
  if type(get) == "function" then
    local rc, res = pcall(get, uri)
    if not rc or type(res)~="table" then
      return nil, "Get function must return a table"
    end
    get = res
  end

  for k,v in pairs(get) do
    if type(v) == "function" then
      local rc, res = pcall(v, uri)
      if rc then
        data[k] = res
      else
        return nil, format("Can't get the parameter %s, error is %s", k, res)
      end
    else
      data[k] = v
    end
  end
  return true, data
end

local function do_set(map, uri)
  local rc, ok, reason = pcall(map.set, uri)
  if not rc or not ok then
    return nil, reason or "Call set function failed"
  else
    return true
  end
end

-- Deal with /status.cgi GET/SET request
-- @param
--   [table] uri: the request uri parameter's table
-- @return
--   true + json encoded content if the action successed,
--   nil + reason otherwise.
local function do_getset(uri)
  local headers = ngx.req.get_headers()
  local session = ngx.ctx.session
  if type(uri) ~= "table" then
    return nil, "Ignoring imporper service"
  end
  local name = uri.nvget or uri.service
  local key = name
  if uri.cmd then
    key = format("%s_%s", name, uri.cmd)
  end
  local map = mappings[key]
  if not map then
    return nil, "The service isn't registered"
  end
  local status = {}
  local seturi = {}
  local setflag = false
  for k,v in pairs(uri) do
    if k ~= "act" and k ~= "service" and k ~= "_" and k ~= "cmd" and k ~= "nvget" then
      seturi[k] = v
      setflag = true
    end
    if k == "act" and v == "nvset" and (session and session:checkXSRFtoken(headers['X-XSRF-TOKEN']) or true) then
      setflag = true
    end
  end

  if setflag then
    if not map.set then
      return nil, "The set action not be defined"
    end
    local rc, res = do_set(map, seturi)
    if not rc then
      return rc, res
    end
  end

  if map.get then
    local rc, res = do_get(map, seturi)
    if not rc then
      return rc, res
    end
    status[untaint(name)] = res
  elseif setflag then
    status.nvset = "ok"
  else
    return nil, "Invalid service request"
  end

  return true, status
end

local function authenticated(uri)
  local session = ngx.ctx.session
  return not session or (session and session:retrieve("loginflag") == "1") or uri.cmd
end

local M = {}

-- Initialize status service and load all the maps to store them to 'mappings' table
-- @param
--   [string] mappath: The location where to read the maps from. It can be one file
--             or a directory with map files. In the latter case it will only
--             load files ending with ".wat".
function M.init(mappath)
  if not mappath then
    ngx.log(ngx.ERR, "No mappath defined")
  else
    local rc, errmsg = load_all_maps(mappath)
    if not rc then
      ngx.log(ngx.ERR, errmsg)
    end
  end
end

-- Take action for the service invoked by request /status.cgi?
-- @param
--   [table] uri: the request parameter's table by URL /status.cgi?key1=val1&...
function M.action(uri)
  if authenticated(uri) then
    local rc, res = do_getset(uri)
    if rc then
      -- response json encoded content
      ngx.print(json.encode(res, {indent=true}))
    else
      ngx.log(ngx.ERR, res)
      ngx.exit(404)
    end
  else
    ngx.exit(ngx.HTTP_FORBIDDEN)
  end
end

return M
