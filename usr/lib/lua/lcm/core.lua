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
local db = require("lcm.db")
local package = require("lcm.package")
local queue = require("lcm.queue")
local ipairs = ipairs

local s_errorcodes = require("lcm.errorcodes")
local s_pkg_states = package.states

-- query each execenv for current package list and populate database
for _, ee in ipairs(execenv.query()) do
  for _, pkg in ipairs(ee.list()) do
    db.add(pkg)
  end
  -- we don't need list() anymore
  -- TODO: for now I need it to figure out which package was added...
  --ee.list = nil
end

---------------------------------------------------------------------
local M = {}

function M.list_execenvs(params)
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

function M.list_packages(params)
  return db.query(params.properties)
end

function M.modify_package(params)
  local ID = params.ID
  if not ID then
    return nil, s_errorcodes.INVALID_ARGUMENT, "no ID provided"
  end
  local properties = params.properties
  if not properties then
    return nil, s_errorcodes.INVALID_ARGUMENT, "no properties provided"
  end
  local pkgs = db.query({ ID = ID })
  if #pkgs == 0 then
    return nil, s_errorcodes.INVALID_ARGUMENT, "unrecognized ID"
  end
  return pkgs[1]:modify(params.properties)
end

function M.install(params)
  -- check params
  -- execenv and URL are mandatory
  local execenv_name = params.execenv
  local ee = execenv.query(execenv_name)
  if not execenv_name or not ee then
    return nil, s_errorcodes.INVALID_ARGUMENT, "invalid execution environment"
  end
  local URL = params.URL
  if not URL then
    return nil, s_errorcodes.INVALID_ARGUMENT, "no URL"
  end
  -- if one of username or password is given then
  -- so must the other
  local username = params.username
  local password = params.password
  if username and not password then
    return nil, s_errorcodes.INVALID_ARGUMENT, "username provided but no password"
  end
  if password and not username then
    return nil, s_errorcodes.INVALID_ARGUMENT, "password provided but no username"
  end
  -- create new db entry
  local pkg = package.new({ execenv = execenv_name, URL = URL, username = username,
                            password = password, state = s_pkg_states.NEW })
  local ID = db.add(pkg)
  -- add to queue and return IdD for further tracking
  local operationID, errorcode, errormsg = queue.add({ pkg }, "download_and_install")
  if not operationID then
    return nil, errorcode, errormsg
  end
  return ID, operationID
end

local function execute(params, action)
  local result = {}
  local pkgs = db.query(params.properties)
  if #pkgs == 0 then
    return result
  end
  local operationID, errorcode, errormsg = queue.add(pkgs, action)
  for _, pkg in ipairs(pkgs) do
    result[#result + 1] = { ID = pkg.ID, errorcode = errorcode, errormsg = errormsg }
  end
  return result, operationID
end

function M.start(params)
  return execute(params, "start")
end

function M.stop(params)
  return execute(params, "stop")
end

function M.uninstall(params)
  return execute(params, "uninstall")
end

return M
