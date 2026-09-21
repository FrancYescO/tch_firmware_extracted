--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2015 - 2016  -  Technicolor Delivery Technologies, SAS **
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

local ipairs, require = ipairs, require
local match = string.match
local logger = require("logger")
local proxy = require("helper.transformer")

local root_paths ={
  "InternetGatewayDevice.",
  "Device.",
  "uci.",
  "sys.",
  "rpc.",
}

local function check_path_matches(path, suggestion, results)
  if match(suggestion, "^"..path) then
    results[#results + 1 ] = suggestion
  end
end

local function complete(path)
  logger:debug("complete datamodel_path called with word %s", path or "unknown")
  local results = {}
  -- First check if the given word contains a dot. If not, only compare to root_paths
  if not match(path, "(%.)") then
    for _, root in ipairs(root_paths) do
      -- First check if the root is actually available
      local dm_paths, errmsg = proxy.getPN(root, true)
      if dm_paths then
        check_path_matches(path, root, results)
      end
    end
  else
    -- The path contains at least one dot. Get the path as is. If it fails, chop off everything after the last dot
    local dm_paths, errmsg = proxy.getPN(path, true)
    if dm_paths then
      for _, dm_path in ipairs(dm_paths) do
        check_path_matches(path, dm_path.path..dm_path.name, results)
      end
    else
      local reduced_path = match(path, "(.*%.)[^%.]*$")
      if reduced_path then
        dm_paths, errmsg = proxy.getPN(reduced_path, true)
        if dm_paths then
          for _, dm_path in ipairs(dm_paths) do
            check_path_matches(path, dm_path.path..dm_path.name, results)
          end
        end
      end
      -- If this still didn't work, give up
    end
  end
  return results
end

return complete