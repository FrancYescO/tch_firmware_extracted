local uc = require("uciconv")
local o = uc.uci('old')
local n = uc.uci('new')

local old_map_enabled = o:get('multiap', 'controller', 'enabled')
local new_map_enabled = n:get('multiap', 'controller', 'enabled')
local old_wireless_bandsteer = o:get('wireless','ap0','bandsteer_id')

local old_wl0_ssid = o:get('wireless','wl0','ssid')
local old_ap0_secmode = o:get('wireless','ap0','security_mode')
local old_ap0_key = o:get('wireless','ap0','wpa_psk_key')

local old_wl1_ssid = o:get('wireless','wl1','ssid')
local old_ap2_secmode = o:get('wireless','ap2','security_mode')
local old_ap2_key = o:get('wireless','ap2','wpa_psk_key')

n:set('multiap','cred0','ssid',old_wl0_ssid)
n:set('multiap','cred0','security_mode',old_ap0_secmode)
n:set('multiap','cred0','wpa_psk_key',old_ap0_key)

n:set('multiap','cred2','ssid',old_wl1_ssid)
n:set('multiap','cred2','security_mode',old_ap2_secmode)
n:set('multiap','cred2','wpa_psk_key',old_ap2_key)

n:commit('multiap')

if (old_map_enabled == nil and new_map_enabled ~= nil) then
  n:set('wireless','ap6','public','1')
  n:set('wireless','ap6','max_assoc','0')
  n:set('wireless','ap6','wps_w7pbc','0')
  n:set('wireless','ap6','wps_ap_setup_locked','1')
  
  n:set('wireless','wl1_2','state','1')
  n:set('wireless','wl1_2','ssid','Telstra_BH')
  n:set('wireless','wl1_2','network','lan')
  
  n:set('wireless','radio_2G','monitor_unassoc_station_state','1')
  n:set('wireless','radio_5G','monitor_unassoc_station_state','1')

  n:set('wireless','ap0','bandsteer_id','off')
  n:set('wireless','ap2','bandsteer_id','off')

  n:commit('wireless')

  if (old_wireless_bandsteer == "off") then
    n:set('multiap','cred2','state','1')
    n:set('multiap','cred0','frequency_bands','radio_2G')
  else
    n:set('multiap','cred2','state','0')
    n:set('multiap','cred0','frequency_bands','radio_2G,radio_5Gu,radio_5Gl')
  end

  n:commit('multiap')

end
