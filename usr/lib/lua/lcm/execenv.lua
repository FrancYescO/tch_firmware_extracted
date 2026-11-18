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

local ipairs = ipairs

-- load execution environments
local s_execenvs = {
--  require("lcm.execenv.base_system"),
  require("lcm.execenv.native"),
  -- require("lcm.execenv.osgi")
}
local s_index_by_name = {}
for _, execenv in ipairs(s_execenvs) do
  local name = execenv.specs.name
  s_index_by_name[name] = execenv
end

---------------------------------------------------------------------
local M = {}

function M.query(name)
  if name then
    return s_index_by_name[name]
  end
  return s_execenvs
end

return M
