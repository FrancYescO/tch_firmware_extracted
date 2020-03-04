local content_helper = require ("web.content_helper")
local wan_interface_path ="uci.network.interface.@wan."
local atm_device_path = "uci.xtm.atmdevice.@atm_ppp."

local content_params = {
    variant = "uci.env.var.iinet_variant",
}
content_helper.getExactContent(content_params)

local helper={
    {
        name = "unconfigured",
        default = true,
        description = "Unconfigured",
        view = "internet-default.lp",
        card = "003_internet_default.lp",
        check = {
            { wan_interface_path .. "proto", "fake"}, -- will be triggered as default if other fail
        },
        operations = {
            { wan_interface_path .. "ifname", ""},
            { wan_interface_path .. "proto", ""},
        },
    },
    {
        name = "dhcp",
        default = false,
        description = "DHCP routed mode",
        view = "internet-dhcp-routed.lp",
        card = "003_internet_dhcp_routed.lp",
        check = {
            { wan_interface_path .. "proto", "^dhcp$"},
        },
        operations = {
            { wan_interface_path .. "ifname", ""},
            { wan_interface_path .. "vpi", ""},
            { wan_interface_path .. "vci", ""},
            { wan_interface_path .. "proto", "dhcp"},
            { wan_interface_path .. "metric", "1"},
            { wan_interface_path .. "reqopts", "1 3 6 43 51 58 59"},
            { wan_interface_path .. "neighreachabletime", "1200000"},
            { wan_interface_path .. "neighgcstaletime", "2400"},
            { wan_interface_path .. "username", ""},
            { wan_interface_path .. "password", ""},
            { wan_interface_path .. "keepalive", ""},
            { wan_interface_path  ..  "ipaddr", ""},
            { wan_interface_path  ..  "netmask", ""},
            { wan_interface_path  ..  "gateway", ""},
        },
    },
    {
        name = "pppoe",
        default = false,
        description = "PPPoE routed mode",
        view = "internet-pppoe-routed.lp",
        card = "003_internet_pppoe_routed.lp",
        check = {
            { wan_interface_path .. "proto", "^pppoe$"},
        },
        operations = {
            { wan_interface_path .. "ifname", ""},
            { wan_interface_path .. "vpi", ""},
            { wan_interface_path .. "vci", ""},
            { wan_interface_path .. "proto", "pppoe"},
            { wan_interface_path .. "metric", "10"},
            { wan_interface_path .. "reqopts", ""},
            { wan_interface_path .. "neighreachabletime", ""},
            { wan_interface_path .. "neighgcstaletime", ""},
            { wan_interface_path .. "keepalive", "4,20"},
            { wan_interface_path  ..  "ipaddr", ""},
            { wan_interface_path  ..  "netmask", ""},
            { wan_interface_path  ..  "gateway", ""},
            { atm_device_path .. "ulp", "eth"},
            { atm_device_path .. "enc", "llc"},
            { wan_interface_path .. "username", ""},
            { wan_interface_path .. "password", ""},
        },
    },
    {
        name = "pppoa",
        default = false,
        description = "PPPoA routed mode",
        view = "internet-pppoa-routed.lp",
        card = "003_internet_pppoe_routed.lp",
        check = {
            { wan_interface_path .. "proto", "^pppoa$"},
        },
        operations = {
            { wan_interface_path .. "ifname", ""},
            { wan_interface_path .. "vpi", ""},
            { wan_interface_path .. "vci", ""},
            { wan_interface_path .. "proto", "pppoa"},
            { wan_interface_path .. "metric", "10"},
            { wan_interface_path .. "reqopts", ""},
            { wan_interface_path .. "neighreachabletime", ""},
            { wan_interface_path .. "neighgcstaletime", ""},
            { wan_interface_path .. "keepalive", "4,20"},
            { wan_interface_path  ..  "ipaddr", ""},
            { wan_interface_path  ..  "netmask", ""},
            { wan_interface_path  ..  "gateway", ""},
            { atm_device_path .. "ulp", "ppp"},
            { atm_device_path .. "enc", "vcmux"},
        },
    },
    {
        name = "static",
        default = false,
        description = "Static routed mode",
        view = "internet-static-routed.lp",
        card = "003_internet_static_routed.lp",
        check = {
            { wan_interface_path .. "proto", "^static$"},
        },
        operations = {
            { wan_interface_path .. "ifname", ""},
            { wan_interface_path .. "vpi", ""},
            { wan_interface_path .. "vci", ""},
            { wan_interface_path .. "proto", "static"},
            { wan_interface_path .. "metric", ""},
            { wan_interface_path .. "reqopts", ""},
            { wan_interface_path .. "neighreachabletime", ""},
            { wan_interface_path .. "neighgcstaletime", ""},
            { wan_interface_path .. "username", ""},
            { wan_interface_path .. "password", ""},
            { wan_interface_path .. "keepalive", ""},
        },
    },
}

local proto2type = {
    static = "ipoe",
    dhcp = "ipoe",
    pppoa = "ppp",
    pppoe = "ppp"
}
local type2ifname = {
    ipoe = { adsl = "atm_ipoe", vdsl = "ptm0", vdslvlan = "ptm0", ethernet = "eth4", ethernetvlan = "eth4" },
    ppp = { adsl = "atm_ppp", vdsl = "ptm0", vdslvlan = "vlan_ppp", ethernet ="eth4", ethernetvlan = "vlan_hfc" },
}

if content_params.variant == "novas" then
  type2ifname = {
    ipoe = { adsl = "atm_ppp", vdsl = "ptm0", vdslvlan = "ptm0", ethernet = "eth4", ethernetvlan = "eth4" },
    ppp = { adsl = "atm_ppp", vdsl = "ptm0", vdslvlan = "vlan_hfc", ethernet ="eth4", ethernetvlan = "vlan_hfc" },
  }
end

local function get(wan_type)
    if not wan_type then
        return helper
    end
    for k,v in ipairs(helper) do
        local operations =  v["operations"]
        local ifnames = type2ifname[proto2type[v.name]]
        if ifnames and ifnames[wan_type] then
            operations[1] = { "uci.network.interface.@wan.ifname", ifnames[wan_type] }
        end

        if wan_type == "adsl" and v.name == "pppoa" then
            local content_xtm = {
                vpi = "uci.xtm.atmdevice.@atm_ppp.vpi",
                vci = "uci.xtm.atmdevice.@atm_ppp.vci",
            }
            content_helper.getExactContent(content_xtm)
            operations[2] = { "uci.network.interface.@wan.vpi", content_xtm.vpi }
            operations[3] = { "uci.network.interface.@wan.vci", content_xtm.vci }

        elseif v.name == "pppoe" then
            local content_ppp = {
                 username = "uci.network.interface.@ppp.username",
                 password = "uci.network.interface.@ppp.password",
            }
            content_helper.getExactContent(content_ppp)
            operations[15] = { "uci.network.interface.@wan.username", content_ppp.username }
            operations[16] = { "uci.network.interface.@wan.password", content_ppp.password }
        end

    end
    return helper
end

return { get = get }
