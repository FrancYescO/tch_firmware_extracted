#!/usr/bin/env lua

local proxy = require("datamodel")
local io = require("io")
local format = string.format

local function convertResultToObject(basepath, results)
  local indexstart, indexmatch, subobjmatch, parsedIndex = false
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
    for _, v in ipairs(results) do
      indexmatch, subobjmatch = v.path:match("^([^%.]+)%.(.*)$", indexstart)
      if indexmatch and find(v.path, basepath) then
        if not data[indexmatch] then
          data[indexmatch] = {}
          data[indexmatch]["paramindex"] = indexmatch
          parsedIndex = indexmatch:match("(%w+)")
          output[parsedIndex] = data[indexmatch]
        end
        data[indexmatch][subobjmatch .. v.param] = v.value
      end
    end
  end
  return output
end

--Generate random key for new rule
--@return 16 digit random key.
local function getRandomKey()
  local bytes
  local key = ("%02X"):rep(16)
  local fd = io.open("/dev/urandom", "r")
  if fd then
    bytes = fd:read(16)
    fd:close()
  end
  return key:format(bytes:byte(1, 16))
end

-- Determine the wireless ap for a given wifi-interface(or L2Interface) by searching
-- through the uci.wireless.wifi-ap.<ap_inst>.iface entries
local function findMatchingAP(wliface)
  local apFound = ""
  local getRetTbl = proxy.get("uci.wireless.wifi-apNumberOfEntries") or ""
  local numAPs = getRetTbl[1].value
  for apinst = 0 , tonumber(numAPs)-1 do
    local test_val = proxy.get(format("uci.wireless.wifi-ap.@ap%s.iface", apinst))
    if test_val and test_val ~= "" and test_val[1].value == wliface then
      apFound = "ap" .. tostring(apinst)
      break
    end
  end
  return apFound
end

