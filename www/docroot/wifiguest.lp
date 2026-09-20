<%
local lp = require("web.lp")
lp.setpath("/www/snippets/")
lp.include("header.lp")
lp.include("navbar.lp")
lp.include("menubar.lp")
lp.include("message.lp")
%>

<%
local istainted = string.istainted
local untaint_mt = require("web.taint").untaint_mt
local setmetatable = setmetatable

-- Localization
gettext.textdomain('webui-telstra')

-- Process POST query

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local pairs = pairs
local floor = math.floor
local format = string.format

local getargs = ngx.req.get_uri_args()
local radio, wl, ap

if getargs.guest == "2g_1" then
    radio = "radio_2G"
    wl = "wl0_1"
    ap = "ap1"
elseif getargs.guest == "5g_1" then
    radio = "radio_5G"
    wl = "wl1_1"
    ap = "ap3"
end

local radiop = "uci.wireless.wifi-device.@" .. radio .. "."
local wlp = "uci.wireless.wifi-iface.@" .. wl .. "."
local app = "uci.wireless.wifi-ap.@" .. ap .. "."

-- UCI parameters list
local mapParams = {
    --interface_enabled = wlp .. "state",
    --standard = radio .. "standard",
    --channelconf= radiop .. "channel",
    channelwidth = radiop .. "channelwidth",
    ap_enabled = app .. "state",
    ssid = wlp .. "ssid",
    security = app .. "security_mode",
    wep_key = app .. "wep_key",
    wpa_psk = app .. "wpa_psk_key",
}

local secmodes
if getargs.guest == "2g_1" or getargs.guest == "2g_2" then
    secmodes = {
        { "none", T"None"},
        { "wep", T"WEP"},
        { "wpa2-psk", T"WPA2 PSK"},
        { "wpa-wpa2-psk", T"WPA+WPA2 PSK"},
    }
else
    -- do NOT show wep in 5G wifi
    secmodes = {
        { "none", T"None"},
        { "wpa2-psk", T"WPA2 PSK"},
        { "wpa-wpa2-psk", T"WPA+WPA2 PSK"},
    }
end

-- Shortcuts to validation helpers to make lines shorter
local gVIPIL = post_helper.getValidationIfPropInList
local gVIES = post_helper.getValidateInEnumSelect
local gVSL = post_helper.getValidateStringLength
local vB = post_helper.validateBoolean
local vNES = post_helper.validateNonEmptyString
local gVCS = post_helper.getValidateCheckboxSwitch()
local vPSK = post_helper.validatePSK
local gVSLIR = post_helper.getValidateStringLengthInRange
local vWEP = post_helper.validateWEP

