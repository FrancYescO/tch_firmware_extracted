local M = {}
local binding = {}
local uciHelper = require("transformer.mapper.ucihelper")
local conn = require("transformer.mapper.ubus").connect()
local getFromUci = uciHelper.get_from_uci
local find, sub, os = string.find, string.sub, os
local pairs, tostring, type = pairs, tostring, type
local tr104Helper = require("transformer.shared.tr104helper")

local incomingCallStatisticMap = {
    CallsReceived = "IncomingCallsReceived",
    CallsConnected = "IncomingCallsConnected",
    CallsFailed = "IncomingCallsFailed",
    CallsDropped = "IncomingCallsDropped",
    TotalCallTime = "IncomingCallsTime",
}

local outgoingCallStatisticMap = {
    CallsReceived = "OutgoingCallsReceived",
    CallsConnected = "OutgoingCallsConnected",
    CallsFailed = "OutgoingCallsFailed",
    CallsDropped = "OutgoingCallsDropped",
    TotalCallTime = "OutgoingCallsTime",
}

local callNumberStatisticMap = {
    PacketsSent = "PacketsSent",
    PacketsReceived = "PacketsReceived",
    BytesSent = "BytesSent",
    BytesReceived = "BytesReceived",
    PacketsLost = "PacketsLost",
    Overruns = "Overruns",
    Underruns = "Underruns",
    IncomingCallsReceived = "IncomingCallsReceived",
    IncomingCallsAnswered = "IncomingCallsAnswered",
    IncomingCallsConnected = "IncomingCallsConnected",
    IncomingCallsFailed = "IncomingCallsFailed",
    OutgoingCallsAttempted = "OutgoingCallsAttempted",
    CallsAttempted = "OutgoingCallsAttempted",
    OutgoingCallsAnswered = "OutgoingCallsAnswered",
    OutgoingCallsConnected = "OutgoingCallsConnected",
    OutgoingCallsFailed = "OutgoingCallsFailed",
    CallsDropped = "CallsDropped",
    TotalCallTime = "callTime",
    X_000E50_AccumAvgRTCPRoundTripDelay = "AverageRoundTripDelay",
    X_000E50_AccumInboundAvgInterarrivalJitter = "AverageReceiveInterarrivalJitter",
    X_000E50_AccumInboundCallCount = "IncomingCallsReceived",
    X_000E50_AccumInboundMaxInterarrivalJitter = "ReceiveMaxInterarrivalJitter",
    X_000E50_AccumInboundRTPPacketLoss = "PacketsLost",
    X_000E50_AccumInboundRTPPacketLossRate = "ReceivePacketLossRate",
    X_000E50_AccumInboundSumFractionLoss = "InboundSumFractionLoss",
    X_000E50_AccumInboundSumInterarrivalJitter = "InboundSumInterarrivalJitter",
    X_000E50_AccumInboundSumSqrFractionLoss = "InboundSumSqrFractionLoss",
    X_000E50_AccumInboundSumSqrInterarrivalJitter = "InboundSumSqrInterarrivalJitter",
    X_000E50_AccumInboundTotalRTCPPackets = "InboundTotalRTCPPackets",
    X_000E50_AccumInboundTotalRTCPXrPackets = "InboundTotalRTCPXrPackets",
    X_000E50_AccumMaxRTCPOneWayDelay = "MaxRTCPOneWayDelay",
    X_000E50_AccumMaxRTCPRoundTripDelay = "WorstRoundTripDelay",
    X_000E50_AccumOutboundAvgInterarrivalJitter = "AverageFarEndInterarrivalJitter",
    X_000E50_AccumOutboundCallCount = "OutgoingCallsAttempted",
    X_000E50_AccumOutboundMaxInterarrivalJitter = "FarEndReceiveMaxInterarrivalJitter",
    X_000E50_AccumOutboundRTPPacketLoss = "FarEndPacketsLost",
    X_000E50_AccumOutboundRTPPacketLossRate = "FarEndPacketLossRate",
    X_000E50_AccumOutboundSumFractionLoss= "OutboundSumFractionLoss",
    X_000E50_AccumOutboundSumInterarrivalJitter = "OutboundSumInterarrivalJitter",
    X_000E50_AccumOutboundSumSqrFractionLoss = "OutboundSumSqrFractionLoss",
    X_000E50_AccumOutboundSumSqrInterarrivalJitter = "OutboundSumSqrInterarrivalJitter",
    X_000E50_AccumOutboundTotalRTCPPackets = "OutboundTotalRTCPPackets",
    X_000E50_AccumOutboundTotalRTCPXrPackets = "OutboundTotalRTCPXrPackets",
    X_000E50_AccumSumRTCPOneWayDelay = "SumRTCPOneWayDelay",
    X_000E50_AccumSumRTCPRoundTripDelay = "SumRTCPRoundTripDelay",
    X_000E50_AccumSumSqrRTCPOneWayDelay = "SumSqrRTCPOneWayDelay",
    X_000E50_AccumSumSqrRTCPRoundTripDelay = "SumSqrRTCPRoundTripDelay"
}

