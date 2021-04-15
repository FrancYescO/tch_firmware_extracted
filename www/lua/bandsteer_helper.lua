local require, ipairs = require, ipairs
local proxy = require("datamodel")
local strmatch = string.match
local post_helper = require("web.post_helper")
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "Wireless", "wireless")
local content_helper = require("web.content_helper")
local M = {}

--Note:wl0, wl0-1, wl1, wl1-1, currently there is only one peeriface
--wl0\wl1 are in one pair, and bsid is bs0
--wl0_1\wl1_1 are in one pair, and bsid is bs1
--wl0_2\wl1_2 are in one pair, and bsid is bs2

--local piface = "uci.wireless.wifi-iface."
function M.getBandSteerPeerIface(curiface)
    local tmpstr = strmatch(curiface, ".*(_%d+)")
    local results = proxy.get("uci.wireless.wifi-iface.")
    local wl_pattern = "uci%.wireless%.wifi%-iface%.@([^%.]*)%."

    if results then
        for _,v in ipairs(results) do
            if v.param == "ssid" then
                local wl = v.path:match(wl_pattern)
                if wl ~= curiface then
                    if not tmpstr then
                        if not strmatch(wl, ".*(_%d+)") then
                            return wl
                        end
                    else
                        if tmpstr == strmatch(wl, ".*(_%d+)") then
                            return wl
                        end
                    end
                end
            end
        end
    end

    return nil
end

function M.isBaseIface(iface)
    if "0" == strmatch(iface, "%d+") then
        return true
    else
        return false
    end
end

function M.getBandSteerId(wl)
    local tmpstr = strmatch(wl, ".*_(%d+)")
    if not tmpstr then
        return string.format("%s", "bs0")
    else
        return string.format("%s", "bs" .. tmpstr)
    end
end

function M.disableBandSteer(object, bandsteer_state, multiap_enabled, isguest, bsPeerAP)
  if (object.bsid == "" or object.bsid == "off" or (bandsteer_state == "0" ) or ((not multiap_enabled or isguest == '1') and object.bsid == "off") or (multiap_enabled and object.multiap_cred_secondary_state == "1")) then
    return true
  else
    if bandsteer_state == "1" then
      object.bs_state = "0"
    end

    local suffix = proxy.get("uci.env.var.commonssid_suffix")[1].value
    local ssid_value
    if post_helper.getVariantValue(variantHelper, "bandSteerSSID") then
      ssid_value = object.ssid .. suffix
    else
      ssid_value = (#object.ssid <= 29) and object.ssid .. suffix or object.ssid:sub(0,29) .. suffix
    end
    if bsPeerAP then
      object["ssid"..bsPeerAP] = ssid_value
    end
    if object.bspifacessid then
      object.bspifacessid =  ssid_value
      object.bspifacessid_uci = ssid_value
    else
      object.ssid = ssid_value
      object.ssid_uci = ssid_value
    end
    if object.multiap_cred_primary_bands then
      object.multiap_cred_primary_bands = "radio_2G"
      object.multiap_cred_secondary_state = "1"
    end

    if object.multiap_bspifacessid then
      object.multiap_bspifacessid = ssid_value
    end
  end
  return true
end

function M.getBandSteerState(bspeerap, ap, multiap_cred_secondary_path, isguest)
  local band_steer_supported, band_steer_enabled
  if bspeerap then
    local content_band_steer = {}
    local bs_path = "rpc.wireless.ap.@" .. ap  .. ".bs_oper_state"
    if multiap_cred_secondary_path then
      content_band_steer.multiap_cred_secondary_state =  multiap_cred_secondary_path .. ".state"
    else
      if isguest ~= "1" then
        if post_helper.isFeatureEnabled("bandsteerDisabled" , role) then
          content_band_steer.band_steer_id = bs_path
        else
          content_band_steer.band_steer_id = "uci.wireless.wifi-bandsteer.@bs0.state"
        end
      else
        if post_helper.isFeatureEnabled("bandsteerDisabled" , role) then
          content_band_steer.band_steer_id = bs_path
        else
          content_band_steer.band_steer_id = "uci.wireless.wifi-ap.@" .. ap .. ".bandsteer_id"
        end
      end
    end
    content_helper.getExactContent(content_band_steer)
    --To get the content_band_steer value
    if content_band_steer.band_steer_id ~= "" then
      band_steer_supported = true
      if not multiap_cred_secondary_path and (content_band_steer.band_steer_id ~= "0") then
        band_steer_enabled = true
      elseif multiap_cred_secondary_path and content_band_steer.multiap_cred_secondary_state == "0" then
        band_steer_enabled = true
      end
    end
  end
  return band_steer_supported, band_steer_enabled
end
return M
