<%
local istainted = string.istainted
local untaint_mt = require("web.taint").untaint_mt
local setmetatable = setmetatable
local untaint = string.untaint
local session = ngx.ctx.session

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
local getWifiAnalyzer = getargs.isWifiAnalyzer

local curradio = "radio_2G"
local curiface = "wl0"
local curap = "ap0"
local isguest = "0"
local isremman = "0" -- AP remotely managed, like a TG233 DANT-5 board in AP mode.
local radio2iface = {}

-- Return the acs data for selected radio to generate Analyzer graph

local function getAcsData(cradio)
  local json = require("dkjson")
  local bsslistData = proxy.get("rpc.wireless.bssid.@" .. cradio .. ".bsslist.")
  bsslistData = content_helper.convertResultToObject("rpc.wireless.bssid.@" .. cradio .. ".bsslist.",bsslistData)
  local buffer = {}
  local success = json.encode (bsslistData, { indent = false, buffer = buffer})
  if success then
    ngx.header.content_type = "application/json"
    ngx.print(buffer)
    ngx.exit(ngx.HTTP_OK)
  end
end

if ngx.req.get_method() == "POST" and  ngx.req.get_post_args().action =="rescan" then
   local cradio = ngx.req.get_post_args().curradio
   proxy.set("rpc.wireless.radio.@" .. cradio .. ".acs.rescan","1")
   getAcsData(cradio)
elseif getWifiAnalyzer and getargs.getAcsData then
   getAcsData(getradio)
end

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

ajax_helper.handleAjaxQuery({
    phy_rate = "rpc.wireless.radio.@" .. curradio .. ".phy_rate",
    channel = "rpc.wireless.radio.@" .. curradio .. ".channel",
    }, function(content)
        content["phy_rate"] = content["phy_rate"] / 1000 .. "Mbps"
    end)

local ap_paths={true}
for i,v in ipairs(proxy.getPN("rpc.wireless.ap.", true)) do
  ap_paths[i] = v.path.."ssid"
end

local wl_list = proxy.get(unpack(ap_paths))
local wls = {}
local cur_ssid
for i,v in ipairs(wl_list) do
  local path = "rpc.wireless.ssid.@" .. v.value
  local values = proxy.get(path .. ".radio" , path .. ".ssid",path .. ".lan")
  if values ~= nil then --and values[3].value == "1"
    wls[#wls+1] = {
            radio = values[1].value,
            ssid = values[2].value,
            iface = v.value
        }
    if (v.value == getiface) or (not getiface and v.value == curiface)then
        curiface = v.value
        curap = match(v.path, "rpc%.wireless%.ap%.@([^%.]+)%.")
        isguest = proxy.get(v.path .. "ap_isolation")[1].value
        cur_ssid = values[2].value
    end
 end
end
table.sort(wls, function(a,b)
    if a.radio == b.radio then
        return a.iface < b.iface
    else
        return a.radio < b.radio
    end
end)

