local ngx = ngx
local find, require = string.find, require
local sort = table.sort
local lfs = require("lfs")

local includepath

module ("cards")

function setpath(path)
  includepath = path
end

function cards()
  local result = {}
  if includepath and lfs.attributes(includepath, 'mode') == 'directory' then
    for file in lfs.dir(includepath) do
      if find(file, "%.lp$") then
        result[#result+1] = file
      end
    end
  end
  sort(result)
  return result
end