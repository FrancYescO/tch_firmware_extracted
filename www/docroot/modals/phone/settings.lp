--pretranslated: do not change this file
 -- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local ngx = ngx
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local string = string
local match, format, upper, istainted, find, pairs = string.match, string.format, string.upper, string.istainted, string.find, pairs
local tonumber, ipairs = tonumber, ipairs
local maxTelnoLength = 390
local maxStrLen = 64
local phoneSettingsData, phoneSettingsVal = {}, {}
local isError
local validateBoolean = post_helper.validateBoolean
local getValidateStringLengthInRange = post_helper.getValidateStringLengthInRange
local getValidateNumberInRange = post_helper.getValidateNumberInRange
local getValidateInEnumSelect = post_helper.getValidateInEnumSelect
local getOptionalValidation = post_helper.getOptionalValidation
local floor = math.floor
local vdf_helper = require("vodafone_helper")
local json = require("dkjson")
local validateURL = vdf_helper.validateURL
local digitTimeOut = ""
local numberInRange = getValidateNumberInRange(0,65535)
local untaint_mt = require("web.taint").untaint_mt
local setMetaTable = setmetatable

local vodafone = {
  variant = "uci.env.var.vodafone_variant",
}
content_helper.getExactContent(vodafone)

local function validateTelephoneNumber(value)
  if value and #value <= maxTelnoLength then
    local pattern = match(value , "[%a%d%+]*")
    if pattern == value then
      return true
    end
  end
end

local function validateVoicePort(value)
  value = tonumber(match(value, "^(%d+)"))
  if value then
    if (value >= 1024 or value == 0 )and value < 65536 then
      return true
    end
  end
end

local function validateUserNamePassword(value)
  if type(value) ~= "string" and not istainted(value) then
    return nil, T"Received a non string value."
  end
  if #value < 1 or #value > maxStrLen then
    return nil, format(T"String must be between %1$d and %2$d characters long.", 1, maxStrLen)
  end
  if find(format("%s", value), "%s") then
    return nil, T"Invalid value, space not allowed"
  end
  return true
end

local function validateRtpPort(value)
  value = tonumber(match(value, "^(%d+)"))
  if value then
    if value >= 1024 and value < 65536 then
      return true
    end
  end
end

local function getCodecIndex(audioCodecList, preferredCodec)
  local instanceNext1
  for _, codec in pairs(audioCodecList) do
    if (codec.name == preferredCodec and codec.media_filter == "media_filter_audio_generic" and codec.name ~= "telephone-event") then
      instanceNext1 = codec.paramindex
      if instanceNext1 then
        break
      end
    end
  end
  return instanceNext1
end

local function setCodecValues(instanceNext1, audioCodecList, preferredCodec, priority, packetization, state)
  local setParam = {}
  local codecPriority = proxy.get(format("uci.mmpbx.codec_filter.%s.priority",instanceNext1))
  codecPriority = codecPriority and codecPriority[1] and codecPriority[1].value or ""
  if(codecPriority) then
    for _, codec in pairs(audioCodecList) do
      if(codec.priority == priority and codec.media_filter == "media_filter_audio_generic" and codec.name ~= "telephone-event") then
        setParam[format("uci.mmpbx.codec_filter.%s.priority",codec.paramindex)] = codecPriority
        local codecAllow = proxy.get(format("uci.mmpbx.codec_filter.%s.allow",instanceNext1))
        codecAllow = codecAllow and codecAllow[1] and codecAllow[1].value or ""
        if(codecAllow) then
          setParam[format("uci.mmpbx.codec_filter.%s.allow",codec.paramindex)] = codecAllow
        end
        break
      end
    end
  end
  setParam[format("uci.mmpbx.codec_filter.%s.packetization_time", instanceNext1)] = packetization
  setParam[format("uci.mmpbx.codec_filter.%s.priority", instanceNext1)] = priority
  setParam[format("uci.mmpbx.codec_filter.%s.allow", instanceNext1)] = state
  proxy.set(setParam)
end

local function getImageCodecInstance()
  local getInstance
  local codecList = proxy.getPN("uci.mmpbx.codec_filter.", true)
  if codecList then
    for _, v in ipairs(codecList) do
      local values = proxy.get(v.path .. "media_filter")
      if values and values[1].value == "media_filter_image_generic" then
        getInstance = string.match(values[1].path, "uci.mmpbx.codec_filter.@(.+)%.")
        return getInstance
      end
    end
  end
  return ""
end

local function getdailPlanInstance()
  local voipTimeout = content_helper.convertResultToObject("uci.mmpbx.dial_plan.", proxy.get("uci.mmpbx.dial_plan."))
  for _, v in pairs(voipTimeout) do
    for key, dialentries in pairs(v) do
      if key:match("network.@%d+.value") and dialentries == "sip_net" then
        return v.paramindex
      end
    end
  end
end

local function getfirewallHelperInstance()
  local destPort = content_helper.convertResultToObject("uci.firewall.helper.", proxy.get("uci.firewall.helper."))
  if destPort then
    for _, v in pairs(destPort) do
      if v.intf == "loopback" then
        return v.paramindex
      end
    end
  end
end

local function getQosRuleInstance()
  local destPort = content_helper.convertResultToObject("uci.qos.rule.", proxy.get("uci.qos.rule."))
  if destPort then
    for _, v in pairs(destPort) do
      if v.voip_signaling == "1" then
        return v.paramindex
      end
    end
  end
end

local function getDspAndSlicGain(inputGain)
  local gain = tonumber(inputGain)
  local slicGain
  local dspGain
  if gain >= 0 then
    slicGain = 0
    dspGain = gain
    elseif gain >= -12 then
      slicGain = gain
      dspGain = 0
    else
      slicGain = -12
      dspGain = gain + 12
    end
    return tostring(slicGain), tostring(dspGain)
  end

local getInstance = getImageCodecInstance()
local packetizationTime = {
  {"10"},
  {"20"},
  {"30"},
}

local dtmfModeList = {
  { T"RFC2833"},
  { T"InBand"},
  { T"SIPInfo"},
}

local locationValues = {
  {"spain", T"ESP-SPAIN"},
}

local intfName = setMetaTable({
  {"Select an option", T"Select an option"},
  {"wan", "wan"},
  {"ull_voice", "ull_voice"},
  {"vdsl_ull_voice", "vdsl_ull_voice"},
  {"ull_data", "ull_data"},
  {"vdsl_ull_data_ipoe", "vdsl_ull_data_ipoe"},
  {"vdsl_ull_data_pppoe", "vdsl_ull_data_pppoe"}
}, untaint_mt)

local validIntfName = setMetaTable({
  ["Select an option"]    = true,
  ["wan"]                 = true,
  ["vdsl_ull_voice"]      = true,
  ["vdsl_ull_data_ipoe"]  = true,
  ["ull_voice"]           = true,
  ["ull_data"]            = true,
  ["vdsl_ull_data_pppoe"] = true
}, untaint_mt)

