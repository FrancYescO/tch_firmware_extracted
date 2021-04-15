--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2019 CUJO LLC. All rights reserved.
--

local rule_group = require'rulegroup'

local function fingerprint_set_rules_iterator()
    local fingerprint_set = rule_group()

    fingerprint_set.add({'iptables', 'ip6tables'},
        "-A CUJO_FINGERPRINT -m set --match-set cujo_fingerprint src -j RETURN")

    fingerprint_set.add('iptables',
        "-A CUJO_FINGERPRINT -d 255.255.255.255/32 -p udp -m udp --sport 68 --dport 67 -m lua --function nf_dhcp")
    fingerprint_set.add('ip6tables',
        "-A CUJO_FINGERPRINT -s fe80::/10 -p udp -m udp --sport 546 --dport 547 -m lua --function nf_dhcp")

    fingerprint_set.add({'iptables', 'ip6tables'},
        "-A CUJO_FINGERPRINT -p udp -m udp --dport 53 -m lua --function nf_dns")
    fingerprint_set.add({'iptables', 'ip6tables'},
        "-A CUJO_FINGERPRINT -p tcp -m tcp --tcp-flags SYN SYN -m lua --function nf_tcpcap")
    fingerprint_set.add({'iptables', 'ip6tables'},
        "-A CUJO_FINGERPRINT -p tcp -m tcp --dport 80 --tcp-flags PSH PSH -m lua --function nf_httpcap")
    fingerprint_set.add({'iptables', 'ip6tables'},
        "-A CUJO_MDNS -m set --match-set cujo_fingerprint src -j RETURN")
    fingerprint_set.add({'iptables', 'ip6tables'},
        "-A CUJO_MDNS -p udp -m udp --dport 5353 -m lua --function nf_mdns")

    return fingerprint_set.rules_iterator
end

local function fingerprint_clear_rules_iterator()
    local fingerprint_clear = rule_group()

    fingerprint_clear.add({'iptables', 'ip6tables'}, "-F CUJO_FINGERPRINT")
    fingerprint_clear.add({'iptables', 'ip6tables'}, "-F CUJO_MDNS")

    return fingerprint_clear.rules_iterator
end

return {
    set_rules   = fingerprint_set_rules_iterator,
    clear_rules = fingerprint_clear_rules_iterator
    }