local currentOngoingStatsMap = {
    ReceivePacketLossRate = "ReceivePacketLossRate",
    FarEndPacketLossRate = "FarEndPacketLossRate",
    ReceiveInterarrivalJitter = "ReceiveInterarrivalJitter",
    FarEndInterarrivalJitter = "FarEndInterarrivalJitter",
    RoundTripDelay = "RoundTripDelay",
    AverageRoundTripDelay = "AverageRoundTripDelay",
    AverageReceiveInterarrivalJitter = "AverageReceiveInterarrivalJitter",
    AverageFarEndInterarrivalJitter = "AverageFarEndInterarrivalJitter",
    X_000E50_CurrCallAvgRTCPRoundTripDelay = "AverageRoundTripDelay",
    X_000E50_CurrCallInboundAvgInterarrivalJitter = "AverageReceiveInterarrivalJitter",
    X_000E50_CurrCallInboundMaxInterarrivalJitter = "MaxReceiveInterarrivalJitter",
    X_000E50_CurrCallInboundRTPPacketLoss = "PacketsLost",
    X_000E50_CurrCallInboundRTPPacketLossRate = "ReceivePacketLossRate",
    X_000E50_CurrCallInboundSumFractionLoss = "InboundSumFractionLoss",
    X_000E50_CurrCallInboundSumInterarrivalJitter = "InboundSumInterarrivalJitter",
    X_000E50_CurrCallInboundSumSqrFractionLoss = "InboundSumSqrFractionLoss",
    X_000E50_CurrCallInboundSumSqrInterarrivalJitter = "InboundSumSqrInterarrivalJitter",
    X_000E50_CurrCallInboundTotalRTCPPackets = "InboundTotalRTCPPackets",
    X_000E50_CurrCallInboundTotalRTCPXrPackets = "InboundTotalRTCPXrPackets",
    X_000E50_CurrCallMaxRTCPOneWayDelay = "MaxRTCPOneWayDelay",
    X_000E50_CurrCallMaxRTCPRoundTripDelay = "WorstRoundTripDelay",
    X_000E50_CurrCallOutboundAvgInterarrivalJitter = "AverageFarEndInterarrivalJitter",
    X_000E50_CurrCallOutboundMaxInterarrivalJitter = "MaxFarEndInterarrivalJitter",
    X_000E50_CurrCallOutboundRTPPacketLoss = "FarEndPacketLost",
    X_000E50_CurrCallOutboundRTPPacketLossRate = "FarEndPacketLossRate",
    X_000E50_CurrCallOutboundSumFractionLoss= "OutboundSumFractionLoss",
    X_000E50_CurrCallOutboundSumInterarrivalJitter = "OutboundSumInterarrivalJitter",
    X_000E50_CurrCallOutboundSumSqrFractionLoss = "OutboundSumSqrFractionLoss",
    X_000E50_CurrCallOutboundSumSqrInterarrivalJitter = "OutboundSumSqrInterarrivalJitter",
    X_000E50_CurrCallOutboundTotalRTCPPackets = "OutboundTotalRTCPPackets",
    X_000E50_CurrCallOutboundTotalRTCPXrPackets = "OutboundTotalRTCPXrPackets",
    X_000E50_CurrCallSumRTCPOneWayDelay = "SumRTCPOneWayDelay",
    X_000E50_CurrCallSumRTCPRoundTripDelay = "SumRTCPRoundTripDelay",
    X_000E50_CurrCallSumSqrRTCPOneWayDelay = "SumSqrRTCPOneWayDelay",
    X_000E50_CurrCalllSumSqrRTCPRoundTripDelay = "SumSqrRTCPRoundTripDelay",
    X_000E50_CurrCallConnectTimeStamp = "SessionStartTime",
    X_000E50_CurrCallDuration = "SessionDuration",
    X_000E50_CurrCallCodecInUse = "codec",
    X_000E50_CurrCallRemoteIP = "FarEndIPAddress"
}

