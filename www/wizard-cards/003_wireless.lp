<%
-- Enable localization
gettext.textdomain('webui-wizard')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local wizard_helper = require("wizard")
local proxy = require("datamodel")
local post_helper = require("web.post_helper")
local gVSLIR = post_helper.getValidateStringLengthInRange
local gVIES = post_helper.getValidateInEnumSelect
local gVIPIL = post_helper.getValidationIfPropInList
local vPSK = post_helper.validatePSK
local format = string.format

local path_ap_security = "rpc.wireless.ap.@ap0.security."
local supported_modes_data  = proxy.get(path_ap_security .. "supported_modes")
local supported_modes = format("%s", supported_modes_data and supported_modes_data[1] and supported_modes_data[1].value or "")

local secmodes = {}

local path_ap_5G_security = "rpc.wireless.ap.@ap1.security."
local supported_5G_modes_data  = proxy.get(path_ap_5G_security .. "supported_modes")
local supported_modes_5G = format("%s", supported_5G_modes_data and supported_5G_modes_data[1] and supported_5G_modes_data[1].value or "")
local secmodes_5G = {}

local secmodes_matched = {
  ["none"] = T"none",
  ["wpa2-psk"] = T"WPA2-PSK",
  ["wpa-wpa2-psk"] =  T"WPA+WPA2 PSK",
}

for mode in supported_modes:gmatch("[^%s]+") do
  if secmodes_matched[mode] then
    secmodes[#secmodes+1] = { mode, secmodes_matched[mode] }
  end
end

for mode in supported_modes_5G:gmatch("[^%s]+") do
  if secmodes_matched[mode] then
    secmodes_5G[#secmodes_5G+1] = { mode, secmodes_matched[mode] }
  end
end

local function validateSecurityMode(value, object, key)
    -- my republic requires security type not changable by user
    object["security"] = "wpa-wpa2-psk"
    object["security_5G"] = "wpa-wpa2-psk"
    return true
end

local mapParams = {
  ap_enabled = "rpc.wireless.ap.@ap0.admin_state",
  ssid = "rpc.wireless.ssid.@wl0.ssid",
  ap_5G_enabled = "rpc.wireless.ap.@ap1.admin_state",
  ssid_5G = "rpc.wireless.ssid.@wl1.ssid",
  security = path_ap_security .. "mode",
  wpa_psk = path_ap_security .. "wpa_psk_passphrase",
  security_5G = path_ap_5G_security .. "mode",
  wpa_psk_5G = path_ap_5G_security .. "wpa_psk_passphrase",
}

local mapValid = {
  ap_enabled = vB,
  ssid = gVSLIR(1,32),
  ap_5G_enabled = vB,
  ssid_5G = gVSLIR(1,32),
  security = validateSecurityMode,
  wpa_psk = gVIPIL(vPSK,"security", {"wpa-psk", "wpa2-psk", "wpa-wpa2-psk"}),
  security_5G = validateSecurityMode,
  wpa_psk_5G = gVIPIL(vPSK,"security", {"wpa-psk", "wpa2-psk", "wpa-wpa2-psk"}),
}

local content, helpmsg = wizard_helper.handleQuery(mapParams, mapValid)

local bool2on = {
  ["1"] = "On",
  ["0"] = "Off"
}

local bool2enable = {
  ["1"] = "Enabled",
  ["0"] = "Disabled"
}
%>
<div class='wizard-card'>
    <fieldset>
      <%="<legend>" .. T"Step 3 of 5" .. "</legend>"%>
      <%= "<h4>" .. T"WiFi Setup " .. "</h4>"%>
      <%
        local html = {}
        local info_attr = {
            alert = {
                class = "alert-info"
            },
         }
        html[#html+1] = ui_helper.createAlertBlock(T"Your modem already has a unique WiFi network set up by default. You can change the broadcast name here if desired, or turn off WiFi completely. <br /> Security Key is already set-up with your Router, however you can change that key here if desired. To connect to the Router via WiFi you will need to enter the Security Key into your device.", info_attr)
        html[#html+1] = ui_helper.createMessages(message_helper.popMessages())
        html[#html+1] = ui_helper.createSwitch(T"Wireless 2.4GHz (WiFi)", "ap_enabled", content["ap_enabled"],nil , helpmsg["ap_enabled"])
        -- Show the SSID
        local ssidclass = {
            input = {
                pattern= "[!-~][ -~]{0,30}[!-~]",
                maxlength= "32",
            }
        }
        html[#html+1] = ui_helper.createInputText(T"2.4GHz SSID Name", "ssid", content["ssid"], ssidclass, helpmsg["ssid"])
        html[#html+1] = ui_helper.createMessages(message_helper.popMessages())
        -- Select the security mode to use
        local secattributes = {
            group = {
                class = "hide"
            },
            select = {
                class = "monitor-changes"
            },
        }
        html[#html+1] = ui_helper.createInputSelect(T"2.4G Security Key Type", "security", secmodes, content["security"], secattributes)
        local pskclass = {
            group = {
                class ="monitor-security monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk",
            },
        }
        html[#html+1] = ui_helper.createInputText(T"2.4GHz Security Key", "wpa_psk", content["wpa_psk"], pskclass, helpmsg["wpa_psk"])
        html[#html+1] = ui_helper.createSwitch(T"Wireless 5GHz (WiFi)", "ap_5G_enabled", content["ap_5G_enabled"], nil, helpmsg["ap_5G_enabled"])
        html[#html+1] = ui_helper.createInputText(T"5GHz SSID Name", "ssid_5G", content["ssid_5G"], ssidclass, helpmsg["ssid_5G"])
        html[#html+1] = ui_helper.createMessages(message_helper.popMessages())
        -- Select the security mode to use
        local secattributes_5G = {
            group = {
                class = "hide"
            },
            select = {
                class = "monitor-changes"
            }
        }
        html[#html+1] = ui_helper.createInputSelect(T"5GHz Security Key Type", "security_5G", secmodes_5G, content["security_5G"], secattributes_5G)
        local pskclass_5G = {
            group = {
                class ="monitor-security_5G monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk",
            },
        }
        html[#html+1] = ui_helper.createInputText(T"5GHz Security Key", "wpa_psk_5G", content["wpa_psk_5G"], pskclass_5G, helpmsg["wpa_psk_5G"])
        ngx.print(html)
      %>
    </fieldset>
</div>
<div class='wizard-confirm'>
    <fieldset>
      <%
        local html = {}
        html[#html+1] = ui_helper.createLabel(T"Wireless 2.4GHz (WiFi)", bool2on[format("%s",content["ap_enabled"])])
        html[#html+1] = ui_helper.createLabel(T"2.4GHz SSID Name", content["ssid"])
        html[#html+1] = ui_helper.createLabel(T"2.4GHz Security Key", content["wpa_psk"])

        html[#html+1] = ui_helper.createLabel(T"Wireless 5GHz (WiFi)", bool2on[format("%s",content["ap_5G_enabled"])])
        html[#html+1] = ui_helper.createLabel(T"5GHz SSID Name", content["ssid_5G"])
        html[#html+1] = ui_helper.createLabel(T"5GHz Security Key", content["wpa_psk_5G"])
        ngx.print(html)
      %>
    </fieldset>
</div>
