--pretranslated: do not change this file
 
local string, table, pairs = string, table, pairs
local ngx, tonumber, ipairs, setmetatable, tinsert, gmatch = ngx, tonumber, ipairs, setmetatable, table.insert, string.gmatch
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

local gVCS = post_helper.getValidateCheckboxSwitch()
local gVIES = post_helper.getValidateInEnumSelect

local checkbox_map = setmetatable({
    ["0"]= T'Off',
    ["1"]= T'On',
}, untaint_mt)

local content_wan = {
    wan_ip = "rpc.network.interface.@wan.ipaddr",
    wan6_ip = "rpc.network.interface.@wan6.ipaddr",
}
content_helper.getExactContent(content_wan)
local wan_down = content_wan.wan_ip == "" and content_wan.wan6_ip == ""

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
	if not wan_down then
		object[key] = nil
		return true
	end
	return gVCS(value, object, key)
end

local function validate_earfcn(value)
	local errmsg = T"The EARFCN needs to be a number between 0 and 65535\nUse commas to separate multiple EARFCN values."
	for part in gmatch(value, '([^,]+)') do
		part = part:gsub("^%s*(.-)%s*$", "%1")
		local num = tonumber(part, 10)
		if not num or num < 0 or num > 65535 then
			return nil, errmsg
		end
	end
	return true
end

local function get_profile_select(device)
	local names = {}

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
			return names
		end
	end

	local profiles = content_helper.getMatchedContent("uci.mobiled.profile.")
	for _, profile in ipairs(profiles) do
		tinsert(names, { string.untaint(profile.id), string.untaint(profile.name) })
	end

	return names
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
	if page.platform.capabilities.antenna_controls then
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

local function revert_provisioning_code()
	local provision_code_path = "uci.env.var.provisioning_code"
	local provisioning_code = {
		default_pcode = "uci.env.var._provisioning_code",
		curr_pcode = provision_code_path,
	}
	content_helper.getExactContent(provisioning_code)
	if provisioning_code.default_pcode ~= provisioning_code.curr_pcode then
		proxy.set(provision_code_path, provisioning_code.default_pcode)
		--proxy apply will do in the caller
	end
end

local function set_cwmpd_iface(mobile_enabled, mobile_interface, default_interface)
	local cwmpd_interface_path = "uci.cwmpd.cwmpd_config.interface"
	local cwmpd_interface6_path = "uci.cwmpd.cwmpd_config.interface6"
	local cwmpd_ip_preference_path = "uci.cwmpd.cwmpd_config.ip_preference"
	local uci_content = {
		cwmpd_interface = cwmpd_interface_path,
	}
	content_helper.getExactContent(uci_content)
	if mobile_enabled then
		if uci_content["cwmpd_interface"] ~= mobile_interface .."_4" then
			revert_provisioning_code()
			proxy.set(cwmpd_ip_preference_path, "v6_only")
			proxy.set(cwmpd_interface_path, mobile_interface .. "_4")
			proxy.set(cwmpd_interface6_path, mobile_interface .. "_6")
		end
	else
		if uci_content["cwmpd_interface"] ~= default_interface then
			proxy.set(cwmpd_ip_preference_path, "v4_only")
			proxy.set(cwmpd_interface_path, default_interface)
			proxy.set(cwmpd_interface6_path, default_interface .. "6")
		end
	end
end
local function set_ddns_iface(mobile_enabled, mobile_interface, default_interface)
    local ddns_interface_path = "uci.ddns.service.@myddns_ipv4.interface"
	local ddns_ip_network_path = "uci.ddns.service.@myddns_ipv4.ip_network"
	local uci_content = {
		ddns_interface = ddns_interface_path,
	}
	content_helper.getExactContent(uci_content)
	if mobile_enabled then
		if uci_content["ddns_interface"] ~= mobile_interface .."_4" then
			proxy.set(ddns_interface_path, mobile_interface .. "_4")
			proxy.set(ddns_ip_network_path, mobile_interface .. "_4")
		end
	else
		if uci_content["ddns_interface"] ~= default_interface then
			proxy.set(ddns_interface_path, default_interface)
			proxy.set(ddns_ip_network_path, default_interface)
		end
	end
end

local function set_upnpd_iface(mobile_enabled, mobile_interface, default_interface)
    local upnpd_interface_path = "uci.upnpd.config.external_iface"
	local uci_content = {
		upnpd_interface = upnpd_interface_path,
	}
	content_helper.getExactContent(uci_content)
	if mobile_enabled then
		if uci_content["upnpd_interface"] ~= mobile_interface .."_4" then
			proxy.set(upnpd_interface_path, mobile_interface .. "_4")
		end
	else
		if uci_content["upnpd_interface"] ~= default_interface then
			proxy.set(upnpd_interface_path, default_interface)
		end
	end
