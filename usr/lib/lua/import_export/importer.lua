
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local setmetatable = setmetatable
local error = error
local getfenv = getfenv
local setfenv = setfenv
local type = type
local pcall = pcall

local Importer = {}
Importer.__index = Importer

local function skip_this_section(section)
  section['.skip'] = true
end

local function wrap_section(section)
  local mt = {}
  function mt.__index(_, key)
    return section[key]
  end
  function mt.__newindex(_, key, value)
    if not key:match("^%.") then
      section[key] = value
    else
      error("field "..key.." is read only")
    end
  end
  return setmetatable({}, mt)
end

local function call_convert(convert, section)
  local old_env = getfenv(convert)
  local env = {
    __index = old_env;
    skip = function()
      section['.skip'] = true
    end,
    rename = function(newname)
      if type(newname)~="string" then
        error("section name must be a string")
      end
      if newname~="" then
        section['.name'] = newname
        section['.anonymous'] = false
      end
    end,
    keepOptions = function(...)
      local keep = {}
      for _, option in ipairs{...} do
        keep[option] = true
      end
      for option in pairs(section) do
        if not option:match("^%.") and not keep[option] then
          section[option] = nil
        end
      end
    end,
  }
  setmetatable(env, env)
  setfenv(convert, env)
  local ok, err = pcall(convert, wrap_section(section))
  setfenv(convert, old_env)
  if not ok then
    error(err)
  end
end

local function convert_this_section(section, converter)
  section['.clear'] = converter.clear_existing
  if not converter.convert then
    -- no special conversion is needed.
    -- this section will be copied as is, because a definition for
    -- it was found in the conversion file
    return
  end
  call_convert(converter.convert, section)
end

local function remember_list_to_clear(self, packname, converter)
  local sectiontype = converter['.sectiontype']
  if not sectiontype then
    -- clear_list only has effect with sectiontypes
    return
  end
  if not converter.clear_list then
    return
  end
  local pack = self._lists_to_clear[packname] or {}
  pack[sectiontype] = true
  self._lists_to_clear[packname] = pack
end

local function convert_section(self, packname, section)
  local converter = self._convdef:find_section(packname, section)
  if converter then
    remember_list_to_clear(self, packname, converter)
    convert_this_section(section, converter)
  else
    skip_this_section(section)
  end
end

local function make_sure_named_section_exists(uci, packname, section)
  if not uci:get(packname, section['.name']) then
    uci:set(packname, section['.name'], section['.type'])
  end
end

local function load_unnamed_list_names(uci, packname, sectiontype)
  local names = {}
  uci:foreach(packname, sectiontype, function(s)
    if s['.anonymous'] then
      names[#names+1] = s ['.name']
    end
  end)
  return names
end

local function make_sure_unnamed_section_exists(uci, packname, section)
  local index = tonumber(section['.name']:match("^@.*%[(%d+)%]$")) or -1
  local sectiontype = section['.type']
  local sections = load_unnamed_list_names(uci, packname, sectiontype)
  local name = sections[index+1] --index is zero based
  if not name then
    name = uci:add(packname, sectiontype)
  end
  section['.name'] = name
end

local function make_sure_section_exists(uci, packname, section)
  if section['.anonymous'] then
    make_sure_unnamed_section_exists(uci, packname, section)
  else
    make_sure_named_section_exists(uci, packname, section)
  end
end

local function save_section_options(uci, packname, section)
  for option, value in pairs(section) do
    if not option:match("^%.") then
      -- normal option
      uci:set(packname, section['.name'], option, value)
    end
  end
end

local function clear_section_if_required(uci, packname, section)
  if not section['.clear'] then
    return
  end
  local sectionname = section['.name']
  local data = uci:get_all(packname, sectionname)
  for option in pairs(data) do
    if not option:match("^%.") then
      uci:delete(packname, sectionname, option)
    end
  end
end

local function save_section(self, uci, packname, section)
  if section['.skip'] then
    return
  end
  make_sure_section_exists(uci, packname, section)
  clear_section_if_required(uci, packname, section)
  save_section_options(uci, packname, section)
end

local function convert_all_sections(self, data)
  for _, packname in ipairs(data) do
    local package = data[packname]
    for _, section in ipairs(package) do
      convert_section(self, packname, section)
    end
  end
end

local function clear_package_if_requested(self, uci, packname)
  local packdef = self._convdef:find_config(packname)
  if not (packdef and packdef.clear_existing) then
    return
  end
  local sections_to_delete = {}
  uci:foreach(packname, function(s)
    sections_to_delete[#sections_to_delete+1] = s['.name']
  end)
  for _, section in ipairs(sections_to_delete) do
    uci:delete(packname, section)
  end
end

local function save_package(self, uci, packname, package)
  uci:ensure_config_file(packname)
  clear_package_if_requested(self, uci, packname)
  for _, section in ipairs(package) do
    save_section(self, uci, packname, section)
  end
  uci:commit(packname)
end

local function clear_list(uci, packname, typename)
  local to_delete = {}
  uci:foreach(packname, typename, function(s)
    to_delete[#to_delete+1] = s['.name']
  end)
  for _, section in ipairs(to_delete) do
    uci:delete(packname, section)
  end
end

local function clear_lists(self, uci)
  for packname, typenames in pairs(self._lists_to_clear) do
    for typename in pairs(typenames) do
      clear_list(uci, packname, typename)
    end
  end
  self._lists_to_clear = {}
end

local function save_all_sections(self, uci, data)
  clear_lists(self, uci)
  for _, packname in ipairs(data) do
    save_package(self, uci, packname, data[packname])
  end
end

local function reset_import(self)
  self._lists_to_clear = {}
end

local function run_import(self, uci, data)
  reset_import(self)
  convert_all_sections(self, data)
  save_all_sections(self, uci, data)
end

function Importer:import(uci, data)
  local ok, errmsg = pcall(run_import, self, uci, data)
  if not ok then
    return nil, errmsg
  end
  return true
end

return function(convdef)
  return setmetatable({
    _convdef = convdef
  }, Importer)
end
