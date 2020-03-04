local proxy = require("datamodel")
local variant = proxy.get("uci.env.var.iinet_variant")
variant = variant and variant[1].value

local checks = {
    adsl = {
        {
            { "uci.network.interface.@wan.ifname", "^atm_" },
        },
        {
            { "uci.network.interface.@wan.ifname", "" },
            { "uci.wansensing.global.enable", "1" },
            { "uci.wansensing.global.l2type", "ADSL" },
        },
    },
    vdsl ={
        {
            { "uci.network.interface.@wan.ifname", "^ptm0$" },
        },
        {
            { "uci.network.interface.@wan.ifname", "" },
            { "uci.wansensing.global.enable", "1" },
            { "uci.wansensing.global.l2type", "VDSL" },
            { "uci.network.interface.@vlan_ppp.ifname", "" },
        },
    },
    vdslVLAN ={
        {
            { "uci.network.interface.@wan.ifname", "^vlan_ppp$" },
            { "uci.network.device.@vlan_ppp.ifname", "^ptm0$" }
        },
        {
            { "uci.network.interface.@wan.ifname", "" },
            { "uci.wansensing.global.enable", "1" },
            { "uci.wansensing.global.l2type", "VDSL" },
            { "uci.network.interface.@vlan_ppp.ifname", "^ptm0$" },
        },
    },
    ethernet = {
        {
            { "uci.network.interface.@wan.ifname", "^eth4$" },
        },
        {
            { "uci.network.interface.@wan.ifname", "" },
            { "uci.wansensing.global.enable", "1" },
            { "uci.wansensing.global.l2type", "ETH" },
            { "uci.network.interface.@vlan_hfc.ifname", "" },
        },
    },
    ethernetVLAN ={
        {
            { "uci.network.interface.@wan.ifname", "^vlan_hfc$" },
            { "uci.network.device.@vlan_hfc.ifname", "^eth4$" }
        },
        {
            { "uci.network.interface.@wan.ifname", "" },
            { "uci.wansensing.global.enable", "1" },
            { "uci.wansensing.global.l2type", "ETH" },
            { "uci.network.interface.@vlan_hfc.ifname", "^eth4$" },
        },
    },
}

if variant == "novas" then
  checks = {
    adsl = {
        {
            { "uci.network.interface.@wan.ifname", "^atm_" },
        },
    },
    vdsl ={
        {
            { "uci.network.interface.@wan.ifname", "^ptm0$" },
        },
    },
    vdslVLAN ={
        {
            { "uci.network.interface.@wan.ifname", "^vlan_hfc$" },
            { "uci.network.device.@vlan_hfc.ifname", "^ptm0$" }
        },
    },
    ethernet = {
        {
            { "uci.network.interface.@wan.ifname", "^eth4$" },
        },
    },
    ethernetVLAN ={
        {
            { "uci.network.interface.@wan.ifname", "^vlan_hfc$" },
            { "uci.network.device.@vlan_hfc.ifname", "^eth4$" }
        },
    },
  }
end

local function get_check_wan_type(wan_type)
    return function()
        local content_cache = {}
        local check = checks[wan_type]
        if type(check) == "table" then
            for _,v in ipairs(check) do
                local ok = true
                -- array of pairs { transformer path, value }, do an equality check on each one of those and then and
                for _,s in ipairs(v) do
                    if #s ~= 2 then
                        ok = false
                    else
                        if not content_cache[s[1]] then
                            local data = proxy.get(s[1])
                            if not data then
                                ok = false
                            else
                                local value = data[1].value
                                content_cache[s[1]] = value
                            end
                        end
                        ok = ok and string.find(content_cache[s[1]],s[2])
                    end
                end
                if ok then
                    return wan_type
                end
            end
        end
        return
    end
end

local helper = {
    {
        name = "adsl",
        default = true,
        description = "ADSL2+",
        view = "broadband-xdsl.lp",
        card = "002_broadband_xdsl.lp",
        check = get_check_wan_type("adsl"),
        operations = {
            { "uci.network.interface.@wan.ifname", "atm_ppp" },
        },
    },
    {
        name = "vdsl",
        default = false,
        description = "VDSL with no VLAN",
        view = "broadband-xdsl.lp",
        card = "002_broadband_xdsl.lp",
        check = get_check_wan_type("vdsl"),
        operations = {
            { "uci.network.interface.@wan.ifname", "ptm0" },
        },
    },
    {
        name = "vdslvlan",
        default = false,
        description = "VDSL using VLAN",
        view = "broadband-xdsl.lp",
        card = "002_broadband_xdsl.lp",
        check = get_check_wan_type("vdslVLAN"),
        operations = {
            { "uci.network.interface.@wan.ifname", "vlan_ppp" },
            { "uci.network.device.@vlan_ppp.ifname", "ptm0" },
        },
    },
    {
        name = "ethernet",
        default = false,
        description = "Ethernet",
        view = "broadband-ethernet.lp",
        card = "002_broadband_ethernet.lp",
        check = get_check_wan_type("ethernet"),
        operations = {
            { "uci.network.interface.@wan.ifname", "eth4" },
        },
    },
    {
        name = "ethernetvlan",
        default = false,
        description = "Ethernet using VLAN",
        view = "broadband-ethernet.lp",
        card = "002_broadband_ethernet.lp",
        check = get_check_wan_type("ethernetVLAN"),
        operations = {
            { "uci.network.interface.@wan.ifname", "vlan_hfc" },
            { "uci.network.device.@vlan_hfc.ifname", "eth4" },
        },
    },
}

