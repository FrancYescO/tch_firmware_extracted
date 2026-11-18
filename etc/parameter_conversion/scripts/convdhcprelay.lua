local uc = require("uciconv")
local o = uc.uci('old')
local n = uc.uci('new')

local enabled = o:get('dhcprelay', 'config', 'enabled')
if enabled and enabled == '1' then
  local serverip = o:get('dhcprelay', 'config', 'serverip')
  local serverif = o:get('dhcprelay', 'config', 'serveriface')
  local intf = o:get('dhcprelay', 'config', 'clientiface')

  local ipaddr = intf and o:get('network', intf, 'ipaddr')
  if ipaddr and serverip then
    local sname = n:add('dhcp', 'relay')
    n:set('dhcp', sname, 'local_addr',  ipaddr)
    n:set('dhcp', sname, 'server_addr',  serverip)
    if serverif then
      n:set('dhcp', sname, 'interface',  serverif)
    end
    n:commit('dhcp')
  end
end
