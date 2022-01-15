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

local pairs = pairs
local ipairs = ipairs
local error = error

local open = io.open
local remove = table.remove

local storage = require 'lcm.store.storage'
-- create a default (no-op) store. This avoids having to nil check
-- in the code in case init is not called to properly initialize
-- a proper storage layer.
local store = storage.open()

local s_db = {}
local s_index_by_ID = {}

---------------------------------------------------------------------
local M = {}

local function read_first_line(filename)
  local firstline
  local fd = open(filename)
  if fd then
    firstline = fd:read("*l")
    fd:close()
  end
  return firstline
end

function M.generateID()
  return read_first_line("/proc/sys/kernel/random/uuid")
end

local function package_by_ID(ID)
  local index = s_index_by_ID[ID]
  return s_db[index]
end

-- we export this mainly to allow for deeper unit testing
-- (to check the s_index_by_ID is properly cleaned up on remove)
-- But as this might also be generally useful I see no problem
-- in doing so.
M.package_by_ID = package_by_ID

local function add_package(pkg)
  local idx = #s_db+1
  s_db[idx] = pkg
  s_index_by_ID[pkg.ID] = idx
  store:save(pkg)
end

local function error_if_package_has_no_ID(pkg)
  if not pkg.ID then
    error("package is missing ID")
  end
end

function M.add(pkg)
  error_if_package_has_no_ID(pkg)
  if not package_by_ID(pkg.ID) then
    add_package(pkg)
  end
end

local function match_properties(pkg, properties)
  if properties then
    for property, value in pairs(properties) do
      if pkg[property] ~= value then
        return false
      end
    end
  end
  return true
end

local function potentially_matching_packages(properties)
  local ID = properties and properties.ID
  if ID then
    -- Use the given ID to locate at most 1 package
    return { package_by_ID(ID) }
  end
  return s_db
end

function M.query(properties)
  local result = {}
  for _, pkg in ipairs(potentially_matching_packages(properties)) do
    if match_properties(pkg, properties) then
      result[#result + 1] = pkg
    end
  end
  return result
end

local function adjust_index(ID, start_idx)
  s_index_by_ID[ID] = nil
  for i = start_idx, #s_db do
    local pkg = s_db[i]
    s_index_by_ID[pkg.ID] = i
  end
end

function M.remove(ID)
  local index = s_index_by_ID[ID]
  if index then
    remove(s_db, index)
    adjust_index(ID, index)
    store:remove(ID)
  end
end

function M.save(pkg)
  return store:save(pkg)
end

function M.init(store_type, store_location)
  store = storage.open(store_type, store_location)
end

function M.restore_contents(load_package)
  local ids = store:list()
  for _, ID in ipairs(ids) do
    local pkg_data = store:load(ID)
    -- note that the package must be added to db by load_package!
    -- we do not add it here.
    load_package(pkg_data)
  end
end

return M
