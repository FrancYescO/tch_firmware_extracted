<%
-- Enable localization
gettext.textdomain('webui-voice')

local tinsert = table.insert
local proxy = require ("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local untaint_mt = require("web.taint").untaint_mt
local setmetatable = setmetatable
local gVIES = post_helper.getValidateInEnumSelect
local gCV = post_helper.getConditionalValidation
local string = string
local format, match, find = string.format, string.match, string.find
local vB = post_helper.validateBoolean
local content_helper = require ("web.content_helper")

local sw_flagParams = {
    sw_flag = "uci.env.var.ssid_prefix",
}
content_helper.getExactContent(sw_flagParams)
local nsp_link = setmetatable({
       ["Adam-Internet"] = "http://www.adam.com.au",
       ["Internode"] = "http://www.internode.on.net",
       ["Other"] = "http://www.internode.on.net"
}, untaint_mt)

local nsp_logo = setmetatable({
       ["Adam-Internet"] = "logo-adam.png",
       ["Internode"] = "internode-logo.svg",
       ["Other"] = "internode-logo.svg"
}, untaint_mt)

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
else
  isp_options = {
      {"iiNet", T"iiNet"},
      {"Westnet", T"Westnet"},
      {"Transact", T"Transact"},
      {"Adam-Internet", T"Adam Internet"},
      {"Internode", T"Internode"},
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
    ppp_username  = "uci.network.interface.@ppp.username",
    delegateRestriction = "uci.network.interface.@wan6.delegateRestriction",
    lan_ip6assign = "uci.network.interface.@lan.ip6assign",
    guest1_ip6assign = "uci.network.interface.@Guest1.ip6assign",
    Guest1_5GHz_ip6assign = "uci.network.interface.@Guest1_5GHz.ip6assign",
    VLAN1_ip6assign = "uci.network.interface.@VLAN1.ip6assign",
    VLAN2_ip6assign = "uci.network.interface.@VLAN2.ip6assign",
    VLAN3_ip6assign = "uci.network.interface.@VLAN3.ip6assign",
}

local function gVerifyIsp(options)
      return function(value, object, key)
          local success, msg = gVIES(options)
          if success then
             if value == "Adam-Internet" then
                 object[key] = "Adam Internet"
             end
             object["nsplink"] = nsp_link[value] or "http://www.iinet.net.au"
             object["nsplogo"] = nsp_logo[value] or "logo.gif"
             if object[key] == "Internode" then
			    object["delegateRestriction"] = "Dynamic"
                if string.find(object["ppp_username"],"@dynamic") then
                    object["lan_ip6assign"] = "64"
					object["guest1_ip6assign"] = ""
					object["Guest1_5GHz_ip6assign"] = ""
					object["VLAN1_ip6assign"] = ""
					object["VLAN2_ip6assign"] = ""
					object["VLAN3_ip6assign"] = ""
				else
					object["lan_ip6assign"] = "64"
					object["guest1_ip6assign"] = "64"
					object["Guest1_5GHz_ip6assign"] = "64"
					object["VLAN1_ip6assign"] = "64"
					object["VLAN2_ip6assign"] = "64"
					object["VLAN3_ip6assign"] = "64"
                end
             else
			    object["delegateRestriction"] = "Off"
				object["lan_ip6assign"] = "64"
				object["guest1_ip6assign"] = "64"
				object["Guest1_5GHz_ip6assign"] = "64"
				object["VLAN1_ip6assign"] = "64"
				object["VLAN2_ip6assign"] = "64"
				object["VLAN3_ip6assign"] = "64"
             end
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
            object["sip_state"] = ""
            object["sip_registrar"] = ""
            object["sip_domain"] = ""
		else
            object["sip_state"] = nil
		end
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

local sipnet_valid = {
    domain_name = post_helper.getOrValidation(post_helper.validateStringIsIP,post_helper.validateStringIsDomainName),
    primaryRegistrarPort = post_helper.validateStringIsPort,
    primaryRegistrar = post_helper.getOrValidation(post_helper.validateStringIsIP,post_helper.validateStringIsDomainName),
    primaryProxy = post_helper.getOrValidation(post_helper.validateStringIsIP,post_helper.validateStringIsDomainName),
    primaryProxyPort = post_helper.validateStringIsPort,
    regExpire = post_helper.validateRegExpire,
}

local sipnet_options = {
    canEdit = true,
    canAdd = false,
    canDelete = false,
    tableid = "sipnet",
    basepath = "uci.mmpbxrvsipnet.network.",
    sorted = "user_friendly_name",
}

local sipnet_data, sipnet_helpmsg = post_helper.handleTableQuery(sipnet_columns, sipnet_options, nil, nil, sipnet_valid)

local column = {
    domain_name = 2,
    primaryRegistrar = 3,
}

for _,v in ipairs(sipnet_data) do
    if v[column.domain_name] == "" then
        v[column.domain_name] = v[column.primaryRegistrar]
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
               local ispclass = {
                      group = {
                             class = "monitor-isp monitor-Transact monitor-iiNet monitor-Westnet monitor-Adam-Internet",
                      },
                      input = {
                             class="span4"
                       }
                }
             html[#html+1]  = ui_helper.createInputSelect(T"State/Territory:", "sip_state", state_t, content["sip_state"],ispclass, helpmsg["sip_state"])
             ngx.print(html)
             %>

            <%=ui_helper.createTable(sipnet_columns, sipnet_data, sipnet_options, nil, sipnet_helpmsg)%>
        </fieldset>
    </form>
</div>

<%= ui_helper.createFooter() %>
