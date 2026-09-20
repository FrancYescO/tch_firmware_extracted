--
-- This file is Confidential Information of CUJO LLC.
-- Copyright (c) 2019 CUJO LLC. All rights reserved.
--

--- @module ipsetparser

--- Parser of IP sets
-- This function creates 'object' that contains parsed output of 'ipset -n list' command.
-- TODO: Currently only name of the set is stored and checked, verify also
--       that rest of the ipset command is matching
-- @param ipset_bin     Path to ipset binary
local function ipset_parser(ipset_bin)

    -- private
    local self = {}
    self.ipset_bin = ipset_bin
    self.setnames = {}
    self.log = function () end

    --- Get output of ipset --list command
    -- @return Output of 'ipset --list' command as list of lines
    local function get_current_setnames()

        local proc = assert(io.popen(self.ipset_bin .. " -n list"),
                            "Failed to get IP sets")
        local data = {}

        repeat
            local line = proc:read()
            data[#data + 1] = line
        until line == nil

        proc:close()

        return data
    end

    --- Parse IP sets into Lua table for quick lookups
    local function parse_ipset_list()

        local ipset_dump = get_current_setnames()

        for _, line in pairs(ipset_dump) do
            self.setnames[line] = true
        end
    end

    parse_ipset_list()

    -- Check does given rule exist in netfilter table for given IP version
    -- @param setname       Name of IP set
    -- @return true, if set with given name is found; false, otherwise
    local function is_setname_present(setname)
        return self.setnames[setname] ~= nil
    end

    return {
        is_setname_present = is_setname_present,
    }
end

return ipset_parser