if vodafone.variant == "NZ" then
  locationValues[1] = {"nz", T"New Zealand"}
  intfName = setMetaTable({
    {"Select an option", T"Select an option"},
    {"wan", "WAN"},
   }, untaint_mt)
  validIntfName = setMetaTable({
    ["Select an option"]    = true,
    ["wan"]                 = true,
  }, untaint_mt)
end

local function valRegProxy(value, object, key)
  if post_helper.validateStringIsIP(value) then
    local isReservedIP, errmsg = post_helper.reservedIPValidation(value)
    local isQTN, errmsg = post_helper.validateQTN(value)
    if not isReservedIP or not isQTN then
      return nil, errmsg
    end
    return true
  end
  return validateURL(value)
end

local function validatePhoneSettingsDetails(postargs)
  local valid
  phoneSettingsData = {
    primRegistrar          =   postargs.primRegistrar,
    primRegistrarPort      =   postargs.primRegistrarPort,
    primProxyServer        =   postargs.primProxyServer,
    primProxyServerPort    =   postargs.primProxyServerPort,
    secRegistrar           =   postargs.secRegistrar,
    secRegistrarPort       =   postargs.secRegistrarPort,
    secProxyServer         =   postargs.secProxyServer,
    secProxyServerPort     =   postargs.secProxyServerPort,
    domainName             =   postargs.domainName,
    rtpMin                 =   postargs.rtpMin,
    rtpMax                 =   postargs.rtpMax,
    regExpTimeout          =   postargs.regExpTimeout,
    regRetryInterval       =   postargs.regRetryInterval,
    sessionTimerExp        =   postargs.sessionTimerExp,
    sessionTimerMin        =   postargs.sessionTimerMin,
    location               =   postargs.location,
    primProxyRetryIntr     =   postargs.primProxyRetryIntr,
    minHookFlash           =   postargs.minHookFlash,
    maxHookFlash           =   postargs.maxHookFlash,
    rtcpPacket             =   postargs.rtcpPacket,
  }
  phoneSettingsVal = {
    primRegistrar          =   getOptionalValidation(valRegProxy),
    primRegistrarPort      =   getOptionalValidation(validateVoicePort),
    primProxyServer        =   getOptionalValidation(valRegProxy),
    primProxyServerPort    =   getOptionalValidation(validateVoicePort),
    secRegistrar           =   getOptionalValidation(valRegProxy),
    secRegistrarPort       =   getOptionalValidation(validateVoicePort),
    secProxyServer         =   getOptionalValidation(valRegProxy),
    secProxyServerPort     =   getOptionalValidation(validateVoicePort),
    domainName             =   getOptionalValidation(validateURL),
    rtpMin                 =   validateRtpPort,
    rtpMax                 =   validateRtpPort,
    regExpTimeout          =   getValidateNumberInRange(60,86400),
    regRetryInterval       =   numberInRange,
    sessionTimerExp        =   getValidateNumberInRange(90,65535),
    sessionTimerMin        =   getValidateNumberInRange(90,65535),
    location               =   getValidateInEnumSelect(locationValues),
    primProxyRetryIntr     =   numberInRange,
    minHookFlash           =   numberInRange,
    maxHookFlash           =   numberInRange,
    rtcpPacket             =   numberInRange,
  }

  --Interface name is validated when "Select an option" is not the item selected in the list of interface names.
  if postargs.intfName ~= "Select an option" then
    phoneSettingsData["intfName"] =   postargs.intfName
    phoneSettingsVal["intfName"]  =   getValidateInEnumSelect(intfName)
  end
  valid = content_helper.validateObject(phoneSettingsData, phoneSettingsVal)
  if valid then
    return true
  end
end

local faxTransportGet = proxy.get("uci.mmpbxbrcmfxsdev.global.fax_transport")
faxTransportGet = faxTransportGet and faxTransportGet[1] and faxTransportGet[1].value or ""
local maxsession = proxy.get("rpc.voiceprofile.1.MaxSessions")
maxsession = maxsession and maxsession[1] and maxsession[1].value or ""
local IMSServContent = {
  primRegistrar         =    "uci.mmpbxrvsipnet.network.@sip_net.primary_registrar",
  primRegistrarPort     =    "uci.mmpbxrvsipnet.network.@sip_net.primary_registrar_port",
  primProxyServer       =    "uci.mmpbxrvsipnet.network.@sip_net.primary_proxy",
  primProxyServerPort   =    "uci.mmpbxrvsipnet.network.@sip_net.primary_proxy_port",
  secRegistrar          =    "uci.mmpbxrvsipnet.network.@sip_net.secondary_registrar",
  secRegistrarPort      =    "uci.mmpbxrvsipnet.network.@sip_net.secondary_registrar_port",
  secProxyServer        =    "uci.mmpbxrvsipnet.network.@sip_net.secondary_proxy",
  secProxyServerPort    =    "uci.mmpbxrvsipnet.network.@sip_net.secondary_proxy_port",
  domainName            =    "uci.mmpbxrvsipnet.network.@sip_net.domain_name",
  minHookFlash          =    "uci.mmpbxbrcmcountry.global_provision.min_hookflash_time",
  maxHookFlash          =    "uci.mmpbxbrcmcountry.global_provision.max_hookflash_time",
  location              =    "uci.mmpbx.mmpbx.@global.country",
  echoCancellation      =    "uci.mmpbxbrcmfxsdev.device.@fxs_dev_0.echo_cancellation",
  rtcpPacket            =    "uci.mmpbxbrcmfxsdev.device.@fxs_dev_0.rtcp_interval",
  dspRxGain             =    "uci.mmpbxbrcmcountry.global_provision.rx_gain_fxs",
  dspTxGain             =    "uci.mmpbxbrcmcountry.global_provision.tx_gain_fxs",
  slicTxGain            =    "uci.mmpbxbrcmsi3226x.xdrv_slic_gains.fxs_profile_tx_gain",
  slicRxGain            =    "uci.mmpbxbrcmsi3226x.xdrv_slic_gains.fxs_profile_dlp",
  dscpRtp               =    "uci.mmpbxrvsipnet.network.@sip_net.realtime_qos_value",
  signalDscp            =    "uci.mmpbxrvsipnet.network.@sip_net.control_qos_value",
  rtpMin                =    "uci.mmpbxrvsipnet.network.@sip_net.rtp_local_port_min",
  rtpMax                =    "uci.mmpbxrvsipnet.network.@sip_net.rtp_local_port_max",
  dtmfMode              =    "rpc.voiceprofile.1.DTMFMethod",
  regExpTimeout         =    "uci.mmpbxrvsipnet.network.@sip_net.reg_expire",
  regRetryInterval      =    "uci.mmpbxrvsipnet.network.@sip_net.reg_back_off_timeout",
  sessionTimerExp       =    "uci.mmpbxrvsipnet.network.@sip_net.session_expires",
  sessionTimerMin       =    "uci.mmpbxrvsipnet.network.@sip_net.min_session_expires",
  faxTransport          =    "uci.mmpbxbrcmfxsdev.global.fax_transport",
  prack                 =    "uci.mmpbxrvsipnet.network.@sip_net.reliable_provisional_response",
  primProxyRetryIntr    =     "uci.mmpbxrvsipnet.network.@sip_net.switch_back_to_primary_proxy_timer",
}