local isNewLayout = proxy.get("uci.env.var.em_new_ui_layout")
isNewLayout = isNewLayout and isNewLayout[1].value or "0"
if isNewLayout == "1" then
  local interface_list = "uci.web.network.@main.intf."
  interface_list = convertResultToObject(interface_list, proxy.get(interface_list))
  local tod_timer_path = "uci.tod.timer."
  local tod_action_path = "uci.tod.action."
  local tod_wifitod_path = "uci.tod.wifitod."
  local tod_ap_path = "uci.tod.ap."
  local action_list = convertResultToObject(tod_action_path, proxy.get(tod_action_path))
  local tod_ap_list = convertResultToObject(tod_ap_path, proxy.get(tod_ap_path))
  local timer_list = convertResultToObject(tod_timer_path, proxy.get(tod_timer_path))
  local wifitod_list = convertResultToObject(tod_wifitod_path, proxy.get(tod_wifitod_path))
  local match = string.match
  local tod_content, setObject = {}, {}
  -- Get the tod config data to update tod rule based on split/Merge mode
  for i, v in pairs(wifitod_list) do
    wifiindex = v.paramindex
    wifiindex = wifiindex:match("wifitod(.+)")
    apList = "uci.tod.wifitod."..v.paramindex..".ap."
    apList = convertResultToObject(apList.."@.", proxy.get(apList))
    tod_content[wifiindex] = {}
    for apIndex, apSection in pairs(apList) do
      apVal = apSection.value
      tod_content[wifiindex]["index"] = wifiindex
      ap_listIndex  = apSection.paramindex
      if apVal and apVal ~= "" then
        tod_content[wifiindex]["ap"..apIndex] = {}
        tod_content[wifiindex]["ap"..apIndex]["ap"] = proxy.get("uci.tod.ap.@"..apVal..".ap")[1].value
        tod_content[wifiindex]["ap"..apIndex]["ssid"] = proxy.get("uci.tod.ap.@"..apVal..".ssid")[1].value
        tod_content[wifiindex]["ap"..apIndex]["state"] = proxy.get("uci.tod.ap.@"..apVal..".state")[1].value
      end
    end
    for index, action in pairs(action_list) do
      if action_list[index].script == "wifitodscript" then
        for timerindex, timeraction in pairs(timer_list) do
          timerIndexVal = timeraction.paramindex
          timerIndexVal = timerIndexVal:match("timer(.+)")
          if timerIndexVal == wifiindex then
            if timer_list[timerindex].name == "" or timer_list[timerindex].name == "wifitod" then
              tod_content[wifiindex]["starttime"] = timer_list[timerindex].start_time
              tod_content[wifiindex]["stoptime"] = timer_list[timerindex].stop_time
              tod_content[wifiindex]["enabled"] = timer_list[timerindex].enabled
              tod_content[wifiindex]["periodic"] = timer_list[timerindex].periodic
              tod_content[wifiindex]["name"] = timer_list[timerindex].name
            end
          end
        end
      end
    end
  end

  local aplists = {}
  local radioType = {}
  for _, iface in pairs(interface_list) do
    iface = iface.value
    apVal = findMatchingAP(iface)
    aplists[#aplists + 1] = apVal
    local radio = proxy.get("uci.wireless.wifi-iface.@"..iface..".device")[1].value
    radio = string.match(radio, "radio[_]?(%w+)")
    radioType[apVal] = radio
  end

  local splitMode = proxy.get("uci.multiap.controller_credentials.@cred1.state") and proxy.get("uci.multiap.controller_credentials.@cred1.state")[1].value

  local multiapAgent = proxy.get("uci.multiap.agent.enabled")
  multiapAgent = multiapAgent and multiapAgent[1].value or "0"

  if multiapAgent == "0" then
    splitMode = proxy.get("uci.web.network.@main.splitssid")
    splitMode = splitMode and splitMode[1].value or "1"
  end
  -- Based on the split/Merge mode tod rules will be updated
  if splitMode then
    local contentap = {}
    for index, content in pairs(tod_content) do
      local count = 1
      contentap["ap"] = content["ap"..count].ap
      contentap["ssid"] = content["ap"..count].ssid
      contentap["state"] = content["ap"..count].state
      count = count + 1
      -- pre-existing all rules are kept
      if (content.name == "" or content.name == "wifitod") and contentap.ap ~= "all" then
        local ssidName = contentap.ssid
        for i, v in pairs(aplists) do
          if splitMode == "0" or (splitMode == "1" and radioType[contentap.ap] == "2G") then
            proxy.set(format("%s@action%s.timers.@1.value", tod_action_path, index),"")
            proxy.del(format("uci.tod.timer.@timer%s.", index))
          end
        end
        -- TOD rules applicable on the 2.4 GHz are applied to 5 GHz and the pre-existing TOD rules for 5 GHz are removed.
        if splitMode == "0" then
          if radioType[contentap.ap] == "2G" then
            local success = proxy.add(tod_action_path, "action"..getRandomKey())
            ssidName = contentap.ssid:gsub("%((2.4G)%)", "")
            ssidName = ssidName .. " (2.4G and 5G)"
            index = success:match("action(.+)")
            proxy.add(tod_action_path .. "@" .. success .. ".timers.")
            proxy.add(tod_timer_path, "timer"..index)
            proxy.add(tod_wifitod_path, "wifitod"..index)
            setObject[format("%s@action%s.timers.@1.value", tod_action_path, index)] = "timer"..index
            setObject[format("%s@action%s.script", tod_action_path, index)] = "wifitodscript"
            setObject[format("%s@action%s.enabled", tod_action_path, index)] = "1"
            setObject[format("%s@action%s.object", tod_action_path, index)] = "wifitod.wifitod"..index
            setObject[format("%s@timer%s.start_time", tod_timer_path, index)] = content.starttime
            setObject[format("%s@timer%s.stop_time", tod_timer_path, index)] = content.stoptime
            for i, v in pairs(aplists) do
              proxy.add(tod_wifitod_path .. "@wifitod"..index..".ap.")
              proxy.add(tod_ap_path, v ..index)
              setObject[format("%s@wifitod%s.ap.@%s.value",  tod_wifitod_path, index, i)] = v .. index
              setObject[format("%s@%s.state", tod_ap_path, v.. index)] = contentap.state
              setObject[format("%s@%s%s.ap", tod_ap_path, v, index)] = v
              setObject[format("%s@%s%s.ssid", tod_ap_path, v, index)] = ssidName
            end
          end
        elseif splitMode == "1" then
          for i, v in pairs(aplists) do
            local wifiIntf = proxy.get("uci.wireless.wifi-ap.@"..v..".iface")[1].value
            local success = proxy.add(tod_action_path, "action"..getRandomKey())
            local ssidName = proxy.get("uci.wireless.wifi-iface.@"..wifiIntf..".ssid")[1].value
            local radio = proxy.get("uci.wireless.wifi-iface.@"..wifiIntf..".device")[1].value
            radio = string.match(radio, "radio[_]?(%w+)")
            if radio == "2G" then
              ssidName = ssidName .." (2.4G)"
            elseif radio == "5G" then
              ssidName = ssidName .. " (5G)"
            else
              ssidName = ssidName .. " (2)"
            end
            index = success:match("action(.+)")
            proxy.add(tod_action_path .. "@" .. success .. ".timers.")
            proxy.add(tod_timer_path, "timer"..index)
            proxy.add(tod_wifitod_path, "wifitod"..index)
            proxy.add(tod_wifitod_path .. "@wifitod"..index..".ap.")
            proxy.add(tod_ap_path, v ..index)
            setObject[format("%s@action%s.timers.@1.value", tod_action_path, index)] = "timer"..index
            setObject[format("%s@action%s.script", tod_action_path, index)] = "wifitodscript"
            setObject[format("%s@action%s.enabled", tod_action_path, index)] = "1"
            setObject[format("%s@action%s.object", tod_action_path, index)] = "wifitod.wifitod"..index
            setObject[format("%s@timer%s.start_time", tod_timer_path, index)] = content.starttime
            setObject[format("%s@timer%s.stop_time", tod_timer_path, index)] = content.stoptime
            setObject[format("%s@timer%s.name", tod_timer_path, index)] = "wifitod"
            setObject[format("%s@wifitod%s.ap.@1.value",  tod_wifitod_path, index)] = v .. index
            setObject[format("%s@%s.state", tod_ap_path, v.. index)] = contentap.state
            setObject[format("%s@%s%s.ap", tod_ap_path, v, index)] = v
            setObject[format("%s@%s%s.ssid", tod_ap_path, v, index)] = ssidName
          end
        end
      end
    end
    proxy.set(setObject)
    proxy.apply()
  end
end
