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

local match = string.match
local logger = require("logger")

-- Complete the input by searching for all matching chains from specified table
local function complete_for_table(input, table, results)
  if table and table ~= "" then
    -- This lists all the chains for a table and their respective rules.
    -- Not all users have read access to iptables or table may be invalid; drop the error in these cases.
    local fd=io.popen("iptables -t "  .. table .. " -L 2>/dev/null")
    if fd then
      for line in fd:lines() do
        -- chain header is e.g. `Chain zone_lan_input (1 references)`
        local chain=line:match("Chain (.*) %(")
        if chain then
          if input and chain:match("^" .. input) then
            results[#results + 1] = chain
          end
        end
      end
      fd:close()
    end
  end
end

-- Completer will complete all chains from a table.
-- Limitation of the completer:
--   The completer will yield no results for users that may not list the iptables rules.
--   In practice, tab completion will currently only work for `root`
local function complete(input, line)
  logger:debug("complete iptables_chain called with word '%s', line '%s'", input or "unknown", line or "unknown")
  local results={}

  -- If user has provided table option `-t`, use that table; else default to `filter`
  local table = (line and line:match("-t[ ]+(%a+)")) or "filter"

  complete_for_table(input, table, results)

  return results
end

return complete
