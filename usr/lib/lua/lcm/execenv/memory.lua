local popen = io.popen

local MemoryEE = {}
MemoryEE.__index = MemoryEE

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
  for _, pkg in pairs(self.packages) do
    array[#array + 1] = pkg
  end
  return array
end

function MemoryEE:install(pkg)
  -- Duplicate package detection is mandatory
  for _, installed_pkg in pairs(self.packages) do
    if installed_pkg.name and installed_pkg.name == pkg.name and
       installed_pkg.version and installed_pkg.version == pkg.version then
      return nil, "Duplicate entry detected"
    end
  end
  self.packages[pkg.ID] = pkg
  local pkg_repo_fd = io.open(self.pkg_file, "w")
  for pkg_ID, pack in pairs(self.packages) do
    pkg_repo_fd:write(pkg_ID.."="..pack.name.."|"..pack.version.."\n")
  end
  pkg_repo_fd:close()
end

function MemoryEE:start()
end

function MemoryEE:stop()
end

function MemoryEE:executing()
end

function MemoryEE:uninstall(pkg)
  self.packages[pkg.ID] = nil
  local pkg_repo_fd = io.open(self.pkg_file, "w")
  for pkg_ID, pack in pairs(self.packages) do
    pkg_repo_fd:write(pkg_ID.."="..pack.name.."|"..pack.version.."\n")
  end
  pkg_repo_fd:close()
end

function MemoryEE:inspect(pkg)
  -- Try to return a deterministic name and version based on the URL.
  local name, version = retrieve_info_from_URL(pkg.URL)
  return { name = name, version = version }
end

function MemoryEE:notify(pkg)
  local logger = require("tch.logger")
  local log = logger.new("memory", 6)
  for k,v in pairs(pkg) do
    log:debug("%s = %s", tostring(k), tostring(v))
  end
end

local M = {}

function M.init(config, ee_type)
  local self = {
    specs = {
      name = config[".name"],
      type = ee_type,
      vendor = "technicolor",
      version = "1.0",
    },
    pkg_file = "/tmp/memory_"..config[".name"].."_packages",
    packages = {},
  }
  local pkg_repo_fd = io.open(self.pkg_file, "r")
  if pkg_repo_fd then
    for line in pkg_repo_fd:lines() do
      local pkg_ID, pkg_name, pkg_version = line:match("^(.+)=(.+)|(.+)$")
      self.packages[pkg_ID] = {ID = pkg_ID, name = pkg_name, version =  pkg_version}
    end
    pkg_repo_fd:close()
  end
  return setmetatable(self, MemoryEE)
end

return M