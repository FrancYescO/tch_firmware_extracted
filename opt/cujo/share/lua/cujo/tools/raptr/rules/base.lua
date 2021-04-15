--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2019 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo

local rule_group = require'rulegroup'


local function get_platform_rules()

    local filename = os.getenv'CUJO_HOME' .. "/share/lua/cujo/tools/raptr/rules/platformrules.lua"
    local f = io.open(filename)

    if not f then
        return nil
    end

    f:close()

    local platform_rules, error = loadfile(filename)

    if error then
        cujo.log:error("Loading platform rules failed with following message:\n\n" .. error)
        os.exit(5)
    end

    return platform_rules()
end


local function base_set_rules_iterator(config, _)
    local base_set = rule_group()

    local platform_rules = get_platform_rules()
    if platform_rules then
        platform_rules.set(base_set, config)
    end

    base_set.add({'iptables', 'ip6tables'}, "-N CUJO_INPUT")
    base_set.add({'iptables', 'ip6tables'}, "-N CUJO_OUTPUT")
    base_set.add({'iptables', 'ip6tables'}, "-N CUJO_FORWARD")
    base_set.add({'iptables', 'ip6tables'}, "-N CUJO_APPBLOCKER")
    base_set.add({'iptables', 'ip6tables'}, "-N CUJO_APPTRACKER")
    base_set.add({'iptables', 'ip6tables'}, "-N CUJO_DNSCACHE")
    base_set.add({'iptables', 'ip6tables'}, "-N CUJO_FINGERPRINT")
    base_set.add({'iptables', 'ip6tables'}, "-N CUJO_MAIN_FWDIN")
    base_set.add({'iptables', 'ip6tables'}, "-N CUJO_MAIN_FWDOUT")
    base_set.add({'iptables', 'ip6tables'}, "-N CUJO_MAIN_LANTOLAN")
    base_set.add({'iptables', 'ip6tables'}, "-N CUJO_MAIN_LOCIN")
    base_set.add({'iptables', 'ip6tables'}, "-N CUJO_MAIN_LOCOUT")
    base_set.add({'iptables', 'ip6tables'}, "-N CUJO_MDNS")
    base_set.add({'iptables', 'ip6tables'}, "-N CUJO_SAFEBRO_IN")
    base_set.add({'iptables', 'ip6tables'}, "-N CUJO_SAFEBRO_OUT")
    base_set.add({'iptables', 'ip6tables'}, "-N CUJO_SSDP")
    base_set.add({'iptables', 'ip6tables'}, "-N CUJO_TCPTRACKER")

    base_set.add({'iptables', 'ip6tables'}, "-I INPUT -j CUJO_INPUT")
    base_set.add({'iptables', 'ip6tables'},
        "-I INPUT -p tcp -m conntrack --ctstate INVALID -j REJECT --reject-with tcp-reset")
    base_set.add({'iptables', 'ip6tables'}, "-I FORWARD -j CUJO_FORWARD")
    base_set.add({'iptables', 'ip6tables'},
        "-I FORWARD -p tcp -m conntrack --ctstate INVALID -j REJECT --reject-with tcp-reset")
    base_set.add({'iptables', 'ip6tables'}, "-I OUTPUT -j CUJO_OUTPUT")
    base_set.add({'iptables', 'ip6tables'},
         "-I OUTPUT -p tcp -m conntrack --ctstate INVALID -j REJECT --reject-with tcp-reset")
    base_set.add({'iptables', 'ip6tables'},
         "-I OUTPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK RST -m conntrack --ctstate INVALID -j ACCEPT")

    base_set.add('ipset',                   "create cujo_iotblock_mac hash:mac -exist")
    base_set.add('ipset',                   "create cujo_iotblock_ip4 hash:ip family inet -exist")
    base_set.add('ipset',                   "create cujo_iotblock_ip6 hash:ip family inet6 -exist")
    base_set.add('ipset',                   "create cujo_fingerprint hash:mac -exist")

    for _, lan in ipairs(config.lan_ifaces) do
        for _, wan in ipairs(config.wan_ifaces) do
            base_set.add({'iptables', 'ip6tables'},
                          "-A CUJO_FORWARD -i " .. wan .. " -o ".. lan .. " -j CUJO_MAIN_FWDOUT")
            base_set.add({'iptables', 'ip6tables'},
                          "-A CUJO_FORWARD -i " .. lan .. " -o " .. wan .. " -j CUJO_MAIN_FWDIN")
        end
        base_set.add({'iptables', 'ip6tables'},
                      "-A CUJO_FORWARD -i " .. lan .. " -o " .. lan .. " -j CUJO_MAIN_LANTOLAN")
        base_set.add({'iptables', 'ip6tables'},
                      "-A CUJO_INPUT -i " .. lan .. " -j CUJO_MAIN_LOCIN")
    end

    base_set.add('iptables',
        "-A CUJO_MAIN_FWDIN -m conntrack --ctstate NEW -m set --match-set cujo_iotblock_ip4 dst " ..
        "-j REJECT --reject-with icmp-port-unreachable")
    base_set.add('iptables',
        "-A CUJO_MAIN_FWDIN -m conntrack --ctstate NEW -m set --match-set cujo_iotblock_mac src " ..
        "-j REJECT --reject-with icmp-port-unreachable")

    base_set.add('ip6tables',
        "-A CUJO_MAIN_FWDIN -m conntrack --ctstate NEW -m set --match-set cujo_iotblock_ip6 dst " ..
        "-j REJECT --reject-with icmp6-port-unreachable")
    base_set.add('ip6tables',
        "-A CUJO_MAIN_FWDIN -m conntrack --ctstate NEW -m set --match-set cujo_iotblock_mac src " ..
        "-j REJECT --reject-with icmp6-port-unreachable")

    base_set.add({'iptables', 'ip6tables'}, "-A CUJO_MAIN_FWDIN -j CUJO_APPBLOCKER")
    base_set.add({'iptables', 'ip6tables'}, "-A CUJO_MAIN_FWDIN -j CUJO_SAFEBRO_IN")
    base_set.add({'iptables', 'ip6tables'}, "-A CUJO_MAIN_FWDIN -j CUJO_APPTRACKER")
    base_set.add({'iptables', 'ip6tables'}, "-A CUJO_MAIN_FWDIN -j CUJO_TCPTRACKER")
    base_set.add({'iptables', 'ip6tables'}, "-A CUJO_MAIN_FWDIN -j CUJO_FINGERPRINT")

    base_set.add('iptables',
        "-A CUJO_MAIN_FWDOUT -m conntrack --ctstate NEW -m set --match-set cujo_iotblock_ip4 src " ..
        "-j REJECT --reject-with icmp-port-unreachable")
    base_set.add('ip6tables',
        "-A CUJO_MAIN_FWDOUT -m conntrack --ctstate NEW -m set --match-set cujo_iotblock_ip6 src " ..
        "-j REJECT --reject-with icmp6-port-unreachable")

    base_set.add({'iptables', 'ip6tables'}, "-A CUJO_MAIN_FWDOUT -j CUJO_APPBLOCKER")
    base_set.add({'iptables', 'ip6tables'}, "-A CUJO_MAIN_FWDOUT -j CUJO_SAFEBRO_OUT")
    base_set.add({'iptables', 'ip6tables'}, "-A CUJO_MAIN_FWDOUT -j CUJO_DNSCACHE")

    base_set.add({'iptables', 'ip6tables'}, "-A CUJO_MAIN_LOCIN -j CUJO_MDNS")

    base_set.add({'iptables', 'ip6tables'}, "-A CUJO_MAIN_LOCIN -j CUJO_SSDP")

    base_set.add('iptables',
        "-A CUJO_MAIN_LOCIN -m conntrack --ctstate NEW -m set --match-set cujo_iotblock_mac src " ..
        "-j REJECT --reject-with icmp-port-unreachable")
    base_set.add('ip6tables',
        "-A CUJO_MAIN_LOCIN -m conntrack --ctstate NEW -m set --match-set cujo_iotblock_mac src " ..
        "-j REJECT --reject-with icmp6-port-unreachable")

    base_set.add({'iptables', 'ip6tables'}, "-A CUJO_MAIN_LOCIN -j CUJO_FINGERPRINT")
    base_set.add({'iptables', 'ip6tables'}, "-A CUJO_MAIN_LOCOUT -j CUJO_DNSCACHE")

    for _, lan in ipairs(config.lan_ifaces) do
        base_set.add({'iptables', 'ip6tables'},
                      "-A CUJO_OUTPUT -o " .. lan .. " -j CUJO_MAIN_LOCOUT")
    end

    for _, lan in ipairs(config.lan_ifaces) do
        base_set.add({'iptables', 'ip6tables'},
            "-A CUJO_SSDP -i " .. lan .. " -p udp -m udp --dport " .. config.ssdpbindport ..
            " -m lua --function nf_ssdp -j DROP")
    end

    return base_set.rules_iterator
