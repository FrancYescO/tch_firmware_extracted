--pretranslated: do not change this file
 
local string, table, pairs = string, table, pairs
local ngx, tonumber, ipairs, setmetatable, tinsert = ngx, tonumber, ipairs, setmetatable, table.insert
local floor, format = math.floor, string.format
-- Enable localization
gettext.textdomain('webui-mobiled')

local utils = require("web.lte-utils")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local untaint_mt = require("web.taint").untaint_mt
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local proxy = require("datamodel")
local telstra_helper = require("telstra_helper")
local symbolv1 = telstra_helper.symbolnamev1

local gVCS = post_helper.getValidateCheckboxSwitch()
local gVIES = post_helper.getValidateInEnumSelect

local label_map = setmetatable({
    ["0"]= T'Off',
    ["1"]= T'On',
}, untaint_mt)

local function validate_in_enum_or_empty(enum)
	local choices = setmetatable({}, untaint_mt)

	-- store that as a dictionnary, will make it simpler
	for _,v in ipairs(enum) do
		choices[v[1]] = true
	end

	return function(value)
		if value == "" then return true end
		return choices[value], T"Invalid value"
	end
end

local function validate_interface_enabled(value, object, key)
	local valid, msg = gVCS(value, object, key)
	if valid and object.autofailover then
		object.autofailover = object.interface_enabled
	end
	return valid, msg
end

local function get_profile_select(device)
	local names = {}
	local authentications = {}

	if device then
		local info = {
			reuse_profiles = device.uci_path .. "reuse_profiles"
		}
		content_helper.getExactContent(info)
		if info and info.reuse_profiles == "1" then
			local profiles = content_helper.getMatchedContent(device.rpc_path .. "profile.")
			for _, profile in ipairs(profiles) do
				tinsert(names, { "device:" .. string.untaint(profile.id), string.untaint(profile.name) })
			end
			return names, authentications
		end
	end

	local profiles = content_helper.getMatchedContent("uci.mobiled.profile.")
	for _, profile in ipairs(profiles) do
		tinsert(names, { string.untaint(profile.id), string.untaint(profile.name) })
		authentications[string.untaint(profile.id)] = string.untaint(profile.authentication)
	end

	return names, authentications
end

local function get_device_data(dev_idx)
	local rpc_path = string.format("rpc.mobiled.device.@%d.", dev_idx)
	local device = {
		rpc_path = rpc_path,
		uci_path = utils.get_uci_device_path()
	}

	device.capabilities = utils.getContent(rpc_path .. "capabilities.")
	if not device.capabilities then return nil end
	device.capabilities.max_data_sessions = tonumber(device.capabilities.max_data_sessions) or 0

	-- Convert the supported_auth_types field from a space-separated string of supported
	-- auth types to a table with a key that maps to true for each supported auth type.
	if device.capabilities.supported_auth_types then
		local supported_auth_types = {}
		for supported_auth_type in device.capabilities.supported_auth_types:gmatch("%S+") do
			supported_auth_types[supported_auth_type] = true
		end
		device.capabilities.supported_auth_types = supported_auth_types
	end

	device.info = utils.getContent(rpc_path .. "info.")
	if not device.info then return nil end

	device.status = utils.getContent(rpc_path .. "display_status")
	if not device.status then return nil end
	device.leds = utils.getContent(rpc_path .. "leds.")

	return device
end

local function get_platform_data()
	local platform = {
		capabilities = {},
		info = {}
	}
	local antennaControls = tonumber(utils.getContent("rpc.mobiled.platform.capabilities.")["AntennaControlNumberOfEntries"])
	if antennaControls and antennaControls > 0 then
		platform.capabilities.antenna_controls = { utils.getContent("rpc.mobiled.platform.capabilities.antenna_control.@1.") }
	end
	antennaControls = tonumber(utils.getContent("rpc.mobiled.platform.info.")["AntennaControlNumberOfEntries"])
	if antennaControls and antennaControls > 0 then
		platform.info.antenna_controls = { utils.getContent("rpc.mobiled.platform.info.antenna_control.@1.") }
	end
	return platform
end

local function get_antenna_selection_section(page, html)
	if page.platform.capabilities.antenna_controls and page.platform.info.antenna_controls then
		local advanced = {
			group = {
				class = "advanced hide"
			},
			span = {
				class = "span5"
			}
		}
		tinsert(html, ui_helper.createInputSelect(T"Antenna Selection"..':', "selected_antenna", page.antenna_select, page.content["selected_antenna"], advanced))
		if page.content["selected_antenna"] == "auto" then
			if page.platform and page.platform.info then
				local val = {}
				val["id"] = "current_antenna"
				tinsert(html, ui_helper.createLabel(T"Selected Antenna" .. ":", utils.antenna_map[page.platform.info.antenna_controls[1].current_antenna], { group = { class = "advanced hide" }, span = val }))
			end
		end
	end
