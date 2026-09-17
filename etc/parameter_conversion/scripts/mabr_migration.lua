local uc = require("uciconv")
local o = uc.uci('old')
local n = uc.uci('new')

local old_map_mabr = o:get('system', 'mabr', 'enabled')

if old_map_mabr == "0" then
  n:set('system','mabr','enabled',old_map_mabr)
  n:commit('system')
  os.execute("/etc/init.d/nanocdn restart")
end