local currentOngoingCallMap = {
    X_000E50_CurrCallNumber = "party",
    X_000E50_CurrCallCID = "partyDisplayName",
}

local lastCallStatsMap = {
    X_000E50_LastCallAvgRTCPRoundTripDelay = "AverageRoundTripDelay",
    X_000E50_LastCallInboundAvgInterarrivalJitter = "AverageReceiveInterarrivalJitter",
    X_000E50_LastCallInboundMaxInterarrivalJitter = "ReceiveMaxInterarrivalJitter",
    X_000E50_LastCallInboundRTPPacketLoss = "PacketsLost",
    X_000E50_LastCallInboundRTPPacketLossRate = "ReceivePacketLossRate",
    X_000E50_LastCallInboundSumFractionLoss = "InboundSumFractionLoss",
    X_000E50_LastCallInboundSumInterarrivalJitter = "InboundSumInterarrivalJitter",
    X_000E50_LastCallInboundSumSqrFractionLoss = "InboundSumSqrFractionLoss",
    X_000E50_LastCallInboundSumSqrInterarrivalJitter = "InboundSumSqrInterarrivalJitter",
    X_000E50_LastCallInboundTotalRTCPPackets = "InboundTotalRTCPPackets",
    X_000E50_LastCallInboundTotalRTCPXrPackets = "InboundTotalRTCPXrPackets",
    X_000E50_LastCallMaxRTCPOneWayDelay = "MaxRTCPOneWayDelay",
    X_000E50_LastCallMaxRTCPRoundTripDelay = "WorstRoundTripDelay",
    X_000E50_LastCallOutboundAvgInterarrivalJitter = "AverageFarEndInterarrivalJitter",
    X_000E50_LastCallOutboundMaxInterarrivalJitter = "FarEndReceiveMaxInterarrivalJitter",
    X_000E50_LastCallOutboundRTPPacketLoss = "FarEndPacketsLost",
    X_000E50_LastCallOutboundRTPPacketLossRate = "FarEndPacketLossRate",
    X_000E50_LastCallOutboundSumFractionLoss= "OutboundSumFractionLoss",
    X_000E50_LastCallOutboundSumInterarrivalJitter = "OutboundSumInterarrivalJitter",
    X_000E50_LastCallOutboundSumSqrFractionLoss = "OutboundSumSqrFractionLoss",
    X_000E50_LastCallOutboundSumSqrInterarrivalJitter = "OutboundSumSqrInterarrivalJitter",
    X_000E50_LastCallOutboundTotalRTCPPackets = "OutboundTotalRTCPPackets",
    X_000E50_LastCallOutboundTotalRTCPXrPackets = "OutboundTotalRTCPXrPackets",
    X_000E50_LastCallSumRTCPOneWayDelay = "SumRTCPOneWayDelay",
    X_000E50_LastCallSumRTCPRoundTripDelay = "SumRTCPRoundTripDelay",
    X_000E50_LastCallSumSqrRTCPOneWayDelay = "SumSqrRTCPOneWayDelay",
    X_000E50_LastCalllSumSqrRTCPRoundTripDelay = "SumSqrRTCPRoundTripDelay",
    X_000E50_LastCallConnectTimeStamp = "connectedTime",
    X_000E50_LastCallDuration = "",
    X_000E50_LastCallRemoteIP = "FarEndIPAddress",
    X_000E50_LastCallNumber = "Remote",
    X_000E50_LastCallCID = "RemoteName",
    X_000E50_LastCallCodecInUse = "Codec",
}

