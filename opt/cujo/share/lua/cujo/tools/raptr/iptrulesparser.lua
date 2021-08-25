--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2019 CUJO LLC. All rights reserved.
--

-- luacheck: read globals cujo

--- @module iptrulesparser

--- Parser of iptables rules
-- This function creates 'object' that contains parsed output of 'iptables -S' commands
-- for all supported IP versions. 'Object' than can be used to check existance of netfilter
-- rules
-- @param nets      Table of supported IP versions and iptables utilities
-- NOTE: nets is expected to be in the same format as config.nets, ie:
-- config.nets = {
--      ip4 = {iptables = '/bin/iptables'},
--      ip6 = {iptables = '/bin/ip6tables'},
-- }
-- @return Table of 'public' functions that can be used on this 'object'
-- @usage parser = ipt_rules_parser(cujo.nets); parser.is_rule_present('ip4', 'filter', '-N INPUT')
local function ipt_rules_parser(nets)
    assert(type(nets) == type({}), "Invalid type of input")

    local self = {}
    self.nets = nets
    self.rules = {}
    for ipfamily, _ in pairs(nets) do
        assert(ipfamily == 'ip4' or ipfamily == 'ip6',
                "Invalid IP family, expected ip4 or ip6, got " .. ipfamily)

        self.rules[ipfamily] = {
            filter = {},
            mangle = {}
        }
        assert(nets[ipfamily].iptables, "Invalid format of input")
    end
    self.log = function () end


    --- Get output of iptables -S command
    -- @param ipfamily      IP version ({ip4, ip6})
    -- @param nftable       One of netfilter tables (filter, mangle)
    -- @return Output of 'iptables -S' command as list of lines
    local function get_current_rules(ipfamily, nftable)

        local extra_flags = cujo.config.extra_iptables_flags or ""
        local proc = assert(io.popen(self.nets[ipfamily].iptables ..
                                     " " .. extra_flags ..
                                     " -t " .. nftable .. " -S"),
                            "Failed to get netfilter rules")
        local data = {}

        repeat
            local line = proc:read()
            data[#data + 1] = line
        until line == nil

        proc:close()

        return data
    end

    --- Parse netfilter rules into Lua table for quick lookups
    -- @param ipfamily      IP version ({ip4, ip6})
    -- @param nftable       One of netfilter tables (filter, mangle)
    local function parse_ipt_rule_list(ipfamily, nftable)

        local tbl = nftable or 'filter'
        local chains = {}
        local nf_rules_dump = get_current_rules(ipfamily, tbl)

        for _, line in pairs(nf_rules_dump) do
            -- iterate over line, split it on spaces
            local iter = line:gmatch("%S+")
            local operation = iter()
            local chain = iter()

            if operation == "-N" or operation == "-P" then
                chains[chain] = {}

            elseif operation == "-A"  then
                local space_after_chain = line:find(chain) + #chain
                local rule = line:sub(space_after_chain + 1)
                local chain_tbl = chains[chain]

                if  chain_tbl ~= nil then
                    chain_tbl[#chain_tbl + 1] = rule
                else
                    return nil, "ERROR: unexpected iptables chain (" .. chain .. ")"
                end
            end
        end
        self.rules[ipfamily][tbl] = chains
    end


    for ipfamily, _ in pairs(self.nets) do
        parse_ipt_rule_list(ipfamily, 'filter')
        parse_ipt_rule_list(ipfamily, 'mangle')
    end


    -- Check does given rule exist in netfilter table for given IP version
    -- @param ipfamily      IP version ({ip4, ip6})
    -- @param nftable       One of netfilter tables (filter, mangle, nat,...)
    -- @param rule_to_check     Rule to check
    -- @return true, if rule is in given netfilter table for given IP version; false, otherwise
    local function is_rule_present(ipfamily, nftable, rule_to_check)

        if self.rules[ipfamily] == nil then
            self.log("Unsupported IP version (" .. ipfamily .. ")")
            return false
        end

        local tbl = nftable or 'filter'

        if self.rules[ipfamily][tbl] == nil then
            self.log("No such table (" .. tbl .. ")")
            return false
        end

        -- third parameter is here for the rules like '-I OUTPUT 1 ...'. iptables will not show it up
        -- in 'iptables -S' output, so we need to ignore it
        local cmd, chain, _, rule_spec = rule_to_check:match("(%S+)%s+(%S+)%s*(%d*)%s*(.*)")

        if cmd == "-A" or cmd == "-I" or cmd == "-D" then
            if self.rules[ipfamily][tbl][chain] == nil then
                self.log("No such chain (" .. chain .. ")")
                return false
            end
            for _, present_rule in pairs(self.rules[ipfamily][tbl][chain]) do
                if present_rule == rule_spec then
                    return true
                end
            end
        elseif cmd == "-N" or cmd == "-P" or cmd == "-F" or cmd == "-X" then
            if self.rules[ipfamily][tbl][chain] ~= nil then
                return true
            end
        end
        self.log("No such rule (" .. rule_to_check .. ")")
        return false
    end

    --- Set function for logging
    -- By default, logging is disabled until logging function is provided
    -- @param log_func      Logging function
    -- @usage set_log(print) -- use built in print() as logging function
    local function set_log(log_func)
        self.log = log_func
    end

    return {
        is_rule_present = is_rule_present,
        set_log = set_log
    }
end

return ipt_rules_parser
