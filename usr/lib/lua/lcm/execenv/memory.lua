local popen = io.popen

local MemoryEE = { 
  specs = {
    name = "memory",
    vendor = "technicolor",
    version = "1.0"
  }
}
MemoryEE.__index = MemoryEE

local pkg_file = "/tmp/memory_packages"
local pkg_repo_fd = io.open(pkg_file, "r")
local packages = {}
if pkg_repo_fd then
  for line in pkg_repo_fd:lines() do
    local pkg_ID, pkg_name, pkg_version = line:match("^(.+)=(.+)|(.+)$")
    packages[pkg_ID] = {ID = pkg_ID, name = pkg_name, version =  pkg_version}
  end
end

local function execute_cmd(full_cmd)
  local f = popen(full_cmd)
  local res = {}
  for line in f:lines() do
    res[#res + 1] = line
  end
  f:close()
  if #res == 1 then
    return res[1]
  end
  return res
end

local function calculate_version(URL)
  local cmd = "echo " .. URL .. " | sha256sum"
  local sha256sum = execute_cmd(cmd)
  return sha256sum:sub(1, 5)
end

local function retrieve_info_from_URL(URL)
  local name, version
  if URL and URL:match("/([^/]+)%-([^/]+)$") then
    name, version = URL:match("/([^/]+)%-([^/]+)$")
  else
    name = URL:match("([^/]+)$")
    version = calculate_version(URL)
  end
  return name, version
end

function MemoryEE:list()
  local array = {}
  for _, pkg in pairs(packages) do
    array[#array + 1] = pkg
  end
  return array
end

function MemoryEE:install(pkg)
  -- Duplicate package detection is mandatory
  for _, installed_pkg in pairs(packages) do
    if installed_pkg.name and installed_pkg.name == pkg.name and
       installed_pkg.version and installed_pkg.version == pkg.version then
      return nil, "Duplicate entry detected"
    end
  end
  packages[pkg.ID] = pkg
  pkg_repo_fd = io.open(pkg_file, "w")
  for pkg_ID, pack in pairs(packages) do
    pkg_repo_fd:write(pkg_ID.."="..pack.name.."|"..pack.version.."\n")
  end
  pkg_repo_fd:close()
end

function MemoryEE:start(pkg)
end

function MemoryEE:stop(pkg)
end

function MemoryEE:uninstall(pkg)
  packages[pkg.ID] = nil
  pkg_repo_fd = io.open(pkg_file, "w")
  for pkg_ID, pack in pairs(packages) do
    pkg_repo_fd:write(pkg_ID.."="..pack.name.."|"..pack.version.."\n")
  end
  pkg_repo_fd:close()
end

function MemoryEE:inspect(pkg)
  -- Try to return a deterministic name and version based on the URL.
  local name, version = retrieve_info_from_URL(pkg.URL)
  return { name = name, version = version }
end

local M = {}

function M.init()
  return setmetatable({}, MemoryEE)
end

return M