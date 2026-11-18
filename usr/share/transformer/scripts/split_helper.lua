#!/usr/bin/env lua

local proxy = require("datamodel")
local match, format = string.match, string.format
local main_split, guest_split = "0", "0"
local unpack = unpack

local function convertResultToObject(basepath, results, sorted)
    local indexstart, indexmatch, subobjmatch
    local data = {}
    local output = {}
    local find, gsub = string.find, string.gsub

    indexstart = #basepath
    if not basepath:find("%.@%.$") then
        indexstart = indexstart + 1
    end

    basepath = gsub(basepath,"-", "%%-")
    basepath = gsub(basepath,"%[", "%%[")
    basepath = gsub(basepath,"%]", "%%]")

    if results then
        for _,v in ipairs(results) do
            -- Try to match the path with basepath.{index}.{subobj}
            -- subobj can be nil (if the parameter is just under basepath) but if it is not, then we concatenate it with the param name
            -- so subobjects will be defined using their full "subpath"
            indexmatch, subobjmatch = v.path:match("^([^%.]+)%.(.*)$", indexstart)
            if indexmatch and find(v.path, basepath) == 1 then
                if data[indexmatch] == nil then
                    -- Initializes 2 structures. One (data) is used to gather the data for a given "object"
                    -- The other (output) is used to create an array of those objects to be able to list data in order
                    data[indexmatch] = {}
                    data[indexmatch]["paramindex"] = indexmatch
                    output[#output + 1] = data[indexmatch]
                end
                -- No need to check on subobj, "worst" case, it's an empty string, not nil since the capture allows for an empty string
                -- Store value using a key that contains the full "sub path"
                data[indexmatch][subobjmatch .. v.param] = v.value
            end
        end
    end
    return output
end

local function getValues(content)
    local result = {}
    if content then
        for _,v in pairs(content) do
            result[#result+1] = v
        end
    end
    return result
end

local function getExactContent(content)
    local paths = getValues(content)
    local result, errmsg = proxy.get(unpack(paths))
    local temp = {}
    for _,v in ipairs(result or {}) do
        temp[v.path..v.param] = v.value
    end
    for k,v in pairs(content) do
        content[k] = temp[v] or ""
    end
    if result then
        return true
    else
        return nil, errmsg
    end
end

local function correct_split()
    local function path_to_data(path)
        return convertResultToObject(path, proxy.get(path))
    end

    local wifi_ap_path = "uci.wireless.wifi-ap."
    local wifi_ap_data = path_to_data(wifi_ap_path)



    local function ap_data_from_wl(wl)
        local returnvar = {}
        local wl_path = format("uci.wireless.wifi-iface.@%s.", wl)
        local wl_data = {
          ssid = wl_path .. "ssid",
          state = wl_path .. "state",
          device = wl_path .. "device",
        }
        getExactContent(wl_data)
        returnvar = wl_data
        for k, v in pairs(wifi_ap_data) do
           if v.iface == wl then
                local ap = match(v.paramindex, "@([^%.]+)")
                local wpa3_pass = proxy.get(format("uci.wireless.wifi-ap-credential.@%s_credential0.passphrase", ap))
                wpa3_pass = wpa3_pass and wpa3_pass[1] and wpa3_pass[1].value or ""
                returnvar["ap"] = { ap=ap, state=v.state, security_mode=v.security_mode, wep_key=v.wep_key, wpa_psk_key=v.wpa_psk_key, passphrase=wpa3_pass }
                return returnvar
           end
        end
    end

    local function cred_data_from_cred(cred)
        local cred_path = format("uci.multiap.controller_credentials.@%s.", cred)
        local cred_data = {
          ssid = cred_path .. "ssid",
          operational_state = cred_path .. "operational_state",
          wpa_psk_key = cred_path .. "wpa_psk_key",
          state = cred_path .. "state",
          frequency_bands = cred_path .. "frequency_bands",
          security_mode = cred_path .. "security_mode",
        }
        getExactContent(cred_data)
        return cred_data
    end

    local function check_wifi(wifi_table)
      local wlssid, wlstate, apstate, apsecmode, apkey
      for k, v in pairs(wifi_table) do
            if not wlssid then
               wlssid = v.ssid
               wlstate = v.state
               apstate = v.ap.state
               apsecmode = v.ap.security_mode
               if apsecmode == "none" then
                    apkey = ""
               elseif apsecmode == "wep" then
                    apkey = v.ap.wep_key
               elseif apsecmode:match("wpa3") then
                    apkey = v.ap.passphrase
               else
                    apkey = v.ap.wpa_psk_key
               end
            else
               local tmp_apsecmode = v.ap.security_mode
               local tmp_apkey
               if tmp_apsecmode == "none" then
                    tmp_apkey = ""
               elseif tmp_apsecmode == "wep" then
                    tmp_apkey = v.ap.wep_key
               elseif tmp_apsecmode:match("wpa3") then
                    tmp_apkey = v.ap.passphrase
               else
                    tmp_apkey = v.ap.wpa_psk_key
               end
               if wlssid == v.ssid and apsecmode == tmp_apsecmode and apkey == tmp_apkey then
                    return "0"
               else
                    return "1"
               end
            end
      end
    end

    local multiap_state = {
      agent = "uci.multiap.agent.enabled",
      controller = "uci.multiap.controller.enabled"
    }
    getExactContent(multiap_state)
    local multiap_controller_enabled = multiap_state.controller == "1"
    local multiap_agent_enabled = multiap_state.agent == "1"
    local main_split_path = "uci.web.network.@main.splitssid"
    local guest_split_path = "uci.web.network.@guest.splitssid"

    local web_split_data = {
          main = main_split_path,
          guest = guest_split_path,
        }
    getExactContent(web_split_data)
    local main_split = "1"
    local guest_split = "1"


    local current_main_split = web_split_data.main
    local current_guest_split = web_split_data.guest


    local cred_values = { main={cred={},wifi={}},guest={cred={},wifi={}}}


    local function cred_data_to_table(cd, t)
        for k, v in pairs(cd) do
            t[k] = v
        end
    end
    if multiap_controller_enabled then
      local main_cred_path = "uci.web.network.@main.cred."
      local main_cred_data = path_to_data(main_cred_path)
      if #main_cred_data > 1 then
          cred_values["main"]["cred"][main_cred_data[1].value] = {}
          cred_values["main"]["cred"][main_cred_data[2].value] = {}

          cred_data_to_table(cred_data_from_cred(main_cred_data[1].value), cred_values["main"]["cred"][main_cred_data[1].value])
          cred_data_to_table(cred_data_from_cred(main_cred_data[2].value), cred_values["main"]["cred"][main_cred_data[2].value])

      end

      local guest_cred_path = "uci.web.network.@guest.cred."
      local guest_cred_data = path_to_data(guest_cred_path)
      if #guest_cred_data > 1 then
          cred_values["guest"]["cred"][guest_cred_data[1].value] = {}
          cred_values["guest"]["cred"][guest_cred_data[2].value] = {}

          cred_data_to_table(cred_data_from_cred(guest_cred_data[1].value), cred_values["guest"]["cred"][guest_cred_data[1].value])
          cred_data_to_table(cred_data_from_cred(guest_cred_data[2].value), cred_values["guest"]["cred"][guest_cred_data[2].value])
      end

      for k, v in pairs(cred_values["main"]["cred"]) do
         if v.frequency_bands:match("radio_2G") and v.frequency_bands:match("radio_5Gl") then
            main_split = "0"
         end
      end
      for k, v in pairs(cred_values["guest"]["cred"]) do
         if v.frequency_bands:match("radio_2G") and v.frequency_bands:match("radio_5Gl") then
            guest_split = "0"
         end
      end

    elseif multiap_agent_enabled then
      local main_intf_path = "uci.web.network.@main.intf."
      local main_intf_data = path_to_data(main_intf_path)
      if #main_intf_data > 1 then
          cred_values["main"]["wifi"][main_intf_data[1].value] = ap_data_from_wl(main_intf_data[1].value)
          cred_values["main"]["wifi"][main_intf_data[2].value] = ap_data_from_wl(main_intf_data[2].value)

      end
      local guest_intf_path = "uci.web.network.@guest.intf."
      local guest_intf_data = path_to_data(guest_intf_path)
      if #guest_intf_data > 1 then
          cred_values["guest"]["wifi"][guest_intf_data[1].value] = ap_data_from_wl(guest_intf_data[1].value)
          cred_values["guest"]["wifi"][guest_intf_data[2].value] = ap_data_from_wl(guest_intf_data[2].value)
      end
      main_split = check_wifi(cred_values["main"]["wifi"])
      guest_split = check_wifi(cred_values["guest"]["wifi"])
    end


    if main_split ~= current_main_split and (multiap_controller_enabled or multiap_agent_enabled) then
       proxy.set(main_split_path, main_split)
       proxy.apply()
    end
    if guest_split ~= current_guest_split and (multiap_controller_enabled or multiap_agent_enabled) then
       proxy.set(guest_split_path, guest_split)
       proxy.apply()
    end
    return true
end

local correct_split = correct_split()

