local M = {}
local gsub, sub, match, len, find = string.gsub, string.sub, string.match, string.len, string.find
local uci_helper = require("transformer.mapper.ucihelper")

local dialPlanDefaultOptionsMap = {
    ['enabled'] = 1,
    ['allow'] = 1,
    ['priority'] = "low",
    ['include_eon'] = 0,
    ['apply_forced_profile'] = 0,
    ['min_length'] = 1,
    ['max_length'] = 1
}

local patternTable = {
    ['('] = "%b()",
    ['['] = "%b[]",
    ['{'] = "%b{}"
}

local function delimeterSeparatedDigits(pattern)
    local i = 0
    local j = 1
    local count = 0
    for i = 1, len(pattern) do
        if sub(pattern , i, i)  == "|" then
            if count < (i - j) then
                count = i - j
            end
            j = i + 1
        end
    end
    return count
end

local function findPatternLength(pattern)
    local pcount = 0
    local pcount2 = 0
    local pcount3 = 0
    local j = 1
    local k = 1
    local i = 0
    local subpattern = pattern:gsub("%b{}", "")    -- remove quantifiers
    local subpattern1 = subpattern:gsub("%b()", "")
    local subpattern2 = subpattern1:gsub("%b[]", "")
    if subpattern1 then
        for i = 1, len(subpattern1) do
            if sub(subpattern1, i, i) == "[" then
                pcount = pcount + 1
            end
        end
        pcount2 = delimeterSeparatedDigits(subpattern1)
    end
    if subpattern then
        for i = 1, len(subpattern) do
            if sub(subpattern , i, i ) == "(" then
                local subpattern3 = ""
                for k = i + 1, len(subpattern) do
                    if sub(subpattern, k, k) == ")" then
                        break
                    else
                        subpattern3 = subpattern3 .. sub(subpattern, k, k)   -- get sub-pattern inside ()
                    end
                end
                if subpattern3 ~= "" then
                    i = k + 1
                    if subpattern3:find("%b[]") then
                        local subpattern = subpattern3:gsub("%b[]", "*")
                        if not match(subpattern, "|") then
                            pcount3 = len(subpattern)
                        else
                            pcount3 = delimeterSeparatedDigits(subpattern)
                        end
                    else
                        pcount3 = findPatternLength(subpattern3) - len(subpattern3)
                    end
                end
            end
        end
    end
    return (subpattern2 and len(subpattern2) or 0) + pcount + pcount2 + pcount3
end

local set_binding = { config = "mmpbx" }

-- The addPatternToUci function creates a new dial plan entry section for the input pattern, writes the pattern & related options to uci
local function addPatternToUci(pattern, dialPlanName, index, transactions, commitapply)
    if not pattern or pattern == "" then
        return
    end
    if dialPlanName == "dial_plan_generic" then
        set_binding.sectionname = "dial_plan_entry_generic_" .. index
    else
        set_binding.sectionname = "dial_plan_entry_" .. index
    end
    set_binding.option = nil
    uci_helper.set_on_uci(set_binding, "dial_plan_entry", commitapply)
    set_binding.option = "dial_plan"
    uci_helper.set_on_uci(set_binding, dialPlanName, commitapply)

    local pattern1 = pattern:gsub(".T","")        -- remove .T; pattern1 will be used to calculate length
    set_binding.option = "pattern"
    uci_helper.set_on_uci(set_binding, "^" .. pattern1, commitapply)

    set_binding.option = "index"
    uci_helper.set_on_uci(set_binding, index, commitapply)

    -- add the default options for the dial plan entry
    for key, val in pairs(dialPlanDefaultOptionsMap) do
        set_binding.option = key
        uci_helper.set_on_uci(set_binding, val, commitapply)
    end

    --- overwirte default min & max lengths with actual values from pattern
    local min_len = findPatternLength(pattern1)
    set_binding.option = "min_length"
    uci_helper.set_on_uci(set_binding, min_len, commitapply)

    set_binding.option = "max_length"
    if pattern:match(".*()T") then
        uci_helper.set_on_uci(set_binding, min_len + 10, commitapply)
    else
        uci_helper.set_on_uci(set_binding, min_len, commitapply)
    end
    transactions[set_binding.config] = true
end

