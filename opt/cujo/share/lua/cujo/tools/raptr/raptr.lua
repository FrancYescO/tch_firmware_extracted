--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2019 CUJO LLC. All rights reserved.
--

-- Error exit codes
local ERR_NOT_MATCHING = 4
local ERR_SUBPROCESS_FAILED = 5

-- add search path for raptr's own local modules
-- if this script is run outside of its own folder, arg[0] will contain
-- full path to this script
local this_script_path = arg[0]:match(".+%/")
if this_script_path then
    package.path = package.path .. ";" .. this_script_path .. "?.lua"
end


--- Helper function for debugging.
-- @param data      Data to pretty print
-- @return Pretty print type of string representing given data structure
local function dump(data)
    local v = require "loop.debug.Viewer"
    return v:tostring(data)
end

local cl_arguments = require'arguments'

-- luacheck: globals cujo
cujo = {
    filesys = require 'cujo.filesys',
    net = require 'cujo.net',
    log = require 'cujo.log',
    snoopy = require 'cujo.snoopy',
}

cujo.log:level(cl_arguments.verbose)

cujo.config = require 'cujo.config'

cujo.log:debug("cl_arguments\n" .. dump(cl_arguments))

local ipt4bin = cujo.config.nets['ip4'] and cujo.config.nets['ip4'].iptables or nil
local ipt6bin = cujo.config.nets['ip6'] and cujo.config.nets['ip6'].iptables or nil

--- Get list of current rules, if needed.
-- @param dry_run   Is this dry run or not
-- @return Current netfilter rules and ipset names,
--          or (nil, nil) if this is just dry run
local function get_current_rules(dry_run)
    if dry_run then
        return nil, nil
    end

    local ipt_rules_parser = require'iptrulesparser'
    local current_nf_rules = ipt_rules_parser(cujo.config.nets)

    local ipset_parser = require'ipsetparser'
    local current_ipsetnames = ipset_parser(cujo.config.ipset)

    return current_nf_rules, current_ipsetnames
end

--- Should handling the rule be skipped or not.
-- @param ipv       IP version (ip4, ip6, or nil for both IPv4 and IPv6)
-- @param util      Type of utility for which rule is specified
-- @return true - Skip handling rule; false - don't skip rule
local function should_skip(ipv, util)
    if (util == 'iptables' and ipt4bin == nil) or
        (util == 'ip6tables' and ipt6bin == nil) then
        return true
    end

    if (ipv == 'ip4' and util == 'ip6tables') or
        (ipv == 'ip6' and util == 'iptables') then
        return true
    end

    return false
end

--- Check is given iptables rule or IP set already present
-- @param nf_rules  List of current netfilter rules
-- @param ipset_names   List of current IPset sets
-- @param util      Type of utility for which rule / IP set is specified
-- @param nftable   Affected netfilter table (for iptables type of rules)
-- @param rule      Rule / IP set scpecification
-- @return true     Rule / IP set is already present,
--         false    No such rule / IP set on the system at the moment
local function is_present(nf_rules, ipset_names, util, nftable, rule)

    if util == 'ipset' then
        local setname = rule:match("^%S+%s+(%S+)")
        if ipset_names.is_setname_present(setname) then
            return true
        end
    else
        if nf_rules.is_rule_present(util == 'iptables' and 'ip4' or 'ip6', nftable, rule) then
            return true
        end
    end

    return false
end

--- Construct iptables / ipset command to set up given rule
-- @param util      Type of utility for which rule / IP set is specified
-- @param nftable   Affected netfilter table (for iptables type of rules)
-- @param rule      Rule / IP set scpecification
-- @return String representing command that needs to be executed to set given rule
local function construct_command(util, nftable, rule)

    -- TODO: platform specific command assembly
    if util == 'ipset' then
        return cujo.config.ipset .. " " .. rule
    else
        local binary = (util == 'iptables') and ipt4bin or ipt6bin
        local extra_flags = cujo.config.extra_iptables_flags or ""
        local tbl = nftable == nil and 'filter' or nftable

        return binary .. " " .. extra_flags .. " -t " .. tbl .. " " .. rule
    end

end

-- Set given group of rules
-- @param cl_args   Comand line arguments
local function set_rules(cl_args)

    local rules_iterator = require("rules." .. cl_args.ruleset).set_rules(cujo.config)

    local current_nf_rules, current_ipsetnames = get_current_rules(cl_args.dry_run)

    -- TODO: extract this loop and reuse it also in clear_rules()
    for _, r in rules_iterator() do
        for _, util in ipairs(r.utils) do
            if should_skip(cl_args.ipv, util) then
                goto continue
            end

            local cmd = construct_command(util, r.nftable, r.rule)
            if cl_args.dry_run then
                print(cmd)
                goto continue
            end

            if is_present(current_nf_rules, current_ipsetnames, util, r.nftable, r.rule) then
                cujo.log:debug("[set_rules] [" .. util .. "] Already present rule: " .. r.rule)
            else
                cujo.log:debug("[set_rules] creating rule / set: '" .. cmd .. "'")

                local success, _, _ = os.execute(cmd)
                if not success then
                    cujo.log:error("Setting rule failed")
                    os.exit(ERR_SUBPROCESS_FAILED)
                end
            end

            ::continue::
        end
    end
