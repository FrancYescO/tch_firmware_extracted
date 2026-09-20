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

setmetatable(M, {
  __index = function(tbl, key)
    return function(...)
      return proxy[key](uuid, ...)
    end
  end,
})

return M
