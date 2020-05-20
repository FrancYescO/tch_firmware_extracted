local require, ipairs = require, ipairs
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local strmatch = string.match

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

function M.disableBandSteer(object, multiap_enabled, isguest)
    if object.bsid == "" or ((not multiap_enabled or isguest == '1') and object.bsid == "off") or (multiap_enabled and object.multiap_cred_secondary_state == "1") then
        return true
    else
        object.bsid = "off"
        object.bspeerid = "off"

        local ssid = object.ssid

        if object.bspifacessid then
            object.bspifacessid = ssid .. "-5G"
        else
            object.ssid = ssid .. "-5G"
        end

        if object.multiap_cred_primary_bands then
            object.multiap_cred_primary_bands = "radio_2G"
            object.multiap_cred_secondary_state = "1"
        end

        if object.multiap_bspifacessid then
            object.multiap_bspifacessid = ssid .. "-5G"
        end
    end
    return true
end

function M.getBandSteerState(bspeerap, ap, multiap_cred_secondary_path)
    local band_steer_supported, band_steer_enabled
    if bspeerap then
        local content_band_steer = {}
        if multiap_cred_secondary_path then
            content_band_steer.multiap_cred_secondary_state =  multiap_cred_secondary_path .. ".state"
        else
            content_band_steer.band_steer_id = "uci.wireless.wifi-ap.@" .. ap .. ".bandsteer_id"
        end
        content_helper.getExactContent(content_band_steer)

        --To get the content_band_steer value
        if content_band_steer.band_steer_id ~= "" then
            band_steer_supported = true
            if not multiap_cred_secondary_path and content_band_steer.band_steer_id ~= "off" then
                band_steer_enabled = true
            elseif multiap_cred_secondary_path and content_band_steer.multiap_cred_secondary_state == "0" then
                band_steer_enabled = true
            end
        end
    end
    return band_steer_supported, band_steer_enabled
end

return M
