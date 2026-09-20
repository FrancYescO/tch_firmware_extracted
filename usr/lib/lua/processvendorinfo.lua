local uci_cursor = require('uci').cursor()
local dm = require('datamodel')
local logger=require('transformer.logger')
local l=logger.new('processvendorinfo',2)
local open=io.open
local M={}

local suboptioncode={
    acsurl = '1',
    provisioningcode = '2'
}
local acsurl=nil
local pcode=nil
local uci_path_pcode = "uci.env.var.provisioning_code"
local uci_path_voice = "uci.mmpbxrvsipnet.sip_net.user_agent"

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

local function set_uci_value(config, section, option, value)
	local config_file = "/etc/config/" .. config
	-- create config_file if it doesn't exist
	local f = open(config_file)
	if not f then
		f = open(config_file, "w")
		if not f then
			l:error("could not create " .. config_file)
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
	-- if value from uci is the same as value, nothing needs to be done
	local uci_value = uci_cursor:get(config, section, option)
	if uci_value == value then
		return true, true
	end
	-- write uci value
	ret = uci_cursor:set(config, section, option, value)
	if not ret then
		l:error(string.format("could not set %s in %s config", option, config))
		return false
	end
	ret = uci_cursor:commit(config)
	if not ret then
		l:error(string.format("failed to commit changes to %s config", config))
		return false
	end
	return true
end

function M.process(interface,suboptions)
	if not match_cwmp_interface(interface) then
		l:error("Failed to set acs url as cwmp interface does not match")
		return
	end

	if suboptions[suboptioncode["provisioningcode"]] then
		pcode=suboptions[suboptioncode["provisioningcode"]]

		local ret, unchanged = set_uci_value("env", "var", "provisioning_code", pcode)
		if not ret then
			l:error("Failed to set provisioning code from dhcp option 43")
		elseif not unchanged then
			-- set via transformer again tring to trigger transformer event
			local res,errors = dm.set(uci_path_pcode, pcode)
			if not res then
				l:error("Failed to set provisioning code via transformer datamodel")
				if errors and type(errors)=="table" then
					for i,v in ipairs(errors) do
						l:error("error " .. v.errcode .. " : " ..  v.path .. " : " .. v.errmsg)
					end
				end
			end
		end

		ret, unchanged = set_uci_value("mmpbxrvsipnet", "sip_net", "user_agent", pcode)
		if not ret then
			l:error("Failed to set mmpbx sip user agent from dhcp option 43")
		elseif not unchanged then
			-- set via transformer again tring to trigger transformer event
			local res,errors = dm.set(uci_path_voice, pcode)
			if not res then
				l:error("Failed to set mmpbx sip user agent via transformer datamodel")
				if errors and type(errors)=="table" then
					for i,v in ipairs(errors) do
						l:error("error " .. v.errcode .. " : " ..  v.path .. " : " .. v.errmsg)
					end
				end
			end
		end

	else
		l:error("dhcp option 43, suboption " .. suboptioncode["provisioningcode"] .. " not found")
	end

	if suboptions[suboptioncode["acsurl"]] then
		acsurl=suboptions[suboptioncode["acsurl"]]
		local ret, unchanged = set_uci_value("cwmpd", "cwmpd_config", "acs_url", acsurl)
		if not ret then
			l:error("Failed to set acs url from dhcp option 43")
		elseif not unchanged then
			os.execute('/etc/init.d/cwmpd reload')
		end
	else
		l:error("dhcp option 43, suboption " .. suboptioncode["acsurl"] .. " not found")
	end
end

return M