end

--- Remove given group of the rules
-- @param cl_args   Comand line arguments
local function clear_rules(cl_args)

    if cl_args.ruleset == "all" then
        cl_args.ruleset = "base"
    end

    local rules_iterator = require("rules." .. cl_args.ruleset).clear_rules(cujo.config)

    local current_nf_rules, current_ipsetnames = get_current_rules(cl_args.dry_run)

    for _, r in rules_iterator() do
        for _, util in ipairs(r.utils) do
            if should_skip(cl_args.ipv, util) then
                goto continue
            end

            local cmd = construct_command(util, r.nftable, r.rule)
            if cl_args.dry_run then
                print(cmd)
                goto continue
            end

            if is_present(current_nf_rules, current_ipsetnames, util, r.nftable, r.rule) then
                cujo.log:debug("[clear_rules] removing rule / set: '" .. cmd .. "'")

                local success, _, _ = os.execute(cmd)
                if not success then
                    cujo.log:error("Clearing rule failed")
                    os.exit(ERR_SUBPROCESS_FAILED)
                end
            else
                cujo.log:debug("[clear_rules] [" .. util .. "] No such rule: " .. r.rule)
            end

            ::continue::
        end
    end
end

--- Check is given single netfilter rule in expected state (present or absent)
-- @param nf_rule   Netfilter rule
-- @param ipv       IP version (ip4, ip6, or nil for both IPv4 and IPv6)
-- @param nf_table  Netfilter table
-- @param present   Check for presence (true) or absence (false) of the nf_rule
-- @return true, if netfilter rule is in expected state; false, otherwise
local function single_rule_in_proper_state(nf_rule, ipv, nf_table, present)

    local rule_str = table.concat(nf_rule, " ")

    local current_nf_rules, _ = get_current_rules(false)
    local rule_present = current_nf_rules.is_rule_present(ipv, nf_table, rule_str)

    if rule_present ~= present then
        if rule_present then
            cujo.log:error("Not expected, but found [" ..
                            ipv .. "][" .. nf_table .. "][" .. rule_str .."]")
        else
            cujo.log:error("Not found [" ..
                            ipv .. "][" .. nf_table .. "][" .. rule_str .."]")
        end
        return false
    end

    return true
end

--- Check are all rules in given group of rules in expected state (present or absent)
-- @param ruleset   Named set of rules
-- @param ipv       IP version (ip4, ip6, or nil for both IPv4 and IPv6)
-- @param present   Check for presence (true) or absence (false) of the ruleset
-- @return true, if all of the rules in the group are in expected state; false, otherwise
local function set_of_rules_in_proper_state(ruleset, ipv, present)

    local rules_iterator = require("rules." .. ruleset).set_rules(cujo.config)

    local present_rules = {}
    local absent_rules = {}

    local current_nf_rules, current_ipsetnames = get_current_rules(false)

    for _, r in rules_iterator() do
        for _, util in ipairs(r.utils) do
            if should_skip(ipv, util) then
                goto continue
            end

            if is_present(current_nf_rules, current_ipsetnames, util, r.nftable, r.rule) then
                present_rules[#present_rules + 1] = util .. " " .. r.rule
            else
                absent_rules[#absent_rules + 1] = util .. " " .. r.rule
            end

            ::continue::
        end
    end

    if present then
        if #absent_rules > 0 then
            cujo.log:error("Expected, but missing rules:\n" .. dump(absent_rules))
            return false
        else
            cujo.log:info("All " .. ruleset .. " rules are set")
        end
    else
        if #present_rules > 0 then
            cujo.log:error("Not expected but present rules:\n" .. dump(present_rules))
            return false
        else
            cujo.log:info("All " .. ruleset .. " rules are cleared")
        end
    end

    return true
end

--- Check are requested rule in expected state
-- @param cl_args   Comand line arguments
-- @return true, if rule or rules are in expected state; false, otherwise
local function rules_in_proper_state(cl_args)
    if cl_args.single then
        return single_rule_in_proper_state(cl_args.nf_rule, cl_args.ipv,
                                           cl_args.table, cl_args.present)
    else
        return set_of_rules_in_proper_state(cl_args.ruleset,
                                            cl_args.ipv, cl_args.present)
    end
end

--- Check is rule or group of rules in expected state (present or absent)
-- @param cl_args   Comand line arguments
local function check_rules(cl_args)

    if rules_in_proper_state(cl_args) then
        return
    end

    local start_time = os.time()
    local timeout = cl_args.timeout or 0

    while os.difftime(os.time(), start_time) < timeout do
        cujo.log:debug("Waiting for rules to be in correct state...")
        os.execute("sleep 1")

        if rules_in_proper_state(cl_args) then
            return
        end
    end
    os.exit(ERR_NOT_MATCHING)
end

local run = {
    ['set'] = set_rules,
    ['clear'] = clear_rules,
    ['check'] = check_rules,
}

run[cl_arguments.command](cl_arguments)