function M.getParamLine(maps)
    return function(mapping, param, key, parentKey)
        local config, name, ltype = tr104Helper.getInfoFromKeyForLine(key, parentKey)
        local map = maps[ltype]
        if map.value[param] then
            if type(map.value[param]) == "function" then
                return map.value[param](config, name, key)
            else
                binding.config = config
                binding.sectionname = name
                binding.option = map.value[param]
                return getFromUci(binding)
            end
        else
            return map.default[param] or ""
        end
    end
end

function M.getParamStats(param, key, parentKey)
    local config, name = tr104Helper.getInfoFromKeyForLine(key, parentKey)
    binding.config = config
    binding.sectionname = name
    binding.option = param
    return getFromUci(binding)
end

function M.convert2Sec(value)
    local timeT = {}
    timeT.year, timeT.month, timeT.day, timeT.hour, timeT.min, timeT.sec = value:match("(%d+)-(%d+)-(%d+)%s+(%d+):(%d+):(%d+)")
    if timeT.year then
        return os.time(timeT)
    end
    return 0
end

local function getModifiedUri(uri)
    local delimiter1 = find(uri, ":")
    local delimiter2 = find(uri, "@")
    if delimiter1 and delimiter2 then
        return sub(uri, (delimiter1 + 1), (delimiter2 - 1))
    elseif delimiter2 then
        return sub(uri, 0, (delimiter2 - 1))
    else
        return uri
    end
end

function M.statsGet(mapping, param, key, parentKey, objectType)
    local uri = M.getParamStats("uri", key, parentKey)
    local modifiedUri = getModifiedUri(uri)
    local ubusName
    if modifiedUri == "" then
        return "0"
    end
    local value = "0"
    if param == "ResetStatistics" then
        return "0"
    end
    if param == "ServerDownTime" then
        local _, name = tr104Helper.getInfoFromKeyForLine(key, parentKey)
        local profiles = conn:call("mmpbx.profile", "get", {}) or {}
        return profiles[name] and profiles[name]["serverDownTime"] and tostring(profiles[name]["serverDownTime"]) or "0"
    end
    if callNumberStatisticMap[param] or incomingCallStatisticMap[param] or outgoingCallStatisticMap[param] then
        local callNumberStats = conn:call("mmdbd.callnumber.statistics", "get", {["profile"]=modifiedUri}) or {}
        if callNumberStats[1] then
	    if objectType == "IncomingCalls" then
                ubusName = incomingCallStatisticMap[param]
	    elseif objectType == "OutgoingCalls" then
                ubusName = outgoingCallStatisticMap[param]
	    else
                ubusName = callNumberStatisticMap[param]
	    end
            value = tostring(callNumberStats[1][ubusName] or "0")
        end
        return value
    end
    if currentOngoingStatsMap[param] then
        local rtpSession = conn:call("mmpbx.rtp.session", "list", {["rtcp"]="1", ["name"]=modifiedUri}) or {}
        if rtpSession[1] then
            if param ~= "X_000E50_CurrCallCodecInUse" then
                ubusName = currentOngoingStatsMap[param]
                value = tostring(rtpSession[1][ubusName] or "0")
            else
                for _, val in pairs(rtpSession[1]) do
                    if type(val) == "table" then
                        for _, val2 in pairs(val) do
                            if type(val2) == "table" then
                                if val2.codec and val2.codec ~= "telephone-event" then
                                    return val2.codec
                                end
                            end
                        end
                    end
                end
            end
        end
        return value
    end

    if currentOngoingCallMap[param] then
        local callInfo = conn:call("mmpbx.call", "get", {["profile"]=modifiedUri}) or {}
        ubusName = currentOngoingCallMap[param]
        for _, callInfoParam in pairs (callInfo) do
            value = tostring(callInfoParam[ubusName] or "0")
        end
        return value
    end
    if lastCallStatsMap[param] then
        local callStats = conn:call("mmdbd.call.statistics", "get", {["profile"]=modifiedUri}) or {}
        ubusName = lastCallStatsMap[param]
        for _, value in pairs(callStats) do
            for _, callStatsParam in pairs(value) do
                if callStatsParam["TxPackets"] ~= 0 then
                    if param == "X_000E50_LastCallDuration" then
                        local connectedTime = tostring(callStatsParam["connectedTime"] or "0")
                        local endTime = tostring(callStatsParam["endTime"] or "0")
                        if endTime ~= "0" then
                            return tostring(M.convert2Sec(endTime) - M.convert2Sec(connectedTime))
                        else
                            return tostring(os.time() - M.convert2Sec(connectedTime))
                        end
                    else
                        return tostring(callStatsParam[ubusName] or "0")
                    end
                end
            end
        end
        return value
    end