end

local function get_network_interface_section(page, html)
	local interfaces_columns = {
		{
			header = T"Interface",
			name = "paramindex",
			param = "paramindex",
			type = "label",
			readonly = true,
			attr = { input = { class="span2" } },
		},
		{
			header = T"Linked Profile",
			name = "profile",
			param = "profile",
			type = "select",
			values = page.profiles_select,
			attr = { select = { class="span2" } }
		},
		{
			header = T"Connect",
			name = "enabled",
			param = "enabled",
			readonly = true,
			type = "label"
		}
	}

	local interfaces_options = {
		tableid = "lte_interfaces",
		basepath = "uci.network.interface.@.",
		canAdd = false,
		canDelete = false
	}

	local interfaces_valid = {
		profile = gVIES(page.profiles_select),
	}
	local function interfaces_filter(data)
		if page.device then
			if data.proto ~= "mobiled" then return false end
			local session_id = tonumber(data.session_id)
			if not session_id or session_id > (page.device.capabilities.max_data_sessions-1) then return false end
			return true
		end
		return false
	end
	local function onModify(index, content)
		if page.device.info.manufacturer == "Quectel" then
			return true
		end
		for _, v in pairs(page.profiles_select) do
			if content["profile"] == v[1] then
				local radio_pref = proxy.get("uci.mobiled.device_defaults.radio_pref")[1].value
				local uci_path = page.device.uci_path
				if v[2] == "telstra.hybrid" then
					if radio_pref ~= "lte" then
						proxy.set("uci.mobiled.device_defaults.radio_pref", "lte")
						proxy.set(uci_path .. "radio_pref", "lte")
					end
				else
					if radio_pref ~= "auto" then
						proxy.set("uci.mobiled.device_defaults.radio_pref", "auto")
						proxy.set(uci_path .. "radio_pref", "auto")
					end
				end
			end
		end
	end

	interfaces_options.onModify = onModify
	local interfaces_data, interfaces_helpmsg = post_helper.handleTableQuery(interfaces_columns, interfaces_options, interfaces_filter, nil, interfaces_valid)

	for _, intf in pairs(interfaces_data) do
		intf[3] = label_map[intf[3]] or "On"
	end

	if utils.Len(interfaces_data) > 0 then
		local authentication_warning = {
			alert = {
				id = "profile_auth_warning",
				class = "alert-warning",
				style = "display: none;"
			}
		}
		if page.device.capabilities.supported_auth_types then
			for _, interface_data in pairs(interfaces_data) do
				local authentication = page.profile_authentications[string.untaint(interface_data[2])]
				if not page.device.capabilities.supported_auth_types[authentication] then
					authentication_warning.alert.style = nil
					break
				end
			end
		end
		tinsert(html, "<fieldset><legend>" .. T"Interfaces" .. "</legend>")
		tinsert(html, ui_helper.createAlertBlock(T"The device does not support the authentication of the selected profile.", authentication_warning))
		tinsert(html, ui_helper.createTable(interfaces_columns, interfaces_data, interfaces_options, nil, interfaces_helpmsg))
		tinsert(html, "</fieldset>")
	end
end

local function get_device_info_section(page, html)
	local advanced = {
		group = {
			class = "advanced hide"
		},
		span = {
			class = "span5"
		}
	}
	local section = {}
	if page.device.info.imei ~= "" then
		tinsert(section, ui_helper.createLabel(T"IMEI" .. ":", page.device.info.imei))
	end
	-- Advanced parameters
	if  page.device.info.manufacturer ~= "" then
		tinsert(section, ui_helper.createLabel(T"Manufacturer" .. ":", page.device.info.manufacturer, advanced))
	end
	if page.device.info.model ~= "" then
		tinsert(section, ui_helper.createLabel(T"Model" .. ":", page.device.info.model, advanced))
	end
	if page.device.info.software_version ~= "" then
		tinsert(section, ui_helper.createLabel(T"Firmware Version" .. ":", page.device.info.software_version, advanced))
	end
	if page.device.info.hardware_version ~= "" then
		tinsert(section, ui_helper.createLabel(T"Hardware Version" .. ":", page.device.info.hardware_version, advanced))
	end
	if page.device.info.temperature ~= "" then
		tinsert(section, ui_helper.createLabel(T"Temperature" .. ":", page.device.info.temperature.." ".."°C", advanced))
	end
	if page.device.info.power_mode ~= "" then
		tinsert(section, ui_helper.createLabel(T"Power Mode" .. ":", utils.power_mode_map[page.device.info.power_mode], advanced))
	end

	if utils.Len(section) > 0 then
		tinsert(html, "<fieldset><legend>" .. T"Device Information" .. "</legend>")
		tinsert(html, section)
		tinsert(html, "</fieldset>")
	end
