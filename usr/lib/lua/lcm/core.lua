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

local execenv = require("lcm.execenv")
local Package = require("lcm.package")
local ipairs = ipairs
local pairs = pairs
local queue = require("lcm.queue").init()
local s_errorcodes = require("lcm.errorcodes")
local logger = require("tch.logger")

local M = {}

local function init_execenv(config, load_pkg)
  execenv.init(config)
  execenv.init = nil
  -- query each execenv for current package list and populate database
  for _, ee in ipairs(execenv.query()) do
    for _, ee_pkg in ipairs(ee:list()) do
      ee_pkg.execenv = ee.specs.name
      load_pkg(ee_pkg)
    end
    -- we don't need list() anymore
    ee.list = nil
  end
end

local function retrievePendingActions()
  local actions
  for _, pkg in ipairs(Package.query()) do
    actions = pkg:pending_actions(actions)
  end
  return actions or {}
end

local function init_package(config)
  Package.init(config)
  local pending = retrievePendingActions()
  queue:loadInitialActions(pending)
  return Package.load
end

function M.init(config)
  local pkg_loader = init_package(config)
  init_execenv(config, pkg_loader)
  logger:debug("Finished LCMd initialization")
end

local expected_arguments = {
  list_execenvs = {
    name = true,
  },
  list_packages = {
    properties = true,
  },
  modify_package = {
    ID = true,
    properties = true,
  },
  install = {
    URL = true,
    execenv = true,
    username = true,
    password = true,
  },
  start = {
    properties = true,
  },
  stop = {
    properties = true,
  },
  uninstall = {
    properties = true,
  },
  delete = {
    properties = true,
  },
}

-- We explicitly check no invalid arguments are specified. Since our default behaviour usually
-- results in an action being performed on all packages, we introduce an extra layer of caution
-- by checking no unexpected arguments are given to our API. The presence of an unexpected argument
-- then results in no action being performed, forming an additional safeguard for our LCM operations.
local function check_no_invalid_arguments(method, params)
  for arg in pairs(params) do
    if not expected_arguments[method][arg] then
      error("Invalid argument")
    end
  end
end

function M.list_execenvs(params)
  check_no_invalid_arguments("list_execenvs", params)
  local name = params.name
  if name then
    local ee = execenv.query(name)
    return { ee and ee.specs }
  end
  local execenvs = {}
  for _, ee in ipairs(execenv.query()) do
    execenvs[#execenvs + 1] = ee.specs
  end
  return execenvs
end

local function public_properties_only(pkg)
  local pub = {}
  for prop, value in pairs(pkg) do
    if not prop:match("^_") then
      pub[prop] = value
    end
  end
  return pub
end

local function list_packages(params)
  return Package.query(params)
end

local function update_pkg_execution_state(pkg)
  local pkg_execenv = execenv.query(pkg.execenv)
  if pkg_execenv then
    pkg:update_execution_state(pkg_execenv)
  end
end

function M.update_execution_states()
  for _, pkg in ipairs(list_packages()) do
    update_pkg_execution_state(pkg)
  end
end


function M.list_packages(params)
  check_no_invalid_arguments("list_packages", params)
  local packages = {}
  for _, pkg in ipairs(list_packages(params.properties)) do
    packages[#packages+1] = public_properties_only(pkg)
  end
  return packages
end

function M.modify_package(params)
  check_no_invalid_arguments("modify_package", params)
  local ID = params.ID
  if not ID then
    return nil, s_errorcodes.INVALID_ARGUMENT, "no ID provided"
  end
  local properties = params.properties
  if not properties then
    return nil, s_errorcodes.INVALID_ARGUMENT, "no properties provided"
  end
  local pkgs = list_packages({ ID = ID })
  if #pkgs == 0 then
    return nil, s_errorcodes.INVALID_ARGUMENT, "unrecognized ID"
  end
  local ok = pkgs[1]:modify(params.properties)
  if ok then
    queue:addNotification(pkgs[1])
  end
  return ok
end

local function execenv_exists(name)
  if name then
    return execenv.query(name)
  end
end

local function check_for_install_arg_errors(params)
  if not execenv_exists(params.execenv) then
    return s_errorcodes.INVALID_ARGUMENT, "invalid execution environment"
  end
  if not params.URL then
    return s_errorcodes.INVALID_ARGUMENT, "no URL"
  end
  -- if one of username or password is given then
  -- so must the other
  local username = params.username
  local password = params.password
  if username and not password then
    return s_errorcodes.INVALID_ARGUMENT, "username provided but no password"
  end
  if password and not username then
    return s_errorcodes.INVALID_ARGUMENT, "password provided but no username"
  end
end

function M.install(params)
  check_no_invalid_arguments("install", params)
  local err, msg = check_for_install_arg_errors(params)
  if err then
    return nil, err, msg
  end

  -- create new package
  local pkg = Package.new{
    execenv = params.execenv,
    URL = params. URL,
    username = params.username,
    password = params.password
  }

  -- add to queue and return ID for further tracking
  local operationID, errorcode, errormsg = queue:add({ pkg }, "installed")
  if not operationID then
    pkg:remove()
    return nil, errorcode, errormsg
  end
  return pkg.ID, operationID
end

local function execute(params, action)
  local result = {}
  local pkgs = list_packages(params.properties)
  if #pkgs == 0 then
    return result
  end
  local operationID, errorcode, errormsg = queue:add(pkgs, action)
  if not operationID then
    return nil, errorcode, errormsg
  end
  for _, pkg in ipairs(pkgs) do
    result[#result + 1] = { ID = pkg.ID, errorcode = errorcode, errormsg = errormsg }
  end
  return result, operationID
end

function M.start(params)
  check_no_invalid_arguments("start", params)
  return execute(params, "running")
end

function M.stop(params)
  check_no_invalid_arguments("stop", params)
  return execute(params, "installed")
end

function M.uninstall(params)
  check_no_invalid_arguments("uninstall", params)
  return execute(params, "retired")
end

function M.delete(params)
  check_no_invalid_arguments("delete", params)
  return execute(params, "gone")
end

return M
