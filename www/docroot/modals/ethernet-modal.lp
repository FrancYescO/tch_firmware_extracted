--pretranslated: do not change this file
 
--pretranslated: do not change this file

-- Localization
--NG-????? ResetButton and friendlyName on LAN-Interface Page
--NG-71196 IPv6 Button pppoe realm
--NG-71457
--NG-73647 changes reloads pppoe
--NG-78292 DHCP server disabled after reset
--NG-72728
--NG-68986 a revert been done
--NG-89213 to revert the revert of the generic NG-68986 changes
--NG-83015 IPv6
--NG-96100 Local Network Modal not opened after upstep to 17.1.7745
--NG-96425 TI-[GUI] - Changing SSID name of Guest 5GHz is not coherent in Wireless and Local Network Modal
--NG-100782 [TI] Local Network card accepts LAN IP in Ospiti range when the subnet mask is changed
--NG-102499 Assigning a Network Address/mask already in use shall not be possible
--NG-70591 GUI : Unable to configure infinite lease time (-1) from GUI but data model allows
gettext.textdomain('webui-core')

-- Process POST query
local bit = require("bit")
local proxy = require("datamodel")
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
local params, error_msg
local match, format, gsub = string.match, string.format, string.gsub
local find, untaint = string.find, string.untaint
local ipv42num = post_helper.ipv42num
local broadcast_ip =post_helper.ipv42num("255.255.255.255")
local DHCPStartAndLimitAddress = post_helper.DHCPStartAndLimitAddress
local timhelper = require("tim_helper")
local role = session:getrole()

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

local hosts_mac = {}

-- Labels that shows DHCP info
local switchDHCP = {
    values = {
        on = "server",
        off = "disabled"
	}
}

local session = ngx.ctx.session
local tech = false
if session:getrole() == "engineer" then
  tech = true
end

