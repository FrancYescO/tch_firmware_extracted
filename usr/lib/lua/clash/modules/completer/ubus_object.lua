--[[
/********** COPYRIGHT AND CONFIDENTIALITY INFORMATION NOTICE *************
** Copyright (c) 2016 - 2016  -  Technicolor Delivery Technologies, SAS **
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

local logger = require("logger")
local ubus_acc = require("helper.ubus_acc")

-- Completer will complete UBUS objects
local function complete(input, line)
  logger:debug("complete ubus_object called with word '%s', line '%s'", input or "unknown", line or "unknown")
  local results={}
  local all={}

  for object in pairs(ubus_acc) do
    all[#all + 1] = object
    if input and object:match("^" .. input) then
      results[#results + 1] = object
    end
  end

  -- When no matches against input, return all possibilities
  if #results == 0 then
    results = all
  end

  -- Sort alphabetically for convenience
  sorted = {}
  for _, result in pairs(results) do table.insert(sorted, result) end
  table.sort(sorted)

  return sorted
end

return complete
