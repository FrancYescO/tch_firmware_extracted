<%
-- Enable localization
gettext.textdomain('webui-voice')

local ngx = ngx
local proxy = require ("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "Telephony", "Global")
local content_helper = require("web.content_helper")
local uimessage_helper = require("web.uimessage_helper")
local format, match, floor = string.format, string.match, math.floor
local session = ngx.ctx.session
local validateDomain = post_helper.validateStringIsDomainName
local role = session:getrole()
local userName = session:getusername()
local validateBoolean = post_helper.validateBoolean
local validatePositiveNum = post_helper.validatePositiveNum
local getOptionalValidation = post_helper.getOptionalValidation
local json = require("dkjson")

local packetizationTime = {
  {"10", T"10"},
  {"20", T"20"},
  {"30", T"30"}
}
local codecList = {
  {"PCMA", T"PCMA"},
  {"PCMU", T"PCMU"},
  {"G729", T"G729"}
}

local transport_type_options = {
  {"undefined", T"Undefined"},
  {"UDP", T"UDP"},
  {"TCP", T"TCP"},
}

if post_helper.isFeatureEnabled("transportTypeTLS", role) then
  transport_type_options[#transport_type_options + 1] = {"TLS", T"TLS"}
end

local qos_field_options = {
  {"dscp", T"dscp"},
  {"precedence", T"precedence"}
}
local qos_dscp_value_options = {
  {"ef", T"ef"},
  {"af11", T"af11"},
  {"af12", T"af12"},
  {"af13", T"af13"},
  {"af21", T"af21"},
  {"af22", T"af22"},
  {"af23", T"af23"},
  {"af31", T"af31"},
  {"af32", T"af32"},
  {"af33", T"af33"},
  {"af41", T"af41"},
  {"af42", T"af42"},
  {"af43", T"af43"},
  {"cs0", T"cs0"},
  {"cs1", T"cs1"},
  {"cs2", T"cs2"},
  {"cs3", T"cs3"},
  {"cs4", T"cs4"},
  {"cs5", T"cs5"},
  {"cs6", T"cs6"},
  {"cs7", T"cs7"},
  {"0", T"0"},
  {"1", T"1"},
  {"2", T"2"},
  {"3", T"3"},
  {"4", T"4"},
  {"5", T"5"},
  {"6", T"6"},
  {"7", T"7"}
}

local qos_precedence_value_options = {
  {"routine", T"routine"},
  {"priority", T"priority"},
  {"immediate", T"immediate"},
  {"flash", T"flash"},
  {"flash_overrides", T"flash_overrides"},
  {"CRITIC_ECP", T"CRITIC_ECP"},
  {"internetworkControl", T"internetwork-control"},
  {"networkControl", T"network-control"},
  {"0", T"0"},
  {"1", T"1"},
  {"2", T"2"},
  {"3", T"3"},
  {"4", T"4"},
  {"5", T"5"},
  {"6", T"6"},
  {"7", T"7"}
}

local content = {}

--Used as function, Since the below values like emission state, qos values and mmpbx enabled are fetched twice
local function getPageParams()
  content["mmpbx_enabled"] = "uci.mmpbx.mmpbx.@global.enabled"
  if proxy.get("rpc.mmpbx.dectemission.state") then
    content["emission_state"] = "rpc.mmpbx.dectemission.state"
  end
  if post_helper.getVariantValue(variantHelper, "NoAnswerTimeout") and  role == "engineer" then
    content["no_answer_timeout"] = "uci.mmpbx.mmpbx.@global.no_answer_timeout"
  end
  if post_helper.isFeatureEnabled("telephonyQosTag", role) then
    content["control_qos_field"] = "uci.mmpbxrvsipnet.network.@sip_net.control_qos_field"
    content["control_qos_value"] = "uci.mmpbxrvsipnet.network.@sip_net.control_qos_value"
    content["realtime_qos_field"] = "uci.mmpbxrvsipnet.network.@sip_net.realtime_qos_field"
    content["realtime_qos_value"] = "uci.mmpbxrvsipnet.network.@sip_net.realtime_qos_value"
  end
  content_helper.getExactContent(content)
end

getPageParams()

local content1, helpmsg, mapValid, mapParams
if post_helper.isFeatureEnabled("dedicatedDomain", role) then
  mapValid = {
    mmpbx_enabled = post_helper.validateBoolean,
  }
  mapParams = {
    mmpbx_enabled = "uci.mmpbx.mmpbx.@global.enabled",
  }
end
if ngx.req.get_method() == "POST" then
  local args = ngx.req.get_post_args()
  if args["domain_state"] == "0" then
    proxy.set("uci.mmpbxrvsipnet.network.@sip_net.domain_name","")
  elseif args["domain_state"] then
    mapParams.domain_name = "uci.mmpbxrvsipnet.network.@sip_net.domain_name"
    mapValid.domain_name = post_helper.validateStringIsDomainName
  end
  local emissionState = args.emission_state
  proxy.set("rpc.mmpbx.dectemission.state", emissionState)
  proxy.apply()
end

local domainName
local domainState

if post_helper.isFeatureEnabled("dedicatedDomain", role) then
  content1, helpmsg = post_helper.handleQuery(mapParams, mapValid)
  local domainVal = proxy.get("uci.mmpbxrvsipnet.network.@sip_net.domain_name")
  domainName = domainVal and domainVal[1] and domainVal[1].value
  domainState = "0"
  if domainName ~= "" then
    domainState = "1"
  end
end

local attribute = {input = { class = "span2"}}

-- SIP Networks
local sipnet_columns = {
  { --[1]
    header = T"Name",
    name = "user_friendly_name",
    param = "user_friendly_name",
    type = "label",
    readonly = true,
    attr = attribute,
  },
  { --[2]
    header = T"Primary Registrar",
    name = "primaryRegistrar",
    param = "primary_registrar",
    type = "text",
    attr = attribute,
  },
  { --[3]
    header = T"Primary RegistrarPort",
    name = "primaryRegistrarPort",
    param = "primary_registrar_port",
    type = "text",
    attr = attribute,
  },
  { --[4]
    header =  T"Primary Proxy",
    name = "primaryProxy",
    param = "primary_proxy",
    type = "text",
    attr = attribute,
  },
  { --[5]
    header = T"Primary ProxyPort",
    name = "primaryProxyPort",
    param = "primary_proxy_port",
    type = "text",
    attr = attribute,
  },
  { --[6]
    header = T"Expire Time",
    name = "regExpire",
    param = "reg_expire",
    type = "text",
    attr = attribute,
  },
  { --[7]
    header = T"Interface",
    name = "interface",
    param = "interface",
    type = "label",
    readonly = true,
    attr = attribute,
  },
  { --[8]
    header =  T"Transport Type",
    name = "transport_type",
    param = "transport_type",
    type = "select",
    values = transport_type_options,
    attr = attribute,
  },
  { --[9]
    header = T"Registration Retry Interval",
    name = "reg_back_off_timeout",
    param = "reg_back_off_timeout",
    type = "text",
    attr = attribute,
  },
}

if post_helper.isFeatureEnabled("dtagMode", role) then
  sipnet_columns[10] = {
    header = T"Local Port",
    name = "local_port",
    param = "local_port",
    type = "text",
    attr = attribute,
  }
end

local function validateStringIsVoicePort(value, object, key)
  value = value and match(value, "^[%s0]*(%d+)%s*$")
  local port = value and tonumber(value)
  if port and (floor(port) == port) and (port == 0 or (port >=1024 and port < 65536)) then
    return true
  end
  return nil, T"Port is invalid. It should be 0 or between 1024 and 65535."
end

local function validateRegProxy(value, object, key)
  local validateStringIsIP = post_helper.validateStringIsIP()
  if validateStringIsIP(value) then
    local ipValid, broadcastIP, isRes, isQTN_LXC, errorMsg
    ipValid, errorMsg = post_helper.validateRelay(value, object)
    if not ipValid then
      return nil, errorMsg
    end
    broadcastIP, errorMsg = post_helper.advancedIPValidation(value, object, key)
    if not broadcastIP then
       return nil, errorMsg
    end
    isRes, errorMsg = post_helper.reservedIPValidation(value)
    if not isRes then
      return nil, errorMsg
    end
    isQTN_LXC, errMsg = post_helper.getAndValidation(post_helper.validateQTN, post_helper.validateLXC)(value)
    if not isQTN_LXC then
      return nil, errMsg
    end
  end
  return validateDomain(value)
end

local function validateRegBackTimer(value)
  local num = tonumber(value)
  if (num and num > 0) then
    return true
  end
  return nil, T"Positive number expected."
end

local sipnet_valid = {
  primaryRegistrarPort = validateStringIsVoicePort,
  primaryRegistrar = validateRegProxy,
  primaryProxy = validateRegProxy,
  primaryProxyPort = validateStringIsVoicePort,
  regExpire = post_helper.validateRegExpire,
  reg_back_off_timeout = validateRegBackTimer
}

if post_helper.isFeatureEnabled("dtagMode", role) then
  sipnet_valid.local_port = validateStringIsVoicePort
end

local sipnet_options = {
  canEdit = true,
  canAdd = false,
  canDelete = false,
  tableid = "sipnet",
  basepath = "uci.mmpbxrvsipnet.network.",
  sorted = "user_friendly_name"
}

local sipnet_data, sipnet_helpmsg = post_helper.handleTableQuery(sipnet_columns, sipnet_options, nil, nil, sipnet_valid)

-- Get the Index of the preferred codec
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

-- Set the codec priority, packetization and state of a preffered codec
local function setCodecValues(instanceNext1, audioCodecList, preferredCodec, priority, packetization, state)
  local setParam = {}
  local codecContent = {}
  codecContent.priority = format("uci.mmpbx.codec_filter.%s.priority", instanceNext1)
  codecContent.allow = format("uci.mmpbx.codec_filter.%s.allow", instanceNext1)
  content_helper.getExactContent(codecContent)
  if(codecContent.priority) then
    for _, codec in pairs(audioCodecList) do
      if(codec.priority == priority and codec.media_filter == "media_filter_audio_generic" and codec.name ~= "telephone-event") then
        setParam[format("uci.mmpbx.codec_filter.%s.priority", codec.paramindex)] = codecContent.priority
        if(codecContent.allow) then
          setParam[format("uci.mmpbx.codec_filter.%s.allow", codec.paramindex)] = codecContent.allow
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

-- Since the entire path for codecs is unknown, POST is used insted of handleQuery
if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SAVE" then
  local postargs = ngx.req.get_post_args()
  local all = 0
  for k, v in pairs(postargs) do
    all = all + 1
  end
  local setTable = {}
  ngx.header.content_type = "text/html"
  setTable["uci.mmpbx.mmpbx.@global.enabled"] = postargs.mmpbx_enabled
  if content and content.mmpbx_enabled == "1" and all > 3 then
    if role == "engineer" or role == "superuser" or role == "telia" then
      if post_helper.getVariantValue(variantHelper, "NoAnswerTimeout") then
        if not getOptionalValidation(validatePositiveNum) then
          return nil, T"Only Positive number allowed"
        end
        setTable["uci.mmpbx.mmpbx.@global.no_answer_timeout"] = postargs.no_answer_timeout
      end
      if post_helper.getVariantValue(variantHelper, "CodecAndQoSTag") then
        local audioCodecList = content_helper.convertResultToObject("uci.mmpbx.codec_filter.", proxy.get("uci.mmpbx.codec_filter."))
        local getIndex1 =  getCodecIndex(audioCodecList, postargs.preferredCodec1)
        if not validateBoolean(postargs.state1) or not validateBoolean(postargs.state2) then
          return
        end
        setCodecValues(getIndex1, audioCodecList, postargs.preferredCodec1, "1", postargs.packetization1, postargs.state1)
        -- audioCodecList2 gets the codec list after setCodecValues of Preferred codec 1
        local audioCodecList2 = content_helper.convertResultToObject("uci.mmpbx.codec_filter.", proxy.get("uci.mmpbx.codec_filter."))
        local getIndex2 = getCodecIndex(audioCodecList2, postargs.preferredCodec2)
        setCodecValues(getIndex2, audioCodecList2, postargs.preferredCodec2, "2", postargs.packetization2, postargs.state2)
        setTable["uci.mmpbxrvsipnet.network.@sip_net.control_qos_field"] = postargs.control_qos_field
        setTable["uci.mmpbxrvsipnet.network.@sip_net.control_qos_value"] = postargs.control_qos_value
        setTable["uci.mmpbxrvsipnet.network.@sip_net.realtime_qos_field"] = postargs.realtime_qos_field
        setTable["uci.mmpbxrvsipnet.network.@sip_net.realtime_qos_value"] = postargs.realtime_qos_value
      end
    end
  end
  local success, _ = proxy.set(setTable)
  if post_helper.isFeatureEnabled("dedicatedDomain", role) then
    if success and not next(helpmsg) then
      proxy.apply()
      uimessage_helper.pushMessage(T"Changes saved successfully", "success")
    else
      ngx.print('{ "status":"error" }')
    end
  elseif not post_helper.isFeatureEnabled("dedicatedDomain", role) then
    if success then
     proxy.apply()
      uimessage_helper.pushMessage(T"Changes saved successfully", "success")
    else
      ngx.print('{ "status":"error" }')
    end
  end
end

-- audioCodec gets the codec list after setCodecValues of Preferred codec 1 & Preferred codec 2
local audiCodec = content_helper.convertResultToObject("uci.mmpbx.codec_filter.", proxy.get("uci.mmpbx.codec_filter."))
local codec1, pTime1, state1, codec2, pTime2, state2
for _,v in pairs(audiCodec) do
  if(v.media_filter == "media_filter_audio_generic" and v.name ~= "telephone-event") then
    if v.priority == "1" then
      codec1 = v.name
      pTime1 = v.packetization_time
      state1 = v.allow
    elseif v.priority == "2" then
      codec2 = v.name
      pTime2 = v.packetization_time
      state2 = v.allow
    end
  end
end

%>
<% if userName == "user" then
     ngx.print(ui_helper.createHeader(T"Telephony", "showAdvanced", true))
   else
     ngx.print(ui_helper.createHeader(T"Telephony", post_helper.variantHasAccess(variantHelper, "showAdvanced", role), true))
   end %>

<div class="modal-body update">
  <%
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-voice.lp")
  %>
  <form class="form-horizontal" id="myform" method="post" action="modals/mmpbx-global-modal.lp">
    <%=ui_helper.createMessages(uimessage_helper.popMessages())%>
    <fieldset id="mmpbx-global-tab">
      <%=getPageParams()%>
      <%if post_helper.getVariantValue(variantHelper, "TelephonyGlobalAccess") or userName == "user" then %>
        <legend><%=  T"Global Information" %></legend>
        <% if post_helper.isFeatureEnabled("dedicatedDomain", role) then %>
          <%= ui_helper.createSwitch(T"Enabled", "mmpbx_enabled", content1.mmpbx_enabled) %>
        <%else%>
          <%= ui_helper.createSwitch(T"Enabled", "mmpbx_enabled", content.mmpbx_enabled) %>
        <%end%>
      <%end%>
      <%if post_helper.getVariantValue(variantHelper, "NoAnswerTimeout") then %>
        <% local advanced = {
          group = { class = "advanced hide"},
          span = { class = "span4" }
        }%>
        <% if content and content.mmpbx_enabled == "1" then %>
          <%= ui_helper.createInputText(T"No Answer Timeout", "no_answer_timeout", content.no_answer_timeout, advanced) %>
        <%end%>
      <%end%>
    </fieldset>
    <% if content and content.mmpbx_enabled == "1" then %>
      <%if session:hasAccess("/modals/mmpbx-dect-modal.lp") and userName ~= "user" then %>
        <fieldset>
          <legend><%= T"DECT Emission" %></legend>
            <% if content.emission_state == "0" then
              local emission_on_class = {
                switch = {
                  ["data-name"] = "action",
                  ["data-value"] = "emission_on",
                }
              }
              ngx.print(ui_helper.createSwitch(T"Emission Mode", "emission_state", "0", emission_on_class))
            else
              local emission_off_class = {
                switch = {
                  ["data-name"] = "action",
                  ["data-value"] = "emission_off",
                }
              }
              ngx.print(ui_helper.createSwitch(T"Emission Mode", "emission_state", "1", emission_off_class))
            end%>
        </fieldset>
      <%end%>
      <%if post_helper.getVariantValue(variantHelper, "sipNetwork") or userName == "user" then %>
        <fieldset class="advanced hide">
      <%else%>
        <fieldset>
      <%end%>
        <legend><%= T"SIP Network"%></legend>
        <% if post_helper.isFeatureEnabled("dedicatedDomain", role) then
          local switch_class_enable = {
            input = {
              class = "monitor-changes"
            }
          } %>
          <%=ui_helper.createSwitch(T"Dedicated Domain", "domain_state", domainState, switch_class_enable)%>
          <%local domain_name = {
            group = {
              class ="monitor-domain_state monitor-1",
            },
            input = {
              maxlength= "255",
              class = "span2",
            },
          }%>
          <%=ui_helper.createInputText(T"Domain Name", "domain_name", domainName, domain_name, helpmsg["domain_name"])%>
        <% end %>
      <%=ui_helper.createTable(sipnet_columns, sipnet_data, sipnet_options, nil, sipnet_helpmsg)%>
      </fieldset>
      <%if post_helper.variantHasAccess(variantHelper, "CodecAndQoSTag", role) then %>
        <fieldset class="advanced hide">
          <legend><%= T"Voice Audio Codec" %></legend>
          <%
            local attr = {input = { class = "span2"}}
            ngx.print(
              ui_helper.createInputSelect(T"Preferred codec 1", "preferredCodec1", codecList, codec1, attr),
              ui_helper.alertAttributes("Duplicate values are not allowed", "alert-error hide", "duplicate-value-codec1"),
              ui_helper.createInputSelect(T"Packetization", "packetization1", packetizationTime, pTime1, attr),
              ui_helper.createSwitch(T"State", "state1", state1),
              ui_helper.createInputSelect(T"Preferred codec 2", "preferredCodec2", codecList, codec2, attr),
              ui_helper.alertAttributes("Duplicate values are not allowed", "alert-error hide", "duplicate-value-codec2"),
              ui_helper.createInputSelect(T"Packetization", "packetization2", packetizationTime, pTime2, attr),
              ui_helper.createSwitch(T"State", "state2", state2)
            )
          %>
        </fieldset>
        <fieldset class="advanced hide">
          <legend><%= T"QoS Tag" %></legend>
          <%
            ngx.print(
              ui_helper.createInputSelect(T"Control QoS field", "control_qos_field", qos_field_options, content.control_qos_field, attribute),
              ui_helper.createInputSelect(T"Control QoS value", "control_qos_value", qos_dscp_value_options, content.control_qos_value, attribute),
              ui_helper.createInputSelect(T"Realtime QoS field", "realtime_qos_field", qos_field_options, content.realtime_qos_field, attribute),
              ui_helper.createInputSelect(T"Realtime QoS value", "realtime_qos_value", qos_dscp_value_options, content.realtime_qos_value, attribute)
            )
          %>
        </fieldset>
      <%end%>
    <%end%>
  </form>
</div>

<%= ui_helper.createFooter() %>
<script>
  <%if content and content.mmpbx_enabled == "0" then %>
    $(".nav li a").addClass("disabled");
  <%else%>
    if($(".nav li a").hasClass("disabled")) {
      $(".nav li a").removeClass("disabled");
    }
  <%end%>
  var mmpbx_enabled = "<%=content["mmpbx_enabled"]%>";
  var dscp_control  = $('<select id="control_qos_value" class=" span2" name="control_qos_value"><%for _,v in pairs(qos_dscp_value_options) do if content.control_qos_value == v[1] then%><option value="<%=v[1]%>" selected="selected"><%=v[2]%></option><%else%><option value="<%=v[1]%>"><%=v[2]%></option><%end%><%end%></select>');
  var precedence_control  = $('<select id="control_qos_value" class=" span2" name="control_qos_value"><%for _,v in pairs(qos_precedence_value_options) do if content.control_qos_value == v[1] then%><option value="<%=v[1]%>" selected="selected"><%=v[2]%></option><%else%><option value="<%=v[1]%>"><%=v[2]%></option><%end%><%end%></select>');
  var dscp_realtime  = $('<select id="realtime_qos_value" class=" span2" name="realtime_qos_value"><%for _,v in pairs(qos_dscp_value_options) do if content.realtime_qos_value == v[1] then%><option value="<%=v[1]%>" selected="selected"><%=v[2]%></option><%else%><option value="<%=v[1]%>"><%=v[2]%></option><%end%><%end%></select>');
  var precedence_realtime  = $('<select id="realtime_qos_value" class=" span2" name="realtime_qos_value"><%for _,v in pairs(qos_precedence_value_options) do if content.realtime_qos_value == v[1] then%><option value="<%=v[1]%>" selected="selected"><%=v[2]%></option><%else%><option value="<%=v[1]%>"><%=v[2]%></option><%end%><%end%></select>');
  var control_qos = "<%=content.control_qos_field%>";
  var realtime_qos = "<%=content.realtime_qos_field%>";
  var role = "<%=role%>";
  var dedicatedDomain = "<%=post_helper.isFeatureEnabled("dedicatedDomain", role)%>";
  var domainNameEmptyErrMsg=  "<%= T"Domain name cannot be empty." %>";
</script>
<script src="/js/mmpbx-global-modal.js"></script>
