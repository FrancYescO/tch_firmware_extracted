local intl = require("web.intl")
local function log_gettext_error(msg)
  ngx.log(ngx.NOTICE, msg)
end
local gettext = intl.load_gettext(log_gettext_error)
local T = gettext.gettext
local N = gettext.ngettext

local function setlanguage()
  gettext.language(ngx.header['Content-Language'])
end
gettext.textdomain('webui-core')

local M = {}
function M.getvalue ()
  setlanguage()
  return {
    {
        name = "pppoe",
        default = true,
        description = T"PPPoE routed mode",
        view = "internet-pppoe-routed.lp",
        card = "003_internet_pppoe_routed.lp",
        check = {
            { "uci.network.interface.@wan.proto", "^pppoe$"},
        },
        operations = {
            { "uci.network.interface.@wan.proto", "pppoe"},
            { "uci.network.interface.@wan.type", ""},
            { "uci.network.interface.@wan.ifname",""},
            { "uci.network.interface.@wan.auto", "0"},
            { "uci.network.interface.@lan.ifname","eth0 eth1 eth2 eth3"},
            { "uci.dhcp.dhcp.@lan.ignore", "0" },
            { "uci.wireless.wifi-device.@radio_2G.state", "1"},
            { "uci.wireless.wifi-device.@radio_5G.state", "1"},
            { "uci.wireless.wifi-iface.@wl0.state", "1"},
            { "uci.wireless.wifi-iface.@wl1.state", "1"},
            { "uci.wansensing.global.enable", "1"},
	    { "uci.network.bcmvopi.@atm_8_35_v0.vid", "0"},
	    { "uci.network.bcmvopi.@atm_8_81_v0.vid", "0"},
            { "uci.ethernet.port.@eth0.speed", "auto"},
            { "uci.ethernet.port.@eth1.speed", "auto"},
            { "uci.ethernet.port.@eth2.speed", "auto"},
            { "uci.ethernet.port.@eth3.speed", "auto"},
        },
    },
    {
        name = "bridge",
        default = false,
        description = T"Bridged mode",
        view = "internet-bridged.lp",
        card = "003_internet_bridged.lp",
        check = {
            { "uci.network.interface.@wan.ifname","^eth0 eth1 eth2 eth3 atm_8_35 atm_8_81 ptm0_v881 eth4_v881 eth4_v981$"},
            { "uci.network.interface.@wan.auto", "^1$"},
        },
        operations = {
            { "uci.network.interface.@ppp_8_35.auto", "0"},
            { "uci.network.interface.@ppp_8_81.auto", "0"},
            { "uci.network.interface.@wan.type", "bridge"},
            { "uci.network.interface.@wan.ifname","eth0 eth1 eth2 eth3 atm_8_35 atm_8_81 ptm0_v881 eth4_v881 eth4_v981"},
            { "uci.network.interface.@wan.auto", "1"},
            { "uci.network.interface.@wan.proto", ""},
            { "uci.network.interface.@lan.ifname",""},
            { "uci.dhcp.dhcp.@lan.ignore", "1" },
            { "uci.wireless.wifi-device.@radio_2G.state", "0"},
            { "uci.wireless.wifi-device.@radio_5G.state", "0"},
            { "uci.wireless.wifi-iface.@wl0.state", "0"},
            { "uci.wireless.wifi-iface.@wl1.state", "0"},
	    { "uci.network.bcmvopi.@atm_8_35_v0.vid", "-1"},
	    { "uci.network.bcmvopi.@atm_8_81_v0.vid", "-1"},
            { "uci.ethernet.port.@eth0.speed", "auto"},
            { "uci.ethernet.port.@eth1.speed", "auto"},
            { "uci.ethernet.port.@eth2.speed", "auto"},
            { "uci.ethernet.port.@eth3.speed", "auto"},
        },
    },
    {
        name = "tpv_10",
        default = false,
        description = T"Business TPV 10/FD",
        view = "internet-bridged.lp",
        card = "003_internet_bridged.lp",
        check = {
            { "uci.network.interface.@wan.ifname","^eth0 eth1 eth2 eth3 atm_8_35 atm_8_81 ptm0_v881 eth4_v881 eth4_v981$"},
            { "uci.network.interface.@wan.auto", "^1$"},
        },
        operations = {
            { "uci.network.interface.@ppp_8_35.auto", "0"},
            { "uci.network.interface.@ppp_8_81.auto", "0"},
            { "uci.network.interface.@wan.type", "bridge"},
            { "uci.network.interface.@wan.ifname","eth0 eth1 eth2 eth3 atm_8_35 atm_8_81 ptm0_v881 eth4_v881 eth4_v981"},
            { "uci.network.interface.@wan.auto", "1"},
            { "uci.network.interface.@wan.proto", ""},
            { "uci.network.interface.@lan.ifname",""},
            { "uci.dhcp.dhcp.@lan.ignore", "1" },
            { "uci.wireless.wifi-device.@radio_2G.state", "0"},
            { "uci.wireless.wifi-device.@radio_5G.state", "0"},
            { "uci.wireless.wifi-iface.@wl0.state", "0"},
            { "uci.wireless.wifi-iface.@wl1.state", "0"},
	    { "uci.network.bcmvopi.@atm_8_35_v0.vid", "-1"},
	    { "uci.network.bcmvopi.@atm_8_81_v0.vid", "-1"},
	    { "uci.ethernet.port.@eth0.speed", "10"},
	    { "uci.ethernet.port.@eth1.speed", "10"},
	    { "uci.ethernet.port.@eth2.speed", "10"},
	    { "uci.ethernet.port.@eth3.speed", "10"},
        },
    },
	{
        name = "tpv_100",
        default = false,
        description = T"Business TPV 100/FD",
        view = "internet-bridged.lp",
        card = "003_internet_bridged.lp",
        check = {
            { "uci.network.interface.@wan.ifname","^eth0 eth1 eth2 eth3 atm_8_35 atm_8_81 ptm0_v881 eth4_v881 eth4_v981$"},
            { "uci.network.interface.@wan.auto", "^1$"},
        },
        operations = {
            { "uci.network.interface.@ppp_8_35.auto", "0"},
            { "uci.network.interface.@ppp_8_81.auto", "0"},
            { "uci.network.interface.@wan.type", "bridge"},
            { "uci.network.interface.@wan.ifname","eth0 eth1 eth2 eth3 atm_8_35 atm_8_81 ptm0_v881 eth4_v881 eth4_v981"},
            { "uci.network.interface.@wan.auto", "1"},
            { "uci.network.interface.@wan.proto", ""},
            { "uci.network.interface.@lan.ifname",""},
            { "uci.dhcp.dhcp.@lan.ignore", "1" },
            { "uci.wireless.wifi-device.@radio_2G.state", "0"},
            { "uci.wireless.wifi-device.@radio_5G.state", "0"},
            { "uci.wireless.wifi-iface.@wl0.state", "0"},
            { "uci.wireless.wifi-iface.@wl1.state", "0"},
	    { "uci.network.bcmvopi.@atm_8_35_v0.vid", "-1"},
	    { "uci.network.bcmvopi.@atm_8_81_v0.vid", "-1"},
	    { "uci.ethernet.port.@eth0.speed", "100"},
	    { "uci.ethernet.port.@eth1.speed", "100"},
	    { "uci.ethernet.port.@eth2.speed", "100"},
	    { "uci.ethernet.port.@eth3.speed", "100"},
        },
    },
  }
end
return M
