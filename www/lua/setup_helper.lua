local proxy = require("datamodel")
local format = string.format
local getdata = proxy.get("uci.env.var.wan_vlan_default","uci.env.var.vci","uci.env.var.vpi","uci.env.var.enc","uci.env.var.ulp","uci.env.var.mtu_adsl","uci.env.var.mtu_vdsl","uci.env.var.mtu_eth")
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
            { "uci.env.var.setup", "ADSL", "set"},
            --{ "uci.xtm.atmdevice.@atm0.vpi", vpi, "set"},
            --{ "uci.xtm.atmdevice.@atm0.vci", vci, "set"},
            --{ "uci.xtm.atmdevice.@atm0.enc", enc, "set"},
            --{ "uci.xtm.atmdevice.@atm0.ulp", ulp, "set"},
            { "uci.env.var.setup", "ADSL", "set"},
            { "uci.network.interface.@wan.type", ""},
            { "uci.network.interface.@wan.vpi", vpi, "set"},
            { "uci.network.interface.@wan.vci", vci, "set"},
            { "uci.network.interface.@wan.authfail","0", "set"},
            --{ "uci.network.interface.@wan.password","", "set"},
            { "uci.network.interface.@wan.mtu",mtu_adsl, "set"},
            { "uci.network.interface.@lan.ifname","eth0 eth1 eth2 eth3", "set"}, 
            { "uci.network.config.wan_mode", "pppoe", "set"},
            { "uci.network.interface.@wan.proto", adsl_ppp, "set"},
            { "uci.network.interface.@wan.ifname","atm0", "set"},
            { "uci.network.interface.@bt_iptv.auto","0", "set"},
            { "uci.ethoam.global.enable","0", "set"},
            { "uci.env.var.WS", "2"},
        },
    },
    {
        name = "VDSL",
        default = false,
        description = "VDSL",
        view = "setup-vdsl.lp",
        operations = {
            { "uci.env.var.setup", "VDSL", "set"},
            { "uci.env.var.wan_vlan_enabled", "1", "set" },
            { "uci.env.var.wan_vlan", vlan_default , "set"},
            { "uci.network.interface.@wan.ifname","wan_vlan", "set"},
            { "uci.network.device.@vlan_wan.vid",vlan_default, "set"},
            { "uci.network.device.@vlan_wan.ifname","ptm0", "set"},
            { "uci.network.device.@vlan_wan.mtu",l2_mtu_vdsl, "set"},
            { "uci.network.device.@ptm0.mtu",l2_mtu_vdsl, "set"},
            { "uci.network.interface.@wan.type", ""},
            { "uci.network.interface.@wan.authfail","0", "set"},
            { "uci.network.interface.@wan.mtu",mtu_vdsl, "set"},
           -- { "uci.network.interface.@wan.password","", "set"},
            { "uci.network.interface.@lan.ifname","eth0 eth1 eth2 eth3", "set"}, 
            { "uci.network.config.wan_mode", "pppoe", "set"},
            { "uci.network.interface.@wan.proto", "pppoe", "set"},
            { "uci.network.interface.@bt_iptv.auto","1", "set"},
            { "uci.ethoam.configuration.@config1.vlan",vlan_default, "set"},   
            { "uci.ethoam.configuration.@config2.vlan",vlan_default, "set"},       
            { "uci.ethoam.global.enable","1", "set"},
            { "uci.env.var.WS", "2"},
        },
    },
    
}