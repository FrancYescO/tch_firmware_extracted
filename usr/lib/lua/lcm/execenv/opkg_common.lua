--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2018 -          Technicolor Delivery Technologies, SAS **
** - All Rights Reserved                                                **
** Technicolor hereby informs you that certain portions                 **
** of this software module and/or Work are owned by Technicolor         **
** and/or its software providers.                                       **
** Distribution copying and modification of all such work are reserved  **
** to Technicolor and/or its affiliates, and are not permitted without  **
** express written authorization from Technicolor.                      **
** Technicolor is registered trademark and trade name of Technicolor,   **
** and shall not be used in any manner without express written          **
** authorization from Technicolor                                       **
*************************************************************************/
--]]

local io = require 'io'

local type, ipairs, setmetatable, tonumber = type, ipairs, setmetatable, tonumber
local match, format = string.match, string.format
local rename = os.rename
local popen = require("tch.process").popen
local ipk = require("lcm.execenv.native.ipk")
local opkg_module = require("lcm.execenv.native.opkg")
local attribs = require("lfs").attributes
local ubus = require("lcm.ubus")
local errcodes = require("lcm.errorcodes")
local execmon = require("lcm.execenv.native.execmon")

local Opkg_EE_wrapper = {}
Opkg_EE_wrapper.__index = Opkg_EE_wrapper

local function initscript(self, pkg_name)
  if not pkg_name then
    return
  end
  local init_script = self.rootfs .. "etc/init.d/" .. pkg_name
  local script_file = self.env:nativePath(init_script)
  if not attribs(script_file, "ino") then
    return
  end
  return init_script, script_file
end

local function run_initscript(self, name, action)
  -- Check if there's an init script; if not we assume the package is
  -- not a daemon but some other resource (library, script, web content, ...).
  -- For those we pretend start/stop succeeds to be in line with TR-069.
  local init_script = initscript(self, name)
  if not init_script then
    return true
  end
  local exec_path, argv = self.env:exec_args(init_script, {action})
  local output = popen(exec_path, argv, "r")
  local init_output, rc
  if output then
    init_output = output:read("*a")
    rc = output:close()
  end
  if not rc or not tonumber(rc) or tonumber(rc) > 0 then
    return nil, format("initscript failed for %s (action=%s): %s", name, action,
                       (init_output or "(no error message)"))
  end
end

local function translate_package(self, opkg_package)
  opkg_package.name = opkg_package.Package
  opkg_package.Package = nil
  if opkg_package.Maintainer then
    opkg_package.vendor = opkg_package.Maintainer:match("^%s*([^<]-)%s*<")
    opkg_package.Maintainer = nil
  end
  if not opkg_package.vendor then
    -- In case there is no Maintainer specified or the specification deviates from the Debian control file requirements, default to Technicolor.
    opkg_package.vendor = "Technicolor"
  end
  opkg_package.version = opkg_package.Version
  opkg_package.Version = nil
  local _, err = run_initscript(self, opkg_package.name, "enabled")
  if err then
    opkg_package.autostart="0"
  else
    opkg_package.autostart="1"
  end
end

