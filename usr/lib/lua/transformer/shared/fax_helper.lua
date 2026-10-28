local M = {}
local uciHelper = require("transformer.mapper.ucihelper")
local brcmfxsBinding = { config = "mmpbxbrcmfxsdev" }
local getFromUci = uciHelper.get_from_uci
local foreachOnUci = uciHelper.foreach_on_uci
local setOnUci = uciHelper.set_on_uci

local function getT38Redundancy(mapping, param, key)
    brcmfxsBinding.sectionname = "global"
    brcmfxsBinding.option = "t38_redundancy"
    local redundancyValue = getFromUci(brcmfxsBinding)
    if redundancyValue ~= nil and redundancyValue >= "0" and redundancyValue <= "3" then
        return redundancyValue
    end
    return ""
end

function M.setT38Redundancy(mapping, paramName, paramValue, key, transactions, commitapply)
    brcmfxsBinding.sectionname = "global"
    brcmfxsBinding.option = "t38_redundancy"
    if paramValue ~= nil then
        setOnUci(brcmfxsBinding, paramValue, commitapply)
    end
end

local function getFaxT38Enable(mapping, param, key)
    local listFxs = {}
    local fxsFaxTransportValue = "t38"
    brcmfxsBinding.sectionname = "device"
    brcmfxsBinding.option = "fax_transport"
    foreachOnUci(brcmfxsBinding, function(s)
        brcmfxsBinding.sectionname = s[".name"]
        listFxs[#listFxs+1] = getFromUci(brcmfxsBinding)
    end)
    if #listFxs then
        for _, deviceValue in pairs(listFxs) do
            if deviceValue ~= fxsFaxTransportValue then
                fxsFaxTransportValue = deviceValue
            end
        end
    end
    brcmfxsBinding.sectionname = "global"
    local globalFaxTransportValue = getFromUci(brcmfxsBinding)
    return ((fxsFaxTransportValue == globalFaxTransportValue) and fxsFaxTransportValue == "t38") and "1" or "0"
end

local faxValue = {
    ["0"] = "inband_renegotiation",
    ["1"] = "t38"
}

function M.setFaxT38Enable(mapping, paramName, paramValue, key, transactions, commitapply)
    local fxsList = {}
    brcmfxsBinding.sectionname = "device"
    brcmfxsBinding.option = "fax_transport"
    foreachOnUci(brcmfxsBinding, function(s)
        fxsList[#fxsList+1] = s[".name"]
    end)
    if #fxsList then
        for _, fxsSection in pairs(fxsList) do
            brcmfxsBinding.sectionname = fxsSection
            setOnUci(brcmfxsBinding, faxValue[paramValue], commitapply)
            transactions[brcmfxsBinding.config] = true
        end
    end
    brcmfxsBinding.sectionname = "global"
    setOnUci(brcmfxsBinding, faxValue[paramValue], commitapply)
    transactions[brcmfxsBinding.config] = true
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

return M
