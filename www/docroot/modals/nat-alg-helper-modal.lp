--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local string, ngx = string, ngx
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local uinetwork = require("web.uinetwork_helper")
local hosts_ac, hosts_ac_v6  = uinetwork.getAutocompleteHostsList()
local pairs = pairs
local ipairs = ipairs
local format = string.format
local session = ngx.ctx.session
local role = session:getrole()
local untaint = string.untaint
local dmzEnable = post_helper.isFeatureEnabled("wanServicesDMZAndNAT", role)
local wanIntf = post_helper.getActiveInterface()
local variant_helper = require("variant_helper")
local variantHelper = post_helper.getVariant(variant_helper, "WANServices", "Settings")
local getAndValidation = post_helper.getAndValidation
local showIPv6DMZ = post_helper.getVariantValue(variantHelper, "showIPv6DMZ")
local validateStringIPv6 = post_helper.validateStringIsIP(6)

local ipv6_status = {
  status = "rpc.network.interface.@wan6.ip6addr"
}
content_helper.getExactContent(ipv6_status)

local pinholerules
local ipv6_dmz_param_index
if showIPv6DMZ and ipv6_status.status ~= "" then
  pinholerules = content_helper.convertResultToObject("rpc.network.firewall.pinholerule.", proxy.get("rpc.network.firewall.pinholerule."))
  for _, v in ipairs(pinholerules) do
    if (v.name == "DMZ IPv6 Rule") then
      ipv6_dmz_param_index = v.paramindex
    end
  end
end

local function isIpv6DestinationsSame(destination_1, destination_2)
  for dest_1 in destination_1:gmatch("([^%s]+)") do
    for dest_2 in destination_2:gmatch("([^%s]+)") do
      if dest_1 == dest_2 then
        return true
      end
    end
  end
  return false
end

-- DMZ / DynDNS switches Only one handleQuery in a page
local qry_params = {
  DMZ_enable = "rpc.network.firewall.dmz.enable",
  DMZ_destinationip = "rpc.network.firewall.dmz.redirect.dest_ip"
}
if showIPv6DMZ and ipv6_status.status ~= "" then
  qry_params.DMZ_enable_ipv6 = "rpc.network.firewall.pinholerule." .. ipv6_dmz_param_index  .. ".enabled"
  qry_params.DMZ_destinationip_ipv6 = "rpc.network.firewall.pinholerule." .. ipv6_dmz_param_index  .. ".dest_ip"
end

-- Shortcuts to validation helpers to make lines shorter
local validateBoolean = post_helper.validateBoolean
local validatePort = post_helper.validateStringIsPort
local validateDMZ = post_helper.validateDMZ

local function validateDMZIPv6(value, object, key)
  local old_DMZ_destinationip_ipv6 = proxy.get("rpc.network.firewall.pinholerule." .. ipv6_dmz_param_index  .. ".dest_ip")
  old_DMZ_destinationip_ipv6 = old_DMZ_destinationip_ipv6 and old_DMZ_destinationip_ipv6[1] and old_DMZ_destinationip_ipv6[1].value or ""
  local old_DMZ_enable_ipv6 = proxy.get("rpc.network.firewall.pinholerule." .. ipv6_dmz_param_index  .. ".enabled")
  old_DMZ_enable_ipv6 = old_DMZ_enable_ipv6 and old_DMZ_enable_ipv6[1] and old_DMZ_enable_ipv6[1].value or ""
  local is_DMZ_enable_ipv6_not_changed = old_DMZ_enable_ipv6 == object.DMZ_enable_ipv6
  local disable_empty_ipv6 = object.DMZ_enable_ipv6 == "0" and object.DMZ_destinationip_ipv6 == ""
  if is_DMZ_enable_ipv6_not_changed and old_DMZ_destinationip_ipv6 == object.DMZ_destinationip_ipv6 or disable_empty_ipv6 then
    return true
  end
  local success, errormsg = validateStringIPv6(value, object, key)
  if not success then
    return nil, errormsg
  end
  return true
end

local qry_valid = {
  DMZ_enable = validateBoolean,
  DMZ_destinationip = validateDMZ
}
if showIPv6DMZ and ipv6_status.status ~= "" then
  qry_valid.DMZ_enable_ipv6 = validateBoolean
  qry_valid.DMZ_destinationip_ipv6 = validateDMZIPv6
end

local wol = proxy.getPN("uci.wol.proxy.@wan2lan.", true)
if wol then
  qry_params.WOL_enable = "uci.wol.proxy.@wan2lan.enable"
  qry_params.WOL_src_port = "uci.wol.proxy.@wan2lan.src_port"
  qry_params.WOL_dest_port = "uci.wol.proxy.@wan2lan.dest_port"
  qry_valid.WOL_enable = validateBoolean
  qry_valid.WOL_src_port = validatePort
  qry_valid.WOL_dest_port = validatePort
