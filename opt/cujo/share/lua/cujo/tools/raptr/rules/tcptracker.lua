--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2019 CUJO LLC. All rights reserved.
--

local rule_group = require'rulegroup'

local function tcptracker_set_rules_iterator(_)

    local tcptracker_set = rule_group()

    tcptracker_set.add({'iptables', 'ip6tables'},
        "-A CUJO_TCPTRACKER -p tcp -m tcp --tcp-flags SYN SYN -m lua --function nf_tcptracker")

    return tcptracker_set.rules_iterator
end

local function tcptracker_clear_rules_iterator(_, _)
    local tcptracker_clear = rule_group()

    tcptracker_clear.add({'iptables', 'ip6tables'}, "-F CUJO_TCPTRACKER")

    return tcptracker_clear.rules_iterator
end

return {
    set_rules   = tcptracker_set_rules_iterator,
    clear_rules = tcptracker_clear_rules_iterator
    }
