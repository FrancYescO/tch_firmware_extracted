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
local hosts_ac = uinetwork.getAutocompleteHostsList()
local pairs = pairs
local ipairs = ipairs
local format = string.format
local session = ngx.ctx.session
local role = session:getrole()
local untaint = string.untaint
local dmzEnable = post_helper.isFeatureEnabled("wanServicesDMZAndNAT", role)
local wanIntf = post_helper.getActiveInterface()

-- DMZ / DynDNS switches Only one handleQuery in a page
local qry_params = {
  DMZ_enable = "rpc.network.firewall.dmz.enable",
  DMZ_destinationip = "rpc.network.firewall.dmz.redirect.dest_ip"
}

-- Shortcuts to validation helpers to make lines shorter
local validateBoolean = post_helper.validateBoolean
local validatePort = post_helper.validateStringIsPort
local validateDMZ = post_helper.validateDMZ

local qry_valid = {
  DMZ_enable = validateBoolean,
  DMZ_destinationip = validateDMZ
}

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
  "rpc.network.firewall.dmz.redirect.dest_mac"
}
content_helper.getExactContent(DMZ_destinationmac)

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
    <legend>');  ngx.print( T"DMZ" ); ngx.print('</legend>\
      ');  
        local html = {}
        local dmzipattr = { autocomplete = hosts_ac}
        html[#html + 1] = ui_helper.createSwitch(T"Enabled", "DMZ_enable", qry_data.DMZ_enable, nil, qry_helpmsg.DMZ_enable)
        if count ~= 0 then
          html[#html + 1] = ui_helper.createInputSelect(T"Destination IP", "DMZ_destinationip", new_host, qry_data.DMZ_destinationip, nil, qry_helpmsg.DMZ_destinationip)
        else
          html[#html + 1] = ui_helper.createInputText(T"Destination IP", "DMZ_destinationip", qry_data.DMZ_destinationip,dmzipattr, qry_helpmsg.DMZ_destinationip)
        end
        html[#html + 1] = ui_helper.createLabel(T"Destination MAC", DMZ_destinationmac[1])
        ngx.print(html)
        ngx.print('\
  </fieldset>\
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
var dmzEnable = ');  ngx.print(dmzEnable); ngx.print(';\
</script>\
<script src="/js/nat-alg-helper-modal.js"></script>\
'); 