end

local qry_data, qry_helpmsg = post_helper.handleQuery(qry_params, qry_valid)
local new_host = {}
local count = 0
for k,v in pairs(hosts_ac) do
  if string.match(v,qry_data.DMZ_destinationip) then
    count = 1
    new_host[#new_host+1] = {v,k}
  else
    new_host[#new_host+1] = {v,k}
  end
end
new_host[#new_host + 1] = {"custom", T"Custom"}

local new_host_v6 = {}
local count_v6 = 0

local multi_ipv6 = {}
local ipv6_match = 0
if showIPv6DMZ and ipv6_status.status ~= "" then
  for ip in qry_data.DMZ_destinationip_ipv6:gmatch("[^%s,]+") do
    multi_ipv6[#multi_ipv6+1] = ip
  end
  for k, v in pairs(hosts_ac_v6) do
    if #multi_ipv6 > 1 then
      for _, ip in pairs(multi_ipv6) do
        if string.match(v, ip) then
          ipv6_match = 1
        else
          ipv6_match = 0
          break
        end
      end
      if ipv6_match == 1 then
        count_v6 = 1
        new_host_v6[#new_host_v6+1] = {v, k}
      else
        new_host_v6[#new_host_v6+1] = {v, k}
      end
    else
      if string.match(v, qry_data.DMZ_destinationip_ipv6) then
        count_v6 = 1
        new_host_v6[#new_host_v6+1] = {v, k}
      else
        new_host_v6[#new_host_v6+1] = {v, k}
      end
    end
  end
  new_host_v6[#new_host_v6 + 1] = {"custom", T"Custom"}
end

-- Firewall forwarding rules
local hlp_columns = {
  {
    header = T"Enable",
    name = "enable",
    param = "enable",
    type = "switch",
    default = "1",
    attr = { switch = { ["data-placement"] = "left" }}
  },
  {
    header = T"Name",
    name = "name",
    param = "name",
    type = "text",
    readonly = true,
    attr = { input = { class="span2" } }
  },
  {
    header = T"Dest port",
    name = "port",
    param = "port",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" }}
  },
  {
    header = T"Protocol",
    name = "proto",
    param = "proto",
    type = "text",
    readonly = true,
    attr = { input = { class="span1" }}
  }
}

local hlp_attributes = {}
local hlp_defaultObject = {}

-- Removing duplicate entries having interface as loopback
local function hlp_filter(object)
  if object.intf == "loopback" then
    return nil
  end
  return true
end

local hlp_options = {
  tableid = "helper",
  basepath = "uci.firewall_helpers.helper.",
  canAdd = false,
  canDelete = false,
  canEdit = false,
  objectName  = post_helper.getRandomKey(),
  addNamedObject = true
}

local ipv6wan2lan_path = "uci.firewall.forwarding.@ipv6wan2lan."
local function disable_ipv6_wan2lan()
  if proxy.del(ipv6wan2lan_path) then
    proxy.apply()
  end
end

local hlp_data, hlp_helpmsg = post_helper.handleTableQuery(hlp_columns, hlp_options, hlp_filter, hlp_defaultObject)

if ngx.req.get_method() == "POST" then
  ngx.header.content_type = "application/json"
  local postArgs = ngx.req.get_post_args()
  if postArgs.dmzChanged == "true" then
    local json = require("dkjson")
    local jsonReq = json.decode(untaint(postArgs.natHelperData))
    local firewallHelper = proxy.get("uci.firewall_helpers.helper.")
    local natHelpers = {}
    local helperState, dmPath
    firewallHelper = content_helper.convertResultToObject("uci.firewall_helpers.helper.", firewallHelper)
    for _, interface in ipairs (firewallHelper) do
      if (jsonReq[tostring(untaint(interface.name))] or jsonReq[tostring(untaint(string.lower(interface.name)))]) then
        helperState = jsonReq[tostring(untaint(interface.name))] or jsonReq[tostring(untaint(string.lower(interface.name)))]
        dmPath = "uci.firewall_helpers.helper."..interface.paramindex..".enable"
        natHelpers[string.untaint(dmPath)] = helperState
      end
    end

  local _, errmsg = proxy.set(natHelpers)
  if errmsg == nil then
    ngx.header.content_type = "text/html"
    proxy.apply()
    message_helper.pushMessage(T"Changes saved successfully", "success")
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
  else
    ngx.print('{ "status":"error" }')
  end
  ngx.exit(ngx.HTTP_OK)
  end
  if showIPv6DMZ and ipv6_status.status ~= "" then
    if postArgs.DMZ_enable_ipv6 == "1" then
      for _, options in ipairs (pinholerules) do
        if isIpv6DestinationsSame(options.dest_ip, postArgs.DMZ_destinationip_ipv6) and options.paramindex ~= ipv6_dmz_param_index then
          proxy.set("rpc.network.firewall.pinholerule." .. options.paramindex .. ".enabled", "0")
          proxy.apply()
        end
      end
    end
  end
end

--Look for the enable set to nothing and set to default "1"
for index, helperValue in pairs (hlp_data) do
  if helperValue[1] == "" then
    hlp_data[index][1] = "1"
  end
  hlp_data[index][2] = string.upper(helperValue[2])
end

--NAT Configuration
local firewall_zone_path = content_helper.convertResultToObject("uci.firewall.zone.", proxy.get("uci.firewall.zone."))
local zoneIndex = ""
for _, firewall_zone in ipairs(firewall_zone_path) do
  if (firewall_zone.name == "wan") then
    zoneIndex = firewall_zone.paramindex
    break
  end
end

local function setForwardRules(forwdnum)
  local forwdIndex = forwdnum
  if forwdIndex == "" then
    forwdIndex = proxy.add("uci.firewall.forwarding.")
  end
  local firewall_value = {[format("uci.firewall.forwarding.%s.src", forwdIndex)] = wanIntf,
                          [format("uci.firewall.forwarding.%s.dest", forwdIndex)] = "lan",
                          [format("uci.firewall.forwarding.%s.name", forwdIndex)] = "for_w2l"}
  proxy.set(firewall_value)
  return forwdIndex
end

--function is used to validate NAT status
--If validation is successful values will be set in uci.firewall.forwarding. path
--If validation failed error message will be returned
local function validateAndUpdateNat(value, object, key)
  local valid, msg = post_helper.validateBoolean(value, object, key)
  local forwdnum = ""
  local setTable = {}
  local masqValue
  local masq = proxy.get("uci.firewall.zone."..zoneIndex..".masq")
  if masq then
    masqValue = masq[1].value
  end
  if valid and zoneIndex ~= "" and value ~= masqValue then
    setTable[format("uci.firewall.zone.%s.conntrack", zoneIndex)] = "1"
    if value == "1" then
      forwdnum = setForwardRules(forwdnum)
      setTable[format("uci.firewall.forwarding.%s.enabled", forwdnum)] = "0"
    else
      forwdnum = setForwardRules(forwdnum)
      setTable[format("uci.firewall.forwarding.%s.enabled", forwdnum)] = "1"
    end
    if proxy.set(setTable) then
      proxy.apply()
    end
  end
  return valid, msg
end

-- Configurable data
local natParams = {
  uci_wan_masq = "uci.firewall.zone."..zoneIndex..".masq"
}

local natValid = {
  uci_wan_masq = validateAndUpdateNat
}

local nat_data, _ = post_helper.handleQuery(natParams, natValid)

local DMZ_destinationmac = {
  DMZ_ipv4 = "rpc.network.firewall.dmz.redirect.dest_mac"
}
if showIPv6DMZ and ipv6_status.status ~= "" then
  DMZ_destinationmac.DMZ_ipv6 = "rpc.network.firewall.pinholerule." .. ipv6_dmz_param_index  .. ".dest_mac"
end

content_helper.getExactContent(DMZ_destinationmac)
if DMZ_destinationmac.DMZ_ipv6 == ""  and qry_data.DMZ_destinationip_ipv6 == "unknown" then
  count_v6 = 1
end
ngx.print(ui_helper.createHeader(T"WAN services", true, true))
  ngx.print('\
\
<div class="modal-body update">\
  <form class="form-horizontal" id="myform">\
  ');  
    ngx.print(ui_helper.createMessages(message_helper.popMessages()))
    lp.setpath("/www/snippets/")
    lp.include("tabs-wanservices.lp")
    ngx.print('\
  ');  if dmzEnable then   ngx.print('\
  <fieldset>\
      ');  if showIPv6DMZ then   ngx.print('\
        <legend>');  ngx.print( T"DMZ IPv4" ); ngx.print('</legend>\
      ');  else   ngx.print('\
        <legend>');  ngx.print( T"DMZ" ); ngx.print('</legend>\
      ');  end   ngx.print('\
      ');  
        local html = {}
        local dmzipattr = { autocomplete = hosts_ac}
        html[#html + 1] = ui_helper.createSwitch(T"Enabled", "DMZ_enable", qry_data.DMZ_enable, nil, qry_helpmsg.DMZ_enable)
        if count ~= 0 then
          html[#html + 1] = ui_helper.createInputSelect(T"Destination IP", "DMZ_destinationip", new_host, qry_data.DMZ_destinationip, nil, qry_helpmsg.DMZ_destinationip)
        else
          html[#html + 1] = ui_helper.createInputText(T"Destination IP", "DMZ_destinationip", qry_data.DMZ_destinationip,dmzipattr, qry_helpmsg.DMZ_destinationip)
        end
        html[#html + 1] = ui_helper.createLabel(T"Destination MAC", DMZ_destinationmac.DMZ_ipv4)
        ngx.print(html)
        ngx.print('\
  </fieldset>\
    ');  if showIPv6DMZ then   ngx.print('\
    <fieldset>\
      <legend>');  ngx.print( T"DMZ IPv6" ); ngx.print('</legend>\
        ');  
          local html = {}
          local dmzipattr_v6 = { autocomplete = hosts_ac_v6}
          local switch_alert = {
          alert = {
            id = "dmz_switch_alert",
            class = "hide"
            }
          }
          local ipv6_dmz_enable_attr = {
            controls = {
              style= "pointer-events: none; opacity: 0.5;"
            }
          }
          if ipv6_status.status ~= "" then
            html[#html + 1] = ui_helper.createSwitch(T"Enabled", "DMZ_enable_ipv6", qry_data.DMZ_enable_ipv6, nil, qry_helpmsg.DMZ_enable_ipv6)
            if count_v6 ~= 0 then
              html[#html + 1] = ui_helper.createInputSelect(T"Destination IP", "DMZ_destinationip_ipv6", new_host_v6, qry_data.DMZ_destinationip_ipv6, nil, qry_helpmsg.DMZ_destinationip_ipv6)
            else
              html[#html + 1] = ui_helper.createInputText(T"Destination IP", "DMZ_destinationip_ipv6", qry_data.DMZ_destinationip_ipv6,dmzipattr_v6, qry_helpmsg.DMZ_destinationip_ipv6)
            end
            html[#html + 1] = ui_helper.createLabel(T"Destination MAC", DMZ_destinationmac.DMZ_ipv6)
            html[#html + 1] = ui_helper.createAlertBlock(T"Warning! All Port forewarding rules for this device will be disabled</br></br>If you want to continue, press Save. If not, press Cancel!", switch_alert)
          else
            html[#html + 1] = ui_helper.createSwitch(T"Enabled", "DMZ_enable_ipv6", "0", ipv6_dmz_enable_attr)
            html[#html + 1] = ui_helper.createAlertBlock(T"Warning! IPv6 address is currently not available")
          end
          ngx.print(html)
          ngx.print('\
    </fieldset>\
    ');  end   ngx.print('\
  ');  end   ngx.print('\
  ');  if wol then  ngx.print('\
    <fieldset>\
      <legend>');  ngx.print( T"Wake on LAN over the Internet" ); ngx.print('</legend>\
        ');  
          ngx.print(
            ui_helper.createSwitch(T"Enabled", "WOL_enable", qry_data["WOL_enable"], nil, qry_helpmsg["WOL_enable"]),
            ui_helper.createInputText(T"WAN port", "WOL_src_port", qry_data["WOL_src_port"], nil, qry_helpmsg["WOL_src_port"]),
            ui_helper.createInputText(T"LAN port", "WOL_dest_port", qry_data["WOL_dest_port"], nil, qry_helpmsg["WOL_dest_port"]))
          ngx.print('\
    </fieldset>\
  ');  end  ngx.print('\
  ');  if dmzEnable and zoneIndex ~= "" then   ngx.print('\
    <fieldset>\
      <legend>');  ngx.print( T"NAT Configuration" ); ngx.print('</legend>\
        ');  
          ngx.print(ui_helper.createSwitch(T"NAT", "uci_wan_masq", nat_data["uci_wan_masq"]))
          ngx.print('\
    </fieldset>\
  ');  end   ngx.print('\
  <fieldset>\
    <legend>');  ngx.print( T"NAT Helpers (ALG's)" ); ngx.print('</legend>\
      ');  
        ngx.print(
          ui_helper.createTable(hlp_columns, hlp_data, hlp_options, hlp_attributes, hlp_helpmsg))
        ngx.print('\
  </fieldset>\
  </form>\
</div>\
\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
<script>\
var waitMsg = \'');  ngx.print( T"Please wait..." ); ngx.print('\';\
var dest_ip_old = "');  ngx.print(qry_data.DMZ_destinationip); ngx.print('";\
');  if showIPv6DMZ then   ngx.print('\
  var dest_ip_old_v6 = "');  ngx.print(qry_data.DMZ_destinationip_ipv6); ngx.print('";\
');  end   ngx.print('\
var showIPv6DMZ = ');  ngx.print(showIPv6DMZ); ngx.print('\
var dmzEnable = ');  ngx.print(dmzEnable); ngx.print(';\
</script>\
<script src="/js/nat-alg-helper-modal.js"></script>\
'); 