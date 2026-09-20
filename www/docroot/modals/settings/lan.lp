--pretranslated: do not change this file
 
--Enable localization
gettext.textdomain('webui-core')
local bit = require("bit")
local json = require("dkjson")
local proxy = require("datamodel")
local ui_helper = require("vdf_ui_helper")
local vdf_helper = require("vodafone_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")

local isMAC = post_helper.validateQTN
local ipv42num = post_helper.ipv42num
local numToIPv4 = post_helper.num2ipv4
local gatewayName = vdf_helper.productName()
local splitIP = vdf_helper.split_IP_into_Octets
local isIPv4 = post_helper.getValidateStringIsDeviceIPv4
local validateDHCPIgnore = post_helper.validateDHCPIgnore
local isNumberInRange = post_helper.getValidateNumberInRange
local calculateDHCPStartAndLimitAddress = vdf_helper.calculateDHCPStartAndLimitAddress

local setMetaTable = setmetatable
local validatorNumberInRange = isNumberInRange(1,255)
local ipv4Content, ipv4Errmsg, startIPAddress, endIPAddress
local pairs, ipairs, ngx = pairs, ipairs, ngx
local string, tostring, tonumber, next = string, tostring, tonumber, next
local match, format, untaint, gsub = string.match, string.format, string.untaint, string.gsub

local success = ""
local session = ngx.ctx.session

--Function used  to handle reboot. When user changes gateway ipaddress, board starts reboots page sends status
--information as "progress". When reboot fails page automatically redirects to login page
local resetlan = {
  reset_ipaddress = "uci.uci-defaults.lan.ipaddress",
  reset_ipsubnet_mask = "uci.uci-defaults.lan.ipsubnet_mask",
  reset_hostname = "uci.uci-defaults.lan.hostname",
  reset_dhcpserver = "uci.uci-defaults.lan.dhcpserver",
  reset_address_pool_startip = "uci.uci-defaults.lan.address_pool_startip",
  reset_address_pool_endip = "uci.uci-defaults.lan.address_pool_endip",
  reset_leasetime = "uci.uci-defaults.lan.leasetime",
  reset_domainname = "uci.uci-defaults.lan.domainname",
  reset_localdnsserver = "uci.uci-defaults.lan.localdnsserver",
  reset_dnsproxy = "uci.uci-defaults.lan.dnsproxy",
}
content_helper.getExactContent(resetlan)

if ngx.req.get_method() == "GET" then
  if ngx.req.get_uri_args().getstatus == "true" then
    ngx.header.content_type = "application/json"
    ngx.print('{ "status":"progress" }')
    ngx.exit(ngx.HTTP_OK)
  end
end

