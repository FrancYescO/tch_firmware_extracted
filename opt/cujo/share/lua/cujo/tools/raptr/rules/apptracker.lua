--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2019 CUJO LLC. All rights reserved.
--

local rule_group = require'rulegroup'

local function apptracker_set_rules_iterator(_)

    local apptracker_set = rule_group()

    apptracker_set.add({'iptables', 'ip6tables'},
        "-A CUJO_APPTRACKER -p tcp -m tcp -m conntrack --ctstate NEW -m lua --function nf_apptracker_new_tcp -j RETURN")
    apptracker_set.add({'iptables', 'ip6tables'},
        "-A CUJO_APPTRACKER -p udp -m udp -m conntrack --ctstate NEW -m lua --function nf_apptracker_new_udp -j RETURN")
    apptracker_set.add({'iptables', 'ip6tables'},
        "-A CUJO_APPTRACKER -p tcp -m tcp -m lua --function nf_apptracker_tcp --tcp-payload")
    apptracker_set.add({'iptables', 'ip6tables'},
        "-A CUJO_APPTRACKER -p udp -m udp -m lua --function nf_apptracker_udp")
    apptracker_set.add({'iptables', 'ip6tables'},
        "-A CUJO_DNSCACHE -p udp -m udp --sport 53 -m lua --function nf_apptracker_dns")

    return apptracker_set.rules_iterator
end

local function apptracker_clear_rules_iterator(_, _)
    local apptracker_clear = rule_group()

    apptracker_clear.add({'iptables', 'ip6tables'}, "-F CUJO_APPTRACKER")
    apptracker_clear.add({'iptables', 'ip6tables'}, "-F CUJO_DNSCACHE")

    return apptracker_clear.rules_iterator
end

return {
    set_rules   = apptracker_set_rules_iterator,
    clear_rules = apptracker_clear_rules_iterator
    }
