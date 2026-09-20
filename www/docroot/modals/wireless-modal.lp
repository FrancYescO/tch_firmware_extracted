<%
local istainted = string.istainted
local untaint_mt = require("web.taint").untaint_mt
local setmetatable = setmetatable
local untaint = string.untaint

-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local ajax_helper = require("web.ajax_helper")
local pairs = pairs
local floor = math.floor
local match, format, gsub  = string.match, string.format, string.gsub

local mapMnemoic = {
					hardware_version = "uci.env.rip.board_mnemonic",
					}
content_helper.getExactContent(mapMnemoic)


-- Take the input options for a listbox, the value and return the associated text
local listboxToText = function(options, value)
    for i,v in ipairs(options) do
        if v[1] == value then
           return v[2]
        end
    end
    return value
end

local getargs = ngx.req.get_uri_args()
local getradio = getargs.radio
local getiface = getargs.iface

local curradio = "radio_2G"
local curiface = "wl0"
local curap = "ap0"
local isguest = "0"
local isremman = "0" -- AP remotely managed, like a TG233 DANT-5 board in AP mode.
local radio2iface = {}

local radios = {}
for i,v in ipairs(proxy.getPN("rpc.wireless.radio.", true)) do
    local radio = match(v.path, "rpc%.wireless%.radio%.@([^%.]+)%.")
    if radio then
        radios[#radios+1] = radio
        if radio == getradio then
            curradio = radio
        end
    end
end
table.sort(radios)

local piface = "rpc.wireless.ssid."
local awls = content_helper.convertResultToObject(piface .. "@.", proxy.get(piface))
local wls = {}
for i,v in ipairs(awls) do
--    if v.lan == "1" then
        wls[#wls+1] = {
            radio = v.radio,
            ssid = v.ssid,
            iface = v.paramindex
        }
        if v.paramindex == getiface then
            curiface = v.paramindex
        end
        -- For each radio, we store the "shortest" iface name (that should be the main SSID)
        if not radio2iface[v.radio] or #v.paramindex < #radio2iface[v.radio] then
            radio2iface[v.radio] = v.paramindex
        end
--    end
end
table.sort(wls, function(a,b)
    if a.radio == b.radio then
        return a.iface < b.iface
    else
        return a.radio < b.radio
    end
end)

local pap = "rpc.wireless.ap."
local aap = content_helper.convertResultToObject(pap .. "@.", proxy.get(pap))
for i,v in ipairs(aap) do
    if v.ssid == curiface then
        curap = v.paramindex
        isguest = v.ap_isolation
    end
end

local radioData = setmetatable({}, untaint_mt)
-- Radio data
for _,v in ipairs(radios) do
    local res = {}
    local rdata = proxy.get("rpc.wireless.radio.@" .. v .. ".")
    post_helper.mergeTables(res, rdata);
    radioData[v] = res

end

local curband = radioData[curradio].supported_frequency_bands

if radioData[curradio].remotely_managed == "1" then
    isremman = "1"
end

function get_acl_whitelist()

	local acl_columns = {
	  {
		header = T"MAC Address",
		name = "acl_macaddress",
		param = "value",
		type = "text",
		attr = { input = { class = "span2", maxlength = "17" } },
	  }
	}
	local macvalid = {
		acl_macaddress = vSIM,
	}
	local acl_whitelist_options = {
		tableid = "acl_whitelist",
		basepath = "uci.wireless.wifi-ap.@" .. curap .. ".acl_accept_list.@.",
		createMsg = T"Add new MAC address",
	}
	local acl_whitelist_data, acl_whitelist_helpmsg = post_helper.handleTableQuery(acl_columns, acl_whitelist_options, nil, nil, macvalid)
	local whitelistclass = {
		group = {
		  class = "monitor-acl_mode monitor-lock monitor-register",
		  id = "whitelist_div"
		}
	}
	if #acl_whitelist_data < 1  then
		local  colheader = T"MAC Address list is empty"
		colheader = format("%s%s%s", "<span style=\"font-weight:normal;\">",colheader,"</span>")
		acl_columns[1].header = colheader
	end

	return ui_helper.createTable(acl_columns, acl_whitelist_data, acl_whitelist_options, whitelistclass, acl_whitelist_helpmsg)
end

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action=="GET_ACL_WHITE" then
	ngx.print(get_acl_whitelist())
	ngx.exit(ngx.HTTP_OK )
end

local pathradio = format("rpc.wireless.radio.@%s.", curradio)
local pathiface = format("rpc.wireless.ssid.@%s.", curiface)
local pathap = format("rpc.wireless.ap.@%s.", curap)
local pathradius = format("uci.wireless.wifi-radius-server.@%s_", curap)

ajax_helper.handleAjaxQuery({
    phy_rate = "rpc.wireless.radio.@" .. curradio .. ".phy_rate",
    channel = "rpc.wireless.radio.@" .. curradio .. ".channel",
    }, function(content)
        content["phy_rate"] = content["phy_rate"] / 1000 .. "Mbps"
    end)

local wpshandler_data = proxy.get("uci.button.button.@wps.handler")
-- Process POST query
-- UCI parameters list
local mapParams = {
    ap_enabled = pathap .. "admin_state",
    ssid = pathiface .. "ssid",
    ap_broadcast_ssid = pathap .. "public",
    security = pathap .. "security.mode",
    wep_key = pathap .. "security.wep_key",
    wpa_psk = pathap .. "security.wpa_psk_passphrase",
    wps_enabled = pathap .. "wps.admin_state",
    wps_ap_pin_code = pathap .. "wps.ap_pin",
    acl_mode = pathap .. "acl.mode",
    wps_button_handler = wpshandler_data and "uci.button.button.@wps.handler",
}

-- Only include radio configuration in UI if not in guest/hotspot mode
if isguest ~= "1" then
    local addRadioParams = {
        interface_enabled = pathradio .. "admin_state",
        standard = pathradio .. "standard",
        channelconf = pathradio .. "requested_channel",
        channelwidth = pathradio .. "requested_channel_width",
        sgi = pathradio .. "sgi",
        cdd = pathradio .. "cdd",
        stbc = pathradio .. "stbc",
    }
    for k,v in pairs(addRadioParams) do
        mapParams[k] = v
    end
    -- Bug fix for NG-12032 GUI wireless enable/disable not working properly
    for k, v in pairs(radios) do
      if v~=curradio then
        mapParams["interface_enabled_" .. v] = "rpc.wireless.radio.@" .. v .. ".admin_state"
      end
    end
end
-- Only include radius configuration in UI if not in guest/hotspot mode or not remotely managed
if isguest ~= "1" and isremman ~= "1" then
    local addRadiusParams = {
        radius_authent_state = pathradius .. "auth0.state",
        radius_authent_ip = pathradius .. "auth0.ip",
        radius_authent_port = pathradius .. "auth0.port",
        radius_authent_secret = pathradius .. "auth0.secret",
        radius_account_state = pathradius .. "acct0.state",
        radius_account_ip = pathradius .. "acct0.ip",
        radius_account_port = pathradius .. "acct0.port",
        radius_account_secret = pathradius .. "acct0.secret",
    }
    for k,v in pairs(addRadiusParams) do
        mapParams[k] = v
    end
end

local output_change_allowed = 0
--[[
-- Only include outputpower if changing the power is allowed
-- It won't be possible to touch this parameter unless this is allowed
local output_change_allowed = proxy.get(pathradio .. "tx_power_overrule_reg")[1].value
if output_change_allowed == "1" then
    mapParams["outputpower"] = pathradio .. "tx_power_adjust"
end
]]

-- We're defining the listbox enums here to be able to use them to validate the input
-- Listbox that shows the supported WiFi standards
local wifi_standard_24GHz = {
      { "bg", T'802.11b/g'},
      { "bgn", T'802.11b/g/n'},
}

local wifi_standard_5GHz = {
    ["an"]= T'802.11a/n',
    ["anac"]= T'802.11a/n/ac',
}
local wifiStandard = {
  standard = "uci.wireless.wifi-device.@radio_5G.standard"
}

local wifi_standard={}
if radioData[curradio].supported_frequency_bands == "5GHz" then
  content_helper.getExactContent(wifiStandard)
  if wifiStandard.standard and wifiStandard.standard ~= "" then
    wifi_standard[1] = {wifiStandard.standard,wifi_standard_5GHz[untaint(wifiStandard.standard)]}
  else
    wifi_standard[1] = {"",""}
  end
else
    wifi_standard = wifi_standard_24GHz
end

-- Choose Wifi power
local wifipower = {
    {"-3", T"100%"},
    {"-2", T"125%"},
    {"-1", T"160%"},
    {"0", T"200%"},
}

local cw_20 = {
    {"20MHz", T"20MHz"},
}
local cw_40 = {
    {"20MHz", T"20MHz"},
    {"auto", T"Auto (20/40MHz)"},
}
local cw_80 = {
    {"20MHz", T"20MHz"},
    {"20/40MHz", T"20/40MHz"},
    {"auto", T"Auto (20/40/80MHz)"},
}

local cw = {
  ["bg"] = "channelwidth20",
  ["bgn"] = "channelwidth40",
  ["an"] = "channelwidth40",
  ["anac"] = "channelwidth80",
}

local cwmaps = {
    ["channelwidth20"] = cw_20,
    ["channelwidth40"] = cw_40,
    ["channelwidth80"] = cw_80,
}
local channelwidth = cwmaps[cw[untaint(radioData[curradio].supported_standards)]]

local supported_modes_data  = proxy.get("rpc.wireless.ap.@" .. curap .. ".security.supported_modes")
local supported_modes = string.format("%s", supported_modes_data and supported_modes_data[1] and supported_modes_data[1].value or "")
local secmodes = {}
local secmodes_matched = {
     ["none"] = T"None",
     ["wpa2-psk"] = T"WPA2 PSK",
     ["wpa-wpa2-psk"] =  T"WPA+WPA2 PSK",
     ["wpa-wpa2"] =  T"WPA+WPA2",
}
supported_modes:gsub("[^%s]+", function(c)
    if secmodes_matched[c] then
        secmodes[#secmodes+1] = { c, secmodes_matched[c] }
    else
        secmodes[#secmodes+1] = { c, T(string.upper(c)) }
    end
end)
-- remove radius modes if in guest ap page
if isguest == "1" then
    local num = #secmodes
    for i=num, 1, -1 do
        if secmodes[i][1] == "wpa2" or secmodes[i][1] == "wpa-wpa2" then
            table.remove(secmodes, i)
        end
    end
end

-- Listbox that shows the supported Access Control modes
local acl_modes = {
      { "disabled", T"Disabled" },
      { "unlock", T"Blacklist" },
      { "lock", T"Whitelist" },
--      { "register", T"Register" },
}

-- Shortcuts to validation helpers to make lines shorter
local gVIPIL = post_helper.getValidationIfPropInList
local gVIES = post_helper.getValidateInEnumSelect
local gVSL = post_helper.getValidateStringLength
local vB = post_helper.validateBoolean
local vNES = post_helper.validateNonEmptyString
local vSII = post_helper.validateStringIsIP
local vSIP = post_helper.validateStringIsPort
local vSIM = post_helper.validateStringIsMAC
local gOV = post_helper.getOptionalValidation
local gCV = post_helper.getConditionalValidation
local gAV = post_helper.getAndValidation
local vPSK = post_helper.validatePSK
local gVSLIR = post_helper.getValidateStringLengthInRange
local vWEP = post_helper.validateWEP
local vPIN = post_helper.validateWPSPIN
local wpa_list = {"wpa2", "wpa-wpa2"}
local VIPIL_IP = gVIPIL(vSII, "security", wpa_list)
local VIPIL_port = gVIPIL(vSIP, "security", wpa_list)

local function getValidateChannelWidth(channelwidth)
  return function(value, postdata, key)
    local success, msg = gVIES(channelwidth)
    if success then
      postdata["channelwidth"] = postdata[cw[untaint(postdata["standard"])]]
      return true
    else
      return nil, msg
    end
  end
end
---
-- Here we're adding logic to make sure that we set the state of the authent and accounting server
-- for radius to 0/1.
-- This is done by checking if we're in EAP mode (wpa2 or wpa-wpa2), and if so, setting the state
-- accordingly (we use the validation chain for that through the use of a condional check)
-- For accounting, we need to additionally check that the IP and port are non empty since they're
-- optional.
local radius_modes = setmetatable({
        ["wpa2"] = true,
        ["wpa-wpa2"] = true
    }, untaint_mt)
local radiusCond = function(value, object, key)
    return radius_modes[object["security"]], ""
end

local function checkIPandPort(value, object, key)
    local ip = object["radius_account_ip"]
    local port = object["radius_account_port"]
    if istainted(port) and istainted(ip) and #ip > 0 and #port > 0 then
        return true
    end
    return false, "IP or port is empty"
end

local function getReplaceValue(newval)
    return function(value, object, key)
        object[key] = newval
        return true
    end
end
-- End of code specific to Radius settings

-- Bug fix for NG-12032 GUI wireless enable/disable not working properly
-- if the post request is from the small card,
-- we need to set the admin state of the radios other than the current radio
local function getInterfaceEnabled2(value, object, key)
    if not object["fromModal"] then
       object[key] = object["interface_enabled"]
    else
       object[key] = nil
    end
    return true
end

local wps_button_handler = setmetatable({
        ["1"] = "wps_button_pressed.sh",
--        ["0"] = "acl_button_pressed.sh",
    }, untaint_mt)

local mapValid = {
    interface_enabled = vB,
    standard = gVIES(wifi_standard),
    sgi = gOV(vB),
    cdd = gOV(vB),
    stbc = gOV(vB),
    outputpower = gVIES(wifipower), -- if the parameter is not included, it does not matter, this validation function will never be called
    channelwidth20 = getValidateChannelWidth(cw_20),
    channelwidth40 = getValidateChannelWidth(cw_40),
    channelwidth80 = getValidateChannelWidth(cw_80),
    ap_enabled = vB,
    ssid = gVSLIR(1,32),
    wep_key = gVIPIL(vWEP,"security", {"wep"}),
    wpa_psk = gVIPIL(vPSK,"security", {"wpa-psk", "wpa2-psk", "wpa-wpa2-psk"}),
    wps_enabled = gOV(vB),
    acl_mode = gVIES(acl_modes),
    radius_authent_ip = VIPIL_IP,
    radius_account_ip = gOV(VIPIL_IP),
    radius_authent_secret = gVIPIL(vNES,"security", wpa_list),
    radius_account_secret = gVIPIL(vNES,"security", wpa_list),
    radius_authent_port = VIPIL_port,
    radius_account_port = gOV(VIPIL_port),
    radius_authent_state = gCV(radiusCond, getReplaceValue("1"), getReplaceValue("0")), -- we know that we're enforcing the server ip and port is there
    radius_account_state = gCV(gAV(radiusCond, checkIPandPort), getReplaceValue("1"), getReplaceValue("0")), -- if no server ip or port, don't set to 1
    wps_button_handler = function(val, object)
      object.wps_button_handler = wps_button_handler[object.wps_enabled]
      return true
    end,
}

-- Bug fix for NG-12032 GUI wireless enable/disable not working properly
for k, v in pairs(radios) do
  if v~=curradio then
    mapValid["interface_enabled_" .. v] = getInterfaceEnabled2
  end
end

if proxy.get(pathiface.."ssid")[1].value ~= "Telia wifi1x" then
	mapValid["security"] = gVIES(secmodes)
end



local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
-- End of parameters saving / loading

-- Support for device PIN code
content["wps_device_pin_code"] = ""

-- triggered only on a POST with action set wps_device_pin_code (button next to field should trigger that)
if ngx.req.get_method() == "POST" then
  if #wls > 1 then
    for _,v in ipairs(wls) do
      if v.iface == curiface then
        v.ssid = content["ssid"]
      end
    end
  end
    local args = ngx.req.get_post_args()
    local action = args["action"]
    local pin = args["wps_device_pin_code"]
    if action == "wps_device_pin_code" and content["wps_enabled"] == "1" then
        local res, help = vPIN(pin)
        content["wps_device_pin_code"] = pin

        if res then
            proxy.set("rpc.wireless.ap.@" .. curap .. ".wps.enrollee_pin",pin)

        else
            helpmsg["wps_device_pin_code"] = help
        end
    end
end
-- End of device PIN code support

-- triggered only on a POST with action set wps_pbc
if ngx.req.get_method() == "POST" then
    local args = ngx.req.get_post_args()
    local action = args["action"]
    if action == "wps_pbc" and content["wps_enabled"] == "1" then
        proxy.set("rpc.wireless.wps_button","1")
    end
end
-- End of WPS PBC code support

-- AP PIN code - read only
content["wps_ap_pin_code"] = proxy.get("rpc.wireless.ap.@" .. curap .. ".wps.ap_pin")[1].value

for k,v in pairs(radioData[curradio]) do
    -- Not replace the value that already exists
    if not content[k] then
        content[k] = v
    end
end

if isguest == "1" then
    local radioConf = {
        interface_enabled = pathradio .. "admin_state",
        standard = pathradio .. "standard",
        channelconf = pathradio .. "requested_channel",
        channelwidth = pathradio .. "requested_channel_width",
    }

    content_helper.getExactContent(radioConf)
    for k,v in pairs(radioConf) do
        content[k] = v
    end
end

-- Ensure Channel and Current channel are the same value after clicking Save
if content["channelconf"] ~= nil and content["channel"] ~= nil then
    if content["channelconf"] ~= "auto" then
        content["channel"] = content["channelconf"]
    end
end

-- Mac Address
content["macaddress"] = proxy.get("rpc.wireless.ssid.@" .. curiface .. ".mac_address")[1].value

local acl_columns = {
  {
    header = T"MAC Address",
    name = "acl_macaddress",
    param = "value",
    type = "text",
    attr = { input = { class = "span2", maxlength = "17" } },
  }
}

local macvalid = {
    acl_macaddress = vSIM,
}

local acl_blacklist_options = {
    tableid = "acl_blacklist",
    basepath = "uci.wireless.wifi-ap.@" .. curap .. ".acl_deny_list.@.",
    createMsg = T"Add new MAC address",
}
local acl_blacklist_data, acl_blacklist_helpmsg = post_helper.handleTableQuery(acl_columns, acl_blacklist_options, nil, nil, macvalid)

%>

<% ngx.print(ui_helper.createHeader(T"Wireless", true, false)) %>

<div class="modal-body update">
<form class="form-horizontal" method="post" action="<%= ngx.var.request_uri %>">
<%
-- Do not display the navlist on the list if only 1 SSID
if #wls > 1 then
%>
<div class="span2">
    <ul class="nav nav-list">
    <%
    html = {}
    local prevradio = ""
    for i,v in ipairs(wls) do
        if v.radio ~= prevradio then
            if radioData[v.radio].remotely_managed == "1"  and radioData[v.radio].integrated_ap ~= "1" then
                html[#html+1] = format('<li class="nav-header">%s %s</li>', T"External access points", radioData[v.radio].supported_frequency_bands)
            else
                html[#html+1] = format('<li class="nav-header">%s %s</li>', T"Access points", radioData[v.radio].supported_frequency_bands)
            end
            prevradio = v.radio
        end
        local active = ""
        if v.iface == curiface then
            active = "active"
        end
        local url = "modals/wireless-modal.lp?radio=" .. v.radio .. "&iface=" .. v.iface
	if not(v.ssid == "Telia wifi1x" and v.radio == "radio_5G") then
        	html[#html+1] = format('<li class="%s"><a href="#" data-remote="%s">%s</a></li>', active, url, v.ssid)
	end
    end
    ngx.print(html)
    %>
    </ul>
</div>
<div class="span6">
<%
end

ngx.print(ui_helper.createMessages(message_helper.popMessages()))
%>
<fieldset>
<legend><%= T"Interface" %></legend>

<%
    local html = {}
    local advanced = {
        group = {
            class = "advanced hide",
        }
    }

    -- In guest page, do not let the user change the configuration of the wifi radio. Only in main AP
    if isguest == "1" then
        -- Switch that shows if the Wifi interface is enabled or not
		if content["ssid"] ~= "Telia wifi1x" then
        	html[#html + 1] = ui_helper.createLabel(T"Frequency band", content["supported_frequency_bands"])
	        -- Label that shows the MAC address of the Wifi interface
    	    html[#html + 1] = ui_helper.createLabel(T"MAC address", content["macaddress"])
    	    if radioData[curradio].supported_frequency_bands == "5GHz" then
    	      html[#html + 1] = ui_helper.createLabel(T"Standard", listboxToText(wifi_standard, wifiStandard.standard), advanced)
    	    else
    	      html[#html + 1] = ui_helper.createLabel(T"Standard", listboxToText(wifi_standard, content["standard"]), advanced)
    	    end
    	    -- Current speed of the Wifi interface
    	    html[#html + 1] = ui_helper.createLabel(T"Speed", content["phy_rate"] / 1000 .. "Mbps", { span = {
    	        id = "phy_rate",
    	        ["data-ajaxrefresh"] = "5",
    	    }})
	
    	    html[#html + 1] = ui_helper.createLabel(T"Channel", content["channelconf"])
	
    	    -- Show which region is being used
    	    html[#html + 1] = ui_helper.createLabel(T"Region", content["country"], advanced)
    	    html[#html + 1] = ui_helper.createLabel(T"Current channel", content["channel"], { span = {
    	        id = "channel",
    	        ["data-ajaxrefresh"] = "10",
        }})

       	 	html[#html + 1] = ui_helper.createLabel(T"Channel width", listboxToText(channelwidth, content["channelwidth"]), advanced)
		else
			html[#html + 1] = ui_helper.createSwitch(T"Enabled", "ap_enabled", content["ap_enabled"])

		end  
	else
        -- Switch that shows if the Wifi interface is enabled or not
        html[#html + 1] = ui_helper.createSwitch(T"Enabled", "interface_enabled", content["interface_enabled"])
        html[#html + 1] = ui_helper.createLabel(T"Frequency band", content["supported_frequency_bands"])
        -- Label that shows the MAC address of the Wifi interface
        html[#html + 1] = ui_helper.createLabel(T"MAC address", content["macaddress"])

        -- Select the standard to use
        local stdattributes = {
            group = {
                class = "advanced hide",
            },
            select = {
                class = "monitor-changes"
            }
        }
        if radioData[curradio].supported_frequency_bands == "5GHz" then
          html[#html + 1] = ui_helper.createLabel(T"Standard", listboxToText(wifi_standard, wifiStandard.standard), stdattributes)
          stdattributes.select={class = "monitor-changes",style="display:none"}
          html[#html + 1] = ui_helper.createSimpleInputSelect("standard", wifi_standard, wifiStandard.standard,stdattributes)
        else
          html[#html + 1] = ui_helper.createInputSelect(T"Standard", "standard", wifi_standard, content["standard"], stdattributes)
        end
        -- Current speed of the Wifi interface
        html[#html + 1] = ui_helper.createLabel(T"Speed", content["phy_rate"] / 1000 .. "Mbps", { span = {
            id = "phy_rate",
            ["data-ajaxrefresh"] = "5",
        }})

        -- Choose which channel to use
        local allowed_channels = { {"auto", T"Auto"} }
        for i in string.gmatch(content["allowed_channels"], "%S+") do
            allowed_channels[#allowed_channels + 1] = {i, i}
        end
        html[#html + 1] = ui_helper.createInputSelect(T"Channel", "channelconf", allowed_channels, content["channelconf"])

        -- Show which region is being used
        html[#html + 1] = ui_helper.createLabel(T"Region", content["country"], advanced)
        html[#html + 1] = ui_helper.createLabel(T"Current channel", content["channel"], { span = {
            id = "channel",
            ["data-ajaxrefresh"] = "5",
        }})
        html[#html + 1] = '<div class = "advanced hide">'
        local cw20attributes  = {
            group = {
                class ="hide monitor-standard monitor-b monitor-bg",
            },
        }

        html[#html + 1] = ui_helper.createInputSelect(T"Channel Width", "channelwidth20", cw_20, content["channelwidth"], cw20attributes)

        local cw40attributes  = {
            group = {
                class ="hide monitor-standard monitor-bgn monitor-an",
            },
        }

        html[#html + 1] = ui_helper.createInputSelect(T"Channel Width", "channelwidth40", cw_40, content["channelwidth"], cw40attributes)

        local cw80attributes  = {
            group = {
                class ="hide monitor-standard monitor-anac",
            },
        }

        html[#html + 1] = ui_helper.createInputSelect(T"Channel Width", "channelwidth80", cw_80, content["channelwidth"], cw80attributes)
        html[#html + 1] = '</div>'
        -- html[#html + 1] = ui_helper.createSwitch("Frame bursting", "framebursting", content["framebursting"], advanced)
        html[#html + 1] = ui_helper.createSwitch(T"Short Guard Interval", "sgi", content["sgi"], advanced)
        if isremman  ~= "1" then
            html[#html + 1] = ui_helper.createSwitch(T"Cyclic-Delay Diversity", "cdd", content["cdd"], advanced)
            html[#html + 1] = ui_helper.createSwitch(T"Space Time Block Code", "stbc", content["stbc"], advanced)
        end
        if output_change_allowed == "1" then
            html[#html + 1] = ui_helper.createSliderSelect(T"Output power", "outputpower", wifipower, content["outputpower"], advanced)
        end
    end
    ngx.print(html)
%>
</fieldset>
<%
if content["ssid"] ~= "Telia wifi1x" then
%>
<fieldset>
<legend><%= T"Access Point" %></legend>
<%

    html = {}
    -- Show if the AP is enabled

	if curradio ~="radio_2G" and string.format("%s", mapMnemoic.hardware_version) =="VANT-W" then
	html[#html + 1] = '<div style="display:none">'
    html[#html + 1] = ui_helper.createSwitch(T"Enabled", "ap_enabled", content["ap_enabled"], advanced)
	html[#html + 1] = '</div>'
	else
	html[#html + 1] = ui_helper.createSwitch(T"Enabled", "ap_enabled", content["ap_enabled"], advanced)
	end

    -- Show the SSID
    local ssidclass = {
        input = {
            pattern= "[!-~][ -~]{0,30}[!-~]",
            maxlength= "32",
            class= "span4",
            }
    }
    html[#html + 1] = ui_helper.createInputText(T"SSID name", "ssid", content["ssid"], ssidclass, helpmsg["ssid"])

    local broadcastclass = {
        group = {
            class = "advanced hide",
        },
        input = {
            class = "monitor-changes"
        }
    }

    -- Should we broadcast the SSID
    html[#html + 1] = ui_helper.createSwitch(T"Broadcast SSID", "ap_broadcast_ssid", content["ap_broadcast_ssid"], broadcastclass)


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

    html[#html + 1] = ui_helper.createInputSelect(T"Security mode", "security", secmodes, content["security"], secattributes)

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
    html[#html + 1] = ui_helper.createInputText(T"WEP key", "wep_key", content["wep_key"], wepclass, helpmsg["wep_key"])
    html[#html + 1] = ui_helper.createInputText(T"Wireless Password", "wpa_psk", content["wpa_psk"], pskclass, helpmsg["wpa_psk"])

    if ( isguest ~= "1" and isremman  ~= "1") then
        local monitorradius = {
                class ="monitor-security monitor-wpa monitor-wpa2 monitor-wpa-wpa2",
        }
        local ipclass = {
                pattern="(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])",
        }
        local serverclass = {
            group = monitorradius,
            input = ipclass
        }
        local basicclass = {
            group = monitorradius,
        }
        html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server's IP", "radius_authent_ip", content["radius_authent_ip"], serverclass, helpmsg["radius_authent_ip"])
        html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server's port", "radius_authent_port", content["radius_authent_port"],basicclass, helpmsg["radius_authent_port"])
        html[#html + 1] = ui_helper.createInputText(T"Radius Authentication Server's secret", "radius_authent_secret", content["radius_authent_secret"],basicclass, helpmsg["radius_authent_secret"])
        html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server's IP", "radius_account_ip", content["radius_account_ip"], serverclass, helpmsg["radius_account_ip"])
        html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server's port", "radius_account_port", content["radius_account_port"],basicclass, helpmsg["radius_account_port"])
        html[#html + 1] = ui_helper.createInputText(T"Radius Accounting Server's secret", "radius_account_secret", content["radius_account_secret"],basicclass, helpmsg["radius_account_secret"])
    end

--Don't show wps for Guest
	
if isguest ~= "1"  then

    local wps_warning = {
        alert = {
            class = "alert-warning monitor-security monitor-wep monitor-wpa-psk monitor-ap_broadcast_ssid monitor-0 monitor-default-show"
        },
    }

    html[#html + 1] = ui_helper.createAlertBlock(T"WPS is automatically disabled if you choose WEP or WPA-only security or disable broadcast of the SSID", wps_warning)

    local wps_class = {
        group = {
            class = "monitor-security monitor-none monitor-wpa2-psk monitor-wpa-wpa2-psk monitor-ap_broadcast_ssid monitor-1"
        }
    }
    html[#html + 1] = ui_helper.createSwitch(T"WPS", "wps_enabled", content["wps_enabled"], wps_class)
    html[#html + 1] = ui_helper.createLabel(T"WPS AP PIN code", content["wps_ap_pin_code"], wps_class)

    wps_class["input"] = {
        class="no-save",
        ["data-for"] = "wps_device_pin_code",
    }
    wps_class["button"] = {
        ["data-name"] = "action",
        ["data-value"] = "wps_device_pin_code",
    }
    html[#html + 1] = ui_helper.createInputTextWithButton(T"WPS Device PIN code", "wps_device_pin_code", content["wps_device_pin_code"], T"Set PIN code", "icon-ok-sign" ,wps_class, helpmsg["wps_device_pin_code"])

    wps_class["button"] = {
        ["data-name"] = "action",
        ["data-value"] = "wps_pbc",
    }
    if isremman  ~= "1" then
        html[#html + 1] = ui_helper.createButton(T"WPS PBC", T"Trigger", "icon-refresh", wps_class)
    end
end

    ngx.print(html)
%>
    <input type="hidden" name="radius_authent_state" value="" >
    <input type="hidden" name="radius_account_state" value="" >


</fieldset>

<fieldset class="advanced hide">
<legend><%= T"Access Control List" %></legend>
<%
    html = {}

    local aclmodeclass = {
        select = {
          class = "monitor-changes"
        }
    }
    html[#html + 1] = ui_helper.createInputSelect(T"ACL mode", "acl_mode", acl_modes, content["acl_mode"], aclmodeclass)

    html[#html + 1] = get_acl_whitelist()

    local blacklistclass = {
        group = {
          class = "monitor-acl_mode monitor-unlock"
        }
    }
    if #acl_blacklist_data < 1  then
      local  colheader = T"MAC Address list is empty"
      colheader = format("%s%s%s", "<span style=\"font-weight:normal;\">",colheader,"</span>")
      acl_columns[1].header = colheader
    else
      acl_columns[1].header = T"MAC Address"
    end
    html[#html + 1] = ui_helper.createTable(acl_columns, acl_blacklist_data, acl_blacklist_options, blacklistclass, acl_blacklist_helpmsg)

    ngx.print(html)
%>
</fieldset>

<fieldset>
<legend><%= T"QR Code" %></legend>
<%= format([[
                    <center>
                        <div class="btn custom-handler" data-remote="modals/wireless-qrcode-modal.lp?iface=%s&ap=%s" data-toggle="modal">
                            %s
                        </div>
                    </center>
                  ]], curiface, curap, T"Generate QRCode")
%>
</fieldset>

<%
end
-- Do not display the navlist on the list if only 1 SSID
if #wls > 1 then
%>
</div>
<%
end
%>
</form>
</div>

<% ngx.print(ui_helper.createFooter())
if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action=="SAVE" and  ngx.req.get_post_args().acl_mode =="lock" then %>
<script>
	var params = [ {name : "action", value : "GET_ACL_WHITE"},{name : "CSRFtoken", value : $("meta[name=CSRFtoken]").attr("content")}];
	$.post("/modals/wireless-modal.lp", params, function (data){
		$('#whitelist_div').replaceWith(data);
	});
</script>
<%end%>
<%
if curradio ~="radio_2G" and string.format("%s", mapMnemoic.hardware_version) =="VANT-W" then
%>
<script>
$(document).ready(function() {
 $('.switch').click(function(){
	var b = $(this).find("input[name='interface_enabled']").attr("value")
	if(b == "0"){
	$('.switch').find("input[name='ap_enabled']").attr("value", "1")
	}
	});
});
</script>
<%
end
%>