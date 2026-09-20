--pretranslated: do not change this file
 
--Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local vdf_helper = require("vodafone_helper")
local json = require("dkjson")
local string, tostring = string, tostring
local match, format, untaint, gsub = string.match, string.format, string.untaint, string.gsub
local ipv42num = post_helper.ipv42num
local pairs, ipairs, tonumber = pairs, ipairs, tonumber
local table = table
local concat = table.concat
local calculateDHCPStartAndLimitAddress = vdf_helper.calculateDHCPStartAndLimitAddress
local splitIP = vdf_helper.split_IP_into_Octets
local validateIPRange = vdf_helper.validateIPRange

-- TODO:
-- Playground doesn't contain tcpudp. We don't have lower layer support
-- for protocol. So let's show tcpupdp so that it refers both Protocols
-- Remove tcpudp once we got lower layer support
local protocolList = {
  { "tcp", "TCP"},
  { "udp", "UDP"},
  { "tcpudp", "TCP/UDP"},
}
local validateProtocol = post_helper.getValidateInEnumSelect(protocolList)

local redirections = {}
local redirectionPath = "uci.firewall.cone."
local redirectionList = content_helper.convertResultToObject(redirectionPath, proxy.get(redirectionPath))

-- Function to validate Service name
-- Only allow name between 1 and 63 characters having alphanumerics/dash
-- @param #string - Service name of a rule
-- @return #boolean  - true if service is valid, nil if not
local function validateServiceName(service)
  if #service > 0 and #service < 64 and not match(service, "[^%w%-%s]") then
    return true
  end
end

local params = {
  IPAddress  = "uci.network.interface.@lan.ipaddr",
  localdevmask = "uci.network.interface.@lan.netmask",
  start = "uci.dhcp.dhcp.@STB_networkid.start",
  limit = "uci.dhcp.dhcp.@STB_networkid.limit",
  stbOption = "uci.dhcp.match.1.match"
}
content_helper.getExactContent(params)

-- STB IP - Start and End
local startAddress, endAddress = calculateDHCPStartAndLimitAddress(tonumber(ipv42num(params.IPAddress)), tonumber(ipv42num(params.localdevmask)), tonumber(params.start), tonumber(params.limit))

