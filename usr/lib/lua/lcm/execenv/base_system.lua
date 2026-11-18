--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2017 -          Technicolor Delivery Technologies, SAS **
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

local package = require("lcm.package")
local match, format = string.match, string.format
local rename = os.rename
local execv = require("tch.posix").execv
local ipk = require("lcm.execenv.native.ipk")
local opkg_module = require("lcm.execenv.native.opkg")
local opkg = opkg_module.new("/")
local attribs = require("lfs").attributes
--local ubus = require("lcm.ubus")

---------------------------------------------------------------------
local M = { specs = { name = "base_system", vendor = "technicolor", version = "1.0" }}
--TODO For demo purpose install/start/stop stays implemented, but these should be removed.

function M.list()
  local package_list = opkg:list()
  local list = {}
  for _, opkg_package in ipairs(package_list) do
    opkg_package.execenv = M.specs.name
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
    opkg_package.state = package.states.INSTALLED
    list[#list + 1] = package.new(opkg_package)
  end
  return list
end

-- this function is invoked in a child process
function M.install(pkg)
  -- for opkg a file must end with .ipk before it will install it...
  local downloadfile = pkg.downloadfile
  if not match(downloadfile, "%.ipk$") then
    downloadfile = downloadfile .. ".ipk"
    rename(pkg.downloadfile, downloadfile)
    -- TODO: this rename needs to be communicated to the master. One way is to
    -- invoke the lcm.modify_package() method but this appears to be unstable;
    -- probably because we're running in a forked child of the master.
    --ubus.call("lcm", "modify_package", { ID = pkg.ID, properties = { downloadfile = downloadfile }})
  end
  local ipk_pkg = ipk.new(downloadfile)
  if not ipk_pkg:verify() then
    return nil, "Package failed verification"
  end
  -- TODO: ideally we can inspect the file and at least derive name and
  -- version to add to the package metadata
  local rc, errmsg = opkg:install(ipk_pkg)
  if rc then
    -- TODO: for now remove the file ourselves
    os.remove(downloadfile)
  end
  return rc, errmsg
end

local function run_initscript(name, action)
  -- Check if there's an init script; if not we assume the package is
  -- not a daemon but some other resource (library, script, web content, ...).
  -- For those we pretend start/stop succeeds to be in line with TR-069.
  local init_script = "/etc/init.d/" .. name
  if not attribs(init_script, "ino") then
    return true
  end
  local rc, errmsg = execv(init_script, { action })
  if not rc then
    return nil, format("failed to invoke initscript for %s (action=%s): %s", name, action,
                       (errmsg or "(no error message)"))
  end
end

-- this function is invoked in a child process
function M.start(pkg)
  return run_initscript(pkg.name, "start")
end

-- this function is invoked in a child process
function M.stop(pkg)
  return run_initscript(pkg.name, "stop")
end

-- this function is invoked in a child process
function M.uninstall(pkg)
  return opkg:uninstall(pkg.name)
end

return M
