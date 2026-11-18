local content_helper = require ("web.content_helper")
local post_helper = require("web.post_helper")
local format = string.format
local wanIntf = post_helper.getActiveInterface()
local wan_interface_path = format("uci.network.interface.@%s.", wanIntf)
local atm_device_path = "uci.xtm.atmdevice.@atm_ppp."
local helper = {}

local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "InternetAccess", "internetAccess")
local atm_device_wan_path

if post_helper.getVariantValue(variantHelper, "atmwan") then
  atm_device_wan_path = "uci.xtm.atmdevice.@atmwan."
elseif post_helper.getVariantValue(variantHelper, "atm_wan") then
  atm_device_wan_path = "uci.xtm.atmdevice.@atm_wan."
else
  atm_device_wan_path = "uci.xtm.atmdevice.@atm_8_35."
end

local content_params = {
    variant = "uci.env.var.iinet_variant",
}
content_helper.getExactContent(content_params)
if post_helper.isFeatureEnabled("internetmodeHelper", role) then
  helper = {
    {
      name = "dhcp",
      default = true,
      description = "DHCP routed mode",
      view = "internet-dhcp-routed-status.lp",
      card = "003_internet_dhcp_routed.lp",
      check = {
        { format("uci.network.interface.@%s.proto", wanIntf), "^dhcp$"},
      },
      operations = {
        { wan_interface_path .. "proto", "dhcp"},
        { wan_interface_path .. "reqopts", "1 3 6 15 33 42 51 121 249"},
      },
    },
    {
      name = "pppoe",
      default = false,
      description = "PPPoE routed mode",
      view = "internet-pppoe-routed-status.lp",
      card = "003_internet_pppoe_routed.lp",
      check = {
        { wan_interface_path .. "proto", "^pppoe$"},
      },
      operations = {
        { wan_interface_path .. "proto", "pppoe"},
      },
    },
    {
      name = "pppoa",
      default = false,
      description = "PPPoA routed mode",
      view = "internet-pppoa-routed-status.lp",
      card = "003_internet_pppoe_routed.lp",
      check = {
        { wan_interface_path .. "proto", "^pppoa$"},
      },
      operations = {
        { wan_interface_path .. "proto", "pppoa"},
        { atm_device_wan_path .. "enc", "vcmux"},
        { atm_device_wan_path .. "ulp", "ppp"},
      },
    },
    {
      name = "static",
      default = false,
      description = "Fixed IP mode",
      view = "internet-static-routed-status.lp",
      card = "003_internet_static_routed.lp",
      check = {
        { wan_interface_path .. "proto", "^static$"},
      },
      operations = {
        { wan_interface_path .. "proto", "static"},
      },
    },
  }
else
  helper={
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
      view = "internet-dhcp-routed-status.lp",
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
      view = "internet-pppoe-routed-status.lp",
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
      view = "internet-pppoa-routed-status.lp",
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
      view = "internet-static-routed-status.lp",
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
end

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

if content_params.variant == "novus" then
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
            operations[1] = { format("uci.network.interface.@%s.ifname", wanIntf), ifnames[wan_type] }
        end

        if wan_type == "adsl" and v.name == "pppoa" then
            local content_xtm = {
                vpi = "uci.xtm.atmdevice.@atm_ppp.vpi",
                vci = "uci.xtm.atmdevice.@atm_ppp.vci",
            }
            content_helper.getExactContent(content_xtm)
            operations[2] = { format("uci.network.interface.@%s.vpi", wanIntf), content_xtm.vpi }
            operations[3] = { format("uci.network.interface.@%s.vci", wanIntf), content_xtm.vci }

        elseif v.name == "pppoe" then
            local content_ppp = {
                 username = "uci.network.interface.@ppp.username",
                 password = "uci.network.interface.@ppp.password",
            }
            content_helper.getExactContent(content_ppp)
            operations[15] = { format("uci.network.interface.@%s.username", wanIntf), content_ppp.username }
            operations[16] = { format("uci.network.interface.@%s.password", wanIntf), content_ppp.password }
        end

    end
    return helper
end

return { get = get }
