local M = {}
local uciHelper = require("transformer.mapper.ucihelper")
local conn = require("transformer.mapper.ubus").connect()
local binding = {}
local getFromUci = uciHelper.get_from_uci
local setOnUci = uciHelper.set_on_uci
local qosBinding = {config = "qos"}
local firewallBinding  = {config = "firewall", sectionname = "siploopback", option = "dest_port"}
local mmpbxrvsipnetBinding = { config = "mmpbxrvsipnet", sectionname = "sip_net"}
local subscribeBinding = { config = "mmpbxrvsipnet", sectionname = "subscription"}
local voiceHelper = require("transformer.shared.voice_helper")
local mt = { __index = function() return "" end }
local commonDefault = setmetatable({}, mt)
local preregdBinding = {config = "mmpbxpreregd", sectionname = "global", default = "0"}
local regExpire , regExpireTBefore
local type = type
local format = string.format

local algorithmMap = {
    ["fixed"] = "reg_back_off_timeout",
    ["exponential"] = "reg_back_off_timeout_min",
    ["random"] = "reg_back_off_timeout_min",
    [""] = "reg_back_off_timeout",
}

local enableStatusMap = {
    ['0'] = "Disabled",
    ['1'] = "Enabled",
    ['Enabled'] = "1",
    ['Disabled'] = "0",
}

local stateMapping = {
    ["Idle"] = "NOTSTARTED",
    ["Pre-registering"] = "NOTSTARTED",
    ["Completed"] = "COMPLETE",
    ["Retrying"] = "FAILED",
    ["Failed"] = "FAILED",
}

local modeMap = {
    ["1"] = "managed",
    ["0"] = "unmanaged"
}

local function getTimerH(object)
    local timer = ""
    local option = "timer_T1"
    if type(object) == "table" then
        if object[option] then
            timer = object[option]
        else
            object.option = option
            timer = getFromUci(object)
        end
    end
    if (timer ~= "") then
        return tostring(tonumber(timer) * 64)
    end
    return ""
end

local function getConferenceCallDomainURI(object)
    mmpbxrvsipnetBinding.option = "conference_factory_uri_user_part"
    local userPart, domainName
    userPart = getFromUci(mmpbxrvsipnetBinding)
    if userPart ~="" then
        if (userPart:match("@")) then
            return userPart
        else
            mmpbxrvsipnetBinding.option = "primary_proxy"
            domainName = getFromUci(mmpbxrvsipnetBinding)
            if domainName == "" then
                mmpbxrvsipnetBinding.option = "domain_name"
                domainName = getFromUci(mmpbxrvsipnetBinding)
            end
            return userPart .."@".. domainName
        end
    end
    return ""
end

local function getEthernetPriorityMark(object)
    local dscpMark = voiceHelper.getDscpMark(object, "control_qos_field", "control_qos_value")
    local pBit
    qosBinding.sectionname = "Voice_Sig"
    qosBinding.option = "dscp"
    local dscpValue = getFromUci(qosBinding)
    if dscpValue == "" then
        pBit = ""
    elseif (dscpValue[string.lower(dscpValue)] == dscpMark) then
        qosBinding.option = "pcp"
        pBit = getFromUci(qosBinding)
        if pBit == "" then
            pBit = "-1"
        end
    else
        pBit = "-1"
    end
    return pBit
end

local function setRegisterExpires(binding, value, transactions, commitApply)
    binding.option = "reg_expire"
    regExpire = getFromUci(binding)
    setOnUci(binding, value, commitApply)
    binding.option = "reg_expire_T_before"
    regExpireTBefore = getFromUci(binding)
    if regExpireTBefore ~= "" and regExpire ~= "" then
        regExpireTBefore = value - math.modf(value*(regExpire-regExpireTBefore)/regExpire)
        setOnUci(binding, regExpireTBefore, commitApply)
    end
end

