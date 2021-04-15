local M = {}
local uciHelper = require("transformer.mapper.ucihelper")
local fxsBinding = { config = "mmpbxbrcmfxsdev" }
local getFromUci = uciHelper.get_from_uci
local foreachOnUci = uciHelper.foreach_on_uci
local setOnUci = uciHelper.set_on_uci

local faxThrough = setmetatable({
    inband_renegotiation = "Auto",
    t38 = "Auto",
    disabled = "Disable",
    Auto = "inband_renegotiation",
    Disable = "disabled",
}, { __index = function() return "" end })

local function getT38Redundancy(mapping, param, key)
    fxsBinding.sectionname = "global"
    fxsBinding.option = "t38_redundancy"
    local redundancyValue = getFromUci(fxsBinding)
    if param == "HighSpeedRedundancy" and redundancyValue <= "3" then
        return redundancyValue
    elseif param == "LowSpeedRedundancy" and redundancyValue <= "5" then
        return redundancyValue
    end
    return ""
end

function M.setT38Redundancy(mapping, paramName, paramValue, key, transactions, commitapply)
    fxsBinding.sectionname = "global"
    fxsBinding.option = "t38_redundancy"
    if paramValue ~= nil then
        setOnUci(fxsBinding, paramValue, commitapply)
    end
end

local function getFaxT38Enable(mapping, param, key)
    local listFxs = {}
    local fxsFaxTransportValue = "t38"
    fxsBinding.sectionname = "device"
    fxsBinding.option = "fax_transport"
    foreachOnUci(fxsBinding, function(s)
        fxsBinding.sectionname = s[".name"]
        listFxs[#listFxs+1] = getFromUci(fxsBinding)
    end)
    if #listFxs then
        for _, deviceValue in pairs(listFxs) do
            if deviceValue ~= fxsFaxTransportValue then
                fxsFaxTransportValue = deviceValue
            end
        end
    end
    fxsBinding.sectionname = "global"
    local globalFaxTransportValue = getFromUci(fxsBinding)
    return ((fxsFaxTransportValue == globalFaxTransportValue) and fxsFaxTransportValue == "t38") and "1" or "0"
end

local faxValue = {
    ["0"] = "inband_renegotiation",
    ["1"] = "t38"
}

function M.setFaxT38Enable(mapping, paramName, paramValue, key, transactions, commitapply)
    local fxsList = {}
    fxsBinding.sectionname = "device"
    fxsBinding.option = "fax_transport"
    foreachOnUci(fxsBinding, function(s)
        fxsList[#fxsList+1] = s[".name"]
    end)
    if #fxsList then
        for _, fxsSection in pairs(fxsList) do
            fxsBinding.sectionname = fxsSection
            setOnUci(fxsBinding, faxValue[paramValue], commitapply)
            transactions[fxsBinding.config] = true
        end
    end
    fxsBinding.sectionname = "global"
    setOnUci(fxsBinding, faxValue[paramValue], commitapply)
    transactions[fxsBinding.config] = true
end

local faxParams = {
    Enable = function(mapping, param, key)
        return getFaxT38Enable(mapping, param, key)
    end,
    LowSpeedRedundancy = function(mapping, param, key)
        return getT38Redundancy(mapping, param, key)
    end,
    HighSpeedRedundancy = function(mapping, param, key)
        return getT38Redundancy(mapping, param, key)
    end,
    BitRate = "14400",
    MaxBitRate = "14400",
    TCFMethod = "Network",
    HighSpeedPacketRate = "20"
}

function M.getFaxParam(mapping, param, key)
    return function(mapping, param, key)
        if faxParams[param] then
            if type(faxParams[param]) == "function" then
                return faxParams[param](mapping, param, key) or ""
            end
            return faxParams[param] or ""
        end
        return ""
    end
end

function M.getFaxPassThrough()
    fxsBinding.sectionname = "global"
    fxsBinding.option = "fax_transport"
    local faxTransport = getFromUci(fxsBinding)
    return faxThrough[faxTransport] or  ""
end

function M.setFaxPassThrough(value, transactions, commitapply)
    fxsBinding.sectionname = "global"
    fxsBinding.option = "fax_transport"
    setOnUci(fxsBinding, faxThrough[value], commitapply)
    transactions[fxsBinding.config] = true
end

return M
