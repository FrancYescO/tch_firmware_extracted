local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local format = string.format
local M = {}
function M.broadBandDetails()
  local content = {
  sfp_enabled = "uci.env.rip.sfp",
  hardware_version = "uci.env.var.hardware_version",
  ethwan_support = "sys.eth.WANCapable",
  intf_ifname = "uci.network.interface.@wan.ifname",
  }
  content_helper.getExactContent(content)
  local broadBand_mode = {}
  local atmPath = proxy.get("uci.xtm.atmdevice.")
  local ptmPath = proxy.get("uci.xtm.ptmdevice.")
  local content_atm = content_helper.convertResultToObject("uci.xtm.atmdevice.", atmPath)
  local content_ptm = content_helper.convertResultToObject("uci.xtm.ptmdevice.", ptmPath)
  local atmdev, ptmdev, checkPath, operationPath
  if #content_atm > 0 then
    atmdev = string.match(content_atm[1].paramindex,"^@(%S+)")
  end
  if #content_ptm > 0 then
    ptmdev = string.match(content_ptm[1].paramindex,"^@(%S+)")
  end
  -- Checks whether EthWAN is tagged or not
  -- @return #boolean or #string, if EthWAN is tagged  return the interface name, else returns false
  local function isEthTagged()
    local interfaceName = content and content.intf_ifname
    if interfaceName then
      local deviceDetails = proxy.get(format("uci.network.device.@%s.ifname", interfaceName))
      if deviceDetails and deviceDetails[1].value == "eth4" then
        return interfaceName
      end
    end
    return false
  end
  -- Populate the check and operation paths based on sfp enabled and ethwan type.
  local function operationChecks(sfpEnabled)
    local deviceName = isEthTagged()
    local interfacePath = "uci.network.interface.@wan.ifname"
    local lanWanModePath = "uci.ethernet.globals.eth4lanwanmode"
    if deviceName and sfpEnabled then
      checkPath = { interfacePath, format("^%s", deviceName)}, { lanWanModePath,"^0"}
      operationPath = { interfacePath, format("%s", deviceName)}, { lanWanModePath,"0"}
    elseif deviceName then
      checkPath = { interfacePath, format("^%s", deviceName)}
      operationPath = { interfacePath, format("%s", deviceName)}
    elseif sfpEnabled then
      checkPath = { interfacePath, "^eth4"}, { lanWanModePath,"^0"}
      operationPath = { interfacePath, "eth4"}, { lanWanModePath,"0"}
    else
      checkPath = { interfacePath, "^eth4"}
      operationPath = { interfacePath, "eth4"}
    end
  end
  if atmdev then
    broadBand_mode[#broadBand_mode+1] = {
      name = "adsl",
      default = false,
      description = "ADSL2+",
      view = "broadband-adsl-advanced.lp",
      card = "002_broadband_xdsl.lp",
      check = {
        { "uci.network.interface.@wan.ifname", format("^%s$",atmdev)},
      },
      operations = {
        { "uci.network.interface.@wan.ifname", atmdev},
      },
    }
  end
  if ptmdev then
    broadBand_mode[#broadBand_mode+1] = {
      name = "vdsl",
      default = true,
      description = "VDSL2",
      view = "broadband-vdsl-advanced.lp",
      card = "002_broadband_xdsl.lp",
      check = {
        { "uci.network.interface.@wan.ifname", format("^%s$",ptmdev)},
      },
      operations = {
        { "uci.network.interface.@wan.ifname", ptmdev},
      },
    }
  end
  local hardware_version = content["hardware_version"]
  -- For GPON platform, return directly. All gpon related, need to implement in webui-gpon
  -- For DSL platform supported SFP, not return
  if hardware_version and string.sub(hardware_version, 1, 1) == "G" then
    return broadBand_mode
  end
  if content["sfp_enabled"] == "1" then
    if content["ethwan_support"] ~= "" then
      operationChecks(true)
      broadBand_mode[#broadBand_mode+1] = {
        name = "ethernet",
        default = false,
        description = "Ethernet",
        view = "broadband-ethernet-advanced.lp",
        card = "002_broadband_ethernet.lp",
        check = {checkPath},
        operations = {operationPath},
      }
    end
    broadBand_mode[#broadBand_mode+1] = {
      name = "gpon",
      default = true,
      description = "GPON",
      view = "broadband-gpon-advanced.lp",
      card = "002_broadband_gpon.lp",
      check = {
        { "uci.network.interface.@wan.ifname", "^eth4"},
        { "uci.ethernet.globals.eth4lanwanmode","^1"},
      },
      operations = {
        { "uci.network.interface.@wan.ifname", "eth4"},
        { "uci.ethernet.globals.eth4lanwanmode","1"},
      },
    }
  else
    if content["ethwan_support"] ~= "" then
      operationChecks(false)
      broadBand_mode[#broadBand_mode+1] = {
        name = "ethernet",
        default = false,
        description = "Ethernet",
        view = "broadband-ethernet-advanced.lp",
        card = "002_broadband_ethernet.lp",
        check = {checkPath},
        operations = {operationPath},
      }
    end
  end
  return broadBand_mode
end
return M