--Interface name is set when "Select an option" is not the item selected in the list of interface names.
if phoneSettingsData["intfName"] ~= "Select an option" then
  IMSServContent["intfName"] = "uci.mmpbxrvsipnet.network.@sip_net.interface"
end

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SAVE" then
  local profileData, profileValidation = {}, {}
  local validPhoneSettingInfo, getIndex1, getIndex2
  local prackList
  local timeOut
  local postargs = ngx.req.get_post_args()
  proxy.set({[format("uci.qos.label.@Voice_Data.dscp")] = postargs.dscpRtp})
  proxy.set({[format("uci.qos.label.@Voice_Sig.dscp")] = postargs.signalDscp})
  if(faxTransportGet ~= "disabled") and (postargs["faxTransport"] == "0") and (postargs["imgCodec"] == "1") then
    postargs["imgCodec"] = "0"
  end
  local dialTimeOutinSec  =  floor(tonumber(postargs.dialTimeout)/1000)
  if (dialTimeOutinSec < 1 or dialTimeOutinSec > 60) then
    isError = true
  end
  dialTimeOutinSec = tostring(dialTimeOutinSec)
  if(tonumber(postargs.rtpMin) >= tonumber(postargs.rtpMax)) then
    isError = true
  end
  if((postargs.rtpMax - postargs.rtpMin) < (maxsession*2)) then
     isError = true
  end
  if (postargs.preferredCodec1 == postargs.preferredCodec2)  or tonumber(postargs.sessionTimerMin) > tonumber(postargs.sessionTimerExp) then
    isError = true
  end
  local rowLength = tonumber(postargs["rows"])
  for i=1,rowLength do
    profileData["uname" ..i] = postargs["uname" ..i]
    profileValidation["uname" ..i] = validateUserNamePassword
    if (postargs["pwd" .. i] ) then
      profileData["pwd" ..i] = postargs["pwd" ..i]
      profileValidation["pwd" ..i] = validateUserNamePassword
    end
    profileData["idName" .. i] = postargs["idName" .. i]
    profileValidation["idName" ..i] = getValidateStringLengthInRange(0,63)
    local validProfile = content_helper.validateObject(profileData, profileValidation)
    if not validProfile or not validateTelephoneNumber(postargs["phnNo" .. i]) or not validateBoolean(postargs["profileState" .. i]) then
      isError = true
      break
    end
  end
  local validPortMap = validatePhoneSettingsDetails(postargs)
  if not validPortMap then
    isError = true
  end

  if not validateBoolean(postargs["state1"]) or not validateBoolean(postargs["state2"]) or not validateBoolean(postargs["echoCancellation"]) or not validateBoolean(postargs["faxTransport"]) or not validateBoolean(postargs["imgCodec"]) then
    isError = true
  end

  local imgCodecSet = {[format("uci.mmpbx.codec_filter.@%s.allow",getInstance)]=postargs["imgCodec"]}
  if not isError then
    timeOut = {["uci.mmpbx.mmpbx.@global.dial_timeout"] = dialTimeOutinSec}
    if(postargs["prack"] =="1") then
      prackList = {["uci.mmpbxrvsipnet.network.@sip_net.reliable_provisional_response"] = "supported"}
    else
      prackList = {["uci.mmpbxrvsipnet.network.@sip_net.reliable_provisional_response"] = "unsupported"}
    end
    proxy.set(prackList)
    proxy.set(timeOut)
    if (postargs["imgCodec"] =="1") then
      if (postargs["faxTransport"] == "1") then
        proxy.set(imgCodecSet)
        proxy.set({["uci.mmpbxbrcmfxsdev.global.fax_transport"] = "t38"})
      else
        isError = true
      end
    else
      proxy.set(imgCodecSet)
    end

    local faxTransportSet, echoCancellationSet
    local imageCodecGet = proxy.get(format("uci.mmpbx.codec_filter.@%s.allow",getInstance))
    if imageCodecGet then
      imageCodecGet = imageCodecGet[1].value
    end
    if ( postargs["faxTransport"] == "1") then
      if (imageCodecGet == "1") then
        faxTransportSet = {["uci.mmpbxbrcmfxsdev.global.fax_transport"] = "t38"}
      else
        faxTransportSet = {["uci.mmpbxbrcmfxsdev.global.fax_transport"] = "inband_renegotiation"}
      end
    else
      faxTransportSet = {["uci.mmpbxbrcmfxsdev.global.fax_transport"] = "disabled"}
      proxy.set({[format("uci.mmpbx.codec_filter.@%s.allow",getInstance)]= "0"})
    end
    proxy.set(faxTransportSet)
    if postargs["echoCancellation"] == "1" then
      echoCancellationSet = {["uci.mmpbxbrcmfxsdev.device.@fxs_dev_1.echo_cancellation"] = "1"}
    elseif postargs["echoCancellation"] == "0" then
      echoCancellationSet = {["uci.mmpbxbrcmfxsdev.device.@fxs_dev_1.echo_cancellation"] = "0"}
    end
    proxy.set(echoCancellationSet)
  end
  if not isError then
    local dialPlansetInst = getdailPlanInstance()
    proxy.set({[format("uci.mmpbx.dial_plan.%s.open_inter_digit_timer", dialPlansetInst)] = postargs.digitTimeOut})
    proxy.set({[format("uci.mmpbx.dial_plan.%s.closed_inter_digit_timer", dialPlansetInst)] = postargs.digitTimeOut})
    local qosRuleInstance = getQosRuleInstance()
    if qosRuleInstance then
      proxy.set({[format("uci.qos.rule.%s.dstports", qosRuleInstance)] = postargs.primProxyServerPort})
    end
    local firewallHelperInst = getfirewallHelperInstance()
    if firewallHelperInst then
      proxy.set({[format("uci.firewall.helper.%s.dest_port", firewallHelperInst)] = postargs.primProxyServerPort})
    end
    local audioCodecList = content_helper.convertResultToObject("uci.mmpbx.codec_filter.",proxy.get("uci.mmpbx.codec_filter."))
    getIndex1 =  getCodecIndex(audioCodecList, postargs.preferredCodec1)
    setCodecValues(getIndex1, audioCodecList, postargs.preferredCodec1, "1", postargs.packetization1, postargs.state1)
    local audioCodecList2 = content_helper.convertResultToObject("uci.mmpbx.codec_filter.",proxy.get("uci.mmpbx.codec_filter."))
    getIndex2 = getCodecIndex(audioCodecList2, postargs.preferredCodec2)
    setCodecValues(getIndex2, audioCodecList2, postargs.preferredCodec2, "2", postargs.packetization2, postargs.state2)
    local codecList = content_helper.convertResultToObject("uci.mmpbx.codec_filter.", proxy.get("uci.mmpbx.codec_filter."))
    local setVADValues = {}
    setVADValues["uci.mmpbxbrcmfxsdev.device.@fxs_dev_1.rtcp_interval"] = postargs.rtcpPacket
    for k, v in pairs(codecList) do
      if v.media_filter ~= "media_filter_image_generic" then
        if postargs.vad == "1" then
          setVADValues[format("uci.mmpbx.codec_filter.%s.remove_silence_suppression", v.paramindex)] = "0"
        else
          setVADValues[format("uci.mmpbx.codec_filter.%s.remove_silence_suppression",v.paramindex)] = "1"
        end
      end
    end
    proxy.set(setVADValues)
    phoneSettingsData["minHookFlash"]     =  postargs.minHookFlash
    phoneSettingsData["maxHookFlash"]     =  postargs.maxHookFlash
    phoneSettingsData["slicRxGain"], phoneSettingsData["dspRxGain"] = getDspAndSlicGain(postargs.ingressGain)
    phoneSettingsData["slicTxGain"], phoneSettingsData["dspTxGain"] = getDspAndSlicGain(postargs.egressGain)
    phoneSettingsData["dscpRtp"]          =  postargs.dscpRtp
    phoneSettingsData["signalDscp"]       =  postargs.signalDscp
    phoneSettingsData["dtmfMode"]         =  postargs.dtmfMode
    phoneSettingsData["echoCancellation"] =  postargs.echoCancellation
    phoneSettingsData["rtcpPacket"]       =  postargs.rtcpPacket
    for i=1,rowLength do
      local index = postargs["index" .. i]
      phoneSettingsData["uname" ..i]        =  postargs["uname" ..i]
      if (postargs["pwd" ..i]) then
       phoneSettingsData["pwd" ..i]        =  postargs["pwd" ..i]
      end
      phoneSettingsData["phnNo" ..i]        =  postargs["phnNo" ..i]
      phoneSettingsData["idName" ..i]       =  postargs["idName" ..i]
      phoneSettingsData["profileState" ..i] =  postargs["profileState" ..i]
      IMSServContent["uname" ..i]           =  format("uci.mmpbxrvsipnet.profile.%s.user_name", index)
      IMSServContent["pwd" ..i]             =  format("uci.mmpbxrvsipnet.profile.%s.password", index)
      IMSServContent["phnNo" ..i]           =  format("uci.mmpbxrvsipnet.profile.%s.uri", index)
      IMSServContent["idName" ..i]          =  format("uci.mmpbxrvsipnet.profile.%s.display_name", index)
      IMSServContent["profileState" ..i]    =  format("uci.mmpbxrvsipnet.profile.%s.enabled", index)
    end
    validPhoneSettingInfo = content_helper.setObject(phoneSettingsData,IMSServContent)
    proxy.apply()
  end
  if not isError and validPhoneSettingInfo then
    ngx.print('<input type="hidden" id="post_status" value="success">')
  else
    ngx.print('<input type="hidden" id="post_status" value="error">')
  end
