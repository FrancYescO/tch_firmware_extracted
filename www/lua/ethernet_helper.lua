local M = {}

-- Process POST query
local bit = require("bit")
local proxy = require("datamodel")
local pairs, string ,ipairs, ngx = pairs, string, ipairs, ngx
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local tonumber, tostring = tonumber, tostring
local match, format, lower, untaint = string.match, string.format, string.lower, string.untaint
local ipv42num = post_helper.ipv42num
local num2ipv4 = post_helper.num2ipv4
local session = ngx.ctx.session

local curintf = "lan"
local cur_dhcp_intf = "lan"
local baseDHCPOptions = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".dhcp_option."
local dhcpData = {}
local dhcp_intfs_path = "uci.dhcp.dhcp."
local all_dhcp_intfs = content_helper.convertResultToObject(dhcp_intfs_path .. "@.", proxy.get(dhcp_intfs_path))
-- Get all the LAN interfaces
local rpcNetworkPath = "rpc.network.interface."
local all_intfs = content_helper.convertResultToObject(rpcNetworkPath .. "@.", proxy.get(rpcNetworkPath))
local lan_intfs = post_helper.getAllNonWirelessInterfaces(all_intfs)
local publicIPValidation = post_helper.publicIPValidation
local intf_list = {}
local timHelperPresent, tim_helper = pcall(require, "tim_helper")

-- Translation initialization. Every function relying on translation MUST call setlanguage to ensure the current
-- language is correctly set (it will fetch the language set by web.web and use it)
-- We create a dedicated context for the web framework (since we cannot easily access the context of the current page)
local intl = require("web.intl")
local function log_gettext_error(msg)
    ngx.log(ngx.NOTICE, msg)
end
local gettext = intl.load_gettext(log_gettext_error)
local T = gettext.gettext
local N = gettext.ngettext
gettext.textdomain('webui-core')
local function setlanguage()
    gettext.language(ngx.header['Content-Language'])
end

