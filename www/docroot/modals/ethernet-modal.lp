--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')
-- Process POST query
local proxy = require("datamodel")
local pairs, string ,ipairs, ngx = pairs, string, ipairs, ngx
local session = ngx.ctx.session
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local uinetwork = require("web.uinetwork_helper")
local hosts_ac = uinetwork.getAutocompleteHostsList()
local tonumber = tonumber
local content, helpmsg, params, error_msg = {}
local match, format, find, untaint = string.match, string.format, string.find, string.untaint
local DHCPStartAndLimitAddress = post_helper.DHCPStartAndLimitAddress
local json = require("dkjson")
local bridged = require("bridgedmode_helper")
local validator = require("ethernet_helper")
local role = session:getrole()
local currentuser = session:getusername()
local inet = require("tch.inet")

-- Shortcuts to validation helpers to make lines shorter
local advancedIP = post_helper.advancedIPValidation
local validateBoolean = post_helper.validateBoolean
local validateNetMask = post_helper.validateIPv4Netmask
local validateQTN = post_helper.validateQTN
local validateLXC = post_helper.validateLXC
local andValidation = post_helper.getAndValidation
local validateEnum = post_helper.getValidateInEnumSelect
local validateDHCPIgnore = post_helper.validateDHCPIgnore
local validateStringIP = post_helper.validateStringIsIP()
local validateStringDomainName = post_helper.validateStringIsDomainName
local validateIPv4InNetwork = post_helper.getValidateStringIsIPv4InNetwork
local hostsMac, hostsIP, setTable = {}, {}
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "LocalNetwork", "lan")
local variantHelperWireless = post_helper.getVariant(variant_helper, "Wireless", "wireless")
local wan6Intf = post_helper.getActiveInterface_v6()

-- Labels that shows DHCP info
local switchDHCP = {
  values = {
    on = "server",
    off = "disabled"
  }
}
local switchDHCP_prefix = {
  values = {
    on = "server",
    off = "disabled"
  },
  input = { id = "dhcpv6State" }
}
local dnsServerRole = post_helper.isFeatureEnabled("DnsServer", role)

local switchDHCPv6 = {
  values = {
    on = "1",
    off = "0"
  },
  group = {
    class = "advanced hide"
  }
}

local function checkCurrentUser(currentuser)
  if (currentuser == "user" or currentuser == "support") then
    return true
  else
    return false
  end
end