end
content_helper.getExactContent(IMSServContent)
local selectionPolicy = proxy.get("uci.mmpbxrvsipnet.network.@sip_net.proxy_selection_policy")
selectionPolicy = selectionPolicy and selectionPolicy[1] and selectionPolicy[1].value or ""
if selectionPolicy ~= "vodafone" then
  IMSServContent["primProxyRetryIntr"] = "0"
end
local qosField = proxy.get("uci.mmpbxrvsipnet.network.@sip_net.realtime_qos_field")
qosField = qosField and qosField[1] and qosField[1].value or ""
if qosField ~= "dscp" then
  IMSServContent["dscpRtp"] = ""
  IMSServContent["signalDscp"] = ""
end
local IMSServerInfo = {
  {T"SIP Primary Registrar Address", "phnset_txt_preg", IMSServContent["primRegistrar"], T"Port:", "phnset_txt_pregport", IMSServContent["primRegistrarPort"], "primRegistrar", "primRegistrarPort"},
  {T"SIP Primary Proxy Server Address", "phnset_txt_pproxy", IMSServContent["primProxyServer"], T"Port:", "phnset_txt_pproxyport", IMSServContent["primProxyServerPort"], "primProxyServer", "primProxyServerPort"},
  {T"SIP Secondary Registrar Address", "phnset_txt_sreg", IMSServContent["secRegistrar"], T"Port:", "phnset_txt_sregport", IMSServContent["secRegistrarPort"], "secRegistrar", "secRegistrarPort"},
  {T"SIP Secondary Proxy Server Address", "phnset_txt_sproxy", IMSServContent["secProxyServer"], T"Port:", "phnset_txt_sproxyport", IMSServContent["secProxyServerPort"], "secProxyServer", "secProxyServerPort"},

}
local mapGainTable = {
  {T"Ingress gain (dB)", "ingressGain", (IMSServContent["dspRxGain"] and tonumber(IMSServContent["dspRxGain"]) or 0) + (IMSServContent["slicRxGain"] and tonumber(IMSServContent["slicRxGain"]) or 0), "phnset_txt_igain"},
  {T"Egress gain (dB)", "egressGain", (IMSServContent["dspTxGain"] and tonumber(IMSServContent["dspTxGain"]) or 0) + (IMSServContent["slicTxGain"] and tonumber(IMSServContent["slicTxGain"]) or 0), "phnset_txt_egain"},
}
local mapDSCPTable = {
  {T"Local Rtp Max port", "rtpMax", "phnset_btn_rtpmax", IMSServContent["rtpMax"]},
  {T"Local Rtp Min port", "rtpMin", "phnset_btn_rtpmin", IMSServContent["rtpMin"]},
}
local mapDSCPTable1 = {
  {T"DSCP for RTP", "dscpRtp", "phnset_btn_dscprtp", IMSServContent["dscpRtp"]},
  {T"Signalling DSCP", "signalDscp", "phnset_btn_sigdscp", IMSServContent["signalDscp"]},
}
local timerTable = {
  {T"Registration Expire Timeout (s)", "regExpTimeout", "phnset_btn_regexptimeout", IMSServContent["regExpTimeout"]},
  {T"Registration Retry Interval (s)", "regRetryInterval", "phnset_btn_regretryintrevel", IMSServContent["regRetryInterval"]},
  {T"Primary Proxy Retry Interval (s)", "primProxyRetryIntr", "phnset_btn_primProxyRetryIntr", IMSServContent["primProxyRetryIntr"]},
  {T"Session Timer Expires (s)", "sessionTimerExp", "phnset_btn_sessiontimerexp", IMSServContent["sessionTimerExp"]},
  {T"Session Timer Min-SE (s)", "sessionTimerMin", "phnset_btn_sessiontimermin", IMSServContent["sessionTimerMin"]},
}
local profileInfo = content_helper.convertResultToObject("uci.mmpbxrvsipnet.profile.", proxy.get("uci.mmpbxrvsipnet.profile."))

