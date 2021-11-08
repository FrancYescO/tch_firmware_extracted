local uc = require("uciconv")
local o = uc.uci('old')
local n = uc.uci('new')
local match = string.match

local haveOldRARule
o:foreach('firewall', 'rule', function(s)
  if s['name'] == "ACCEPT" or s['name'] == 'DROP' then
    haveOldRARule = true
    return false
  end
end)

if haveOldRARule then
  n:foreach('firewall', 'rule', function(s)
    if s['name'] == "ACCEPT" then
      n:set('firewall', s['.name'], 'name', 'Dev_Allow_Access')
    elseif s['name'] == 'DROP' then
      n:set('firewall', s['.name'], 'name', 'Dev_Deny_Access')
    end
  end)
end

-- remove the useless rules upgraded from 17.2.245,17.2.279,17.2.392,etc
n:delete('firewall', 'Deny_SSDP_wan')
n:delete('firewall', 'Deny_SSDP_mgmt')
n:delete('firewall', 'Deny_SSDP_wwan')
n:delete('firewall', 'Deny_IGMP_wan')
n:delete('firewall', 'Deny_IGMP_mgmt')
n:delete('firewall', 'Deny_IGMP_wwan')

-- remove the rule when upgraded
n:delete('firewall', 'Deny_HTTP_lan')

-- correct the names upgraded from 17.2.245,17.2.279,17.2.392,etc
n:set('firewall', 'Allow_DHCP_Renew_mgmt', 'name', 'Allow-DHCP-Renew-mgmt')
n:set('firewall', 'Allow_DHCP_Renew_wan', 'name', 'Allow-DHCP-Renew-wan')
n:set('firewall', 'Access_Guest_DNS_input', 'name', 'Allow-Guest-DNS-input')
n:set('firewall', 'telnetguest', 'name', 'Refuse_TELNET_GUEST')

-- correct the sip rules upgraded from 17.2.245,17.2.279,17.2.392,etc
-- Remove the useless SIP LAN/Guest rules upgraded from 18.3.155,etc
n:foreach('firewall', 'rule', function(s)
  local num = match(s['.name'], '^Deny_SIP_LAN_(%d+)$') or
              match(s['.name'], '^Deny_SIP_Guest_(%d+)$')
  if num and tonumber(num) then
    n:delete('firewall', s[".name"])
  end

  num = match(s['.name'], '^Allow_restricted_sip_(%d+)$')
  num = num and tonumber(num)
  if num then
    if num >= 1 and num <= 10 then
      local src_ip
      if num == 1 then
        src_ip = '10.247.0.0/24'
      elseif num == 2 then
        src_ip = '10.247.1.0/24'
      elseif num == 3 then
        src_ip = '10.247.5.0/24'
      elseif num == 4 then
        src_ip = '10.247.30.0/24'
      elseif num == 5 then
        src_ip = '10.247.48.0/24'
      elseif num == 6 then
        src_ip = '10.247.49.0/24'
      elseif num == 7 then
        src_ip = '10.252.47.0/24'
      elseif num == 8 then
        src_ip = '10.252.48.0/24'
      elseif num == 9 then
        src_ip = '10.252.50.0/24'
      elseif num == 10 then
        src_ip = '30.253.253.0/24'
      end
      n:set('firewall',s[".name"], 'name', "Allow-restricted-sip-from-wan-again-" .. num)
      n:set('firewall',s[".name"], 'src_ip', src_ip)
      n:set('firewall',s[".name"], 'dest_port', '5060')
    else
      n:delete('firewall', s[".name"])
    end
  end
end)

-- remove the ACS rules
n:delete('firewall', 'Allow_ACS_1')
n:delete('firewall', 'Allow_ACS_2')

n:commit('firewall')
