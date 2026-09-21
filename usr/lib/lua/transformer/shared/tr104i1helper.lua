local M = {}
local duplicator = require('transformer.mapper.multiroot').duplicate

--tr104i1VoiceServiceParameters table contains parameters specific to TR104I1 VoiceService DM object
local tr104i1VoiceServiceParameters = {
    X_000E50_FXOState = "true",
    X_000E50_FXSState = "true",
    X_000E50_VoiceUplinkRateLimit = "true",
    X_FASTWEB_BoundIfName = "true",
    X_TELSTRA_ActiveCall = "true",
    X_BELGACOM_PhyInterfaceNumberOfEntries = "true",
    VoiceProfileNumberOfEntries = "true",
}

--tr104i1Objects table contains all TR104I1 DM objects and parameters of corresponding objects which are to be registered
local tr104i1Objects = {
    {"Multi_Services_VoiceService_i_", tr104i1VoiceServiceParameters},
    {"Multi_Services_VoiceService_i_VoiceProfile_i_Line_i_Codec_List_i_"},
    {"Multi_Services_VoiceService_i_VoiceProfile_i_FaxT38_"},
    {"Multi_Services_VoiceService_i_Capabilities_Codecs_i_"},
    {"Multi_Services_VoiceService_i_VoiceProfile_i_SIP_"},
    {"Multi_Services_VoiceService_i_VoiceProfile_i_SIP_EventSubscribe_i_"},
    {"Multi_Services_VoiceService_i_VoiceProfile_i_Line_i_"},
    {"Multi_Services_VoiceService_i_VoiceProfile_i_Line_i_Stats_"},
}

--objectName is the name of the DM object table passed as a string from the mapping file
--objectMapping is the DM object table passed from the mapping file
--register is to register the DM object
function M.registerObject(objectName, objectMapping, register)
    for _, val in ipairs(tr104i1Objects) do
        if val[1] == objectName then
            local duplicates = duplicator(objectMapping, "#ROOT", {"InternetGatewayDevice", "Device"})
            for _, object in ipairs(duplicates) do
                if val[2] then
                    for params,_ in pairs(object.objectType.parameters) do
                        if not val[2][params] then
                            object.objectType.parameters[params] = nil
                        end
                    end
                end
                register(object)
            end
        end
    end
end

function M.getVoiceServiceEntries()
    return {"SIPUA", "INTUA"}
end

function M.getInfoFromKeyForLine(key, parentKey)
    local config, name, ltype
    config = parentKey:match("^(.*)|.*$")
    name, ltype = key:match("((%w+_%w+)_%d+)$")
    if not ltype then
        name = key
        if config:match("mmpbxmobilenet") then
            ltype = "mobile_profile"
        elseif config:match("mmpbxrvsipnet") then
            ltype = "sip_profile"
        end
    end
    return config, name, ltype
end

return M
