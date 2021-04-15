local M = {}
local uciHelper = require("transformer.mapper.ucihelper")
local setOnUci = uciHelper.set_on_uci
local getFromUci = uciHelper.get_from_uci
local foreachOnUci = uciHelper.foreach_on_uci
local fxsBinding = { config = "mmpbxbrcmfxsdev" }
local sipnetBinding = { config = "mmpbxrvsipnet", sectionname = "sip_net" }
local mmpbxBinding = { config = "mmpbx"}
local countryBinding = { config = "mmpbxbrcmcountry", sectionname = "global_provision" }

local qosField, qosValue

function M.getEnable(binding)
    binding.option = "enabled"
    return getFromUci(binding)
end

function M.setEnable(binding, value, commitapply)
    binding.option = "enabled"
    if getFromUci(binding) ~= value then
        setOnUci(binding, value, commitapply)
    end
end

function M.getMaxSessions()
    -- Must be less than or equal to VoiceService.{i}.Capabilities.MaxSessionCount
    -- Multi.Services.VoiceService.1.Capabilities.MaxSessionCount = 4
    local numOfFxs, numOfDect, numOfSipdev = 0, 0, 0
    sipnetBinding.option = "cac"
    local cac = getFromUci(sipnetBinding)
    cac = tonumber(cac)
    if cac == nil or cac == 0 or cac < -1 then
        return ""
    elseif cac == -1 or 2 * cac > 4 then
        local maxSessions = numOfFxs * 2
        if numOfDect <= 1 then
            maxSessions = maxSessions + numOfDect * 2
        end
        -- 4 simultaneous DECT calls
        maxSessions = maxSessions + 4
        maxSessions = maxSessions + numOfSipdev * 2
        return tostring(maxSessions)
    else
        return tostring(2 * cac)
    end
end

function M.setMaxSessions(paramValue, transactions, commitapply)
    -- Must be less than or equal to VoiceService.{i}.Capabilities.MaxSessionCount
    -- Multi.Services.VoiceService.1.Capabilities.MaxSessionCount = 4
    local numOfFxs, numOfDect, numOfSipdev = 0, 0, 0
    paramValue = tonumber(paramValue)
    sipnetBinding.option = "cac"
    if paramValue == 2 or paramValue == 4 then
        paramValue = paramValue/2
        setOnUci(sipnetBinding, paramValue, commitapply)
        transactions[sipnetBinding.config] = true
    elseif paramValue > 4 then
        -- The value must be less than or equal to VoiceService.{i}.Capabilities.MaxSessionCount
        -- This MAY be greater than the number of lines if each line can support more than one session
        if (numOfFxs + numOfDect + numOfSipdev) > 2 then
            paramValue = -1
            setOnUci(sipnetBinding, paramValue, commitapply)
            transactions[sipnetBinding.config] = true
        else
            return nil, "Less than 2 devices are configured, so the MaxSessions must be less than 5"
        end
    else
        return nil, "The value must be non-zero even number"
    end
end

local function revTable(inTable)
    local reverseTable = { }
    for key , value in pairs(inTable) do
        reverseTable[value] = key
    end
    return reverseTable
end

local dscp = {
    cs0 = "0",
    cs1 = "8",
    af11 = "10",
    af12 = "12",
    af13 = "14",
    cs2 = "16",
    af21 = "18",
    af22 = "20",
    af23 = "22",
    cs3 = "24",
    af31 = "26",
    af32 = "28",
    af33 = "30",
    cs4 = "32",
    af41 = "34",
    af42 = "36",
    af43 = "38",
    cs5 = "40",
    ef = "46",
    cs6 = "48",
    cs7 = "56",
}

local revDscp = revTable(dscp)

local precedence = {
    ["routine"] = "0",
    ["priority"] = "8",
    ["immediate"] = "16",
    ["flash"] = "24",
    ["flash override"] = "32",
    ["critic/ecp"] = "40",
    ["internetwork control"] = "48",
    ["network control"] = "50",
}

