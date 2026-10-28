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

local print = print

local function complete(boolval)
  --logger:debug("GV: complete datamodel_path called with word %s", path or "unknown")
  local results = {}
  
  if match("true", "^" .. boolval) then
    results[#results + 1] = "true"
  elseif match("false", "^" .. boolval) then
    results[#results + 1] = "false"
  end  
  
  return results
end

return complete