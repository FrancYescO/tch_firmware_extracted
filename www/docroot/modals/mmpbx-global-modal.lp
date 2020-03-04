<%
-- Enable localization
gettext.textdomain('webui-voice')

local tinsert = table.insert
local proxy = require ("datamodel")
local ui_helper = require("web.ui_helper")
local uimessage_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local untaint_mt = require("web.taint").untaint_mt
local setmetatable = setmetatable
local gVIES = post_helper.getValidateInEnumSelect
local gCV = post_helper.getConditionalValidation
local string = string
local floor = math.floor
local format, match, find = string.format, string.match, string.find
local vB = post_helper.validateBoolean
local vSIDN = post_helper.validateStringIsDomainName
local content_helper = require ("web.content_helper")

local sw_flagParams = {
    sw_flag = "uci.env.var.ssid_prefix",
    variant = "uci.env.var.iinet_variant",
}
content_helper.getExactContent(sw_flagParams)
local nsp_link = setmetatable({
       ["Adam-Internet"] = "https://www.adam.com.au",
       ["Internode"] = "https://www.internode.on.net",
       ["Other"] = "https://www.internode.on.net"
}, untaint_mt)

local nsp_logo = setmetatable({
       ["Adam-Internet"] = "logo-adam.png",
       ["Internode"] = "logo-internode.svg",
       ["Other"] = "logo-internode.svg"
}, untaint_mt)

if sw_flagParams["sw_flag"] ~= "Internode" then
    nsp_link["Other"] = nil
    nsp_logo["Other"] = nil
end

local codec_table = {
    {"G722","G722"},
    {"PCMA","G.711 A law"},
    {"PCMU","G.711 U law"},
    {"G729","G729"},
}

local isp_options = {}
if sw_flagParams["sw_flag"] == "Internode" then
  isp_options = {
      {"Internode", T"Internode"},
      {"Other", T"Other"},
  }
elseif sw_flagParams["variant"] ~= "novas" then
  isp_options = {
      {"iiNet", T"iiNet"},
      {"Westnet", T"Westnet"},
      {"Transact", T"Transact"},
      {"Adam-Internet", T"Adam Internet"},
      {"Internode", T"Internode"},
  }
else
  isp_options = {
      {"iiNet", T"iiNet"},
      {"Westnet", T"Westnet"},
      {"Internode", T"Internode"},
      {"Other", T"Other"},
  }
end

local state_t = {
    {"act", T"ACT"},
    {"nsw", T"NSW"},
    {"nt", T"NT"},
    {"qld", T"QLD"},
    {"sa", T"SA"},
    {"tas", T"TAS"},
    {"vic", T"VIC"},
    {"wa", T"WA"},
}

local sip_profile_p = "uci.mmpbxrvsipnet.profile.@sip_profile_0."
local sip_net_p = "uci.mmpbxrvsipnet.network.@sip_net."
local content_codecs = {}

local function getcodecpath()
    local name, path = nil, ""
    local results = proxy.get("uci.mmpbx.codec_filter.")
    if results then
        for _,v in ipairs(results) do
            v.value = string.format("%s", v.value)
            if v.param == "name" then
               name = v.value
               if not content_codecs[name] then
                 content_codecs[name] = {}
               end
               content_codecs[name]["path"]=v.path
            end
        end
    end
end

getcodecpath()

local mapParams = {
    mmpbx_enabled = "uci.mmpbx.mmpbx.@global.enabled",
    isp = "uci.mmpbxrvsipnet.network.@sip_net.isp",
    sip_state = sip_net_p .. "primary_proxy",
    sip_registrar = sip_net_p .. "primary_registrar",
    sip_domain = sip_net_p .. "domain_name",
    nsplink = "uci.web.uiconfig.@uidefault.nsplink",
    nsplogo = "uci.web.uiconfig.@uidefault.nsplogo",
 }
if sw_flagParams["variant"] == "novas" then
    mapParams.provisioningCode = "uci.env.var.provisioning_code"
