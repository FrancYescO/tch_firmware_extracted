
local pairs = pairs
local ipairs = ipairs
local loadfile = loadfile
local setfenv = setfenv
local xpcall = xpcall
local type = type
local setmetatable = setmetatable

local debug = debug

local M = {}

--- retrieve filename of conversion handler for the given version
-- @param uci a uci cursor
-- @string version the version to look for
-- @return a filename if found or nil if not
function M.locate(uci, version)
  local importer
  uci:foreach("system", "importversion", function(s)
    local accept = s.version_match
    if accept and version:match(accept) then
      importer = s.importer
      return false
    end
  end)
  return importer
end

local function traceback(err)
  local r = {
    msg = err,
    traceback = {},
  }
  local tb = debug.traceback(err, 2)
  for line in tb:gmatch("([^\n]+)") do
    r.traceback[#r.traceback+1] = line
  end
  return r
end

--- load the given conversion file
-- @string filename the name of the file to load
-- @param env the environment to execute the file in
-- @return the given env
-- @error error msg and traceback (a table with strings)
function M.load(filename, env)
  local f, err = loadfile(filename)
  if not f then
    return nil, err
  end
  setfenv(f, env)
  local ok, e = xpcall(f, traceback)
  if not ok then
    return nil, e.msg, e.traceback
  end
  return env
end

--- create an importer env.
--
-- This adds the `config`, `section` and `sectiontype` functions to
-- the environment.
-- @param convdef ConversionDef object
-- @param env the initial environment to be augmented (may be nil)
-- @return the env or nil if define_config is not a function
function M.importenv(convdef, env)
  if type(convdef)~="table" then
    return
  end
  env = env or {}

  env.config = function(packname)
    return function(packdef)
      return convdef:define_config(packname, packdef)
    end
  end

  env.section = function(sectionname)
    return function(secdef)
      return convdef:define_section(sectionname, secdef)
    end
  end

  env.sectiontype = function(sectiontype)
    return function(secdef)
      return convdef:define_sectiontype(sectiontype, secdef)
    end
  end

  return env
end

local ConversionDef = {}
ConversionDef.__index = ConversionDef

local function ConversionDef_new()
  return {
    _configs = {}
  }
end

local _sectionKinds = {
  section = ".sectionname",
  sectiontype = ".sectiontype"
}
local function sectionKind(t)
  if type(t)~="table" then
    return
  end
  for kind, field in pairs(_sectionKinds) do
    local v = t[field]
    if v then
      return kind, v
    end
  end
end

local function storeSectionDef(packdef, secdef)
  local kind, name = sectionKind(secdef)
  if kind=="section" then
    packdef._sections[name] = secdef
    return true
  elseif kind=="sectiontype" then
    packdef._types[name] = secdef
    return true
  end
  return false
end

local function createConfigDef(definition)
  local def = {
    _sections = {},
    _types = {},
  }
  for k, v in pairs(definition) do
    if not storeSectionDef(def, v) then
      def[k] = v
    end
  end
  return def
end

function ConversionDef:define_config(name, definition)
  self._configs[name] = createConfigDef(definition)
end

function ConversionDef:define_section(sectionname, secdef)
  secdef = secdef or {}
  secdef['.sectionname'] = sectionname
  secdef['.sectiontype'] = nil
  return secdef
end

function ConversionDef:define_sectiontype(sectiontype, secdef)
  secdef = secdef or {}
  secdef['.sectionname'] = nil
  secdef['.sectiontype'] = sectiontype
  return secdef
end

function ConversionDef:find_config(name)
  local config = self._configs[name]
  if not config then
    config = self._configs["*"]
  end
  return config
end

function ConversionDef:find_section(config_name, section)
  local config = self._configs[config_name]
  local sectiondef
  
  if config and not section['.anonymous'] then
    sectiondef = config._sections[section['.name']]
  end

  if config and not sectiondef then
    sectiondef = config._types[section['.type']]
  end
  
  if config and not sectiondef then
    sectiondef = config._sections["*"]
  end

  if not sectiondef then
    config = self._configs["*"]
    if config then
      sectiondef = config._sections["*"]
    end
  end
  
  return sectiondef
end

function M.ConversionDef()
  return setmetatable(ConversionDef_new(), ConversionDef)
end

return M