local mapValid = {
    --interface_enabled = vB,
    ap_enabled = gVCS,
    security = gVIES(secmodes),
    ssid = gVSLIR(1,32),
    wep_key = gVIPIL(vWEP,"security", {"wep"}),
    wpa_psk = gVIPIL(vPSK,"security", {"wpa-psk", "wpa2-psk", "wpa-wpa2-psk"}),
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
-- End of parameters saving / loading

-- Radio data
local radioData = proxy.get("rpc.wireless.radio.@".. radio .. ".")
post_helper.mergeTables(content, radioData)

-- If phy_rate is nil we need to set it ot 0 for division
content["phy_rate"] = content["phy_rate"] or 0

-- Mac Address
content["macaddress"] = proxy.get("sys.class.net.@" .. wl .. ".address")[1].value

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end

%>

<div class="container toplevel">
    <% lp.include("tabs-wifi.lp") %>
    <div class="row">
        <div class="span11">

<form class="form-horizontal" method="post" action="<%= uri %>">
<%
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
%>
<%
local content_radio = {
  state = radiop .. "state",
}
content_helper.getExactContent(content_radio)
%>

<fieldset>
<legend><%= T"Wi-Fi Radio" %></legend>

<%
html = {}
-- Switch that shows if the Wifi interface is enabled or not
html[#html + 1] = ui_helper.createCheckboxSwitch(T"Enabled", "interface_enabled", content_radio["state"], { input = { disabled = "disabled" }})
ngx.print(html)
%>
</fieldset>

<fieldset>
<legend><%= T"Wi-Fi Channel" %></legend>

<%
local html = {}

-- Label that shows the MAC address of the Wifi interface
html[#html + 1] = ui_helper.createLabel(T"MAC Address", content["macaddress"])

--html[#html + 1] = ui_helper.createLabel(T"Standard", content["standard"])

-- Current speed of the Wifi interface
html[#html + 1] = ui_helper.createLabel(T"Speed", content["phy_rate"] / 1000 .. "Mbps")

html[#html + 1] = ui_helper.createLabel(T"Current Channel", content["channel"])

html[#html + 1] = ui_helper.createLabel(T"Channel Width", content["channelwidth"])

ngx.print(html)
%>
</fieldset>

<fieldset>
<legend><%= T"Wi-Fi Network" %></legend>

<%
html = {}

--when radio is off, AP shall be off and button shall be greyed out.
local default_ap_enabled = "0"
local ap_enable_class = {
    input = {
        class = "monitor-changes",
        disabled = "disabled"
    },
}


--when radio is on, ap enabled button is active
if content_radio["state"] == "1" then
  default_ap_enabled = content["ap_enabled"]
  ap_enable_class["input"]["disabled"] = nil
end

html[#html + 1] = ui_helper.createCheckboxSwitch(T"Enabled", "ap_enabled", default_ap_enabled, ap_enable_class)

-- Show the SSID
local ssidclass = {
    input = {
        pattern= "[!-~][ -~]{0,30}[!-~]",
        maxlength= "32",
        class= "span4",
    }
}

--when AP is off, ssid input for AP shall be greyed out.
if default_ap_enabled == "0" then
  ssidclass["input"]["disabled"] = "disabled"
end

html[#html + 1] = ui_helper.createInputText(T"Network Name", "ssid", content["ssid"], ssidclass, helpmsg["ssid"])

local security_warning = {
    alert = {
        class = "alert-error monitor-security monitor-none"
    },
}
html[#html + 1] = ui_helper.createAlertBlock(T"Security for this wireless network is disabled, anybody can connect or listen to it", security_warning)

-- Select the security mode to use
local secattributes = {
    group = {
        class = "",
    },
    select = {
        class = "monitor-changes"
    }
}

--when radio is off, AP shall be off and select shall be greyed out.
if default_ap_enabled == "0" then
  secattributes["select"]["disabled"] = "1"
end

html[#html + 1] = ui_helper.createInputSelect(T"Security Mode", "security", secmodes, content["security"], secattributes)

local wepclass = {
    group = {
        class ="monitor-security monitor-wep",
    },
    input = {
        class= "span4",
    }
}
local pskclass = {
    group = {
        class ="monitor-security monitor-wpa-psk monitor-wpa2-psk monitor-wpa-wpa2-psk",
    },
    input = {
        class= "span4",
    }
}

--when AP is off, AP text input shall be greyed out.
if default_ap_enabled == "0" then
  wepclass["input"]["disabled"] = "disabled"
  pskclass["input"]["disabled"] = "disabled"
end

html[#html + 1] = ui_helper.createInputText(T"WEP Key", "wep_key", content["wep_key"], wepclass, helpmsg["wep_key"])
html[#html + 1] = ui_helper.createInputText(T"Network Key", "wpa_psk", content["wpa_psk"], pskclass, helpmsg["wpa_psk"])


ngx.print(html)
%>
</fieldset>
</form>

<%
if content_radio["state"] == "1" then
  lp.include("save.lp")
end
%>

</div>
</div>
</div>


<%
lp.include("networkmap.lp")
lp.include("footer.lp")
%>