end
local function gVerifyIsp(options)
      return function(value, object, key)
          local success, msg = gVIES(options)(value)
          if success then
             object["provisioningCode"] = object["isp"]
             if value == "Adam-Internet" then
                 object[key] = "Adam Internet"
             end
             object["nsplink"] = nsp_link[value] or "https://www.iinet.net.au"
             object["nsplogo"] = nsp_logo[value] or "logo.gif"
             return true
          else
             return nil, msg
          end
      end
end

local function getSipHost(value, object, key)
    if object["isp"] == "Internode" then
        object["sip_state"] = "sip.internode.on.net"
        object["sip_registrar"] = object["sip_state"]
        object["sip_domain"] = object["sip_state"]
    elseif object["isp"] == "Other" then
        local isp_Param = {
            old_sip = "uci.mmpbxrvsipnet.network.@sip_net.isp",
        }
        content_helper.getExactContent(isp_Param)
        if isp_Param["old_sip"] ~= "Other" then
            object["sip_state"] = "0.0.0.0"
            object["sip_registrar"] = "0.0.0.0"
            object["sip_domain"] = "0.0.0.0"
        else
            object["sip_state"] = nil
        end
    elseif sw_flagParams["variant"] == "novas" then
        object["sip_state"] = "uni-v1.iinet.net.au"
        object["sip_domain"] = object["sip_state"]
        object["sip_registrar"] = object["sip_state"]
    else
        local vSipState = gVIES(state_t)
        local ok, err = vSipState(value)
        if not ok then
            return ok, err
        end
        object["sip_state"] = format("sip.%s.iinet.net.au", object["sip_state"])
        object["sip_registrar"] = object["sip_state"]
        object["sip_domain"] = "iinetphone.iinet.net.au"
    end
    return true
 end

local mapValid = {
    mmpbx_enabled = vB,
    isp = gVerifyIsp(isp_options),
    sip_state = gCV(getSipHost),
    sip_registrar = function (val, object)
      return true
    end,
    sip_domain = function (val, object)
      return true
    end,
    nsplink = function (val, object)
      return true
    end,
    nsplogo = function (val, object)
      return true
    end,
}

for k, v in pairs(content_codecs) do
      local param = string.gsub(k, "(%-)", "_")
      param = param .. "_allow"
      mapParams[param] = v["path"] .. "allow"
      mapValid[param] = vB
end

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
if content["isp"] ~= "Internode" and content["isp"] ~= "Other" then
	content["sip_state"] = content["sip_state"]:match("sip%.([^%.]*)%.iinet.net.au") or "nsw"
end

if content["isp"] == "Adam Internet" then
    content["isp"] = "Adam-Internet"
end

-- SIP Networks
local sipnet_columns = {
  {
    header = T"Name",
    name = "user_friendly_name",
    param = "user_friendly_name",
    type = "label",
    readonly = true,
    attr = { input = { class="span2" }},
  },
  {
    header = T"SIP Domain",
    name = "domain_name",
    param = "domain_name",
    type = "text",
    attr = { input = { class="span2" } },
  },
  {
    header = T"Primary Registrar",
    name = "primaryRegistrar",
    param = "primary_registrar",
    type = "text",
    attr = { input = { class="span2" } },
  },
  {
    header = T"Primary RegistrarPort",
    name = "primaryRegistrarPort",
    param = "primary_registrar_port",
    type = "text",
    attr = { input = { class="span1" } },
  },
  {
    header = T"Primary Proxy",
    name = "primaryProxy",
    param = "primary_proxy",
    type = "text",
    attr = { input = { class="span2" } },
  },
  {
    header = T"Primary ProxyPort",
    name = "primaryProxyPort",
    param = "primary_proxy_port",
    type = "text",
    attr = { input = { class="span1" } },
  },
  {
    header = T"Expire Time",
    name = "regExpire",
    param = "reg_expire",
    type = "text",
    attr = { input = { class="span2" } },
  },
}

local column = {
    domain_name = 2,
    primaryRegistrar = 3,
    primaryproxy = 5,
}

if sw_flagParams["variant"] == "novas" then
    for _,v in pairs(column) do
        sipnet_columns[v]["type"] = "password"
    end
end

local function validateStringIsVoicePort(value, object, key)
    local value = value and match(value, "^[%s0]*(%d+)%s*$")
    local port = value and tonumber(value)
    if port and (floor(port) == port) and (port == 0 or (port >=1024 and port < 65536)) then
        return true
    end
    return nil, T"Port is invalid. It should be 0 or between 1024 and 65535."
