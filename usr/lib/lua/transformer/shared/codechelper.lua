local uciHelper = require("transformer.mapper.ucihelper")
local codecBinding = { config = "mmpbx", sectionname = "codec_filter" }
local M = {}
local match, format = string.match, string.format
local mt = { __index = function() return "" end }

local codecPtime = setmetatable({
    PCMU = "20",
    PCMA = "20",
    G722 = "20",
    ["G726-16"] = "20",
    ["G726-24"] = "20",
    ["G726-32"] = "20",
    ["G726-40"] = "20",
    G729 = "20",
    G723 = "30",
    ["telephone-event"] = "20",
    AMR = "20",
    G729E = "20",
    G728 = "20",
    ["GSM-EFR"] = "20",
    iLBC = "20"
}, mt)

local codecRates = setmetatable({
    PCMU = "64000",
    PCMA = "64000",
    G722 = "64000",
    ["G726-16"] = "16000",
    ["G726-24"] = "24000",
    ["G726-32"] = "32000",
    ["G726-40"] = "40000",
    G729 = "8000",
    G723 = "6300",
    AMR = "12200",
    G729E = "11800",
    G728 = "16000",
    ["GSM-EFR"] = "12200",
    iLBC = "15200"
}, mt)

local codecStandards = setmetatable({
    PCMU = "G.711MuLaw",
    PCMA = "G.711ALaw",
    G729 = "G.729",
    G722 = "G.722",
    ["G726-40"] = "G.726",
    ["G726-32"] = "G.726",
    ["G726-24"] = "G.726",
    ["G726-16"] = "G.726",
    AMR = "AMR",
    ["AMR-WB"] = "G.722.2"
}, mt)

local cvtBoolean = setmetatable({
    ['0'] = '1',
    ['1'] = '0',
}, mt)

local contentCodec = {}

local function getCodecSection(key)
    key = match(key, "^(.*)|")
    return contentCodec[key] or {}
end

local codecMap = {
    EntryID = function(s)
        return s._key  -- backwards compatibility; see entries()
    end,
    Codec = function(s)
       return codecStandards[s.name]
    end,
    BitRate = function(s)
        return codecRates[s.name]
    end,
    PacketizationPeriod = function(s)
        return codecPtime[s.name]
    end,
    SilenceSuppression = function(s)
        return cvtBoolean[s.remove_silence_suppression]
    end,
}

function M.getAllCodecParams(name)
    return function(mapping, key)
        local data = {}
        local codecSection = getCodecSection(key)
        for param,_ in pairs(name.objectType.parameters) do
            if codecMap[param] then
                if type(codecMap[param]) == "function" then
                    data[param] = codecMap[param](codecSection) or ""
                else
                    data[param] = codecSection[codecMap[param]] or ""
                end
            end
        end
        return data
    end
end

function M.getCodecParam()
    return function(mapping, param, key)
        local codecSection = getCodecSection(key)
        if codecMap[param] then
            if type(codecMap[param]) == "function" then
                return codecMap[param](codecSection) or ""
            else
                return codecSection[codecMap[param]] or ""
            end
        end
        return ""
    end
end

function M.getCodecEntries()
    return function(mapping, parentKey)
        local entries = {}
        local codecs = {}
        local entry = 0
        local name = ""
        local blackList
        local codecList = " "
        local mmpbxBinding = { config = "mmpbx" }
        local flag = 0
        local codecBlackList = ""
        local deviceBinding = {config = "mmpbxbrcmfxsdev", sectionname = "device"}
        -- there can be multiple codec filters with the same name (internal and
        -- sip have their own set of codecs) but here we should report each
        -- codec only once
        uciHelper.foreach_on_uci(deviceBinding, function(s)
            blackList = s.codec_black_list
            if blackList ~= nil then
                if type(blackList) == "table" and flag == 0 then
	            blackList = table.concat(blackList, " ")
	            flag = 1
                end
                if codecBlackList ~= "" then
	            if type(blackList) == "string" then
	                if match(codecBlackList, blackList) then
	                    codecList = codecList..blackList
	                end
	            elseif type(blackList) == "table" then
	                for _, codec in ipairs(blackList) do
	                    if match(codecBlackList, codec) then
	                        codecList = codecList..codec
	                    end
	                end
	            end
                else
	            codecBlackList = blackList
                end
            end
        end)
        uciHelper.foreach_on_uci(codecBinding, function(s)
            if s.name ~= "telephone-event" and s.name ~= "T38" and (not codecList:match(s.name))then
                entry = entry + 1
                name = s.name
                if ((not s._key) or (tonumber(s._key) == nil)) then
                    mmpbxBinding.sectionname = s[".name"]
                    mmpbxBinding.option = "_key"
                    s._key = tostring(uciHelper.generate_key_on_uci(mmpbxBinding, tonumber(entry)))
                    uciHelper.commit_keys(mmpbxBinding)
                end
                if not codecs[name] then
                    entries[#entries + 1] = format("%s|%s", entry, parentKey)
                    contentCodec[tostring(entry)] = s
                    codecs[name] = true
                end
            end
        end)
        return entries
    end
end

return M
