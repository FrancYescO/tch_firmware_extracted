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

local type, ipairs, setmetatable = type, ipairs, setmetatable
local match, format = string.match, string.format
local rename = os.rename
local execv = require("tch.posix").execv
local ipk = require("lcm.execenv.native.ipk")
local opkg_module = require("lcm.execenv.native.opkg")
local attribs = require("lfs").attributes
local ubus = require("lcm.ubus")
local errcodes = require("lcm.errorcodes")

local Opkg_EE_wrapper = {}
Opkg_EE_wrapper.__index = Opkg_EE_wrapper

local function translate_package(opkg_package)
  opkg_package.name = opkg_package.Package
  opkg_package.Package = nil
  if opkg_package.Maintainer then
    opkg_package.vendor = opkg_package.Maintainer:match("^%s*([^<]-)%s*<")
    opkg_package.Maintainer = nil
  else
    opkg_package.vendor = "Technicolor"
  end
  opkg_package.version = opkg_package.Version
  opkg_package.Version = nil
end

function Opkg_EE_wrapper:list()
  local package_list = self.opkg:list()
  local list = {}
  for _, opkg_package in ipairs(package_list) do
    if not self.lxc_name or opkg_package.Essential ~= "yes" then
      opkg_package.execenv = self.specs.name
      translate_package(opkg_package)
      list[#list + 1] = opkg_package
    end
  end
  return list
end

function Opkg_EE_wrapper:install(pkg)
  if not pkg.downloadfile or not pkg.ID or not pkg.version or not pkg.name then
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
  local ipk_pkg = ipk.new(downloadfile)
  if not ipk_pkg or not ipk_pkg:verify() then
    return nil, errcodes.UNVERIFIED_PKG, "Package failed verification"
  end
  -- Perform duplicate package detection. Opkg will allow installation of a duplicate package, but we don't want this.
  local package_list = self.opkg:list()
  for _, opkg_package in ipairs(package_list) do
    if opkg_package.Version == pkg.version and opkg_package.Package == pkg.name then
      return nil, errcodes.DUPLICATE_PKG, "Duplicate package detected"
    end
  end
  local success = self.opkg:install(ipk_pkg)
  if success then
    translate_package(ipk_pkg.opkg_package)
    return ipk_pkg.opkg_package
  end
  return nil, errcodes.INSTALL_FAILED, "Package installation failed"
end

local function run_initscript(self, name, action)
  -- Check if there's an init script; if not we assume the package is
  -- not a daemon but some other resource (library, script, web content, ...).
  -- For those we pretend start/stop succeeds to be in line with TR-069.
  local init_script = self.rootfs .. "etc/init.d/" .. name
  if self.lxc_name then
    init_script = "/srv/lxc/" .. self.lxc_name .. "/rootfs" .. init_script
  end
  if not attribs(init_script, "ino") then
    return true
  end
  local exec_path, argv
  if self.lxc_name then
    exec_path = "/usr/bin/lxc-attach"
    argv = {
      "-n",
      self.lxc_name,
      "--",
      self.rootfs .. "etc/init.d/" .. name,
      action,
    }
  else
    exec_path = init_script
    argv = {
      action,
    }
  end
  local rc, errmsg = execv(exec_path, argv)
  if not rc then
    return nil, format("failed to invoke initscript for %s (action=%s): %s", name, action,
                       (errmsg or "(no error message)"))
  end
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

function Opkg_EE_wrapper:inspect(pkg)
  local downloadfile = pkg.downloadfile
  local ipk_pkg = ipk.new(downloadfile)
  if not ipk_pkg:verify() then
    return nil, "Package failed verification"
  end
  local name = ipk_pkg:query("Package")
  local version = ipk_pkg:query("Version")
  return { name = name, version = version }
end

local M = {}

function M.init(config, ee_type)
  if type(config) ~= "table" then
    return nil, "The config section should be a table"
  end
  if not config[".name"] then
    return nil, "The config section should be named"
  end
  if not config["rootfs"] then
    return nil, "An " .. ee_type .. " EE should have a rootfs directory"
  end
  local opkg = opkg_module.new(config.rootfs, ee_type == "lxc_opkg" and config[".name"])
  if not opkg then
    return nil, "Unable to load the opkg information present in " .. ee_type .." EE " .. config[".name"] .. " " .. config.rootfs
  end
  local self = {
    specs = {
      name = config[".name"],
      type = ee_type,
      vendor = "technicolor",
      version = "1.0",
    },
    rootfs = config.rootfs,
    opkg = opkg,
  }
  if ee_type == "lxc_opkg" then
    self.lxc_name = config[".name"] -- For now the config section name needs to match the container name used.
  end 
  return setmetatable(self, Opkg_EE_wrapper)
end

return M