local function setReRegisterTimer(binding, value, transactions, commitApply)
    local registerExpire, registerExpireBefore
    binding.option = "reg_expire"
    registerExpire = getFromUci(binding)
    if value <= registerExpire then
        registerExpireBefore = registerExpire - value
    else
        registerExpireBefore = "0"
        setOnUci(binding, value, commitApply)
    end
    binding.option = "reg_expire_T_before"
    setOnUci(binding, registerExpireBefore, commitApply)
end

local function updateVoipSignallingRule(sectionName, value ,transactions ,commitApply)
    qosBinding.sectionname = sectionName
    qosBinding.option = "dstports"
    setOnUci(qosBinding, value, commitApply)
    transactions[qosBinding.config] = true
end

local function updateFirewallHelper(value ,transactions ,commitApply)
    setOnUci(firewallBinding, value, commitApply)
    transactions[firewallBinding.config] = true
end

local function searchVoipSignallingRule(value)
    local sectionName
    qosBinding.sectionname = "rule"
    uciHelper.foreach_on_uci(qosBinding, function(s)
        if s.voip_signalling == "1" then
            sectionName = s[".name"]
            return false
        end
    end)
    return sectionName
end

local function updateVoipSignallingRuleIfPresent(value ,transactions ,commitApply)
    local sectionName = searchVoipSignallingRule(value)
    if sectionName then
        updateVoipSignallingRule(sectionName, value ,transactions ,commitApply)
        updateFirewallHelper(value ,transactions ,commitApply)
    end
end

local sipServerMap = {
    value = {
        RegistrarServer = "domain",
        RegistrarServerPort = "registrar_port",
    },
    default = commonDefault,
}

