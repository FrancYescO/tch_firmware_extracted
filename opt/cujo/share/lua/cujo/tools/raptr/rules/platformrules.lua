--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2019 CUJO LLC. All rights reserved.
--

local rule_group = require'rulegroup'

local function platform_set_rules(base_group, config)

    -- Let first 15 packets go through netfilter, then switch to fastpath
    base_group.add({'iptables', 'ip6tables'},
                    "-I PREROUTING -p tcp -m connbytes --connbytes 0:16 --connbytes-mode packets --connbytes-dir both -j SKIPLOG",
                    'mangle')
end

local function platform_clear_rules(base_group, config)

    base_group.add({'iptables', 'ip6tables'},
                    "-D PREROUTING -p tcp -m connbytes --connbytes 0:16 --connbytes-mode packets --connbytes-dir both -j SKIPLOG",
                    'mangle')
end

return {
    set   = platform_set_rules,
    clear = platform_clear_rules
    }
