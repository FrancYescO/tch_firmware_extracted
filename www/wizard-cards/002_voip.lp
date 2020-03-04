--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-wizard')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local gCV = post_helper.getConditionalValidation
local vB = post_helper.validateBoolean
local gVIES = post_helper.getValidateInEnumSelect
local session = ngx.ctx.session
local wizard_helper = require("wizard")
local string = string
local format, match, find = string.format, string.match, string.find

local param_content = {
    variant = "uci.env.var.iinet_variant",
}
require("web.content_helper").getExactContent(param_content)

if param_content.variant ~= "novas" then

local mask_password = "********"
local sip_profile_p = "uci.mmpbxrvsipnet.profile.@sip_profile_0."
local sip_net_p = "uci.mmpbxrvsipnet.network.@sip_net."

local mapParams = {
    sip_enabled = sip_profile_p .. "enabled",
    sip_number = sip_profile_p .. "uri",
    sip_username = sip_profile_p .. "user_name",
    sip_password = sip_profile_p .. "password",
    sip_displayname = sip_profile_p .. "display_name",
    sip_state = sip_net_p .. "primary_proxy",
    sip_registrar = sip_net_p .. "primary_registrar",
    sip_domain = sip_net_p .. "domain_name",
}

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

local function validateNonspaceString(value, object, key)
    if value == "" then
        return nil, T"Please set value."
    end
    if find(format("%s", value), "%s") then
        return nil, T"Invalid value, space not allowed"
    end
    return true
end

local function getSipEnabled(value, object, key)
    return object["sip_enabled"] == "1"
end

local function clearParam(value, object, key)
    object[key] = nil
    if key == "sip_number" then
        object["sip_username"] = object[key]
        object["sip_displayname"] = object[key]
    end
    return true
end

local function getSipHost(value, object, key)
    if not object["isp"] then
        object[key] = nil
        return true
    end
    if object["isp"] == "Internode" then
        object["sip_state"] = "sip.internode.on.net"
        object["sip_registrar"] = object["sip_state"]
        object["sip_domain"] = object["sip_state"]
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

local function getValidateSipAccount(value, object, key)
    local ok, err = validateNonspaceString(value)
    if not ok then
        return ok, err
    end
    --if the uri/password are still the defaults,
    -- sip_profile_0 needs to be disabled to prevent the gateway try to register the sipserver with wrong info
    if match(value, "^profile") then
        object["sip_enabled"] = "0"
    end
    object["sip_username"] = object[key]
    object["sip_displayname"] = object[key]
    return true
end

local function getValidateSipPassword(value, object, key)
    local ok, err = validateNonspaceString(value)
    if not ok then
        return ok, err
    end
    --if the uri/password are still the defaults,
    -- sip_profile_0 needs to be disabled to prevent the gateway try to register the sipserver with wrong info
    if match(value, "^profile") then
        object["sip_enabled"] = "0"
    end
    if value == mask_password then
        object[key] = session:retrieve("sip_password")
    else
        session:store("sip_password", value)
    end
    return true
end

local mapValid = {
    sip_enabled = vB,
    sip_state = gCV(getSipEnabled, getSipHost,clearParam),
    sip_number = gCV(getSipEnabled, getValidateSipAccount, clearParam),
    sip_password = gCV(getSipEnabled, getValidateSipPassword, clearParam),
    sip_domain = gCV(getSipEnabled, getValidateDomain, clearParam),
    sip_username = function(value, object, key)
      return true
    end,
    sip_displayname = function(value, object, key)
      return true
    end,
    sip_registrar = function(value, object, key)
      return true
    end,
}

local content, helpmsg = wizard_helper.handleQuery(mapParams, mapValid)
content["sip_state"] = content["sip_state"]:match("sip%.([^%.]*)%.iinet.net.au") or "nsw"

local service_name = content["isp"] == "Internode" and "NodePhone" or "Netphone"

if ngx.req.get_method() == "GET" then
    session:store("sip_password", content["sip_password"])
elseif content["action"] == "SAVE" then
    session:store("sip_password", nil)
end

  ngx.print('\
<div class=\'wizard-card\'>\
    <fieldset>\
      ');  ngx.print("<legend></legend>"); ngx.print('\
      ');  ngx.print('<h4>' .. T("VoIP " .. service_name .. " Setup") .. '</h4>'); ngx.print('\
      ');  
        local info_attr = {
            alert = {
                class = "alert-info"
            },
         }
        local html = {}
        local textinfo = T("VoIP (" .. service_name .. ") is an optional phone service that runs over the internet. If you have purchased this service, enter your VoIP settings here. You'll find your settings in your VoIP activation email.")
        html[#html+1] = ui_helper.createAlertBlock(textinfo, info_attr)
        html[#html+1] = ui_helper.createMessages(message_helper.popMessages())
        local buttonClass = {
            controls =  { id = "no-voip" }
        }
        html[#html+1] = ui_helper.createButton("", T"I don't have VoIP", "icon-large", buttonClass)
        local hideClass = {
            group =  { class = "hide" }
        }
        html[#html+1] = ui_helper.createSwitch("", "sip_enabled", content["sip_enabled"], hideClass)
        html[#html+1] = ui_helper.createInputText(T"VoIP Phone number:", "sip_number", content["sip_number"], nil, helpmsg["sip_number"])
        html[#html+1] = ui_helper.createInputPassword(T"VoIP Password:", "sip_password", content["sip_password"],nil, helpmsg["sip_password"])
        if content["isp"] ~= "Internode" then
            html[#html+1] = ui_helper.createInputSelect(T"State/Territory:", "sip_state", state_t, content["sip_state"], helpmsg["sip_state"])
        end
        ngx.print(html)
        ngx.print('\
    </fieldset>\
</div>\
');  if content["sip_enabled"] == "1" then   ngx.print('\
<div class=\'wizard-confirm\'>\
    <fieldset>\
      ');  
        local html = {}
        html[#html+1] = ui_helper.createLabel(T"VoIP Phone number: ", content["sip_number"])
        html[#html+1] = ui_helper.createLabel(T"VoIP Password: ", mask_password)
        if content["isp"] ~= "Internode" then
            html[#html+1] = ui_helper.createLabel(T"State/Territory: ", string.upper(content["sip_state"]))
        end
        ngx.print(html)
        ngx.print('\
    </fieldset>\
</div>\
');  end   ngx.print('\
<script>\
  $("#no-voip").click(function(){\
     $(\'input[name="sip_enabled"]\').val("0");\
     tch.nextWizardCard(1);\
  });\
  $("#wizard-next").click(function(){\
     if ($("#no-voip").is(":visible")) {\
        $(\'input[name="sip_enabled"]\').val("1");\
     };\
  });\
</script>\
');  end   ngx.print('\
'); 