-- The parseSetPattern parses the input digitmap string (| de-limited) and identifies individual patterns.
-- when each pattern identified, the remaining part of the digitmap string is parsed further
local function parseSetPattern(dmstring, dialPlanName, transactions, commitapply)
    if not dmstring or dmstring == "" then
        return
    end
    local pcount = 0  -- index to track identified patterns
    local endIndex = 1       -- index to track end of brackets
    local startIndex = 0
    local dmIndex = 1       -- to track completion of dmstring parsing
    local index = 1       -- index to parse each subpattern
    local subpattern = ""
    local remainingStr = ""
    local parsestring = dmstring
    local ch = ""
    local patternTableChar = ""
    while parsestring and dmIndex < #dmstring do
        while index and index < #parsestring do
            subpattern = ""
            remainingStr = ""
            dmIndex = dmIndex + 1

            -- check for any brackets & if found update the current index to end of the closing bracket
            ch = sub(parsestring, index, index)
            if patternTable[ch] then
                startIndex, endIndex = parsestring:find(patternTable[ch])
                if not endIndex then
                    return nil, "Invalid digitmap string"
                end
                if patternTableChar == ch then
                    index = index + 1
                else
                    index = endIndex
                end
                patternTableChar = ch
            end

            -- parse till the delimiter "|" to find the pattern
            if sub(parsestring, index, index) == "|" then
               subpattern = sub(parsestring, 1, index - 1)
               remainingStr = sub(parsestring, index + 1, #parsestring)
               pcount = pcount + 1
               addPatternToUci(subpattern, dialPlanName, pcount, transactions, commitapply)
               parsestring = remainingStr
               patternTableChar = ""
               index = 1
               break
            end
            index = index + 1
            if index >= #parsestring then
                pcount = pcount + 1
                addPatternToUci(parsestring, dialPlanName, pcount, transactions, commitapply)
                patternTableChar = ""
                dmIndex = #dmstring
                break
            end
        end
    end
    return true
end

function M.getDigitMap()
    local resPrioHigh = ""
    local resPrioLow = ""
    local planName = ""
    local binding = { config = "mmpbx" , sectionname = "dial_plan"}

    -- get the dial plan name for which sip_net is configured
    uci_helper.foreach_on_uci(binding,function(s)
        local network = s.network
        if network and type(network) == "table" then
            for _,v in pairs(network) do
                if v == "sip_net" then
                    planName = s[".name"]
                end
            end
        end
    end)

    binding.sectionname = "dial_plan_entry"
    uci_helper.foreach_on_uci(binding,function(s)
        if s.dial_plan and s.dial_plan == planName and s.enabled and s.enabled == "1" and s.allow and s.allow == "1" then
            local pattern = s.pattern and gsub(s.pattern, "%^", "") or ""
            local length = findPatternLength(pattern)
            local digitHolder = ""
            local min_length = s.min_length and tonumber(s.min_length) or 0
            local max_length = s.max_length and tonumber(s.max_length) or 0
            if length < min_length then
                for i = length + 1 , min_length do
                    digitHolder = digitHolder .. "x"
                end
                pattern = pattern .. digitHolder
            end
            if min_length < max_length then
                pattern = pattern .. ".T"
            end
            if s.priority and s.priority == "high" then
                resPrioHigh  =  resPrioHigh ~= "" and string.format(resPrioHigh .. "|" .. pattern) or pattern
            else
                resPrioLow = resPrioLow ~= "" and string.format(resPrioLow .. "|" .. pattern) or pattern
            end
        end
    end)
    return resPrioHigh ~= "" and resPrioHigh .. "|" .. resPrioLow or resPrioLow
end

function M.setDigitMap(paramname, paramvalue, transactions, commitapply)
    local resPrioHigh = ""
    local resPrioLow = ""
    local planName = ""
    local binding = { config = "mmpbx" , sectionname = "dial_plan"}
    local del_binding = { config = "mmpbx" }

    -- get the dial plan name for which sip_net is configured
    uci_helper.foreach_on_uci(binding,function(s)
        local network = s.network
        if type(network) == "table" then
            for _, v in ipairs(network) do
                if v == "sip_net" then
                    planName = s[".name"]
                end
            end
        end
    end)

    -- remove all the existing dial plan entries for the above dial plan (with sip_net network)
    binding.sectionname = "dial_plan_entry"
    uci_helper.foreach_on_uci(binding,function(s)
        if s.dial_plan == planName then
            del_binding.sectionname = s[".name"]
            del_binding.option = nil
            uci_helper.delete_on_uci(del_binding, commitapply)
            transactions[del_binding.config] = true
        end
    end)
    -- parse the digitMap string, get unique patterns and create new list of dial plan entries
    return parseSetPattern(paramvalue, planName, transactions, commitapply)
end

function M.validateDigitMapString(dmstring)
    -- Exclude delimeters inside () brackets while counting the number of patterns
    local digitMapString = dmstring:gsub("%b()", "")
    local _, numberOfDelimeters = gsub(digitMapString, "|", "")
    -- Number of patterns in a digitmap can be accounted as number of delimeters added by one
    if numberOfDelimeters + 1 > 254 then
        return false
    end
    if not dmstring or dmstring == "" then
        return true
    end
    if #dmstring > 2048 then
        return  false
    end
    local endPattern = ""
    local patternIndex = 1
    local patternCount = 1
    local index = 1
    local character = ""
    local endChar = ""
    local patternTable = {
       ['('] = ")",
       ['['] = "]",
       ['{'] = "}",
    }
    local ignorepatternTable = {
       [')'] = true,
       [']'] = true,
       ['}'] = true,
    }
    while index <= #dmstring do
        character = sub(dmstring, index, index)
        if not match(character, '[-+|0-9TXx%[%]%.#%*(){}]') then
            return  false
        end
        if ignorepatternTable[character] then
            patternCount = patternCount-1
        end
        if patternTable[character] then
            patternCount = patternCount+1
            endPattern = patternTable[character]
            endChar = sub(dmstring, #dmstring, #dmstring)
            patternIndex = index
            local char = ""
            while patternIndex and patternIndex <= #dmstring do
                char = sub(dmstring, patternIndex, patternIndex)
                if ignorepatternTable[char] then
                    break
                end
                if char == endPattern or patternIndex == #dmstring then
                    endPatternIndex = patternIndex
                    setString = string.sub(dmstring, index, endPatternIndex)
                    local setIndex = 1
                    local iserror = 0
                    while setIndex and setIndex <= #setString do
                        setChar = sub(setString, setIndex, setIndex)
                        if setChar == endPattern or endChar == endPattern then
                            iserror = 1
                        end
                        setIndex = setIndex + 1
                    end
                    if iserror == 0 then
                        return false
                    end
                    break
                end
                patternIndex = patternIndex + 1
            end
        end
        index = index + 1
    end
    if patternCount ~= 1 then
        return false
    end
    return true
end

return M
