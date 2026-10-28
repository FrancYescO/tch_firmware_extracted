local M = {}
local uciHelper = require("transformer.mapper.ucihelper")
local setOnUci = uciHelper.set_on_uci
local getFromUci = uciHelper.get_from_uci
local sipnetBinding = { config="mmpbxrvsipnet" }
local binding = {}

function M.getEnable(binding)
    binding.option = "enabled"
    return getFromUci(binding)
end

function M.setEnable(binding, value)
    binding.option = "enabled"
    if getFromUci(binding) ~= value then
        setOnUci(binding, value, commitapply)
    end
end

function M.getMaxsessions(mapping, param, key)
    -- Must be less than or equal to VoiceService.{i}.Capabilities.MaxSessionCount
    -- Multi.Services.VoiceService.1.Capabilities.MaxSessionCount = 4
    local numOfFxs, numOfDect, numOfSipdev = 0, 0, 0
    sipnetBinding.sectionname = "sip_net"
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

function M.setMaxsessions(mapping, paramValue, paramName, key, commitapply)
    -- Must be less than or equal to VoiceService.{i}.Capabilities.MaxSessionCount
    -- Multi.Services.VoiceService.1.Capabilities.MaxSessionCount = 4
    local numOfFxs, numOfDect, numOfSipdev = 0, 0, 0
    paramValue = tonumber(paramValue)
    sipnetBinding.sectionname = "sip_net"
    sipnetBinding.option = "cac"
    if paramValue == 2 or paramValue == 4 then
        paramValue = paramValue/2
        setOnUci(sipnetBinding, paramValue, commitapply)
    elseif paramValue > 4 then
        -- The value must be less than or equal to VoiceService.{i}.Capabilities.MaxSessionCount
        -- This MAY be greater than the number of lines if each line can support more than one session
        if (numOfFxs + numOfDect + numOfSipdev) > 2 then
            paramValue = -1
            setOnUci(sipnetBinding, paramValue, commitapply)
        else
            return nil, "Less than 2 devices are configured, so the MaxSessions must be less than 5"
        end
    else
        return nil, "The value must be non-zero even number"
    end
end

return M
