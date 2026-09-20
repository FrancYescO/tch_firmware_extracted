local ngx = ngx
local find, match, require = string.find, string.match, require
local sort = table.sort
local lfs = require("lfs")
local bridged = require("bridgedmode_helper")

local includepath

module ("cards")

function setpath(path)
  includepath = path
end

--Config Card files for bidged mode
local cardsbridged = " \
    001_gateway.lp \
    002_broadband.lp \
    004_wireless.lp \
    005_LAN.lp \
    011_usermgr.lp \
    "

function cards()
  local result = {}
  if includepath and lfs.attributes(includepath, 'mode') == 'directory' then
    for file in lfs.dir(includepath) do
      if find(file, "%.lp$") then
        if (bridged.isBridgedMode()) then
          if match(cardsbridged, file) then
            result[#result+1] = file
          end
        else
          result[#result+1] = file
        end
      end
    end
  end
  sort(result)
  return result
end