for i, v in ipairs(redirectionList) do
  if ipv42num(v.dest_ip) and validateIPRange(startAddress, endAddress)(v.dest_ip) then
    redirections[#redirections + 1] = {}
    redirections[#redirections].index    = v.paramindex
    redirections[#redirections].enabled  = "1"
    redirections[#redirections].service  = v.name
    redirections[#redirections].ip       = v.dest_ip
    redirections[#redirections].proto    = "TCP/UDP" -- Hardcoded because of no lower layer support. It will be the default till lower layer supports
    redirections[#redirections].lan_port = gsub(v.dest_port, ":", "-")
    redirections[#redirections].wan_port = gsub(v.src_port, ":", "-")
  end
end

local devicesList = proxy.get("rpc.hosts.host.")
devicesList = content_helper.convertResultToObject("rpc.hosts.host.", devicesList)
local devices = {}
local hostNameCount = {}
local dropdownOptions =  {}

-- Iterate over all connected device and find the devices within STB IP Range
for i, v in ipairs(devicesList) do
  local IPv4address = match(v.IPAddress, "%d+.%d+.%d+.%d+")
  if IPv4address and validateIPRange(startAddress, endAddress)(IPv4address) then
    devices[IPv4address] = { name = v.FriendlyName, mac = v.MACAddress }
    hostNameCount[v.FriendlyName] = (hostNameCount[v.FriendlyName] or 0) + 1
  end
end

-- Construct <option> with all devices for <select> element used in HTML
for k, v in pairs(devices) do
  if hostNameCount[v.name] > 1 then
    devices[k].name = format("%s (%s)", v.name, v.mac)
  end
  dropdownOptions[#dropdownOptions+1] = format("<option value='%s'>%s</option>", k, devices[k].name)
end

-- Function to validate all the Portmap values coming from GUI
-- Also, it will validate duplicate and overlapping wan and lan ports
-- @function validateTvSettingsDetails
-- @param #table data All portMap details coming from each rows in GUI
-- @param #string startIP First IP in STB Range
-- @param #string endIP Last IP in STB Range
-- @return #boolean  - true if everything is valid, nil if anything fails
local function validateTvSettingsDetails(data, startIP, endIP)
  -- Validate all the Portmap values coming from GUI
  for i, v in ipairs(data) do
    local tvData = {
      dest_ip   = v.ip,
      name      = v.service,
      protocol  = v.proto
    }
    local tvValid = {
      dest_ip   = validateIPRange(startIP, endIP),
      name      = validateServiceName,
      protocol  = validateProtocol
    }
    local valid = content_helper.validateObject(tvData, tvValid)
    if not valid then
      return nil
    end
  end

  -- Convert single port to port range so that overlap validation can be done
  -- Validate duplicate and overlapping wan and lan ports
  for i = 1, #data do
    if data[i].index and not match(data[i].index, "del.+") then
      local lanPortStart1, lanPortEnd1 = match(data[i].lan_port, "(%d+):(%d+)")
      if not lanPortStart1 then
        lanPortStart1, lanPortEnd1 = data[i].lan_port, data[i].lan_port
      end
      lanPortStart1  = tonumber(lanPortStart1)
      lanPortEnd1    = tonumber(lanPortEnd1)
      if lanPortStart1 and lanPortEnd1 and (lanPortStart1 > lanPortEnd1) then
        return nil
      end
      local wanPortStart1, wanPortEnd1 = match(data[i].wan_port, "(%d+):(%d+)")
      if not wanPortStart1 then
        wanPortStart1, wanPortEnd1 = data[i].wan_port, data[i].wan_port
      end
      wanPortStart1  = tonumber(wanPortStart1)
      wanPortEnd1    = tonumber(wanPortEnd1)
      if wanPortStart1 and wanPortEnd1 and (wanPortStart1 > wanPortEnd1) then
        return nil
      end
      local proto1   = data[i].proto
      local ip1   = data[i].ip
      for j = i+1, #data do
        if data[j].index and not match(data[j].index, "del.+") then
          local lanPortStart2, lanPortEnd2 = match(data[j].lan_port, "(%d+):(%d+)")
          local wanPortStart2, wanPortEnd2 = match(data[j].wan_port, "(%d+):(%d+)")
          if not lanPortStart2 then
            lanPortStart2, lanPortEnd2 = data[j].lan_port, data[j].lan_port
          end
          if not wanPortStart2 then
            wanPortStart2, wanPortEnd2 = data[j].wan_port, data[j].wan_port
          end
          lanPortStart2  = tonumber(lanPortStart2)
          lanPortEnd2    = tonumber(lanPortEnd2)
          if lanPortStart2 and lanPortEnd2 and (lanPortStart2 > lanPortEnd2) then
            return nil
          end
          wanPortStart2  = tonumber(wanPortStart2)
          wanPortEnd2    = tonumber(wanPortEnd2)
          if wanPortStart2 and wanPortEnd2 and (wanPortStart2 > wanPortEnd2) then
            return nil
          end
          local proto2   = data[j].proto
          local ip2   = data[j].ip
          if proto1 == proto2 and ip1 == ip2 then  -- duplicate protocols and IP, so check further
            if lanPortStart1 and lanPortEnd2 and lanPortEnd1 and lanPortStart2 and
               (lanPortStart1 <= lanPortEnd2 and lanPortEnd1 >= lanPortStart2) or     -- duplicate lan ports
               wanPortStart1 and wanPortEnd2 and wanPortEnd1 and wanPortStart2 and
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

-- Function to validate all the DHCP Related values coming from GUI
-- @function validateDHCPParams
-- @param #table data All DHCP Related values from each rows in GUI
-- @return #boolean  - true if everything is valid, nil if anything fails
local function validateDHCPParams(data)
  local DHCPData = {
    DHCPstart = data.startIP,
    DHCPend   = data.endIP,
    opt12     = data.opt12,
  }
  local DHCPValid = {
    DHCPstart = post_helper.getValidateNumberInRange(1,255),
    DHCPend   = post_helper.getValidateNumberInRange(1,255),
    opt12     = post_helper.getValidateStringLengthInRange(1,63)
  }
  local valid = content_helper.validateObject(DHCPData, DHCPValid)
  if not valid then
    return nil
  end
  return true
end

if ngx.req.get_method() == "POST" then
  ngx.header.content_type = "application/json"
  local postargs = ngx.req.get_post_args()
  local tvSettingsTable = json.decode(untaint(postargs.tvSettingsTable))
  local dhcpParams = json.decode(untaint(postargs.dhcpParams))
  local rows = tonumber(postargs.rows)
  local validTvSettings = validateDHCPParams(dhcpParams) and validateTvSettingsDetails(tvSettingsTable, postargs.startAddress, postargs.endAddress)

  if not validTvSettings then
    ngx.print('{ "status":"error" }')
    ngx.exit(ngx.HTTP_OK)
  end

  local paramMap = {
    service   = "name",
    ip        = "dest_ip",
    -- proto     = proto,
    lan_port  = "dest_port",
    wan_port  = "src_port",
  }
  for i = 1, rows do
    local tvSettingIndex = tvSettingsTable[i].index
    local index

    --Deleting Tv Setting rule
    index = match(tvSettingIndex, "del(%d+)")
    if index then
      proxy.del(format("uci.firewall.cone.%d.", index))
    end
    local tvSettingData = {
      index   = tvSettingsTable[i].index,
      service   = tvSettingsTable[i].name,
      ip         = tvSettingsTable[i].ip,
      -- proto      = tvSettingsTable[i].proto,
      lan_port       = tvSettingsTable[i].lan_port,
      wan_port    = tvSettingsTable[i].wan_port,
    }

    --Add Tv Setting rules
    if tvSettingIndex == "new" then
      content_helper.addNewObject("uci.firewall.cone.", tvSettingData, paramMap)
    end

    --Editing Tv Setting rule
    if match(tvSettingIndex, "^%d+$") then
      local validData = content_helper.setObject(tvSettingData, paramMap, "uci.firewall.cone." .. tvSettingData.index .. ".")
      if not validData then
        break
      end
    end
  end
  if validTvSettings then
    paramMap = {
      start = "uci.dhcp.dhcp.@STB_networkid.start",
      limit = "uci.dhcp.dhcp.@STB_networkid.limit",
      opt12 = "uci.dhcp.match.1.match"
    }
    local dhcpData = {
      start = tostring(dhcpParams.startIP),
      limit = tostring(dhcpParams.endIP),
      opt12 = tostring(dhcpParams.opt12)
    }
    validTvSettings, msg = content_helper.setObject(dhcpData, paramMap)
    if not validTvSettings then print("\n\n\n Set failed \n\n\n") print(msg) end
  end

  if not validTvSettings then
    ngx.print('{ "status":"error" }')
  else
    proxy.apply()
    ngx.print('{ "status":"success" }')
  end
  ngx.exit(ngx.HTTP_OK)
end

startAddress, endAddress = splitIP(startAddress), splitIP(endAddress)

  ngx.print('\
<!-- Start -->\
<h1><span>');  ngx.print(T"TV Settings"); ngx.print('</span></h1>\
<h3><span>');  ngx.print(T"Redirections"); ngx.print('</span></h3>\
<form id="tvSettings-form" class="form-horizontal" method="post" action="modals/tv-settings.lp">\
  <div class="content-tv-settings">\
    <div class="h3-content table-responsive mobile-margin-bottom-lg">\
      <div class="table tvSettings tvSettings-table no-margin-bottom" id ="tvSettings-table">\
        <div class="table-row table-row-head">\
          <div class="table-col">\
            <span>');  ngx.print(T"Service Name"); ngx.print('</span>\
          </div>\
          <div class="table-col">\
            <span>');  ngx.print(T"LAN IP"); ngx.print('</span>\
          </div>\
          <div class="table-col">\
            <span>');  ngx.print(T"Protocol"); ngx.print('</span>\
          </div>\
          <div class="table-col">\
            <span>');  ngx.print(T"LAN Port"); ngx.print('</span>\
          </div>\
          <div class="table-col">\
            <span>');  ngx.print(T"Public Port"); ngx.print('</span>\
          </div>\
          <div class="table-col">\
            &nbsp;\
          </div>\
          <div class="table-col">\
            &nbsp;\
          </div>\
        </div>\
        ');  for i=1, #redirections do   ngx.print('\
        ');  local tvSettingsRowclass = redirections[i].enabled  and "tvSettingsRow" or "tvSettingsRow op40"   ngx.print('\
        <div class="table-row">\
          <div class="table-col ');  ngx.print(tvSettingsRowclass); ngx.print(' service">');  ngx.print(redirections[i].service); ngx.print('</div>\
          <div class="table-col ');  ngx.print(tvSettingsRowclass); ngx.print(' ip">');  ngx.print(redirections[i].ip); ngx.print('</div>\
          <div class="table-col ');  ngx.print(tvSettingsRowclass); ngx.print(' proto">');  ngx.print(redirections[i].proto); ngx.print('</div>\
          <div class="table-col ');  ngx.print(tvSettingsRowclass); ngx.print(' lan_port">');  ngx.print(redirections[i].lan_port); ngx.print('</div>\
          <div class="table-col ');  ngx.print(tvSettingsRowclass); ngx.print(' wan_port">');  ngx.print(redirections[i].wan_port); ngx.print('</div>\
          <div class="table-col ');  ngx.print(tvSettingsRowclass); ngx.print('">\
            <input class="button button-edit editbutton" id="tvSettings-btn-edit_');  ngx.print(i); ngx.print('" type="button" data-toggle="modal" data-target="#tv-popup-edit" onclick="copyData(this)">\
          </div>\
          <div class="table-col ');  ngx.print(tvSettingsRowclass); ngx.print('">\
            <input class="button button-delete deletebutton" id="tvSettings-btn-delete_');  ngx.print(i); ngx.print('" type="button">\
            <input type="hidden" class="index" value="');  ngx.print(redirections[i].index); ngx.print('"/>\
            <input type="hidden" class="enabled" value="');  ngx.print(redirections[i].enabled and 1 or 0); ngx.print('"/>\
          </div>\
          <!--  <div class="table-col fR tR">\
            <div class="button toggle-row-enable ');  if redirections[i].enabled then   ngx.print('button-on');  else  ngx.print('button-off');  end  ngx.print('" id="tvSettings-btn-enable_');  ngx.print(i); ngx.print('" >\
            </div>\
          </div> -->\
        </div>\
        ');  end   ngx.print('\
        <div class="table-row" id="tvSettings-row-last">\
          <div class="table-col">\
            &nbsp;\
          </div>\
          <div class="table-col">\
            &nbsp;\
          </div>\
          <div class="table-col">\
            &nbsp;\
          </div>\
          <div class="table-col">\
            &nbsp;\
          </div>\
          <div class="table-col">\
            &nbsp;\
          </div>\
          <div class="table-col">\
            &nbsp;\
          </div>\
          <div class="table-col fR tR">\
            <input class="button button-add"  id="tvSettings-btn-add" type="button" data-toggle="modal" data-target="#addTVSettingsModal">\
          </div>\
        </div>\
      </div>\
    </div>\
\
    <h3><span>');  ngx.print(T"DHCP Server Parameters"); ngx.print('</span></h3>\
    <div class="h3-content table mobile-margin-bottom-lg">\
      <div class="vdf-row">\
        <div class="left">\
          <span>');  ngx.print(T"Address Pool Start IP"); ngx.print('</span>\
        </div>\
        <div class="right">\
          <input id="tv-txt-startIP1" class="max3 op40" type="text" value="');  ngx.print(startAddress[1]); ngx.print('">.<input id="tv-txt-startIP2" class="max3 op40" type="text" value="');  ngx.print(startAddress[2]); ngx.print('">.<input id="tv-txt-startIP3" class="max3 op40" type="text" value="');  ngx.print(startAddress[3]); ngx.print('">.<input id="tv-txt-startIP4" class="max3" type="text" value="');  ngx.print(startAddress[4]); ngx.print('"/>\
        </div>\
      </div>\
      <div class="vdf-row">\
        <div class="left">\
          <span>');  ngx.print(T"Address Pool End IP"); ngx.print('</span>\
        </div>\
        <div class="right">\
          <input id="tv-txt-endIP1" class="max3 op40" readonly="" value="');  ngx.print(endAddress[1]); ngx.print('" type="text"/>.<input id="tv-txt-endIP2" class="max3 op40" readonly="" value="');  ngx.print(endAddress[2]); ngx.print('" type="text"/>.<input id="tv-txt-endIP3" class="max3 op40" readonly="" value="');  ngx.print(endAddress[3]); ngx.print('" type="text"/>.<input id="tv-txt-endIP4" class="max3" value="');  ngx.print(endAddress[4]); ngx.print('" type="text"/>\
        </div>\
      </div>\
      <div class="vdf-row">\
        <div class="left">\
          <span>');  ngx.print(T"STB Option12"); ngx.print('</span>\
        </div>\
        <div class="right">\
          <input value="');  ngx.print((params.stbOption):match("^12,(.*)$")); ngx.print('" id="tv-txt-opt12" type="text">\
        </div>\
      </div>\
    </div>\
  </div>\
</form>\
<!-- End -->\
');  
local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("apply-cancel.lp")
  ngx.print('\
<!-- Edit Popup Modal -->\
<div class="modal fade" id="tv-popup-edit" data-backdrop="static" role="dialog">\
  <div class="modal-dialog">\
    <div class="modal-content change-password-content">\
      <div class="modal-header hidden-sm hidden-md hidden-lg">\
        <div class="mobile-cancel-popup button-cancel"></div>\
      </div>\
      <div class="modal-body no-padding">\
        <div class="mobile-cancel-popup button-cancel"></div>\
        <p class="title">');  ngx.print(T"Edit Redirections"); ngx.print('</p>\
        <div class="table-wrapper table">\
          <div class="vdf-row">\
            <div class="left">\
              <span>');  ngx.print(T"Service Name"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <input type="text" id="tvSettings-txt-editServiceName">\
            </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <span>');  ngx.print(T"Device"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <div id="top-info-mode" class="rel">\
                <select id="tvSettings-sel-editDevice">\
                  <option value="noDevice">');  ngx.print(T"No specific device"); ngx.print('</option>\
                  ');  ngx.print(concat(dropdownOptions, " ")); ngx.print('\
                </select>\
              </div>\
            </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <span>');  ngx.print(T"LAN IP"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <input class="max3" type="text" id="tvSettings-txt-editLanIp1" value = "">.\
              <input class="max3" type="text" id="tvSettings-txt-editLanIp2" value = "">.\
              <input class="max3" type="text" id="tvSettings-txt-editLanIp3" value = "">.\
              <input class="max3" type="text" id="tvSettings-txt-editLanIp4" value = "">\
            </div>\
          </div>\
          <div class="vdf-row hide">\
            <div class="left">\
              <span>');  ngx.print(T"Protocol"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <div id="top-info-mode" class="rel">\
                <select id="tvSettings-sel-editProtocol">\
                  <option value="tcp">TCP</option>\
                  <option value="udp">UDP</option>\
                  <option value="tcpudp" selected>TCP/UDP</option>\
                </select>\
              </div>\
            </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <span>');  ngx.print(T"Type"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <input class="radio radio-checked" name="portRadioEdit" value="0" id="tvSettings-radio-editSingle" type="radio">\
              <label for="tvSettings-radio-editSingle" style="margin:0 10px;"></label>\
              <span>');  ngx.print(T"Port"); ngx.print('</span>\
              <input class="radio radio-unchecked" name="portRadioEdit" value="1" id="tvSettings-radio-editRange" type="radio">\
              <label for="tvSettings-radio-editRange" style="margin:0 10px;"></label>\
              <span>');  ngx.print(T"Port Range"); ngx.print('</span>\
            </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <span>');  ngx.print(T"Public Port"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <input class="singleEditWAN max4" type="text" id="tv-txt-EditWANPort">\
              <div class="rangeEditWAN" style="display:none">\
                <input class="max4" type="text" id="tv-txt-EditWANPort1">-<input class="max4" type="text" id="tv-txt-EditWANPort2">\
              </div>\
            </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <span>');  ngx.print(T"LAN Port"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <input class="singleEditLAN max4" type="text" id="tv-txt-EditLANPort">\
              <div class="rangeEditLAN" style="display:none">\
                <input class="max4" type="text" id="tv-txt-EditLANPort1">-<input class="max4" type="text" id="tv-txt-EditLANPort2">\
              </div>\
            </div>\
          </div>\
        </div>\
        <div class="apply-cancel">\
          <input id="tvSettings-btn-editSave" class="button button-apply save " data-dismiss="modal" value="');  ngx.print(T" Save "); ngx.print('" type="button">\
          <input id="tvSettings-btn-editCancel" class="button button-cancel close-password-popup" data-dismiss="modal" value="');  ngx.print(T" Cancel "); ngx.print('" type="button">\
        </div>\
      </div>\
    </div>\
  </div>\
</div>\
<!-- ADD Popup Modal  -->\
<div class="modal fade" id="addTVSettingsModal" data-backdrop="static" role="dialog">\
  <div class="modal-dialog">\
    <!-- Modal content -->\
    <div class="modal-content change-password-content">\
      <div class="modal-header hidden-sm hidden-md hidden-lg">\
        <div class="mobile-cancel-popup button-cancel"></div>\
      </div>\
      <div class="modal-body no-padding">\
        <div class="mobile-cancel-popup button-cancel"></div>\
        <p class="title">\
          ');  ngx.print(T"Add Redirections"); ngx.print('\
        </p>\
        <div class="table-wrapper table">\
          <div class="vdf-row">\
            <div class="left">\
              <span>');  ngx.print(T"Service Name"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <input type="text" id="tvSettings-txt-addServiceName">\
            </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <span>');  ngx.print(T"Device"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <div id="top-info-mode" class="rel">\
                <select id="tvSettings-sel-addDevice">\
                  <option value="noDevice">');  ngx.print(T"No specific device"); ngx.print('</option>\
                  ');  ngx.print(concat(dropdownOptions, " ")); ngx.print('\
                </select>\
              </div>\
            </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <span>');  ngx.print(T"LAN IP"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <input class="max3" type="text">.<input class="max3" type="text">.<input class="max3" type="text">.<input class="max3" type="text">\
            </div>\
          </div>\
          <div class="vdf-row hide">\
            <div class="left">\
              <span>');  ngx.print(T"Protocol"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <div id="top-info-mode" class="rel">\
                <select id="tvSettings-sel-addProtocol">\
                  <option value="tcp">TCP</option>\
                  <option value="udp">UDP</option>\
                </select>\
              </div>\
            </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <span>');  ngx.print(T"Type"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <input class="radio radio-checked" value="0" name="portRadioAdd" checked="checked" id="tvSettings-radio-addSingle" type="radio">\
              <label for="tvSettings-radio-addSingle" style="margin:0 10px;"></label>\
              <span>');  ngx.print(T"Port"); ngx.print('</span>\
              <input class="radio radio-unchecked" value="1" name="portRadioAdd" id="tvSettings-radio-addrange" type="radio">\
              <label for="tvSettings-radio-addrange" style="margin:0 10px;"></label>\
              <span>');  ngx.print(T"Port Range"); ngx.print('</span>\
            </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <span>');  ngx.print(T"Public Port"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <input class="singleAddWAN max4" id="tv-txt-AddWANPort" type="text">\
              <div class="rangeAddWAN" style="display:none">\
                <input class="max4" id="tv-txt-AddWANPort1" type="text">-<input class="max4" id="tv-txt-AddWANPort2" type="text">\
              </div>\
            </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <span>');  ngx.print(T"LAN Port"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <input class="singleAddLAN max4" id="tv-txt-AddLANPort" type="text">\
              <div class="rangeAddLAN" style="display:none">\
                <input class="max4" id="tv-txt-AddLANPort1" type="text">-<input class="max4" id="tv-txt-AddLANPort1" type="text">\
              </div>\
            </div>\
          </div>\
        </div>\
        <div class="apply-cancel">\
          <input id="tvSettings-btn-addSave" class="button button-apply save" data-dismiss="modal" value="');  ngx.print(T"Save"); ngx.print('" type="button">\
          <input id="tvSettings-btn-addCancel" class="button button-cancel close-password-popup" data-dismiss="modal" value="');  ngx.print(T"Cancel"); ngx.print('" type="button">\
        </div>\
      </div>\
    </div>\
  </div>\
</div>\
\
<script src="js/global.js"/>\
<script>\
  var devices = [];\
  var editedRow = [];\
  var totalRows = 0;\
  ');  for k in pairs(devices) do   ngx.print('\
       devices.push("');  ngx.print(k); ngx.print('")\
  ');  end   ngx.print('\
</script>\
<script src="js/tv-settings.js"></script>\
'); 