end

local function get_session_info_section(page, html)
	for i = 1, page.device.capabilities.max_data_sessions do
		local section = {}
		local sessionInfo = utils.getContent(page.device.rpc_path .. "network.sessions.@" .. i .. ".")
		if sessionInfo.session_state ~= "" then
			tinsert(section, ui_helper.createLabel(T"Status" .. ":", utils.session_state_map[sessionInfo.session_state]))
		end
		if sessionInfo.ipv4_addr ~= "" then
			tinsert(section, ui_helper.createLabel(T"IPv4 Address" .. ":", sessionInfo.ipv4_addr))
		end
		if sessionInfo.ipv4_dns1 ~= "" then
			tinsert(section, ui_helper.createLabel(T"IPv4 Primary DNS" .. ":", sessionInfo.ipv4_dns1))
		end
		if sessionInfo.ipv4_dns2 ~= "" then
			tinsert(section, ui_helper.createLabel(T"IPv4 Secondary DNS" .. ":", sessionInfo.ipv4_dns2))
		end
		if sessionInfo.ipv6_addr ~= "" then
			tinsert(section, ui_helper.createLabel(T"IPv6 Address" .. ":", sessionInfo.ipv6_addr))
		end
		if sessionInfo.duration ~= "" then
			tinsert(section, ui_helper.createLabel(T"Session Duration" .. ":", sessionInfo.duration..' '..T"seconds"))
		end
		if sessionInfo.tx_bytes ~= "" then
			tinsert(section, ui_helper.createLabel(T"Tx Bytes" .. ":", sessionInfo.tx_bytes))
		end
		if sessionInfo.rx_bytes ~= "" then
			tinsert(section, ui_helper.createLabel(T"Rx Bytes" .. ":", sessionInfo.rx_bytes))
		end
		if sessionInfo.tx_packets ~= "" then
			tinsert(section, ui_helper.createLabel(T"Tx Packets" .. ":", sessionInfo.tx_packets))
		end
		if sessionInfo.rx_packets ~= "" then
			tinsert(section, ui_helper.createLabel(T"Rx Packets" .. ":", sessionInfo.rx_packets))
		end
		if sessionInfo.tx_packets_error ~= "" then
			tinsert(section, ui_helper.createLabel(T"Tx Packet Errors" .. ":", sessionInfo.tx_packets_error))
		end
		if sessionInfo.rx_packets_error ~= "" then
			tinsert(section, ui_helper.createLabel(T"Rx Packet Errors" .. ":", sessionInfo.rx_packets_error))
		end
		if sessionInfo.pdn_retry_timer_remaining ~= "" then
			local s = tonumber(sessionInfo.pdn_retry_timer_remaining)
			if s then
				local str = format("%.2d:%.2d:%.2d", floor(s/(60*60)), floor(s/60%60), floor(s%60))
				tinsert(section, ui_helper.createLabel(T"Connection Retry" .. ":", str, { span = { class="span4" } }))
			end
		else
			local errors = proxy.get(page.device.rpc_path .. "errors.")
			for _, errorInfo in pairs(errors) do
				if errorInfo.param == "type" and string.untaint(errorInfo.value) == "pdn_retry_timer_max_duration" then
					local str = T("Maximum retry duration reached. Please check and correct your mobile configuration and reboot the " .. symbolv2)
					tinsert(section, ui_helper.createLabel(T"Connection Retry" .. ":", str, { span = { class="span4" } }))
					break
				end
			end
		end

		if utils.Len(section) > 0 then
			if sessionInfo.profile ~= "" and sessionInfo.internal ~= "true" then
				tinsert(html, '<fieldset class="profileinfo"><legend>' .. T'Interface' .. ' ' .. sessionInfo.interface .. '</legend>')
				tinsert(html, section)
				tinsert(html, "</fieldset>")
			end
		end
	end
end

