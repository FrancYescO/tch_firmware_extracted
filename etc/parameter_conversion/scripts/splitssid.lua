local uc = require("uciconv")
local o = uc.uci('old')
local n = uc.uci('new')

local function getParam(config ,section , option)
  return n:get(config ,section , option)
end
local function splitSSID(type, wl2G, wl5G , ap2G ,ap5G)
  local state_2G = getParam('wireless', wl2G, 'state')
  local ssid_2G = getParam('wireless', wl2G, 'ssid')
  local security_mode_2G = getParam('wireless', ap2G, 'security_mode')

  local state_5G = getParam('wireless', wl5G, 'state')
  local ssid_5G = getParam('wireless', wl5G, 'ssid')
  local security_mode_5G = getParam('wireless', ap5G, 'security_mode')

  local passphrase_2G  ,passphrase_5G = "None", "None"
  if security_mode_2G == "wep" then
    passphrase_2G = getParam('wireless', ap2G, 'wep_key')
    passphrase_5G = getParam('wireless', ap5G, 'wep_key')
  elseif security_mode_2G ~= "none" then
    passphrase_2G = getParam('wireless', ap2G, 'wpa_psk_key')
    passphrase_5G = getParam('wireless', ap5G, 'wpa_psk_key')
  end
  local splitssid = n:get('web', type, 'splitssid')
  if state_2G == state_5G and ssid_2G == ssid_5G and security_mode_2G == security_mode_5G and passphrase_2G == passphrase_5G and splitssid == "1" then
    n:set('web',type,'splitssid','0')
  elseif splitssid == "0" then
    n:set('web',type,'splitssid','1')
  end
end

if not o:get('web', 'main', 'splitssid') then 
  splitSSID('main', 'wl0', 'wl1', 'ap0', 'ap1')
end
if not o:get('web', 'guest', 'splitssid') then 
  splitSSID('guest', 'wl0_1', 'wl1_1', 'ap2', 'ap3')
end
n:commit('web')