local sipNetMap = {
    value = {
        ProxyServer = "primary_proxy",
        ProxyServerPort = "primary_proxy_port",
        ProxyServerTransport = "transport_type",
        RegistrarServer = "primary_registrar",
        RegistrarServerPort = "primary_registrar_port",
        RegistrarServerTransport = "transport_type",
        Realm = "realm",
        AuthRealm = "realm",
        UserAgentDomain = "domain_name",
        UserAgentPort = "local_port",
        UserAgentTransport = "transport_type",
        OutboundProxy = "primary_proxy",
        OutboundProxyPort = "primary_proxy_port",
        RegistrationPeriod = "reg_expire",
        TimerT1 = "timer_T1",
        TimerT2 = "timer_T2",
        TimerT4 = "timer_T4",
        TimerA = "timer_T1",
        TimerB = "timer_B",
        TimerD = "timer_D",
        TimerE = "timer_T1",
        TimerF = "timer_F",
        TimerG = "timer_T1",
        --hard code T4, now only consider UDP type
        TimerI = "timer_T4",
        TimerJ = "timer_J",
        --hard code T4, now only consider UDP type
        TimerK = "timer_T4",
        RegisterExpires = "reg_expire",
        RegisterRetryInterval = "reg_back_off_timeout",
        InviteExpires = "invite_expire_timer",
        TimerH = function(object)
            return getTimerH(object)
        end,
        DSCPMark = function(object)
            return voiceHelper.getDscpMark(object, "control_qos_field", "control_qos_value")
        end,
        ConferenceCallDomainURI = function(object)
            return getConferenceCallDomainURI(object)
        end,
        EthernetPriorityMark = function(object)
            return getEthernetPriorityMark(object)
        end,
        VLANIDMark = function(object)
            return voiceHelper.getVlanIdMark(object)
        end,
        X_000E50_401407Waiting = "401_407_waiting_time",
        X_000E50_SecProxyServer = "secondary_proxy",
        X_000E50_SecProxyServerPort = "secondary_proxy_port",
        X_AltProxyServer = "secondary_proxy",
        X_AltProxyServerPort = "secondary_proxy_port",
        X_AltRegistrarServer = "secondary_registrar",
        X_AltRegistrarServerPort = "secondary_registrar_port",
        X_000E50_MaxRetransInvite = "max_retransmits_invite",
        X_000E50_MaxRetransNonInvite = "max_retransmits_non_invite",
        X_000E50_403Waiting = "403_waiting_time",
        X_000E50_400503Waiting = "400_503_waiting_time",
        X_000E50_Other4xx5xx6xxWaiting = "4xx_5xx_6xx_waiting_time",
        X_000E50_TimerFExpWaiting = "timer_F_expiry_waiting_time",
        X_000E50_StopRegisterOn403 = "stop_register_on_403",
        X_000E50_StopRegisterOnTimerF = "stop_register_on_TimerF",
        X_000E50_StopRegisterOn408 = "stop_register_on_408",
        X_000E50_RegisterBackOffTimerMax = "reg_back_off_timeout_max",
        X_000E50_CallWaitingRejectResponse = "call_waiting_reject_response",
        X_000E50_NoAnswerResponse = "no_answer_response",
        X_SessionExpires = "session_expires",
        X_000E50_IgnoreAssertedID = "ignore_asserted_id",
        X_FASTWEB_RegisterExpiresRefreshPercent = function(object)
            if type(object) == "table" then
                if object["reg_expire_T_before"] then
                    regExpireTBefore = object["reg_expire_T_before"]
                else
                    object.option = "reg_expire_T_before"
                    regExpireTBefore = getFromUci(object)
                end
                if object["reg_expire"] then
                    regExpire = object["reg_expire"]
                else
                    object.option = "reg_expire"
                    regExpire = getFromUci(object)
                end
                if regExpireTBefore ~= "" and regExpire ~= "" then
                    local registerExpiresRefreshPercent = math.modf((regExpire-regExpireTBefore)/regExpire * 100)
                    return tostring(registerExpiresRefreshPercent)
                end
            end
            return ""
        end,
        X_000E50_RegisterBackOffTimer = function(object)
            mmpbxrvsipnetBinding.option = "reg_back_off_timeout_algorithm"
            local algorithm = getFromUci(mmpbxrvsipnetBinding)
            mmpbxrvsipnetBinding.option = algorithmMap[algorithm]
            return getFromUci(mmpbxrvsipnetBinding)
        end,
        X_FASTWEB_RegisterSleepTimeMin = "reg_back_off_timeout_min";
        X_FASTWEB_RegisterSleepTimeMax = "reg_back_off_timeout_max";
        X_0876FF_PreRegisterEnable = function(object)
            preregdBinding.option = "enabled"
            local enableStatus = enableStatusMap[getFromUci(preregdBinding)]
            preregdBinding.option = "mode"
            local mode = getFromUci(preregdBinding)
            return enableStatus == "Enabled" and mode == "managed" and "Enabled" or "Disabled"
        end,
        X_0876FF_PreRegisterState = function(object)
            local preRegisterState = conn:call("mmpbxpreregd.state", "get", {}) or {}
            return preRegisterState.status and stateMapping[preRegisterState.status] or "Idle"
        end,
        X_DT_ReRegisterTimer = function(object)
            mmpbxrvsipnetBinding.option = "reg_expire"
            local registerExpire = getFromUci(mmpbxrvsipnetBinding)
            mmpbxrvsipnetBinding.option = "reg_expire_T_before"
            local registerExpireBefore = getFromUci(mmpbxrvsipnetBinding)
            if registerExpireBefore ~= "" and registerExpire ~= "" then
                return tostring(registerExpire - registerExpireBefore)
            end
            return ""
        end,
        X_DT_ProxySwitchWhenRetryAfterPresent = "geo_redundancy_proxy_switch_when_retry_after_present",
        X_DT_RetryAfterMinValue = "geo_redundancy_retry_after_time_min",
        X_DT_QuarantineTimer = "geo_redundancy_proxy_quarantine_timer",
    },
    default = setmetatable({
        ProxyServerTransport = "undefined",
        RegistrarServerTransport = "undefined",
        RegisterExpires = "1",
        TimerC = "180000",
        InviteExpires = "0",
        RegistersMinExpires = "1",
        ReInviteExpires = "1",
        UseCodecPriorityInSDPResponse = "1",
        ConferenceCallDomainURI = "",
        EthernetPriorityMark = "-1",
        VLANIDMark = "-1",
        SIPResponseMapNumberOfElements = "0",
        X_FASTWEB_RegisterExpiresRefreshPercent = "98",
        X_FASTWEB_RegisterSleepTimeMin = "600",
        X_FASTWEB_RegisterSleepTimeMax = "900",
        X_000E50_RegisterBackOffTimer = "32",
        X_000E50_MaxRetransInvite = "-1",
        X_000E50_MaxRetransNonInvite = "-1",
        X_000E50_CallWaitingRejectResponse = "486",
        X_000E50_NoAnswerResponse = "480",
        X_SessionExpires = "",
        X_DT_ProxySwitchWhenRetryAfterPresent = "0",
        X_DT_RetryAfterMinValue = "30",
        X_DT_QuarantineTimer = "900",
    }, mt),
}