local dialPlanInst = getdailPlanInstance()
if dialPlanInst then
  digitTimeOut = proxy.get(string.format("uci.mmpbx.dial_plan.%s.open_inter_digit_timer", dialPlanInst))
  digitTimeOut = digitTimeOut and digitTimeOut[1] and digitTimeOut[1].value or ""
end

local dialTimeoutinms = proxy.get("uci.mmpbx.mmpbx.@global.dial_timeout")
dialTimeoutinms = dialTimeoutinms and dialTimeoutinms[1] and dialTimeoutinms[1].value or ""
dialTimeoutinms = (dialTimeoutinms and tonumber(dialTimeoutinms) or 0) * 1000
local imageCodec = proxy.get(format("uci.mmpbx.codec_filter.@%s.allow", getInstance))
if imageCodec then
  imageCodec = imageCodec[1].value
end

local audiCodec = content_helper.convertResultToObject("uci.mmpbx.codec_filter.", proxy.get("uci.mmpbx.codec_filter."))
local resetphonesettings = {
  reset_primary_reg_address = "uci.uci-defaults.phonesettings.primary_reg_address",
  reset_primary_reg_address_port = "uci.uci-defaults.phonesettings.primary_reg_address_port",
  reset_primary_proxy_server_address = "uci.uci-defaults.phonesettings.primary_proxy_server_address",
  reset_primary_proxy_server_address_port = "uci.uci-defaults.phonesettings.primary_proxy_server_address_port",
  reset_secondary_reg_address = "uci.uci-defaults.phonesettings.secondary_reg_address",
  reset_secondary_reg_address_port = "uci.uci-defaults.phonesettings.secondary_reg_address_port",
  reset_secondary_proxy_server_address = "uci.uci-defaults.phonesettings.secondary_proxy_server_address",
  reset_secondary_proxy_server_address_port = "uci.uci-defaults.phonesettings.secondary_proxy_server_address_port",
  reset_user_agent_domain = "uci.uci-defaults.phonesettings.user_agent_domain",
  reset_line1 = "uci.uci-defaults.phonesettings.line1",
  reset_caller_id_name_1 = "uci.uci-defaults.phonesettings.caller_id_name_1",
  reset_phone_no_1 = "uci.uci-defaults.phonesettings.phone_no_1",
  reset_username1 = "uci.uci-defaults.phonesettings.username1",
  reset_password1 = "uci.uci-defaults.phonesettings.password1",
  reset_line2 = "uci.uci-defaults.phonesettings.line2",
  reset_caller_id_name_2 = "uci.uci-defaults.phonesettings.caller_id_name_2",
  reset_phone_no_2 = "uci.uci-defaults.phonesettings.phone_no_2",
  reset_username2 = "uci.uci-defaults.phonesettings.username2",
  reset_password2 = "uci.uci-defaults.phonesettings.password2",
  reset_voip_dial_timeout = "uci.uci-defaults.phonesettings.voip_dial_timeout",
  reset_preferred_codec_1 = "uci.uci-defaults.phonesettings.preferred_codec_1",
  reset_preferred_codec_2 = "uci.uci-defaults.phonesettings.preferred_codec_2",
  reset_state_1 = "uci.uci-defaults.phonesettings.state_1",
  reset_state_2 = "uci.uci-defaults.phonesettings.state_2",
  reset_packetization_1 = "uci.uci-defaults.phonesettings.packetization_1",
  reset_packetization_2 = "uci.uci-defaults.phonesettings.packetization_2",
  reset_t38 = "uci.uci-defaults.phonesettings.t38",
  reset_location = "uci.uci-defaults.phonesettings.location",
  reset_echo_cancellation = "uci.uci-defaults.phonesettings.echo_cancellation",
  reset_VAD_support = "uci.uci-defaults.phonesettings.VAD_support",
  reset_fax_detection = "uci.uci-defaults.phonesettings.fax_detection",
  reset_local_rtp_max_port = "uci.uci-defaults.phonesettings.local_rtp_max_port",
  reset_local_rtp_min_port = "uci.uci-defaults.phonesettings.local_rtp_min_port",
  reset_dtmf_mode = "uci.uci-defaults.phonesettings.dtmf_mode",
  reset_reg_exp_timeout = "uci.uci-defaults.phonesettings.reg_exp_timeout",
  reset_reg_retry_interval = "uci.uci-defaults.phonesettings.reg_retry_interval",
  reset_session_timer_exp = "uci.uci-defaults.phonesettings.session_timer_exp",
  reset_session_timer_minse = "uci.uci-defaults.phonesettings.session_timer_minse",
  reset_prack = "uci.uci-defaults.phonesettings.prack",
  reset_interface_name = "uci.uci-defaults.phonesettings.interface_name",
  reset_rtcpPacket = "uci.uci-defaults.phonesettings.rtcpPacket",
  reset_minHookFlash = "uci.uci-defaults.phonesettings.minHookFlash",
  reset_maxHookFlash = "uci.uci-defaults.phonesettings.maxHookFlash",
  reset_dscpRtp = "uci.uci-defaults.phonesettings.dscpRtp",
  reset_signalDscp = "uci.uci-defaults.phonesettings.signalDscp",
  reset_ingressGain = "uci.uci-defaults.phonesettings.ingressGain",
  reset_egressGain = "uci.uci-defaults.phonesettings.egressGain",
  reset_primProxyRetryIntr = "uci.uci-defaults.phonesettings.primProxyRetryIntr",
  reset_digitTimeOut = "uci.uci-defaults.phonesettings.digitTimeOut",
}
content_helper.getExactContent(resetphonesettings)
local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")
  ngx.print('\
\
<div class="row no-margin-right">\
  <div class="col-md-8 col-sm-8">\
    <h1><span>');  ngx.print(T"Phone Settings"); ngx.print('</span></h1>\
  </div>\
</div>\
<form id="phoneSettings-form" class="form-horizontal" method="post" action="/modals/phone/settings.lp">\
  <input type="hidden" name= "CSRFtoken" id= "CSRFtoken" value = "');  ngx.print(CSRFtoken); ngx.print('"></input>\
  <input type="hidden" name= "action" id= "action" value = "SAVE"></input>\
  <h2><span>');  ngx.print(T"Warning: the voice services are usable only with data connection up and running. If the service activation request is ongoing, the services will be available within 48hrs starting from the line activation."); ngx.print('</span></h2>\
  <h3><span>');  ngx.print(T"IMS Server Settings"); ngx.print('</span></h3>\
  <div class="h3-content phone-settings">\
    ');  for i = 1, #IMSServerInfo do   ngx.print('\
    <div class="vdf-row">\
      <div class="left">\
        <span>');  ngx.print(IMSServerInfo[i][1]); ngx.print('</span>\
      </div>\
      <div class="right">\
       <input name="');  ngx.print(IMSServerInfo[i][7]); ngx.print('" id = "');  ngx.print(IMSServerInfo[i][2]); ngx.print('" value="');  ngx.print(IMSServerInfo[i][3]); ngx.print('" type="text">\
     </div>\
     <div class="right">\
      <span>');  ngx.print(IMSServerInfo[i][4]); ngx.print('</span>\
    </div>\
    <div class="right">\
      <input class="max5" id = "');  ngx.print(IMSServerInfo[i][5]); ngx.print('" name="');  ngx.print(IMSServerInfo[i][8]); ngx.print('" value="');  ngx.print(IMSServerInfo[i][6]); ngx.print('" type="text" maxlength = "5">\
    </div>\
  </div>\
  ');  end  ngx.print('\
  <div class="vdf-row">\
    <div class="left">\
      <span>');  ngx.print(T"User Agent Domain"); ngx.print('</span>\
    </div>\
    <div class="right hidden-xs">&nbsp;</div>\
    <div class="right hidden-xs">&nbsp;</div>\
    <div class="right">\
      <input name="domainName" id = "phnset_domain_txt" value="');  ngx.print(IMSServContent["domainName"]); ngx.print('" type="text">\
    </div>\
  </div>\
