
local M = {}

local function new_package()
  return {}
end

local function retrieve_package(packages, package)
  if not packages[package] then
    packages[#packages+1] = package
    packages[package] = new_package()
  end
  return packages[package]
end


local function create_section(packages, line)
  local package_name, name, sectype = line:match("^%s*([^.%s]+)%.([^.%s]+)=(%S+)")
  if not package_name then
    return false
  end
  local section = {
    ['.type'] = sectype,
    ['.name'] = name,
    ['.anonymous'] = name:match("^@")~=nil,
  }
  local package = retrieve_package(packages, package_name)
  if not package[name] then
    package[name] = section
    package[#package+1] = section
  end
  return true
end

local function sanitize_option_value(s)
  return s:match("^%s*'(.*)'%s*$") or s
end

local function retrieve_list_option_value(s)
  local list = {}
  for item in s:gmatch("'([^']*)'") do
    list[#list+1] = item
  end
  return list
end

local function retrieve_option_value(s)
  local list = s:match("^%s*{(.*)}%s*$")
  if list then
    return retrieve_list_option_value(list)
  else
    return sanitize_option_value(s)
  end
end

local function create_option(packages, line)
  local package_name, name, option, value = line:match("^%s*([^.%s]+)%.([^.%s]+)%.([^=%s]+)=(.*)$")
  if not package_name then
    return false
  end
  local package = retrieve_package(packages, package_name)
  local section = package[name]
  if section then
    section[option] =retrieve_option_value(value)
    return true
  end
  return false
end

local function process_set(packages, line)
  if create_section(packages, line) then
    return true
  end
  return create_option(packages, line)
end

local function process_package(packages, line)
  local package = line:match("^%s*%[([^[]+)%]%s*$")
  if not package then return
    false
  end
  if package~="*" then
    retrieve_package(packages, package)
  end
  return true
end

local function process_data_line(packages, line)
  if line:match("^%s*$") then
    return true
  end
  if process_package(packages, line) then
    return true
  end
  if process_set(packages, line) then
    return true
  end
  -- did not know how to handle
  return false
end

function M.load(rawdata)
  local packages = {}
  for line in rawdata:gmatch("([^\n]+)") do
    if not process_data_line(packages, line) then
      return nil, "failed to handle: "..line
    end
  end
  return packages
end

return M