local revPrecedence = revTable(precedence)

function M.getDscpMark(object, fieldOption, valueOption)
    qosField, qosValue = "", ""
    if type(object) == "table" then
        if object[fieldOption] and object[valueOption] then
            qosField = object[fieldOption]
            qosValue = object[valueOption]
        else
            object.option = fieldOption
            qosField = getFromUci(object)
            object.option = valueOption
            qosValue = getFromUci(object)
        end
        local dscpMark = ""
        if qosField == "dscp" then
            dscpMark = dscp[qosValue]
        elseif qosField == "precedence" then
            dscpMark = precedence[qosValue]
        end
        if not dscpMark then
            dscpMark = qosValue or ""
        end
        return dscpMark
    end
    return ""
end

function M.setDscpMark(binding, value, fieldOption, valueOption, transactions, commitapply)
    binding.option = fieldOption
    qosField = getFromUci(binding)
    local checkValue = value
    if (qosField == "dscp") then
        checkValue = revDscp[value]
    elseif (qosField == "precedence") then
        local precedenceOrder = checkValue
        if (checkValue ~= "50") then
            precedenceOrder = tostring (math.modf(checkValue/8)*8)
        end
        checkValue = revPrecedence[precedenceOrder]
    end
    if checkValue then
        value = checkValue
    end
    binding.option = valueOption
    setOnUci(binding, value, commitapply)
    transactions[binding.config] = true
    value = string.upper(value)
    local qosBinding
    if (fieldOption == "control_qos_field") then
        qosBinding = { config = "qos", sectionname = "Voice_Sig", option = "dscp"}
    else
        qosBinding = { config = "qos", sectionname = "Voice_Data", option = "dscp"}
    end
    setOnUci(qosBinding, value, commitapply)
    transactions[qosBinding.config] = true
    return transactions
end

function M.getVlanIdMark(object)
    local vid = ""
    sipnetBinding.option = "interface"
    local interface = getFromUci(sipnetBinding)
    if interface ~= "" then
        local networkBinding = { config = "network", sectionname = interface, option = "ifname"}
        local ifname = getFromUci(networkBinding)
        if ifname ~= "" then
            networkBinding = { config = "network", sectionname = ifname, option = "vid"}
            vid = getFromUci(networkBinding)
        end
    end
    return vid ~= "" and vid or "-1"
end

function M.getDtmfMethod()
    sipnetBinding.option = "dtmf_relay"
    return getFromUci(sipnetBinding) or ""
end

local dtmfSetmap = setmetatable({
    --RFC4733 is not supported in mmpbx currently
    RFC4733 = "rfc2833",
    RFC2833 = "rfc2833",
    SIPInfo = "sipinfo",
    InBand  = "disabled",
}, { __index = function() return "" end })