local function get(wan_proto)
    if not wan_proto then
        return helper
    end
    local bmh_operations = {
        adsl = {
            ipoe = {
                { "uci.network.interface.@wan.ifname", "atm_ipoe" },
            },
            ppp = {
                { "uci.network.interface.@wan.ifname", "atm_ppp" },
            }
        },
        vdsl = {
            ipoe = {
                { "uci.network.interface.@wan.ifname", "ptm0" },
            },
            ppp = {
                { "uci.network.interface.@wan.ifname", "ptm0" },
            },
        },
        vdslvlan = {
            ipoe = {
                { "uci.network.device.@vlan_ppp.ifname", "ptm0" },
                { "uci.network.interface.@wan.ifname", "vlan_ppp" },
            },
            ppp = {
                { "uci.network.device.@vlan_ppp.ifname", "ptm0" },
                { "uci.network.interface.@wan.ifname", "vlan_ppp" },
            },
        },
        ethernet = {
            ipoe = {
                { "uci.network.interface.@wan.ifname", "eth4" },
            },
            ppp = {
                 { "uci.network.interface.@wan.ifname", "eth4" },
            },
        },
        ethernetvlan = {
            ipoe = {
                { "uci.network.device.@vlan_hfc.ifname", "eth4" },
                { "uci.network.device.@vlan_hfc.auto", "1" },
                { "uci.network.interface.@wan.ifname", "vlan_hfc" },
            },
            ppp = {
                { "uci.network.device.@vlan_hfc.ifname", "eth4" },
                { "uci.network.device.@vlan_hfc.auto", "1" },
                { "uci.network.interface.@wan.ifname", "vlan_hfc" },
            },
        }
    }
    if variant == "novas" then
      bmh_operations = {
        adsl = {
            ipoe = {
                { "uci.network.interface.@wan.ifname", "atm_ppp" },
                { "uci.network.interface.@ipoe.auto", "0" },
            },
            ppp = {
                { "uci.network.interface.@wan.ifname", "atm_ppp" },
                { "uci.network.interface.@ipoe.auto", "0" },
            }
        },
        vdsl = {
            ipoe = {
                { "uci.network.interface.@wan.ifname", "ptm0" },
                { "uci.network.interface.@ipoe.auto", "0" },
            },
            ppp = {
                { "uci.network.interface.@wan.ifname", "ptm0" },
                { "uci.network.interface.@ipoe.auto", "0" },
            },
        },
        vdslvlan = {
            ipoe = {
                { "uci.network.device.@vlan_hfc.ifname", "ptm0" },
                { "uci.network.interface.@wan.ifname", "vlan_hfc" },
            },
            ppp = {
                { "uci.network.device.@vlan_hfc.ifname", "ptm0" },
                { "uci.network.interface.@wan.ifname", "vlan_hfc" },
            },
        },
        ethernet = {
            ipoe = {
                { "uci.network.interface.@wan.ifname", "eth4" },
                { "uci.network.interface.@ipoe.auto", "0" },
            },
            ppp = {
                { "uci.network.interface.@wan.ifname", "eth4" },
                { "uci.network.interface.@ipoe.auto", "0" },
            },
        },
        ethernetvlan = {
            ipoe = {
                { "uci.network.device.@vlan_hfc.ifname", "eth4" },
                { "uci.network.interface.@wan.ifname", "vlan_hfc" },
            },
            ppp = {
                { "uci.network.device.@vlan_hfc.ifname", "eth4" },
                { "uci.network.interface.@wan.ifname", "vlan_hfc" },
            },
        }
      }
    end
    for _,v in ipairs(helper) do
        local proto_mode
        if wan_proto == "static" or wan_proto == "dhcp" then
            proto_mode = "ipoe"
        else
            proto_mode = "ppp"
        end
        v.operations = bmh_operations[v.name][proto_mode]
        if wan_proto == "pppoa" and v.name ~= "adsl" then
            local operations = v["operations"]
            operations[#operations+1] = {"uci.network.interface.@wan.proto", "pppoe"}
            operations[#operations+1] = {"uci.network.interface.@wan.metric", "10"}
            operations[#operations+1] = {"uci.network.interface.@wan.keepalive", "4,20"}
            operations[#operations+1] = {"uci.network.interface.@wan.vpi", ""}
            operations[#operations+1] = {"uci.network.interface.@wan.vci", ""}
        end
    end
    return helper
end

return { get = get }