end


local gV = post_helper.getOrValidation
local vSII = post_helper.validateStringIsIP
local vSIDN = post_helper.validateStringIsDomainName
local vRE =  post_helper.validateRegExpire

local mask_password = "********"
local sipnet_valid = {
    domain_name = function(value, object, key)
        if sw_flagParams["variant"] == "novas" and value == mask_password then
            object[key] = nil
            return true
        else
            return gV(vSII,vSIDN)(value, object, key)
        end
    end,
    primaryRegistrarPort = validateStringIsVoicePort,
    primaryRegistrar = function(value, object, key)
        if sw_flagParams["variant"] == "novas" and value == mask_password then
            object[key] = nil
            return true
        else
            return gV(vSII,vSIDN)(value, object, key)
        end
    end,
    primaryProxy = function(value, object, key)
        if sw_flagParams["variant"] == "novas" and value == mask_password then
            object[key] = nil
            return true
        else
            return gV(vSII,vSIDN)(value, object, key)
        end
    end,
    primaryProxyPort = validateStringIsVoicePort,
    regExpire = vRE,
}

local sipnet_options = {
    canEdit = true,
    canAdd = false,
    canDelete = false,
    tableid = "sipnet",
    basepath = "uci.mmpbxrvsipnet.network.",
    sorted = "user_friendly_name",
}

if sw_flagParams["variant"] == "novas" then
    sipnet_options.canEdit = (content["isp"] == "Other")
end

local sipnet_data, sipnet_helpmsg = post_helper.handleTableQuery(sipnet_columns, sipnet_options, nil, nil, sipnet_valid)

for _,v in ipairs(sipnet_data) do
    if sw_flagParams["variant"] == "novas" then
        v[column.domain_name] = mask_password
        v[column.primaryRegistrar] = mask_password
        v[column.primaryproxy] = mask_password
    else
        if v[column.domain_name] == "" then
            v[column.domain_name] = v[column.primaryRegistrar]
        end
    end
end

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end
%>

<%= ui_helper.createHeader(T"Telephony", false, true) %>
<div class="modal-body update">
  <%
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-voice.lp")
  %>
  <form class="form-horizontal" method="post" action="<%= uri %>">
  <%=ui_helper.createMessages(uimessage_helper.popMessages())%>
	<fieldset id="mmpbx-global-tab">
	    <legend><%= T"Global Information" %></legend>
	    <%= ui_helper.createSwitch(T"Enabled", "mmpbx_enabled", content["mmpbx_enabled"]) %>
	</fieldset>
         <fieldset>
           <legend><%= T"Codec" %></legend>
             <%
               html = {}
               for _, v in ipairs(codec_table) do
                   local param = string.gsub(v[1], "(%-)", "_")
                   param = param .. "_allow"
                   html[#html+1] = ui_helper.createSwitch(T(v[2]), param, content[param])
               end
               ngx.print(html)
              %>
          </fieldset>
        <fieldset>
            <legend><%= T"SIP Network" %></legend>
            <%
               --According to Service Provider select State
               html = { }
               local SerProattributes = {
                       group = {
                            class = "",
                       },
                       select ={
                            class = "monitor-changes"
                       }
               }
               html[#html+1]  = ui_helper.createInputSelect(T"Internet Service Provider", "isp", isp_options, content["isp"], SerProattributes )
               if sw_flagParams["variant"] ~= "novas" then
                 local ispclass = {
                      group = {
                             class = "monitor-isp monitor-Transact monitor-iiNet monitor-Westnet monitor-Adam-Internet",
                      },
                      input = {
                             class="span4"
                       }
                }
                html[#html+1]  = ui_helper.createInputSelect(T"State/Territory:", "sip_state", state_t, content["sip_state"],ispclass, helpmsg["sip_state"])
             end
             ngx.print(html)
             %>

            <%=ui_helper.createTable(sipnet_columns, sipnet_data, sipnet_options, nil, sipnet_helpmsg)%>
        </fieldset>
    </form>
</div>

<%= ui_helper.createFooter() %>
