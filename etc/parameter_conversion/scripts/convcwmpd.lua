local uc = require("uciconv")
local o = uc.uci('old')
local n = uc.uci('new')

local scenario = o:get('env', 'custovar_sensing', 'Scenario')
local oper_acs_url = o:get('cwmpd', 'cwmpd_config', 'acs_url')
local oper_acs_user= o:get('cwmpd', 'cwmpd_config', 'acs_user')
local oper_acs_pass= o:get('cwmpd', 'cwmpd_config', 'acs_pass')
local oper_connectionrequest_username = o:get('cwmpd', 'cwmpd_config', 'connectionrequest_username')
local oper_connectionrequest_password = o:get('cwmpd', 'cwmpd_config', 'connectionrequest_password')
local oper_periodicinform_enable = o:get('cwmpd', 'cwmpd_config', 'periodicinform_enable')
local oper_periodicinform_interval = o:get('cwmpd', 'cwmpd_config', 'periodicinform_interval')

local section = scenario == "1" and "operationalACS2" or "operationalACS1"

n:set('cwmpd', section, 'acs_url', oper_acs_url)
n:set('cwmpd', section, 'acs_user', oper_acs_user)
n:set('cwmpd', section, 'acs_pass', oper_acs_pass)
n:set('cwmpd', section, 'connectionrequest_username', oper_connectionrequest_username)
n:set('cwmpd', section, 'connectionrequest_password', oper_connectionrequest_password)
n:set('cwmpd', section, 'periodicinform_enable', oper_periodicinform_enable)
n:set('cwmpd', section, 'periodicinform_interval', oper_periodicinform_interval)

n:commit('cwmpd')
