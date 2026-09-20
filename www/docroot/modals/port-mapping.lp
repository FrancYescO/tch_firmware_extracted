--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")
local string = string
local format, match, untaint = string.format, string.match, string.untaint
local table, setmetatable = table, setmetatable
local pairs, ipairs, sort, next, concat = pairs, ipairs, table.sort, next, table.concat
local tonumber = tonumber
local untaint_mt = require("web.taint").untaint_mt
local setMetaTable = setmetatable
local json = require("dkjson")
local subnetError

local getNATpath = content_helper.getMatchedContent("uci.firewall.cone.", {name = "NAT traversal"})

local network_details = {
  gateway_ip = "uci.network.interface.@lan.ipaddr",
  netmask    = "uci.network.interface.@lan.netmask",
}
content_helper.getExactContent(network_details)

-- Function to compare tables based on their index
local function compareIndexInTable(a, b)
  return tonumber(a.index) < tonumber(b.index)
end
-- Function to compare tables based on their Name
local function compareNameInTable(a, b)
  return a.Name < b.Name
end

local HelperPath = content_helper.convertResultToObject("uci.firewall.helper.", proxy.get("uci.firewall.helper."))

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
    Q931   = "Q931",
  }, untaint_mt)
  local HelperNameTable = {}
  for _, v in ipairs(HelperPath) do

    if ALGListTable[v.helper] then
      --Check for helpers of same name
      if not HelperNameTable[ALGListTable[v.helper] .. "name"] and v.intf ~= "loopback" then
        HelperNameTable[ALGListTable[v.helper] .. "name"] = true
        ALGData[#ALGData+1] = {}
        ALGData[#ALGData].Name = ALGListTable[v.helper]
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
  sort(ALGData, compareNameInTable)
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
  reservedPorts[#reservedPorts +1] = {
    port = servicesTable[i].value,
    proto = servicesTable[i+1].value
  }
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
    if reservedPort.proto == protocol or protocol == "tcpudp" then
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
        protocol  = ports[i].proto
      }
      local portMapValidations = {
        dest_ip   = validateIP,
        name      = validateService,
        protocol  = validateProtocol
      }

      local valid = content_helper.validateObject(portMapData, portMapValidations) and --Validating all necessary portmap rule details
        validatePort(ports[i].wan_port, ports[i], "wan_port") and   --Check if the public port range is valid
        validatePort(ports[i].lan_port, ports[i], "lan_port") and   --Check if the lan port range is valid
        validateReservedPort(ports[i].wan_port, ports[i].proto) and --Check if the specified ports aren't reserved ports
        validateAndGetPortRange(ports[i])                           --Check if the public port range and lan port range are equal
      if not valid then
        return nil
      end
    end
  end

  for i = 1, #ports do
    if ports[i].index and not match(ports[i].index, "del.+") then
      local proto1   = ports[i].proto
      local lanIP1   = ports[i].ip
      local _, wanPortStart1, wanPortEnd1, LanPortStart1, LanPortEnd1 = validateAndGetPortRange(ports[i])
      for j = i+1, #ports do
        if not match(ports[j].index, "del.+") then
          local proto2   = ports[j].proto
          local lanIP2   = ports[j].ip
          local _, wanPortStart2, wanPortEnd2, LanPortStart2, LanPortEnd2 = validateAndGetPortRange(ports[j])
          if proto1 == proto2 or proto1 == "tcpudp" or proto2 == "tcpudp" then     -- duplicate protocols, so check further
            if (LanPortStart1 <= LanPortEnd2 and LanPortEnd1 >= LanPortStart2 and lanIP1 == lanIP2) or                        -- duplicate/overlapping lan ports for same device
               (wanPortStart1 <= wanPortEnd2 and wanPortEnd1 >= wanPortStart2) then  -- duplicate/overlapping wan ports
              return nil
            end
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
local dropdownOptions =  {}

for i, v in ipairs(devicesList) do
  local IPv4address = match(v.IPAddress, "%d+.%d+.%d+.%d+")
  if IPv4address then
    devices[IPv4address] = { name = v.FriendlyName, mac = v.MACAddress }
    hostNameCount[v.FriendlyName] = (hostNameCount[v.FriendlyName] or 0) + 1
  end
end

for k, v in pairs(devices) do
  if hostNameCount[v.name] > 1 then
    devices[k].name = format("%s (%s)", v.name, v.mac)
  end
  dropdownOptions[#dropdownOptions+1] = format("<option value='%s'>%s</option>", k, devices[k].name)
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

if ngx.req.get_method() == "POST" then
  local postargs = ngx.req.get_post_args()
  local portmapTable = json.decode(untaint(postargs.portmapTable))
  local ALGTable = json.decode(untaint(postargs.ALGTable))
  local deletedIndices = {}
  local rows = tonumber(postargs.rows)
  local NATStatus = postargs.NATStatus
  local validData = validatePortMapDetails(portmapTable) and validateALG(ALGTable)

  if validData then
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
      content_helper.addNewObject("uci.firewall.cone.", NATdetails, paramMapForNAT)
    elseif NATStatus == "false" and next(getNATpath) then
      proxy.del(getNATpath[1].path)
    end
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

for i, v in pairs(portmapsList) do
  portmaps[i] = {}
  portmaps[i].index    = v.paramindex
  portmaps[i].service  = v.name
  portmaps[i].ip       = v.dest_ip == "unknown" and T"Offline" or v.dest_ip
  -- protocol is a seperate list which cannot be get correctly from convertResultToObject. So get it seperately.
  local protocolPath   = format("rpc.network.firewall.portforward.%s.proto.@1.value",v.paramindex)
  local protocol       = proxy.get(protocolPath)[1].value
  protocol             = protocol == "tcpudp" and "TCP/UDP" or string.upper(protocol)
  portmaps[i].proto    = protocol
  portmaps[i].lan_port = string.gsub(v.dest_port, ":", "-")
  portmaps[i].wan_port = string.gsub(v.src_dport, ":", "-")
end

-- We cannot guarantee transformer to return portmaps table in the same order every time
-- So, sorting this table by param index to display in same order every time in GUI
sort(portmaps, compareIndexInTable)
local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")
  ngx.print('\
<h1>');  ngx.print(T"Port Mapping"); ngx.print('</h1>\
<h2>');  ngx.print(T"Port mapping allows remote computers to connect to a specific device within your private network."); ngx.print('</h2>\
<h3>');  ngx.print(T"Port Mapping"); ngx.print('</h3>\
<div class="h3-content portmap-div-mainTable">\
	<table class="table-four-columns desktop hidden-xs" id="portmap-tbl-desktop">\
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
            <tr class="noRulesSet" ');  if #portmaps ~= 0 then  ngx.print(' style="display:none" ');  end  ngx.print('>\
                <td class="noEntryTD tC italic" colspan="6">\
                    <span>');  ngx.print(T"No port mapping defined"); ngx.print('</span>\
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
<h3>');  ngx.print(T"ALGs"); ngx.print('</h3>\
<div class="h3-content vdf-table" id="portmp-algs">\
  ');  for _, v in ipairs(ALGData) do  ngx.print('\
    <div class="vdf-row">\
      <div class="left light-font">');  ngx.print(v.Name); ngx.print('</div>\
      <div class="right alghelp">\
        <div id="portmapping-btn-alg_');  ngx.print(v.Name); ngx.print('" class="button ');  if v.enable == "1" or v.enable == "" then  ngx.print(' button-on ');  else  ngx.print(' button-off ');  end  ngx.print(' pull-right toggle-content-button button-alg">\
        <input type="hidden" class="name" value="');  ngx.print(v.Name); ngx.print('"/>\
        <input type="hidden" class="status" value="');  ngx.print(v.enable); ngx.print('"/>\
        <input type="hidden" class="index" value="');  ngx.print(v.index); ngx.print('"/>\
      </div>\
      </div>\
  </div>\
  ');  end  ngx.print('\
</div>\
\
<div class="h3-content vdf-table" id="NATSection">\
  <div class="vdf-row">\
    <div class="left light-font">\
      ');  ngx.print(T"NAT Traversal"); ngx.print('\
    </div>\
    <div class="right">\
      <div id="portmapping-btn-nat" class="button ');  if next(getNATpath) then  ngx.print(' button-on ');  else  ngx.print(' button-off ');  end  ngx.print(' pull-right toggle-content-button">\
      </div>\
    </div>\
  </div>\
</div>\
\
');  
  lp.include("apply-cancel.lp")
  lp.include("reset-wrap-mobile.lp")
  ngx.print('\
\
<!-- Port Mapping Popup Modal -->\
<div id="mobile-popup" class="mobile-reset hidden-md hidden-sm hidden-lg">\
  <div class="row padding-bottom-lg">\
    <div class="col-xs-12">\
        <div class="close-icon cancelR"></div>\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-12">\
      <h3 class="padding-bottom-20">');  ngx.print(T"Port Mapping"); ngx.print('</h3>\
    </div>\
  </div>\
</div>\
\
<!-- End -->\
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
              <p class="title tL">');  ngx.print(T"Edit Port Mapping"); ngx.print('</p>\
            </div>\
          </div>\
		  <div class="vdf-table">\
          <div class="vdf-row">\
            <div class="left">\
              <label for="inputPassword" class="control-label">');  ngx.print(T"Service"); ngx.print('</label>\
            </div>\
            <div class="right">\
                <input id="portmap-txt-editService" maxlength="63" type="text" class="port-input"/>\
            </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <label for="inputPassword" class="control-label">');  ngx.print(T"Protocol"); ngx.print('</label>\
            </div>\
              <div id="top-info-mode" class="right rel">\
                <select class="service" id="portmap-sel-editProtocol" style="font-weight:bold;">\
                  ');  
                    for i = 1, #protocolList do
                      ngx.print(format('<option value="%s">%s</option>', protocolList[i][1], protocolList[i][2]))
                    end
                    ngx.print('\
                </select>\
            </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <label for="inputPassword" class="control-label">');  ngx.print(T"Device"); ngx.print('</label>\
            </div>\
              <div id="top-info-mode" class="right rel">\
                <select id="portmap-sel-editDevices">\
                  <option value="noDevice">');  ngx.print(T"No specific device"); ngx.print('</option>\
                  ');  ngx.print(concat(dropdownOptions, " ")); ngx.print('\
                </select>\
              </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <label for="inputPassword2" class="control-label">');  ngx.print(T"LAN IP"); ngx.print('</label>\
            </div>\
              <div class="right halfWidth no-important" style="width: 270px;">\
                <input class="max3 ip editIP" maxlength="3" id="portmap-txt-editIP1" type="text" /> <span>.</span>\
                <input class="max3 ip editIP" maxlength="3" id="portmap-txt-editIP2" type="text" /> <span>.</span>\
                <input class="max3 ip editIP" maxlength="3" id="portmap-txt-editIP3" type="text" /> <span>.</span>\
                <input class="max3 ip editIP" maxlength="3" id="portmap-txt-editIP4" type="text" />\
              </div>\
            </div>\
          <div class="vdf-row">\
            <div class="left">\
              <label for="portSingle" class="control-label">');  ngx.print(T"Type"); ngx.print('</label>\
            </div>\
            <div class="right" style="width:50%;">\
                <span class="fL">\
                  <input name="edit-port-radio" value="1" class="radio radio-checked" checked="checked" id="portmap-rad-editPortS" type="radio" />\
                  <label for="portmap-rad-editPortS" style="margin-right: 10px;"></label>\
                  <span>');  ngx.print(T"Port"); ngx.print('</span>\
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
          <div class="message message-info message-error not-similiar" id="portmap-err-edit" style="display:none">');  ngx.print(T"The selected port cannot be configured as it is reserved for internal usage. Please use a different port."); ngx.print('</div>\
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
<!-- TODO - No lower layer support for Port Triggering Fuctionality\
<!-- Edit Port Triggering Modal  -->\
<!--\
<div class="modal fade" id="editPortTriggeringModal" role="dialog">\
  <div class="modal-dialog"> -->\
    <!-- Modal content-->\
    <!--\
    <div class="modal-content">\
    <div class="modal-header hidden-sm hidden-md hidden-lg">\
       <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
     </div>\
      <div class="modal-body no-padding">\
        <form class="form-horizontal">\
          <div class="form-group">\
            <div class="col-sm-12">\
              <p class="title tL">\
                Edit Port triggering Rule\
              </p>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
              <label for="inputPassword" class="control-label">Outgoing Protocol</label>\
            </div>\
            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
              <div id="top-info-mode" class="rel">\
                <select  class="service" style="font-weight:bold;">\
                  <option value="tcp">TCP</option>\
                  <option value="udp">UDP</option>\
                </select>\
              </div>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
              <label for="portSingle" class="control-label">Type</label>\
            </div>\
            <div class="btn-wrap-mobile col-md-7 col-sm-7 modal-padding-lrt-none">\
              <div class="col-xs-6 col-md-5 col-sm-5 modal-padding-lrt-none fL">\
                <span class="fL">\
                  <input class="radio radio-checked" name="portsE" id="editTriggerOutgoing" type="radio" />\
                  <label for="editTriggerOutgoing" style="margin-right: 10px;"></label>\
                  <span>Port</span>\
                </span>\
              </div>\
              <div class="col-xs-6 col-md-7 col-sm-7 modal-padding-lrt-none fL">\
                <span style="display:inline-block;">\
                  <input class="radio radio-checked" checked="checked" name="portsE" id="editTrigger2Outgoing" type="radio" />\
                  <label for="editTrigger2Outgoing" style="margin-right: 10px;"></label>\
                  <span>Port range</span>\
                </span>\
              </div>\
            </div>\
          </div>\
       <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
              <label for="inputPassword2" class="control-label">Outgoing Port</label>\
            </div>\
            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
              <div class="right halfWidth no-important" id="unknownIPedit">\
                <input class="num-only max5 ip" value="9000" type="text" /> .\
                <input class="num-only max5 ip" value="9003" type="text" />\
              </div>\
            </div>\
          </div>\
           <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
              <label for="inputPassword" class="control-label">Incoming Protocol</label>\
            </div>\
            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
              <div id="top-info-mode" class="rel">\
                <select  class="service" style="font-weight:bold;">\
                  <option value="tcp">TCP</option>\
                  <option value="udp">UDP</option>\
                </select>\
              </div>\
            </div>\
          </div>\
      <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
              <label for="portSingle" class="control-label">Type</label>\
            </div>\
            <div class="btn-wrap-mobile col-md-7 col-sm-7 modal-padding-lrt-none">\
              <div class="col-xs-6 col-md-5 col-sm-5 modal-padding-lrt-none fL">\
                <span class="fL">\
                  <input class="radio radio-checked" name="portsE" id="editTriggerIncoming" type="radio" />\
                  <label for="editTriggerIncoming" style="margin-right: 10px;"></label>\
                  <span>Port</span>\
                </span>\
              </div>\
              <div class="col-xs-6 col-md-7 col-sm-7  modal-padding-lrt-none fL">\
                <span style="display:inline-block;">\
                  <input class="radio radio-checked" checked="checked" name="portsE" id="editTrigger2Incoming" type="radio" />\
                  <label for="editTrigger2Incoming" style="margin-right: 10px;"></label>\
                  <span>Port range</span>\
                </span>\
              </div>\
            </div>\
          </div>\
           <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
              <label for="inputPassword2" class="control-label">Incoming Port</label>\
            </div>\
            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
              <div class="right halfWidth no-important" id="unknownIPedit">\
                <input class="num-only max5 ip" value="8000" type="text" /> .\
                <input class="num-only max5 ip" value="8003" type="text" />\
              </div>\
            </div>\
          </div>\
          <div class="form-group">\
            <div class="col-sm-12">\
              <div class="modal-footer">\
                <input class="button button-apply save mob-button-width" value="Save"  type="button" />\
                <input class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" data-dismiss="modal" value="Cancel" type="button" />\
              </div>\
            </div>\
          </div>\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
-->\
<!-- Add Port Mapping Popup Modal-->\
<div class="modal fade" id="portmap-popup-add" role="dialog" data-backdrop="static">\
  <div class="modal-dialog">\
    <!-- Modal content-->\
    <div class="modal-content">\
    <div class="modal-header hidden-sm hidden-md hidden-lg">\
        <div class="mobile-cancel-popup button-cancel"></div>\
\
      </div>\
      <div class="modal-body no-padding">\
        <form class="form-horizontal">\
          <div class="form-group">\
            <div class="col-sm-12">\
              <p class="title tL">');  ngx.print(T"Add Port Mapping"); ngx.print('</p>\
            </div>\
          </div>\
		  <div class="vdf-table">\
          <div class="vdf-row">\
            <div class="left">\
              <label for="inputPassword" class="control-label">');  ngx.print(T"Service"); ngx.print('</label>\
            </div>\
              <div class="right" style="text-align:right;">\
                <input id="portmap-txt-addService" class="port-input" type="text" />\
              </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <label for="inputPassword" class="control-label">');  ngx.print(T"Protocol"); ngx.print('</label>\
            </div>\
              <div id="top-info-mode" class="right rel">\
                <select id="portmap-sel-addProtocol" class="service" style="font-weight:bold;">\
                  ');  
                    for i = 1, #protocolList do
                      ngx.print(format('<option value="%s">%s</option>', protocolList[i][1], protocolList[i][2]))
                    end
                    ngx.print('\
                </select>\
            </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <label for="inputPassword" class="control-label">');  ngx.print(T"Device"); ngx.print('</label>\
            </div>\
              <div id="top-info-mode" class="right rel">\
                <select id="portmap-sel-addDevices">\
                  <option value="noDevice">');  ngx.print(T"No specific device"); ngx.print('</option>\
                  ');  ngx.print(concat(dropdownOptions, " ")); ngx.print('\
                </select>\
            </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <label for="inputPassword2" class="control-label">');  ngx.print(T"LAN IP"); ngx.print('</label>\
            </div>\
              <div class="right halfWidth no-important">\
                <input class="max3 ip addIP" maxlength="3" id="portmap-txt-addIP1" type="text" /> <span>.</span>\
                <input class="max3 ip addIP" maxlength="3" id="portmap-txt-addIP2" type="text" /> <span>.</span>\
                <input class="max3 ip addIP" maxlength="3" id="portmap-txt-addIP3" type="text" /> <span>.</span>\
                <input class="max3 ip addIP" maxlength="3" id="portmap-txt-addIP4" type="text" />\
              </div>\
          </div>\
\
\
          <div class="vdf-row">\
            <div class="left">\
              <label for="portSingle" class="control-label">');  ngx.print(T"Type"); ngx.print('</label>\
            </div>\
            <div class="right" style="width:50%;">\
                <span class="fL" style="width:50%;">\
                  <input class="radio radio-checked" value="1" name="add-port-radio" checked="checked" id="portmap-rad-addPortS" type="radio" />\
                  <label for="portmap-rad-addPortS" style="margin-right: 10px;"></label>\
                  <span>');  ngx.print(T"Port"); ngx.print('</span>\
                </span>\
                <span style="display:inline-block; width:50%;">\
                  <input class="radio radio-checked" value="2" name="add-port-radio" id="portmap-rad-addPortR" type="radio" />\
                  <label for="portmap-rad-addPortR" style="margin-right: 10px;"></label>\
                  <span>');  ngx.print(T"Port range"); ngx.print('</span>\
                </span>\
            </div>\
          </div>\
\
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
          <div class="message message-info message-error not-similiar" id="portmap-err-add" style="display:none">');  ngx.print(T"The selected port cannot be configured as it is reserved for internal usage. Please use a different port."); ngx.print('</div>\
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
<!-- TODO - No lower layer support for Port Triggering Fuctionality\
<!-- Add Port Triggering Popup Modal-->\
<!--\
<div class="modal fade" id="addPortTriggeringModal" role="dialog">\
  <div class="modal-dialog"> -->\
    <!-- Modal content -->\
    <!--\
    <div class="modal-content">\
    <div class="modal-header hidden-sm hidden-md hidden-lg">\
       <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
      </div>\
      <div class="modal-body no-padding">\
        <form class="form-horizontal">\
          <div class="form-group">\
            <div class="col-sm-12">\
              <p class="title tL">\
                Add Port triggering Rule\
              </p>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
              <label for="inputPassword" class="control-label">Outgoing Protocol</label>\
            </div>\
            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
              <div id="top-info-mode" class="rel">\
                <select  class="service" style="font-weight:bold;">\
                  <option value="tcp">TCP</option>\
                  <option value="udp">UDP</option>\
                </select>\
              </div>\
            </div>\
          </div>\
      <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
              <label for="portSingle" class="control-label">Type</label>\
            </div>\
            <div class="btn-wrap col-md-7 col-sm-7 modal-padding-lrt-none">\
              <div class="col-xs-6 col-md-5 col-sm-5 modal-padding-lrt-none fL">\
                <span class="fL">\
                  <input class="radio radio-checked" name="portsE" id="portSingle" type="radio" />\
                  <label for="portSingle" style="margin-right: 10px;"></label>\
                  <span>Port</span>\
                </span>\
              </div>\
              <div class="col-xs-6 col-md-7 col-sm-7 modal-padding-lrt-none fL">\
                <span style="display:inline-block;">\
                  <input class="radio radio-checked" checked="checked" name="portsE" id="portRange" type="radio" />\
                  <label for="portRange" style="margin-right: 10px;"></label>\
                  <span>Port range</span>\
                </span>\
              </div>\
            </div>\
          </div>\
      <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
              <label for="inputPassword2" class="control-label">Outgoing Port</label>\
            </div>\
            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
              <div class="right halfWidth no-important" id="unknownIPedit">\
                <input class="num-only max5" id="publicSinglePort1" style="width: 75px;" type="text" />\
              </div>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
              <label for="inputPassword" class="control-label">Incoming Protocol</label>\
            </div>\
            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
              <div id="top-info-mode" class="rel">\
                <select id="devicesSelectEdit">\
                  <option value="tcp">TCP</option>\
                  <option value="udp">UDP</option>\
                </select>\
              </div>\
            </div>\
          </div>\
       <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
              <label for="portSingle" class="control-label">Type</label>\
            </div>\
            <div class="col-md-7 col-sm-7 btn-wrap modal-padding-lrt-none">\
              <div class="col-xs-6 col-md-5 col-sm-5 modal-padding-lrt-none fL">\
                <span class="fL">\
                  <input class="radio radio-checked" name="portsE" id="portSingle" type="radio" />\
                  <label for="portSingle" style="margin-right: 10px;"></label>\
                  <span>Port</span>\
                </span>\
              </div>\
              <div class="col-xs-6 col-md-7 col-sm-7 modal-padding-lrt-none fL">\
                <span style="display:inline-block;">\
                  <input class="radio radio-checked" checked="checked" name="portsE" id="portRange" type="radio" />\
                  <label for="portRange" style="margin-right: 10px;"></label>\
                  <span>Port range</span>\
                </span>\
              </div>\
            </div>\
          </div>\
          <div class="form-group padding-top-bottom-20 no-margin">\
            <div class="col-md-5 col-sm-5 modal-padding-lrt-none">\
              <label for="inputPassword2" class="control-label">Incoming Port</label>\
            </div>\
            <div class="col-md-7 col-sm-7 modal-padding-lrt-none btn-wrap-mobile">\
              <div class="right halfWidth no-important" id="unknownIPedit">\
                <input class="num-only max5" style="width: 75px;" type="text" />\
              </div>\
            </div>\
          </div>\
          <div class="form-group">\
            <div class="col-sm-12">\
              <div class="modal-footer">\
                <input class="button button-apply save mob-button-width" value="Save"  type="button" />\
                <input class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" data-dismiss="modal" value="Cancel" type="button" />\
              </div>\
            </div>\
          </div>\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
-->\
<script src="js/global.js"></script>\
<script>\
  var devices = [];\
  var selectedRow = [];\
  var MAX_MOBILE_WIDTH = 767;\
  var screenSize = $(window).width();\
  var reservedPorts = [];\
  ');  for k in pairs(devices) do   ngx.print('\
       devices.push("');  ngx.print(k); ngx.print('")\
  ');  end   ngx.print('\
  var T = {\
    "Public Port" : "');  ngx.print(T"Public Port"); ngx.print('",\
    "Local Port" : "');  ngx.print(T"Local Port"); ngx.print('",\
    "Public Port Range" : "');  ngx.print(T"Public Port Range"); ngx.print('",\
    "LAN Port Range" : "');  ngx.print(T"LAN Port Range"); ngx.print('",\
    "Service" : "');  ngx.print(T"Service"); ngx.print('",\
    "Local IP Address" : "');  ngx.print(T"Local IP Address"); ngx.print('",\
    "Protocol" : "');  ngx.print(T"Protocol"); ngx.print('"\
  }\
  var reservedPorts = ');  ngx.print(json.encode(reservedPorts)); ngx.print('\
  var resetPortmapping = ');  ngx.print(json.encode(resetportmapping)); ngx.print('\
</script>\
<script src="js/port-mapping.js"></script>\
'); 