----Lists in rpc.hosts.hosts only LAN device which are in connected state
local hostsList = proxy.get("rpc.hosts.host.")
hostsList = content_helper.convertResultToObject("rpc.hosts.host.", hostsList)
local connectedMACList = {}
local deviceInfo = {}
local deviceName
for _, host in pairs(hostsList) do
  if host["State"] == "1" and host["L2Interface"] ~= "eth5" then
    deviceName = host["FriendlyName"]
    if deviceName and deviceName:match(":") then
      deviceName = deviceName:gsub(":", "")
    end
    deviceInfo[#deviceInfo + 1] = {}
    deviceInfo[#deviceInfo].name = deviceName
    deviceInfo[#deviceInfo].mac = host["MACAddress"]
    deviceInfo[#deviceInfo].ip = match(host["IPAddress"], "%d+.%d+.%d+.%d+") or ""
    connectedMACList[host.MACAddress] = true
  end
end

local leaseTimes = {
  { "1h"  , T"1 Hour"},
  { "6h"  , T"6 Hours"},
  { "24h" , T"24 Hours"},
  { "infinite"  , T"Forever"},
}

local dhcpEnabledOptions = {
  {"disabled"},
  {""},
}

-- Filtering secureDNS details based on target "DNAT"
local secureDns =  content_helper.getMatchedContent("uci.firewall.redirect.", { target = "DNAT"} )

local STB_IP = {
  start = "uci.dhcp.dhcp.@STB_networkid.start",
  limit = "uci.dhcp.dhcp.@STB_networkid.limit"
}
content_helper.getExactContent(STB_IP)

-- function to validate Gateway IP not inside STB Pool range
-- @function STBIPValidation
-- @param #string ip the Gateway IP
-- @param #table object the post data from this page
-- @return #boolean true if IP is not inside STB Pool, nil+error msg otherwise
local function STBIPValidation(ip, object)
  -- Vodafone NZ does not support STB which result in empty value for start and end IP.
  -- In such case, bypass STBIPValidation
  if STB_IP.start == "" and STB_IP.limit == "" then
    return true
  end
  local GW_IP, netmask = ipv42num(ip), ipv42num(object.localdevmask)
  local STB_start, STB_end = calculateDHCPStartAndLimitAddress(GW_IP, netmask, tonumber(STB_IP.start), tonumber(STB_IP.limit))
  if not vdf_helper.validateIPRange(STB_start, STB_end)(ip) then
    return true
  end
  return nil, T"Cannot use IP in STB Pool"
end

--function is used to validate limit value which is in range (1,255) based given
--param @ip = end ipaddress
local function validateNewLimit(ip, object, key)
  local ipAddress = ipv42num(object["IPAddress"])
  local netmask = ipv42num(object["localdevmask"])
  local limitvalue, limitmsg = validatorNumberInRange(tonumber(ip))
  if not limitvalue then
    return nil, limitmsg
  end
  local startvalue, startmsg = validatorNumberInRange(tonumber(object["IPStart"]))
  if not startvalue then
    return nil, startmsg
  end
  local start = tonumber(object["IPStart"])
  local limitNum = tonumber(ip)
  if limitNum < start then
     return nil, T"Invalid range"
  end
  local _, _, _, limitval = calculateDHCPStartAndLimitAddress(ipAddress,netmask,start,limitNum)
  local validatorNumberInRange = post_helper.getValidateNumberInRange(1,limitval)
  local validEndIP = validatorNumberInRange(limitNum)
  if not validEndIP then
    return nil, T"DHCP End Address is not valid in Subnet Range"
  end
  if not post_helper.validateQTN(object.DHCPStart) then
    return nil, T"DHCP Start Addess Is Not Valid"
  end
  -- if board supports STB, do DHCP and STB Pools overlap check
  if STB_IP.start ~= "" and STB_IP.limit ~= "" then
    local STB_start, STB_end = calculateDHCPStartAndLimitAddress(ipAddress, netmask, tonumber(STB_IP.start), tonumber(STB_IP.limit))
    if ipv42num(object.DHCPStart) <= ipv42num(STB_end) and ipv42num(object.DHCPEnd) >= ipv42num(STB_start) then
      return nil, T"DHCP and STB Pools overlap each other"
    end
  end
  local limit = (tonumber(limitNum) - start) + 1
  object[key] = tostring(limit)
  return true
end

-- function is used to validatename. It should be in range 1 and 63 characters
local function validateName(name)
  if #name == 0 or #name > 63 then
    return nil, T"A devicename must be between 1 and 63 characters"
  end
  if match(name, "[^%w%-%.]") or not match(name, "%w") then
    return nil, T"A devicename must contain only alphanumeric characters and dash and dot"
  end
  return true
end

local startLoopback = ipv42num("127.0.0.0")
local endLoopback = ipv42num("127.255.255.255")
local startMulticastRange = ipv42num("224.0.0.0")
local endMulticastRange = ipv42num("239.255.255.255")
local limitedBroadcast = ipv42num("255.255.255.255")

local function validateDNS(value, object, key)
  local valid, helpmsg_validip = post_helper.validateStringIsIP(value, object, key)
  if valid then
    local isNetmask = post_helper.validateIPv4Netmask(value)
    if isNetmask then
      return nil, T"Cannot use netmask as DNS server IP"
    end
    local ip = ipv42num(value)
    if not ip then
      return nil, T"Invalid IP Address."
    end
    if startLoopback <= ip and ip <= endLoopback then
      return nil,T"Cannot use IPv4 loopback address range"
    end
    if startMulticastRange <= ip and endMulticastRange >= ip then
      return nil, T"Cannot use a multicast address"
    end
    if limitedBroadcast == ip then
      return nil, T"Cannot use the limited broadcast destination address"
    end
    if value ~= object["IPAddress"] and post_helper.getValidateStringIsIPv4InNetwork(object["IPAddress"], object["localdevmask"])(value) then
      local res, errmsg = isIPv4(object["IPAddress"], object["localdevmask"])(value)
      if not res then
        return nil, errmsg
      end
    end
    if not post_helper.validateQTN(value) then
      return nil, T"Entered IP is Quantenna IP"
    end
    local successRes, errmsgRes = post_helper.reservedIPValidation(value)
    if not successRes then
      return nil, errmsgRes
    end
  else
    return nil, helpmsg_validip
  end
  return true
end

--function validateAndCalculateNewStart is used to validate given startip is valid ipAddress
--and given start value within range of(1,255)
local function validateAndCalculateNewStart(ip, object, key)
  local inRange, inRangeErrmsg = validatorNumberInRange(tonumber(ip))
  if not inRange then
    return nil, inRangeErrmsg
  end
  local ipAddress = ipv42num(object["IPAddress"])
  local netmask = ipv42num(object["localdevmask"])
  if not netmask or not ipAddress  then
    return nil, T"Invalid IP"
  end
  local start = tonumber(object["IPStart"])
  local limit = tonumber(object["IPEnd"])
  local limitvalue, limitmsg = validatorNumberInRange(start)
  if not limitvalue then
    return nil, limitmsg
  end
  local startAddress,_, network ,limitval = calculateDHCPStartAndLimitAddress(ipAddress,netmask,start,limit)
  local validatorNumberInRange = post_helper.getValidateNumberInRange(1,limitval)
  local validstartIP = validatorNumberInRange(start)
  if not validstartIP then
    return nil, T"DHCP Start Address is not valid in Subnet Range"
  end
  ipAddress = numToIPv4(ipAddress)
  if startAddress == ipAddress then
    return nil, T("Invalid Input.Ensure DHCP Start Address should not be equal to IP Address of " .. gatewayName ..".")
  elseif startAddress == network then
    return nil, T"Invalid Input.Ensure DHCP Start Address should not be equal to Network address."
  end
  object[key] = tostring(start)
  return true
end

local ipv4Content = {
  IPAddress  = "uci.network.interface.@lan.ipaddr",
  localdevmask = "uci.network.interface.@lan.netmask",
  hostName   = "uci.network.interface.@lan.hostname",
  IPStart    = "uci.dhcp.dhcp.@lan.start",
  IPEnd      = "uci.dhcp.dhcp.@lan.limit",
  domainName = "uci.dhcp.dnsmasq.@dnsmasq.domain",
  leaseTime  = "uci.dhcp.dhcp.@lan.leasetime",
  dhcpv4State = "uci.dhcp.dhcp.@lan.dhcpv4",
  dhcpIgnore = "uci.dhcp.dhcp.@lan.ignore",
}
content_helper.getExactContent(ipv4Content)
local currentHostName = ipv4Content["hostName"]
local ipAddress = ipv42num(ipv4Content["IPAddress"])
local netmask = ipv42num(ipv4Content["localdevmask"])
local start  = tonumber(ipv4Content["IPStart"])
local limit = tonumber(ipv4Content["IPEnd"])
if ipAddress and netmask and netmask and limit then
  startIPAddress, endIPAddress = calculateDHCPStartAndLimitAddress(ipAddress, netmask, start, limit)
end

local function getDnsServer(path)
  local dnsServerIp = proxy.get(path) or {}
  dnsServerIp = dnsServerIp[1] and dnsServerIp[1].value
  return dnsServerIp
end

-- DNS Server is obtained from uci.dhcp.dnsmasq.@dnsmasq.server.@1.value
-- If instance doesn't exist, assume there is no DNS Server
local dnsServerPath = "uci.dhcp.dnsmasq.@dnsmasq.server."
local dnsServer = getDnsServer(dnsServerPath)
if not dnsServer or dnsServer == "" then
  local localDnsServer = proxy.get("rpc.network.interface.@lan.ipaddr") or {}
  dnsServer = localDnsServer[1] and localDnsServer[1].value or ''
end

-- DNS proxy is obtained from uci.dhcp.dhcp.@lan.dhcp_option.
-- If any value listed in above path contains Option 6 (<TAG>,6,<IP>)
-- and the IP is not GW IP, then DNS Proxy is OFF.
-- Otherwise (if there is no Option 6 or IP is GW IP), DNS Proxy is ON
local dhcpPath = "uci.dhcp.dhcp.@lan.dhcp_option."
local dnsProxy, dhcpOptionIndex = true
local dhcpOptionsList = proxy.get(dhcpPath) or {}
local opt6Paths = {}


for i, v in ipairs(dhcpOptionsList) do
  local opt6 = v.value:match("^6,\"?([^\"]*)\"?")
  if opt6 then
    if post_helper.validateStringIsIP(opt6) and not dhcpOptionIndex then
      dhcpOptionIndex = v.path:match(".@(%d+)\.")
      dnsProxy = dnsServer == ipv4Content.IPAddress
    else
      opt6Paths[#opt6Paths+1] = v.path
    end
  end
end

-- function to update dns related information
-- Argument postArgs will contain post related data
-- return boolean
local function dnsUpdate(postArgs)
  if validateName(postArgs.hostName) then
    local dnsHostnamePath = "uci.dhcp.dnsmasq.@dnsmasq.hostname."
    local dnsHostname = proxy.get(dnsHostnamePath) or {}
    local index
    for i,v in ipairs(dnsHostname) do
      if v.value == currentHostName or v.value == resetlan.reset_hostname then
        index = i
      end
    end
    local dnsHostnameContent = {
      dnsHostname = postArgs.hostName
    }
    local dnsHostnameParam = {
      dnsHostname = "value"
    }
    if not index then
      content_helper.addNewObject(dnsHostnamePath .. "@.", dnsHostnameContent, dnsHostnameParam)
    else
      content_helper.setObject(dnsHostnameContent, dnsHostnameParam, dnsHostnamePath .. "@" .. index .. ".")
    end
  else
    return nil
  end

  -- If User provides DNS Server, Save it in "uci.dhcp.dnsmasq.@dnsmasq.server."
  -- If instance doesn't exist, create one and save otherwise update.
  local DNSContent = {
    dns = postArgs.dnsServer,
    IPAddress = postArgs.IPAddress,
    localdevmask = postArgs.localdevmask
  }
  local DNSParam = {
    dns = "value"
  }
  local DNSValidation = {
    dns = post_helper.getOptionalValidation(validateDNS)
  }
  if content_helper.validateObject(DNSContent, DNSValidation) then
    dnsServer = getDnsServer(dnsServerPath)
    if not dnsServer then
      content_helper.addNewObject("uci.dhcp.dnsmasq.@dnsmasq.server.@.", DNSContent, DNSParam)
    else
      content_helper.setObject(DNSContent, DNSParam, "uci.dhcp.dnsmasq.@dnsmasq.server.@1.")
    end
  else
    return nil
  end

  -- If user disables DNS Proxy, Save the WAN DNS Server IP with DHCP Option 6 tag ("6,<IP>"), Also delete all the other Option 6 entries if exist
  -- If user enables DNS Proxy, delete the Option 6 entry
  if post_helper.validateBoolean(postArgs.dnsProxy) then
    local setTable = {}
    local index = secureDns and match(secureDns[1].path, ".(@%S+).")
    if postArgs.dnsProxy == "0" then
      local wanDNSPath = "rpc.network.interface.@wan.dnsservers"
      local wanDNS = proxy.get(wanDNSPath)[1].value
      wanDNS = wanDNS ~= "" and wanDNS:match("^([^,]+)") or "8.8.8.8"
      if not dhcpOptionIndex then
        dhcpOptionIndex = proxy.add(dhcpPath)
      end
      opt6 = format('6,%s', postArgs.dnsServer ~= "" and postArgs.dnsServer or wanDNS)
      setTable[format("%s@%s.value", dhcpPath, dhcpOptionIndex)] = opt6
      setTable[format("uci.firewall.redirect.%s.dest_ip",index)] = postArgs.dnsServer ~= "" and postArgs.dnsServer or wanDNS
    else
      if dhcpOptionIndex then
        opt6Paths[#opt6Paths+1] = format("%s@%s.", dhcpPath, dhcpOptionIndex)
       end
       setTable[format("uci.firewall.redirect.%s.dest_ip",index)] = postArgs["IPAddress"]
    end
    proxy.set(setTable)
  else
    return nil
  end

  -- Deleting a path reorders the entire list. So, Sort the paths in descending order based on index
  table.sort(opt6Paths, function(a, b)
    return tonumber(a:match(".@(%d+)\.")) > tonumber(b:match(".@(%d+)\."))
  end)

  -- Delete all Option 6 entries created from GUI
  for i = 1, #opt6Paths do
    proxy.del(opt6Paths[i])
  end
  proxy.apply()
  return true
end

local function WANIPValidation(ipAddress)
  local net_intfs_path = "rpc.network.interface."
  local all_intfs = content_helper.convertResultToObject(net_intfs_path .. "@.", proxy.get(net_intfs_path))

  local isWan, intf = post_helper.isWANIP(ipAddress, all_intfs)
  if isWan then
    return nil, T"Gateway IP should not be in " .. intf .." subnet range"
  end

  return true
end

local function validGWIP(ipAddress, object, key)
  local valid, err
  valid, err = post_helper.advancedIPValidation(ipAddress, object, key)
  if not valid then
    return nil, err
  end

  valid, err = STBIPValidation(ipAddress, object)
  if not valid then
    return nil, err
  end

  valid, err = post_helper.reservedIPValidation(ipAddress)
  if not valid then
    return nil, err
  end

  valid, err = WANIPValidation(ipAddress)
  if not valid then
    return nil, err
  end

  valid = post_helper.isPublicIP(ipAddress)
  if valid then
    return nil, T"Cannot use the public address."
  end

  return true
end

-- function to update all postdate
-- Argument addList, updateList, deleteList, postArgs
-- addList data for add new rule
-- updateList data for update existing entry
-- deletelist date to delete entry
-- postArgs contain all post data
-- return errorFlag, ipv4Errmsg, setFlag
local function postDataUpdate(addList, updateList, deleteList, postArgs)
  local isMACAddress, isIPAddress, isQTNIP
  local errorFlag, setFlag = false, false
  local basePath ="uci.dhcp.host."
  local paramMap =setMetaTable({
    ["mac"] = "mac",
    ["ip"] = "ip",
    ["name"] = "name"
  },untaint_mt)
  local addContent, updateContent
  local duplicateMAC = {}
  local duplicateIP  = {}

  -- deleting existing entry from static lease table
  if #deleteList > 0 then
    for i,j in ipairs(deleteList) do
      proxy.del(format(basePath.."%s.", j))
    end
    proxy.apply()
  end
  local oldStaticLeaseList = content_helper.convertResultToObject("uci.dhcp.host.", proxy.get("uci.dhcp.host."))
  for _, lease in ipairs(oldStaticLeaseList) do
    duplicateMAC[string.lower(untaint(lease.mac))] = true
    duplicateIP[untaint(lease.ip)] = true
  end
  local validateIPAdd

  -- Validating and populating newly added data
  if #addList > 0 then
    local basePath = "uci.dhcp.host.@."
    for _, j in ipairs(addList) do
      addContent = {}
      isMACAddress = isMAC(j.mac)
      validateIPAdd = isIPv4(postArgs["IPAddress"], postArgs["localdevmask"])
      isIPAddress = validateIPAdd(j.ip)
      isQTNIP = post_helper.validateQTN(j.ip)
      if not j.name or j.name == "" then
         errorFlag =true
         break
      end
      if not (isMACAddress and isIPAddress and isQTNIP) then
        errorFlag = true
      break
      end
      if duplicateMAC[string.lower(j.mac)] then
        errorFlag = true
        break
      else
       duplicateMAC[string.lower(j.mac)] = true
      end
      if duplicateIP[j.ip] and not post_helper.reservedIPValidation(j.ip) then
        errorFlag = true
        break
      else
       duplicateIP[j.ip] =true
      end
    end
    if not errorFlag then
      for _, j in ipairs(addList) do
        addContent["mac"] = j.mac
        addContent["ip"] = j.ip
        addContent["name"] = j.name
        success = content_helper.addNewObject(basePath, addContent, paramMap, nil, post_helper.getRandomKey())
        if not connectedMACList[j.mac] then
          local setTable = {}
          local deviceInstance = proxy.add("uci.user_friendly_name.name.", post_helper.getRandomKey())
          local path = format("uci.user_friendly_name.name.@%s.name", deviceInstance)
          setTable[path] = j.name
          path = format("uci.user_friendly_name.name.@%s.mac", deviceInstance)
          setTable[path] = j.mac
          if setTable and proxy.set(setTable) then
            setFlag = true
          end
        end
      end
    end
  end

  -- updating data in existing entry in static lease table
    if #updateList > 0 then
    for i,j in ipairs(updateList) do
      updateContent = {}
      validateIPAdd = isIPv4(postArgs["IPAddress"], postArgs["localdevmask"])
      isIPAddress = validateIPAdd(j.ip)
      isQTNIP = post_helper.validateQTN(j.ip)
      if not (isQTNIP and isIPAddress) then
        errorFlag = true
        break
      end
      if duplicateIP[j.ip] then
        errorFlag = true
        break
      else
        duplicateIP[j.ip] = true
      end
    end
    if not errorFlag then
      for i,j in ipairs(updateList) do
        updateContent[format(basePath.."%s.ip", j.index)] = j.ip
      end
    end
  end
  if not errorFlag then
    if proxy.set(updateContent) then
      setFlag = true
    end
  end
  -- After table validation, validations for handle query will be done.
  if not errorFlag and success then
    local params = {
      IPAddress  = "uci.network.interface.@lan.ipaddr",
      localdevmask = "uci.network.interface.@lan.netmask",
      hostName   = "uci.network.interface.@lan.hostname",
      IPStart    = "uci.dhcp.dhcp.@lan.start",
      IPEnd      = "uci.dhcp.dhcp.@lan.limit",
      domainName = "uci.dhcp.dnsmasq.@dnsmasq.domain",
      leaseTime  = "uci.dhcp.dhcp.@lan.leasetime",
      dhcpv4State = "uci.dhcp.dhcp.@lan.dhcpv4",
      dhcpIgnore = "uci.dhcp.dhcp.@lan.ignore",
    }
    local validations = {
      IPAddress    = validGWIP,
      localdevmask = post_helper.validateIPv4Netmask,
      IPEnd        = validateNewLimit,
      IPStart      = validateAndCalculateNewStart,
      domainName   = validateName,
      hostName     = validateName,
      leaseTime    = post_helper.getValidateInEnumSelect(leaseTimes),
      dhcpv4State  = post_helper.getValidateInEnumSelect(dhcpEnabledOptions),
      dhcpIgnore   = validateDHCPIgnore,
   }
    ipv4Content, ipv4Errmsg = post_helper.handleQuery(params, validations)
  end
  return errorFlag, ipv4Errmsg, setFlag
end
if ngx.req.get_method() == "POST" then
  local untaint_mt = require("web.taint").untaint_mt
  local postArgs = ngx.req.get_post_args()
  local tableList = json.decode(untaint(postArgs.tableRequest), 1, nil)
  tableList = setMetaTable(tableList, untaint_mt)
  local addList = tableList.ADD
  local updateList = tableList.UPDATE
  local deleteList = tableList.DELETE
  local dnsSuccess = true
  if postArgs.dnsCheck then
    dnsSuccess = dnsUpdate(postArgs)
  end
  local errorFlag, ipv4Errmsg, setFlag =  postDataUpdate(addList, updateList, deleteList, postArgs)
  if postArgs["isIPChanged"] == "1" then  ngx.print('\
    <!DOCTYPE html>\
    <html>\
    <head>\
    <title>');  ngx.print(T"Connecting.."); ngx.print('</title>\
    <meta charset="utf-8">\
    <meta name="viewport" content="width=device-width, initial-scale=1">\
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />\
    <link rel="stylesheet" type="text/css" href="/css/bootstrap.min.css">\
    <link rel="stylesheet" type="text/css" href="/css/vodafone.css">\
    <link rel="stylesheet" type="text/css" href="/css/global.css">\
    <link rel="stylesheet" type="text/css" href="/css/responsive.css">\
    <link rel="stylesheet" type="text/css" href="/css/vodafoneFont.css" />\
    <script src="/js/main-min.js"></script>\
    </head>\
    ');  session:store("isUpload",nil)
    if not errorFlag  and not next(ipv4Errmsg)  and dnsSuccess then
      proxy.set({["rpc.system.reboot"] = "GUI" })
      proxy.apply()
      ngx.print('\
    <body>\
      <div class="row">\
        <div class="modal install-update-popup-5" id="install-update-popup-5" role="dialog" data-backdrop = "static">\
          <div class="modal-dialog" style="margin-top: 18%;">\
            <!-- Modal content-->\
            <div class="modal-content">\
              <div class="modal-body">\
                <img src="/img/look_4/icons/icon-thinking.gif" alt="Loading..." />\
                <p class="modal-title tL">\
                  <span>');  ngx.print(T"Gateway IPAddress Changed"); ngx.print('\
                  </span>\
                </p>\
                <p class="big">\
                ');  if vdf_helper.getVariant() ~= "NZ" then  ngx.print('\
                  <span>');  ngx.print(T"Your EasyBox is now restarting. Please do not turn it off or press any buttons until it has restarted."); ngx.print('</span>\
                ');  else  ngx.print('\
                  <span>');  ngx.print(T("Your " .. gatewayName .. " is now restarting. Please do not turn it off or press any buttons until it has restarted.")); ngx.print('</span>\
                ');  end  ngx.print('\
                </p>\
              </div>\
            </div>\
          </div>\
        </div>\
      </div>\
    </body>\
    <script>\
      $(\'#install-update-popup-5\').modal();\
      var isDone = false;\
      function getStatus(target){\
      $.get(target, function(responseTxt, statusTxt, xhr){\
        if(isDone){\
          window.setTimeout(function(){\
            window.location = location.protocol+"//');  ngx.print(postArgs["IPAddress"]); ngx.print('";}, 10000);\
            return;\
        } else {\
          window.setTimeout(function(){\
          getStatus("/modals/settings/lan.lp?getstatus=true");}, 20000);\
        }\
      }).fail(function(data) {\
        isDone = true;\
        window.setTimeout(function(){\
          getStatus(location.protocol+"//');  ngx.print(postArgs["IPAddress"]); ngx.print('/login.lp?rb=1")}, 20000);\
      });\
      }\
      window.setTimeout(function() { getStatus("/modals/settings/lan.lp?getstatus=true");},20000);\
    </script>\
    ');  elseif (errorFlag  or next(ipv4Errmsg) or not dnsSuccess) then   ngx.print('\
    <body>\
      <div class="row">\
        <!-- Modal -->\
        <div class="modal install-update-popup-5" id="install-error-popup" role="dialog" data-backdrop = "static">\
          <div class="modal-dialog">\
            <!-- Modal content-->\
            <div class="modal-content">\
              <div class="modal-body">\
                <img src="/img/look_4/icons/status-indicators/info.png" alt="Error..." />\
                <p class="modal-title tL">\
                  <span>');  ngx.print(T"Error Found"); ngx.print('\
                  </span>\
                </p>\
                <p class="big">\
                  <a href = "#" id ="ipv4-href-error"> <span>');  ngx.print(T"Click here to redirect"); ngx.print('</a>\
                  </span>\
                </p>\
              </div>\
            </div>\
          </div>\
        </div>\
      </div>\
    </body>\
    <script>\
      $(\'#install-error-popup\').modal();\
      $("#ipv4-href-error").click(function(){\
        window.location = "/";\
        $(\'a[data-src="modals/settings/password.lp"]\').click();\
        $(\'a[data-src="modals/settings/lan.lp"]\').click();\
      });\
    </script>\
   ');  end  ngx.print('\
   <html>\
  ');  elseif  postArgs["isIPChanged"] ~= "1" and  not errorFlag and not next(ipv4Errmsg) and dnsSuccess then
      if setFlag then
        proxy.apply()
      end
      ngx.header.content_type = "application/json"
      ngx.print('{ "status":"success" }')
  else
    ngx.header.content_type = "application/json"
    ngx.print('{ "status":"error" }')
  end
  ngx.exit(ngx.HTTP_OK)
end

local leaseListMAC = {}
local staticLeaseList = proxy.get("uci.dhcp.host.")
staticLeaseList = content_helper.convertResultToObject("uci.dhcp.host.", staticLeaseList)

for _, lease in pairs(staticLeaseList) do
   leaseListMAC[lease.mac] = true
  if not connectedMACList[lease.mac] then
    deviceInfo[#deviceInfo + 1] = {}
    deviceInfo[#deviceInfo].name = lease["name"]
    deviceInfo[#deviceInfo].mac = lease["mac"]
    deviceInfo[#deviceInfo].ip = lease["ip"]
  end
end

local friendlyNameList = proxy.get("uci.user_friendly_name.name.")
friendlyNameList = content_helper.convertResultToObject("uci.user_friendly_name.name.", friendlyNameList)
for _, name in pairs(friendlyNameList) do
  if not connectedMACList[name.mac] then
    deviceInfo[#deviceInfo + 1] = {}
    deviceInfo[#deviceInfo].name = name["name"]
    deviceInfo[#deviceInfo].mac = name["mac"]
    deviceInfo[#deviceInfo].ip = ""
  end
end
local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")
  ngx.print('\
\
<script src="js/global-min.js"></script>\
\
 <form id="ipv4Form"  method="post" action="modals/settings/lan.lp">\
 <h1>');  ngx.print(T"IPv4"); ngx.print('</h1>\
<h2>');  ngx.print(T("This page allows to configure IP addresses used in your home network. In case DHCP is used, " .. gatewayName .. " automatically assignes an IP address to devices connected to the network. Using static DHCP it is possible to always assign the same IP address to specific devices.")); ngx.print('</h2>\
<h3>');  ngx.print(T"Network Settings"); ngx.print('</h3>\
  <div class="h3-content vdf-table row-border" id="network-setting">\
    ');  
    local row = {
      label = T("IP Address of " .. gatewayName),
      element = ui_helper.createIPAddressFields("ipv4-txt-ipaddr"),
      colRightId = "allowNumbers"
    }
    ngx.print(ui_helper.createRow(row))
    row = {
      label = T"IP Subnet Mask",
      element = ui_helper.createIPAddressFields("ipv4-txt-subntmsk"),
      colRightId = "allowNumbers"
    }
    ngx.print(ui_helper.createRow(row))
    row = {
      label = T"Host Name",
      element = ui_helper.createTextField({id = "ipv4-txt-hstnme", type = "text"})
    }
    ngx.print(ui_helper.createRow(row))
      ngx.print('\
    <div class="vdf-row" id="ipv4-div-dnsServer">\
        <div class="left">\
            <span>');  ngx.print(T"Local DNS Server"); ngx.print('</span>\
        </div>\
        <div class="right font-sub">\
          ');  dnsServer = splitIP(dnsServer) or {}  ngx.print('\
          <input class="max3 dns" type="number" id="ipv4-txt-dns1" maxlength="3" value="');  ngx.print(dnsServer[1] or ""); ngx.print('"><span>.</span>\
          <input class="max3 dns" type="number" id="ipv4-txt-dns2" maxlength="3" value="');  ngx.print(dnsServer[2] or ""); ngx.print('"><span>.</span>\
          <input class="max3 dns" type="number" id="ipv4-txt-dns3" maxlength="3" value="');  ngx.print(dnsServer[3] or ""); ngx.print('"><span>.</span>\
          <input class="max3 dns" type="number" id="ipv4-txt-dns4" maxlength="3" value="');  ngx.print(dnsServer[4] or ""); ngx.print('">\
        </div>\
    </div>\
    ');  
    row = {
      label = T"DNS Proxy",
      element = ui_helper.createButton({id = "ipv4-btn-dnsProxy", class = dnsProxy and "button button-on" or "button button-off"}),
      rowId = "ipv4-div-dnsProxy"
    }
    ngx.print(ui_helper.createRow(row))
    row = {
      label = T"DHCP Server",
      element = ui_helper.createButton({id = "ipv4-btn-dhcpEnabled", class = (ipv4Content.dhcpv4State == "" or ipv4Content.dhcpv4State == "server") and "button button-on" or "button button-off"})
    }
    ngx.print(ui_helper.createRow(row))
      ngx.print('\
</div>\
\
<!--DHCP Server Parameters -->\
<div id="ipv4-info-dhcpparams" class=');  if ipv4Content.dhcpv4State == "" or ipv4Content.dhcpv4State == "server" then   ngx.print(' show ');  else  ngx.print(' hide ');  end  ngx.print(' >\
<h3 class=" homeFadeOut ">\
<span >');  ngx.print(T"DHCP Server Parameters"); ngx.print('</span></h3>\
<div class="h3-content homeFadeOut vdf-table row-border">\
\
  <div class="vdf-row">\
    <div class="left">\
      <span >');  ngx.print(T"Address Pool Start IP"); ngx.print('</span>\
    </div>\
    <div class="right" id="allowNumbers">\
      <input class="max3 op40" value="" type="number" id="ipv4-txt-ipstart1" maxlength="3" disabled="disabled" ><span>.</span><input class="max3 op40" value="" type="number" id="ipv4-txt-ipstart2" maxlength="3" disabled="disabled" ><span>.</span><input class="max3 op40" value="" type="number" id="ipv4-txt-ipstart3" maxlength="3" disabled="disabled" ><span>.</span><input class="max3" value="" type="number" id="ipv4-txt-ipstart4" maxlength="3">\
    </div>\
  </div>\
  <div class="vdf-row">\
    <div class="left">\
      <span >');  ngx.print(T"Address Pool End IP" ); ngx.print('</span>\
    </div>\
    <div class="right" id="allowNumbers">\
      <input class="max3 op40"  type="number" id="ipv4-txt-ipend1" maxlength="3" disabled="disabled" ><span>.</span><input class="max3 op40"  type="number" id="ipv4-txt-ipend2" maxlength="3" disabled="disabled" ><span>.</span><input class="max3 op40"  type="number" id="ipv4-txt-ipend3" maxlength="3" disabled="disabled" ><span>.</span><input class="max3"  type="number" id="ipv4-txt-ipend4" maxlength="3">\
    </div>\
  </div>\
  ');  
    row = {
      label = T"Lease Time",
      element = format('<div id="top-info-mode">%s</div>', ui_helper.createDropDown({
        id = "ipv4-sel-lease",
        name = "network_type"
      }, leaseTimes, ipv4Content.leaseTime))
    }
    ngx.print(ui_helper.createRow(row))
    row = {
      label = T"Domain Name",
      element = ui_helper.createTextField({id = "ipv4-txt-domain", type = "text", value = ""})
    }
    ngx.print(ui_helper.createRow(row))
    ngx.print('\
</div>\
</div>\
<h3>\
<span >');  ngx.print(T"Static DHCP - Home Network"); ngx.print('</span></h3>\
<div class="h3-content home-network">\
    <table class="desktop" id ="ipv4-tbl-staticdhcp">\
        <thead>\
            <tr>\
                <th>\
                    <span >');  ngx.print(T"Device Name"); ngx.print('</span>\
                </th>\
                <th>\
                    <span >');  ngx.print(T"MAC Address"); ngx.print('</span>\
                </th>\
                <th>\
                    <span >');  ngx.print(T"IP Address"); ngx.print('</span>\
                </th>\
                <th> </th>\
                <th> </th>\
            </tr>\
        </thead>\
        <tbody>\
          ');  for k,l in ipairs(staticLeaseList)do   ngx.print('\
            ');  if not l["name"]:find("^ReservedStatic") then   ngx.print('\
              <tr>\
                  <td><p class="text-overflow" style="width: 285px;">');  ngx.print(l["name"]); ngx.print('</p></td>\
                  <td>');  ngx.print(l["mac"]); ngx.print('</td>\
                  <td>');  ngx.print(l["ip"]); ngx.print('</td>\
                  <td class="tR">\
                     <input class="button button-edit triggering" value="" type="button" data-toggle="modal" data-target="#static-popup-add" data-value="');  ngx.print(l["paramindex"]); ngx.print('" >\
                   </td>\
                   <td>\
                      <input class="button button-delete" value="" type="button" data-value="');  ngx.print(l["paramindex"]); ngx.print('" >\
                   </td>\
              </tr>\
            ');  end   ngx.print('\
          ');  end   ngx.print('\
            <tr class="add-btn-port-triggering-wrapper">\
                <td> </td>\
                <td> </td>\
                <td> </td>\
                <td> </td>\
                <td>\
                    <input class="button button-add" value="" type="button" data-toggle="modal" data-target="#static-popup-add" id="ipv4-btn-add">\
                </td>\
            </tr>\
        </tbody>\
    </table>\
    <div class="mobile-simple-table mobile">\
      <div class="mobile-simple-table mobile" id= "ipv4-tbl-mobilestaticdhcp">\
    ');  for k,l in ipairs(staticLeaseList)do   ngx.print('\
        <div class="mobile-entry mobile-display">\
            <div class="table-mobile-title">\
                <span>');  ngx.print(T"Device Name"); ngx.print('</span>\
            </div>\
            <div class="table-mobile-content mobile-devname">\
                ');  ngx.print(l["name"]); ngx.print('\
            </div>\
            <div class="table-mobile-title">\
                <span>');  ngx.print(T"MAC Address"); ngx.print('</span>\
            </div>\
            <div class="table-mobile-content mobile-devmac">\
                ');  ngx.print(l["mac"]); ngx.print('\
            </div>\
            <div class="table-mobile-title">\
                <span>');  ngx.print(T"IP Address"); ngx.print('</span>\
            </div>\
            <div class="table-mobile-content mobile-devip">\
                ');  ngx.print(l["ip"]); ngx.print('\
            </div>\
            <div class="btn-wrap">\
                <input class="button button-edit"  data-value="');  ngx.print(l["paramindex"]); ngx.print('" value="" type="button" id="ipv4-btn-mobedit">\
                <input class="button button-delete" data-value="');  ngx.print(l["paramindex"]); ngx.print('" value="" type="button" id="ipv4-btn-mobdel">\
            </div>\
        </div>\
    ');  end   ngx.print('\
        <div class="add-entry mob-add">\
            <input class="button button-add" value="" type="button" data-toggle="modal" data-target="#static-popup-add" id="ipv4-btn-mobadd">\
        </div>\
    </div>\
    </div>\
</div>\
</form>\
');  
    lp.include("apply-cancel.lp")
    lp.include("reset-wrap-mobile.lp")
  ngx.print('\
<!--\
<div class="row apply-cancel-hr no-margin-right">\
  <div class="col-md-12 col-sm-12 col-xs-12 no-padding-right">\
    <div class="articlediv hide">\
      <div class="message-arrowbox-applied">\
        <div class="message-arrowbox-applied-right">\
          <p class="success-info" ></p>\
        </div>\
      </div>\
    </div>\
    <input class="button button-apply mob-button-width" value="Apply" type="button" />\
    <input class="button button-cancel mob-button-width mob-apply-cancel" value="Cancel" type="button" />\
  </div>\
</div> -->\
<!-- Modal -->\
<div id="mobile-popup" class="mobile-reset hidden-md hidden-sm hidden-lg">\
    <div class="row padding-bottom-lg">\
      <div class="col-xs-12">\
        <div class="close-icon cancelR"></div>\
      </div>\
    </div>\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-12">\
      <h3>');  ngx.print(T"IPv4"); ngx.print('</h3>\
    </div>\
  </div>\
</div>\
<!-- End -->\
<div class="row">\
  <!-- Modal -->\
  <div class="modal install-update-popup-5" id="install-update-popup-5" role="dialog" data-backdrop = "static">\
    <div class="modal-dialog">\
      <!-- Modal content-->\
      <div class="modal-content">\
        <div class="modal-body">\
          <img src="img/look_4/icons/icon-thinking.gif" alt="Loading..." />\
          <p class="modal-title tL">\
            <span>');  ngx.print(T"Gateway IPAddress Changed"); ngx.print('\
            </span>\
          </p>\
          <p class="big">\
            <span>');  ngx.print(T"Your EasyBox is now restarting. Please do not turn it off or press any buttons until it has restarted."); ngx.print('\
            </span>\
          </p>\
        </div>\
      </div>\
    </div>\
  </div>\
</div>\
\
<div class="modal fade" id="static-popup-add" role="dialog" data-backdrop="static" data-value="new">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
    <div class="modal-header hidden-sm hidden-md hidden-lg">\
        <div class="mobile-cancel-popup button-cancel" id="ipv4-btn-mobileclose"></div>\
      </div>\
      <div class="modal-body no-padding">\
        <form class="form-horizontal">\
          <div class="form-group">\
            <div class="col-sm-12">\
              <p class="title tL" id="ipv4-lbl-tittle">');  ngx.print(T"Add Static DHCP - Home Network"); ngx.print('</p>\
            </div>\
          </div>\
          <div class="vdf-table">\
          <div class="vdf-row">\
            <div class="left">\
              <label for="inputPassword" class="control-label">');  ngx.print(T"Device Name"); ngx.print('</label>\
            </div>\
                  <div class="lan-col text-left">\
                <div id="top-info-mode" class="rel">\
                    <select id="ipv4-sel-popupcondev" class="select-class-add">\
                      ');  for i,v in ipairs (deviceInfo) do   ngx.print('\
                       <option value=\'');  ngx.print(v["mac"]); ngx.print('\'>');  ngx.print(v["name"]); ngx.print('</option>\
                      ');  end  ngx.print('\
                     <option value = "0" selected >');  ngx.print(T"No specific device"); ngx.print('</option>\
                    </select>\
                  </div>\
          </div>\
          </div>\
          ');  
            row = {
              label = T"Device Name",
              element = ui_helper.createTextField({id = "ipv4-txt-popupdevname", type = "text"}),
              rowClass = "vdf-row no-device add-device-name",
              rowId = "new-device"
            }
            ngx.print(ui_helper.createRow(row))
            row = {
              colRightClass = "right halfWidth no-important popup-macaddress",
              colRightId = "unknownIPedit",
              label = format('<label for="inputPassword2" class="control-label">%s</label>', T"MAC Address"),
              element = ui_helper.createMACAddressFields("ipv4-txt-popupmac", "ip lan-max2 alphanum")
            }
            ngx.print(ui_helper.createRow(row))
            row = {
              label = format('<label for="inputPassword2" class="control-label">%s</label>', T"IP Address"),
              element = ui_helper.createIPAddressFields("ipv4-txt-popupip", "ip lan-max2 max3"),
              colRightClass = "right halfWidth no-important text-left popup-ipaddress",
              colRightId = "unknownIPedit"
            }
            ngx.print(ui_helper.createRow(row))
            ngx.print('\
\
          </div>\
          <div class="message message-info message-error not-similiar" id="portmap-err-add" style="display:none">Please check the inputs entered.</div>\
          <div class="form-group">\
            <div class="col-sm-12">\
              <div class="modal-footer">\
                <input class="button button-apply save mob-button-width" id="ipv4-btn-addsave" value="Add" data-dismiss="modal" type="button" autocomplete="off">\
                <input class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" data-dismiss="modal" value="Cancel" type="button" id="ipv4-btn-addcancel" autocomplete="off">\
              </div>\
            </div>\
          </div>\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
<form id = "lanreboot" method="post" action="modals/settings/lan.lp">\
</form>\
<script>\
    var deviceInfo = ');  ngx.print(json.encode(deviceInfo)); ngx.print(' || {}\
    var ipv4Content_IPAddress = "');  ngx.print(ipv4Content["IPAddress"]); ngx.print('"\
    var ipv4Content_hostName = "');  ngx.print(ipv4Content["hostName"]); ngx.print('"\
    var startIPAddress = "');  ngx.print(startIPAddress); ngx.print('"\
    var endIPAddress = "');  ngx.print(endIPAddress); ngx.print('"\
    var ipv4Content_domainName = "');  ngx.print(ipv4Content["domainName"]); ngx.print('"\
    var ipv4Content_localdevmask = "');  ngx.print(ipv4Content["localdevmask"]); ngx.print('"\
    var resetLan = ');  ngx.print(json.encode(resetlan)); ngx.print('\
    var T = {\
      "Device Name" : "');  ngx.print(T"Device Name"); ngx.print('",\
      "MAC Address" : "');  ngx.print(T"MAC Address"); ngx.print('",\
      "IP Address" : "');  ngx.print(T"IP Address"); ngx.print('"\
    }\
</script>\
<script src="js/settings/lan.js"></script>\
'); 