local syshosts_data = proxy.get("sys.hosts.host.")
local arranged_data = content_helper.convertResultToObject("sys.hosts.host.", syshosts_data)
-- VPN details are not listed in dropdown for static lease
for _, host_mac in pairs(arranged_data) do
  for macAddr, ipAddr in pairs(hosts_ac) do
    local mac = match(macAddr, "%[(.*)%]")
    if not match(host_mac["L2Interface"], "ppp*") and mac == host_mac["MACAddress"] then
      hostsMac[#hostsMac + 1] = {mac, mac}
      hostsIP[#hostsIP + 1] = {ipAddr, ipAddr}
    end
  end
end

hostsMac[#hostsMac + 1] = {"custom", T"custom"}
hostsIP[#hostsIP + 1] = {"custom", T"custom"}

local getargs = ngx.req.get_uri_args()
local getintf = getargs.intf
local curintf = "lan"
if not getintf then
  getintf = curintf
end
validator.updateCurInterface(getintf)

local IPv6Address = {
  uniqueGlobalAddr = format("rpc.network.interface.@%s.ipv6uniqueglobaladdr", getintf),
  uniqueLocalAddr = format("rpc.network.interface.@%s.ipv6uniquelocaladdr", getintf),
  ip6_prefix = format("rpc.network.interface.@%s.ip6prefix_assignment", getintf),
  ip6_prefix_network = format("rpc.network.interface.@%s.ip6prefix", wan6Intf)
}
content_helper.getExactContent(IPv6Address)
if post_helper.getVariantValue(variantHelper, "ipv6Prefix") then
  IPv6Address.ip6_prefix = IPv6Address.ip6_prefix == "" and "Not Assigned" or IPv6Address.ip6_prefix
  IPv6Address.ip6_prefix_network = IPv6Address.ip6_prefix_network == "" and "Not Assigned" or IPv6Address.ip6_prefix_network
end
local wireless_radio = {}
local wireless_ssid = proxy.getPN("rpc.wireless.ssid.", true)
for _, interface in ipairs(wireless_ssid) do
  local radios = match(interface.path, "rpc%.wireless%.ssid%.@([^%.]+)%.")
  if radios then
    wireless_radio[radios] = true
  end
end
local intfes = {}

local pppIntf, pppDev
-- Get all the LAN interfaces
local all_intfs = content_helper.convertResultToObject("rpc.network.interface." .. "@.", proxy.get("rpc.network.interface."))
local lan_intfs, otherLanIps, otherLannms, bridges = {}, {}, {}, {}

if not post_helper.isFeatureEnabled("lanNetwork", role) then
  for _, dhcpIntfs in ipairs(all_intfs) do
    if dhcpIntfs.type == "lan" and (not find(dhcpIntfs["ppp.ll_intf"], "wl") or wireless_radio[untaint(dhcpIntfs["ppp.ll_intf"])])then
      if dhcpIntfs.name and dhcpIntfs.name ~= "" then
        lan_intfs[#lan_intfs + 1] = {name = dhcpIntfs.name, index = dhcpIntfs.paramindex}
      else
        lan_intfs[#lan_intfs + 1] = {name = dhcpIntfs.paramindex, index = dhcpIntfs.paramindex}
      end
    end
    if dhcpIntfs.paramindex == getintf then
      curintf = dhcpIntfs.paramindex
    end
  end
elseif not post_helper.isFeatureEnabled("lanNetworkIP", role) then
  for _, lanIntfs in ipairs(all_intfs) do
    local network_type = proxy.get('rpc.network.interface.@' .. lanIntfs.paramindex .. '.type')
    network_type = network_type and network_type[1].value
    if network_type == 'lan' then
      -- remove VLANx as these will be handled in multi-bridge page
      if not match(lanIntfs.paramindex, "^VLAN%d$") then
        lan_intfs[#lan_intfs + 1] = lanIntfs.paramindex
      else
        bridges[#bridges +1] = lanIntfs.paramindex
      end
      if lanIntfs.paramindex == getintf then
        curintf = lanIntfs.paramindex
      else
        if lanIntfs.ipaddr ~= "" then
          otherLanIps[lanIntfs.paramindex] = untaint(lanIntfs.ipaddr)
          otherLannms[lanIntfs.paramindex] = untaint(lanIntfs.netmask)
        end
      end
    end
  end
  bridges[#bridges +1] = curintf
else
  lan_intfs = post_helper.getAllNonWirelessInterfaces(all_intfs)
  if not post_helper.isFeatureEnabled("localNetwork", role) then
    for _, interface in ipairs(all_intfs) do
      for row, intf in ipairs(lan_intfs) do
        if interface.paramindex == intf.index then
          if match(interface["ppp.ll_dev"], "wl") then
            lan_intfs[row].name = proxy.get('rpc.wireless.ssid.@'..interface['ppp.ll_dev']..'.ssid')[1].value
            lan_intfs[row]["radio"] = match(proxy.get("rpc.wireless.ssid.@"..interface["ppp.ll_dev"]..".radio")[1].value, "radio_5G") and "5GHz" or "2.4GHz"
          else
            lan_intfs[row].name = interface.paramindex
            lan_intfs[row]["radio"] = "noradio"
          end
        end
      end
    end
  end
end

-- Get the interface, pppDev and pppIntf for Quantenna WiFi Guest IPv6
for _, intfs in ipairs(all_intfs) do
  if intfs.paramindex == getintf then
    intfes[#intfes +1 ] = intfs.paramindex
    curintf = intfs.paramindex
    pppDev = intfs["ppp.ll_dev"]
    pppIntf = intfs["ppp.ll_intf"]
    break
  end
end
local cur_dhcp_intf = "lan"
local dhcp_intfs_path = "uci.dhcp.dhcp."
local all_dhcp_intfs = content_helper.convertResultToObject(dhcp_intfs_path .. "@.", proxy.get(dhcp_intfs_path))

for _, dhcp_intfs in ipairs(all_dhcp_intfs) do
  if dhcp_intfs.paramindex == "STB" and post_helper.isFeatureEnabled("lanNetworkIP", role) then
    intfes[#intfes + 1 ] = dhcp_intfs.paramindex
  end
  if dhcp_intfs.interface == curintf then
    cur_dhcp_intf = dhcp_intfs.paramindex
    break
  end
end

-- If the current interface is "STB", in order to get the DHCP range, name it as "lan"
if cur_dhcp_intf == "STB" then
  cur_dhcp_intf = "lan"
end

local IP6assign = "uci.network.interface.@" .. curintf .. ".ip6assign"
local tch_IP6assign = "uci.network.interface.@" .. curintf .. ".tch_ip6assign"  -- cache variable
local mapParam = {
  dhcpv6State = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".dhcpv6"
}

-- resetData used to set the default values for DHCP fields.
local resetData = {
  localdevIP = "uci.ucidefaults.interface.@" .. curintf .. "_reset.ipaddr",
  localdevmask = "uci.ucidefaults.interface.@" .. curintf .. "_reset.netmask",
  dhcpStart = "uci.ucidefaults.interface.@" .. curintf .. "_reset.start",
  dhcpLimit = "uci.ucidefaults.interface.@" .. curintf .. "_reset.limit",
  dhcpv4State = "uci.ucidefaults.interface.@" .. curintf .. "_reset.dhcpv4",
  dhcpv6State = "uci.ucidefaults.interface.@" .. curintf .. "_reset.dhcpv6",
  ra = "uci.ucidefaults.interface.@" .. curintf .. "_reset.ra"
}

content_helper.getExactContent(resetData)
resetData["leaseTime"..curintf] = proxy.get("uci.ucidefaults.interface.@" .. curintf .. "_reset.leasetime")[1].value
local defautDHCPOptions = proxy.get("uci.ucidefaults.interface.@" .. curintf .. "_reset.dhcp_option.")
for _, dhcpOpts in ipairs(defautDHCPOptions) do
  if dhcpOpts.value:find("^6,") == 1 then
    resetData.dnsServer = (dhcpOpts.value or ""):sub(3)
  end
end
if not resetData.dnsServer or resetData.dnsServer == "" then
  resetData.dnsServer = resetData.localdevIP
end
resetData["dhcpStartAddress"..curintf], resetData["dhcpEndAddress"..curintf], resetData.NetworkAddress = DHCPStartAndLimitAddress(resetData.localdevIP,
resetData.localdevmask, tonumber(resetData.dhcpStart), tonumber(resetData.dhcpLimit))
if resetData.dhcpv4State == "" or resetData.dhcpv4State == "enabled" then
  resetData.dhcpv4State = "server"
end
if resetData.dhcpv6State == "server" and resetData.ra == "server" then
  resetData.dhcpv6State = "server"
end

-- check if the @param radios is quantenna,isRemote and isguest by querying wireless config.
local function isQtnGuestWiFi(radios)
  if wireless_radio[radios] then
    local radio = proxy.get(format("rpc.wireless.ssid.@%s.radio", radios))
    if radio then
      local isRemote = proxy.get(format("rpc.wireless.radio.@%s.remotely_managed", radio))
      if isRemote and isRemote[1].value == "1" then
        for _, wireless_ap in ipairs(proxy.getPN("rpc.wireless.ap.", true)) do
          local isGuest = proxy.get(wireless_ap.path.. "ap_isolation")
          if isGuest and isGuest[1].value == "1" then
            return true
          end
        end
      end
    end
  end
end

--We need to update IPv6 state only when user want to update the IPv6 state alone.

if ngx.var.request_method == "POST" and ngx.req.get_post_args().Reset and post_helper.getVariantValue(variantHelper,"staticLeaseReset") then
  proxy.set("uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".ra", resetData.ra)
  for _, slease in ipairs(proxy.getPN("uci.dhcp.host.", true)) do
    proxy.del(slease.path)
  end
  proxy.apply()
  ngx.exit(ngx.HTTP_OK)
end

if ngx.var.request_method == "POST" and ngx.req.get_post_args().iPv6StateOnlyChanged == "yes" then
  local validation = {
    dhcpv6State = post_helper.validateNonEmptyString
  }
  local dhcpVal = post_helper.handleQuery(mapParam, validation)
  if dhcpVal.dhcpv6State then
    setTable = {}
    if post_helper.variantHasAccess(variantHelper, "userIPv6State") then
      setTable["uci.env.var.useripv6"] = "1"
    end
    local ip6Content = {
      ip6assign = IP6assign,
      tch_ip6assign = tch_IP6assign
    }
    content_helper.getExactContent(ip6Content)
    if not ip6Content.tch_ip6assign or ip6Content.tch_ip6assign == "" then
      ip6Content.tch_ip6assign = ip6Content.ip6assign
    end
      if dhcpVal.dhcpv6State == "disabled" then
        -- In case we disable IPv6, we must first invalidate the existing prefix so that local devices know not to use IPv6 anymore
        -- Do this here by set the ip6assign pref and only on ipv6 state change
        -- set ra to 'disabled' in dhcp config
        setTable["uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".ra"] = "disabled"
        -- need to delete ip6assign entry
        setTable[tch_IP6assign] = ip6Content.ip6assign
        setTable[IP6assign] = ""
      else
        -- enable router advertisements and restore ip6assign value from cache
        setTable["uci.dhcp.dhcp.@" .. curintf .. ".ra"] = "server"
        setTable[IP6assign] = ip6Content.tch_ip6assign
        setTable[tch_IP6assign] = ""  -- restore value from cache
      end
      if isQtnGuestWiFi(pppDev) then
        local ucipath = content_helper.getMatchedContent("uci.network.device.", {ifname = pppIntf})
        local result = dhcpVal.dhcpv6State== "disabled" and "0" or "1"
        if ucipath and #ucipath > 0 then
          setTable[ucipath[1].path .. "ipv6"] = result
        end
      end
      proxy.set(setTable)
      proxy.apply()
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
    ngx.exit(ngx.HTTP_OK)
  end
end

--Public Subnet
if curintf == "public_lan" then
  local subin_fwd = ""
  local subout_fwd = ""
  local forward_path = "uci.firewall.forwarding."
  local forward_path_content = content_helper.getMatchedContent (forward_path)
  for _, forwardPathIntfs in pairs (forward_path_content) do
    if forwardPathIntfs.src == "wan" and forwardPathIntfs.dest == "public_lan" then
      subin_fwd = forwardPathIntfs.path
    end
    if forwardPathIntfs.dest == "wan" and forwardPathIntfs.src == "public_lan" then
      subout_fwd = forwardPathIntfs.path
    end
  end

  local publicSubnetParams = {
    enable = "uci.network.interface.@".. curintf ..".auto",
    localcpeip = "uci.network.interface.@".. curintf ..".ipaddr",
    localpublicmask = "uci.network.interface.@".. curintf ..".netmask"
  }

  local publicSubnetValid = {
    enable = validateBoolean,
    localcpeip = publicIPValidation,
    localpublicmask = validateNetMask
  }

  params, error_msg = post_helper.handleQuery(publicSubnetParams, publicSubnetValid)

  if ngx.var.request_method == "POST" then
    setTable = {}
    if params.enable == "1" then
      setTable[subin_fwd .. "enabled"] = "1"
      setTable[subout_fwd .. "enabled"] = "1"
      setTable[format("uci.dropbear.dropbear.@%s.enable", curintf)] = "1"
    else
      setTable[subin_fwd .. "enabled"] = "0"
      setTable[subout_fwd .. "enabled"] = "0"
      setTable[format("uci.dropbear.dropbear.@%s.enable", curintf)] = "0"
    end
    proxy.set(setTable)
    proxy.apply()
  end
end

local dns_visible_param = proxy.get("rpc.X_000E50_GUI.DNS_visible")
dns_visible_value = dns_visible_param and dns_visible_param[1].value or "true"

-- Static leases
local sleases_columns = {
  {
    header = T"Hostname",
    name = "sleases_name",
    param = "name",
    type = "text",
    attr = { input = { class = "span2" } }
  },
  {
    header = T"MAC address",
    name = "sleases_mac",
    param = "mac",
    type = "select",
    values = hostsMac,
    attr = { input = { class = "span2", maxlength = "17", id = "sleases_mac" }, autocomplete = hostsMac },
    unique = true
  },
  {
    header = T"IP",
    name = "sleases_ip",
    param = "ip",
    type = "select",
    values = hostsIP,
    attr = { select = { class = "span2", maxlength = "15", id = "sleases_ip" }, autocomplete = hostsIP },
    unique = true
  },
  {
    header = "",
    name = "sleases_owner",
    param = "owner",
    type = "hidden",
    readonly = true,
    attr = { }
  },
}

local sleases_valid = {
  sleases_name = andValidation(validator.sleasesNameValidation, post_helper.validateStringIsDomainName),
  sleases_mac = andValidation(validator.sleasesMacValidation, validateQTN, validateLXC),
  sleases_ip = andValidation(validator.sleasesIpValidation, validateQTN, validateLXC, post_helper.reservedIPValidation)
}

local sleases_options = {
  tableid = "sleases",
  basepath = "uci.dhcp.host.@.",
  createMsg = T"Add new static lease",
  objectName = post_helper.getRandomKey(),
  addNamedObject = true
}

local sleases_filter = function(data)
  if data['owner'] == "portforward" then
    local path
    if syshosts_data then
      for _, hostMac in pairs(syshosts_data) do
        if hostMac.value == data['mac'] then
          path = hostMac.path
          break
        end
      end
      for _, sysHosts in pairs(syshosts_data) do
        if sysHosts.path == path and sysHosts.param == "HostName" then
          data['name'] = sysHosts.value
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

local isValidationError = false
if sleases_helpmsg and next(sleases_helpmsg) then
 isValidationError = true
end

local inUseFlag = false
if ngx.var.request_method == "POST" then
  local post_data = ngx.req.get_post_args()

  local post_data = ngx.req.get_post_args()
  if isValidationError then
    sleases_columns[2] = {
        header = T"MAC address",
        name = "sleases_mac",
        param = "mac",
        type = "text",
        attr = { input = { class="span2", maxlength="17", id= "sleases_macInput", value = post_data.sleases_mac }},
        unique = true,
       }
    sleases_columns[3] = {
        header = T"IP",
        name = "sleases_ip",
        param = "ip",
        type = "text",
        attr = { input = { class = "span2", maxlength = "15", id = "sleases_ipInput",  value = post_data.sleases_ip }},
        unique = true,
      }
  end

  if ( post_data.action == "TABLE-MODIFY" or  post_data.action == "TABLE-EDIT"  or  post_data.action == "TABLE-ADD") then
    local text_mac_index = tonumber(post_data.index)
    local text_mac
    local text_ip
    local isSameMacAddr = true
    local isSameIPAddr = true
    if  post_data.action == "TABLE-ADD" then
      text_mac = post_data["sleases_mac"]
      text_ip = post_data["sleases_ip"]
    else
      text_mac = sleases_data[text_mac_index][2]
      text_ip = sleases_data[text_mac_index][3]
    end
    for _, hostMacAddr in ipairs(hostsMac) do
      if text_mac == hostMacAddr[1] then
        isSameMacAddr = false
        break
      end
    end
    if isSameMacAddr then
      sleases_columns[2] = {
        header = T"MAC address",
        name = "sleases_mac",
        param = "mac",
        type = "text",
        attr = { input = { class="span2", maxlength="17", id= "sleases_macInput", value = text_mac }},
        unique = true,
      }
    end
    for _, hostIP in ipairs(hostsIP) do
      if text_ip == hostIP[1] then
        isSameIPAddr = false
        break
      end
    end
    if isSameIPAddr then
      sleases_columns[3] = {
	header = T"IP",
	name = "sleases_ip",
	param = "ip",
	type = "text",
	attr = { input = { class = "span2", maxlength = "15", id = "sleases_ipInput",  value = text_ip }},
	unique = true,
      }
    end
    if post_data.action == "TABLE-MODIFY" or  post_data.action == "TABLE-ADD" then
      local slease_ip = post_data.sleases_ip
      if arranged_data then
        for _, hostData in pairs(arranged_data) do
          local IPAddress = hostData.IPAddress:match("[^%s]+")
          if hostData.DhcpLeaseTime ~= "" and IPAddress == slease_ip then
            inUseFlag = true
            break
          end
        end
      end
    end
  end
  if ngx.req.get_post_args().ipChanged == "1" then
    setTable = {}
    local hostList  = content_helper.convertResultToObject("uci.dhcp.host.", proxy.get("uci.dhcp.host."))
    local updateIPList = ngx.req.get_post_args().ipList
    updateIPList = json.decode(untaint(updateIPList))
    for _, value in ipairs(hostList) do
      if updateIPList[untaint(value.mac)] then
        setTable["uci.dhcp.host.".. value["paramindex"] ..".ip"] = updateIPList[untaint(value.mac)]
      end
    end
    proxy.set(setTable)
    proxy.apply()
  end
  if not sleases_helpmsg and post_data.tableid == "sleases" then
    if post_data.sleases_name ~= "" and post_data.sleases_name then
      for _, v in pairs(syshosts_data) do
        if post_data.sleases_mac == v.value then
          proxy.set({[v.path .. "FriendlyName"] = post_data.sleases_name})
          proxy.apply()
        end
      end
    end
  end
end

-- Standard parameters
local mapParams = {
  dhcpv4State = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".dhcpv4",
  dhcpIgnore = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".ignore",
  localdevIP = "uci.network.interface.@" .. curintf .. ".ipaddr",
  localdevmask = "uci.network.interface.@" .. curintf .. ".netmask",
  dhcpv6State = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".dhcpv6",
  domainName = "uci.dhcp.dnsmasq.@dnsmasq.domain"
}

local curip6prefix = ""
local tmp = proxy.get("rpc.network.interface.@" .. curintf .. ".ipv6uniqueglobaladdr")
if tmp ~= nil then
    curip6prefix = tmp[1].value
end

if role == "engineer" then
  mapParams.port1 = "uci.ethernet.port.@eth0.enable"
  mapParams.dhcpv6Stateful = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".ra_management"
end

local firewall_rule_names = {}
if curintf == "lan" and not post_helper.isFeatureEnabled("lanNetworkIP", role) then
  mapParams.guestruleaddress = "rpc.network.firewall.guestruleaddress"
  for _, bridge in ipairs(bridges) do
    firewall_rule_names[#firewall_rule_names + 1] = format("drop-%s_2_lan_GW", bridge)
  end
  firewall_rule_names[#firewall_rule_names + 1] = "Allow-lan_ICMP"
end

local ethports = {
  {"port1", "port1"}
}

-- Generic solution for boards without eth1/2/3
local ethport_count = 0
for i = 1, 3 do
  local ethport = "eth" .. i
  local port = "port" .. (i+1)
  local path = "uci.ethernet.port.@" .. ethport .. "."
  local v = proxy.get(path .. "duplex")
  if v ~= nil then
    ethport_count = ethport_count + 1
    table.insert(ethports, {port, port})
    mapParams[port] = path .. "enable"
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

for _, dhcpOptVal in ipairs(dhcp.options) do
  if dhcpOptVal.value:find("^6,") == 1 then
    dnsIndex = tonumber(string.match(dhcpOptVal.path, "%.@(%d+)%.$"))
  end
end
local publicIPValidation = post_helper.publicIPValidation
local function validateDNS(value, object, key)
  local validateNetMask = post_helper.validateIPv4Netmask
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

      local validateStringIP = post_helper.validateStringIsIP()
      local valid, helpmsg_validip = validateStringIP(ip_Address, object, key)
      if valid then
        local success, errmsg = andValidation(post_helper.reservedIPValidation, validateLXC)(ip_Address, object, key)
        if not success then
          return nil, errmsg
        end
        local isNetmask = validateNetMask(ip_Address)
        if isNetmask then
          return nil, T"Cannot use netmask as DNS server IP"
        end
        local success, errormsg = post_helper.DNSIPValidation(ip_Address, object)
        if not success then
          return nil, errormsg
        end
        if publicIPValidation(ip_Address, object, key) then
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


local function validateDevIP(value, object, key)
  local valid, msg = andValidation(advancedIP, validateLXC)(value, object, key)
  if valid then
    local netmask = untaint(object.localdevmask)
    local result, netmask1 = inet.validateIPv4Netmask(netmask)
    if result then
      for row, lanIP in pairs(otherLanIps) do
        local netmask, netmask2 = inet.validateIPv4Netmask(otherLannms[row])
        local validate
        if netmask then
          validate = netmask1 > netmask2 and validateIPv4InNetwork(untaint(value), netmask) or validateIPv4InNetwork(lanIP, otherLannms[row])
          result = validate(netmask1 > netmask2 and lanIP or value)
          if result then
            return nil, format(T"IP address %s / %s should not be overlapped with LAN IP interface %s ( %s / %s )" , value, (32-netmask1), row, lanIP, (32-netmask2))
          end
        end
      end
    end
    if firewall_rule_names then
      object.guestruleaddress = format("%s|%s", value, table.concat(firewall_rule_names, ","))
    end
  end
  return valid, msg
end

local dhcpv4Stateselect = {
  {"server"},
  {"disabled"}
}

local mapValid = {
  localdevmask = andValidation(validateNetMask, validateStringIP),
  dhcpv4State = validateEnum(dhcpv4Stateselect),
  dhcpv6State = post_helper.validateNonEmptyString,
  dhcpIgnore = validateDHCPIgnore,
  domainName = post_helper.getOptionalValidation(validateStringDomainName),
  dhcpv6Stateful = validateBoolean,
  dnsServer = validateDNS
}

if not post_helper.isFeatureEnabled("lanNetworkIP", role) then
  mapValid.localdevIP = validateDevIP
else
  mapValid.localdevIP = andValidation(validator.validateGWIP, post_helper.reservedIPValidation, validateLXC)
end

if role == "engineer" then
  mapValid.port1 = validateBoolean
  mapValid.ethports = validator.validateEthports
  mapValid.dhcpv6Stateful = validateBoolean
end

for _, intf in pairs(intfes) do
  intf = (intf ~= "loopback" and intf ~= "Guest1" and intf ~= "Guest1_5GHz") and intf or cur_dhcp_intf
  mapParams["dhcpStart"..intf] = "uci.dhcp.dhcp.@"..intf..".start"
  mapParams["dhcpLimit"..intf] = "uci.dhcp.dhcp.@"..intf..".limit"
  mapParams["leaseTime"..intf] = "uci.dhcp.dhcp.@"..intf..".leasetime"
  mapValid["dhcpStart"..intf] = validator.validateDHCPStart
  mapValid["dhcpLimit"..intf] = validator.validateLimit
  mapValid["leaseTime"..intf] = validator.validateLeaseTime
end


for i = 1, ethport_count do
  mapValid["port" .. i] = validateBoolean
end

-- This is quite convoluted but I only found this way to get it to work.
-- getExactContent will return an error if we access an unknown instance
-- so we cannot load from uci an option if it does not exist
-- in the end we only add the parameter to the parameters list if:
--    - it exists (get or post)
--    - we're doing a post -> in this case, we add an entry and delete it if validation fails
local network, modemIPChangeState
local ethports_checked, dhcpIP = {}, {}
if curintf ~= "public_lan" then
  if (dnsIndex < #dhcp.options + 1) or ( (ngx.var.request_method == "POST") and (ngx.req.get_post_args().action == "SAVE") ) then
      mapParams.dnsServer = baseDHCPOptions .. "@" .. dnsIndex .. ".value"
  end
  if (dnsIndex == #dhcp.options + 1) and (ngx.var.request_method == "POST") and (ngx.req.get_post_args().action == "SAVE") then
    proxy.add(baseDHCPOptions)
  end

  content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

  if ngx.var.request_method == "POST" then
    if not next(helpmsg) then
      if not post_helper.isFeatureEnabled("lanNetwork", role) and curintf == "guest" then
        proxy.set("uci.firewall.rule.@drop_lan_2_Guest_GW.dest_ip", content.localdevIP)
        proxy.set("uci.firewall.rule.@Allow_Guest_ICMP.dest_ip", content.localdevIP)
      end
      if not post_helper.isFeatureEnabled("lanNetwork", role) and curintf == "Guest1" then
        proxy.set("uci.firewall.rule.@drop_lan_2_Guest1_GW.dest_ip", content.localdevIP)
        proxy.set("uci.firewall.rule.@Allow_Guest1_ICMP.dest_ip", content.localdevIP)
      end
      if curintf == "wlnet_b_5" then
        proxy.set("uci.firewall.rule.@drop_lan_2_z_wlnetb5_GW.dest_ip",content.localdevIP)
        proxy.set("uci.firewall.rule.@Allow_z_wlnetb5_ICMP.dest_ip",content.localdevIP)
      end
      if curintf == "wlnet_b_24" then
        proxy.set("uci.firewall.rule.@drop_lan_2_z_wlnetb24_GW.dest_ip",content.localdevIP)
        proxy.set("uci.firewall.rule.@Allow_z_wlnetb24_ICMP.dest_ip",content.localdevIP)
      end
    end
    if not helpmsg.domainName then
      proxy.set(format("uci.network.interface.@%s.domain", curintf), content.domainName)
      proxy.apply()
    end
    if not next(helpmsg) then
      local dhcp_options_path = "uci.dhcp.dhcp.@"..cur_dhcp_intf..".dhcp_option."
      local dhcp_options = content_helper.convertResultToObject(dhcp_options_path,proxy.get(dhcp_options_path))
      for _, dhcpOptData in ipairs(dhcp_options) do
        if dhcpOptData.value:match("^3,") then
          proxy.del(dhcp_options_path..dhcpOptData.paramindex..".")
        end
      end
    end
  end
  -- because we do the localdevmask validation in localdevIP validation, we check if local ip starts with error msg "[netmask]".
  -- If so move it to localdevmask
  if helpmsg.localdevIP then
    local msg = match(helpmsg.localdevIP, '^%[netmask%] (.*)')
    if msg then
      helpmsg.localdevIP = nil
      helpmsg.localdevmask = msg
    end
  end
  for i, v in pairs(intfes) do
    if helpmsg["dhcpLimit"..v] then
      local msg = match(helpmsg["dhcpLimit"..v], '^%["dhcpStart"..v%] (.*)')
      if msg then
        helpmsg["dhcpLimit"..v] = nil
        helpmsg["dhcpStart"..v] = msg
      end
    end
  end

  -- post_helper restores values that have been removed during validation
  -- so if you remove the dns server, it will still be displayed on the page (though correctly set in datamodel)
  -- this handles this case
  if dnsRemoved then
    content.dnsServer = ""
  end
  if content.dnsServer == nil then
    local localIP = proxy.get("uci.network.interface.@" .. curintf .. ".ipaddr")[1].value
    content.dnsServer = localIP
  else
    if content.dnsServer:find("^6,") == 1 then
      content.dnsServer = (content.dnsServer or ""):sub(3) -- the dhcp option will contain "6," at the start
    end
  end

  if content.dhcpv4State == "" or content.dhcpv4State == "enabled" then
    content.dhcpv4State = "server"
  end
  local ra = proxy.get("uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".ra")[1].value
  if content.dhcpv6State == "server" and ra == "server" then
    content.dhcpv6State = "server"
  else
    content.dhcpv6 = "disabled"
  end
  for i, v in pairs(intfes) do
    if content["leaseTime"..v] then
      if content["leaseTime"..v] == "infinite" then
        content["leaseTime"..v] = validator.ethtrans().eth_infinit
     elseif not match(content["leaseTime"..v],"^0*([1-9]%d*[smhdw])$") then
        content["leaseTime"..v] = content["leaseTime"..v] .. "s"
      end
    end
  end
  local baseip = content.localdevIP
  local netmask = content.localdevmask
  for _, v in pairs(intfes) do
    v = (v ~= "loopback" and v ~= "Guest1" and v ~= "Guest1_5GHz") and v or cur_dhcp_intf
    dhcpIP["start"..v] = tonumber(content["dhcpStart"..v])
    dhcpIP["numips"..v] = tonumber(content["dhcpLimit"..v])
    if dhcpIP["start"..v] and dhcpIP["numips"..v] and not helpmsg.localdevIP and not helpmsg.localdevmask and not helpmsg["dhcpStart"..v] and not helpmsg["dhcpLimit"..v] then
        dhcpIP["ipStart"..v], dhcpIP["ipEnd"..v], network = DHCPStartAndLimitAddress(baseip, netmask, dhcpIP["start"..v], dhcpIP["numips"..v])
        session:store("networkAddr", network)
      if dhcpIP["ipStart"..v] then
        session:store("dhcpStartAddr"..v, dhcpIP["ipStart"..v])
        session:store("dhcpEndAddr"..v, dhcpIP["ipEnd"..v])
      end
    else
      dhcpIP["ipStart"..v] = session:retrieve("dhcpStartAddr"..v)
      dhcpIP["ipEnd"..v] = session:retrieve("dhcpEndAddr"..v)
      network = session:retrieve("networkAddr")
    end

    if helpmsg["leaseTime"..v] then
      content["leaseTime"..v] = ngx.req.get_post_args()["leaseTime"..v]
    end
    if helpmsg["dhcpStart"..v] then
      dhcpIP["ipStart"..v] = ngx.req.get_post_args()["dhcpStartAddress"..v]
    end
    if helpmsg["dhcpLimit"..v] then
      dhcpIP["ipEnd"..v] = ngx.req.get_post_args()["dhcpEndAddress"..v]
    end
  end

  local function updateVpnConfig(param)
    local vpnConfigVal = proxy.get("uci.vpn.l2tpipsecserver." .. param)[1].value
    local dhcpDevIP = content["localdevIP"]
    if vpnConfigVal and dhcpDevIP then
      return (match(dhcpDevIP, "(%d+%.%d+%.%d+)%.%d+")) ..".".. (match(vpnConfigVal, "%d+%.%d+%.%d+%.(%d+)"))
    end
  end

  -- VPN config param's, in which the DHCP config changes are applicable
  local vpnParam = {
    local_ip = "uci.vpn.l2tpipsecserver.local_ip",
    remote_ip_start = "rpc.l2tpipsecserver.remote_ip_start",
    remote_ip_end = "rpc.l2tpipsecserver.remote_ip_end",
  }

  if ngx.var.request_method == "POST" then
    local gwIP = session:retrieve("old_ip")
    if curintf == "lan" and content.localdevIP ~= gwIP and not next(helpmsg) then
      modemIPChangeState = "1"
    end
    session:store("old_ip", (content.localdevIP))

    -- Redirect the GUI only if the local GW device IP address is changed for the "lan" interface
    if curintf == "lan" and content.localdevIP ~= gwIP and not next(helpmsg) then
      -- Check to apply the changes for VPN config, when DHCP config is altered
      if ngx.req.get_post_args().action == "SAVE" then
        if not post_helper.isFeatureEnabled("lanNetwork", role) then
          for param, path in pairs(vpnParam) do
            local updatedVpnIp = updateVpnConfig(param)
            if updatedVpnIp then
              proxy.set(path, updatedVpnIp)
              proxy.apply()
            end
          end
       end
      end  ngx.print('\
      <script type ="text/javascript">\
	window.setTimeout(function(){\
        window.location = "http://');  ngx.print(content.localdevIP); ngx.print('";}, 10000);\
      </script>\
      ');  session:logout()
    end
  else
    session:store("old_ip", (content.localdevIP))
  end

  if type(content) == "table" then
    for _, ethPortVal in ipairs(ethports) do
      if (content[ethPortVal[1]] == "1") then
        ethports_checked[#ethports_checked + 1] = ethPortVal[1]
      end
    end
  end
end

local function resetreboot(path, value)
  proxy.set(path, value)
  ngx.header.content_type = "application/json"
  ngx.print('{ "success":"true" }')
  ngx.timer.at(0, function()
    proxy.apply()
  end)
  ngx.exit(ngx.HTTP_OK)
end

if ngx.var.request_method == "POST" and ngx.req.get_post_args().action == "BRIDGED" then
  if not bridged.isBridgedMode() then
    bridged.configBridgedMode()
    return resetreboot("rpc.system.reboot", "GUI")
  end
end
  ngx.print('\
\
');  
if post_helper.getVariantValue(variantHelper, "resetConfig") then
  ngx.print(ui_helper.createHeader(T"Local Network", true, true))
else
  ngx.print(ui_helper.createHeader(T"Local Network", true, false, nil, nil, true))
end
  ngx.print('\
  <div class = "modal-body update">\
');  
if not post_helper.isFeatureEnabled("localNetwork", role) and role ~= "admin" and post_helper.variantHasAccess(variantHelper, "ipextras", role) or not post_helper.isFeatureEnabled("lanNetwork", role) and role ~= "admin" or not post_helper.isFeatureEnabled("publicLANInterface", role) then
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-localnetwork.lp")
end
  ngx.print('\
\
    <form class = "form-horizontal" method = "post" action="');  ngx.print( ngx.var.request_uri ); ngx.print('">\
      ');  
        -- Do not display the navlist on the list if only 1 lan interface
      if #lan_intfs> 1 and (not bridged.isBridgedMode()) then
        ngx.print('\
      <div class = "span2">\
        <ul class = "nav nav-list">\
          ');  
          local html = { format('<li class="nav-header">%s</li>', T"LAN Interfaces")}
          local checkGuestSSID = checkCurrentUser(currentuser)
          html[#html + 1] = ui_helper.createSimpleInputHidden("ipChanged", "")
          html[#html + 1] = ui_helper.createSimpleInputHidden("ipList", "")
          local url
          if not post_helper.isFeatureEnabled("localNetwork", role) then
            local tmpEth = {}
            local tmpR24 = {}
            local tmpR5 = {}

           for row, intf in ipairs(lan_intfs) do
             if intf.radio == "noradio" then
               tmpEth[#tmpEth + 1] = lan_intfs[row]
             elseif intf.radio == "2.4GHz" then
               tmpR24[#tmpR24 + 1] = lan_intfs[row]
             else
               tmpR5[#tmpR5 + 1] = lan_intfs[row]
             end
           end
           local lanInterfaces = tmpEth
           for radio, v in ipairs(tmpR24) do
             lanInterfaces[#lanInterfaces + 1] = tmpR24[radio]
           end
           for radio, v in ipairs(tmpR5) do
             lanInterfaces[#lanInterfaces + 1] = tmpR5[radio]
           end
           local ethExist = 0
           for _, intfs in ipairs(lanInterfaces) do
             if intfs.radio ~= "" then
               if intfs.radio == "5GHz" or intfs.radio == "2.4GHz" then
                   html[#html + 1] = format('<li class="nav-header">%s %s</li>', T"Access point", intfs.radio)
               else
                 if ethExist == 0 then
                   html[#html + 1] = format('<li class="nav-header">%s</li>', T"Ethernet")
                   ethExist = 1
                 end
               end
             end
             local active = ""
             if intfs.index == curintf then
               active = "active"
             end
             if intfs.index ~= "public_lan" and intfs.index ~= "loopback" then
               url = "modals/ethernet-modal.lp?intf=" .. intfs.index
               html[#html+1] = format('<li class="%s"><a id = "%s" href="#" data-remote="%s">%s</a></li>', active, intfs.index, url, intfs.name)
             elseif role ~= "ispuser" and intfs.index == "public_lan" then
               url = "modals/ethernet-modal.lp?intf=" .. intfs.index
               html[#html+1] = format('<li class="%s"><a id = "%s" href="#" data-remote="%s">%s</a></li>', "advanced hide " ..active, intfs.index, url, "Public Lan")
             end
           end
           ngx.print(html)
           elseif not post_helper.isFeatureEnabled("publicLANInterface", role) then
             for _, interface in ipairs(lan_intfs) do
               if interface.index == curintf then
                 url = "modals/ethernet-modal.lp?intf=" .. interface.index
                 html[#html + 1] = format('<li class="%s"><a id = "%s" href="#" data-remote="%s">%s</a></li>', "active", interface.index, url, interface.name)
                 break
               end
             end
             ngx.print(html)
           else
           for _, interface in ipairs(lan_intfs) do
             local active = ""
             if interface.index == curintf then
               active = "active"
             end
             if not post_helper.isFeatureEnabled("lanNetworkIP", role) then
                if interface == curintf then
                 active = "active"
               end
                url = "modals/ethernet-modal.lp?intf=" .. interface
                html[#html + 1] = format('<li class="%s"><a href="#" data-remote="%s">%s</a></li>', active, url, interface)
             else
               url = "modals/ethernet-modal.lp?intf=" .. interface.index
               if interface.index ~= "loopback" then
                 if interface.index == "public_lan" then
                   html[#html + 1] = format('<li class="%s"><a id = "%s" href="#" data-remote="%s">%s</a></li>', "advanced hide " ..active, interface.index, url, "Public Lan")
                 else
                   if post_helper.getVariantValue(variantHelperWireless, "hideGuestSSID") then
                     if (checkGuestSSID and match(interface.index, "lan")) or not checkGuestSSID  then
                       html[#html + 1] = format('<li class="%s"><a id="%s" href="#" data-remote="%s">%s</a></li>', active, interface.index, url, interface.name)
                     end
                   else
                     html[#html + 1] = format('<li class="%s"><a id="%s" href="#" data-remote="%s">%s</a></li>', active, interface.index, url, interface.name)
                   end
                 end
               end
             end
           end
           if not bridged.isBridgedMode() and not post_helper.isFeatureEnabled("lanNetworkIP", role) then
             html[#html + 1] = format('<li class="nav-header">%s</li>', T"VLAN Interfaces")
             html[#html + 1] = format('<li><a href="#" data-remote="modals/bridge-modal.lp">%s</a></li>', T"VLAN")
           end
           ngx.print(html)
         end
            ngx.print('\
        </ul>\
      </div>\
      <div class = "span6">\
        ');  
        html = {}
        if not post_helper.isFeatureEnabled("lanNetworkIP", role) then
          html[#html + 1] = ui_helper.createMessages(message_helper.popMessages())
          local intfDescr = {
            lan = T"'lan' is the local network that is used for the wifi associated with (SSID of " .. T"main wifi).",
            Guest1 = T"'Guest1' is the local network that is used for the wifi associated with (SSID of " .. T"Guest wifi).",
            Guest1_5GHz = T"'Guest1_5GHZ' is the local network that is used for the wifi associated with (SSID of " .. T"Guest 5GHz wifi).",
          }
          local intfDescrAttr = {
            alert = {
              class = "alert-info"
            }
          }
          html[#html + 1] = ui_helper.createAlertBlock(intfDescr[curintf], intfDescrAttr)
          ngx.print(html)
        end
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
          if curintf == "public_lan" then
            local publicSubnetSetting = {
              group = {
                class = "public-subnet-settings"
              }
          }  ngx.print('\
          <div class = "advanced hide">\
	    <legend>');  ngx.print( T"Public Subnet Settings" ); ngx.print('</legend>\
              ');  
	       -- Labels thats shows Public Subnet info
              ngx.print(
              ui_helper.createLabel(T"CPE IP Address", params.localcpeip, publicSubnetSetting, error_msg.localcpeip),
              ui_helper.createLabel(T"Subnet Mask", params.localpublicmask, publicSubnetSetting, error_msg.localpublicmask)
              )
                ngx.print('\
          </div>\
        ');  else  ngx.print('\
          <legend>');  ngx.print( T"Global Information" ); ngx.print('</legend>\
            ');  
            -- Labels that shows the Local Device IP address & network subnet
            ngx.print(
            ui_helper.createInputText(T"Local Device IPv4 address", "localdevIP", content.localdevIP, {}, helpmsg.localdevIP),
            ui_helper.createInputText(T"Local Network subnet", "localdevmask", content.localdevmask, advanced, helpmsg.localdevmask)
            )
            local wait_for_reset = {
              group = {
                class = "advanced hide"
              },
              button = {
                id = "btn-dhcp-reset"
              }
            }
            local IPv6_prefix_pattern = {
              group = {
                id = "ipv6-prefix"
              }
            }
            local IPv6_local_prefix_pattern = {
              group = {
                id = "ipv6-local-prefix"
              }
            }
            local html = {}
            if post_helper.getVariantValue(variantHelper, "resetConfig") then
              html[#html + 1] = ui_helper.createButton(T"Restore Default Configuration", T"Reset Configuration", "icon-bolt", wait_for_reset)
              ngx.print(html)
            end
            html = {}
            if not bridged.isBridgedMode() then
              if curintf == "lan" then
                if not post_helper.isFeatureEnabled("localNetwork", role) then
                  if role == "engineer" then
                    html[#html + 1] =  ui_helper.createSwitch(T"IPv6 state", "dhcpv6State", content["dhcpv6State"], switchDHCP)
                  else
                    if content.dhcpv6State == "server" then
                      html[#html + 1] = ui_helper.createLabel(T"IPv6 state", T"enabled");
                    else
                      html[#html + 1] = ui_helper.createLabel(T"IPv6 state", T"disabled");
                    end
                  end
                  ngx.print(html)
                  html = {}
                  if content.dhcpv6State ~= "server" then
		    html[#html + 1] =  ui_helper.createLabel(T"Local Device IPv6 address", T"IPv6 not assigned", advanced)
	          elseif content.dhcpv6State == "server" and IPv6Address.uniqueGlobalAddr == "" and IPv6Address.uniqueGlobalAddr == "" then
		    html[#html + 1] = ui_helper.createLabel(T"Local Device IPv6 address", T"IPv6 not assigned", advanced)
	          else
	            if IPv6Address.uniqueGlobalAddr ~= "" then
		      html[#html + 1] = ui_helper.createLabel(T"Local Device IPv6 address", IPv6Address.uniqueGlobalAddr, advanced)
	            else
		      html[#html + 1] = ui_helper.createLabel(T"Local Device IPv6 address", IPv6Address.uniqueLocalAddr, advanced)
	            end
                  end
                  if role == "engineer" then
                    html[#html + 1] =  ui_helper.createCheckboxGroup(T"Ethernet Ports enabled", "ethports", ethports, ethports_checked, {checkbox = { class="inline" }}, nil)
                  end
                end
                ngx.print(html)
              end
              if not post_helper.isFeatureEnabled("lanNetwork", role) or not post_helper.isFeatureEnabled("lanNetworkIP", role) then
                ngx.print(
                ui_helper.createSwitch(T"IPv6 state", "dhcpv6State", content.dhcpv6State, switchDHCP_prefix)
                )
                if post_helper.getVariantValue(variantHelper, "ipv6Prefix") then
                  ngx.print(ui_helper.createLabel(T"IPv6 Prefix", IPv6Address.ip6_prefix, IPv6_prefix_pattern),
                  ui_helper.createLabel(T"IPv6 Network Received Prefix", IPv6Address.ip6_prefix_network, IPv6_local_prefix_pattern)
                  )
                end
              end
              if role == "engineer" and post_helper.isFeatureEnabled("lanNetwork", role) and post_helper.isFeatureEnabled("localNetwork", role) then
              ngx.print('\
               <div class = "advanced hide">\
                ');  
                ngx.print(
                ui_helper.createSwitch(T"IPv6 state", "dhcpv6State", content.dhcpv6State, switchDHCP),
                ui_helper.createLabel(T"IPv6 Prefix", IPv6Address.ip6_prefix, advanced),
                ui_helper.createLabel(T"Local Device IPv6 address", IPv6Address.uniqueGlobalAddr, advanced)
              )
              if content["localIPv6"] ~= "0" and curip6prefix ~= "" and post_helper.isFeatureEnabled("ipv6GUA") then
                ngx.print(ui_helper.createLabel(T"IPv6 GUA", curip6prefix))
              end
                 ngx.print('\
               </div>\
              ');  
              end
              if curintf == "lan" and role == "engineer" then
                local checkbox1 = {
                  group = {
                    class = "advanced hide"
                  },
                  checkbox = {
                    class = "inline"
                  }
                }
                if post_helper.isFeatureEnabled("localNetwork", role) then
	          ngx.print(
                    ui_helper.createCheckboxGroup(T"Ethernet Ports enabled", "ethports", ethports, ethports_checked, checkbox1, nil)
                  )
                end
              end
                ngx.print('\
              <legend>');  ngx.print(T"DHCP Settings" ); ngx.print('</legend>\
              ');  
              ngx.print(
                ui_helper.createSwitch(T"DHCP Server", "dhcpv4State", content.dhcpv4State, switchDHCP)
              )
              for _, v in pairs(intfes) do
                if v ~= "STB" then
                  ngx.print(ui_helper.createLabel(T"Network address", network, advanced))
                end
              end
              if post_helper.isFeatureEnabled("DnsServer", role) and dns_visible_value == "true" then
              ngx.print(
                ui_helper.createInputText(T"DNS server", "dnsServer", content.dnsServer, advanced, helpmsg.dnsServer)
              )
              end
              if not post_helper.isFeatureEnabled("publicLANInterface", role) then
                ngx.print(
                  ui_helper.createInputText(T"Domain", "domainName", content.domainName, advanced, helpmsg.domainName)
                )
               end
               if role == "engineer" and post_helper.isFeatureEnabled("localNetwork", role) then
                ngx.print(
                ui_helper.createSwitch(T"DHCPv6 Stateful", "dhcpv6Stateful", content.dhcpv6Stateful, switchDHCPv6)
                )
               end
               for _, intf in pairs(intfes) do
                 intf = (intf ~= "loopback" and intf ~= "Guest1" and intf ~= "Guest1_5GHz") and intf or cur_dhcp_intf   ngx.print('\
                <legend class = "advanced hide control-group">');  ngx.print( T"DHCP Pool ".. string.upper(intf) ); ngx.print('</legend>\
                ');  if role == "admin" and intf == "STB" or not post_helper.isFeatureEnabled("localNetwork", role) and intf == "STB" then
                  ngx.print(
                    ui_helper.createLabel(T"Start address", dhcpIP["ipStart"..intf], advanced),
                    ui_helper.createLabel(T"End address", dhcpIP["ipEnd"..intf], advanced),
                    ui_helper.createLabel(T"Lease time", content["leaseTime"..intf], advanced)
                  )  ngx.print('\
                 <input type = "hidden" name = \'dhcpStartAddress');  ngx.print(intf ); ngx.print('\' value = ');  ngx.print( dhcpIP["ipStart"..intf]); ngx.print(' >\
                 <input type = "hidden" name = \'dhcpEndAddress');  ngx.print(intf ); ngx.print('\' value = ');  ngx.print( dhcpIP["ipEnd"..intf]); ngx.print(' >\
                 <input type = "hidden" name = \'leaseTime');  ngx.print(intf ); ngx.print('\' value = ');  ngx.print( content["leaseTime"..intf]); ngx.print(' >\
                ');  
                else
                  ngx.print(
                  ui_helper.createInputText(T"Start address", "dhcpStartAddress".. intf, dhcpIP["ipStart"..intf], advanced, helpmsg["dhcpStart"..intf]),
                  ui_helper.createInputText(T"End address", "dhcpEndAddress".. intf, dhcpIP["ipEnd"..intf], advanced, helpmsg["dhcpLimit"..intf]),
                  ui_helper.createInputText(T"Lease time", "leaseTime"..intf, content["leaseTime" ..intf], advanced, helpmsg["leaseTime"..intf])
                  )
                end
              end  ngx.print('\
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
                   ');  if role == "engineer" and post_helper.isFeatureEnabled("localNetwork", role) or not post_helper.isFeatureEnabled("lanNetworkIP", role) then
                   if not post_helper.isFeatureEnabled("lanNetworkIP", role) then   ngx.print('\
                     <legend>');  ngx.print( T"Network mode" ); ngx.print('</legend>\
                   ');  else  ngx.print('\
                     <legend class = "advanced hide">');  ngx.print( T"Network mode" ); ngx.print('</legend>\
                   ');  end
                   local rebooting = {
                     alert = {
                       class = "alert hide",
                       id = "rebooting-msg"
                     }
                   }
                   local confirming = {
                     alert = {
                       class = "alert hide",
                       id = "confirming-msg"
                     }
                   }
                   html = {}
                   if post_helper.isFeatureEnabled("lanNetworkIP", role) then
                     local bridged_button = {
                       group = {
                         class = "advanced hide"
                       },
                       button = {
                         id = "btn-bridged"
                       }
                     }
                     html[#html + 1] = ui_helper.createButton(T"Bridged Mode", "Bridged Mode", "icon-cog", bridged_button)
                     else
                       local bridged_button = {
                         button = {
                         id = "btn-bridged"
                         }
                       }
                      html[#html + 1] = ui_helper.createButton(T"Bridged Mode", "Bridged Mode", "icon-cog", bridged_button)
                   end
                   html[#html + 1] = string.format('<div class="control-group controls">')
                   html[#html + 1] = ui_helper.createAlertBlock(T"Switching to <strong>Bridged Mode</strong> and restarting, please wait...", rebooting)
                   html[#html + 1] = ui_helper.createAlertBlock(T"Are you sure to switch the modem to <strong>Bridged Mode</strong>?", confirming)
                   html[#html + 1] = string.format([[
                   <div id = "bridged-changes" class = "hide">
                     <div id = "bridged-confirm" class = "btn btn-primary" data-dismiss = "modal">%s</div>
                     <div id = "bridged-cancel" class = "btn">%s</div>
                   </div>
                   </div>
                   ]], T"Confirm", T"Cancel")
                   ngx.print(html)
                     ngx.print('\
                 ');  
                  end
              end
             else
              local infomessage = {
                alert = {
                  class = "alert"
                }
              }
              if post_helper.getVariantValue(variantHelper, "bridgedReset") then
                html[#html + 1] = ui_helper.createAlertBlock(T[[Note: your gateway is in Bridged Mode. If you want the gateway to run in Routed Mode again, please do factory reset <a href="javascript:tch.loadModal('/modals/system-config-modal.lp')">here</a>]], infomessage)
                ngx.print(html)
              end
            end
            ngx.print('\
          </fieldset>\
              ');  
              end
                ngx.print('\
          ');  
          -- Do not display the navlist on the list if only 1 lan interface
          if #lan_intfs > 1 then
            ngx.print('\
          </div>\
          ');  
          end
            ngx.print('\
          <input type = "hidden" name = "isAdvanced" id = "isAdvanced" value = "0">\
        </form>\
   </div>\
<script>\
  var curintfValue = "');  ngx.print( curintf ); ngx.print('";\
  var currentlanip = "');  ngx.print( content.localdevIP ); ngx.print('";\
  var confirmMessage = "');  ngx.print( T"Do you want to reset this page to default settings?" ); ngx.print('";\
  var resetData = ');  ngx.print( json.encode(resetData) ); ngx.print(';\
  var inUseFlagValue = ');  ngx.print( inUseFlag ); ngx.print(';\
  var dnsServerRoleSupported = "');  ngx.print( dnsServerRole ); ngx.print('";\
</script>\
<script src="/js/ethernet.js"></script>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
'); 