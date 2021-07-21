--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2019 CUJO LLC. All rights reserved.
--

local rule_group = require'rulegroup'

local function safebro_set_rules_iterator()
    local safebro_set = rule_group()

    safebro_set.add({'iptables', 'ip6tables'},
        "-A CUJO_SAFEBRO_IN -p tcp -m tcp --dport 80 -m conntrack --ctstate NEW -m lua --function nf_conn_new")
    safebro_set.add({'iptables', 'ip6tables'},
        "-A CUJO_SAFEBRO_IN -p tcp -m tcp --dport 80 -m lua --function nf_http --tcp-payload")
    safebro_set.add({'iptables', 'ip6tables'},
        "-A CUJO_SAFEBRO_OUT -p tcp -m tcp --sport 80 -m lua --function nf_reset_response --tcp-payload " ..
        "-j REJECT --reject-with tcp-reset")
    safebro_set.add({'iptables', 'ip6tables'},
        "-A CUJO_SAFEBRO_IN -p tcp -m tcp --dport 443 -m conntrack --ctstate NEW -m lua --function nf_conn_new")
    safebro_set.add({'iptables', 'ip6tables'},
        "-A CUJO_SAFEBRO_IN -p tcp -m tcp --dport 443 -m lua --function nf_ssl --tcp-payload")
    safebro_set.add({'iptables', 'ip6tables'},
        "-A CUJO_SAFEBRO_OUT -p tcp -m tcp --sport 443 -m lua --function nf_reset_response --tcp-payload " ..
        "-j REJECT --reject-with tcp-reset")

    return safebro_set.rules_iterator
end

local function safebro_clear_rules_iterator()
    local safebro_clear = rule_group()

    safebro_clear.add({'iptables', 'ip6tables'}, "-F CUJO_SAFEBRO_OUT")
    safebro_clear.add({'iptables', 'ip6tables'}, "-F CUJO_SAFEBRO_IN")

    return safebro_clear.rules_iterator
end

return {
    set_rules   = safebro_set_rules_iterator,
    clear_rules = safebro_clear_rules_iterator
    }