</div>\
<h3><span>');  ngx.print(T"User Account Settings"); ngx.print('</span></h3>\
<div class="h3-content phonesettings">\
  ');  local index   ngx.print('\
  ');  for k,v in ipairs(profileInfo) do   ngx.print('\
  <div class = "phone-settings-profile">\
    ');  index = k-1   ngx.print('\
    <input type="hidden" value="');  ngx.print(v["paramindex"]); ngx.print('">\
    <div class="row padding-top-bottom-20">\
      <div class="col-xs-6 col-md-6 col-sm-6">\
        <span class = "line-height-32">');  ngx.print(T"Line"); ngx.print('</span>\
      </div>\
      <div class="col-xs-6 col-md-6 col-sm-6 text-right">\
        <div class="button profile-enabled');  ngx.print(index); ngx.print(' toggle-content-button ');  if(v["enabled"] == "1") then  ngx.print(' button-on ');  else  ngx.print(' button-off ');  end  ngx.print('" id ="phnset_line_txt');  ngx.print(index); ngx.print('" data-row="');  ngx.print(v["paramindex"]); ngx.print('"></div>\
      </div>\
    </div>\
    <div class="row">\
      <div class="col-md-12">\
        <hr/>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20">\
      <div class="col-xs-12 col-md-6 col-sm-6">\
        <span>');  ngx.print(T"Caller ID Name"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-6 col-sm-6 text-right">\
        <input  value="');  ngx.print(v["display_name"]); ngx.print('" id ="phnset_name_txt');  ngx.print(index); ngx.print('" type="text">\
      </div>\
    </div>\
    <div class="row">\
      <div class="col-md-12">\
        <hr/>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20">\
      <div class="col-xs-12 col-md-6 col-sm-6">\
        <span>');  ngx.print(T"Phone Number"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-6 col-sm-6 text-right">\
        <input value="');  ngx.print(v["uri"]); ngx.print('" id ="phnset_num_txt');  ngx.print(index); ngx.print('" type="text">\
      </div>\
    </div>\
    <div class="row">\
      <div class="col-md-12">\
        <hr/>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20">\
      <div class="col-xs-12 col-md-6 col-sm-6">\
        <span>');  ngx.print(T"Username"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-6 col-sm-6 text-right">\
        <input value="');  ngx.print(v["user_name"]); ngx.print('" id ="phnset_uname_txt');  ngx.print(index); ngx.print('" type="text">\
      </div>\
    </div>\
    <div class="row">\
      <div class="col-md-12">\
        <hr/>\
      </div>\
    </div>\
    <div class="row padding-top-bottom-20">\
      <div class="col-xs-12 col-md-6 col-sm-6">\
        <span>');  ngx.print(T"Password"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-6 col-sm-6 text-right">\
        <input type="password" placeholder="********" style="display: none;">\
        <input value="" id ="phnset_pwd_txt');  ngx.print(index); ngx.print('" type="password" placeholder = "********">\
      </div>\
    </div>\
  </div>\
  ');  end  ngx.print('\
</div>\
<h3><span>');  ngx.print(T"Voice Dial Plan"); ngx.print('</span></h3>\
<div class="h3-content phonesettings">\
<!--<div class="row padding-top-bottom-20">\
    <div class="col-xs-12 col-md-6 col-sm-6">\
      <span>');  ngx.print(T"VoIP Dial plan Settings"); ngx.print('</span>\
    </div>\
    <div class="col-xs-12 col-md-6 col-sm-6 text-right">\
      <input name="" value="[0-9*#ABCD].T|[6-9]XXX" type="text">\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>-->\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-12 col-md-6 col-sm-6">\
      <span>');  ngx.print(T"VoIP Dial Timeout (ms)"); ngx.print('</span>\
    </div>\
    <div class="col-xs-12 col-md-6 col-sm-6 text-right">\
      <input name="digitTimeOut" id = "phnset_txt_digittimeout" value="');  ngx.print(digitTimeOut); ngx.print('" type="text">\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-12 col-md-6 col-sm-6">\
      <span>');  ngx.print(T"First Digit Timeout (ms)"); ngx.print('</span>\
    </div>\
    <div class="col-xs-12 col-md-6 col-sm-6 text-right">\
      <input name="dialTimeout" id = "phnset_txt_dtimeout" value="');  ngx.print(dialTimeoutinms); ngx.print('" type="text">\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-7 col-md-6 col-sm-6">\
      <span>');  ngx.print(T"Min-hook-flash (ms)"); ngx.print('</span>\
    </div>\
    <div class="col-xs-5   col-md-6 col-sm-6 text-right">\
      <input name="minHookFlash" id = "phnset_txt_minhook" value="');  ngx.print(IMSServContent["minHookFlash"]); ngx.print('" type="text">\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-7 col-md-6 col-sm-6">\
      <span>');  ngx.print(T"Max-hook-flash (ms)"); ngx.print('</span>\
    </div>\
    <div class="col-xs-5 col-md-6 col-sm-6 text-right">\
     <input name="maxHookFlash" id = "phnset_txt_maxhook" value="');  ngx.print(IMSServContent["maxHookFlash"]); ngx.print('" type="text">\
   </div>\
 </div>\
</div>\
<h3><span>');  ngx.print(T"Voice Audio Codec"); ngx.print('</span></h3>\
<div class="h3-content phonesettings">\
  <div id = "codecChosen">\
    <div class="row padding-top-bottom-20">\
      <div class="col-xs-12 col-md-6 col-sm-6">\
        <span class="line-height-40">');  ngx.print(T"Preferred codec 1"); ngx.print('</span>\
      </div>\
      <div class="col-xs-12 col-md-6 col-sm-6 text-right">\
        <div id="top-info-mode" class="rel col-xs-12 col-md-12 col-sm-12 padding-left-right-mobile no-padding-right">\
          <select id = "phnset_sel_codec1">\
            ');  for k,v in pairs(audiCodec) do  ngx.print('\
              ');  if(v.media_filter == "media_filter_audio_generic" and v.name ~= "telephone-event") then  ngx.print('\
              <option ');  if(v.media_filter == "media_filter_audio_generic" and v.priority == "1") then  ngx.print(' selected ');  end  ngx.print(' value = "');  ngx.print(v.name); ngx.print('">');  ngx.print(v.name); ngx.print('</option>\
              ');  end  ngx.print('\
            ');  end  ngx.print('\
          </select>\
        </div>\
      </div>\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-12 col-md-6 col-sm-6">\
      <span class="line-height-40">');  ngx.print(T"Packetization"); ngx.print('</span>\
    </div>\
    <div class="col-xs-12 col-md-6 col-sm-6 text-right">\
      <div id="top-info-mode" class="rel col-xs-12 col-md-12 col-sm-12 padding-left-right-mobile no-padding-right">\
        <select id = "phnset_sel_packet1">\
          ');  local val, state1
            for k,v in pairs(audiCodec) do
              if(v.media_filter == "media_filter_audio_generic" and v.name ~= "telephone-event" and v.priority == "1") then
                val = v.packetization_time
                state1 = v.allow
              end
            end  ngx.print('\
          ');  for i =1 , #packetizationTime do  ngx.print('\
            <option ');  if packetizationTime[i][1] == val then  ngx.print(' selected ');  end  ngx.print(' value = "');  ngx.print(packetizationTime[i][1]); ngx.print('">');  ngx.print(packetizationTime[i][1]); ngx.print('</option>\
          ');  end  ngx.print('\
        </select>\
      </div>\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-6 col-md-6 col-sm-6">\
      <span class="line-height-32">');  ngx.print(T"State"); ngx.print('</span>\
    </div>\
    <div class="col-xs-6 col-md-6 col-sm-6 text-right">\
      <div id = "phnset_btn_codecstat1" class="button toggle-content-button ');  if state1 == "1" then  ngx.print(' button-on ');  else  ngx.print(' button-off ');  end  ngx.print('"></div>\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-12 col-md-6 col-sm-6">\
      <span class="line-height-40">');  ngx.print(T"Preferred codec 2"); ngx.print('</span>\
    </div>\
    <div class="col-xs-12 col-md-6 col-sm-6 text-right">\
      <div id="top-info-mode" class="rel col-xs-12 col-md-12 col-sm-12 padding-left-right-mobile no-padding-right">\
        <select id = "phnset_sel_codec2">\
          ');  for k,v in pairs(audiCodec) do  ngx.print('\
            ');  if(v.media_filter == "media_filter_audio_generic" and v.name ~= "telephone-event") then  ngx.print('\
              <option ');  if(v.media_filter == "media_filter_audio_generic" and v.priority == "2") then  ngx.print(' selected ');  end  ngx.print(' value = "');  ngx.print(v.name); ngx.print('">');  ngx.print(v.name); ngx.print('</option>\
            ');  end  ngx.print('\
          ');  end  ngx.print('\
        </select>\
      </div>\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-12 col-md-6 col-sm-6">\
      <span class="line-height-40">');  ngx.print(T"Packetization"); ngx.print('</span>\
    </div>\
    <div class="col-xs-12 col-md-6 col-sm-6 text-right">\
      <div id="top-info-mode" class="rel col-xs-12 col-md-12 col-sm-12 padding-left-right-mobile no-padding-right">\
        <select id = "phnset_sel_packet2">\
          ');  local val1, state2
            for k,v in pairs(audiCodec) do
              if(v.media_filter == "media_filter_audio_generic" and v.name ~= "telephone-event" and v.priority == "2") then
                val1 = v.packetization_time
                state2 = v.allow
              end
            end  ngx.print('\
          ');  for i =1 , #packetizationTime do  ngx.print('\
            <option ');  if packetizationTime[i][1] == val1 then  ngx.print(' selected ');  end  ngx.print(' value = "');  ngx.print(packetizationTime[i][1]); ngx.print('">');  ngx.print(packetizationTime[i][1]); ngx.print('</option>\
          ');  end  ngx.print('\
        </select>\
      </div>\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-6 col-md-6 col-sm-6">\
      <span class="line-height-32">');  ngx.print(T"State"); ngx.print('</span>\
    </div>\
    <div class="col-xs-6 col-md-6 col-sm-6 text-right">\
      <div id = "phnset_btn_codecstat2" class="button toggle-content-button ');  if state2 == "1" then  ngx.print(' button-on ');  else  ngx.print(' button-off ');  end  ngx.print('"></div>\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-6 col-md-6 col-sm-6">\
      <span class="line-height-32">');  ngx.print(T"T.38"); ngx.print('</span>\
    </div>\
    <div class="col-xs-6 col-md-6 col-sm-6 text-right">\
      <div id = "phnset_btn_imgcodec" class="button toggle-content-button ');  if(imageCodec =="1") then   ngx.print(' button-on ');  else  ngx.print(' button-off ');  end  ngx.print('"></div>\
    </div>\
  </div>\