local setSipNetMap = {
    ProxyServer = true,
    ProxyServerPort = true,
    ProxyServerTransport = true,
    RegistrarServer = true,
    RegistrarServerPort = true,
    RegistrarServerTransport = true,
    Realm = true,
    AuthRealm = true,
    UserAgentDomain = true,
    UserAgentPort = true,
    UserAgentTransport = true,
    OutboundProxy = true,
    OutboundProxyPort = true,
    RegistrationPeriod = true,
    TimerT1 = true,
    TimerT2 = true,
    TimerT4 = true,
    TimerB = true,
    TimerD = true,
    TimerF = true,
    TimerJ = true,
    RegisterExpires = function(binding, value, transactions, commitApply)
        return setRegisterExpires(binding, value, transactions, commitApply)
    end,
    RegisterRetryInterval = true,
    InviteExpires = true,
    DSCPMark = function(binding, value, transactions, commitApply)
        voiceHelper.setDscpMark(binding, value, "control_qos_field", "control_qos_value", transactions, commitApply)
    end,
    ConferenceCallDomainURI = function(binding, value, transactions, commitApply)
        binding.option = "conference_factory_uri_user_part"
        setOnUci(binding, value, commitApply)
    end,
    X_000E50_401407Waiting = true,
    X_AltRegistrarServer = true,
    X_AltRegistrarServerPort = true,
    X_AltProxyServer = true,
    X_AltProxyServerPort = true,
    X_000E50_SecProxyServer = true,
    X_000E50_SecProxyServerPort = true,
    X_000E50_MaxRetransInvite = true,
    X_000E50_MaxRetransNonInvite = true,
    X_000E50_403Waiting = true,
    X_000E50_400503Waiting = true,
    X_000E50_Other4xx5xx6xxWaiting = true,
    X_000E50_TimerFExpWaiting = true,
    X_000E50_StopRegisterOn403 = true,
    X_000E50_StopRegisterOnTimerF = true,
    X_000E50_StopRegisterOn408 = true,
    X_000E50_RegisterBackOffTimerMax = true,
    X_000E50_CallWaitingRejectResponse = true,
    X_000E50_NoAnswerResponse = true,
    X_000E50_IgnoreAssertedID = true,
    X_FASTWEB_RegisterExpiresRefreshPercent = function(binding, value, transactions, commitApply)
        binding.option = "reg_expire"
        regExpire = getFromUci(binding)
        local setRegExpireTBefore = regExpire - math.modf(regExpire*value / 100)
        binding.option = "reg_expire_T_before"
        setOnUci(binding, setRegExpireTBefore, commitApply)
    end,
    X_000E50_RegisterBackOffTimer = function(binding, value, transactions, commitApply)
        binding.option = "reg_back_off_timeout_algorithm"
        local algorithm = getFromUci(binding)
        binding.option = algorithmMap[algorithm]
        setOnUci(binding, value, commitApply)
    end,
    X_FASTWEB_RegisterSleepTimeMin = true,
    X_FASTWEB_RegisterSleepTimeMax = true,
    X_SessionExpires = function(binding, value, transactions, commitApply)
        binding.option = "min_session_expires"
        local min_session_expires = getFromUci(binding)
        if (tonumber(min_session_expires) > tonumber(value)) then
            setOnUci(binding, value, commitApply)
        end
        binding.option = "session_expires"
        setOnUci(binding, value, commitApply)
    end,
    X_0876FF_PreRegisterEnable = function(preregdBinding, value, transactions, commitApply)
        preregdBinding.sectionname = "global"
        preregdBinding.option = "enabled"
        setOnUci(preregdBinding, value, commitApply)
        preregdBinding.option = "mode"
        setOnUci(preregdBinding, modeMap[value], commitApply)
    end,
    X_DT_ReRegisterTimer =  function(binding, value, transactions, commitApply)
        return setReRegisterTimer(binding, value, transactions, commitApply)
    end,
    X_DT_ProxySwitchWhenRetryAfterPresent = true,
    X_DT_RetryAfterMinValue = true,
    X_DT_QuarantineTimer = true,
}

