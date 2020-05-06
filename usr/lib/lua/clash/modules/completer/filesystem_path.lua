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

local ipairs = ipairs
local match = string.match
local logger = require("logger")
local lfs = require("lfs")

-- root paths for completion are hard-coded for now
-- these should match the paths specified in verifier/file_systempath
local root_paths = {
  "/var/log/",
}

local function complete_root_paths(path)
  local matches = {}
  for _, rp in ipairs(root_paths) do
    -- If match, complete path to a root path
    if match("^" .. rp, path) then
      matches[#matches + 1] = rp
    elseif #path > #rp then
      -- If the path is larger than root path, check if it is under one of the root paths
      if match(path, "^" .. rp) then
        -- Reduced path is full provided path, except part beyond last '/', i.e. the deepest directory
        matches[#matches + 1] = match(path,"([/]?.*/)") -- Reduced path
      end
    end
  end
  return matches
end

local function complete(path)
  logger:debug("complete filesystem_path called with word %s", path or "unknown")
  local results = {}
  local rootpaths = complete_root_paths(path)

  if #rootpaths == 1 then
    local rp = rootpaths[1]
    for file in lfs.dir(rp) do
      if file ~= "." and file ~= ".." then
        -- Limitation: this basic completion does not handle partial file names,
        -- e.g. when user has typed `/var/log/te`, completer will yield all files and directories
        -- listed in `/var/log/`, not simply those starting with `te`.
        results[#results + 1] = rp .. file
      end
    end
  else
    results = rootpaths
  end
  return results
end

return complete
