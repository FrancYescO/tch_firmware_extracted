--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local contentHelper = require("web.content_helper")
local postHelper = require("web.post_helper")
local vodafone_helper = require("vodafone_helper")
local proxy = require("datamodel")
local json = require("dkjson")
local string = string
local format, match, untaint = string.format, string.match, string.untaint
local table, setmetatable = table, setmetatable
local ipairs, sort = ipairs, table.sort
local tonumber = tonumber
local untaint_mt = require("web.taint").untaint_mt
local setMetaTable = setmetatable
local ipv42num, calculateIPRange = postHelper.ipv42num, vodafone_helper.calculateIPRange
local validateIP = postHelper.validateStringIsIP

local serviceAllowOrDeny = {
  {"ACCEPT", T"Allow"},
  {"DROP", T"Deny"},
}

local serviceTrustedOrDeny = {
  {"ACCEPT", T"Trusted Only"},
  {"DROP", T"Deny"},
}

local validTarget = {
  ["ACCEPT"] = "ACCEPT",
  ["DROP"]   = "DROP",
}

-- Splits IP into octets
-- @function splitIP
-- @param #string IPv4
-- @return #table array of octets
local function splitIP(ip)
  if not ip then return nil end
  local tmp_ip = {}
  for octet in ip:gmatch("%d+") do
    tmp_ip[#tmp_ip+1] = octet
  end
  return tmp_ip
end

-- Validate Access Control Service data provided
-- @function validateAccessControlDetails
-- @param ACSData Access Control details for each service in GUI
-- @return #boolean true if everything is valid, nil if anything fails
local function validateAccessControlDetails(ACSData)
  for i = 1, #ACSData do
    if not validTarget[ACSData[i].LanTarget] then
      return nil
    end
  end
  return true
end

-- Validates Trusted networks data coming from GUI
-- @function validateTrustedNetworks
-- @param value Data from GUI
-- @return #boolean true if everything is valid, nil if anything fails validation
local function validateTrustedNetworks(value)
  for i,v in ipairs(value) do
    if not (v.index):match("^del") then
      local startIP, endIP = (v.IP_range):match("^(.+)%-(.+)$")
      if not (validateIP(startIP) and validateIP(endIP)) or ipv42num(startIP) > ipv42num(endIP) then
        return nil
      end
    end
  end
  return true
end

if ngx.req.get_method() == "POST" then
  ngx.header.content_type = "application/json"
  local postargs = ngx.req.get_post_args()
  local AccessControlTable = json.decode(untaint(postargs.AccessControlTable))
  local trustedNetworks = json.decode(untaint(postargs.trustedNetworks))
  local validateACS = validateAccessControlDetails(AccessControlTable)
  local validTrustedNetworks = validateTrustedNetworks(trustedNetworks)

  if validateACS and validTrustedNetworks then
    local setPath = {}
    local setData = {}
    local rows = tonumber(postargs.rows)
    for i = 1, rows do
      setPath["target" .. i] = format("uci.firewall.rule.%s.target", AccessControlTable[i].LanIndex)
      setData["target" .. i] = AccessControlTable[i].LanTarget
    end
    for i, v in ipairs(trustedNetworks) do
      setPath["ip" .. v.index] = format("uci.ipset.ipset_entry.%s.ip", v.index)
      setPath["ipset" .. v.index] = format("uci.ipset.ipset_entry.%s.ipset", v.index)
      setData["ip" .. v.index] = v.IP_range
      setData["ipset" .. v.index] = "trusted_network"
    end
    validateACS = contentHelper.setObject(setData, setPath)
  end
  if not (validateACS and validTrustedNetworks) then
    ngx.print('<input type="hidden" id="post_status" value="error">')
  else
    proxy.apply()
    ngx.print('<input type="hidden" id="post_status" value="success">')
  end
end

local getParamValues = {
  SSHStatus       = "InternetGatewayDevice.X_Management.Server.SSHServer.Enable",
  tr69Status    = "uci.cwmpd.cwmpd_config.state",
  tr69Mode      = "uci.cwmpd.cwmpd_config.interface",
}
contentHelper.getExactContent(getParamValues)

local firewallPath = contentHelper.convertResultToObject("uci.firewall.rule.", proxy.get("uci.firewall.rule."))

local onOffState = setMetaTable({
  ["1"] = T"On",
  [""]  = T"On",
  ["0"] = T"Offline",
}, untaint_mt)

local AccessControlServices = {}
local serviceName

if firewallPath then
  serviceName = setMetaTable({
    ["Allow-Ping-Vodafone-wan"] = "ICMP",
    ["Allow-SSH-Vodafone-wan"]  = "SSH",
    ["Allow-HTTP-Vodafone-wan"] = "HTTP",
    ["ICMP"] = "Allow-Ping-Vodafone-lan",
    ["SSH"]  = "Allow-SSH-Vodafone-lan",
    ["HTTP"] = "Allow-HTTP-Vodafone-lan",
  }, untaint_mt)
  for _, rule in ipairs(firewallPath) do
    if serviceName[rule.name] then
      AccessControlServices[#AccessControlServices+1] = {}
      AccessControlServices[#AccessControlServices].WanIndex = rule.paramindex
      AccessControlServices[#AccessControlServices].WanTarget = rule.target
      AccessControlServices[#AccessControlServices].name = serviceName[rule.name]
      local getLanpath = contentHelper.getMatchedContent("uci.firewall.rule.", {name = serviceName[serviceName[rule.name]]})
      if next(getLanpath) then
        AccessControlServices[#AccessControlServices].LanIndex = match(getLanpath[1].path,"(%d+)")
        AccessControlServices[#AccessControlServices].LanTarget = getLanpath[1].target
      end
    end
  end
end

AccessControlServices[#AccessControlServices+1] = {}
AccessControlServices[#AccessControlServices].WanTarget = getParamValues["tr69Mode"]
AccessControlServices[#AccessControlServices].name = "TR69"
AccessControlServices[#AccessControlServices].LanIndex = ""

-- The services will be listed in this order with reference to Playground
local servicesNameOrder = {
  ["ICMP"] = 1,
  ["SSH"]  = 2,
  ["HTTP"] = 3,
  ["TR69"] = 4,
}

sort(AccessControlServices, function(service1, service2)
  return servicesNameOrder[service1.name] < servicesNameOrder[service2.name]
end)

local trusted_networks_list = contentHelper.getMatchedContent("uci.ipset.ipset_entry.", {ipset="trusted_network"})

for i,v in ipairs(trusted_networks_list) do
  if (v.ip):find("/") then  -- IP is in IP/CIDR Format
    local startIP, endIP = calculateIPRange(v.ip)
    v.ip = startIP .. "-" .. endIP
  elseif not (v.ip):find("-") then -- only start IP
    v.ip = v.ip .. "-" .. v.ip
  end
end
sort(trusted_networks_list, function(a, b)
  return (a.path):match("%d+") < (b.path):match("%d+")
end)

-- Get the status of firewall rule (Allow-Ping-Vodafone-wan-Trusted)
local getPingWanPath = contentHelper.getMatchedContent("uci.firewall.rule.", {name = "Allow-Ping-Vodafone-wan-Trusted"})

-- Default is DROP(With reference to Openwrt specification for a firewall rule)
local getPingTarget  = "DROP"
if getPingWanPath[1].target then
  getPingTarget = getPingWanPath[1].target
end
  ngx.print('\
<script src="js/global.js"></script>\
<h1>');  ngx.print(T"Access Control Services"); ngx.print('</h1>\
<h2>&nbsp;</h2>\
<h3>');  ngx.print(T"Access Control Services"); ngx.print('</h3>\
<div class="h3-content access-control-services" id="access-control">\
  <table class="accesscontrol-table">\
    <thead>\
        <tr>\
          <th>&nbsp;</th>\
          <th><span>');  ngx.print(T"Service Status"); ngx.print('</span></th>\
          <th><span>');  ngx.print(T"WAN"); ngx.print('</span></th>\
          <th><span>');  ngx.print(T"LAN"); ngx.print('</span></th>\
        </tr>\
    </thead>\
      <tbody>\
        ');  for i, service in ipairs(AccessControlServices) do  ngx.print('\
          <tr>\
            <td><span>');  ngx.print(service.name); ngx.print('</span></td>\
            <td class="data-service-row">\
            ');  if service.name == "ICMP" and service.WanTarget == "ACCEPT" then  ngx.print('\
              <span style="display:block" class="status-service-indicator status-service-on"><span>');  ngx.print(T"On"); ngx.print('</span></span>\
            </td>\
              <td>\
                <select id="access-control-sel-wan-');  ngx.print(i); ngx.print('" class="acs-drop wan" disabled="true" style="display: none;">\
                  ');  for _, wanserviceStatus in ipairs(serviceTrustedOrDeny) do
                    ngx.print(format("<option value='%s'>%s</option>",wanserviceStatus[1], wanserviceStatus[2]))
                  end  ngx.print('\
                </select>\
              </td>\
            ');  else  ngx.print('\
              ');  if service.name == "SSH" then  ngx.print('\
                  <span style="display:block" class="status-service-indicator ');  if getParamValues.SSHStatus ~= "0" then  ngx.print(' status-service-on');  else  ngx.print('status-service-off');  end  ngx.print('"><span>');  ngx.print(onOffState[getParamValues.SSHStatus]); ngx.print('</span></span>\
              ');  elseif service.name == "TR69" then  ngx.print('\
                <span style="display:block" class="status-service-indicator ');  if getParamValues["tr69Status"] == "1" then  ngx.print(' status-service-on');  else  ngx.print('status-service-off');  end  ngx.print('"><span>');  ngx.print(onOffState[getParamValues["tr69Status"]]); ngx.print('</span></span>\
              ');  else  ngx.print('\
                <span style="display:block" class="status-service-indicator status-service-on"><span>');  ngx.print(T"On"); ngx.print('</span></span>\
              ');  end  ngx.print('\
            </td>\
            <td>\
              <select id="access-control-sel-wan-');  ngx.print(i); ngx.print('" class="acs-drop wan" disabled="true" style="display: none;">\
                ');  for _, wanserviceStatus in ipairs(serviceTrustedOrDeny) do
                  ngx.print(format("<option value='%s'>%s</option>",wanserviceStatus[1], wanserviceStatus[2]))
                  end  ngx.print('\
              </select>\
            </td>\
            ');  end  ngx.print('\
            <td>\
              <select id="access-control-sel-lan-');  ngx.print(i); ngx.print('" class="acs-drop lan" onchange = "ChangeStatus(this,\'');  ngx.print(service.LanIndex); ngx.print('\')" style="display: none;">\
                ');  for _, lanserviceStatus in ipairs(serviceAllowOrDeny) do
                  ngx.print(format("<option value='%s'>%s</option>",lanserviceStatus[1], lanserviceStatus[2]))
                end  ngx.print('\
              </select>\
            </td>\
            <input type="hidden" class="Service" value="');  ngx.print(service.name); ngx.print('"/>\
            <input type="hidden" class="WanTarget" value="');  ngx.print(service.WanTarget); ngx.print('"/>\
            ');  if serviceName[service.name] then  ngx.print('\
              <input type="hidden" class="LanIndex" value="');  ngx.print(service.LanIndex); ngx.print('"/>\
              <input type="hidden" class="LanTarget" id="LanTarget_');  ngx.print(service.LanIndex); ngx.print('" value="');  ngx.print(service.LanTarget); ngx.print('"/>\
            ');  end  ngx.print('\
          </tr>\
        ');  end  ngx.print('\
      </tbody>\
  </table>\
</div>\
<div id="acc-ctl-trusted-networks">\
<h3><span>');  ngx.print(T"Trusted Network"); ngx.print('</span></h3>\
<div class="h3-content trusted-networks">\
    <table id="accectrl-tbl-trustednw">\
        <thead>\
            <tr>\
                <th><span>');  ngx.print(T"IP Range - Start"); ngx.print('</span></th>\
                <th><span>');  ngx.print(T"IP Range - End"); ngx.print('</span></th>\
            </tr>\
        </thead>\
        <tbody>\
            <tr id="accectrl-info-empty" class="no-items-info" ');  if #trusted_networks_list > 0 then  ngx.print(' style="display:none" ');  end   ngx.print('>\
                <td colspan="2" style="text-align:center"><span>');  ngx.print(T"No ranges set"); ngx.print('</span></td>\
                <td>&nbsp;</td>\
            </tr>\
            ');  
            for i, v in ipairs(trusted_networks_list) do
              local start_ip, end_ip = (v.ip):match("^(.+)%-(.+)$")
              start_ip = splitIP(start_ip)
              end_ip = splitIP(end_ip)   ngx.print('\
              <tr>\
                <input type="hidden" class="index" value="');  ngx.print((v.path):match("(@[^%.]+)")); ngx.print('">\
                <td>\
                  <div class="right halfWidth no-important">\
                    <input class="max3 ip" value="');  ngx.print(start_ip[1]); ngx.print('" type="text"><span>.</span>\
                    <input class="max3 ip" value="');  ngx.print(start_ip[2]); ngx.print('" type="text"><span>.</span>\
                    <input class="max3 ip" value="');  ngx.print(start_ip[3]); ngx.print('" type="text"><span>.</span>\
                    <input class="max3 ip" value="');  ngx.print(start_ip[4]); ngx.print('" type="text">\
                  </div>\
                </td>\
                <td>\
                  <div class="right halfWidth no-important">\
                    <input class="max3 ip" value="');  ngx.print(end_ip[1]); ngx.print('" type="text"><span>.</span>\
                    <input class="max3 ip" value="');  ngx.print(end_ip[2]); ngx.print('" type="text"><span>.</span>\
                    <input class="max3 ip" value="');  ngx.print(end_ip[3]); ngx.print('" type="text"><span>.</span>\
                    <input class="max3 ip" value="');  ngx.print(end_ip[4]); ngx.print('" type="text">\
                  </div>\
                </td>\
            ');  end   ngx.print('\
        </tbody>\
    </table>\
</div>\
</div>\
');  
  local lp = require("web.lp")
  lp.setpath("/www/docroot/")
  lp.include("apply-cancel.lp")
  ngx.print('\
<script>\
  $(function() {\
    $(\'select\').chosen({\
        disable_search_threshold: 100000,\
        allow_single_deselect: true\
    });\
    if ($("#home-sel-mode").val() !== "35"){\
      $("#acc-ctl-trusted-networks").hide();\
    } else {\
      $("#acc-ctl-trusted-networks").hide();\
    }\
  });\
 function ChangeStatus(protocol_selected, row_index) {\
    if (Number(row_index) > 0)\
      $("#LanTarget_"+row_index).val((protocol_selected.selectedIndex == 0)?"ACCEPT":"DROP");\
  }\
  var elements = {\
    ipOctets: "#accectrl-tbl-trustednw .ip"\
  }\
  var validations = {\
    ipOctets: validateNumberRange(0, 255)\
  }\
  $(function() {\
    var getPingTarget = "');  ngx.print(getPingTarget); ngx.print('";\
    $(\'.accesscontrol-table tr:not(:first)\').each(function () {\
      var service = $(this).find(\'.Service\').val();\
      var WanTarget = $(this).find(\'.WanTarget\').val();\
      if (service == "TR69")\
      {\
        $(this).find("select.wan").attr("disabled", true);\
        if(WanTarget == "wan")\
          $(this).find("select.wan").val("ACCEPT").trigger("chosen:updated");\
        else\
          $(this).find("select.wan").val("DROP").trigger("chosen:updated");\
        $(this).find("select.lan").attr("disabled", true);\
        $(this).find("select.lan").val("DROP").trigger("chosen:updated");\
      }\
      else {\
        var LanTarget = $(this).find(\'.LanTarget\').val();\
        $(this).find("select.lan").val(LanTarget).trigger("chosen:updated");\
        if (service == "ICMP" && WanTarget != "ACCEPT")\
          $(this).find("select.wan").val(getPingTarget).trigger("chosen:updated");\
        else\
          $(this).find("select.wan").val(WanTarget).trigger("chosen:updated");\
      }\
    });\
\
    $("#global-apply").click(function() {\
      if (!validateElements(elements, validations)) return false;\
      var totalRows = 0;\
      var target = "/modals/access-control.lp";\
      var ACSrouteObj = [];\
      $(".accesscontrol-table tr:not(:first)").each(function() {\
        var service  = $.trim($(this).find(".Service").val());\
        if (service != "TR69")\
        {\
          totalRows++;\
          ACSrouteObj.push({\
            LanIndex  : $.trim($(this).find(".LanIndex").val()),\
            LanTarget : $.trim($(this).find(".LanTarget").val()),\
          });\
        }\
      });\
\
      var trustedNetworks = [];\
      $("#accectrl-tbl-trustednw tbody tr:not(:first)").each(function(row) {\
        trustedNetworks[row] = {\
          index : $(this).find(".index").val(),\
          IP_range : []\
        }\
        $(this).find("td").each(function(i) {\
          var tmp_IP = [];\
          $(this).find("input").each(function() {\
            tmp_IP.push($(this).val());\
          });\
          trustedNetworks[row].IP_range.push(tmp_IP.join("."));\
        });\
        trustedNetworks[row].IP_range = trustedNetworks[row].IP_range.join("-");\
      });\
\
      var postObj = [];\
      postObj.push({ name : "AccessControlTable", value : JSON.stringify(ACSrouteObj) });\
      postObj.push({ name : "trustedNetworks", value : JSON.stringify(trustedNetworks) });\
      postObj.push({ name : "CSRFtoken", value : "');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('" });\
      postObj.push({ name : "rows", value : totalRows });\
      postHandler(target, postObj);\
     });\
    $("#global-cancel").click(function() {\
      $("#content").load("/modals/access-control.lp");\
    });\
  });\
</script>\
'); 