local mobileNetMap = {
    value = { },
    default = commonDefault,
}

local sipMaps = {
    mmpbxrvsipnet = sipNetMap,
    mmpbxrvsipdev = sipServerMap,
    mmpbxmobilenet = mobileNetMap,
}

local setSipServerMap = {
    RegistrarServer = true,
    RegistrarServerPort = true,
}

local setSipMaps = {
    mmpbxrvsipnet = setSipNetMap,
    mmpbxrvsipdev = setSipServerMap,
    mmpbxmobilenet = {},
}

function M.getInfoFromKey(key, parentKey)
    local config, val= key:match("^(.*)|(.*)$")
    local sectionName = tostring(val)
    return config, sectionName
end

function M.getAllSipnetParams(parameters)
    return function(mapping, key, parentKey)
        local config, sectionName = M.getInfoFromKey(key, parentKey)
        binding.config = config
        binding.sectionname = sectionName
        binding.option = nil
        local object = uciHelper.getall_from_uci(binding)
        local map = sipMaps[config]
        local data = {}
        for param,_ in pairs(parameters) do
            if map.value[param] then
                if type(map.value[param]) == 'function' then
                    data[param] = map.value[param](object)
                else
                    data[param] = object[map.value[param]]
                end
            end
            data[param] = data[param] or map.default[param]
        end
        return data
    end
end

function M.getSipnetParam()
    return function(mapping, param, key, parentKey)
        local config, sectionName = M.getInfoFromKey(key, parentKey)
        binding.config = config
        binding.sectionname = sectionName
        local map = sipMaps[config]
        if map.value[param] then
            if type(map.value[param]) == "function" then
                return map.value[param](binding)
            else
                binding.option = map.value[param]
                binding.default = map.default[param]
                return getFromUci(binding)
            end
        else
            return map.default[param]
        end
    end
end

function M.setSipnetParam(mapping, param, value, key, parentKey, transactions, commitApply)
    local config, sectionName = M.getInfoFromKey(key, parentKey)
    binding.config = config
    binding.sectionname = sectionName
    local map = sipMaps[config]
    local setMap = setSipMaps[config]
    local msg, err
    if setMap[param] then
        if type(setMap[param]) == "function" then
            msg, err = setMap[param](binding, value, transactions, commitApply)
            transactions[binding.config] = true
            if err then
                return msg, err
            end
            return true
        elseif type(map.value[param]) == "string" then
            binding.option = map.value[param]
            if getFromUci(binding) ~= value then
                setOnUci(binding, value, commitApply)
                transactions[binding.config] = true
                if param == "ProxyServerPort" or param == "OutboundProxyPort" then
                    updateVoipSignallingRuleIfPresent(value ,transactions ,commitApply)
                end
            end
            return true
        end
    end
    return nil, "Not supported currently"
