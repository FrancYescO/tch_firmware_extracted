--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2019 CUJO LLC. All rights reserved.
--

local argparse = require'argparse'
local table = require "table"

local supported_features = {'appblocker', 'fingerprint', 'safebro', 'trackerblock', 'tcptracker', 'apptracker'}
local set_rules_options = {'base', table.unpack(supported_features)}
local clear_rules_options = {'all', 'base', table.unpack(supported_features)}

-- validators for arguments which accept only predefined set of values
local function validate(field, tbl)
    for _, v in pairs(tbl) do
        if field == v then
            return field, nil
        end
    end

    local errormsg = "unrecognized value '" .. field .. "'\n" ..
    "       valid options are: '" .. table.concat(tbl, "' '") .. "'"
    return nil, errormsg
end

local function validate_set_rules_options(ruleset)
    return validate(ruleset, set_rules_options)
end

local function validate_clear_rules_options(ruleset)
    return validate(ruleset, clear_rules_options)
end

local function validate_ipv(ipv)
    return validate(ipv, {'ip4', 'ip6'})
end

local function validate_nf_table(tbl)
    return validate(tbl, {'filter', 'mangle'})
end

local parser = argparse("raptr", "rabid's netfilter rules manager")
parser:command_target("command")
parser:help_max_width(80)
parser:usage_margin(18)
parser:usage_max_width(80)
parser:help_description_margin(17)

parser:flag("-n --dry-run")
    :description("Do not execute, only print commands.")
    :default(false)

parser:mutex(
    parser:flag("-4", "Only IPv4 rules are affected.")
        :target("ipv")
        :action(function(args)
            args.ipv = 'ip4'
         end),
    parser:flag("-6", "Only IPv6 rules are affected.")
        :target("ipv")
        :action(function(args)
            args.ipv = 'ip6'
         end)
)

parser:flag("-v --verbose", "Increase log verbosity level." ..
        "Can be used multiple times, ie. -vvv will increase verbosity 3 levels up.")
    :count("*")

parser:flag("-q --quiet", "Decrease log verbosity level." ..
        "Can be used multiple times, ie. -qq will decrease verbosity 2 levels down.")
    :count("*")

-- raptr set <ruleset>
local cmd_set = parser:command("set")
    :description("Set named groups of netfilter rules.")

cmd_set:argument("ruleset")
    :description("Named set of rules\n{" .. table.concat(set_rules_options, " | ") .. "}")
    :convert(validate_set_rules_options)
    :args("1")

-- raptr clear <ruleset>
local cmd_clear = parser:command("clear")
    :description("Clear netfilter rules.")

cmd_clear:argument("ruleset")
    :description("Named set of rules\n{" .. table.concat(clear_rules_options, " | ") .. "}")
    :convert(validate_clear_rules_options)
    :args("1")

-- raptr check single [-h] <ipv> <table> -- <nf-rule>
-- raptr check group [-h] <ruleset>
local cmd_check = parser:command("check")
    :description("Check are given netfilter rule or set of rules in place or not.")

cmd_check:flag("-N --not-present")
    :description("Check that rule / all rules are NOT present.")
    :target("present")
    :action("store_false")
    :default(true)

cmd_check:option("-w --wait-applied")
    :description("If rules are not in expected state, wait up to given amount of seconds for the rules to be applied")
    :count("0-1")
    :convert(tonumber)
    :target("timeout")
    :defmode("a")
    :default("5")

local cmd_check_single = cmd_check:command("single")
    :description("Check is single netfilter rule present or not")
    -- there is no way to properly autogenerate this:
    :usage("Usage: raptr check single [-h] <ipv> <table> -- <nf-rule>")
    :epilog("NOTE: <nf-rule> must be provided after '--' to prevent interpreting rule flags as flags of this tool")

cmd_check_single:argument("ipv")
    :description("IP family to which rule belongs ({ip4 | ip6})")
    :convert(validate_ipv)
    :args("1")

cmd_check_single:argument("table")
    :description("Affected netfilter table ({filter | mangle})")
    :convert(validate_nf_table)
    :args("1")

cmd_check_single:argument("nf-rule")
    :description("netfilter rule in format of output of 'iptables -S' command")
    :args("+")
    :target("nf_rule")
    :argname("-- <nf-rule>")

local cmd_check_group = cmd_check:command("group")
    :description("Check named set of rules")

cmd_check_group:argument("ruleset")
    :description("Named set of rules\n{" .. table.concat(set_rules_options, " | ") .. "}")
    :convert(validate_set_rules_options)
    :args("1")

-- show usage of all commands when running 'raptr -h'
local top_usage = "Usage: \n" ..
        parser:get_usage():gsub("Usage: ", "       ") .. "\n" ..
        cmd_set:get_usage():gsub("Usage: ", "       ") .. "\n" ..
        cmd_clear:get_usage():gsub("Usage: ", "       ") .. "\n" ..
        cmd_check_group:get_usage():gsub("Usage: ", "       ") .. "\n" ..
        cmd_check_single:get_usage():gsub("Usage: ", "       ")
parser:usage(top_usage)

local args = parser:parse()

if args.dry_run and args.command == 'check' then
    local usage = "Usage: \n" ..
            cmd_check_group:get_usage():gsub("Usage: ", "       ") .. "\n" ..
            cmd_check_single:get_usage():gsub("Usage: ", "       ")
    parser:usage(usage)
    parser:error("-n/--dry-run flag cannot be used with 'check' command")
end

if args.nf_rule then
    if not table.concat(arg, " "):find(" %-%- ") then
        cmd_check_single:error("<nf-rule> must be provided after '--'")
    end
end

if args.command == 'check' and args.single then
    -- Does input parameters contain -4 or -6 flags
    for _, a in ipairs(arg) do
        if a == '--' then
            break
        end
        if a == '-4' or a == '-6' then
            cmd_check_single:error("-4 / -6 flags cannot be used with 'check single' command")
        end
    end
end

args.verbose = args.verbose - args.quiet + 1
args.verbose = math.max(args.verbose, 0)

return args
