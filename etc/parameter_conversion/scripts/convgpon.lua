#!/usr/bin/lua

--[[
By default all the configurations of gpon /etc/config/gpon are taken from
current configuraiton except following sections. these sections are used to
control the behavior of OMCI stack or represent key information of ONU. They
are not configurable by end used and deemed as integral part of OMCI stack.
Only sections with state set to 1 are copied from /rom/etc/config/gpon
--]]

local section_to_convert = {
	'vlanctl_rule_priority',
	'omci_misc',
	'active_sw_version',
	'ont_version',
	'ont2g_equipment_id'
}

local section_name2type = {
	vlanctl_rule_priority = 'omci_control',
	omci_misc             = 'omci_control',
	active_sw_version     = 'custo_version',
	ont_version           = 'custo_version',
	ont2g_equipment_id    = 'custo_version'
}

local uci = require 'uci'

local function section_convert(section_name)
	local s_dup = {}
	local uci_rom = uci.alt_cursor('/rom/etc/config', '/tmp/.olduci')
	uci_rom:foreach('gpon', section_name2type[section_name], function(s)
		if s.state == '1' and s['.name'] == section_name  then
			-- copy all options
			for option, value in pairs(s) do
				if type(value) == 'table' then
					-- it is a list option, so an array
					local nv = {}
					for _, v in ipairs(value) do
						nv[#nv+1] = v
					end
					value = nv
				end
				s_dup[option] = value
			end
		end
	end)

	local uci_new = uci.alt_cursor('/etc/config')
	uci_new:foreach('gpon',  section_name2type[section_name], function(s)
		if  s['.name'] == section_name then
			for option, value in pairs(s_dup) do
				-- filter out all intenal option starting with .
				-- handle normal options only
				if string.match(option,"%.*") == '' then
					uci_new:set('gpon', section_name, option, value)
				end
			end
		end
	end)

	uci_new:commit('gpon')
end

--copy section active_sw_version to passive_sw_version
local uci_new2 =uci.alt_cursor('/etc/config')
local state = uci_new2:get('gpon','active_sw_version','state')
local style = uci_new2:get('gpon','active_sw_version','style')
local val = uci_new2:get('gpon','active_sw_version','val')
uci_new2:set('gpon','passive_sw_version','state',state)
uci_new2:set('gpon','passive_sw_version','style',style)
uci_new2:set('gpon','passive_sw_version','val',val)
uci_new2:commit('gpon')

for key, value in pairs(section_to_convert) do
	section_convert(value)
end

