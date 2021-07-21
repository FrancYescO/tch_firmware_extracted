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

local lower = string.lower

--- Matches a given line against a given filter, taking case sensitivity into account.
-- @tparam string line The line to be processed
-- @tparam string filter The filter to match the line against
-- @tparam boolean caseInsensitive Specifies whether to do case-insensitive matching or not
-- @return boolean True if the specified line matches the specified filter
local function pass(line, filter, caseInsensitive)
  if line and filter then
    if ( caseInsensitive and lower(line):match( lower(filter) ) ) or line:match(filter) then
      return true
    end
  end
end

return pass
