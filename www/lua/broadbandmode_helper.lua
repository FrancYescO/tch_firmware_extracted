
local proxy = require("datamodel")
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
            { "uci.network.interface.@wan.ifname", "^vlan_ptc274$" },
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
        },
    },
}

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
            { "uci.network.interface.@wan.ifname", "atm_8_35" },
        },
    },
    {
        name = "vdsl",
        default = false,
        description = "VDSL",
        view = "broadband-xdsl.lp",
        card = "002_broadband_xdsl.lp",
        check = get_check_wan_type("vdsl"),
        operations = {
            { "uci.network.interface.@wan.ifname", "vlan_ptc274" },
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
}

local function get(wan_proto)
    if not wan_proto then
        return helper
    end
    local bmh_operations = {
        adsl = {
            ppp = {
                { "uci.network.interface.@wan.ifname", "atm_8_35" },
            }
        },
        vdsl = {
            ipoe = {
                { "uci.network.interface.@wan.ifname", "vlan_ptc274" },
            },
        },
        ethernet = {
            { "uci.network.interface.@wan.ifname", "eth4" },
            { "uci.network.interface.@video.ifname", "" },
            { "uci.network.interface.@video.auto", "0" },
            { "uci.network.interface.@video2.ifname", "" },
            { "uci.network.interface.@video2.auto", "0" },
        }
    }
    for _,v in ipairs(helper) do
        if v.name == "ethernet" then
            v.operations = bmh_operations.ethernet
        else
            local proto_mode
            if wan_proto == "static" or wan_proto == "dhcp" then
                proto_mode = "ipoe"
            else
                proto_mode = "ppp"
            end
            v.operations = bmh_operations[v.name][proto_mode]
        end
        if wan_proto == "pppoa" and v.name == "adsl" then
            local operations = v["operations"]
            operations[#operations+1] = {"uci.network.interface.@wan.proto", "pppoa"}
            operations[#operations+1] = {"uci.network.interface.@wan.metric", "10"}
            operations[#operations+1] = {"uci.network.interface.@wan.keepalive", "4,20"}
            operations[#operations+1] = {"uci.network.interface.@wan.vpi", "8"}
            operations[#operations+1] = {"uci.network.interface.@wan.vci", "35"}
        end
    end
    return helper
end

return { get = get }
