--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

-- Process POST query
local bit = require("bit")
local proxy = require("datamodel")
local lfs = require("lfs")
local pairs, string ,ipairs, ngx = pairs, string, ipairs, ngx
local session = ngx.ctx.session
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local uinetwork = require("web.uinetwork_helper")
local hosts_ac = uinetwork.getAutocompleteHostsList()
local tonumber, tostring = tonumber, tostring
local content, helpmsg
local match, format = string.match, string.format
local find, untaint = string.find, string.untaint
local ipv42num = post_helper.ipv42num
local broadcast_ip =post_helper.ipv42num("255.255.255.255")

-- Shortcuts to validation helpers to make lines shorter
local aIPV = post_helper.advancedIPValidation
local vB = post_helper.validateBoolean
local vIP4N = post_helper.validateIPv4Netmask
local vQTN = post_helper.validateQTN
local gAV = post_helper.getAndValidation
local gVIC = post_helper.getValidateInCheckboxgroup
local gVIES = post_helper.getValidateInEnumSelect
local validateDHCPIgnore = post_helper.validateDHCPIgnore
local pIPV = post_helper.isPublicIP

local dhcpDefaultExist
local hosts_mac = {}
for k, v in pairs(hosts_ac) do
    local mac = match(k, "%[(.*)%]")
    hosts_mac[#hosts_mac+1] = {mac, mac}
end

hosts_mac[#hosts_mac+1] = {"custom",T"custom"}

if lfs.attributes("/www/lua/dhcpreset_helper.lua", "mode") == "file" then
   dhcpDefaultExist = require("dhcpreset_helper")
end

local function num2ipv4(ip)
    local ret = bit.band(ip, 255)
    ip = bit.rshift(ip,8)
    for i=1,3 do
        ret = bit.band(ip,255) .. "." .. ret
        ip = bit.rshift(ip,8)
    end
    return ret
end

local getargs = ngx.req.get_uri_args()
local getintf = getargs.intf

local curintf = "lan"
-- Get all the LAN interfaces
local net_intfs_path = "rpc.network.interface."
local all_intfs = content_helper.convertResultToObject(net_intfs_path .. "@.", proxy.get(net_intfs_path))
local wireless_radio = {}
for i,v in ipairs(proxy.getPN("rpc.wireless.ssid.", true)) do
  local radios = match(v.path, "rpc%.wireless%.ssid%.@([^%.]+)%.")
  if radios then
    wireless_radio[radios] = true
  end
end
local lan_intfs = {}
local pppIntf, pppDev
for k,v in ipairs(all_intfs) do
    if v.type == "lan" and (not find(v["ppp.ll_intf"], "wl") or wireless_radio[untaint(v["ppp.ll_intf"])])then
         if v.paramindex ~= "lan_public" then
		if v.name and v.name ~= "" then
			lan_intfs[#lan_intfs + 1] = {name = v.name, index = v.paramindex}
		else
			lan_intfs[#lan_intfs + 1] = {name = v.paramindex, index = v.paramindex}
		end
         end
    end
    if v.paramindex == getintf then
        curintf = v.paramindex
        pppDev = v["ppp.ll_dev"]
        pppIntf = v["ppp.ll_intf"]
    end
end

local IP6assign = "uci.network.interface.@" .. curintf .. ".ip6assign"

local mapParam = {
  localIPv6 = "uci.network.interface.@" .. curintf .. ".ipv6"
}
local function validateIPv6(value, object, key)
    local valid, msg = post_helper.validateBoolean(value, object, key)
    if valid then
        if value == "0" then
            -- In case we disable IPv6, we must first invalidate the existing prefix so that local devices know not to use IPv6 anymore
            -- Do this here by set the ip6assign pref and only on ipv6 state change
            local ipv6 = proxy.get(mapParam["localIPv6"]) -- get current value in datamodel to know if we're switching state
            if ipv6 and ipv6.value ~= "0" then -- default is enabled so anything non 0 is enabled
                proxy.set(IP6assign, "0") -- the value will be set back to its current value by process_query
                proxy.apply()
                ngx.sleep(3) -- ugly but need to give it the time to complete
            end
        else
            proxy.set(IP6assign, "64")
            proxy.apply()
        end
        if isQtnGuestWiFi(pppDev) then
            local ucipath = content_helper.getMatchedContent("uci.network.device.",{ifname = pppIntf})
            if ucipath and #ucipath > 0 then
               proxy.set(ucipath[1].path .. "ipv6", value)
            end
        end
        -- Modify IPv6 at WAN-side accordingly:
        -- this is especially necessary to make sure Neighbor Solicitation (for DAD etc.) messages are sent upon network reload
        proxy.set("uci.network.interface.@wan.ipv6", value)
        proxy.apply()
    end
    return valid, msg
end
--We need to update IPv6 state only when user want to update the IPv6 state alone.
if ngx.var.request_method == "POST" and ngx.req.get_post_args().iPv6StateOnlyChanged == "yes" then
  local validation = {
    localIPv6 = validateIPv6,
  }
  post_helper.handleQuery(mapParam, validation)
  ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  ngx.exit(ngx.HTTP_OK)
end
-- Static leases
local sleases_columns = {
  {
    header = T"Hostname",
    name = "sleases_name",
    param = "name",
    type = "text",
    attr = { input = { class="span2", maxlength="63" } },
  },
  {
    header = T"MAC address",
    name = "sleases_mac",
    param = "mac",
    type = "select",
    values = hosts_mac,
    attr = { input = { class="span2", maxlength="17", id= "lease_mac" }, autocomplete=hosts_mac },
    unique = true,
  },
  {
    header = T"IP",
    name = "sleases_ip",
    param = "ip",
    type = "text",
    attr = { input = { class="span2", maxlength="15"}, autocomplete=hosts_ac },
    unique = true,
  },
  {
    header = "",
    name = "sleases_owner",
    param = "owner",
    type = "hidden",
    readonly = true,
    attr = { },
  },
}

-- Function to avoid users to enter ReservedStatic name as custom static lease name
local function sleases_name_validation(value)
  if (value:find("^ReservedStatic") ~= nil) then
    return nil, T"Cannot use reserved names as static lease name"
  end
  return true
end

local function sleases_mac_validation(value, object, key)
  local r1, r2 = post_helper.validateStringIsMAC(value)
  if r1 then
    if string.lower(value) == "ff:ff:ff:ff:ff:ff" then
        return nil, T"The requested MAC address can't be the broadcast MAC"
    else
        object[key] = string.lower(value)
    end
  end
  return r1, r2
end

-- Function to check the input IP is in Reserved IP list
local function reserved_ip_validation(value)
    local reservedList = {}
    local reservedIPList = proxy.get("uci.dhcp.host.")
    reservedIPList = content_helper.convertResultToObject("uci.dhcp.host.", reservedIPList)
    if reservedIPList then
        for _,v in pairs(reservedIPList) do
            if v["name"]:find("^ReservedStatic") ~= nil then
                reservedList[#reservedList + 1] = v["ip"]
                if value == v["ip"] then
                    return nil
                end
            end
        end
    end
    return true
end

local function sleases_ip_validation(value, object, key)
    local contentdata = {
      localdevIP = "uci.network.interface.@" .. curintf .. ".ipaddr",
      localdevmask = "uci.network.interface.@" .. curintf .. ".netmask",
    }
    content_helper.getExactContent(contentdata)
    return post_helper.staticLeaseIPValidation(value, contentdata)
end

local sleases_valid = {
    sleases_name = gAV(sleases_name_validation,post_helper.validateStringIsDomainName),
    sleases_mac = gAV(sleases_mac_validation,vQTN),
    sleases_ip = gAV(sleases_ip_validation,vQTN),
}

local sleases_options = {
    tableid = "sleases",
    basepath = "uci.dhcp.host.@.",
    createMsg = T"Add new static lease",
    objectName  = post_helper.getRandomKey(),
    addNamedObject = true,
}


local syshosts_data = proxy.get("sys.hosts.host.")
local sleases_filter = function(data)
    if data['owner'] == "portforward" then
        local path
        if syshosts_data then
            for _, v in pairs(syshosts_data) do
                if v.value == data['mac'] then
                    path = v.path
                    break
                end
            end
            for _, v in pairs(syshosts_data) do
                if v.path == path and v.param == "HostName" then
                    data['name'] = v.value
                    break
                end
            end
        end
        return { canEdit = false, canDelete = false }
    end
    if (data['name']:find("^ReservedStatic") == 1) then
       return false
    end
    return true
end

local sleases_data, sleases_helpmsg = post_helper.handleTableQuery(sleases_columns, sleases_options, sleases_filter, nil, sleases_valid)

local inUseFlag = false
if ngx.var.request_method == "POST" then
  local post_data = ngx.req.get_post_args()
  if ( post_data.action == "TABLE-MODIFY" or  post_data.action == "TABLE-EDIT"  or  post_data.action == "TABLE-ADD") then
    local text_mac_index = tonumber(post_data.index)
    local text_mac
    if  post_data.action == "TABLE-ADD" then
      text_mac = post_data["sleases_mac"]
    else
      text_mac = sleases_data[text_mac_index][2]
    end
    local flag = true
    for _,j in ipairs(hosts_mac) do
      if text_mac == j[1] then
        flag = false
        break
      end
    end
    if flag   then
      sleases_columns[2] = {
        header = T"MAC address",
        name = "sleases_mac",
        param = "mac",
        type = "text",
        attr = { input = { class="span2", maxlength="17", id= "lease_mac", value = text_mac }},
        unique = true,
      }
    end
    if post_data.action == "TABLE-MODIFY" or  post_data.action == "TABLE-ADD" then
      local slease_ip = post_data.sleases_ip
      local arranged_data = content_helper.convertResultToObject("sys.hosts.host.", syshosts_data)
      if arranged_data then
        for _, v in pairs(arranged_data) do
            if v.DhcpLeaseTime ~= "" and v.IPAddress == slease_ip then
                inUseFlag = true
                break
           end
        end
      end
    end
  end
end

local cur_dhcp_intf = "lan"
local dhcp_intfs_path = "uci.dhcp.dhcp."
local all_dhcp_intfs = content_helper.convertResultToObject(dhcp_intfs_path .. "@.", proxy.get(dhcp_intfs_path))

for k,v in ipairs(all_dhcp_intfs) do
    if v.interface == curintf then
        cur_dhcp_intf = v.paramindex
        break
    end
end
-- Standard parameters
local mapParams = {
    dhcpStart = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".start",
    dhcpLimit = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".limit",
    dhcpv4State = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".dhcpv4",
    dhcpIgnore = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".ignore",
    leaseTime = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".leasetime",
    localdevIP = "uci.network.interface.@" .. curintf .. ".ipaddr",
    localdevmask = "uci.network.interface.@" .. curintf .. ".netmask",
    localIPv6 = "uci.network.interface.@" .. curintf .. ".ipv6",
    eth0 = "uci.ethernet.port.@eth0.enable",
}

local ethports = {
    {"eth0", "eth1"},
}

-- Generic solution for boards without eth1/2/3
local ethport_count = 0
for i = 1, 3 do
    local ethport = "eth" .. i
    local ethportplus1 =  "eth" .. i+1
    local path = "uci.ethernet.port.@" .. ethport .. "."
    local v = proxy.get(path .. "duplex")
    if v ~= nil then
        ethport_count = ethport_count + 1
        table.insert(ethports, {ethport, ethportplus1})
        mapParams[ethport] = path .. "enable"
    end
end

local dnsIndex
local dhcp = {}
local baseDHCPOptions = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".dhcp_option."
local dnsRemoved = false

-- Check if there is a custom DNS server, if so, then retrieve its index
-- we'll update the parameters list to include it for retrieval
dhcp.options = proxy.get(baseDHCPOptions)
dnsIndex = #dhcp.options + 1 -- by default index is end of list

for i,v in ipairs(dhcp.options) do
    if v.value:find("^6,") == 1 then
        dnsIndex = tonumber(string.match(v.path, "%.@(%d+)%.$"))
    end
end

local function validateDNS(value, object, key)
    -- If there is no value, then we want to delete the dhcp_option if it exists
    -- Otherwise, we want to check the value is an IP
    if value == "" then
        -- if the key does not exist, no harm done
        proxy.del(mapParams[key]:sub(1,-6))
        -- remove the value, there is nothing to set
        object[key] = nil
        dnsRemoved = true
        return true
    else
        local dns = {}
        for ip_Address in string.gmatch(value, '([^,]+)') do
          dns[#dns + 1] = ip_Address
	  local valid, helpmsg_validip = post_helper.validateStringIsIP(ip_Address, object, key)
	  if valid then
             --if pIPV(value) then
             --   return nil, T"Public IP Range should not be used"
             --end
	     -- Check for Limited Broadcast IP Address and "0.0.0.0" IP Address
             local ipAddr = ipv42num(ip_Address)
	     if ipAddr == broadcast_ip or ipAddr == 0 then
		return nil, T"Invalid IP Address"
             end
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

function isQtnGuestWiFi(intf)
  if wireless_radio[untaint(intf)] then
     local radio = proxy.get(format("rpc.wireless.ssid.@%s.radio", intf))
     local isRemote = proxy.get(format("rpc.wireless.radio.@%s.remotely_managed", radio[1].value))
     if isRemote and isRemote[1].value == "1" then
        for _, v in ipairs(proxy.getPN("rpc.wireless.ap.", true)) do
          local isGuest = proxy.get(v.path.."ap_isolation")
          if isGuest and isGuest[1].value == "1" then
            return true
          end
        end
     end
  end
end

local function validateLeaseTime(value, postdata, key)
   if value == '-1' then -- included '-1' as a feasible set value as specified in TR 181
      postdata[key] = "infinite" -- included to ensure uci parameter is set as infinite
      return true
   else
      local success, msg = post_helper.validateStringIsLeaseTime(value)
      if success then
         postdata["leaseTime"] = match(untaint(value), "^0*([1-9]%d*[smhdw]?)$")
         return true
      else
         return nil, msg
      end
   end
end
--[[
Function calculateDHCPStartAddress, Calculating DHCPStartaddress using localdeviceip, netmask, newstart and newlimit value. function returns DHCPStartAddress, DHCPEndAddress  and NetworkAddress
]]
local function calculateDHCPStartAddress (baseip, netmask, start, numips)
    local network = bit.band(baseip, netmask)
    local ipmax = bit.bor(network, bit.bnot(netmask)) - 1
    local ipstart = bit.bor(network, bit.band(start, bit.bnot(netmask)))
    local ipend = ipstart+numips-1
    ipstart = num2ipv4(ipstart)
    if ipend > ipmax then
      ipend = ipmax
    end
    ipend = num2ipv4(ipend)
    network = num2ipv4(network)
  return ipstart,ipend,network
end

local function getDHCPData(object)
  -- Check the entered IP is valid IP and convert it to number
  local baseip = post_helper.validateStringIsIP(object["localdevIP"]) and ipv42num(object["localdevIP"])
  local netmask = post_helper.validateStringIsIP(object["localdevmask"]) and ipv42num(object["localdevmask"])
  local dhcpstart = post_helper.validateStringIsIP(object["dhcpStartAddress"]) and ipv42num(object["dhcpStartAddress"])
  local dhcpend = post_helper.validateStringIsIP(object["dhcpEndAddress"]) and ipv42num(object["dhcpEndAddress"])

  return baseip, netmask, dhcpstart, dhcpend
end

-- Validation is done for the dhcpLimit for the particular subnet
-- If different subnet mask is given other than 255.255.255.0, then the
-- DHCP Range limit has to be calculated from the new subnet and the validation
-- has to be done for the new limit.
local function validateLimit(value, object)
  if match(value, "^[0-9]*$") then
    local baseip, netmask, dhcpstart, dhcpend = getDHCPData(object)

    if not dhcpend then
       return nil, T"DHCP End Address is Invalid"
    end

    if dhcpstart and dhcpstart > dhcpend then
       return nil, T"DHCP Start Address should not be greater than End Address"
    end

    if baseip and netmask and dhcpstart then
      local network = bit.band(baseip, netmask)
      local ipmax = bit.bor(network, bit.bnot(netmask))
      local numips = dhcpend - dhcpstart + 1
      local limit = ipmax - network - 1

      if dhcpend == ipmax then
          return nil, T"Broadcast Address should not be used"
      end

      local validatorNumberInRange = post_helper.getValidateNumberInRange(1,limit)
      local limitvalue =  validatorNumberInRange(numips)
      if not limitvalue or dhcpend <= network or dhcpend >= ipmax then
          return nil, T"DHCP End Address is not valid in Subnet Range"
      end
      return true
    else
      return nil
    end
  else
    return nil, T"DHCP End Address is Invalid"
  end
end

-- Validation is done for the DHCP start Address for the particular subnet
-- For different subnets, validation for dhcpStart Address has to be done
-- from the new DHCP Range with respect to the subnet mask & Network Address
local function validateDHCPStart(value, object)
    if match(value, "^[0-9]*$") then
      local baseip, netmask, dhcpstart, dhcpend = getDHCPData(object)

      if not dhcpstart then
         return nil, T"DHCP Start Address is Invalid"
      end

      if baseip and netmask and dhcpend then
        local network = bit.band(baseip, netmask)
        local ipmax = bit.bor(network, bit.bnot(netmask))
        local start = dhcpstart - network
        local numips = dhcpend - dhcpstart + 1

        local limit = ipmax - network - 1

        local validatorNumberInRange = post_helper.getValidateNumberInRange(1,limit)

        if dhcpstart == baseip then
           return nil, T"DHCP Start Address should not be Local Device IP Address"
        elseif dhcpstart == network then
           return nil, T"DHCP Start Address should not be a Network Address"
        end

        local val = validatorNumberInRange(start)
        if not val or dhcpstart <= network or dhcpstart >= ipmax then
            return nil, T"DHCP Start Address is not valid in Subnet Range"
        end

        -- Setting the dhcpStart and dhcpLimit from the calculated DHCP Range
        object["dhcpStart"] = tostring(start)
        object["dhcpLimit"] = tostring(numips)

        return true
      else
        return nil
      end
    else
      return nil, T"DHCP Start Address is Invalid"
    end
end

-- This function will validate the Modem IP Address and check for
-- Valid IP Format, Limited Broadcast Address, Public IP Range, Multicast Address Range
local function validateGWIP(value, object, key)
   local val, errmsg = aIPV(value, object, key)
   local post_data = ngx.req.get_post_args()
   if not val then
      return nil, errmsg
   end

   if value and pIPV(value) then
      return nil, T"Public IP Range should not be used"
   end

   local ip = ipv42num(value)

   for _,intf in pairs(lan_intfs) do
      if intf.index ~= curintf then
         local ipaddr = proxy.get("uci.network.interface.@" .. intf.index .. ".ipaddr")[1].value
         local mask = proxy.get("uci.network.interface.@" .. intf.index .. ".netmask")[1].value
         local baseip = post_helper.validateStringIsIP(ipaddr) and ipv42num(ipaddr)
         local netmask = post_helper.validateStringIsIP(mask) and ipv42num(mask)

         local network, ipmax
         if baseip and netmask then
            network = bit.band(baseip, netmask)
            ipmax = bit.bor(network, bit.bnot(netmask))
         end

         if network and ipmax then
            if ip >= network and ip <= ipmax then
               if intf.name ~= "" then
                  return nil, T"Gateway IP should not be in " .. intf.name .. T" IP Range"
               else
                  return nil, T"Gateway IP should not be in " .. intf.index .. T" IP Range"
               end
            end
         end
      end
   end
   return true
end

local function isChecked(key, checked)
    for _,v in ipairs(checked) do
        if v == key then
            return true
        end
    end
    return false
end

local function validateEthports(value, object, key)
    local getValidateEthports = gVIC(ethports)
    local ok, msg = getValidateEthports(value, object, key)

    if not ok then
        return ok, msg
    end

    for k,v in ipairs(ethports) do
        object[v[1]] = nil
        object[v[1]] = isChecked(v[1], value) and "1" or "0"
    end

    return true
end

local function validatedhcpIgnore(value, object, key)
  local valid, msg = post_helper.getOptionalValidation(value, object, key)
  if not valid then
    return nil,  msg
  end
  if object["dhcpv4State"] == "server" then
    if object["dhcpIgnore"] == "1" then
      object["dhcpIgnore"] = "0"
    end
  end
  return true
end

local dhcpv4Stateselect = {
    {"server"},
    {"disabled"},
}

local mapValid = {
    localdevIP = validateGWIP,
    localIPv6 = validateIPv6,
    dnsServer = validateDNS,
    leaseTime = validateLeaseTime,
    localdevmask = post_helper.getAndValidation(vIP4N,post_helper.validateStringIsIP),
    dhcpStart = validateDHCPStart,
    dhcpLimit = validateLimit,
    dhcpv4State = gVIES(dhcpv4Stateselect),
    --dhcpIgnore = validatedhcpIgnore,
    eth0 = vB,
    ethports = validateEthports,
}

for i = 1, ethport_count do
  mapValid["eth" .. i] = vB
end

-- This is quite convoluted but I only found this way to get it to work.
-- getExactContent will return an error if we access an unknown instance
-- so we cannot load from uci an option if it does not exist
-- in the end we only add the parameter to the parameters list if:
--    - it exists (get or post)
--    - we're doing a post -> in this case, we add an entry and delete it if validation fails
if (dnsIndex < #dhcp.options +1) or ( (ngx.var.request_method == "POST") and (ngx.req.get_post_args().action == "SAVE") ) then
    mapParams["dnsServer"] = baseDHCPOptions .. "@" .. dnsIndex .. ".value"
end
if (dnsIndex == #dhcp.options + 1) and (ngx.var.request_method == "POST") and (ngx.req.get_post_args().action == "SAVE") then
    proxy.add(baseDHCPOptions)
end

content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

if (ngx.var.request_method == "POST")  and not next(helpmsg) then
   local dhcp_options_path = "uci.dhcp.dhcp.@"..cur_dhcp_intf..".dhcp_option."
   local dhcp_options = content_helper.convertResultToObject(dhcp_options_path,proxy.get(dhcp_options_path))
    for _,v in ipairs(dhcp_options) do
      if v.value:match("^3,") then
        proxy.del(dhcp_options_path..v.paramindex..".")
      end
    end
end

-- because we do the localdevmask validation in localdevIP validation, we check if local ip starts with error msg "[netmask]".
-- If so move it to localdevmask
if helpmsg["localdevIP"] then
  local msg = match(helpmsg["localdevIP"], '^%[netmask%] (.*)')
  if msg then
    helpmsg["localdevIP"] = nil
    helpmsg["localdevmask"] = msg
  end
end
if helpmsg["dhcpLimit"] then
    local msg = match(helpmsg["dhcpLimit"], '^%[dhcpStart%] (.*)')
    if msg then
        helpmsg["dhcpLimit"] = nil
        helpmsg["dhcpStart"] = msg
    end
end

-- post_helper restores values that have been removed during validation
-- so if you remove the dns server, it will still be displayed on the page (though correctly set in datamodel)
-- this handles this case
if dnsRemoved then
    content["dnsServer"] = ""
end
if content["dnsServer"] ~= nil then
    if content["dnsServer"]:find("^6,") == 1 then
      content["dnsServer"] = (content["dnsServer"] or ""):sub(3) -- the dhcp option will contain "6," at the start
    end
end

if content["dhcpv4State"] == "" then
    content["dhcpv4State"] = "server"
end
if content["localIPv6"] == "" then
    content["localIPv6"] = "0"
end
if not match(content["leaseTime"],"^0*([1-9]%d*[smhdw])$") then
  content["leaseTime"] = content["leaseTime"] .. "s"
end
local baseip = ipv42num(content["localdevIP"])
local netmask = ipv42num(content["localdevmask"])
local start = tonumber(content["dhcpStart"])
local numips = tonumber(content["dhcpLimit"])
local ipstart,ipend,network
if start and numips and not helpmsg["localdevIP"] and not helpmsg["localdevmask"] and not helpmsg["dhcpStart"] and not helpmsg["dhcpLimit"] then
  ipstart,ipend,network = calculateDHCPStartAddress(baseip,netmask,start,numips)
  session:store("dhcpStartAddr",ipstart)
  session:store("dhcpEndAddr",ipend)
  session:store("networkAddr",network)
else
  ipstart = ngx.req.get_post_args().dhcpStartAddress
  ipend = ngx.req.get_post_args().dhcpEndAddress
  network = session:retrieve("networkAddr")
 end
if helpmsg["leaseTime"] then
  content["leaseTime"] = ngx.req.get_post_args().leaseTime
end
  if ngx.var.request_method == "POST" then
    local gwIP = session:retrieve("old_ip")
    session:store("old_ip",(content["localdevIP"]))

  -- Redirect the GUI only if the local GW device IP address is changed for the "lan" interface
  if curintf == "lan" and content["localdevIP"]~= gwIP and not next(helpmsg) then
    ngx.print('\
    <script type="text/javascript">\
      window.location="http://', content["localdevIP"], '";\
    </script>');
    session:logout()
  end
else
  session:store("old_ip",(content["localdevIP"]))
end

local ethports_checked = {}
if type(content) == "table" then
    for _,v in ipairs(ethports) do
        if (content[v[1]] == "1") then
            ethports_checked[#ethports_checked + 1] = v[1]
        end
    end
end

ngx.print(ui_helper.createHeader(T"Local Network", true, false), '\
\
   <div class="modal-body update">\
     <form class="form-horizontal" method="post" action="', ngx.var.request_uri, '">');
     -- Do not display the navlist on the list if only 1 lan interface
     if #lan_intfs> 1 then
ngx.print('\
     <div class="span2">\
        <ul class="nav nav-list">');
        local html = { format('<li class="nav-header">%s</li>', T"LAN Interfaces") }
        for k,v in ipairs(lan_intfs) do
            local active = ""
            if v.index == curintf then
                active = "active"
            end
            local url = "modals/ethernet-modal.lp?intf=" .. v.index
            html[#html+1] = format('<li class="%s"><a id = "%s" href="#" data-remote="%s">%s</a></li>', active, v.index, url, v.name:upper())
        end
        ngx.print(html, '\
        </ul>\
     </div>\
     <div class="span6">');
        end
        ngx.print(ui_helper.createMessages(message_helper.popMessages()), '\
          <fieldset>\
              <legend>', T"Global Information", '</legend>');
              local advanced = {
                group = {
                  class = "advanced hide"
                }
              }
              local IP_warn = {
              alert = {
                      class = "alert-warning ip-warn hide"
                  },
              }
              -- Labels that shows the Local Device IP address & network subnet
              ngx.print(
                ui_helper.createInputText(T"Local Device IP address", "localdevIP", content["localdevIP"],{},helpmsg["localdevIP"]),
                ui_helper.createInputText(T"Local Network subnet", "localdevmask", content["localdevmask"], advanced, helpmsg["localdevmask"]),
                ui_helper.createAlertBlock(format("%s<br/><br/>%s<br/><br/>%s",T"When changing the LAN IP address information be aware you need to reconnect your devices to get the right connection details.",T"You may need to enter the new IP address in the browser once your device has the correct details.",T"Please allow up to 60 seconds for the address change to complete."),  IP_warn),
                ui_helper.createSwitch(T"IPv6 state", "localIPv6", content["localIPv6"])
                );
              if curintf == "lan" then
	               ngx.print(ui_helper.createCheckboxGroup(T"Ethernet Ports enabled", "ethports", ethports, ethports_checked, {checkbox = { class="inline" }}, nil));
              end
                ngx.print('\
              <legend>', T"DHCP Settings", '</legend>');
                -- Labels that shows DHCP info
                local switchDHCP = {
                  values = {
                    on = "server",
                    off = "disabled"
                  }
                }
                local DNS_warn = {
                alert = {
                        class = "alert-warning advanced hide"
                    },
                }
                ngx.print(
                  ui_helper.createSwitch(T"DHCP Server", "dhcpv4State", content["dhcpv4State"],switchDHCP),
                  ui_helper.createLabel(T"Network Address", network, advanced),
                  ui_helper.createInputText(T"DHCP Start Address", "dhcpStartAddress", ipstart, advanced, helpmsg["dhcpStart"]),
                  ui_helper.createInputText(T"DHCP End Address", "dhcpEndAddress", ipend, advanced, helpmsg["dhcpLimit"]),
                  ui_helper.createInputText(T"Lease Time", "leaseTime", content["leaseTime"], advanced, helpmsg["leaseTime"]),
                  ui_helper.createInputText(T"DNS Server", "dnsServer", content["dnsServer"], advanced, helpmsg["dnsServer"]),
                  ui_helper.createAlertBlock(format("%s",T"To enter multiple DNS please use comma seperation,e.g. 8.8.8.8,8.8.4.4."), DNS_warn));
		            if dhcpDefaultExist and curintf == "lan" then
                    local wait_for_reset = {
                        group = {
                           class = "advanced hide"
                        },
                        button = {
                           id = "btn-dhcp-reset"
                        }
                    }
                    ngx.print(ui_helper.createButton(T"Restore Default Configuration", T"Reset Configuration", "icon-bolt", wait_for_reset))
                 end
              -- Do not display the static lease when the interface is not lan
              if curintf == "lan" then
                ngx.print('\
                  <legend>');  ngx.print( T"Static leases" ); ngx.print('</legend>\
                  ');  
                    local confilictipchange_alert = {
                      alert = {
                          class = "alert hide",
                          id = "confilictipchange-msg"
                      }
                    }
                    ngx.print(
                      ui_helper.createAlertBlock(T"The latest added/modified static lease is set to an IP that is already in use, please perform a reboot to apply the changes", confilictipchange_alert),
                      ui_helper.createTable(sleases_columns, sleases_data, sleases_options, nil, sleases_helpmsg))
                ngx.print('\
              </fieldset>\
              ');  
              end
          -- Do not display the navlist on the list if only 1 lan interface
          if #lan_intfs > 1 then
          ngx.print('</div>');
          end
	  ngx.print('\
          <input type="hidden" name="isAdvanced" id="isAdvanced" value="0">\
        </form>\
   </div>\
<script type=\'text/javascript\'>\
$(function() {\
    var iPv6StateOnlyChanged = 0;\
    $("input, select").on("change", function(){\
       if(this.id == "localIPv6" && iPv6StateOnlyChanged == 0)\
         iPv6StateOnlyChanged = 1;\
       else\
         iPv6StateOnlyChanged = 2;\
    });\
    //Override the save button click event to update the IPv6 state alone.\
    $("#save-config").click(function(){\
         if(iPv6StateOnlyChanged == 1){\
          var params = [];\
          params.push({\
            name : "action",\
            value : "SAVE"\
          },\
          {\
            name : "iPv6StateOnlyChanged",\
            value : "yes"\
          },\
          {\
            name : "localIPv6",\
            value : $("#localIPv6").val()\
          }, tch.elementCSRFtoken());\
          var target = $(".modal form").attr("action");\
          tch.showProgress(waitMsg);\
          $.post(target, params, function(response){\
            //The following block of code used to display the success/error message and manage the footer.\
            $(".alert").remove();\
            $("form").prepend(response);\
            $("#modal-changes").attr("style","display:none");\
            $("#modal-no-change").attr("style","display:block");\
            iPv6StateOnlyChanged = 0;\
            tch.removeProgress();\
          });\
          return false;\
         }\
     });\
\
    var currentlanip = "', content["localdevIP"], '";\
    $("[name=\'localdevIP\']").change(function(){\
      if (currentlanip == $("[name=\'dnsServer\']").val()){\
          $("[name=\'dnsServer\']").val($(this).val());\
          currentlanip = $(this).val();\
      }\
    });\
\
    $("#save-config").click(function(){\
      if($("#Hide_Advanced_id").is(":visible"))\
        $("#isAdvanced").val("1");\
      else\
        $("#isAdvanced").val("0");\
    });\
\
});\
$("[name =\'sleases_mac\']").change(function () {\
    if ((this.value) == "custom") {\
          $(this).replaceWith($(\'<input/>\',{\'type\':\'text\', \'name\':\'sleases_mac\'}));\
    }\
});\
\
$("[name=localdevIP]").focus(function(){$(".ip-warn").slideDown();});');
if dhcpDefaultExist then
  ngx.print('$("#btn-dhcp-reset").click(function(){');
  for k,v in pairs(dhcpDefaultExist) do
  ngx.print('\
    $("#',k, '").val("', v, '");');
  end
  ngx.print('\
  $("#localIPv6").prev().removeClass("switcherOn").closest(".switch").removeClass("switchOn");\
  $("#dhcpState").prev().addClass("switcherOn").closest(".switch").addClass("switchOn");\
  $("#modal-changes").show();\
  $("#modal-no-change").hide();\
});\
');  
end
if inUseFlag == true then  ngx.print('\
  $("#confilictipchange-msg").show();\
  ');  
end
ngx.print('</script>',
ui_helper.createFooter()
);