end

local function set_ra_iface(mobile_enabled, mobile_interface, default_interface)
	local ra_helper = require("assistance_helper")
	local path = proxy.get("uci.web.assistance.")[1].path
	local ra_interface_path = path .. "interface"
	local _, _, secname = string.find(path, "web%.assistance%.@([^%.]*)%.")
	if mobile_enabled then
		proxy.set(ra_interface_path, mobile_interface)
		ra_helper.change_interface(secname, mobile_interface)
	else
		proxy.set(ra_interface_path, default_interface)
		ra_helper.change_interface(secname, default_interface)
	end
end

local function process_services_on_failover(content, mobile_interface, default_interface)
	if content.autofailover == "0" then
		local uci_content = {
			mobile_interface_enable = "uci.network.interface.@" .. mobile_interface .. ".enabled",
		}
		content_helper.getExactContent(uci_content)
		local mobile_enabled = content.interface_enabled == "1" and uci_content.mobile_interface_enable == "1"
		set_cwmpd_iface(mobile_enabled, mobile_interface, default_interface)
		set_ddns_iface(mobile_enabled, mobile_interface, default_interface)
		set_upnpd_iface(mobile_enabled, mobile_interface, default_interface)
		set_ra_iface(mobile_enabled, mobile_interface, default_interface)
	end
	proxy.apply()
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
	}
	if wan_down and page.content["autofailover"] ~= "1"  then
		interfaces_columns[#interfaces_columns + 1] =
		{
			header = T"Connect",
			name = "enabled",
			param = "enabled",
			type = "checkboxswitch"
		}
	else
		interfaces_columns[#interfaces_columns + 1] =
		{
			header = T"Connect",
			name = "enabled",
			param = "enabled",
			readonly = true,
			type = "label"
		}

	end
	local interfaces_options = {
		tableid = "lte_interfaces",
		basepath = "uci.network.interface.@.",
		canAdd = false,
		canDelete = false
	}

	local interfaces_valid = {
		enabled = gVCS,
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

	if (not interfaces_helpmsg or not next(interfaces_helpmsg)) and ngx.req.get_method() == "POST" then
		local post_args = ngx.req.get_post_args()
		if post_args.action == "TABLE-MODIFY" then
			process_services_on_failover(page.content, "wwan", "wan")
		end
	end

	if wan_down and page.content["autofailover"] ~= "1" then
		for _, intf in pairs(interfaces_data) do
			if string.format("%s", intf[3]) == "" then
				intf[3] = "1"
			end
		end
	else
		for _, intf in pairs(interfaces_data) do
			intf[3] = checkbox_map[intf[3]] or "On"
		end
	end

	local apn_warning = {
		alert = {
			class = "alert-warning"
		},
	}
	if utils.Len(interfaces_data) > 0 then
		tinsert(html, "<fieldset><legend>" .. T"Interfaces" .. "</legend>")

		--to find the not used linked_profile, since there is only one lte interface, so no need to loop
		for _, v in pairs(page.profiles_select) do
			if v[2] == "telstra.hybrid" then
				tinsert(html, ui_helper.createAlertBlock(T"You must select the <strong>telstra.hybrid</strong> profile for your backup service to work.", apn_warning))
			end
		end
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
		tinsert(section, ui_helper.createLabel(T"Firmware version" .. ":", page.device.info.software_version, advanced))
	end
	if page.device.info.hardware_version ~= "" then
		tinsert(section, ui_helper.createLabel(T"Hardware version" .. ":", page.device.info.hardware_version, advanced))
	end
	if page.device.info.temperature ~= "" then
		tinsert(section, ui_helper.createLabel(T"Temperature" .. ":", page.device.info.temperature.." ".."°C", advanced))
	end
	if page.device.info.power_mode ~= "" then
		tinsert(section, ui_helper.createLabel(T"Power mode" .. ":", utils.power_mode_map[page.device.info.power_mode], advanced))
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
					local str = T"Maximum retry duration reached. Please check and correct your mobile configuration and reboot the gateway"
					tinsert(section, ui_helper.createLabel(T"Connection Retry" .. ":", str, { span = { class="span4" } }))
					break
				end
			end
		end

		if utils.Len(section) > 0 then
			if sessionInfo.profile ~= "" then
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
		platform = platform,
		profiles_select = get_profile_select(device),
	}
	local content_wansensing = {
		autofailover = "uci.wansensing.global.autofailover"
	}
	content_helper.getExactContent(content_wansensing)
	if content_wansensing.autofailover ~= "readonly" then
		p.mapParams.autofailover = "uci.wansensing.global.autofailover"
		p.mapValid.autofailover = gVCS
	end

	if type(device) == "table" then
		p.mapParams["interface_enabled"] = device.uci_path .. "enabled"
		if string.match(device.capabilities.arfcn_selection_support, "lte") then
			p.mapParams["earfcn"] = device.uci_path .. "earfcn"
			p.mapValid["earfcn"] = validate_earfcn
		end
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

	--if the network is enabled for wwan_4, the device is disabled, and autofailover is disabled, we should maintain the cwmpd as wwan_4
	if (not helpmsg or not next(helpmsg)) and ngx.req.get_method() == "POST" then
		local post_args = ngx.req.get_post_args()
		if post_args.action == "SAVE" then
			process_services_on_failover(p.content, "wwan", "wan")
		end
	end

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
			if not page then
					ngx.print(ui_helper.createAlertBlock(utils.string_map["no_device"]))
					ngx.print("</form></div>")
					ngx.print(ui_helper.createFooter())
					ngx.exit(ngx.HTTP_OK)
			end
			if not page.device then
				if page.platform and page.platform.capabilities.module_power_control ~= "true" then
					ngx.print(ui_helper.createAlertBlock(utils.string_map["no_device"]))
					ngx.print("</form></div>")
					ngx.print(ui_helper.createFooter())
					ngx.exit(ngx.HTTP_OK)
				else
					local html = {}
					tinsert(html, "<fieldset><legend>" .. T"General Status And Settings" .. "</legend>")
					tinsert(html, ui_helper.createMessages(message_helper.popMessages()))
					local interface_enable_switch_class, interface_enable_label_class
					if page.content["autofailover"] ~= "" then
						if wan_down then
							interface_enable_label_class = {
								group = {
									class ="monitor-autofailover monitor-1",
								}
							}
							interface_enable_switch_class = {
								group = {
									class ="monitor-autofailover monitor-0",
								}
							}
						end
						tinsert(html, ui_helper.createLabel(T"Enabled" .. ":", checkbox_map[page.content["interface_enabled"]], interface_enable_label_class))
					end
					if wan_down then
						tinsert(html, ui_helper.createCheckboxSwitch(T"Enabled" .. ":", "interface_enabled", page.content["interface_enabled"], interface_enable_switch_class))
					end
					if page.content["autofailover"] ~= "" then
						local autofailover_class = {
							input = {
								class = "monitor-changes",
							}
						}
						tinsert(html, ui_helper.createCheckboxSwitch(T"Auto Failover" .. ":", "autofailover", page.content["autofailover"], autofailover_class))
					end
					tinsert(html, "</fieldset>")
					ngx.print(html)
					ngx.print("</form></div>")
					ngx.print(ui_helper.createFooter())
					ngx.exit(ngx.HTTP_OK)
				end
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
			local interface_enable_switch_class, interface_enable_label_class
			if page.content["autofailover"] ~= "" then
				if wan_down then
					interface_enable_label_class = {
						group = {
							class ="monitor-autofailover monitor-1",
						}
					}
					interface_enable_switch_class = {
						group = {
							class ="monitor-autofailover monitor-0",
						}
					}
				end
				tinsert(html, ui_helper.createLabel(T"Enabled", checkbox_map[page.content["interface_enabled"]], interface_enable_label_class))
			end
			if wan_down then
				tinsert(html, ui_helper.createCheckboxSwitch(T"Enabled", "interface_enabled", page.content["interface_enabled"], interface_enable_switch_class))
			end
			if utils.mobiled_state_map[page.device.status.display_status] ~= "" then
				tinsert(html, ui_helper.createLabel(T"Device Status" .. ":", utils.mobiled_state_map[page.device.status.display_status]))
			end
			if utils.radio_tech_map[page.device.leds.radio] ~= "" then
				tinsert(html, ui_helper.createLabel(T"Access Technology" .. ":", utils.radio_tech_map[page.device.leds.radio]))
			end

			if string.match(page.device.capabilities.arfcn_selection_support, "lte") then
				tinsert(html, ui_helper.createInputText(T"EARFCN" .. ":", "earfcn", page.content["earfcn"], advanced))
			end

			get_antenna_selection_section(page, html)
			if page.content["autofailover"] ~= "" then
				local autofailover_class = {
					input = {
						class = "monitor-changes",
					}
				}
				tinsert(html, ui_helper.createCheckboxSwitch(T"Auto Failover", "autofailover", page.content["autofailover"], autofailover_class))
			end
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
'); 