end

local function base_clear_rules_iterator(config)
    local base_clear = rule_group()

    base_clear.add({'iptables', 'ip6tables'}, "-F CUJO_APPBLOCKER")
    base_clear.add({'iptables', 'ip6tables'}, "-F CUJO_APPTRACKER")
    base_clear.add({'iptables', 'ip6tables'}, "-F CUJO_DNSCACHE")
    base_clear.add({'iptables', 'ip6tables'}, "-F CUJO_FINGERPRINT")
    base_clear.add({'iptables', 'ip6tables'}, "-F CUJO_MDNS")
    base_clear.add({'iptables', 'ip6tables'}, "-F CUJO_SAFEBRO_IN")
    base_clear.add({'iptables', 'ip6tables'}, "-F CUJO_SAFEBRO_OUT")
    base_clear.add({'iptables', 'ip6tables'}, "-F CUJO_SSDP")
    base_clear.add({'iptables', 'ip6tables'}, "-F CUJO_TCPTRACKER")
    base_clear.add({'iptables', 'ip6tables'}, "-F CUJO_MAIN_FWDIN")
    base_clear.add({'iptables', 'ip6tables'}, "-F CUJO_MAIN_FWDOUT")
    base_clear.add({'iptables', 'ip6tables'}, "-F CUJO_MAIN_LANTOLAN")
    base_clear.add({'iptables', 'ip6tables'}, "-F CUJO_MAIN_LOCIN")
    base_clear.add({'iptables', 'ip6tables'}, "-F CUJO_MAIN_LOCOUT")
    base_clear.add({'iptables', 'ip6tables'}, "-F CUJO_INPUT")
    base_clear.add({'iptables', 'ip6tables'}, "-F CUJO_OUTPUT")
    base_clear.add({'iptables', 'ip6tables'}, "-F CUJO_FORWARD")

    base_clear.add({'iptables', 'ip6tables'}, "-X CUJO_APPBLOCKER")
    base_clear.add({'iptables', 'ip6tables'}, "-X CUJO_APPTRACKER")
    base_clear.add({'iptables', 'ip6tables'}, "-X CUJO_DNSCACHE")
    base_clear.add({'iptables', 'ip6tables'}, "-X CUJO_FINGERPRINT")
    base_clear.add({'iptables', 'ip6tables'}, "-X CUJO_MDNS")
    base_clear.add({'iptables', 'ip6tables'}, "-X CUJO_SAFEBRO_IN")
    base_clear.add({'iptables', 'ip6tables'}, "-X CUJO_SAFEBRO_OUT")
    base_clear.add({'iptables', 'ip6tables'}, "-X CUJO_SSDP")
    base_clear.add({'iptables', 'ip6tables'}, "-X CUJO_TCPTRACKER")
    base_clear.add({'iptables', 'ip6tables'}, "-X CUJO_MAIN_FWDIN")
    base_clear.add({'iptables', 'ip6tables'}, "-X CUJO_MAIN_FWDOUT")
    base_clear.add({'iptables', 'ip6tables'}, "-X CUJO_MAIN_LANTOLAN")
    base_clear.add({'iptables', 'ip6tables'}, "-X CUJO_MAIN_LOCIN")
    base_clear.add({'iptables', 'ip6tables'}, "-X CUJO_MAIN_LOCOUT")

    base_clear.add({'iptables', 'ip6tables'}, "-D INPUT -j CUJO_INPUT")
    base_clear.add({'iptables', 'ip6tables'},
        "-D INPUT -p tcp -m conntrack --ctstate INVALID -j REJECT --reject-with tcp-reset")
    base_clear.add({'iptables', 'ip6tables'}, "-D FORWARD -j CUJO_FORWARD")
    base_clear.add({'iptables', 'ip6tables'},
        "-D FORWARD -p tcp -m conntrack --ctstate INVALID -j REJECT --reject-with tcp-reset")
    base_clear.add({'iptables', 'ip6tables'}, "-D OUTPUT -j CUJO_OUTPUT")
    base_clear.add({'iptables', 'ip6tables'},
        "-D OUTPUT -p tcp -m conntrack --ctstate INVALID -j REJECT --reject-with tcp-reset")
    base_clear.add({'iptables', 'ip6tables'},
        "-D OUTPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK RST -m conntrack --ctstate INVALID -j ACCEPT")

    base_clear.add({'iptables', 'ip6tables'}, "-X CUJO_INPUT")
    base_clear.add({'iptables', 'ip6tables'}, "-X CUJO_OUTPUT")
    base_clear.add({'iptables', 'ip6tables'}, "-X CUJO_FORWARD")

    base_clear.add('ipset',                   "destroy cujo_iotblock_mac")
    base_clear.add('ipset',                   "destroy cujo_iotblock_ip4")
    base_clear.add('ipset',                   "destroy cujo_iotblock_ip6")
    base_clear.add('ipset',                   "destroy cujo_fingerprint")

    local platform_rules = get_platform_rules()
    if platform_rules then
        platform_rules.clear(base_clear, config)
    end

    return base_clear.rules_iterator
end

return {
    set_rules   = base_set_rules_iterator,
    clear_rules = base_clear_rules_iterator
    }
