--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2019 CUJO LLC. All rights reserved.
--

--- @module rulegroup

--- Collection of commands for managing group of netfilter rules
-- New commands can be added to the group using add() function, and
-- existing commands / rules can be walked through using iterator
-- obtained with rules_iterator() function.
local function rule_group()
    local self = {}
    self.rules = {}

    --- Add new command for managing netfilter rule
    -- @param utils     Utilities to use to create rules
    -- @param rule      Rule specification
    -- @param nftable   Affected nftable
    local function add(utils, rule, nftable)
        local supported_utils = {
            ['iptables']  = true,
            ['ip6tables'] = true,
            ['ipset']     = true
        }

        if type(utils) == type("") then
            utils = {utils}
        end

        for _, util in pairs(utils) do
            assert(supported_utils[util], "Unsupported utility: " .. util)
        end

        nftable = nftable or 'filter'
        assert(nftable == 'filter' or nftable == 'mangle', "Unsupported nftable " .. nftable)

        self.rules[#self.rules + 1] = { utils = utils, rule = rule, nftable = nftable }
    end

    --- Provide iterator over rules in this group
    local function rules_iterator()
        return ipairs(self.rules)
    end

    return {
        add = add,
        rules_iterator = rules_iterator
    }
end

return rule_group