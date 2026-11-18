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

local require, setmetatable = require, setmetatable

local proxy = require("datamodel-bck")

local uuid

local M = {}

M.set_uuid = function(new_uuid)
  uuid = new_uuid
end

local function obscure_password_value(results)
  if type(results) ~= "table" then
    return results
  end

  for _,result in ipairs(results) do
    if result.type == "password" then
        result.value = "********"
    end
  end

  return results
end

setmetatable(M, {
  __index = function(tbl, key)
    return function(...)
      -- Obscure password values when getting datamodel location(s).
      if key == "get" then
        results, errmsg, errcode = proxy[key](uuid, ...)
        results = obscure_password_value(results)
        return results, errmsg, errcode
      end

      return proxy[key](uuid, ...)
    end
  end,
})

return M