function Opkg_EE_wrapper:list()
  local package_list = self.opkg:list()
  local list = {}
  for _, opkg_package in ipairs(package_list) do
    if not self.env:nativeEssential(opkg_package) then
      opkg_package.execenv = self.specs.name
      translate_package(self, opkg_package)
      list[#list + 1] = opkg_package
    end
  end
  return list
end

local function verify_package(ipk_pkg, ee_name)
  if not ipk_pkg then
    return nil, "No package found"
  end
  return ipk_pkg:verify(ee_name)
end

local function verified_package(pkg_file, ee_name)
  local ipk_pkg = ipk.new(pkg_file)
  local verified, verification_error = verify_package(ipk_pkg, ee_name)
  if not verified then
    return nil, "Package failed verification: "..(verification_error or "<unkown reason>")
  end
  return ipk_pkg
end

function Opkg_EE_wrapper:install(pkg)
  if not pkg or not pkg.downloadfile or not pkg.ID or not pkg.version or not pkg.name then
    return nil, errcodes.INTERNAL_ERROR, "Malformed package provided to install"
  end
  -- for opkg a file must end with .ipk before it will install it...
  local downloadfile = pkg.downloadfile
  if not match(downloadfile, "%.ipk$") then
    downloadfile = downloadfile .. ".ipk"
    local ok, errmsg = rename(pkg.downloadfile, downloadfile)
    if ok then
      -- This rename needs to be communicated to the master.
      ubus.call("lcm", "modify_package", { ID = pkg.ID, properties = { downloadfile = downloadfile }})
    else
      return nil, errcodes.INSTALL_FAILED, "Failed to rename package: "..errmsg
    end
  end
  local ipk_pkg, errmsg = verified_package(downloadfile, self.specs.name)
  if not ipk_pkg then
    return nil, errcodes.UNVERIFIED_PKG, errmsg
  end
  if pkg.updated_name and pkg.updated_name ~= pkg.name then
    return nil, errcodes.UPDATE_NAME_CHANGED, "Trying to update with different package name"
  end
  if pkg.updated_version and pkg.updated_version == pkg.version then
    return nil, errcodes.DUPLICATE_PKG, "Trying to update to the same package version"
  end
  -- Perform duplicate package detection. Opkg will allow installation of a duplicate package, but we don't want this.
  local name = pkg.name
  local package_list = self.opkg:list()
  for _, opkg_package in ipairs(package_list) do
    if (opkg_package.Package == name) and not pkg.updated_name then
      return nil, errcodes.DUPLICATE_PKG, "Duplicate package detected"
    end
  end
  local success = self.opkg:install(ipk_pkg)
  if success then
    translate_package(self, ipk_pkg.opkg_package)
    return ipk_pkg.opkg_package
  end
  return nil, errcodes.INSTALL_FAILED, "Package installation failed"
end

local function unquote(v)
  local quoted, quoted_val = v:match("^(['\"])(.*)%1$")
  if quoted then
    return quoted_val
  end
  return v
end

local function resolve_pid_variables(self, path)
  path = path:gsub("%$LCM_INSTALL_ROOT", self.rootfs)
  path = path:gsub("%${LCM_INSTALL_ROOT}", self.rootfs)
  return path
end

local function load_pid_files(self, filename)
  local pid_files = {}
  for line in io.lines(filename) do
    local pid_file = line:match("^%s*[%w_]*PID_FILE=(.*)")
    if pid_file then
      pid_file = resolve_pid_variables(self, unquote(pid_file))
      pid_files[#pid_files+1] = self.env:nativePath(pid_file)
    end
  end
  return pid_files
end

local function package_pid_files(self, pkg)
  local _, init_script = initscript(self, pkg.name)
  if not init_script then
    return
  end
  return load_pid_files(self, init_script)
end

function Opkg_EE_wrapper:start(pkg)
  return run_initscript(self, pkg.name, "start")
end

function Opkg_EE_wrapper:stop(pkg)
  return run_initscript(self, pkg.name, "stop")
end

function Opkg_EE_wrapper:uninstall(pkg)
  return self.opkg:uninstall(pkg.name)
end

local monitors = setmetatable({}, {__mode="k"})
local function monitor_for(self, pkg)
  local m = monitors[pkg]
  if not m then
    m = execmon.ExecutionMonitor(self.env, package_pid_files(self, pkg))
    monitors[pkg] = m
  end
  return m
end

function Opkg_EE_wrapper:executing(pkg)
  local monitor = monitor_for(self, pkg)
  return monitor:executing(pkg:inRunningState())
end

function Opkg_EE_wrapper:inspect(pkg)
  local downloadfile = pkg.downloadfile
  local ipk_pkg, errmsg = verified_package(downloadfile, self.specs.name)
  if not ipk_pkg then
    return nil, errmsg
  end
  local name = ipk_pkg:query("Package")
  local version = ipk_pkg:query("Version")
  return { name = name, version = version }
end

function Opkg_EE_wrapper:notify(pkg)
  if tonumber(pkg.autostart) == 1 then
    return run_initscript(self, pkg.name, "enable")
  elseif tonumber(pkg.autostart) == 0 then
    return run_initscript(self, pkg.name, "disable")
  end
end

local M = {}

function M.init(config, ee_type, envType)
  if type(config) ~= "table" then
    return nil, "The config section should be a table"
  end
  if not config[".name"] then
    return nil, "The config section should be named"
  end
  if not config["rootfs"] then
    return nil, "An " .. ee_type .. " EE should have a rootfs directory"
  end
  local env = envType(ee_type, config['.name'])
  local opkg = opkg_module.new(config.rootfs, env)
  if not opkg then
    return nil, "Unable to load the opkg information present in "..ee_type ..
                " EE " .. config[".name"] .. " " .. config.rootfs
  end
  local self = {
    specs = {
      name = config[".name"],
      type = ee_type,
      vendor = "technicolor",
      version = "1.0",
      parent = config.parent,
    },
    rootfs = config.rootfs,
    opkg = opkg,
    env = env,
  }
  return setmetatable(self, Opkg_EE_wrapper)
end

return M