local function get_page(platform, device)
	local p = {
		mapParams = {},
		mapValid = {
			interface_enabled = validate_interface_enabled
		},
		device = device,
		platform = platform
	}

	p.profiles_select, p.profile_authentications = get_profile_select(device)

	local content_wansensing = {
		autofailover = "uci.wansensing.global.autofailover"
	}
	content_helper.getExactContent(content_wansensing)
	if content_wansensing.autofailover ~= "readonly" then
		p.mapParams.autofailover = "uci.wansensing.global.autofailover"
	end

	if type(device) == "table" then
		p.mapParams["interface_enabled"] = device.uci_path .. "enabled"
	end

	if type(platform) == "table" then
		if platform.capabilities.antenna_controls then
			p.antenna_select = {}
			for k, v in pairs(utils.antenna_map) do
				table.insert(p.antenna_select, {k, v})
			end
			p.mapParams["selected_antenna"] = "uci.mobiled.platform.antenna"
			p.mapValid["selected_antenna"] = validate_in_enum_or_empty(p.antenna_select)
		end
	end

	local helpmsg
	p.content, helpmsg = post_helper.handleQuery(p.mapParams, p.mapValid)

	setmetatable(p.content, { __index = function() return "" end })

	return p
end

local mobiled = {
	num_devices = "rpc.mobiled.DeviceNumberOfEntries"
}
content_helper.getExactContent(mobiled)

mobiled.devices = {}
mobiled.num_devices = tonumber(mobiled.num_devices)
if mobiled.num_devices and mobiled.num_devices >= 1 then
	for dev_idx=1,mobiled.num_devices do
		mobiled.devices[dev_idx] = get_device_data(dev_idx)
	end
end

local page = get_page(get_platform_data(), mobiled.devices[1])
  ngx.print('\
\
<link href="/css/chosen.css" rel="stylesheet">\
<script language="javascript" type="text/javascript" src="js/chosen-min.js"></script>\
\
<style>\
	.uneven {\
		background-color: #eee;\
	}\
	.selectable {\
		cursor: pointer;\
		cursor: hand;\
	}\
	.selectable:hover {\
		background-color: #aaa;\
	}\
	.currentplmn {\
		background-color: #5d215d;\
		color: #fff;\
	}\
	.img-center {\
		margin: 0 auto;\
		display: block;\
	}\
	.waiting-msg {\
		color: #777;\
	}\
	.float-left {\
		float: left;\
		margin-right: 5px;\
	}\
</style>\
\
');  
	local uri = ngx.var.uri
	local help_link = { href="/help/index.html?anchor=" .. string.format("%s", uri:match("/([^/]+)%.lp")) }
	local params = utils.get_params()
	ngx.print(ui_helper.createHeader(params.modal_title, true, true, nil, help_link))
  ngx.print('\
\
<div class="modal-body update" id="lte-body">\
	<form class="form-horizontal" method="post" action="modals/lte-modal.lp">\
		');  
			local lp = require("web.lp")
			lp.setpath("/www/snippets/")
			lp.include("tabs-mobiled.lp")

			if not page or not page.device then
				ngx.print(ui_helper.createAlertBlock(utils.string_map["no_device"]))
				ngx.print("</form></div>")
				ngx.print(ui_helper.createFooter())
				message_helper.popMessages()
				ngx.exit(ngx.HTTP_OK)
			end

			local html = {}
			local advanced = {
				group = {
					class = "advanced hide"
				},
				span = {
					class = "span5"
				}
			}
			tinsert(html, "<fieldset><legend>" .. T"Device Status And Settings" .. "</legend>")
			tinsert(html, ui_helper.createMessages(message_helper.popMessages()))
			tinsert(html, ui_helper.createCheckboxSwitch(T"Enabled", "interface_enabled", page.content["interface_enabled"]))
			if utils.mobiled_state_map[page.device.status.display_status] ~= "" then
				tinsert(html, ui_helper.createLabel(T"Device Status" .. ":", utils.mobiled_state_map[page.device.status.display_status]))
			end
			if utils.radio_tech_map[page.device.leds.radio] ~= "" then
				tinsert(html, ui_helper.createLabel(T"Access Technology" .. ":", utils.radio_tech_map[page.device.leds.radio]))
			end
			get_antenna_selection_section(page, html)
			tinsert(html, "</fieldset>")
			ngx.print(html)
		  ngx.print('\
			');  
			html = {}
			get_network_interface_section(page, html)
			get_session_info_section(page, html)
			get_device_info_section(page, html)
			ngx.print(html)
		  ngx.print('\
	</form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
<script>\
	$("select[name=\'profile\']").change(function() {\
		var unsupported_profiles = [');  
			if page.device and page.device.capabilities.supported_auth_types then
				local separator = ""
				for profile_id, authentication in pairs(page.profile_authentications) do
					if not page.device.capabilities.supported_auth_types[authentication] then
						ngx.print(string.format('%s"%s"', separator, profile_id))
						separator = ", "
					end
				end
			end
		  ngx.print('];\
		if(unsupported_profiles.indexOf($(this).val()) === -1) {\
			$(\'#profile_auth_warning\').hide();\
		} else {\
			$(\'#profile_auth_warning\').show();\
		}\
	});\
</script>\
'); 