-- Updates the current interface and other data used in the validation functions
-- @param #intf current interface name
function M.updateCurInterface(intf)
  if intf then
    curintf = intf
  end
  intf_list = {}

  for _, dhcp_intfs in ipairs(all_dhcp_intfs) do
    if dhcp_intfs.interface == curintf then
      if dhcp_intfs.paramindex == "STB" then
        intf_list[#intf_list+1 ] = dhcp_intfs.paramindex
      end
      cur_dhcp_intf = dhcp_intfs.paramindex
    end
  end

  baseDHCPOptions = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".dhcp_option."

  for _, intfs in ipairs(all_intfs) do
    if intfs.paramindex == curintf then
      if intfs.paramindex:match("Guest1") then
        intf_list[#intf_list+1 ] = intfs.paramindex.."_private"
      else
        intf_list[#intf_list +1 ] = intfs.paramindex
      end
      curintf = intfs.paramindex
    end
  end
end

local function getDHCPData(object, interface)
  -- Check the entered IP is valid IP and convert it to number
  local validateStringIP = post_helper.validateStringIsIP()
  local baseip = validateStringIP(object.localdevIP) and ipv42num(object.localdevIP)
  local netmask = validateStringIP(object.localdevmask) and ipv42num(object.localdevmask)
  local dhcpstart = validateStringIP(object["dhcpStartAddress"..interface]) and ipv42num(object["dhcpStartAddress"..interface])
  local dhcpend = validateStringIP(object["dhcpEndAddress"..interface]) and ipv42num(object["dhcpEndAddress"..interface])
  return baseip, netmask, dhcpstart, dhcpend
end

local STB_IP = {
  start = "uci.dhcp.dhcp.@STB.start",
  limit = "uci.dhcp.dhcp.@STB.limit"
}
content_helper.getExactContent(STB_IP)

function M.calculateSTBRange(object)
  local DHCPStartAndLimitAddress = post_helper.DHCPStartAndLimitAddress
  local stbstart = object.dhcpStartSTB
  local stblimit = object.dhcpLimitSTB
  if not stbstart or not stblimit then
    stbstart = STB_IP.start
    stblimit = STB_IP.limit
  end
  local baseip, netmask = getDHCPData(object, "lan")
  if baseip and netmask then
    baseip = num2ipv4(baseip)
    netmask = num2ipv4(netmask)
    local stbStart, stbEnd = DHCPStartAndLimitAddress(baseip, netmask, tonumber(stbstart), tonumber(stblimit))
    if stbStart then
      return ipv42num(stbStart), ipv42num(stbEnd)
    end
  end
end

function M.STBCheck(object, ipStart, ipEnd, startend)
  if ipStart and ipEnd and all_dhcp_intfs[1].paramindex == "STB" then
    local stbStart, stbEnd = M.calculateSTBRange(object)
    local ipAddr = startend == "start" and ipStart or ipEnd
    if stbStart and stbEnd then
      if (ipAddr >= stbStart and ipAddr <= stbEnd) or (ipStart <= stbStart and ipEnd >= stbEnd) then
        return nil, T"Lan pool range overlaps with the STB pool range"
      end
    end
  end
  return true
end

-- Validation is done for the dhcpLimit for the particular subnet
-- If different subnet mask is given other than 255.255.255.0, then the
-- DHCP Range limit has to be calculated from the new subnet and the validation
-- has to be done for the new limit.
function M.validateLimit(value, object, key)
  setlanguage()
  for _, intf in pairs(intf_list) do
    if key:match(intf) then
      if object["dhcpEndAddress"..intf] then
        local isReserved, msg = post_helper.reservedIPValidation(object["dhcpEndAddress"..intf])
        if not isReserved then
          return nil, msg
        end
        local isLXC, errMsg = post_helper.validateLXC(object["dhcpEndAddress"..intf])
        if not isLXC then
          return nil, errMsg
        end
        if value then
          local baseip, netmask, dhcpstart, dhcpend = getDHCPData(object, intf)
          if intf ~= "STB" then
            local success, errmsg = M.STBCheck(object, dhcpstart, dhcpend, "end")
            if not success then
              return nil, errmsg
            end
          end
          if not dhcpend then
            return nil, format(T"DHCP %s End Address is Invalid", intf)
          end
          if dhcpstart and dhcpstart > dhcpend then
            return nil, format(T"DHCP %s Start Address should not be greater than End Address", intf)
          end
          if baseip and netmask and dhcpstart then
            local network = bit.band(baseip, netmask)
            local ipmax = bit.bor(network, bit.bnot(netmask))
            local numips = dhcpend - dhcpstart + 1
            local limit = ipmax - network - 1
            if dhcpend == ipmax then
              return nil, T"Broadcast Address should not be used"
            end
            local validateNumberInRange = post_helper.getValidateNumberInRange
            local validatorNumberInRange = validateNumberInRange(1, limit)
            local limitvalue =  validatorNumberInRange(numips)
            if not limitvalue or dhcpend <= network or dhcpend >= ipmax then
              return nil, format(T"DHCP %s End Address is not valid in Subnet Range", intf)
            end
            return true
          else
            return nil
          end
        else
          return nil, format(T"DHCP %s End Address is Invalid", intf)
        end
      else
       return false, format(T"DHCP %s End Address is Invalid", intf)
      end
    end
  end
end

-- Validation is done for the DHCP start Address for the particular subnet
-- For different subnets, validation for dhcpStart Address has to be done
-- from the new DHCP Range with respect to the subnet mask & Network Address
function M.validateDHCPStart(value, object, key)
  setlanguage()
  for _, intf in pairs(intf_list) do
    if key:match(intf) then
      if object["dhcpStartAddress"..intf] then
        local isReserved, msg = post_helper.reservedIPValidation(object["dhcpStartAddress"..intf])
        if not isReserved then
          return nil, msg
        end
        local isLXC, errMsg = post_helper.validateLXC(object["dhcpStartAddress"..intf])
        if not isLXC then
          return nil, errMsg
        end
        if match(value, "^[0-9]*$") then
          local baseip, netmask, dhcpstart, dhcpend = getDHCPData(object, intf)
          if intf ~= "STB" then
            local success, errmsg = M.STBCheck(object, dhcpstart, dhcpend, "start")
            if not success then
              return nil, errmsg
            end
          end
          if not dhcpstart then
            return nil, format(T"DHCP %s Start Address is Invalid", intf)
          end
          if baseip and netmask and dhcpend then
            local network = bit.band(baseip, netmask)
            local ipmax = bit.bor(network, bit.bnot(netmask))
            local start = dhcpstart - network
            local numips = dhcpend - dhcpstart + 1
            local limit = ipmax - network - 1
            local validateNumberInRange = post_helper.getValidateNumberInRange
            local validatorNumberInRange = validateNumberInRange(1, limit)
            if dhcpstart == baseip then
              return nil, format(T"DHCP %s Start Address should not be Local Device IP Address", intf)
            elseif dhcpstart == network then
              return nil, format(T"DHCP %s Start Address should not be a Network Address", intf)
            end
            local val = validatorNumberInRange(start)
            if not val or dhcpstart <= network or dhcpstart >= ipmax then
              return nil, format(T"DHCP %s Start Address is not valid in Subnet Range", intf)
            end
            -- Setting the dhcpStart and dhcpLimit from the calculated DHCP Range
            object[key] = tostring(start)
            object["dhcpLimit"..intf] = tostring(numips)
            return true
          else
            return false
          end
        else
          return nil, format(T"DHCP %s Start Address is Invalid", intf)
        end
      else
        return nil, format(T"DHCP %s Start Address is Invalid", intf)
      end
    end
  end
end

function M.ethtrans()
  setlanguage()
  return {
    eth_infinit = T"infinite"
  }
end

function M.validateLeaseTime(value, postdata, key)
  value = type(value) == "userdata" and untaint(value) or value
  if value == '-1' or value == "infinite" then -- included '-1' as a feasible set value as specified in TR 181
    postdata[key] = "infinite" -- included to ensure uci parameter is set as infinite
    return true
  else
    local isLeaseTime, msg = post_helper.validateStringIsLeaseTime(value)
    if isLeaseTime then
      postdata[key] = match(value, "^0*([1-9]%d*[smhdw]?)$")
      return true
    else
      return nil, msg
    end
  end
end

local ethports = {
  {"port1", "port1"}
}

-- Generic solution for boards without eth1/2/3
local ethport_count = 0
for index = 1, 3 do
  local ethport = "eth" .. index
  local port = "port" .. (index+1)
  local path = "uci.ethernet.port.@" .. ethport .. "."
  local value = proxy.get(path .. "duplex")
  if value ~= nil then
    ethport_count = ethport_count + 1
    table.insert(ethports, {port, port})
  end
end

-- Function to avoid users to enter ReservedStatic name as custom static lease name
function M.sleasesNameValidation(sleaseName)
  if (sleaseName:find("^ReservedStatic")) then
    return nil, T"Cannot use reserved names as static lease name"
  end
  return true
end

function M.sleasesMacValidation(value, object, key)
  local staticMacAddr, macErrMsg = post_helper.validateStringIsMAC(value)
  if staticMacAddr then
    if lower(value) == "ff:ff:ff:ff:ff:ff" then
      return nil, T"The requested MAC address can't be the broadcast MAC"
    else
      value = value:match("^%x%x%-%x%x%-%x%x%-%x%x%-%x%x%-%x%x$") and value:gsub("-",":") or value
      object[key] = lower(value)
    end
  end
  return staticMacAddr, macErrMsg
end

function M.sleasesIpValidation(value, object, key)
  local contentdata = {
    localdevIP = "uci.network.interface.@" .. curintf .. ".ipaddr",
    localdevmask = "uci.network.interface.@" .. curintf .. ".netmask"
  }
  content_helper.getExactContent(contentdata)
  local staticMacAddr, macErrMsg= post_helper.staticLeaseIPValidation(value, contentdata)
  return post_helper.staticLeaseIPValidation(value, contentdata)
end

function M.validateDNS(value, object, key)
  local validateNetMask = post_helper.validateIPv4Netmask
  -- If there is no value, then we want to delete the dhcp_option if it exists
  -- Otherwise, we want to check the value is an IP
  if value == "" then
    -- if the key does not exist, no harm done
    proxy.del(object[key]:sub(1,-6))
    -- remove the value, there is nothing to set
    object[key] = nil
    dnsRemoved = true
    return true
  else
    local dns = {}
    for ip_Address in string.gmatch(value, '([^,]+)') do
      dns[#dns + 1] = ip_Address
      local success, errmsg = post_helper.reservedIPValidation(ip_Address)
      if not success then
        return nil, errmsg
      end

      local validateStringIP = post_helper.validateStringIsIP()
      local valid, helpmsg_validip = post_helper.getAndValidation(validateStringIP(ip_Address, object, key), post_helper.validateLXC)
      if valid then
        local isNetmask = validateNetMask(ip_Address)
        if isNetmask then
          return nil, T"Cannot use netmask as DNS server IP"
        end
        local success, errormsg = post_helper.DNSIPValidation(ip_Address, object)
        if not success then
          return nil, errormsg
        end
        --[[Comment out as DNS Servers should be allowed to be public IP's
        if publicIPValidation(value, object, key) then
          return nil, T"Public IP Range should not be used"
        end
        ]]
      else
        return nil, helpmsg_validip
      end
    end
    if #dns > 3 then
      return nil, nil
    end
     object[key] = "6," .. value -- DHCP option for DNS server is option 6
     return true
  end
end

-- Updates and validates default gateway field
-- @param #string value Expected default gateway
-- @return #boolean true if data is good or nil and error message
function M.validateDefaultGateway(value)
  setlanguage()
  local validateStringIP = post_helper.validateStringIsIP()
  content_helper.addListContent(dhcpData, { options = baseDHCPOptions } )
  local gwPos = #dhcpData.options + 1
  local gwPath = format("%s@%s.value", baseDHCPOptions, gwPos)
  local baseGwPath, tag_or_path, errmsg, code
  local gwExists = false
  -- tag_or_path: keeps track of instance/path pointing to Default Gateway DHCP option entry
  -- errmsg:      error message generated from proxy.add() call on failure
  -- code:        error code generated from proxy.add() call on failure
  for _, dhcpOpts in ipairs(dhcpData.options) do
    if dhcpOpts:find("^3,") == 1 then
      -- since index values between dhcp table and transformer mapping are most likely inconsistent
      -- need to acquire exact path of existing default gateway option
      -- this function returns after matching a single value (we're only using one default gateway)
      local dhcpContent = content_helper.getMatchedContent(baseDHCPOptions, { value = dhcpOpts }, 1)
      if #dhcpContent > 0 then
        for _, dhcpContentVal in ipairs(dhcpContent) do
          baseGwPath = dhcpContentVal.path
          gwPath = baseGwPath .. "value"
        end
      end
      gwExists = true
      break
    end
  end
  -- check to create new DHCP option entry
  if gwExists == false and value ~= "" then
    tag_or_path, errmsg, code = proxy.add(baseDHCPOptions)
  end
  -- check and update user setting
  if value and value ~= "" then
    -- make sure data is in proper format
    local isIP, errMsg = validateStringIP(value)
    if not isIP and value ~= "" then
      if gwExists == false then
        -- undo dhcp_option entry added if we don't have a valid IPv4 address
        proxy.del(format("%s@%s.", baseDHCPOptions, tag_or_path))
      end
      return nil, errMsg
    end
    -- finally, do the update
    proxy.set(gwPath, format("3,%s", value))
  elseif value == "" then
    -- remove default gateway entry
    proxy.del(baseGwPath)
  else
    return nil, T"Something went wrong during default gateway update"
  end
  -- commit & apply
  proxy.apply()
  return true
end

--This function will validate modem IP address should not be
--Any of active portfowarding IP address
local function isPfwIP(value)
local pfw_path = proxy.get("rpc.network.firewall.portforward.")
local pfw_data = content_helper.convertResultToObject("rpc.network.firewall.portforward.", pfw_path)
  for k,v in ipairs(pfw_data) do
    if v.dest_ip and v.dest_ip == value then
      return false
    end
  end
  return true
end

-- This function will validate the Modem IP Address and check for
-- Valid IP Format, Limited Broadcast Address, Public IP Range, Multicast Address Range
function M.validateGWIP(value, object, key)
  setlanguage()
  local advancedIP = post_helper.advancedIPValidation
  local publicIP = post_helper.isPublicIP
  local val, errmsg = advancedIP(value, object, key)
  all_intfs = content_helper.convertResultToObject(rpcNetworkPath .. "@.", proxy.get(rpcNetworkPath))
  if not val then
    return nil, errmsg
  end
  if not isPfwIP(value) then
    return nil, T"Active Portforwarding IP cannot be configured"
  end
  local isWan, interface = post_helper.isWANIP(value, all_intfs)
  if isWan then
    return nil, format(T"Gateway IP should not be in %s IP Range", interface)
  end
  local isLan, intfs = false, ""
  if timHelperPresent then
    isLan, intfs = tim_helper.isIPinOtherRange(value, object["localdevmask"], all_intfs, curintf)
  else
    isLan, intfs = post_helper.isLANIP(value, all_intfs, curintf)
  end
  if isLan then
    for _, value in pairs(all_intfs) do
      if intfs == value.paramindex then
        return nil, format(T"Gateway IP should not be in %s IP Range", value.name ~= "" and value.name or intfs)
      end
    end
  end
  if value and publicIP(value) then
    return nil, T"Public IP Range should not be used"
  end

  local ip = ipv42num(value)
  for _, intf in pairs(lan_intfs) do
    if intf.index ~= curintf then
      local localIPMask = {
        ipaddr = "uci.network.interface.@" .. intf.index .. ".ipaddr",
        mask = "uci.network.interface.@" .. intf.index .. ".netmask"
      }
      content_helper.getExactContent(localIPMask)
      local validateStringIP = post_helper.validateStringIsIP()
      local baseip = validateStringIP(localIPMask.ipaddr) and ipv42num(localIPMask.ipaddr)
      local netmask = validateStringIP(localIPMask.mask) and ipv42num(localIPMask.mask)

      local network, ipmax
      if baseip and netmask then
        network = bit.band(baseip, netmask)
        ipmax = bit.bor(network, bit.bnot(netmask))
      end

      if network and ipmax then
        if ip >= network and ip <= ipmax then
          if intf.name ~= "" then
            return nil, format(T"Gateway IP should not be in %s IP Range", intf.name)
          end
        end
      end
    end
  end
  return true
end

local function isChecked(key, checked)
  if type(checked) == "table" then
    for _, check in ipairs(checked) do
      if check == key then
        return true
      end
    end
  end
  return false
end

function M.validateEthports(value, object, key)
  local validateCheckbox = post_helper.getValidateInCheckboxgroup
  local getValidateEthports = validateCheckbox(ethports)
  local ok, msg = getValidateEthports(value, object, key)

  if not ok then
    return ok, msg
  end

  for _, eth_port in ipairs(ethports) do
    object[eth_port[1]] = nil
    object[eth_port[1]] = isChecked(eth_port[1], value) and "1" or "0"
  end

  return true
end

return M
