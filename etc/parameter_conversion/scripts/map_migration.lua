local uc = require("uciconv")
local o = uc.uci('old')
local n = uc.uci('new')

local function get_ap_name(ifname)
  o:foreach("wireless", "wifi-ap", function(s)
    if s.iface == ifname then
      ap = s[".name"]
    end
  end)
  return ap
end

local old_map_enabled = o:get('multiap', 'controller', 'enabled')
local new_map_enabled = n:get('multiap', 'controller', 'enabled')
local new_conductor_enabled = n:get('wifi_conductor','global','multiap_enabled')

local ap_wl0 = get_ap_name("wl0")
local ap_wl1 = get_ap_name("wl1")
local old_wireless_bandsteer = o:get('wireless',ap_wl0,'bandsteer_id')

local old_wl0_ssid = o:get('wireless','wl0','ssid')
local old_ap0_secmode = o:get('wireless',ap_wl0,'security_mode')
local old_ap0_key = o:get('wireless',ap_wl0,'wpa_psk_key')

local old_wl1_ssid = o:get('wireless','wl1','ssid')
local old_ap1_secmode = o:get('wireless',ap_wl1,'security_mode')
local old_ap1_key = o:get('wireless',ap_wl1,'wpa_psk_key')

n:set('multiap','cred0','ssid',old_wl0_ssid)
n:set('multiap','cred0','security_mode',old_ap0_secmode)
n:set('multiap','cred0','wpa_psk_key',old_ap0_key)

n:set('multiap','cred1','ssid',old_wl1_ssid)
n:set('multiap','cred1','security_mode',old_ap1_secmode)
n:set('multiap','cred1','wpa_psk_key',old_ap1_key)

n:commit('multiap')

if (old_map_enabled == nil and new_map_enabled ~= nil) then
  if (new_map_enabled == "1" and new_conductor_enabled == "1") then
    n:set('wireless','bs0','state','0')
    n:commit('wireless')
  end

  if (old_wireless_bandsteer == "off") then
    n:set('multiap','cred1','state','1')
    n:set('multiap','cred0','frequency_bands','radio_2G')
  else
    n:set('multiap','cred1','state','0')
    n:set('multiap','cred0','frequency_bands','radio_2G,radio_5Gu,radio_5Gl')
  end

  n:commit('multiap')

end
