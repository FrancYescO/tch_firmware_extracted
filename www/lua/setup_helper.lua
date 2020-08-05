local proxy = require("datamodel")
local format = string.format
local getdata = proxy.get("uci.env.custovar.wan_vlan_default","uci.env.custovar.vci","uci.env.custovar.vpi","uci.env.custovar.enc","uci.env.custovar.ulp","uci.env.custovar.mtu_adsl","uci.env.custovar.mtu_vdsl","uci.env.custovar.mtu_eth")
local vlan_default = getdata[1].value
local vci = getdata[2].value
local vpi = getdata[3].value
local enc = getdata[4].value
local ulp = getdata[5].value
local mtu_adsl = getdata[6].value
local mtu_vdsl = getdata[7].value
local l2_mtu_vdsl = tostring(tonumber(mtu_vdsl)+8)
local mtu_eth = getdata[8].value
local l2_mtu_eth = tostring(tonumber(mtu_eth)+8)
local adsl_ppp = "pppoa"
if ulp ~= "ppp" then adsl_ppp = "pppoe" end 
if not vlan_default then vlan_default = "101" end
return {
    {
        name = "ADSL",
        default = true,
        description = "ADSL",
        view = "setup-adsl.lp",
        operations = {
            { "uci.ethoam.global.enable","0", "set"},  
            { "uci.env.custovar.setup", "ADSL", "set"},
            { "uci.xtm.atm0.vpi", vpi, "set"},
            { "uci.xtm.atm0.vci", vci, "set"},
            { "uci.xtm.atm0.enc", enc, "set"},
            { "uci.xtm.atm0.ulp", ulp, "set"},
            { "uci.network.interface.@wan.type", ""},
            { "uci.network.interface.@wan.vpi", vpi, "set"},
            { "uci.network.interface.@wan.vci", vci, "set"},
            { "uci.network.interface.@wan.authfail","0", "set"},
            { "uci.network.interface.@wan.mtu",mtu_adsl, "set"},
            { "uci.network.interface.@lan.ifname","eth0 eth1 eth2 eth3 eth5", "set"}, 
            { "uci.network.interface.@wan.proto", adsl_ppp, "set"},
            { "uci.network.interface.@wan.ifname","atm0", "set"},
            { "uci.network.interface.@bt_iptv.auto","0", "set"},
            { "uci.env.custovar.WS", "2"},
            { "uci.wansensing.global.enable","0"},
        },
    },
    {
        name = "VDSL",
        default = false,
        description = "VDSL",
        view = "setup-vdsl.lp",
        operations = {              
            { "uci.env.custovar.setup", "VDSL", "set"},
            { "uci.env.custovar.wan_vlan_enabled", "1", "set" },
            { "uci.env.custovar.wan_vlan", vlan_default , "set"},
            { "uci.network.interface.@wan.ifname","vlan_wan", "set"},
            { "uci.network.device.@vlan_wan.vid",vlan_default, "set"},
            { "uci.network.device.@vlan_wan.ifname","ptm0", "set"},
            { "uci.network.device.@vlan_wan.mtu",l2_mtu_vdsl, "set"},
            { "uci.network.device.@ptm0.mtu",l2_mtu_vdsl, "set"},
            { "uci.network.interface.@wan.type", ""},
            { "uci.network.interface.@wan.authfail","0", "set"},
            { "uci.network.interface.@wan.mtu",mtu_vdsl, "set"},
            { "uci.network.interface.@lan.ifname","eth0 eth1 eth2 eth3 eth5", "set"}, 
            { "uci.network.interface.@wan.proto", "pppoe", "set"},
            { "uci.network.interface.@bt_iptv.auto","1", "set"}, 
            { "uci.env.custovar.WS", "2"},
	    { "uci.ethoam.configuration.@config1.ifname","vlan_wan", "set"},
            { "uci.ethoam.configuration.@config2.ifname","vlan_wan", "set"},
	    { "uci.ethoam.global.enable","1", "set"},
	    { "uci.wansensing.global.enable","0"},
        },
    },
    {
        name = "ETH",
        default = false,
        description = "Ethernet Port 5",
        view = "setup-eth.lp",
        operations = { 
            { "uci.ethoam.global.enable","0", "set"},                 
            { "uci.env.custovar.setup", "ETH", "set"},
            { "uci.env.custovar.wan_vlan_enabled", "0", "set" },
            { "uci.env.custovar.wan_vlan", vlan_default, "set" },
            { "uci.network.interface.@wan.type", ""},
            { "uci.network.interface.@wan.ifname","eth4", "set"},
            { "uci.network.interface.@wan.authfail","0", "set"},
            { "uci.network.interface.@wan.mtu",mtu_eth, "set"},
            { "uci.network.device.@vlan_wan.mtu",l2_mtu_eth, "set"},
            { "uci.network.device.@eth4.mtu",l2_mtu_eth, "set"},
            { "uci.network.interface.@lan.ifname","eth0 eth1 eth2 eth3 eth5", "set"}, 
            { "uci.network.interface.@wan.proto", "pppoe", "set"},
            { "uci.network.interface.@bt_iptv.auto","0", "set"},
            { "uci.env.custovar.WS", "2"},
        },
    },
}