--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")
local vdf_helper = require("vodafone_helper")
local ui_helper = require("vdf_ui_helper")
local string = string
local format, match, untaint, gsub = string.format, string.match, string.untaint, string.gsub
local table, setmetatable = table, setmetatable
local pairs, ipairs, sort, next, concat = pairs, ipairs, table.sort, next, table.concat
local tonumber = tonumber
local untaint_mt = require("web.taint").untaint_mt
local setMetaTable = setmetatable
local json = require("dkjson")
local subnetError
local getNATpath, HelperPath
local validateQTN = post_helper.validateQTN
local reservedIP = post_helper.reservedIPValidation
local uniqueKey = post_helper.getRandomKey()

local vodafone = {
    variant = "uci.env.var.vodafone_variant",
}
content_helper.getExactContent(vodafone)

if vodafone.variant ~= "VF-UK" then
  getNATpath = content_helper.getMatchedContent("uci.firewall.cone.", {name = "NAT traversal"})
  HelperPath = content_helper.convertResultToObject("uci.firewall.helper.", proxy.get("uci.firewall.helper."))
end

local network_details = {
  gateway_ip = "uci.network.interface.@lan.ipaddr",
  netmask    = "uci.network.interface.@lan.netmask",
}
if vodafone.variant == "VF-UK" then
  network_details.cwmpPort   = "uci.cwmpd.cwmpd_config.connectionrequest_port"
end

content_helper.getExactContent(network_details)

-- Function to compare tables based on their index
local function compareIndexInTable(a, b)
  return a.index < b.index
end

-- Function to compare tables based on their Name
local function compareNameInTable(a, b)
  return a.Name < b.Name
end

local ALGData = {}
local MultiHelperTable = {}

