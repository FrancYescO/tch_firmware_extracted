local M = {}
local uciHelper = require("transformer.mapper.ucihelper")
local wirelessBinding = { config = "wireless" }
local get_from_uci = uciHelper.get_from_uci
local eWiFiBinding = { config = "enhancedwifi", sectionname = "global"}
local wifiConductorBinding = { config = "wifi_conductor", sectionname = "global", option = "enabled" }
local envBinding = { config = "env", sectionname = "var", option = "PXS_TV_MODE_REQ" }
local wlanConfCommon = require("transformer.shared.WLANConfigurationCommon")
local setOnUci = wlanConfCommon.setOnUci
local getFromUci = wlanConfCommon.getFromUci
local setBandSteerID = wlanConfCommon.setBandSteerID
local enableBandSteer = wlanConfCommon.enableBandSteer
local getAPFromIface = wlanConfCommon.getAPFromIface
local commit = wlanConfCommon.commit

-- This function gets the 2G from the wifi config and returns its interface and access point, and its peer inetrface and access point (5GHz)
function M.getBaseAndPeerInterfaceAndAp()
  local iface_base
  local ap_base
  local iface_peer
  local ap_peer

  wirelessBinding.sectionname = "wifi-iface"
  uciHelper.foreach_on_uci(wirelessBinding, function(s)
      if s.device == 'radio_2G' and s.network == 'lan' then
         iface_base = s[".name"]
         ap_base = getAPFromIface(iface_base)
      end
      if s.device == 'radio_5G' and s.network == 'lan' then
         iface_peer = s[".name"]
         ap_peer = getAPFromIface(iface_peer)
      end
  end)
  return iface_base, ap_base, iface_peer, ap_peer
end

function M.eWiFiEnable(base_iface, base_ap, peer_iface, peer_ap)
  if get_from_uci(envBinding)  == "Bridged" then
    return nil,  "TV mode is Bridged so Enhanced-WiFi cannot be enabled."
  else
    -- Set the radio_2G wps_state to radio_5G wps_state: Device.WiFi.AccessPoint.{i}.WPS.Enable
    setOnUci(peer_ap, "wps_state", getFromUci(base_ap, "wps_state"), commitapply)

    --Copy of the State of the 2.4 GHz to the 5.0 GHz
    setOnUci(peer_iface, "state", getFromUci(base_iface, "state"), commitapply)

    --The MAC filter mode and list of the 2.4 GHz should be copied to the 5GHz.
    setOnUci(peer_ap, "acl_mode", getFromUci(base_ap, "acl_mode"), commitapply)
    setOnUci(peer_ap, "acl_accept_list", getFromUci(base_ap, "acl_accept_list"), commitapply)
    setOnUci(peer_ap, "acl_deny_list", getFromUci(base_ap, "acl_deny_list"), commitapply)

    --if "Device.Services.X_000E50_WiFiAgent.ConductorEnable" == "true" then
    local wifi_conductor_enable =  get_from_uci(wifiConductorBinding)

    --if wifi_conductor is enabled bandsteering should be disabled otherwise the bandsteering should be enabled
    --ssid, keypassphrase and security mode should be copied from radio_2G to radio_5G in both cases, when enabling
    --the bandsteering these parameters are set but when disabling the bandsteering the parameters should be set separately.
    if wifi_conductor_enable == '1' then
      -- Set the radio_2G ssid to radio_5G ssid: Device.WiFi.SSID.{i}.SSID
      setOnUci(peer_iface, "ssid", getFromUci(base_iface, "ssid"), commitapply)

      -- Set the radio_2G wpa_psk_key to radio_5G wpa_psk_key: Device.WiFi.AccessPoint.{i}.Security.KeyPassphrase
      setOnUci(peer_ap, "wpa_psk_key", getFromUci(base_ap, "wpa_psk_key"), commitapply)

      -- Set the radio_2G security_mode to radio_5G security_mode: Device.WiFi.AccessPoint.{i}.Security.ModeEnabled
      setOnUci(peer_ap, "security_mode", getFromUci(base_ap, "security_mode"), commitapply)

      --Local band steering is disabled
      setBandSteerID(base_ap, peer_ap, "off", nil, commitapply)
    else
       --Local band steering is enabled
       enableBandSteer(base_iface, commitapply)
    end
  end
end

function M.eWiFiOn()
  local base_iface, base_ap, peer_iface, peer_ap = M.getBaseAndPeerInterfaceAndAp()
  if not (base_iface and base_ap and peer_iface and peer_ap) then
    return nil, "no peer found for the radio_2G"
  end
  M.eWiFiEnable(base_iface, base_ap, peer_iface, peer_ap)
  eWiFiBinding.option = "enable"
  uciHelper.set_on_uci(eWiFiBinding, "1", commitapply)
  uciHelper.commit(eWiFiBinding)
  commit()
end

return M
