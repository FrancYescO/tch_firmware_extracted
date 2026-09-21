local uci_cursor = require('uci').cursor()
local logger=require('transformer.logger')
local l=logger.new('processvendorinfo',2)
local open=io.open
local M={}

local acsurlsuboptioncode='1'
local acsurl=nil

local function match_cwmp_interface(interface)
	local config = "cwmpd"

	local ret = uci_cursor:load(config)
	if not ret then
		l:error("could not load " .. config)
		return true
	end

	local cwmp_interface = uci_cursor:get(config,"cwmpd_config","interface")
	if cwmp_interface == nil or cwmp_interface:len() == 0 or cwmp_interface == interface then
		return true
	end

	return false
end

local function set_acs_url(acsurl)
	local cwmpd_config_file = "/etc/config/cwmpd"
	local config = "cwmpd"
	-- create /etc/config/cwmpd if it doesn't exist
	local f = open(cwmpd_config_file)
	if not f then
		f = open(cwmpd_config_file, "w")
		if not f then
			l:error("could not create " .. cwmpd_config_file)
			return false
		end
	end
	f:close()
	-- load cursor
	local ret = uci_cursor:load(config)
	if not ret then
		l:error("could not load " .. config)
		return false
	end
	-- get acs url
	local cwmp_acsurl = uci_cursor:get(config,"cwmpd_config","acs_url")
	if (cwmp_acsurl ~= nil and cwmp_acsurl:len() ~= 0 and cwmp_acsurl == acsurl) then
		return true
	end
	-- write acs url
	ret = uci_cursor:set(config,"cwmpd_config","acs_url",acsurl)
	if not ret then
		l:error("could not set acs url in cwmpd config")
		return false
	end
	ret = uci_cursor:commit(config)
	if not ret then
		l:error("failed to commit changes to cwmpd config")
		return false
	end
	os.execute('/etc/init.d/cwmpd reload')
	return true
end

function M.process(interface,suboptions)
	if not match_cwmp_interface(interface) then
		l:error("Failed to set acs url as cwmp interface does not match")
		return
	end

	if suboptions[acsurlsuboptioncode] then
		acsurl=suboptions[acsurlsuboptioncode]
		local ret = set_acs_url(acsurl)
		if not ret then
			l:error("Failed to set acs url from dhcp option 43")
		end
	else
		l:error("dhcp option 43, suboption " .. acsurlsuboptioncode .. " not found")
	end
end

return M

