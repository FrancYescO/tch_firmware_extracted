local ipairs, string = ipairs, string
local proxy = require("datamodel")
local gmatch = string.gmatch
local find, gsub = string.find, string.gsub

local function convertResultToObject(basepath, results)
  local indexstart, indexmatch, subobjmatch, parsedIndex = false
  local data = {}
  local output = {}
  if basepath then
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
          if subobjmatch then
            data[indexmatch][subobjmatch .. v.param] = v.value
          end
        end
      end
    end
  end
  return output
end

local sysPath = "sys.hosts.host."
local rpcMultiapPath = "rpc.multiap.device."
local easymeshDevicesPath = "uci.easymesh_devices.name.@user.user_mac."

local devicesList = convertResultToObject(sysPath, proxy.get(sysPath))
local rpcMultiapDevicesData = convertResultToObject(rpcMultiapPath, proxy.get(rpcMultiapPath))
local easymeshDevicesData = convertResultToObject(easymeshDevicesPath, proxy.get(easymeshDevicesPath))
local setFriendlyName = false

-- Iterate over the devices list obtained from multiAP- rpc.multiap.device.
for _, device in pairs(rpcMultiapDevicesData) do
  -- Each and every device should now be iterated with devices list from sys.hosts.host
  for _, host in pairs(devicesList) do
    -- In the parameter macList with the seperation of , every mac in the list is now compared with the sys.host MACAddress
    for mac in device.local_interfaces:gmatch('([^,]+)') do
      if host.MACAddress and host.MACAddress == mac then
        setFriendlyName = true
        break
      end
    end

    for _, macAdd in pairs(easymeshDevicesData) do
      if macAdd.value == host.MACAddress then
        setFriendlyName = false
      end
    end

    if setFriendlyName and host.paramindex then
      setFriendlyName = false
      device.serial_number = device.serial_number and device.serial_number ~= "" and device.serial_number or "UnknownName"
      local _, err = proxy.set(sysPath .. host.paramindex .. ".FriendlyName", device.serial_number)
      local index = proxy.add("uci.easymesh_devices.name.@user.user_mac.")
      if index and index ~= "" then
        _, err = proxy.set(string.format("uci.easymesh_devices.name.@user.user_mac.@%s.value", index ), host.MACAddress)
      end
      if not err then
        proxy.apply()
        break
      end
    end

  end
end

return
