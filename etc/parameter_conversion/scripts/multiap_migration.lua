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

local old_map_controller = o:get('multiap', 'controller', 'enabled')
local old_map_agent = o:get('multiap', 'agent', 'enabled')

if old_map_controller == "0" and old_map_agent == "0" then
  local ap_wl0 = get_ap_name("wl0")
  local ap_wl1 = get_ap_name("wl1")

  -- By default multiap is enbaled so copying the ssid, key and mode from wireless if multiap is disabled in old

  local old_wl0_ssid = o:get('wireless','wl0','ssid')
  local old_ap0_secmode = o:get('wireless',ap_wl0,'security_mode')
  old_ap0_secmode = old_ap0_secmode == "wpa3-psk" and "wpa2-wpa3-psk" or old_ap0_secmode
  local old_ap0_key = o:get('wireless',ap_wl0,'wpa_psk_key')

  local old_wl1_ssid = o:get('wireless','wl1','ssid')
  local old_ap1_secmode = o:get('wireless',ap_wl1,'security_mode')
  old_ap1_secmode = old_ap1_secmode == "wpa3-psk" and "wpa2-wpa3-psk" or old_ap1_secmode
  local old_ap1_key = o:get('wireless',ap_wl1,'wpa_psk_key')

  n:set('multiap','cred0','ssid',old_wl0_ssid)
  n:set('multiap','cred0','security_mode',old_ap0_secmode)
  n:set('multiap','cred0','wpa_psk_key',old_ap0_key)

  n:set('multiap','cred1','ssid',old_wl1_ssid)
  n:set('multiap','cred1','security_mode',old_ap1_secmode)
  n:set('multiap','cred1','wpa_psk_key',old_ap1_key)

  local old_layout_enabled = o:get("env","var","em_new_ui_layout")
  local mainSplit
  if old_layout_enabled == "1" then
     mainSplit = o:get('web', 'main', 'splitssid')
  end
  local guestSplit = o:get('web', 'guest', 'splitssid')

 --NG-223739 If ssid, key, and mode are same for 2.4GHz and 5Ghz then merge mode will shown.

  if (old_wl0_ssid == old_wl1_ssid and old_ap0_key == old_ap1_key and old_ap0_secmode == old_ap1_secmode and mainSplit ~= "nil" and mainSplit == "0") or (old_wl0_ssid == old_wl1_ssid and old_ap0_key == old_ap1_key and old_ap0_secmode == old_ap1_secmode and old_layout_enabled ~= "nil" and old_layout_enabled == "0") then
    n:set('multiap','cred1','state','0')
    n:set('multiap','cred0','frequency_bands','radio_2G,radio_5Gu,radio_5Gl')
  else
    n:set('multiap','cred1','state','1')
    n:set('multiap','cred0','frequency_bands','radio_2G')
  end

  local ap_wl0_1 = get_ap_name("wl0")
  local ap_wl1_1 = get_ap_name("wl1")

  local old_wl0_1_ssid = o:get('wireless','wl0_1','ssid')
  local old_wl1_1_ssid = o:get('wireless','wl1_1','ssid')
  if old_wl0_1_ssid == old_wl1_1_ssid and guestSplit ~= "nil" and guestSplit == "0" then
    n:set('multiap','cred4','state','0')
    n:set('multiap','cred3','frequency_bands','radio_2G,radio_5Gu,radio_5Gl')
  else
    n:set('multiap','cred4','state','1')
    n:set('multiap','cred3','frequency_bands','radio_2G')
  end
  n:commit('multiap')

end
