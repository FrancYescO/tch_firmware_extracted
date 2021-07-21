--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2019 CUJO LLC. All rights reserved.
--

local rule_group = require'rulegroup'

local function appblocker_set_rules_iterator()
    local appblocker_set = rule_group()

    appblocker_set.add('iptables',
        "-A CUJO_APPBLOCKER -m conntrack --ctstate NEW -m lua --function nf_appblocker " ..
        "-j REJECT --reject-with icmp-port-unreachable")
    appblocker_set.add('ip6tables',
        "-A CUJO_APPBLOCKER -m conntrack --ctstate NEW -m lua --function nf_appblocker " ..
        "-j REJECT --reject-with icmp6-port-unreachable")

    return appblocker_set.rules_iterator
end

local function appblocker_clear_rules_iterator()
    local appblocker_clear = rule_group()

    appblocker_clear.add({'iptables', 'ip6tables'}, "-F CUJO_APPBLOCKER")

    return appblocker_clear.rules_iterator
end

return {
    set_rules   = appblocker_set_rules_iterator,
    clear_rules = appblocker_clear_rules_iterator
    }
