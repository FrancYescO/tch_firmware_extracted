local uc = require("uciconv")
local o = uc.uci('old')
local n = uc.uci('new')

local wlListMain = {}
local wlListGuest = {}

local function get_ap_name(ifname)
  o:foreach("wireless", "wifi-ap", function(s)
    if s.iface == ifname then
      ap = s[".name"]
    end
  end)
  return ap
end

local function get_wl_name()
  n:foreach("web", "network", function(s)
    if s[".name"] == "main" then
      for opt, val in ipairs(s.intf) do
        wlListMain[#wlListMain+1] = s.intf[opt]
      end
    end
    if s[".name"] == "guest" then
      for option, value in ipairs(s.intf) do
        wlListGuest[#wlListGuest+1] = s.intf[option]
      end
    end
  end)
end
get_wl_name()

local ap_wl0 = get_ap_name(wlListMain[1])
local ap_wl1 = get_ap_name(wlListMain[2])
local ap_wl2, old_wl2_ssid, old_ap2_secmode, old_ap2_key
local ap_wl0_1 = get_ap_name(wlListGuest[1])
local ap_wl1_1 = get_ap_name(wlListGuest[2])
local ap_wl2_1, old_wl2_1_ssid, old_ap4_secmode, old_ap4_key

if wlListMain[3] then
  ap_wl2 = get_ap_name(wlListMain[3])
  old_wl2_ssid = o:get('wireless',wlListMain[3],'ssid')
  old_ap2_secmode = o:get('wireless',ap_wl2,'security_mode')
  old_ap2_key = o:get('wireless',ap_wl2,'wpa_psk_key')
end

if wlListGuest[3] then
  ap_wl2_1 = get_ap_name(wlListGuest[3])
  old_wl2_1_ssid = o:get('wireless',wlListGuest[3],'ssid')
  old_ap5_secmode = o:get('wireless',ap_wl2_1,'security_mode')
  old_ap5_key = o:get('wireless',ap_wl2_1,'wpa_psk_key')
end

local old_wl0_ssid = o:get('wireless',wlListMain[1],'ssid')
local old_ap0_secmode = o:get('wireless',ap_wl0,'security_mode')
local old_ap0_key = o:get('wireless',ap_wl0,'wpa_psk_key')

local old_wl1_ssid = o:get('wireless',wlListMain[2],'ssid')
local old_ap1_secmode = o:get('wireless',ap_wl1,'security_mode')
local old_ap1_key = o:get('wireless',ap_wl1,'wpa_psk_key')

local old_wl0_1_ssid = o:get('wireless',wlListGuest[1],'ssid')
local old_ap3_secmode = o:get('wireless',ap_wl0_1,'security_mode')
local old_ap3_key = o:get('wireless',ap_wl0_1,'wpa_psk_key')

local old_wl1_1_ssid = o:get('wireless',wlListGuest[2],'ssid')
local old_ap4_secmode = o:get('wireless',ap_wl1_1,'security_mode')
local old_ap4_key = o:get('wireless',ap_wl1_1,'wpa_psk_key')

local function mergeModeSync(apSec, apMain, apTer)
  n:delete("wireless", apSec, "acl_accept_list")
  n:delete("wireless", apSec, "acl_deny_list")
  local main_acl_mode = n:get("wireless", apMain, "acl_mode")
  n:set("wireless", apSec, "acl_mode", main_acl_mode)
  if apTer then
    n:delete("wireless", apTer, "acl_accept_list")
    n:delete("wireless", apTer, "acl_deny_list")
    n:set("wireless", apTer, "acl_mode", main_acl_mode)
  end
  n:foreach("wireless", "wifi-ap", function(s)
    if s[".name"] == apMain then
      if s.acl_accept_list then
        local copyValuesAccept = {}
        for opt, val in ipairs(s.acl_accept_list) do
          copyValuesAccept[#copyValuesAccept+1] = s.acl_accept_list[opt]
        end
        n:set("wireless", apSec, "acl_accept_list", copyValuesAccept)
        if apTer then
          n:set("wireless", apTer, "acl_accept_list", copyValuesAccept)
        end
      end
      if s.acl_deny_list then
        local copyValuesDeny = {}
        for option, value in ipairs(s.acl_deny_list) do
          copyValuesDeny[#copyValuesDeny+1] = s.acl_deny_list[option]
        end
        n:set("wireless", apSec, "acl_deny_list", copyValuesDeny)
        if apTer then
          n:set("wireless", apTer, "acl_deny_list", copyValuesDeny)
        end
      end
    end
  end)
end

local new_layout_enabled = o:get("env","var","em_new_ui_layout")                             
new_layout_enabled = new_layout_enabled or "0"                                               

if new_layout_enabled ~= "1" then
  if old_wl0_ssid == old_wl1_ssid and old_ap0_secmode == old_ap1_secmode and old_ap0_key == old_ap1_key then
    if wlListMain[3] then
      if old_wl0_ssid == old_wl2_ssid and old_ap0_secmode == old_ap2_secmode and old_ap0_key == old_ap2_key then
        n:set('web','main','splitssid','0')
        mergeModeSync(ap_wl1, ap_wl0, ap_wl2)
      else
        n:set('web','main','splitssid','1')
      end
    else
      n:set('web','main','splitssid','0')
      mergeModeSync(ap_wl1, ap_wl0)
    end
  else
    n:set('web','main','splitssid','1')
  end
end
                                                                          
if new_layout_enabled ~= "1" then
  if old_wl0_1_ssid == old_wl1_1_ssid and old_ap3_secmode == old_ap4_secmode and old_ap3_key == old_ap4_key then
    if wlListGuest[3] then
      if old_wl0_1_ssid == old_wl2_1_ssid and old_ap3_secmode == old_ap5_secmode and old_ap3_key == old_ap5_key then
        n:set('web','guest','splitssid','0')
        mergeModeSync(ap_wl1_1, ap_wl0_1, ap_wl2_1)
      else
        n:set('web','guest','splitssid','1')
      end
    else
      n:set('web','guest','splitssid','0')
      mergeModeSync(ap_wl1_1, ap_wl0_1)
    end
  else
    n:set('web','guest','splitssid','1')
  end
end

n:commit("wireless")
n:commit("web")

