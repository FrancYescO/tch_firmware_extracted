local uci = require("uci")
local uci_read_cursor = uci.cursor(nil, "/var/state")
local uci_write_cursor = uci.cursor()
local logger=require('transformer.logger')
local l=logger.new('processvendorinfo',2)
local open=io.open
local M={}

local acsurlsuboptioncode='1'
local acsurl=nil
local config = "cwmpd"

local function match_cwmp_interface(interface)
  local ret = uci_read_cursor:load(config)
  if not ret then
    l:error("could not load " .. config)
    return true
  end

  local cwmp_interface = uci_read_cursor:get(config,"cwmpd_config","interface")
  uci_read_cursor:unload(config)
  if cwmp_interface == nil or cwmp_interface:len() == 0 or cwmp_interface == interface then
    return true
  end

  return false
end

local function set_acs_url(acsurl)
  local cwmpd_config_file = "/etc/config/cwmpd"
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

  -- Load write cursor -- Does not take into account /var/state
  local ret = uci_write_cursor:load(config)
  if not ret then
    l:error("could not load " .. config)
    return false
  end

  -- get current ACS url
  local cwmp_acsurl = uci_write_cursor:get(config,"cwmpd_config","acs_url")

  if (cwmp_acsurl and cwmp_acsurl:len() ~= 0 and cwmp_acsurl == acsurl) then
    return true
  end

  -- Get HTTPS enforcing: if set to 1, don't allow a HTTPS->HTTP transition
  local https_enforce = uci_write_cursor:get(config,"cwmpd_config","enforce_https")
  if https_enforce == "1" and cwmp_acsurl and cwmp_acsurl:match("^https://") and acsurl:match("^http://") then
    l:error("Not allowed to transition from HTTPS to HTTP")
    return false
  end
  -- write acs url
  ret = uci_write_cursor:set(config,"cwmpd_config","acs_url",acsurl)
  if not ret then
    l:error("could not set acs url in cwmpd config")
    return false
  end
  ret = uci_write_cursor:commit(config)
  if not ret then
    l:error("failed to commit changes to cwmpd config")
    return false
  end
  os.execute('/etc/init.d/cwmpd reload')
  uci_write_cursor:unload(config)
  return true
end

local function handle_dhcp_option()
  -- Load read cursor
  local ret = uci_read_cursor:load(config)
  if not ret then
    l:error("could not load " .. config)
    return true
  end

  -- acs_url: ignore the acs_url received in DHCP option 43, only if "use_dhcp" flag is
  -- configured and set to "0" (disabled) in the cwmpd config

  local use_dhcp = uci_read_cursor:get(config,"cwmpd_config","use_dhcp")
  uci_read_cursor:unload(config)

  if use_dhcp ~= "0" then
    return true
  end

  return false
end

function M.process(interface,suboptions)
  if not match_cwmp_interface(interface) then
    l:error("Failed to set acs url as cwmp interface does not match")
    return
  end

  if suboptions[acsurlsuboptioncode] then
    acsurl=suboptions[acsurlsuboptioncode]
    if handle_dhcp_option() then
      local ret = set_acs_url(acsurl)
      if not ret then
        l:error("Failed to set acs url from dhcp option 43")
      end
    end
  else
    l:error("dhcp option 43, suboption " .. acsurlsuboptioncode .. " not found")
  end
end

return M