function M.setDtmfMethod(paramValue, transactions, commitapply)
    if dtmfSetmap[paramValue] then
        sipnetBinding.option = "dtmf_relay"
        setOnUci(sipnetBinding, dtmfSetmap[paramValue], commitapply)
        transactions[sipnetBinding.config] = true

        mmpbxBinding.sectionname = "codec_filter"
        fxsBinding.sectionname = "device"
        fxsBinding.option = "codec_black_list"
        if (paramValue == "InBand" or paramValue == "SIPInfo" ) then
            foreachOnUci(mmpbxBinding, function(s)
                if s.name == "telephone-event" then
                    mmpbxBinding.sectionname = s[".name"]
                    mmpbxBinding.option = "allow"
                    setOnUci(mmpbxBinding, "0", commitapply)
                    transactions[mmpbxBinding.config] = true
                end
            end)

            local check = 0
            foreachOnUci(fxsBinding, function(s)
                if s[".name"] then
                    fxsBinding.sectionname = s[".name"]
                    local blackList = getFromUci(fxsBinding)
                    if (#blackList ~= 0) then
                        check = 0
                        for _, value in ipairs(blackList) do
                            if value == "telephone-event" then
                                check = 1
                                break
                            end
                        end
                    else
                        blackList = {}
                    end
                    if check == 0 then
                        blackList[#blackList + 1] = "telephone-event"
                        setOnUci(fxsBinding, blackList)
                        transactions[fxsBinding.config] = true
                    end
                end
            end)
        elseif (paramValue == "RFC4733")  or (paramValue == "RFC2833") then
            foreachOnUci(mmpbxBinding, function(s)
                if s.name == "telephone-event" then
                    mmpbxBinding.sectionname = s[".name"]
                    mmpbxBinding.option = "allow"
                    setOnUci(mmpbxBinding, "1", commitapply)
                    transactions[mmpbxBinding.config] = true
                end
            end)
            foreachOnUci(fxsBinding, function(s)
                if s[".name"] then
                    fxsBinding.sectionname = s[".name"]
                    local blackList = getFromUci(fxsBinding)
                    if (#blackList ~= 0) then
                        for index, value in ipairs(blackList) do
                            if value == "telephone-event" then
                                table.remove(blackList,index)
                                index = index - 1
                            end
                        end
                        setOnUci(fxsBinding, blackList)
                        transactions[fxsBinding.config] = true
                    end
                end
            end)
        end
    return transactions
    else
        return nil, "invalid value"
    end
end

function M.getPayLoadType()
    local id
    mmpbxBinding.sectionname = "codec_filter"
    foreachOnUci(mmpbxBinding, function(s)
        if s.name == "telephone-event" then
            if s.dynamic_rtp_payload_type then
                id = s.dynamic_rtp_payload_type
            else
                id = "96"
            end
        end
   end)
   return id
end


function M.setPayLoadType(paramValue, transactions, commitapply)
    mmpbxBinding.sectionname = "codec_filter"
    local binding = {config = "mmpbx"}
    foreachOnUci(mmpbxBinding, function(s)
        if ((s.name == "telephone-event") and ((s.media_filter == "media_filter_audio_generic") or (s.media_filter == "media_filter_audio_sip"))) then
             binding.sectionname = s[".name"]
             binding.option = "dynamic_rtp_payload_type"
             setOnUci(binding, paramValue, commitapply)
             transactions[binding.config] = true
             return true
         end
    end)
    return true
end

function M.getTxGain()
    countryBinding.option = "tx_gain_fxs"
    return getFromUci(countryBinding)
end

function M.getRxGain()
    countryBinding.option = "rx_gain_fxs"
    return getFromUci(countryBinding)
end

function M.setTxGain(paramName, paramValue, transactions, commitapply)
    countryBinding.option = "tx_gain_fxs"
    local transmitGain = setOnUci(countryBinding, paramValue, commitapply)
    transactions[countryBinding.config] = true
    return transmitGain
end

function M.setRxGain(paramName, paramValue, transactions, commitapply)
    countryBinding.option = "rx_gain_fxs"
    local receiveGain = setOnUci(countryBinding, paramValue, commitapply)
    transactions[countryBinding.config] = true
    return receiveGain
end

local cidModeValueMap = {
    ["0"] = "RING",
    ["1"] = "LRCARIR",
    ["2"] = "DTAS",
    ["3"] = "RPAS",
    ["4"] = "LRAS",
}

local function cidModeNameMap(paramValue)
    for cidValue, modeName in pairs(cidModeValueMap) do
        if paramValue == modeName then
            return cidValue
        end
    end
end

function M.getCidMode()
    countryBinding.option = "cid_mode"
    return cidModeValueMap[getFromUci(countryBinding)] or ""
end

function M.setCidMode(paramValue, transactions, commitapply)
    countryBinding.option = "cid_mode"
    setOnUci(countryBinding, cidModeNameMap(paramValue), commitapply)
    transactions[countryBinding.config] = true
    return true
end

return M