local clear_network_stats = {
  controls = {
    class = "clear_network_stats"
  },
  group = {
    class = "advanced hide"
  },
  button = {
    ["data-name"] = "action",
    ["data-value"] = "RESET"
  }
}
for k, v in pairs(hosts_ac) do
  local mac = match(k, "%[(.*)%]")
  hosts_mac[#hosts_mac+1] = {mac, mac}
end

hosts_mac[#hosts_mac+1] = {"custom",T"custom"}

local IPv6addressGlob = proxy.get("rpc.network.interface.@lan.ipv6uniqueglobaladdr")

if IPv6addressGlob then
  IPv6addressGlob = IPv6addressGlob[1].value
end

local IPv6addressLoc = proxy.get("rpc.network.interface.@lan.ipv6uniquelocaladdr")

if IPv6addressLoc then
  IPv6addressLoc = IPv6addressLoc[1].value
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
    local radio = "noradio"
    local name = ""
    if match(v["ppp.ll_dev"], "wl") then
      name = proxy.get("rpc.wireless.ssid.@"..v["ppp.ll_dev"]..".ssid")[1].value
      if match(proxy.get("rpc.wireless.ssid.@"..v["ppp.ll_dev"]..".radio")[1].value, "radio_5G") then
        radio = "5GHz"
      else
	radio = "2.4GHz"
      end
    end
    if name ~= "" then
      lan_intfs[#lan_intfs + 1] = {name = name, index = v.paramindex, radio = radio}
    elseif v.name and v.name ~= "" then
      lan_intfs[#lan_intfs + 1] = {name = v.name, index = v.paramindex, radio = radio}
    else
      lan_intfs[#lan_intfs + 1] = {name = v.paramindex, index = v.paramindex, radio = radio}
    end
  end
  if v.paramindex == getintf then
      curintf = v.paramindex
      pppDev = v["ppp.ll_dev"]
      pppIntf = v["ppp.ll_intf"]
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

local IP6assign = "uci.network.interface.@" .. curintf .. ".ip6assign"
local tch_IP6assign = "uci.network.interface.@" .. curintf .. ".tch_ip6assign"  -- cache variable
local mapParam = {
  dhcpv6State = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".dhcpv6"
}

local resetData = {
    localdevIP = "uci.ucidefaults.interface.@" .. curintf .. "_reset.ipaddr",
    localdevmask = "uci.ucidefaults.interface.@" .. curintf .. "_reset.netmask",
    dhcpStart = "uci.ucidefaults.interface.@" .. curintf .. "_reset.start",
    dhcpLimit = "uci.ucidefaults.interface.@" .. curintf .. "_reset.limit",
    dhcpv4State = "uci.ucidefaults.interface.@" .. curintf .. "_reset.dhcpv4",
    dhcpv6State = "uci.ucidefaults.interface.@" .. curintf .. "_reset.dhcpv6",
    leaseTime = "uci.ucidefaults.interface.@" .. curintf .. "_reset.leasetime",
    ra = "uci.ucidefaults.interface.@" .. curintf .. "_reset.ra",
}

content_helper.getExactContent(resetData)
local defautDHCPOptions = proxy.get("uci.ucidefaults.interface.@" .. curintf .. "_reset.dhcp_option.")
for _, v in ipairs(defautDHCPOptions) do
    if v.value:find("^6,") == 1 then
        resetData["dnsServer"] = (v.value or ""):sub(3)
    end
end
if not resetData["dnsServer"] or resetData["dnsServer"] == "" then
    resetData["dnsServer"] = resetData["localdevIP"]
end
resetData["dhcpStartAddress"], resetData["dhcpEndAddress"], resetData["NetworkAddress"] = DHCPStartAndLimitAddress(resetData.localdevIP,
    resetData.localdevmask, tonumber(resetData.dhcpStart), tonumber(resetData.dhcpLimit))
if resetData["dhcpv4State"] == "" then
    resetData["dhcpv4State"] = "server"
end
if resetData["dhcpv6State"] == "server" and resetData["ra"] == "server" then
    resetData["dhcpv6State"] = "server"
end

local function validateIPv6(value, object, key)
local valid, msg = post_helper.validateNonEmptyString(value, object, key)
    local ip6assign = proxy.get(IP6assign)[1].value -- get current value and store in cache if we are switching state
    local tch_ip6assign = proxy.get(tch_IP6assign)[1].value  -- fetching from cache
    if not tch_ip6assign or tch_ip6assign == "" then
        tch_ip6assign = ip6assign
    end
    if valid then
        if value == "disabled" then
            -- In case we disable IPv6, we must first invalidate the existing prefix so that local devices know not to use IPv6 anymore
            -- Do this here by set the ip6assign pref and only on ipv6 state change
            -- set ra to 'disabled' in dhcp config
            proxy.set("uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".ra", "disabled")
            -- need to delete ip6assign entry
            proxy.set(tch_IP6assign, ip6assign)  -- save current value to cache
            proxy.set(IP6assign, "")
            proxy.apply()
        else
            -- enable router advertisements and restore ip6assign value from cache
            proxy.set("uci.dhcp.dhcp.@" .. curintf .. ".ra", "server")
            proxy.set(IP6assign, tch_ip6assign)  -- restore value from cache
            proxy.set(tch_IP6assign, "")         -- reset cache
            proxy.apply()
        end
        if isQtnGuestWiFi(pppDev) then
            local ucipath = content_helper.getMatchedContent("uci.network.device.",{ifname = pppIntf})
            local result = value == "disabled" and "0" or "1"
            if ucipath and #ucipath > 0 then
               proxy.set(ucipath[1].path .. "ipv6", result)
            end
        end
    end
    return valid, msg
end

--We need to update IPv6 state only when user want to update the IPv6 state alone.
if ngx.var.request_method == "POST" and ngx.req.get_post_args().iPv6StateOnlyChanged == "yes" and curintf == "lan" then
    local validation = {
    dhcpv6State = validateIPv6,
    }
    post_helper.handleQuery(mapParam, validation)
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
    ngx.exit(ngx.HTTP_OK)
end

local classEStartIP = ipv42num("240.0.0.0")
local classEEndIP = ipv42num("255.255.255.254")
local softwareStartIP = ipv42num("0.0.0.1")
local softwareEndIP = ipv42num("0.255.255.255")
local startLoopback = ipv42num("127.0.0.0")
local endLoopback = ipv42num("127.255.255.255")
local startMulticastRange = ipv42num("224.0.0.0")
local endMulticastRange = ipv42num("239.255.255.255")

-- function is used to validate the given Public IP address
local function publicIPValidation(value, object, key)
  if value ~= "" then
    if not pIPV(value) then
      return nil, T"Not a Public address"
    end
    local ip = ipv42num(value)
    if classEStartIP <= ip and classEEndIP >= ip then
      return nil, T"Cannot use classE IP address range."
    end
    if softwareStartIP <= ip and softwareEndIP >= ip then
      return nil, T"Cannot use software address range."
    end
    if startLoopback <= ip and ip <= endLoopback  then
      return nil,T"Cannot use IPv4 loopback address range."
    end
    if startMulticastRange <= ip and endMulticastRange >= ip then
      return nil, T"Cannot use a multicast address."
    end
    if object.localpublicmask then
      local success1, errmsg = post_helper.isNetworkAddress(value, object.localpublicmask)
      if success1 then
        return nil, T"Cannot use the network address"
      end
      local success2, errmsg2 = post_helper.isBroadcastAddress(ip, object.localpublicmask)
      if success2 then
        return nil, T"Cannot use the broadcast address"
      end
    end
    return true
  end
end


--Public Subnet
if curintf == "public_lan" then
  local subin_fwd = ""
  local subout_fwd = ""
  local forward_path = "uci.firewall.forwarding."
  local forward_path_content = content_helper.getMatchedContent (forward_path)
  for _, v in pairs (forward_path_content) do
    if v["src"] == "wan" and v["dest"] == "public_lan" then
      subin_fwd = v["path"]
    end
    if v["dest"] == "wan" and v["src"] == "public_lan" then
      subout_fwd = v["path"]
    end
  end

  local publicSubnetParams = {
    enable = "uci.network.interface.@".. curintf ..".auto",
    localcpeip = "uci.network.interface.@".. curintf ..".ipaddr",
    localpublicmask = "uci.network.interface.@".. curintf ..".netmask"
  }

  local publicSubnetValid = {
    enable = post_helper.validateBoolean,
    localcpeip = publicIPValidation,
    localpublicmask = post_helper.validateIPv4Netmask
  }

   params, error_msg = post_helper.handleQuery(publicSubnetParams, publicSubnetValid)

  if ngx.var.request_method == "POST" then
    if params.enable == "1" then
      proxy.set(subin_fwd .. "enabled","1")
      proxy.set(subout_fwd .. "enabled","1")
      proxy.set("uci.dropbear.dropbear.@"..curintf ..".enable","1")
      proxy.set("uci.dropbear.dropbear.@"..curintf ..".RootLogin","1")
    else
      proxy.set(subin_fwd .. "enabled","0")
      proxy.set(subout_fwd .. "enabled","0")
      proxy.set("uci.dropbear.dropbear.@"..curintf ..".enable","0")
      proxy.set("uci.dropbear.dropbear.@"..curintf ..".RootLogin","0")
    end
  end
end

-- Static leases
local sleases_columns = {
  {
    header = T"Hostname",
    name = "sleases_name",
    param = "name",
    type = "text",
    attr = { input = { class="span2" } },
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
      value = value:match("^%x%x%-%x%x%-%x%x%-%x%x%-%x%x%-%x%x$") and value:gsub("-",":") or value
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
  sleases_name = gAV(sleases_name_validation, post_helper.validateStringIsDomainName),
  sleases_mac = gAV(sleases_mac_validation,vQTN),
  sleases_ip = gAV(sleases_ip_validation, vQTN, post_helper.reservedIPValidation),
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
          local IPAddress = v.IPAddress:match("[^%s]+")
          if v.DhcpLeaseTime ~= "" and IPAddress == slease_ip then
            inUseFlag = true
            break
          end
        end
      end
    end
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
  dhcpv6State = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".dhcpv6",
  eth0 = "uci.ethernet.port.@eth0.enable",
}

local ethports = {
    {"eth0", "eth0"},
}

-- Generic solution for boards without eth1/2/3
local ethport_count = 0
for i = 1, 3 do
  local ethport = "eth" .. i
  local path = "uci.ethernet.port.@" .. ethport .. "."
  local v = proxy.get(path .. "duplex")
  if v ~= nil then
    ethport_count = ethport_count + 1
    table.insert(ethports, {ethport, ethport})
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
        local mask, msg = post_helper.validateIPv4Netmask(object.localdevmask)
        if not msg then
          local dns = {}
          for ip_Address in string.gmatch(value, '([^,]+)') do
            dns[#dns + 1] = ip_Address
            local success, errmsg = post_helper.reservedIPValidation(ip_Address)
            if not success then
              return nil, errmsg
            end

	    local valid, helpmsg_validip = post_helper.validateStringIsIP(ip_Address, object, key)
	    if valid then
              local isNetmask = post_helper.validateIPv4Netmask(ip_Address)
              if isNetmask then
                return nil, T"Cannot use netmask as DNS server IP"
              end
              local dnsIP, errmsg = post_helper.DNSIPValidation(ip_Address, object)
              if errmsg then
                return nil, errmsg
              end
              if pIPV(value) then
                return nil, T"Public IP Range should not be used"
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
  if value == '-1' or value == timhelper.ethtrans().eth_infinit then -- included '-1' as a feasible set value as specified in TR 181
    postdata[key] = "infinite" -- included to ensure uci parameter is set as infinite
    return true
  else
    local success, msg = timhelper.validateStringIsLeaseTime(value)
    if success then
      postdata["leaseTime"] = match(untaint(value), "^0*([1-9]%d*[smhdw]?)$")
      return true
    else
      return nil, msg
    end
  end
end

local function getDHCPData(object)
  -- Check the entered IP is valid IP and convert it to number
  local baseip = post_helper.validateStringIsIP(object["localdevIP"]) and ipv42num(object["localdevIP"])
  local netmask = post_helper.validateStringIsIP(object["localdevmask"]) and ipv42num(object["localdevmask"])
  local dhcpstart = post_helper.validateStringIsIP(object["dhcpStartAddress"]) and ipv42num(object["dhcpStartAddress"])
  local dhcpend = post_helper.validateStringIsIP(object["dhcpEndAddress"]) and ipv42num(object["dhcpEndAddress"])

  return baseip, netmask, dhcpstart, dhcpend
end

local STB_IP = {
  start = "uci.dhcp.dhcp.@STB.start",
  limit = "uci.dhcp.dhcp.@STB.limit"
}
content_helper.getExactContent(STB_IP)

local function calculateSTBRange(object)
  local stbstart = STB_IP.start
  local stblimit = STB_IP.limit
  local baseip, netmask = getDHCPData(object)
  if baseip and netmask then
    baseip = num2ipv4(baseip)
    netmask = num2ipv4(netmask)
    local stbStart, stbEnd = DHCPStartAndLimitAddress(baseip, netmask, tonumber(stbstart), tonumber(stblimit))
    if stbStart then
      stbStartNum = ipv42num(stbStart)
      stbEndNum = ipv42num(stbEnd)
      return stbStartNum, stbEndNum
    end
  end
end

local function STBCheck(object, stbrange)
  if all_dhcp_intfs[1].paramindex == "STB" then
    local ipstart, ipend = calculateSTBRange(object)
    if ipstart and ipend then
      if stbrange >= ipstart and stbrange <= ipend then
        return "nil",T"Lan pool range overlaps with the STB pool range"
      end
    end
  end
  return true
end

-- Validation is done for the dhcpLimit for the particular subnet
-- If different subnet mask is given other than 255.255.255.0, then the
-- DHCP Range limit has to be calculated from the new subnet and the validation
-- has to be done for the new limit.
local function validateLimit(value, object)
  local mask, msg = post_helper.validateIPv4Netmask(object.localdevmask)
  if not msg then
    if object.dhcpEndAddress then
      local isReserved, msg = post_helper.reservedIPValidation(object.dhcpEndAddress)
      if not isReserved then
        return nil, msg
      end
    end

    if match(value, "^[0-9]*$") then
      local baseip, netmask, dhcpstart, dhcpend = getDHCPData(object)

      local ok,error = STBCheck(object, dhcpend)
      if error then
        return nil, error
      end

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
end

-- Validation is done for the DHCP start Address for the particular subnet
-- For different subnets, validation for dhcpStart Address has to be done
-- from the new DHCP Range with respect to the subnet mask & Network Address
local function validateDHCPStart(value, object)
  local mask, msg = post_helper.validateIPv4Netmask(object.localdevmask)
  if not msg then
    if object.dhcpStartAddress then
      local isReserved, msg = post_helper.reservedIPValidation(object.dhcpStartAddress)
      if not isReserved then
        return nil, msg
      end
    end

    if match(value, "^[0-9]*$") then
      local baseip, netmask, dhcpstart, dhcpend = getDHCPData(object)

      local ok,error = STBCheck(object, dhcpstart)
      if error then
        return nil,error
      end

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
end

-- This function will validate the Modem IP Address and check for
-- Valid IP Format, Limited Broadcast Address, Public IP Range, Multicast Address Range
local function validateGWIP(value, object, key)
  local mask, msg = post_helper.validateIPv4Netmask(object.localdevmask)
  if not msg then
    local val, errmsg = aIPV(value, object, key)
    local post_data = ngx.req.get_post_args()
    if not val then
      return nil, errmsg
    end

    if not reserved_ip_validation(value) then
      return nil, T"The IP is internally used for other services."
    end

    local isWan, intf = post_helper.isWANIP(value, all_intfs)
    if isWan and intf~= nil then
      return nil, T"Gateway IP should not be in ".. intf .." IP Range"
    end

    local isLan, intf = timhelper.isIPinOtherRange(value, object["localdevmask"],all_intfs, curintf)
    if isLan then
      for _,v in pairs(all_intfs) do
        if intf == v.paramindex and v.name ~= "" then
	  return nil, T"Gateway IP should not be in ".. v.name .." IP Range"
	elseif intf == v.paramindex then
	  return nil, T"Gateway IP should not be in ".. intf .." IP Range"
	end
      end
   end
    
   if value and pIPV(value) then
     return nil, T"Public IP Range should not be used"
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

local dhcpv4Stateselect = {
  {"server"},
  {"disabled"},
}

local mapValid = {
  localdevIP = validateGWIP,
  dhcpv6State = validateIPv6,
  dnsServer = validateDNS,
  leaseTime = validateLeaseTime,
  localdevmask = gAV(vIP4N,post_helper.validateStringIsIP),
  dhcpStart = validateDHCPStart,
  dhcpLimit = validateLimit,
  dhcpv4State = gVIES(dhcpv4Stateselect),
  dhcpIgnore = validatedhcpIgnore,
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

local ipStart, ipEnd, network, stbStart, stbEnd, modemIPChangeState
local ethports_checked = {}
if curintf ~= "public_lan" then
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
if content["dnsServer"] == nil then
  local localIP = proxy.get("uci.network.interface.@" .. curintf .. ".ipaddr")[1].value
  content["dnsServer"] = localIP
else
  if content["dnsServer"]:find("^6,") == 1 then
    content["dnsServer"] = (content["dnsServer"] or ""):sub(3) -- the dhcp option will contain "6," at the start
  end
end

  if content["dhcpv4State"] == "" then
    content["dhcpv4State"] = "server"
  end

  local ra = proxy.get("uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".ra")[1].value
  if content["dhcpv6State"] == "server" and ra == "server" then
    content["dhcpv6State"] = "server"
  else
    content["dhcpv6"] = "disabled"
  end
  if content["leaseTime"] == "infinite" then
    content["leaseTime"] = timhelper.ethtrans().eth_infinit
  elseif not match(content["leaseTime"],"^0*([1-9]%d*[smhdw])$")then
    content["leaseTime"] = content["leaseTime"] .. "s"
  end
  local baseip = content["localdevIP"]
  local netmask = content["localdevmask"]
  local start = tonumber(content["dhcpStart"])
  local numips = tonumber(content["dhcpLimit"])
  local stbipstart = tonumber(STB_IP.start)
  local stbipend = tonumber(STB_IP.limit)

  if start and numips and not helpmsg["localdevIP"] and not helpmsg["localdevmask"] and not helpmsg["dhcpStart"] and not helpmsg["dhcpLimit"] then
    ipStart,ipEnd,network = DHCPStartAndLimitAddress(baseip,netmask,start,numips)
    if ipStart then
      session:store("dhcpStartAddr",ipStart)
      session:store("dhcpEndAddr",ipEnd)
      session:store("networkAddr",network)
    end
  else
    ipStart = ngx.req.get_post_args().dhcpStartAddress
    ipEnd = ngx.req.get_post_args().dhcpEndAddress
    network = session:retrieve("networkAddr")
  end

  if stbipstart and stbipend then
    stbStart, stbEnd = DHCPStartAndLimitAddress(baseip,netmask,stbipstart,stbipend)
    if stbStart then
      session:store("STBStartAddr",stbStart)
      session:store("STBEndAddr",stbEnd)
    end
  end

  if helpmsg["leaseTime"] then
    content["leaseTime"] = ngx.req.get_post_args().leaseTime
  end
  if ngx.var.request_method == "POST" then
    local gwIP = session:retrieve("old_ip")
    if curintf == "lan" and content["localdevIP"]~= gwIP and not next(helpmsg) then
      modemIPChangeState = "1"
    end
    session:store("old_ip",(content["localdevIP"]))

  -- Redirect the GUI only if the local GW device IP address is changed for the "lan" interface
  if curintf == "lan" and content["localdevIP"]~= gwIP and not next(helpmsg) then  ngx.print('\
    <script type="text/javascript">\
      window.location="http://');  ngx.print(content["localdevIP"]); ngx.print('";\
    </script>\
    ');  session:logout()
  end
else
  session:store("old_ip",(content["localdevIP"]))
end

  if type(content) == "table" then
    for _,v in ipairs(ethports) do
      if (content[v[1]] == "1") then
        ethports_checked[#ethports_checked + 1] = v[1]
      end
    end
  end
end
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Local Network", true, false))   ngx.print('\
\
<div class="modal-body update">\
<form class="form-horizontal" method="post" action="');  ngx.print( ngx.var.request_uri ); ngx.print('">\
');  
  -- Do not display the navlist on the list if only 1 lan interface
  if #lan_intfs> 1 then
  ngx.print('\
  <div class="span2">\
  <ul class="nav nav-list">\
  ');  
    local html = { format('<li class="nav-header">%s</li>', T"LAN Interfaces") }
    local tmp_eth = {}
    local tmp_R24 = {}
    local tmp_R5 = {}

 for k,v in ipairs(lan_intfs) do
 if v.radio == "noradio" then
  tmp_eth[#tmp_eth + 1] = lan_intfs[k]
  elseif v.radio == "2.4GHz" then
			tmp_R24[#tmp_R24 + 1] = lan_intfs[k]
		else
			tmp_R5[#tmp_R5 + 1] = lan_intfs[k]
		end
	end
	lan_intfs2 = tmp_eth

	for i,v in ipairs(tmp_R24) do
		lan_intfs2[#lan_intfs2 + 1] = tmp_R24[i]
	end
	for i,v in ipairs(tmp_R5) do
		lan_intfs2[#lan_intfs2 + 1] = tmp_R5[i]
	end

	local ethExist = 0
	local wl5GHzExist = 0
	local wl24GHzGHzExist = 0
      for k,v in ipairs(lan_intfs2) do
      local prev = ""
      if v.radio ~= prev then
		if v.radio == "5GHz" then
			if wl5GHzExist == 0 then
				html[#html + 1] = format('<li class="nav-header">%s %s</li>', T"Access point", v.radio)
				wl5GHzExist = 1
			end
		elseif v.radio == "2.4GHz" then
			if wl24GHzGHzExist == 0 then
				html[#html + 1] = format('<li class="nav-header">%s %s</li>', T"Access point", v.radio)
				wl24GHzGHzExist = 1
			end
		else
			if ethExist == 0 then
				html[#html + 1] = format('<li class="nav-header">%s</li>', T"Ethernet")
				ethExist = 1
			end
		end
      end
      local active = ""
      if v.index == curintf then
        active = "active"
      end
      if v.index ~= "public_lan" then
        local url = "modals/ethernet-modal.lp?intf=" .. v.index
        html[#html+1] = format('<li class="%s"><a id = "%s" href="#" data-remote="%s">%s</a></li>', active, v.index, url, v.name)
      elseif role ~= "ispuser" then
        local url = "modals/ethernet-modal.lp?intf=" .. v.index
        html[#html+1] = format('<li class="%s"><a id = "%s" href="#" data-remote="%s">%s</a></li>', "advanced hide " ..active, v.index, url, "Public Lan")
      end
    end
    ngx.print(html)
    ngx.print('\
  </ul>\
  </div>\
  <div class="span6">\
  ');  
    end
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
    ngx.print('\
  <fieldset>\
    ');  
    local advanced = {
    group = {
      class = "advanced hide"
      }
    }
    local wait_for_reset = {
    group = {
      class = "advanced hide"
         },
      button = {
          id = "btn-dhcp-reset"
         }
     }

    if curintf == "public_lan" then
      local publicSubnetSwitch = {
        switch = {
          id = "public-subnet-btn-enable"
        }
      }
      local publicSubnetSetting = {
        group = {
        class = "public-subnet-settings"
        }
      }  ngx.print('\
      <div class="advanced hide">\
      <legend>');  ngx.print( T"Public Subnet Settings" ); ngx.print('</legend>\
      ');  
      -- Labels thats shows Public Subnet info
      ngx.print(
        ui_helper.createLabel(T"CPE IP", params["localcpeip"],publicSubnetSetting,error_msg["localcpeip"]),
        ui_helper.createLabel(T"Subnet Mask", params["localpublicmask"],publicSubnetSetting, error_msg["localpublicmask"])
      )
        ngx.print('\
      </div>\
      ');  else   ngx.print('\
        <legend>');  ngx.print( T"Global Information" ); ngx.print('</legend>\
      ');  

    -- Labels that shows the Local Device IP address & network subnet
    local html = {}

    html[#html + 1] = ui_helper.createInputText(T"Local Device IPv4 address", "localdevIP", content["localdevIP"],{},helpmsg["localdevIP"])
    html[#html + 1] = ui_helper.createInputText(T"Local Network subnet", "localdevmask", content["localdevmask"], advanced, helpmsg["localdevmask"])
    html[#html + 1] =ui_helper.createButton(T"Restore Default Configuration", T"Reset Configuration", "icon-bolt", wait_for_reset)
    if curintf == "lan" then
    if tech then
	html[#html + 1] =  ui_helper.createSwitch(T"IPv6 state", "dhcpv6State", content["dhcpv6State"], switchDHCP)
	if content["dhcpv6State"] ~= "server" then
		html[#html + 1] =  ui_helper.createLabel(T"Local Device IPv6 address", T"IPv6 not assigned")
	elseif IPv6addressGlob == "" and IPv6addressLoc == "" then
		html[#html + 1] = ui_helper.createLabel(T"Local Device IPv6 address", T"IPv6 not assigned", advanced)
	else
	if IPv6addressGlob ~= "" then
		html[#html + 1] = ui_helper.createLabel(T"Local Device IPv6 address", IPv6addressGlob, advanced)
	else
		html[#html + 1] = ui_helper.createLabel(T"Local Device IPv6 address", IPv6addressLoc, advanced)
	end
	end
          html[#html + 1] =  ui_helper.createCheckboxGroup(T"Ethernet Ports enabled", "ethports", ethports, ethports_checked, {checkbox = { class="inline" }}, nil)
		else
		if content["dhcpv6State"] == "server" then
		  html[#html + 1] = ui_helper.createLabel(T"IPv6 state", T"enabled");
		else
		  html[#html + 1] = ui_helper.createLabel(T"IPv6 state", T"disabled");
		end
		if content["dhcpv6State"] ~= "server" then
		  html[#html + 1] =  ui_helper.createLabel(T"Local Device IPv6 address", T"IPv6 not assigned")
		elseif IPv6addressGlob == "" and IPv6addressLoc == "" then
		  html[#html + 1] = ui_helper.createLabel(T"Local Device IPv6 address", T"IPv6 not assigned", advanced)
		else
		  if IPv6addressGlob ~= "" then
		html[#html + 1] = ui_helper.createLabel(T"Local Device IPv6 address", IPv6addressGlob, advanced)
		  else
		html[#html + 1] = ui_helper.createLabel(T"Local Device IPv6 address", IPv6addressLoc, advanced)
		end
		end
		end
    end
    ngx.print(html)
              if curintf == "lan" then
	          ngx.print(

                  )
              end
      ngx.print('\
    <legend>');  ngx.print( T"DHCP Settings" ); ngx.print('</legend>\
    ');  
      ngx.print(
        ui_helper.createSwitch(T"DHCP Server", "dhcpv4State", content["dhcpv4State"],switchDHCP),
        ui_helper.createLabel(T"Network address", network, advanced))
      if all_dhcp_intfs[1].paramindex == "STB" and stbStart and stbEnd then
                ngx.print(
                  ui_helper.createLabel(T"STB Start address", stbStart, advanced),
                  ui_helper.createLabel(T"STB End address", stbEnd, advanced)
                )
      end
      ngx.print(
        ui_helper.createInputText(T"DHCP Start address", "dhcpStartAddress", ipStart, advanced, helpmsg["dhcpStart"]),
        ui_helper.createInputText(T"DHCP End address", "dhcpEndAddress", ipEnd, advanced, helpmsg["dhcpLimit"]),
        ui_helper.createInputText(T"Lease time", "leaseTime", content["leaseTime"], advanced, helpmsg["leaseTime"]),
        ui_helper.createInputText(T"DNS server", "dnsServer", content["dnsServer"], advanced, helpmsg["dnsServer"])
        )
       ngx.print('\
     ');  
       -- Do not display the static lease when the interface is not lan
       if curintf == "lan" and modemIPChangeState ~= "1" then
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
     ');  end   ngx.print('\
     </fieldset>\
     ');  end  ngx.print('\
     ');  
       -- Do not display the navlist on the list if only 1 lan interface
       if #lan_intfs > 1 then
       ngx.print('\
     </div>\
     ');  end  ngx.print('\
     <input type="hidden" name="isAdvanced" id="isAdvanced" value="0">\
     </form>\
   </div>\
\
<script type=\'text/javascript\'>\
$(function() {\
  var iPv6StateOnlyChanged = 0;\
  $("input, select").on("change", function(){\
  if(this.id == "dhcpv6State" && iPv6StateOnlyChanged == 0)\
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
      name : "dhcpv6State",\
      value : $("#dhcpv6State").val()\
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
  ');  if curintf ~= "public_lan" then   ngx.print('\
    var currentlanip = "');  ngx.print( content["localdevIP"] ); ngx.print('";\
    $("[name=\'localdevIP\']").change(function(){\
      if (currentlanip == $("[name=\'dnsServer\']").val()){\
        $("[name=\'dnsServer\']").val($(this).val());\
        currentlanip = $(this).val();\
      }\
    });\
  ');  end  ngx.print('\
\
  $(".public-subnet-settings").show();\
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
$("#btn-dhcp-reset").click(function(){\
  ');  for k,v in pairs(resetData) do   ngx.print('\
    $("#');  ngx.print(k); ngx.print('").val("');  ngx.print(v); ngx.print('");\
  ');  end  ngx.print('\
  $("#dhcpv6State").prev().removeClass("switcherOn").closest(".switch").removeClass("switchOn");\
  $("#dhcpv4State").prev().addClass("switcherOn").closest(".switch").addClass("switchOn");\
  $("#modal-changes").show();\
  $("#modal-no-change").hide();\
});\
');  if inUseFlag == true then  ngx.print('\
  $("#confilictipchange-msg").show();\
');  end   ngx.print('\
</script>\
\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 