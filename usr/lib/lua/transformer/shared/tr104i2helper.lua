local M = {}
local duplicator = require('transformer.mapper.multiroot').duplicate

--tr104i2VoiceServiceParameters table contains parameters specific to TR104I2 VoiceService DM object
local tr104i2VoiceServiceParameters = {
    VoIPProfileNumberOfEntries = "true",
    CodecProfileNumberOfEntries = "true",
    InterworkNumberOfEntries = "true",
    TrunkNumberOfEntries = "true",
    CallLogNumberOfEntries = "true",
    TerminalNumberOfEntries = "true",
}

--tr104i2Objects table contains all TR104I2 DM objects and corresponding parameters of the object which are to be registered
local tr104i2Objects = {
    {"Multi_Services_VoiceService_i_", tr104i2VoiceServiceParameters},
    {"Multi_Services_VoiceService_i_CodecProfile_i_"},
    {"Multi_Services_VoiceService_i_CallControl_CallingFeatures_"},
    {"Multi_Services_VoiceService_i_CallControl_CallingFeatures_Set_i_"},
    {"Multi_Services_VoiceService_i_CallControl_Extension_i_Stats_"},
    {"Multi_Services_VoiceService_i_CallControl_Extension_i_Stats_IncomingCalls_"},
    {"Multi_Services_VoiceService_i_CallControl_Extension_i_Stats_OutgoingCalls_"},
    {"Multi_Services_VoiceService_i_CallControl_Extension_i_Stats_RTP_"},
    {"Multi_Services_VoiceService_i_CallControl_Extension_i_Stats_DSP_"},
    {"Multi_Services_VoiceService_i_VoIPProfile_i_"},
    {"Multi_Services_VoiceService_i_VoIPProfile_i_RTP_"},
    {"Multi_Services_VoiceService_i_VoIPProfile_i_FaxT38_"},
    {"Multi_Services_VoiceService_i_Capabilities_"},
    {"Multi_Services_VoiceService_i_Capabilities_Codec_i_"},
    {"Multi_Services_VoiceService_i_SIP_Network_i_"},
    {"Multi_Services_VoiceService_i_CallControl_"},
    {"Multi_Services_VoiceService_i_CallControl_Line_i_"},
    {"Multi_Services_VoiceService_i_CallControl_Line_i_Stats_"},
    {"Multi_Services_VoiceService_i_CallControl_Line_i_Stats_IncomingCalls_"},
    {"Multi_Services_VoiceService_i_CallControl_Line_i_Stats_OutgoingCalls_"},
    {"Multi_Services_VoiceService_i_CallControl_Line_i_Stats_RTP_"},
    {"Multi_Services_VoiceService_i_CallControl_Line_i_Stats_DSP_"},
    {"Multi_Services_VoiceService_i_CallControl_IncomingMap_i_"},
    {"Multi_Services_VoiceService_i_CallControl_OutgoingMap_i_"},
    {"Multi_Services_VoiceService_i_CallLog_i_"},
    {"Multi_Services_VoiceService_i_POTS_"},
    {"Multi_Services_VoiceService_i_POTS_FXS_i_"},
    {"Multi_Services_VoiceService_i_POTS_FXS_i_VoiceProcessing_"},
}

--objectName is the name of the DM object table passed as a string from the mapping file
--objectMapping is the DM object table passed from the mapping file
--register is to register the DM object
function M.registerObject(objectName, objectMapping, register)
    for _, val in ipairs(tr104i2Objects) do
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
    return {"SIPUA"}
end

local configurations = {
    config = "mmpbxrvsipnet",
    sectionname = "profile",
    parentKey =  "SIPUA",
}

function M.getInfoFromKeyForLine(key, parentKey)
    local config, name, ltype
    if parentKey == configurations["parentKey"] then
            config = configurations["config"]
    end
    name, ltype = key:match("((%w+_%w+)_%d+)")
    if not ltype then
        name = key
        if config:match("mmpbxrvsipnet") then
            ltype = "sip_profile"
        end
    end
    return config, name, ltype
end

return M
