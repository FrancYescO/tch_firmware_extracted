local M = {}

local uci_helper = require("transformer.mapper.ucihelper")
local foreach_on_uci = uci_helper.foreach_on_uci
local ethBinding = { config = "ethernet", sectionname = "port"}
local networkBinding = { config = "network" }
local xtmBinding = { config = "xtm"}
local wirelessBinding = { config = "wireless"}

-- Get all the devices of Ethernet/ATM/PTM/WiFi including VLAN and Bridge devices.
-- Based on the device name, respective Device-2 object will be resolved for LowerLayers Parameter.
function M.get_devices_for_lowerlayers()
  local allDevices = {}
  networkBinding.sectionname = "device"
  foreach_on_uci(networkBinding,function(device)
    if device.type == "8021q" then
      allDevices[device.name] = "Device.Ethernet.VLANTermination.{i}."
    end
  end)

  foreach_on_uci(ethBinding,function(ethDevice)
    allDevices[ethDevice[".name"]] = "Device.Ethernet.Interface.{i}."
  end)

  networkBinding.sectionname = "interface"
  foreach_on_uci(networkBinding,function(device)
    if device.type == "bridge" and device.ifname then
      allDevices[device.ifname] = "Device.Bridging.Bridge.{i}.Port.{i}."
    end
  end)

  xtmBinding.sectionname = "atmdevice"
  foreach_on_uci(xtmBinding,function(atmDevice)
    allDevices[atmDevice[".name"]] = "Device.ATM.Link.{i}."
  end)

  xtmBinding.sectionname = "ptmdevice"
  foreach_on_uci(xtmBinding,function(ptmDevice)
    allDevices[ptmDevice[".name"]] = "Device.PTM.Link.{i}."
  end)

  wirelessBinding.sectionname = "wifi-iface"
  foreach_on_uci(wirelessBinding,function(ssidDevice)
    allDevices[ssidDevice[".name"]] = "Device.WiFi.SSID.{i}."
  end)

  wirelessBinding.sectionname = "wifi-device"
  foreach_on_uci(wirelessBinding,function(radioDevice)
    allDevices[radioDevice[".name"]] = "Device.WiFi.Radio.{i}."
  end)
  return allDevices
end

return M
