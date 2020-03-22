local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local format = string.format
local content = {
  sfp_enabled = "uci.env.rip.sfp",
  ethwan_support = "sys.eth.WANCapable",
}
content_helper.getExactContent(content)

local broadBand_mode = {}
local atmPath = proxy.get("uci.xtm.atmdevice.")
local ptmPath = proxy.get("uci.xtm.ptmdevice.")
local content_atm = content_helper.convertResultToObject("uci.xtm.atmdevice.", atmPath)
local content_ptm = content_helper.convertResultToObject("uci.xtm.ptmdevice.", ptmPath)
local atmdev, ptmdev
if #content_atm > 0 then
  atmdev = string.match(content_atm[1].paramindex,"^@(%S+)")
end
if #content_ptm > 0 then
  ptmdev = string.match(content_ptm[1].paramindex,"^@(%S+)")
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

if content["sfp_enabled"] == "1" then
  if content["ethwan_support"] ~= "" then
    broadBand_mode[#broadBand_mode+1] = {
      name = "ethernet",
      default = false,
      description = "Ethernet",
      view = "broadband-ethernet-advanced.lp",
      card = "002_broadband_ethernet.lp",
      check = {
        { "uci.network.interface.@wan.ifname", "^eth4"},
        { "uci.ethernet.globals.eth4lanwanmode","^0"},
      },
      operations = {
        { "uci.network.interface.@wan.ifname", "eth4"},
        { "uci.ethernet.globals.eth4lanwanmode","0"},
      },
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
    broadBand_mode[#broadBand_mode+1] = {
      name = "ethernet",
      default = false,
      description = "Ethernet",
      view = "broadband-ethernet-advanced.lp",
      card = "002_broadband_ethernet.lp",
      check = {
        { "uci.network.interface.@wan.ifname", "^eth4"},
      },
      operations = {
        { "uci.network.interface.@wan.ifname", "eth4"},
      },
    }
  end
end
return broadBand_mode