if HelperPath then
  local ALGListTable = setMetaTable({
    pptp   = "PPTP",
    snmp   = "SNMP",
    rtsp   = "RTSP",
    irc    = "IRC",
    tftp   = "TFTP",
    ftp    = "FTP",
    amanda = "AMANDA",
    sip    = "SIP",
    l2tp   = "L2TP",
    ipsec  = "IPSEC",
    h323   = "H323",
    RAS    = "RAS",
    ["Q.931"] = "Q.931",
  }, untaint_mt)
  local HelperNameTable = {}
  for _, v in ipairs(HelperPath) do

    if ALGListTable[v.helper] then
      --Check for helpers of same name
      if not HelperNameTable[ALGListTable[v.helper] .. "name"] and v.intf ~= "loopback" then
        HelperNameTable[ALGListTable[v.helper] .. "name"] = true
        ALGData[#ALGData+1] = {}
        ALGData[#ALGData].Name = ALGListTable[v.helper]:gsub("(%.)","")
        ALGData[#ALGData].display = ALGListTable[v.helper]
        ALGData[#ALGData].enable = v.enable
        ALGData[#ALGData].index = v.paramindex
      else
        MultiHelperTable[ALGListTable[v.helper] .. "name"] = true -- This flag is later used as a check to enable/disable corresponding helpers of same name
        MultiHelperTable[ALGListTable[v.helper] .. "index"] = v.paramindex
      end
    end
  end

  -- We cannot guarantee transformer to return ALGData table in the same order every time
  -- So, sorting this table by param index to display in same order every time in GUI
  if vodafone.variant == "NZ" then
    sort(ALGData, compareNameInTable)
  else
    sort(ALGData, compareIndexInTable)
  end
end

local protocolList = {
  { "tcp", "TCP"},
  { "udp", "UDP"},
  { "tcpudp", "TCP/UDP"}
}

local reservedPorts = {}
-- Retrieve all wan-services sections in system config
local servicesTable = proxy.get("uci.system.wan-service.") or {}
for i = 1, #servicesTable, 2 do
  local portVal = servicesTable[i].value
  for port in string.gmatch(portVal, "%d+") do
    reservedPorts[#reservedPorts +1] = {
      port = port,
      proto = servicesTable[i+1].value
    }
  end
end

if vodafone.variant == "VF-UK" then
  for port in string.gmatch(network_details.cwmpPort, "%d+") do
    reservedPorts[#reservedPorts +1] = {
      port = port,
      proto = "tcpudp",
    }
  end
end

local function validateReservedPort(port, protocol)
  local portStart, portEnd = match(port, "^(%d+):(%d+)$")
  if not portStart then
    portStart, portEnd = port, port
  end
  portStart = tonumber(portStart)
  portEnd = tonumber(portEnd)
  for _, reservedPort in ipairs(reservedPorts) do
    reservedPort.port = tonumber(reservedPort.port)
    if reservedPort.proto == protocol or protocol == "tcpudp" or reservedPort.proto == "tcpudp" then
      if reservedPort.port >= portStart and reservedPort.port <= portEnd then
        return nil
      end
    end
  end
  return true
end

local validateIP = post_helper.getOrValidation(post_helper.getValidateStringIsDeviceIPv4(network_details.gateway_ip, network_details.netmask), post_helper.getValidateInEnumSelect({{T"Offline"}}))
local validateProtocol = post_helper.getValidateInEnumSelect(protocolList)
local validatePort = post_helper.validateStringIsPortRange
local validateBoolean = post_helper.validateBoolean

-- Function to validate Service name
-- Only allow name between 1 and 63 characters having alphanumerics/dash
-- @param #string - Service name of a rule
-- @return #boolean  - true if service is valid, nil if not
local function validateService(service)
  if #service > 0 and #service < 64 and not match(service, "[^%w%-%s]") then
    return true
  end
end

-- Function to get and validate the Port Range values(Public and Lan port range) provided from GUI
-- Checks if port values are given in range.If in range format, check if public port range and lan port range are same
-- @param #table - table containing all the necessary portmap details of a rule
-- @return #boolean, portvalues - true if both public port range and lan port range is equal and also returns all the port values
local function validateAndGetPortRange(ports)
  local validRange = true
  local wanPortStart, wanPortEnd = match(ports.wan_port, "^(%d+):(%d+)$")
  local LanPortStart, LanPortEnd = match(ports.lan_port, "^(%d+):(%d+)$")

  -- If not in Port range format, both start and end port are assigned same values
  if not wanPortStart then
    wanPortStart, wanPortEnd = ports.wan_port, ports.wan_port
    LanPortStart, LanPortEnd = ports.lan_port, ports.lan_port

    -- Check if Public port range values are equal to Lan port range values
  elseif wanPortStart ~= LanPortStart or wanPortEnd ~= LanPortEnd then
    validRange = false
  end
  return validRange, tonumber(wanPortStart), tonumber(wanPortEnd), tonumber(LanPortStart), tonumber(LanPortEnd)
end

--UPNP Rules
local upnp_list = "sys.upnp.redirect."
local upnp_params = content_helper.convertResultToObject(upnp_list, proxy.get(upnp_list))

-- Checks Static Ports conflicting with UPNP Ports
-- @param #table - table containing all the necessary portmap details of a rule
-- @return #boolean  - true if no conflict, nil if not
local function validatePortUpnp(ports)
  for _, l in ipairs(upnp_params) do
    if ports.protocol == string.lower(l.proto) or ports.protocol == "tcpudp" or string.lower(l.proto) == "tcpudp" then    -- duplicate protocols, so check further
      local _, wanPortStart, wanPortEnd, lanPortStart, lanPortEnd = validateAndGetPortRange(ports)
      if (l.dest_ip == ports.dest_ip and tonumber(l.dest_port) >= lanPortStart and tonumber(l.dest_port) <= lanPortEnd) or    -- duplicate/overlapping lan ports for same device
        (tonumber(l.src_dport) >= wanPortStart and tonumber(l.src_dport) <= wanPortEnd) then    -- duplicate/overlapping wan ports
        return nil
      end
    end
  end
  return true
end

-- Checks Static Ports conflicts
-- @param #table - table containing all the necessary portmap details of a rule
-- @return #boolean  - true if no conflict, nil if not
local function validateStaticPorts(port1, port2)
  if string.lower(port1.proto) == string.lower(port2.proto) or string.lower(port1.proto) == "tcpudp" or string.lower(port2.proto) == "tcpudp" then     -- duplicate protocols, so check further
    local _, wanPortStart1, wanPortEnd1, LanPortStart1, LanPortEnd1 = validateAndGetPortRange(port1)
    local _, wanPortStart2, wanPortEnd2, LanPortStart2, LanPortEnd2 = validateAndGetPortRange(port2)
    if (port1.ip == port2.ip and LanPortStart1 <= LanPortEnd2 and LanPortEnd1 >= LanPortStart2) or  -- duplicate/overlapping lan ports for same device
      (wanPortStart1 <= wanPortEnd2 and wanPortEnd1 >= wanPortStart2) then  -- duplicate/overlapping wan ports
    return nil
    end
  end
  return true
end

-- Function to check the validatePort, validateReservedPort & validatePortUpnp.
-- @param, key may be lan_port or wan_port.
-- @return #boolean - true if success, nil if not
local function validatePortValues(value, object, key)
  local success, errmsg =  validatePort(value, object, key)
  if not success then
    return nil, errmsg
  end
  success, errmsg = validateReservedPort(value, object["protocol"])
  if not success then
    return nil, errmsg
  end
  success, errmsg = validatePortUpnp(object)
  if not success then
    return nil, errmsg
  end
  return true
end

-- Function to validate all the Portmap values coming from GUI
-- Also, it will validate duplicate and overlapping wan and lan ports
-- @function validatePortMapDetails
-- @param #table map - All portMap details coming from each rows in GUI
-- @return #boolean  - true if everything is valid, nil if anything fails
local function validatePortMapDetails(ports)
  for i = 1, #ports do
    if ports[i].index and not match(ports[i].index, "del.+") then
      local portMapData = {
        dest_ip   = ports[i].ip,
        name      = ports[i].service,
        protocol  = ports[i].proto,
        wan_port  = ports[i].wan_port,
        lan_port  = ports[i].lan_port,
      }
      local portMapValidations = {
        dest_ip   = post_helper.getAndValidation(post_helper.getAndValidation(validateQTN, reservedIP), validateIP),
        name      = validateService,
        protocol  = validateProtocol,
        wan_port  = validatePortValues,
        lan_port  = validatePortValues,
      }
      local valid, errormsg = content_helper.validateObject(portMapData, portMapValidations)
      if not valid then
        return nil
      end
      --Check if the static port map rules conflict
      for j = i+1, #ports do
        if not match(ports[j].index, "del.+") then
          valid = validateStaticPorts(ports[i], ports[j])
          if not valid then
            return nil
          end
        end
      end
    end
  end
  return true
end

-- Function to validate ALG helper status
-- @param #Table - Contains status of each ALG helper
-- @return #boolean  - true if status is valid, nil if not
local function validateALG(ALGdata)
  for i = 1, #ALGdata do
    if not validateBoolean(tonumber(ALGdata[i].status)) then
      return nil
    end
  end
  return true
end

local devicesList = proxy.get("rpc.hosts.host.")
devicesList = content_helper.convertResultToObject("rpc.hosts.host.", devicesList)
local devices = {}
local hostNameCount = {}
local deviceDropdownOptions =  {}

local function guestCheck(ipv4Address, friendlyName, macAddress)
  devices[ipv4Address] = { name = friendlyName, mac = macAddress }
  hostNameCount[friendlyName] = (hostNameCount[friendlyName] or 0) + 1
end

for i, v in ipairs(devicesList) do
  local ipv4Address = match(v.IPAddress, "%d+.%d+.%d+.%d+")
  if vodafone.variant == "VF-UK" then
    if ipv4Address and v.L3Interface ~= "br-guest" then
      guestCheck(ipv4Address, v.FriendlyName, v.MACAddress)
    end
  else
    if ipv4Address then
      guestCheck(ipv4Address, v.FriendlyName, v.MACAddress)
    end
  end
end

for k, v in pairs(devices) do
  if hostNameCount[v.name] > 1 then
    devices[k].name = format("%s (%s)", v.name, v.mac)
  end
  deviceDropdownOptions[#deviceDropdownOptions+1] = {k, devices[k].name}
end
local resetportmapping = {
  reset_ftp = "uci.uci-defaults.portmapping.ftp",
  reset_pptp = "uci.uci-defaults.portmapping.pptp",
  reset_snmp = "uci.uci-defaults.portmapping.snmp",
  reset_irc = "uci.uci-defaults.portmapping.irc",
  reset_rtsp = "uci.uci-defaults.portmapping.rtsp",
  reset_sip = "uci.uci-defaults.portmapping.sip",
  reset_amanda = "uci.uci-defaults.portmapping.amanda",
  reset_tftp = "uci.uci-defaults.portmapping.tftp",
  reset_nat_traversal = "uci.uci-defaults.portmapping.nat_traversal",
  reset_l2tp = "uci.uci-defaults.portmapping.l2tp",
  reset_ipsec = "uci.uci-defaults.portmapping.ipsec",
  reset_h323 = "uci.uci-defaults.portmapping.h323",
  reset_q931 = "uci.uci-defaults.portmapping.q931",
  reset_ras = "uci.uci-defaults.portmapping.ras"
}
content_helper.getExactContent(resetportmapping)

if ngx.req.get_method() == "POST" and ngx.var.content_type and match(ngx.var.content_type, "application/x%-www%-form%-urlencoded") then
  local postargs = ngx.req.get_post_args()
  local portmapTable = json.decode(untaint(postargs.portmapTable))
  local deletedIndices = {}
  local rows = tonumber(postargs.rows)
  local validData
  local NATStatus, ALGTable
  if vodafone.variant == "VF-UK" then
    validData = validatePortMapDetails(portmapTable)
  else
    ALGTable = json.decode(untaint(postargs.ALGTable))
    NATStatus = postargs.NATStatus
    validData = validatePortMapDetails(portmapTable) and validateALG(ALGTable)
  end

  if validData then
    if vodafone.variant ~= "VF-UK" then
      if NATStatus == "true" and not next(getNATpath) then
        local paramMapForNAT = {
          dest_port = "dest_port",
          src       = "src",
          name      = "name",
        }
        local NATdetails = {
          dest_port = "4500",
          src       = "wan",
          name      = "NAT traversal",
        }
        content_helper.addNewObject("uci.firewall.cone.@.", NATdetails, paramMapForNAT, nil, uniqueKey)
      elseif NATStatus == "false" and next(getNATpath) then
        proxy.del(getNATpath[1].path)
      end
      local paramMapForALG = {
        enable   = "enable",
      }
      for i = 1, #ALGTable do
        local ALGStatusTable = {
          enable = ALGTable[i].status,
        }
        validData = content_helper.setObject(ALGStatusTable, paramMapForALG, "uci.firewall.helper." .. ALGTable[i].index .. ".")
        if validData and MultiHelperTable[ALGTable[i].name .. "name"] then
          proxy.set({["uci.firewall.helper." .. MultiHelperTable[ALGTable[i].name .. "index"] .. ".enable"] = ALGTable[i].status})
        end
        if not validData then
          break
        end
      end
    end
   -- End of if for variant VF-UK
    local paramMap = {
      enabled   = "enabled",
      src_dport = "src_dport",
      dest_ip   = "dest_ip",
      dest_port = "dest_port",
      src       = "src",
      name      = "name",
      dest      = "dest",
      target    = "target",
      family    = "family",
      proto     = "proto.@1.value",
    }
    for i = 1, rows do
      portmapTable[i].index = portmapTable[i].index or ""

      -- If index contains del followed by number, Delete the entry having that index
      local index = match(portmapTable[i].index, "del(%d+)")
      if index then
        proxy.del("rpc.network.firewall.portforward." .. index .. ".")
        deletedIndices[#deletedIndices+1] = tonumber(index)
      end

      -- If index is new, Add an entry with the values coming from GUI
      if portmapTable[i].index == "new" then
        local portMapData = {
          dest_ip   = portmapTable[i].ip,
          name      = portmapTable[i].service,
          enabled   = "1",
          src_dport = portmapTable[i].wan_port,
          dest_port = portmapTable[i].lan_port,
          src       = "wan",
          dest      = "lan",
          target    = "DNAT",
          family    = "ipv4",
          proto     = portmapTable[i].proto,
        }
        content_helper.addNewObject("rpc.network.firewall.portforward.", portMapData, paramMap)
      end

      -- If index is a number, then the enrty having this index needs to be updated
      if string.find(portmapTable[i].index, "^%d+$") then
        local portmapDetails = {
          src_dport = portmapTable[i].wan_port,
          dest_ip   = portmapTable[i].ip,
          dest_port = portmapTable[i].lan_port,
          name      = portmapTable[i].service,
          proto     = portmapTable[i].proto,
        }
        validData = content_helper.setObject(portmapDetails, paramMap, "rpc.network.firewall.portforward." .. portmapTable[i].index .. ".")
        if not validData then
          break
        end
      end
    end
  end

  ngx.header.content_type = "application/json"
  if not validData then
    ngx.print('{ "status":"error" }')
  else
    proxy.apply()
    ngx.print('{ "status":"success" }')
  end
  ngx.exit(ngx.HTTP_OK)
end

local portmaps = {}
local portmapPath = "rpc.network.firewall.portforward."
local portmapsList = content_helper.convertResultToObject(portmapPath, proxy.get(portmapPath))

for _, v in pairs(portmapsList) do
  if v.enabled == "1" then
    portmaps[#portmaps + 1] = {}
    portmaps[#portmaps].index    = v.paramindex
    portmaps[#portmaps].service  = v.name
    portmaps[#portmaps].ip       = v.dest_ip == "unknown" and T"Offline" or v.dest_ip
    -- protocol is a seperate list which cannot be get correctly from convertResultToObject. So get it seperately.
    local protocolPath           = format("rpc.network.firewall.portforward.%s.proto.@1.value", v.paramindex)
    local protocol               = proxy.get(protocolPath) or {}
    protocol                     = protocol[1] and protocol[1].value or "tcpudp"
    portmaps[#portmaps].proto    = protocol == "tcpudp" and "TCP/UDP" or string.upper(protocol)
    portmaps[#portmaps].lan_port = gsub(v.dest_port, ":", "-")
    portmaps[#portmaps].wan_port = gsub(v.src_dport, ":", "-")
  end
end

-- We cannot guarantee transformer to return portmaps table in the same order every time
-- So, sorting this table by param index to display in same order every time in GUI
sort(portmaps, compareIndexInTable)

local portmapsupnp = {}
local portmapPathUpnp = "sys.upnp.redirect."
local portmapsListUpnp = content_helper.convertResultToObject(portmapPathUpnp, proxy.get(portmapPathUpnp))
for _, vu in pairs(portmapsListUpnp) do
    portmapsupnp[#portmapsupnp + 1] = {}
    portmapsupnp[#portmapsupnp].service  = "upnp"
    portmapsupnp[#portmapsupnp].ip       = vu.dest_ip == "unknown" and T"Offline" or vu.dest_ip
    portmapsupnp[#portmapsupnp].proto    = protocol == "tcpudp" and "TCP/UDP" or string.upper(vu.proto)
    portmapsupnp[#portmapsupnp].lan_port = gsub(vu.dest_port, ":", "-")
    portmapsupnp[#portmapsupnp].wan_port = gsub(vu.src_dport, ":", "-")
end

local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")
  ngx.print('\
<h1>');  ngx.print(T"Port Mapping"); ngx.print('</h1>\
<h2>');  ngx.print(T"Port mapping allows remote computers to connect to a specific device within your private network."); ngx.print('</h2>\
<h3>');  ngx.print(T"Port Mapping"); ngx.print('</h3>\
<div class="h3-content portmap-div-mainTable">\
    <table class="table-four-columns desktop hidden-xs" id="portmap-tbl-desktop" style="width:100%">\
        <thead>\
            <tr>\
                <th class="ipv6-font-size"><span style="font-weight: normal;font-size: 13px;">');  ngx.print(T"Service"); ngx.print('</span></th>\
                <th class="ipv6-font-size"><span style="font-weight: normal;font-size: 13px;">');  ngx.print(T"Local IP Address"); ngx.print('</span></th>\
                <th class="ipv6-font-size"><span style="font-weight: normal;font-size: 13px;">');  ngx.print(T"Protocol"); ngx.print('</span></th>\
                <th class="ipv6-font-size"><span style="font-weight: normal;font-size: 13px;">');  ngx.print(T"LAN Port"); ngx.print('</span></th>\
                <th class="ipv6-font-size"><span style="font-weight: normal;font-size: 13px;">');  ngx.print(T"Public Port"); ngx.print('</span></th>\
                <th>&nbsp;</th>\
                <th>&nbsp;</th>\
            </tr>\
        </thead>\
        <tbody>\
            <tr class="noRulesSet" ');  if #portmaps ~= 0 then  ngx.print(' style="display:none" ');  end  ngx.print('>\
                <td class="noEntryTD tC italic" colspan="7" style="text-align:center;font-weight: normal;">\
                    <span style="font-weight: normal;font-size: 16px;font-style: italic;text-align: center !important;line-height: 30px;">');  ngx.print(T"No port mapping defined"); ngx.print('</span>\
                </td>\
            </tr>\
            ');  for i = 1, #portmaps do
              local portMapData = {
                dest_ip = portmaps[i].ip
              }
              local portMapValid = {
                dest_ip = validateIP
              }
              local valid = content_helper.validateObject(portMapData, portMapValid)  ngx.print('\
              <tr class="portmap-rule ');  if not valid then subnetError=true  ngx.print(' error ');  end  ngx.print('">\
                  <input type="hidden" value="');  ngx.print(portmaps[i].index); ngx.print('">\
                  <td class="ipv6-font-size service">');  ngx.print(portmaps[i].service); ngx.print('</td>\
                  <td class="ipv6-font-size ip">');  ngx.print(portmaps[i].ip); ngx.print('</td>\
                  <td class="ipv6-font-size proto">');  ngx.print(portmaps[i].proto); ngx.print('</td>\
                  <td class="ipv6-font-size lan_port">');  ngx.print(portmaps[i].lan_port); ngx.print('</td>\
                  <td class="ipv6-font-size wan_port">');  ngx.print(portmaps[i].wan_port); ngx.print('</td>\
                  <td><input class="button button-edit mapping" type="button" id="portmap-btn-edit');  ngx.print(i); ngx.print('" onclick="copyData(this)" data-toggle="modal" data-target="#portmap-popup-edit" /></td>\
                  <td><input class="button button-delete" type="button" id="portmap-btn-delete');  ngx.print(i); ngx.print('" /></td>\
              </tr>\
            ');  end  ngx.print('\
            <tr class="add-btn-port-mapping-wrapper" id="portmap-row-last">\
                <td>&nbsp;</td>\
                <td>&nbsp;</td>\
                <td>&nbsp;</td>\
                <td>&nbsp;</td>\
                <td>&nbsp;</td>\
                <td>&nbsp;</td>\
                <td>\
                    <input id="portmap-btn-add" class="button button-add" type="button" data-toggle="modal" data-target="#portmap-popup-add" />\
                </td>\
            </tr>\
        </tbody>\
    </table>\
</div>\
\
');  if subnetError then  ngx.print('\
<div class="h3-content no-padding-bottom">\
  <div class="message message-error">\
    <span id="portmapping-footerlan-info" class="font-normal">');  ngx.print(T"This port mapping rule is invalid due to a change to the LAN subnet."); ngx.print('</span>\
  </div>\
</div>\
');  end  ngx.print('\
<!-- Mobile View MMMM -->\
<div class="mobile port-table" id="portmap-tbl-mobile">\
  ');  for i = 1, #portmaps do  ngx.print('\
  <div class="mobile-entry portmap-rule portmap-mobile-row">\
    <div class="table-mobile-title">\
      <span>');  ngx.print(T"Service"); ngx.print('</span>\
    </div>\
    <div class="table-mobile-content service">');  ngx.print(portmaps[i].service); ngx.print('</div>\
    <div class="table-mobile-title">\
      <span>');  ngx.print(T"Local IP Address"); ngx.print('</span>\
    </div>\
    <div class="table-mobile-content ip">');  ngx.print(portmaps[i].ip); ngx.print('</div>\
    <div class="table-mobile-title">\
      <span>');  ngx.print(T"Protocol"); ngx.print('</span>\
    </div>\
    <div class="table-mobile-content proto">');  ngx.print(portmaps[i].proto); ngx.print('</div>\
    <div class="table-mobile-title">\
      <span>');  ngx.print(T"LAN Port"); ngx.print('</span>\
    </div>\
    <div class="table-mobile-content lan_port">');  ngx.print(portmaps[i].lan_port); ngx.print('</div>\
    <div class="table-mobile-title">\
      <span>');  ngx.print(T"Public Port"); ngx.print('</span>\
    </div>\
    <div class="table-mobile-content wan_port">');  ngx.print(portmaps[i].wan_port); ngx.print('</div>\
    <div class="btn-wrap">\
      <input class="button button-edit mapping" type="button">\
      <input class="button button-delete" type="button">\
    </div>\
  </div>\
  ');  end  ngx.print('\
  <div class="add-entry" id="mobileAddBtn">\
    <input id="portmap-btn-mobileAdd" class="button button-add" type="button">\
  </div>\
</div>\
\
<h3>');  ngx.print(T"UPnP Port Mapping"); ngx.print('</h3>\
<div class="h3-content portmap-div-mainTable">\
    <table class="table-four-columns desktop hidden-xs" id="upnpportmap-tbl-desktop">\
        <thead>\
            <tr>\
                <th class="ipv6-font-size"><span>');  ngx.print(T"Service"); ngx.print('</span></th>\
                <th class="ipv6-font-size"><span>');  ngx.print(T"Local IP Address"); ngx.print('</span></th>\
                <th class="ipv6-font-size"><span>');  ngx.print(T"Protocol"); ngx.print('</span></th>\
                <th class="ipv6-font-size"><span>');  ngx.print(T"LAN Port"); ngx.print('</span></th>\
                <th class="ipv6-font-size"><span>');  ngx.print(T"Public Port"); ngx.print('</span></th>\
                <th>&nbsp;</th>\
                <th>&nbsp;</th>\
            </tr>\
        </thead>\
        <tbody>\
            <tr class="noUpnpRulesSet" ');  if #portmapsupnp ~= 0 then  ngx.print(' style="display:none" ');  end  ngx.print('>\
                <td class="noEntryTD tC italic" colspan="6">\
                    <span>');  ngx.print(T"No port mapping defined"); ngx.print('</span>\
                </td>\
            </tr>\
            ');  for i = 1, #portmapsupnp do
              local portMapDataUpnp = {
                dest_ip = portmapsupnp[i].ip
              }
              local portMapUpnpValid = {
                dest_ip = validateIP
              }
              local valid = content_helper.validateObject(portMapDataUpnp, portMapUpnpValid)  ngx.print('\
              <tr class="portmap-rule ');  if not valid then subnetError=true  ngx.print(' error ');  end  ngx.print('">\
                  <input type="hidden" value="');  ngx.print(portmapsupnp[i].index); ngx.print('">\
                  <td class="ipv6-font-size service">');  ngx.print(portmapsupnp[i].service); ngx.print('</td>\
                  <td class="ipv6-font-size ip">');  ngx.print(portmapsupnp[i].ip); ngx.print('</td>\
                  <td class="ipv6-font-size proto">');  ngx.print(portmapsupnp[i].proto); ngx.print('</td>\
                  <td class="ipv6-font-size lan_port">');  ngx.print(portmapsupnp[i].lan_port); ngx.print('</td>\
                  <td class="ipv6-font-size wan_port">');  ngx.print(portmapsupnp[i].wan_port); ngx.print('</td>\
              </tr>\
            ');  end  ngx.print('\
        </tbody>\
    </table>\
</div>\
\
');  if vodafone.variant ~= "VF-UK" then   ngx.print('\
  <h3>');  ngx.print(T"ALGs"); ngx.print('</h3>\
  ');  
    local rows = {}
    for _, v in ipairs(ALGData) do
      local algElements = {
        ui_helper.createButton({id = "portmapping-btn-alg_"..v.Name, class = (v.enable == "1" or v.enable == "") and "button button-on pull-right toggle-content-button button-alg" or "button button-off pull-right toggle-content-button button-alg"}),
        ui_helper.createHiddenField(nil, nil, v.Name, "name"),
        ui_helper.createHiddenField(nil, nil, v.enable, "status"),
        ui_helper.createHiddenField(nil, nil, v.index, "index")
      }
      rows[#rows+1] = {
        label = v.display,
        element = format("%s", table.concat(algElements, "\n")),
        colLeftClass = "left light-font",
        colRightClass = "right alghelp"
      }
    end
    ngx.print(ui_helper.createTable(rows, "portmp-algs", "h3-content vdf-table"))

    local row = {
      label = T"NAT Traversal",
      element = ui_helper.createButton({id = "portmapping-btn-nat", class = next(getNATpath) and "button button-on toggle-content-button pull-right" or "button button-off toggle-content-button pull-right"}),
      colLeftClass = "left light-font"
    }
    ngx.print(ui_helper.createTable(row, "NATSection", "h3-content vdf-table"))
  end
  ngx.print('\
<!-- End of if variant ~= VF-UK -->\
\
');  
  lp.include("apply-cancel.lp")
  lp.include("reset-wrap-mobile.lp")
  ngx.print('\
\
<!-- Edit Port Mapping Modal  -->\
<div class="modal fade" id="portmap-popup-edit" role="dialog" data-backdrop="static">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
      <div class="modal-header hidden-sm hidden-md hidden-lg">\
        <div class="mobile-cancel-popup button-cancel"></div>\
      </div>\
      <div class="modal-body no-padding">\
        <form class="form-horizontal">\
          <div class="form-group">\
            <div class="col-sm-12">\
              <p class="title tL">\
                ');  ngx.print(T"Edit Port Mapping"); ngx.print('\
              </p>\
            </div>\
          </div>\
          <div class="vdf-table">\
            ');  
              local rows = {
                {
                  label = T"Service",
                  element = ui_helper.createTextField({id = "portmap-txt-editService", maxlength = "63", type = "text", class = "port-input"}),
                },
                {
                  label = T"Protocol",
                  element = ui_helper.createDropDown({id = "portmap-sel-editProtocol", style = "font-weight:bold;"}, protocolList),
                  colRightId = "top-info-mode",
                  colRightClass = "right rel"
                },
                {
                  label = T"Device",
                  element = ui_helper.createDropDown({id = "portmap-sel-editDevices"}, deviceDropdownOptions, "", {{"noDevice", T"No specific device"}}),
                  colRightId = "top-info-mode",
                  colRightClass = "right rel"
                },
                {
                  label = T"LAN IP",
                  element = ui_helper.createIPAddressFields("portmap-txt-editIP", "editIP"),
                  colRightClass = "right halfWidth no-important"
                }
              }
              for i, v in ipairs(rows) do
                ngx.print(ui_helper.createRow(v))
              end
              ngx.print('\
            <div class="vdf-row">\
              <div class="left">\
                <label for="portSingle" class="control-label">');  ngx.print(T"Port Type"); ngx.print('</label>\
              </div>\
              <div class="right" style="width:50%;">\
                <span class="fL">\
                  ');  
                    ngx.print(ui_helper.createRadioButton({
                      class = "radio radio-checked",
                      name = "edit-port-radio",
                      checked = "checked",
                      id = "portmap-rad-editPortS",
                      type = "radio",
                      value = "1"
                    },"portmap-rad-editPortS",
                    {
                      style="margin-right: 10px;"
                    },T"Port"))
                    ngx.print('\
                </span>\
                <span style="display:inline-block;width:50%;">\
                  <input name="edit-port-radio" value="2" class="radio radio-checked" id="portmap-rad-editPortR" type="radio" />\
                  <label for="portmap-rad-editPortR" style="margin-right: 10px;"></label>\
                  <span>');  ngx.print(T"Port range"); ngx.print('</span>\
                </span>\
              </div>\
            </div>\
            <div class="vdf-row">\
              <div class="left">\
                <label for="inputPassword2" class="control-label" id="portmap-lbl-editPort1">');  ngx.print(T"Public Port"); ngx.print('</label>\
              </div>\
              <div class="right halfWidth no-important" id="portmap-div-editWanPort" style="text-align:right;">\
                <input id="portmap-txt-editWanPort" class="num-only max5" maxlength="5" type="text" />\
              </div>\
              <div class="right halfWidth no-important" id="portmap-div-editWanPortRange" style="text-align:right;display:none">\
                <input id="portmap-txt-editWanPort1" style="width: 75px;" class="num-only max5-range wanrange" maxlength="5" type="text" /> <span>-</span>\
                <input id="portmap-txt-editWanPort2" style="width: 75px;" class="num-only max5-range wanrange" maxlength="5" type="text" />\
              </div>\
            </div>\
            <div class="vdf-row">\
              <div class="left">\
                <label for="inputPassword2" class="control-label" id="portmap-lbl-editPort2">');  ngx.print(T"Local Port"); ngx.print('</label>\
              </div>\
              <div class="right halfWidth no-important" style="text-align:right;" id="portmap-div-editLanPort">\
                <input id="portmap-txt-editLanPort" class="num-only max5" maxlength="5" style="width: 75px;" type="text" />\
              </div>\
              <div class="right halfWidth no-important" id="portmap-div-editLanPortRange" style="text-align:right;display:none">\
                <input id="portmap-txt-editLanPort1" style="width: 75px;" class="num-only max5-range lanrange" maxlength="5" type="text" /> <span>-</span>\
                <input id="portmap-txt-editLanPort2" style="width: 75px;" class="num-only max5-range lanrange" maxlength="5" type="text" />\
              </div>\
            </div>\
          </div>\
          <div class="message message-info message-error not-similiar" id="portmap-err-edit" style="display:none">\
            ');  ngx.print(T"The selected port cannot be configured as it is reserved for internal usage. Please use a different port."); ngx.print('\
          </div>\
          <div class="form-group">\
            <div class="col-sm-12">\
              <div class="modal-footer">\
                <input class="button button-apply save mob-button-width" id="portmap-btn-editSave" value="');  ngx.print(T"Save"); ngx.print('" data-dismiss="modal" type="button" />\
                <input class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" id="portmap-btn-editCancel" data-dismiss="modal" value="');  ngx.print(T"Cancel"); ngx.print('" type="button" />\
              </div>\
            </div>\
          </div>\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
\
<!-- Add Port Mapping Popup Modal-->\
<div class="modal fade" id="portmap-popup-add" role="dialog" data-backdrop="static">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
      <div class="modal-header hidden-sm hidden-md hidden-lg">\
        <div class="mobile-cancel-popup button-cancel"></div>\
      </div>\
      <div class="modal-body no-padding">\
        <form class="form-horizontal">\
          <div class="form-group">\
            <div class="col-sm-12">\
              <p class="title tL">\
                ');  ngx.print(T"Add Port Mapping"); ngx.print('\
              </p>\
            </div>\
          </div>\
          <div class="vdf-table">\
            ');  
              local rows = {
                {
                  label = T"Service",
                  element = ui_helper.createTextField({id = "portmap-txt-addService", class = "port-input", type="text"}),
                },
                {
                  label = T"Protocol",
                  element = ui_helper.createDropDown({id = "portmap-sel-addProtocol", class = "service", style = "font-weight:bold;"}, protocolList),
                  colRightClass = "right rel",
                  colRightId = "top-info-mode"
                },
                {
                  label = T"Device",
                  element = ui_helper.createDropDown({id = "portmap-sel-addDevices"}, deviceDropdownOptions,"",{{"noDevice", T"No specific device"}}),
                  colRightClass = "right rel",
                  colRightId = "top-info-mode"
                },
                {
                  label = T"LAN IP",
                  element = ui_helper.createIPAddressFields("portmap-txt-addIP", "addIP"),
                  colRightClass = "right halfWidth no-important"
                }
              }
              for i, v in ipairs(rows) do
                ngx.print(ui_helper.createRow(v))
              end
              ngx.print('\
            <div class="vdf-row">\
              <div class="left">\
                <label for="portSingle" class="control-label">');  ngx.print(T"Port Type"); ngx.print('</label>\
              </div>\
              <div class="right" style="width:50%;">\
                <span class="fL" style="width:50%;">\
                  ');  
                    ngx.print(ui_helper.createRadioButton({
                      class = "radio radio-checked",
                      name = "add-port-radio",
                      checked = "checked",
                      id = "portmap-rad-addPortS",
                      type = "radio",
                      value = "1"
                    },"portmap-rad-addPortS",
                    {
                      style = "margin-right: 10px;"
                    },T"Port"))
                    ngx.print('\
                </span>\
                <span style="display:inline-block; width:50%;">\
                  ');  
                    ngx.print(ui_helper.createRadioButton({
                      class = "radio radio-checked",
                      name = "add-port-radio",
                      checked = "checked",
                      id = "portmap-rad-addPortR",
                      type = "radio",
                      value = "2"
                    },"portmap-rad-addPortR",
                    {
                      style = "margin-right: 10px;"
                    },T"Port range"))
                    ngx.print('\
                </span>\
              </div>\
            </div>\
            <div class="vdf-row">\
              <div class="left">\
                <label for="inputPassword2" class="control-label" id="portmap-lbl-addPort1">');  ngx.print(T"Public Port"); ngx.print('</label>\
              </div>\
              <div class="right halfWidth no-important" id="portmap-div-addWanPort" style="text-align:right;">\
                <input class="num-only max5" maxlength="5" id="portmap-txt-addWanPort" style="width: 75px;" type="text" />\
              </div>\
              <div class="right halfWidth no-important" id="portmap-div-addWanPortRange" style="text-align:right; display:none">\
                <input class="num-only max5-range wanrange" maxlength="5" style="width: 75px;" id="portmap-txt-addWanPort1" style="width: 75px;" type="text" /> -\
                <input class="num-only max5-range wanrange" maxlength="5" style="width: 75px;" id="portmap-txt-addWanPort2" style="width: 75px;" type="text" />\
              </div>\
            </div>\
            <div class="vdf-row">\
              <div class="left">\
                <label for="inputPassword2" class="control-label" id="portmap-lbl-addPort2">');  ngx.print(T"Local Port"); ngx.print('</label>\
              </div>\
              <div class="right halfWidth no-important" id="portmap-div-addLanPort">\
                <input class="num-only max5" maxlength="5" id="portmap-txt-addLanPort" style="width: 75px;" type="text" />\
              </div>\
              <div class="right halfWidth no-important" id="portmap-div-addLanPortRange" style="text-align:right; display:none">\
                <input class="num-only max5-range lanrange" maxlength="5" style="width: 75px;" id="portmap-txt-addLanPort1" style="width: 75px;" type="text" /> -\
                <input class="num-only max5-range lanrange" maxlength="5" style="width: 75px;" id="portmap-txt-addLanPort2" style="width: 75px;" type="text" />\
              </div>\
            </div>\
          </div>\
          <div class="message message-info message-error not-similiar" id="portmap-err-add" style="display:none">\
            ');  ngx.print(T"The selected port cannot be configured as it is reserved for internal usage. Please use a different port."); ngx.print('\
          </div>\
          <div class="form-group">\
            <div class="col-sm-12">\
              <div class="modal-footer">\
                <input class="button button-apply save mob-button-width" id="portmap-btn-addSave" value="');  ngx.print(T"Save"); ngx.print('" data-dismiss="modal" type="button" />\
                <input class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" data-dismiss="modal" value="');  ngx.print(T"Cancel"); ngx.print('" type="button" id="portmap-btn-addCancel" />\
              </div>\
            </div>\
          </div>\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
\
<script src="js/global-min.js"></script>\
<script>\
  var devices = [];\
  var selectedRow = [];\
  var MAX_MOBILE_WIDTH = 767;\
  var screenSize = $(window).width();\
  var reservedPorts = [];\
  var variant = "');  ngx.print(vodafone.variant); ngx.print('";\
  if ($("#home-sel-mode").val() !== "35" && variant != "NZ") $("#NATSection").hide();\
  ');  for k in pairs(devices) do   ngx.print('\
    devices.push("');  ngx.print(k); ngx.print('")\
  ');  end   ngx.print('\
  var T = {\
    "Public Port" : "');  ngx.print(T"Public Port"); ngx.print('",\
    "Local Port" : "');  ngx.print(T"Local Port"); ngx.print('",\
    "Public Port Range" : "');  ngx.print(T"Public Port Range"); ngx.print('",\
    "Local Port Range" : "');  ngx.print(T"Local Port Range"); ngx.print('",\
    "Service" : "');  ngx.print(T"Service"); ngx.print('",\
    "Local IP Address" : "');  ngx.print(T"Local IP Address"); ngx.print('",\
    "Protocol" : "');  ngx.print(T"Protocol"); ngx.print('"\
  }\
  var reservedPorts = ');  ngx.print(json.encode(reservedPorts)); ngx.print('\
  var resetPortmapping = ');  ngx.print(json.encode(resetportmapping)); ngx.print('\
</script>\
<script src="js/internet/portMapping.js"></script>\
'); 