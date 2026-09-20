local content_helper = require("web.content_helper")
local proxy = require("datamodel")
local format = string.format
local content_atm = content_helper.convertResultToObject("uci.xtm.atmdevice.", proxy.get("uci.xtm.atmdevice."))
local content_ptm = content_helper.convertResultToObject("uci.xtm.ptmdevice.", proxy.get("uci.xtm.ptmdevice."))
if (content_atm and #content_atm > 0) or (content_ptm and #content_ptm > 0) then
  local atmdev = string.match(content_atm[1].paramindex,"^@(%S+)")
  local ptmdev = string.match(content_ptm[1].paramindex,"^@(%S+)")
local content = {
sfp_enabled = "uci.env.rip.sfp",
}
content_helper.getExactContent(content)

if content["sfp_enabled"] == "1" then
  return {
      {
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
      },
      {
          name = "vdsl",
          default = false,
          description = "VDSL2",
          view = "broadband-vdsl-advanced.lp",
          card = "002_broadband_xdsl.lp",
          check = {
              { "uci.network.interface.@wan.ifname", format("^%s$",ptmdev)},
          },
          operations = {
              { "uci.network.interface.@wan.ifname", ptmdev},
          },
      },
      {
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
      },
      {
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
      },
  }
  else
  return {
      {
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
      },
      {
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
      },
      {
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
      },
  }
 end
end