</div>\
<h3><span>');  ngx.print(T"Other Settings"); ngx.print('</span></h3>\
<div class="h3-content phonesettings">\
<!--<div class="row padding-top-bottom-20">\
    <div class="col-xs-6 col-md-6 col-sm-6">\
      <span>Voice Re-injection Settings</span>\
    </div>\
    <div class="col-xs-6 col-md-6 col-sm-6 text-right">\
      <div class="button button-on"></div>\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>-->\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-12 col-md-6 col-sm-6">\
      <span class="line-height-40">');  ngx.print(T"Location"); ngx.print('</span>\
    </div>\
    <div class="col-xs-12 col-md-6 col-sm-6 text-right">\
      <div id="top-info-mode" class="rel col-xs-12 col-md-12 col-sm-12 padding-left-right-mobile no-padding-right">\
        <select id = "phnset_chk_loc">\
          <option  selected value = "');  ngx.print(IMSServContent["location"]); ngx.print('"> ');  ngx.print("ESP - " .. upper(IMSServContent["location"])); ngx.print('</option>\
        </select>\
      </div>\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-6 col-md-6 col-sm-6">\
      <span>');  ngx.print(T"Echo Cancellation"); ngx.print('</span>\
    </div>\
    <div class="col-xs-6 col-md-6 col-sm-6 text-right">\
      <div id = "phnset_btn_echocancel" class="button toggle-content-button ');  if IMSServContent["echoCancellation"] =="0" then  ngx.print('button-off ');  else  ngx.print(' button-on');  end  ngx.print('"></div>\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-6 col-md-6 col-sm-6">\
      <span>');  ngx.print(T"VAD support"); ngx.print('</span>\
    </div>\
    ');  local value
      for k,v in pairs(audiCodec) do
        if(v.priority == "1" and v.media_filter ~= "media_filter_image_generic") then
          value = v.remove_silence_suppression
        end
      end  ngx.print('\
    <div class="col-xs-6 col-md-6 col-sm-6 text-right">\
      <div id = "phnset_btn_vad" class="button toggle-content-button ');  if value == "0" then  ngx.print(' button-on ');  else  ngx.print(' button-off ');  end  ngx.print('"></div>\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  ');  for i = 1 , #mapGainTable do  ngx.print('\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-7 col-md-6 col-sm-6">\
      <span>');  ngx.print(mapGainTable[i][1]); ngx.print('</span>\
    </div>\
    <div class="col-xs-5 col-md-6 col-sm-6 text-right">\
      <input name="');  ngx.print(mapGainTable[i][2]); ngx.print('" id = "');  ngx.print(mapGainTable[i][4]); ngx.print('" value="');  ngx.print(mapGainTable[i][3]); ngx.print('" type="text">\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  ');  end  ngx.print('\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-6 col-md-6 col-sm-6">\
      <span class = "line-height-32">');  ngx.print(T"FAX detection"); ngx.print('</span>\
    </div>\
    <div class="col-xs-6 col-md-6 col-sm-6 text-right">\
      <div id = "phnset_btn_faxtransport" class="button toggle-content-button ');  if IMSServContent["faxTransport"] == "disabled" then   ngx.print(' button-off ');  else  ngx.print(' button-on ');  end  ngx.print('"></div>\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  ');  for i = 1 , #mapDSCPTable do   ngx.print('\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-12 col-md-6 col-sm-6">\
      <span>');  ngx.print(mapDSCPTable[i][1]); ngx.print('</span>\
    </div>\
    <div class="col-xs-12 col-md-6 col-sm-6 text-right">\
      <input name="');  ngx.print(mapDSCPTable[i][2]); ngx.print('" id = "');  ngx.print(mapDSCPTable[i][3]); ngx.print('" value="');  ngx.print(mapDSCPTable[i][4]); ngx.print('" type="text" maxlength = "5">\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  ');  end  ngx.print('\
  ');  for i = 1 , #mapDSCPTable1 do   ngx.print('\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-12 col-md-6 col-sm-6">\
      <span>');  ngx.print(mapDSCPTable1[i][1]); ngx.print('</span>\
    </div>\
    <div class="col-xs-12 col-md-6 col-sm-6 text-right">\
      <input name="');  ngx.print(mapDSCPTable1[i][2]); ngx.print('" id = "');  ngx.print(mapDSCPTable1[i][3]); ngx.print('" value="');  ngx.print(mapDSCPTable1[i][4]); ngx.print('" type="text">\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  ');  end  ngx.print('\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-7 col-md-6 col-sm-6">\
      <span>');  ngx.print(T"RTCP packet interval (ms)"); ngx.print('</span>\
    </div>\
    <div class="col-xs-5 col-md-6 col-sm-6 text-right" >\
      <input name="rtcpPacket" id = "phnset_btn_rtcpPacket" value="');  ngx.print(IMSServContent["rtcpPacket"]); ngx.print('" type="text" maxlength = "5">\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-12 col-md-6 col-sm-6">\
      <span class="line-height-40">');  ngx.print(T"DTMF Mode"); ngx.print('</span>\
    </div>\
    <div class="col-xs-12 col-md-6 col-sm-6 text-right">\
      <div id="top-info-mode" class="rel col-xs-12 col-md-12 col-sm-12 padding-left-right-mobile no-padding-right">\
        <select id = "phnset_btn_dtmfmode">\
          ');  for i = 1, #dtmfModeList do  ngx.print('\
          <option ');  if IMSServContent["dtmfMode"] == dtmfModeList[i][1] then  ngx.print(' selected ');  end  ngx.print('value = "');  ngx.print(dtmfModeList[i][1]); ngx.print('">');  ngx.print(dtmfModeList[i][1]); ngx.print('</option>\
          ');  end  ngx.print('\
        </select>\
      </div>\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  ');  for i =1, #timerTable do   ngx.print('\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-12 col-md-6 col-sm-6">\
      <span>');  ngx.print(timerTable[i][1]); ngx.print('</span>\
    </div>\
    <div class="col-xs-12 col-md-6 col-sm-6 text-right">\
      <input name="');  ngx.print(timerTable[i][2]); ngx.print('" id = "');  ngx.print(timerTable[i][3]); ngx.print('" value="');  ngx.print(timerTable[i][4]); ngx.print('" type="text" maxlength="5">\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  ');  end  ngx.print('\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-6 col-md-6 col-sm-6">\
      <span class="line-height-32">');  ngx.print(T"Prack"); ngx.print('</span>\
    </div>\
    <div class="col-xs-6 col-md-6 col-sm-6 text-right">\
      <div id = "phnset_btn_prack" class="button toggle-content-button ');  if IMSServContent["prack"] == "supported" then   ngx.print(' button-on ');  elseif IMSServContent["prack"] == "unsupported" then  ngx.print(' button-off ');  end  ngx.print('">\
      </div>\
    </div>\
  </div>\
  <div class="row">\
    <div class="col-md-12">\
     <hr/>\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-12 col-md-6 col-sm-6">\
      <span class="line-height-40">');  ngx.print(T"Interface Name"); ngx.print('</span>\
    </div>\
    <div class="col-xs-12 col-md-6 col-sm-6 text-right">\
      <div id="top-info-mode" class="rel col-xs-12 col-md-12 col-sm-12 padding-left-right-mobile no-padding-right">\
        <select id = "phnset_sel_intfname">\
        ');  for _, intf in ipairs(intfName) do
            if (intf[1] == "Select an option") then
              ngx.print(format("<option value='%s' %s>%s</option>", intf[1], ((validIntfName[IMSServContent["intfName"]] == nil) and ("selected = 'selected'") or ""), intf[2]))
            else
              ngx.print(format("<option value='%s' %s>%s</option>", intf[1], ((intf[1] == IMSServContent["intfName"]) and ("selected = 'selected'") or ""), intf[2]))
            end
          end  ngx.print('\
        </select>\
      </div>\
    </div>\
  </div>\
</div>\
</form>\
');  
  lp.include("apply-cancel.lp")
  lp.include("reset-wrap-mobile.lp")
  ngx.print('\
<!-- End -->\
<script src="/js/global-min.js" ></script>\
<script>\
  var resetPhonesettings = ');  ngx.print(json.encode(resetphonesettings)); ngx.print('\
</script>\
<script src="/js/phone/settings.js"></script>\
<!-- End -->\
'); 