end

function M.statsGetAll(mapping, key, parentKey, objectType)
    local callStatisticMap, results = {}
    if objectType == "IncomingCalls" then
	results = {
            CallsReceived = "0",
            CallsConnected = "0",
            CallsFailed = "0",
            CallsDropped = "0",
            TotalCallTime = "0"
	}
	callStatisticMap = incomingCallStatisticMap
    elseif objectType == "OutgoingCalls" then
	results = {
            CallsAttempted = "0",
            CallsConnected = "0",
            CallsFailed = "0",
            CallsDropped = "0",
            TotalCallTime = "0"
	}
	callStatisticMap = outgoingCallStatisticMap
    else
        results = {
            IncomingCallsReceived = "0",
            IncomingCallsAnswered = "0",
            IncomingCallsConnected = "0",
            IncomingCallsFailed = "0",
            OutgoingCallsAttempted = "0",
            OutgoingCallsAnswered = "0",
            OutgoingCallsConnected = "0",
            OutgoingCallsFailed = "0",
            TotalCallTime = "0",
            CallsDropped = "0",
            PacketsSent  = "0",
            PacketsReceived  = "0",
            BytesSent  = "0",
            BytesReceived  = "0",
            PacketsLost  = "0",
            ReceivePacketLossRate  = "0",
            FarEndPacketLossRate  = "0",
            ReceiveInterarrivalJitter  = "0",
            FarEndInterarrivalJitter  = "0",
            RoundTripDelay  = "0",
            AverageReceiveInterarrivalJitter  = "0",
            AverageFarEndInterarrivalJitter  = "0",
            AverageRoundTripDelay  = "0",
            Overruns = "0",
            Underruns = "0",
            ResetStatistics = "0",
            ServerDownTime = "0",
            X_000E50_CurrCallAvgRTCPRoundTripDelay = "0",
            X_000E50_CurrCallInboundAvgInterarrivalJitter = "0",
            X_000E50_CurrCallInboundMaxInterarrivalJitter = "0",
            X_000E50_CurrCallInboundRTPPacketLoss = "0",
            X_000E50_CurrCallInboundRTPPacketLossRate = "0",
            X_000E50_CurrCallInboundSumFractionLoss = "0",
            X_000E50_CurrCallInboundSumInterarrivalJitter = "0",
            X_000E50_CurrCallInboundSumSqrFractionLoss = "0",
            X_000E50_CurrCallInboundSumSqrInterarrivalJitter = "0",
            X_000E50_CurrCallInboundTotalRTCPPackets = "0",
            X_000E50_CurrCallInboundTotalRTCPXrPackets = "0",
            X_000E50_CurrCallMaxRTCPOneWayDelay = "0",
            X_000E50_CurrCallMaxRTCPRoundTripDelay = "0",
            X_000E50_CurrCallOutboundAvgInterarrivalJitter = "0",
            X_000E50_CurrCallOutboundMaxInterarrivalJitter = "0",
            X_000E50_CurrCallOutboundRTPPacketLoss = "0",
            X_000E50_CurrCallOutboundRTPPacketLossRate = "0",
            X_000E50_CurrCallOutboundSumFractionLoss= "0",
            X_000E50_CurrCallOutboundSumInterarrivalJitter = "0",
            X_000E50_CurrCallOutboundSumSqrFractionLoss = "0",
            X_000E50_CurrCallOutboundSumSqrInterarrivalJitter = "0",
            X_000E50_CurrCallOutboundTotalRTCPPackets = "0",
            X_000E50_CurrCallOutboundTotalRTCPXrPackets = "0",
            X_000E50_CurrCallSumRTCPOneWayDelay = "0",
            X_000E50_CurrCallSumRTCPRoundTripDelay = "0",
            X_000E50_CurrCallSumSqrRTCPOneWayDelay = "0",
            X_000E50_CurrCalllSumSqrRTCPRoundTripDelay = "0",
            X_000E50_CurrCallConnectTimeStamp = "",
            X_000E50_CurrCallDuration = "0",
            X_000E50_CurrCallRemoteIP = "0",
            X_000E50_CurrCallCID = "",
            X_000E50_CurrCallNumber = "",
            X_000E50_CurrCallCodecInUse = "",
            X_000E50_LastCallAvgRTCPRoundTripDelay = "0",
            X_000E50_LastCallInboundAvgInterarrivalJitter = "0",
            X_000E50_LastCallInboundMaxInterarrivalJitter = "0",
            X_000E50_LastCallInboundRTPPacketLoss = "0",
            X_000E50_LastCallInboundRTPPacketLossRate = "0",
            X_000E50_LastCallInboundSumFractionLoss = "0",
            X_000E50_LastCallInboundSumInterarrivalJitter = "0",
            X_000E50_LastCallInboundSumSqrFractionLoss = "0",
            X_000E50_LastCallInboundSumSqrInterarrivalJitter = "0",
            X_000E50_LastCallInboundTotalRTCPPackets = "0",
            X_000E50_LastCallInboundTotalRTCPXrPackets = "0",
            X_000E50_LastCallMaxRTCPOneWayDelay = "0",
            X_000E50_LastCallMaxRTCPRoundTripDelay = "0",
            X_000E50_LastCallOutboundAvgInterarrivalJitter = "0",
            X_000E50_LastCallOutboundMaxInterarrivalJitter = "0",
            X_000E50_LastCallOutboundRTPPacketLoss = "0",
            X_000E50_LastCallOutboundRTPPacketLossRate = "0",
            X_000E50_LastCallOutboundSumFractionLoss= "0",
            X_000E50_LastCallOutboundSumInterarrivalJitter = "0",
            X_000E50_LastCallOutboundSumSqrFractionLoss = "0",
            X_000E50_LastCallOutboundSumSqrInterarrivalJitter = "0",
            X_000E50_LastCallOutboundTotalRTCPPackets = "0",
            X_000E50_LastCallOutboundTotalRTCPXrPackets = "0",
            X_000E50_LastCallSumRTCPOneWayDelay = "0",
            X_000E50_LastCallSumRTCPRoundTripDelay = "0",
            X_000E50_LastCallSumSqrRTCPOneWayDelay = "0",
            X_000E50_LastCalllSumSqrRTCPRoundTripDelay = "0",
            X_000E50_AccumAvgRTCPRoundTripDelay = "0",
            X_000E50_AccumInboundAvgInterarrivalJitter = "0",
            X_000E50_AccumInboundCallCount = "0",
            X_000E50_AccumInboundMaxInterarrivalJitter = "0",
            X_000E50_AccumInboundRTPPacketLoss = "0",
            X_000E50_AccumInboundRTPPacketLossRate = "0",
            X_000E50_AccumInboundSumFractionLoss = "0",
            X_000E50_AccumInboundSumInterarrivalJitter = "0",
            X_000E50_AccumInboundSumSqrFractionLoss = "0",
            X_000E50_AccumInboundSumSqrInterarrivalJitter = "0",
            X_000E50_AccumInboundTotalRTCPPackets = "0",
            X_000E50_AccumInboundTotalRTCPXrPackets = "0",
            X_000E50_AccumMaxRTCPOneWayDelay = "0",
            X_000E50_AccumMaxRTCPRoundTripDelay = "0",
            X_000E50_AccumOutboundAvgInterarrivalJitter = "0",
            X_000E50_AccumOutboundCallCount = "0",
            X_000E50_AccumOutboundMaxInterarrivalJitter = "0",
            X_000E50_AccumOutboundRTPPacketLoss = "0",
            X_000E50_AccumOutboundRTPPacketLossRate = "0",
            X_000E50_AccumOutboundSumFractionLoss= "0",
            X_000E50_AccumOutboundSumInterarrivalJitter = "0",
            X_000E50_AccumOutboundSumSqrFractionLoss = "0",
            X_000E50_AccumOutboundSumSqrInterarrivalJitter = "0",
            X_000E50_AccumOutboundTotalRTCPPackets = "0",
            X_000E50_AccumOutboundTotalRTCPXrPackets = "0",
            X_000E50_AccumSumRTCPOneWayDelay = "0",
            X_000E50_AccumSumRTCPRoundTripDelay = "0",
            X_000E50_AccumSumSqrRTCPOneWayDelay = "0",
            X_000E50_LastCallConnectTimeStamp = "",
            X_000E50_LastCallDuration = "0",
            X_000E50_LastCallRemoteIP = "",
            X_000E50_LastCallNumber = "",
            X_000E50_LastCallCID = "",
            X_000E50_LastCallCodecInUse = "",
        }
	callStatisticMap = callNumberStatisticMap
    end
    local uri = M.getParamStats("uri", key, parentKey)
    local modifiedUri = getModifiedUri(uri)
    if modifiedUri == "" then
        return results
    end

    local currentCodec = 0
    local rtpSession = conn:call("mmpbx.rtp.session", "list", {["rtcp"]="1", ["name"]=modifiedUri} ) or {}
    if rtpSession[1] then
        for index, val in pairs(currentOngoingStatsMap) do
            if index ~= "X_000E50_CurrCallCodecInUse" then
                results[index] = tostring(rtpSession[1][val] or "0")
            else
                for _, val1 in pairs(rtpSession[1]) do
                    if type(val1) == "table" then
                        for _, val2 in pairs(val1) do
                            if type(val2) == "table" then
                                if val2.codec and val2.codec ~= "telephone-event" then
                                    results[index] = val2.codec
                                    currentCodec = 1
                                    break
                                end
                            end
                        end
                    end
                    if currentCodec == 1 then
                        break
                    end
                end
            end
	end
    end

    local callInfo = conn:call("mmpbx.call", "get", {["profile"]=modifiedUri} ) or {}
    if callInfo[1] then
        for param, val in pairs(currentOngoingCallMap) do
            results[param] = tostring(callInfo[1][val] or "0")
        end
    end

    local callNumberStats = conn:call("mmdbd.callnumber.statistics", "get", {["profile"]=modifiedUri} ) or {}
    if callNumberStats[1] then
        for param, val in pairs(callStatisticMap) do
	    results[param] = tostring(callNumberStats[1][val] or "0")
	end
    end

    local callStats = conn:call("mmdbd.call.statistics", "get", {["profile"]=modifiedUri}) or {}
    for _, val in pairs(callStats) do
        for _, val2 in pairs(val) do
            if val2["TxPackets"] ~= 0 then
                for index, val3 in pairs(lastCallStatsMap) do
                    if index == "X_000E50_LastCallDuration" then
                        local connectedTime = tostring(val2["connectedTime"] or "0")
                        local endTime = tostring(val2["endTime"] or "0")
                        if endTime ~= "0" then
                            results[index] = tostring(M.convert2Sec(endTime) - M.convert2Sec(connectedTime))
                        else
                            results[index] = tostring(os.time() - M.convert2Sec(connectedTime))
                        end
                    else
                        results[index] = tostring(val2[val3] or "0")
                    end
                end
                break
            end
        end
    end

    local _, name = tr104Helper.getInfoFromKeyForLine(key, parentKey)
    local profiles = conn:call("mmpbx.profile", "get", {}) or {}
    if profiles[name] then
        results.ServerDownTime =  tostring(profiles[name]["serverDownTime"]) or "0"
    end
    return results
end

return M