end

local subscribeMap = {
    Event = "event",
    Notifier = "notifier",
    NotifierPort = "notifier_port",
    NotifierTransPort = "transport_type",
    ExpireTime = "expire_time",
    X_FASTWEB_SubscribeRefreshPercent = "expire_time_T_before",
    X_FASTWEB_SubscribeSleepTimeMin = "retry_time_min",
    X_FASTWEB_SubscribeSleepTimeMax = "retry_time_max",
}

function M.subscribeGet()
    return function(mapping, paramName, key)
        subscribeBinding.sectionname = key
        if paramName == "Enable" then
            return "1"
        elseif paramName == "NotifierTransPort" then
            mmpbxrvsipnetBinding.option = "transport_type"
            return getFromUci(mmpbxrvsipnetBinding)
        elseif paramName == "X_FASTWEB_SubscribeRefreshPercent" then
            local value = "0"
            subscribeBinding.option = subscribeMap[paramName]
            local expireBefore = tonumber(getFromUci(subscribeBinding))
            subscribeBinding.option = "expire_time"
            local expireTime = tonumber(getFromUci(subscribeBinding))
            if (expireTime ~= nil and  expireBefore ~= nil and expireTime ~= 0) then
                value = tostring(math.modf(expireTime - expireBefore) / expireTime * 100)
            end
            return value
        end
        subscribeBinding.option = subscribeMap[paramName]
        return getFromUci(subscribeBinding)
    end
end

function M.subscribeSet(paramName, paramValue, key,  transactions, commitApply)
    subscribeBinding.sectionname = key
    if paramName == "NotifierTransPort" then
        mmpbxrvsipnetBinding.option = subscribeMap[paramName]
        setOnUci(mmpbxrvsipnetBinding, paramValue, commitApply)
        transactions[mmpbxrvsipnetBinding.config] = true
        return true
    elseif paramName == "X_FASTWEB_SubscribeRefreshPercent" then
        local value = "0"
        subscribeBinding.option = "expire_time"
        expireTime = tonumber(getFromUci(subscribeBinding))
        if (expireTime ~= nil and expireTime ~= 0) then
            value = tostring(expireTime - math.modf(expireTime * paramValue / 100))
        end
        paramValue = value
    end
    subscribeBinding.option = subscribeMap[paramName]
    setOnUci(subscribeBinding, paramValue, commitApply)
    transactions[subscribeBinding.config] = true
    return true
end

local function getHighestSubscriptionId()
    local highestId = -1
    subscribeBinding.sectionname = "subscription"
    subscribeBinding.option = nil
    uciHelper.foreach_on_uci(subscribeBinding, function(s)
        local id = tonumber(s['.name']:match("(%d+)$"))
        if (highestId < id) then
            highestId = id
        end
    end)
    return highestId + 1
end

function M.subscribeAdd(key, transactions, commitApply)
     subscribeBinding.sectionname = format("subscribe_notifier_%s", getHighestSubscriptionId())
     setOnUci(subscribeBinding, "subscription", commitApply)
     local subscribeNetwork = key:match("^.*|(.*)$")
     subscribeBinding.option = "network"
     setOnUci(subscribeBinding, subscribeNetwork, commitApply)
     transactions[subscribeBinding.config] = true
     return subscribeBinding.sectionname
end

function M.subscribeDelete(key, transactions, commitApply)
    subscribeBinding.option = nil
    subscribeBinding.sectionname = key
    uciHelper.delete_on_uci(subscribeBinding, commitApply)
    transactions[subscribeBinding.config] = true
    return true
end

return M
