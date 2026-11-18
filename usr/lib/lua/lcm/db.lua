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

local open = io.open
local remove = table.remove
local next, ipairs, pairs = next, ipairs, pairs

local s_uuid_fd = open("/proc/sys/kernel/random/uuid")
local s_db = {}
local s_db_entries = 0
local s_index_by_ID = {}

---------------------------------------------------------------------
local M = {}

function M.generateID()
  local ID = s_uuid_fd:read("*l")
  s_uuid_fd:seek("set")  -- reset fd to beginning so a next read succeeds
  return ID
end

function M.add(pkg)
  local ID = M.generateID()
  pkg.ID = ID
  s_db_entries = s_db_entries + 1
  s_db[s_db_entries] = pkg
  s_index_by_ID[ID] = s_db_entries
  return ID
end

local function match_properties(pkg, properties)
  for property, value in pairs(properties) do
    if pkg[property] ~= value then
      return false
    end
  end
  return true
end

function M.query(properties)
  if not properties or not next(properties) then
    return s_db
  end
  local result = {}
  -- if 'properties' contains the ID we can use our ID index
  local prop_ID = properties.ID
  if prop_ID then
    properties.ID = nil
    local pkg = s_db[s_index_by_ID[prop_ID]]
    if pkg and match_properties(pkg, properties) then
      result[1] = pkg
    end
  else
    for _, pkg in ipairs(s_db) do
      if match_properties(pkg, properties) then
        result[#result + 1] = pkg
      end
    end
  end
  return result
end

function M.remove(ID)
  local index = s_index_by_ID[ID]
  if index then
    s_db_entries = s_db_entries - 1
    remove(s_db, index)
    s_index_by_ID[ID] = nil
    for i = index, s_db_entries do
      local pkg = s_db[i]
      s_index_by_ID[pkg.ID] = i
    end
  end
end

return M