-- The function can be reused to load the ACL mac list by ajax and normal request
-- Normal request means - Adding, Editing and Deleting the ACL mac address entries by normal POST request
function loadAclList(aclmode)
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
    acl_macaddress = post_helper.validateStringIsMAC,
  }
  local acl_whitelist_options = {
    tableid = "acl_whitelist",
    basepath = format("uci.wireless.wifi-ap.@%s.acl_accept_list.@.",curap),
    createMsg = T"Add new MAC address",
  }
  local acl_whitelist_data, acl_whitelist_helpmsg = post_helper.handleTableQuery(acl_columns, acl_whitelist_options, nil, nil, macvalid)

  local acl_blacklist_options = {
    tableid = "acl_blacklist",
    basepath = format("uci.wireless.wifi-ap.@%s.acl_deny_list.@.",curap),
    createMsg = T"Add new MAC address",
  }
  local acl_blacklist_data, acl_blacklist_helpmsg = post_helper.handleTableQuery(acl_columns, acl_blacklist_options, nil, nil, macvalid)

  local html={}
  local whitelistclass = {
    group = {
      class = "monitor-acl_mode monitor-lock monitor-register",
    }
  }
  if aclmode == "unlock" or aclmode == "disabled" then
    whitelistclass["group"].style = "display:none;"
  end
  if #acl_whitelist_data < 1  then
    whitelistclass ["span"] = {id = "Address_list_Whitelistclass"}
    html[#html+1] = ui_helper.createLabel("", T"MAC Address list is empty", whitelistclass, nil)
    acl_columns[1].header = "<span></span>"
  end
  html[#html+1] = ui_helper.createTable(acl_columns, acl_whitelist_data, acl_whitelist_options, whitelistclass, acl_whitelist_helpmsg)

  local blacklistclass = {
        group = {
          class = "monitor-acl_mode monitor-unlock"
        }
    }
  if #acl_blacklist_data < 1  then
    blacklistclass ["span"] = {id = "Address_list_Blacklistclass"}
    html[#html+1] = ui_helper.createLabel("", T"MAC Address list is empty", blacklistclass, nil)
    acl_columns[1].header = "<span></span>"
  end
  if aclmode == "lock" or aclmode == "register" or aclmode == "disabled" then
    blacklistclass["group"].style = "display:none;"
  end
    html[#html+1] = ui_helper.createTable(acl_columns, acl_blacklist_data, acl_blacklist_options, blacklistclass, acl_blacklist_helpmsg)
  return html
end
-- Load the ACL Mac Address list by ajax get request
if getargs.action=="GET_ACL_MAC_LIST" then
  local acl_mode = getargs.acl_mode
  ngx.print(loadAclList(acl_mode))
  ngx.exit(ngx.HTTP_OK)
end

local radioData ={}
for i,v in ipairs(radios) do
  local path = "rpc.wireless.radio.@" .. v
  local rdata = proxy.get(path..".supported_frequency_bands" ,path .. ".remotely_managed", path .. ".supported_standards",path .. ".integrated_ap")
  if rdata ~= nil then
    radioData[v] = {
      supported_frequency_bands=rdata[1].value,
      remotely_managed=rdata[2].value,
      supported_standards=rdata[3].value,
      integrated_ap=rdata[4].value,
    }
  end
end

if radioData[curradio].remotely_managed == "1" then
    isremman = "1"
end

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
      postdata["requested_channel_width"] = postdata[cw[untaint(postdata["standard"])]]
      return true
    else
      return nil, msg
    end
  end
end

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
       object[key] = object["admin_state"]
    else
       object[key] = nil
    end
    return true
end

local pathradio = format("rpc.wireless.radio.@%s.", curradio)
local pathiface = format("rpc.wireless.ssid.@%s.", curiface)
local pathap = format("rpc.wireless.ap.@%s.", curap)
local pathradius = format("uci.wireless.wifi-radius-server.@%s_", curap)

-- Constructing the rpc parameters and validations for post handleQuery
function getParamsAndValidation()
  local is5Ghz = (ngx.req.get_uri_args().radio == "radio_5G")
  local wps_button_handler = setmetatable({
        ["1"] = "wps_button_pressed.sh",
        ["0"] = "acl_button_pressed.sh",
    }, untaint_mt)

  -- rpc parameters list
  local mapParams = {
    ap_enabled = pathap .. "admin_state",
    ssid = pathiface .. "ssid",
    ap_broadcast_ssid = pathap .. "public",
    security = pathap .. "security.mode",
    wep_key = pathap .. "security.wep_key",
    wpa_psk = pathap .. "security.wpa_psk_passphrase",
    wps_enabled = pathap .. "wps.admin_state",
    acl_mode = pathap .. "acl.mode",
    wps_button_handler = wpshandler_data and "uci.button.button.@wps.handler",
    }

  if isguest ~= "1" then
    if not is5Ghz and isremman  ~= "1" then
      mapParams.standard = pathradio .. "standard"
      mapParams.sgi = pathradio .. "sgi"
      mapParams.cdd = pathradio .. "cdd"
      mapParams.stbc = pathradio .. "stbc"
    end
    mapParams.requested_channel_width = pathradio .. "requested_channel_width"
    mapParams.admin_state = pathradio .. "admin_state"
    mapParams.requested_channel = pathradio .. "requested_channel"
    -- Bug fix for NG-12032 GUI wireless enable/disable not working properly
    for k, v in pairs(radios) do
      if v~=curradio then
        mapParams["admin_state_" .. v] = "rpc.wireless.radio.@" .. v .. ".admin_state"
      end
    end
  end

  -- Only include radius configuration in UI if not in guest/hotspot mode or not remotely managed
  if isguest ~= "1" and isremman ~= "1" then
    mapParams.radius_authent_state = pathradius .. "auth0.state"
    mapParams.radius_authent_ip = pathradius .. "auth0.ip"
    mapParams.radius_authent_port = pathradius .. "auth0.port"
    mapParams.radius_authent_secret = pathradius .. "auth0.secret"
    mapParams.radius_account_state = pathradius .. "acct0.state"
    mapParams.radius_account_ip = pathradius .. "acct0.ip"
    mapParams.radius_account_port = pathradius .. "acct0.port"
    mapParams.radius_account_secret = pathradius .. "acct0.secret"
  end

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
 --   security = gVIES(secmodes),
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
      mapValid["admin_state_" .. v] = getInterfaceEnabled2
    end
  end

  if proxy.get(pathiface.."ssid")[1].value ~= "Telia wifi1x" then
	mapValid["security"] = gVIES(secmodes)
end

  return mapParams, mapValid
end

local content, helpmsg = {},{}
-- Process POST query
if ngx.req.get_method() == "POST" then

  local mapParams, mapValid = getParamsAndValidation()
  content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
  -- End of parameters saving / loading

  -- Support for device PIN code
  content["wps_device_pin_code"] = ""

-- triggered only on a POST with action set wps_device_pin_code (button next to field should trigger that)
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
  -- End of device PIN code support
  -- triggered only on a POST with action set wps_pbc
    if action == "wps_pbc" and content["wps_enabled"] == "1" then
        proxy.set("rpc.wireless.wps_button","1")
    end
  -- End of WPS PBC code support

  -- AP PIN code and Mac - read only
  content["macaddress"] = proxy.get(pathiface .. "mac_address")[1].value
  content["wps_ap_pin_code"] = proxy.get("rpc.wireless.ap.@" .. curap .. ".wps.ap_pin")[1].value
else
    -- The else part will be executed only for http GET request(while opening the modal or switching between SSID's)
    content = {
      ap_enabled = pathap .. "admin_state",
      ap_broadcast_ssid = pathap .. "public",
      security = pathap .. "security.mode",
      wep_key = pathap .. "security.wep_key",
      wpa_psk = pathap .. "security.wpa_psk_passphrase",
      wps_enabled = pathap .. "wps.admin_state",
      acl_mode = pathap .. "acl.mode",
      wps_ap_pin_code = pathap .. "wps.ap_pin",
      macaddress=pathiface .. "mac_address",
    }
    content_helper.getExactContent(content)
    content["ssid"] = cur_ssid
    if isguest ~= "1" and isremman ~= "1" then
        local radius_authent = proxy.get(pathradius .. "auth0.")
        for _, v in pairs(radius_authent) do
          content["radius_authent_" .. v.param]=v.value
        end
        local radius_account = proxy.get(pathradius .. "acct0.")
        for _, v in pairs(radius_account) do
          content["radius_account_" .. v.param]=v.value
        end
    end
end
local radion_data=proxy.get(pathradio)
for _, v in pairs(radion_data) do
    if not content[v.param] then
        content[v.param]=v.value
    end
end

-- Ensure Channel and Current channel are the same value after clicking Save
if content["requested_channel"] ~= nil and content["channel"] ~= nil and content["requested_channel"] ~= "auto" then
    content["channel"] = content["requested_channel"]
end

ngx.print(ui_helper.createHeader(T"Wireless", false, false)) %>

<div class="modal-body update">
<form class="form-horizontal" method="post" action="<%= ngx.var.request_uri %>">
<%
-- Do not display the navlist on the list if only 1 SSID
if #wls > 1 then
%>
<div class="span2">
    <ul class="nav nav-list">
    <%
  local html = {}
    local prevradio = ""
    for i,v in ipairs(wls) do
        if v.radio ~= prevradio then
            if radioData[untaint(v.radio)].remotely_managed == "1" and radioData[untaint(v.radio)].integrated_ap ~= "1" then
                html[#html+1] = format('<li class="nav-header">%s %s</li>', T"External access points", radioData[untaint(v.radio)].supported_frequency_bands)
            else
                html[#html+1] = format('<li class="nav-header">%s %s</li>', T"Access points", radioData[untaint(v.radio)].supported_frequency_bands)
            end
            prevradio = v.radio
        end
        local active = ""
        if v.iface == curiface and not getWifiAnalyzer then
            active = "active"
        end
        local url = "modals/wireless-modal.lp?radio=" .. v.radio .. "&iface=" .. v.iface
	-- Don't show Telia wifi1x in the menu for radio_5G and for Telia wifi1x Disabled.
	if not(v.ssid == "Telia wifi1x" and v.radio == "radio_5G") and not(v.ssid == "Telia wifi1x Disabled") then
          html[#html+1] = format('<li class="%s"><a href="#" data-remote="%s">%s</a></li>', active, url, v.ssid)
	end
    end
     -- If wifi analyzer enabled, draw it
    local wifi_analyzer_disable = proxy.get("uci.wireless.wifi.@global.wifi_analyzer_disable")
    if wifi_analyzer_disable and wifi_analyzer_disable[1].value ~= "1" then
      html[#html+1] = string.format('<li class="nav-header">%s</li>', T"Wireless Data")
      local freq = "2.4"
      local isDuplicate = {}
      for i,v in ipairs(wls) do
          if not isDuplicate[v.radio] and (v.radio == "radio_5G" or v.radio == "radio_2G") then
            if v.radio == "radio_5G" then freq = "5" or "2.4" end
            local active = ""
            if getWifiAnalyzer == v.iface then
              active = "active"
              radio = v.radio
            end
            local url = "modals/wireless-modal.lp?radio=" .. v.radio .. "&isWifiAnalyzer=" .. v.iface
            html[#html+1] = string.format('<li class="%s"><a href="#" data-remote="%s" >%s %sGHz</a></li>',active, url, T"Analyzer",freq )
          end
          isDuplicate[v.radio] = true
      end
    end
    if session:hasAccess("/modals/wireless-client-modal.lp") then
      html[#html+1] = format("<li><a href=\"#\" <a href=\"#\" data-remote=\"modals/wireless-client-modal.lp\" >%s</a></li>", T"Client Monitoring")
    end
    ngx.print(html)
    %>
    </ul>
</div>
<div class="span6">
<%
end
local current_acl_mode = content["acl_mode"]
if not getWifiAnalyzer then%>
<%
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
%>
<fieldset>
<legend><%= T"Interface" %></legend>

<%
    local html = {}
   -- local advanced = {
     --   group = {
       --     class = "advanced hide",
        --}
    --}

    -- In guest page, do not let the user change the configuration of the wifi radio. Only in main AP
    if isguest == "1" then
		-- Don't show the interface information for Telia wifi1x SSID's
		if content["ssid"] ~= "Telia wifi1x" then
		        html[#html + 1] = ui_helper.createLabel(T"Frequency band", content["supported_frequency_bands"])
		        -- Label that shows the MAC address of the Wifi interface
		        html[#html + 1] = ui_helper.createLabel(T"MAC address", content["macaddress"])
			    if radioData[curradio].supported_frequency_bands == "5GHz" then
			      html[#html + 1] = ui_helper.createLabel(T"Standard", listboxToText(wifi_standard, wifiStandard.standard))
			    else
			      html[#html + 1] = ui_helper.createLabel(T"Standard", listboxToText(wifi_standard, content["standard"]))
			    end
		        -- Current speed of the Wifi interface
		        html[#html + 1] = ui_helper.createLabel(T"Speed", content["phy_rate"] / 1000 .. "Mbps", { span = {
		            id = "phy_rate",
		            ["data-ajaxrefresh"] = "5",
		        }})

		        html[#html + 1] = ui_helper.createLabel(T"Channel", content["requested_channel"])

		        -- Show which region is being used
		        html[#html + 1] = ui_helper.createLabel(T"Region", content["country"])
		        html[#html + 1] = ui_helper.createLabel(T"Current channel", content["channel"], { span = {
		            id = "channel",
		            ["data-ajaxrefresh"] = "10",
		        }})

		        html[#html + 1] = ui_helper.createLabel(T"Channel width", listboxToText(channelwidth, content["requested_channel_width"]))
		else
			html[#html + 1] = ui_helper.createSwitch(T"Enabled", "ap_enabled", content["ap_enabled"])

		end
	else
        -- Switch that shows if the Wifi interface is enabled or not
        html[#html + 1] = ui_helper.createSwitch(T"Enabled", "admin_state", content["admin_state"])
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
     html[#html + 1] = ui_helper.createLabel(T"Standard", listboxToText(wifi_standard, wifiStandard.standard),stdattributes)
     stdattributes.select={class = "monitor-changes",style="display:none"}
     html[#html + 1] = ui_helper.createSimpleInputSelect("standard", wifi_standard, wifiStandard.standard,stdattributes)
   else
     html[#html + 1] = ui_helper.createInputSelect(T"Standard", "standard", wifi_standard, content["standard"],stdattributes)
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
        html[#html + 1] = ui_helper.createInputSelect(T"Channel", "requested_channel", allowed_channels, content["requested_channel"])

        -- Show which region is being used
        html[#html + 1] = ui_helper.createLabel(T"Region", content["country"])
        html[#html + 1] = ui_helper.createLabel(T"Current channel", content["channel"], { span = {
            id = "channel",
            ["data-ajaxrefresh"] = "5",
        }})
        html[#html + 1] ='<div class >'
        local cw20attributes  = {
            group = {
                class ="hide monitor-standard monitor-b monitor-bg",
            },
        }

        html[#html + 1] = ui_helper.createInputSelect(T"Channel Width", "channelwidth20", cw_20, content["requested_channel_width"], cw20attributes)

        local cw40attributes  = {
            group = {
                class ="hide monitor-standard monitor-bgn monitor-an",
            },
        }

        html[#html + 1] = ui_helper.createInputSelect(T"Channel Width", "channelwidth40", cw_40, content["requested_channel_width"], cw40attributes)

        local cw80attributes  = {
            group = {
                class ="hide monitor-standard monitor-anac",
            },
        }

        html[#html + 1] = ui_helper.createInputSelect(T"Channel Width", "channelwidth80", cw_80, content["requested_channel_width"], cw80attributes)
        html[#html + 1] = '</div>'
        -- html[#html + 1] = ui_helper.createSwitch("Frame bursting", "framebursting", content["framebursting"], advanced)
        if isremman  ~= "1" then
            html[#html + 1] = ui_helper.createSwitch(T"Short Guard Interval", "sgi", content["sgi"])
            html[#html + 1] = ui_helper.createSwitch(T"Cyclic-Delay Diversity", "cdd", content["cdd"])
            html[#html + 1] = ui_helper.createSwitch(T"Space Time Block Code", "stbc", content["stbc"])
        end
    end
    ngx.print(html)
%>
</fieldset>
<%
-- Don't show ap and wps sections for Telia wifi1x
if content["ssid"] ~= "Telia wifi1x" then
%>
<fieldset>
<legend><%= T"Access Point" %></legend>
<%
    html = {}
    -- Show if the AP is enabled
    html[#html + 1] = ui_helper.createSwitch(T"Enabled", "ap_enabled", content["ap_enabled"])

    -- Show the SSID
    local ssidclass = {
        input = {
            pattern= "[!-~][ -~]{0,30}[!-~]",
            maxlength= "32",
            class= "span4",
            }
    }
    html[#html + 1] = ui_helper.createInputText(T"SSID name", "ssid", content["ssid"], ssidclass, helpmsg["ssid"])

 --   local broadcastclass = {
   --     group = {
     --       class = "advanced hide",
       -- },
        --input = {
          --  class = "monitor-changes"
        --}
    --}

    -- Should we broadcast the SSID
    html[#html + 1] = ui_helper.createSwitch(T"Broadcast SSID", "ap_broadcast_ssid", content["ap_broadcast_ssid"])


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
    if radioData[curradio].remotely_managed ~= "1" or radioData[curradio].integrated_ap == "1"  then
      html[#html + 1] = ui_helper.createButton(T"WPS PBC", T"Trigger", "icon-refresh", wps_class)
    end
end

    ngx.print(html)
%>
    <input type="hidden" name="radius_authent_state" value="" >
    <input type="hidden" name="radius_account_state" value="" >


</fieldset>

<fieldset>
<legend><%= T"Access Control List" %></legend>
<%
    html = {}

    local aclmodeclass = {
        select = {
          class = "monitor-changes",
          id="aclmode"
        }
    }

    local isTableLoaded =  false
    if ngx.req.get_method() == "POST" and  ngx.req.get_post_args().action ~="nil" and string.find(ngx.req.get_post_args().action, "TABLE") ~= nil then
        local tableid = ngx.req.get_post_args().tableid
        if tableid == "acl_whitelist" then
            content["acl_mode"] = "lock"
        elseif tableid == "acl_blacklist" then
            content["acl_mode"] = "unlock"
        elseif tableid == "acl_register" then
            content["acl_mode"] = "register"
            acl_whitelist_options["tableid"] = "acl_register"
        end
            html[#html + 1] = ui_helper.createInputSelect(T"ACL mode", "acl_mode", acl_modes, content["acl_mode"], aclmodeclass)
            html[#html + 1] = loadAclList(content["acl_mode"])
            isTableLoaded =  true
    else
        html[#html + 1] = ui_helper.createInputSelect(T"ACL mode", "acl_mode", acl_modes, content["acl_mode"], aclmodeclass)
        html[#html + 1] = "<div id=\"acl_list_div\" class=\"monitor-acl_mode monitor-lock monitor-register monitor-unlock\"><img src=\"/img/loading.gif\"/></div>"
    end
    ngx.print(html)
%>
</fieldset>

<%
if isremman ~= "1" then
%>

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
%>

<%
end

else
--wifi analyzer handler
  local uri = ngx.var.uri
  if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
  end
%>
<form id="wifiForm" class="form-horizontal" method="post" action="<%=uri%>">
<div class="span6">
<fieldset>
<legend><%= T"Wifi Analyzer" %></legend>
<div id ="analyzerloader" style="height:100px"><img src = "/img/loading.gif"></img></div>
<div id = "analyzerGraph" class="hide">
<%= T"The below chart shows the results of the latest scan of your local area from your gateway." %>
<canvas id="wrapper" width="720px" height="400px" style="border:1px solid #c3c3c3;">
<%= T"Please update your browser to use this page." %>
</canvas>
<div id="ReScan" style="width:650px;text-align:right;margin-right:20px;"><div class="btn btn-primary btn-large">Re-scan</div></div>
</div>
<div id="key" style="width: 700px;"></div>
<div id ="analyzerloader1" style="height:100px"><img src = "/img/loading.gif"></img></div>
</fieldset>
</div>
</form>

<script language ="javascript">
function get_random_color() {
  var letters = '0123456789ABCDEF'.split('');
  var color = '#';
  for (var i = 0; i < 6; i++ ) {
    color += letters[Math.round(Math.random() * 15)];
  }
   return color;
}
  function get_y_from_sig(max, min, range, sig) {
    return ((sig-max)/((min-max)/range))+30;
  }
  function get_curve_y_from_sig(max, min, range, sig) {
      var line = 350 - get_y_from_sig(max, min, range, sig);
      var line = 350 - (line *2);
    return line;
  }

    var maximum= -20;
    var minimum= -105;
    var range = 320;
    var bittarget40 = 10;
    var bittarget80 = 16;
    var c=document.getElementById("wrapper");
    var ctx=c.getContext("2d");
    ctx.lineStyle="#FF0000";

    //Y Axis
    ctx.moveTo(30,30);
    ctx.lineTo(30,350);
    ctx.stroke();

    //Power Marks
    //30
    var line10 = get_y_from_sig(maximum, minimum, range, -10);
    ctx.moveTo(30,line10);
    ctx.lineTo(25,line10);
    ctx.stroke();
    ctx.font="9px Arial";
    ctx.fillText("-10",7,line10 + 3);

    var line30 = get_y_from_sig(maximum, minimum, range, -30);
    ctx.moveTo(30,line30);
    ctx.lineTo(25,line30);
    ctx.stroke();
    ctx.font="9px Arial";
    ctx.fillText("-30",7,line30 + 3);

    //60
    var line60 = get_y_from_sig(maximum, minimum, range, -60);
    ctx.moveTo(30,line60);
    ctx.lineTo(25,line60);
    ctx.stroke();
    ctx.font="9px Arial";
    ctx.fillText("-60",7,line60 + 3);

     //90
    var line90 = get_y_from_sig(maximum, minimum, range, -90);
    ctx.moveTo(30,line90);
    ctx.lineTo(25,line90);
    ctx.stroke();
    ctx.font="9px Arial";
    ctx.fillText("-90",7,line90 + 3);

    //X Axis
    ctx.moveTo(30,350);
    ctx.lineTo(690,350);
    ctx.stroke();
    //Titles
    ctx.font="9px Arial";
    ctx.fillText("Channel",310,390);
    ctx.save();
    ctx.translate(0, 0);
    //ctx.rotate(Math.PI/2);
    ctx.textAlign = "center";
    ctx.fillText("Signal Strength (-dBm)", 60, 25);
    ctx.restore();
    <% if radio == "radio_2G" then %>
    //Channel Marks
    ctx.moveTo(120,350);
    ctx.lineTo(120,355);
    ctx.stroke();
    ctx.font="9px Arial";
    ctx.fillText("1",117,370);
    ctx.moveTo(320,350);
    ctx.lineTo(320,355);
    ctx.stroke();
    ctx.font="9px Arial";
    ctx.fillText("6",317,370);
    ctx.moveTo(520,350);
    ctx.lineTo(520,355);
    ctx.stroke();
    ctx.font="9px Arial";
    ctx.fillText("11",517,370);
    <%else%>
    //Channel Marks
    var chn_diff = 30;
    var chnl = 0;

    for (i = 0; i <= 7; i++) {
         ctx.moveTo(60+(chn_diff*i),350);
         ctx.lineTo(60+(chn_diff*i),355);
         ctx.stroke();
         ctx.font="9px Arial";
         chnl = 36+(i*4);
         ctx.fillText(chnl.toString(),60+(chn_diff*i)-4,370);
    }

    for (i = 10; i <= 20; i++) {
         ctx.moveTo(60+(chn_diff*i),350);
         ctx.lineTo(60+(chn_diff*i),355);
         ctx.stroke();
         ctx.font="9px Arial";
         chnl = 60+(i*4);
         ctx.fillText(chnl.toString(),60+(chn_diff*i)-6,370);
    }

    <%end%>

    var key=document.getElementById("key");
    var offset = 30;
    var startcolor = parseInt("00000F",16 );
    var color = startcolor;
    key.innerHTML=key.innerHTML+"<br/>";
    key.innerHTML=key.innerHTML+"<div style='display: inline-block;width:200px;'><b><%= T'Network Name (SSID)'%></b></div>";
    key.innerHTML=key.innerHTML+"<div style='display: inline-block;width:80px;text-align: center;'><b><%= T'Channel' %></b></div>";
    key.innerHTML=key.innerHTML+"<div style='display: inline-block;width:60px;text-align: center;'><b><%= T'40MHz'%></b></div>";
    <% if radio ~= "radio_2G" then %>
    key.innerHTML=key.innerHTML+"<div style='display: inline-block;width:60px;text-align: center;'><b><%= T'80MHz'%></b></div>";
    <% end %>
    key.innerHTML=key.innerHTML+"<div style='display: inline-block;width:180px;text-align: center;'><b><%= T'Signal Strength (RSSI)'%></b></div><br/>";

    function generateGraph(ssid,channel,rssi,cap){
      color =  get_random_color();
      var Mhz = 1;
      var Str = "&nbsp;";
      var cap = parseInt(cap,16).toString(2);

      /*if(cap.indexOf("40MHz")!=-1)
      {
        Mhz = 2;
        Str = "*"
      }
      */
      while (cap.length <= 16)
        {
         cap = "0"+cap;
        }

     if (cap.charAt(cap.length-bittarget40) == "1") {
         Mhz = 2;
         Str = '*';
      }

      <% if radio == "radio_2G" then %>
      //2.4GHz
      var xcoord = 80+(channel*40);
      var sig = rssi;
      if (sig > maximum){sig = maximum }else if (sig < minimum){sig = minimum}
      ctx.beginPath();

      color =  get_random_color();
      ctx.strokeStyle = color;

        ctx.moveTo(xcoord-(80*Mhz), 350);
        ctx.quadraticCurveTo(xcoord, get_curve_y_from_sig(maximum, minimum, range, sig), xcoord+(80*(Mhz)), 350);

      ctx.stroke();
       <% else %>
       //5GH

      var chlist40 = [38,46,54,62,102,110,118,126,134,142]
      var chlist80 = [42,58,106,122,138]
      var str40 = ""
      var str80 = ""

      for (i = 0; i <= chlist40.length; i++) {
          if (chlist40[i] == channel){
            str40 = "*";
            Mhz = 2;
          }
      }
      for (i = 0; i <= chlist80.length; i++) {
          if (chlist80[i] == channel){
            str80 = "*";
            Mhz = 4;
          }
      }
      var xcoord = 0
      if  (channel <= 64) {
         xcoord = 60+((channel-36)*7.5);
      }else{
         xcoord = 360+((channel-100)*7.5);
      }

      var sig = rssi;

      if (sig > maximum){sig = maximum }else if (sig < minimum){sig = minimum}
          ctx.beginPath();
          color =  get_random_color();
          ctx.strokeStyle = color;
          ctx.moveTo(xcoord-(15*Mhz), 350);
          ctx.quadraticCurveTo(xcoord, get_curve_y_from_sig(maximum, minimum, range, sig) , xcoord+(15*Mhz), 350);
          ctx.stroke();
       <% end %>
      key.innerHTML=key.innerHTML+"<font style=\'color:"+color+";\'>"
      key.innerHTML=key.innerHTML+"<div style='display: inline-block;width:200px;color:"+color+";'><b>"+ssid+"</b></div>"
      key.innerHTML=key.innerHTML+"<div style='display: inline-block;width:80px;color:"+color+";text-align: center;'><b>"+channel+"</b></div>"
      <% if radio == "radio_2G" then %>
         key.innerHTML=key.innerHTML+"<div style='display: inline-block;width:60px;color:"+color+";text-align: center;'><b>"+Str+"</b></div>"
      <%else%>
        key.innerHTML=key.innerHTML+"<div style='display: inline-block;width:60px;color:"+color+";text-align: center;'><b>"+str40+"</b></div>"
        key.innerHTML=key.innerHTML+"<div style='display: inline-block;width:60px;color:"+color+";text-align: center;'><b>"+str80+"</b></div>"
      <%end%>
      key.innerHTML=key.innerHTML+"<div style='display: inline-block;width:180px;color:"+color+";text-align: center;'><b>"+rssi+"</b></div>"
      key.innerHTML=key.innerHTML+"</font><br/>"
    }
    $(document).ready(function(){
      $("#ReScan").on("click",function(a){
        var params = [];
        params.push({
          name : "action",
          value : "rescan"
        });
        params.push({
          name : "curradio",
          value : "<%=radio%>"
        });

        params.push(tch.elementCSRFtoken());
        tch.showProgress("<%=T"Re-scanning"%>...");
        $.post("/modals/wireless-modal.lp", params, function(acsData){
          tch.removeProgress();
          if (acsData.length > 0 ) {
            $.each(acsData, function(i, data){
              generateGraph(data.ssid,data.channel,data.rssi,data.cap);
            });
          }
        });
      });
      $.get("/modals/wireless-modal.lp?isWifiAnalyzer=<%=getWifiAnalyzer%>&getAcsData=true&radio=<%=radio%>",function(acsData){
         $("#analyzerloader").addClass("hide");
         $("#analyzerGraph").removeClass("hide");
         $("#analyzerloader1").addClass("hide");
         $.each(acsData, function(i, data) {
           generateGraph(data.ssid,data.channel,data.rssi,data.cap);
         });
       });
    });
</script>

<% end --End of wifi analyzer
-- Do not display the navlist on the list if only 1 SSID
if #wls > 1 then
%>
</div>
<%
end
%>
</form>
</div>

<% ngx.print(ui_helper.createFooter()) %>
<script>
<%if not isTableLoaded then %>
    $.get("/modals/wireless-modal.lp?radio=<%=curradio%>&iface=<%=curiface%>&action=GET_ACL_MAC_LIST&acl_mode=<%=content["acl_mode"]%>", function (data){
        $('#acl_list_div').replaceWith(data);
    });
<%end%>
$("#aclmode").change(function(){
var aclmode = $(this).val();
if(aclmode == "register"){
    $("#acl_whitelist").attr("id","acl_register");
}else{
    $("#acl_register").attr("id","acl_whitelist");
}
});
</script>
