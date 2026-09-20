local M = {}

local ubus
local lcmd_cache = {}
local lcmd_cache_date = 0

local function init(ubus_connection)
  ubus = ubus_connection
end

local function check_cache_expired()
  return os.time() > lcmd_cache_date + 5
end

local function check_cache()
  if check_cache_expired() then
    lcmd_cache.execenvs = nil
    lcmd_cache.packages = nil
    lcmd_cache = {}
  end
end

local function retrieve_EE(ee_name)
  check_cache()
  if not lcmd_cache.execenvs then
    local execenvs = ubus:call("lcm", "list_execenvs", {})
    if execenvs and execenvs.execenvs then
      local ees = {}
      for _, ee in pairs(execenvs.execenvs) do
        if ee.name then
          ees[ee.name] = ee
        end
      end
      lcmd_cache.execenvs = ees
      lcmd_cache_date = os.time()
    end
  end
  if not ee_name then
    return lcmd_cache.execenvs
  else
    return lcmd_cache.execenvs[ee_name]
  end
end

local function retrieve_EE_packages(ee_name)
  check_cache()
  if not lcmd_cache.packages then
    local list_packages = ubus:call("lcm", "list_packages", {})
    local packages = {}
    if list_packages and list_packages.packages then
      for _, package in pairs(list_packages.packages) do
        packages[package.ID] = package
        if package.execenv then
          local ee = retrieve_EE(package.execenv)
          if not ee.packages then
            ee.packages = {}
          end
          ee.packages[package.ID] = package
        end
      end
    end
    lcmd_cache.packages = packages
    lcmd_cache_date = os.time()
  end
  if not ee_name then
    return lcmd_cache.packages
  else
    local ee = retrieve_EE(ee_name)
    return ee.packages or {}
  end
end


M.init = init
M.retrieve_EE = retrieve_EE
M.retrieve_EE_packages = retrieve_EE_packages

return M
