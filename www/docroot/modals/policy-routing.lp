--pretranslated: do not change this file
 
--Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local vdf_helper = require("vodafone_helper")
local string = string
local format, gmatch = string.format, string.gmatch
local lower, upper = string.lower, string.upper
local bit = require("bit")
local json = require("dkjson")
local validateIP = post_helper.validateStringIsIP
local validateString = post_helper.validateNonEmptyString
local validateNetmask = post_helper.validateIPv4Netmask
local getOrValidation = post_helper.getOrValidation
local getValInEnum = post_helper.getValidateInEnumSelect
local getValidateNumberInRange = post_helper.getValidateNumberInRange
local netMaskToMask = post_helper.cidr2mask
local ipairs, tonumber = ipairs, tonumber
local table = table
local booleanValid = post_helper.validateBoolean
local numToIPv4 = vdf_helper.numToIPv4
local untaint_mt = require("web.taint").untaint_mt
local setMetaTable = setmetatable
local getPath = "uci.firewall.redirect."

-- The typeListTable contains key-value pairs with index of Type dropdown list(as key) with the corresponding text(as value)
-- Used index to refer the type of a Policy route as the texts will change on translation
local typeListTable = setMetaTable({
  [0]  = T"Source Interface",
  [1]  = T"Source IP",
  [2]  = T"Destination IP",
  [3]  = T"Protocol Type",
  [4]  = T"DSCP",
}, untaint_mt)

---Get IPv4 address and its subnetmask. Based on the Netmask prefix, the subnetmask is calculated
-- @function getIPv4AddressAndSubnet
-- @param ip IPv4 address of the form IPv4/Netmask prefix(eg:192.168.0.12/24, 10.10.20.33 etc)
-- @return IPv4 address(eg: 192.168.0.12) and subnet mask(eg:255.255.255.0)
local function getIPv4AddressAndSubnet(Ipaddress)
  local getIPaddress = {}
  local subnetMask
  for ipAddress in gmatch(Ipaddress, '([^/]+)') do

    --getIPaddress[1]: IPv4 address, getIPaddress[2]: netmask prefix
    getIPaddress[#getIPaddress+1] = ipAddress
  end
  if getIPaddress[2] then
    subnetMask = netMaskToMask(tonumber(getIPaddress[2]))
  else
    subnetMask = "255.255.255.255"
  end
  return subnetMask, getIPaddress[1]
end

local zoneParameters = content_helper.convertResultToObject("uci.firewall.zone.", proxy.get("uci.firewall.zone."))
local routePath = content_helper.convertResultToObject("uci.firewall.redirect.", proxy.get("uci.firewall.redirect."))
local interfaces = {}
local routeTable = {}
for _, rule in ipairs(zoneParameters) do
  interfaces[#interfaces+1] = {}
  if tonumber(rule.wan) == 1 then
    interfaces[#interfaces].wanName = upper(rule.name)
  else
    interfaces[#interfaces].lanName = upper(rule.name)
  end
end

for _, route in ipairs(routePath) do
  if route.dest == "wan" then
    routeTable[#routeTable+1] = {}
    if route.src ~= "" then
      routeTable[#routeTable].type = typeListTable[0]
      routeTable[#routeTable].selectedType = 0
      routeTable[#routeTable].fwdcondition = upper(route.src)
    elseif route.src_ip ~= "" then
      routeTable[#routeTable].type = typeListTable[1]
      routeTable[#routeTable].selectedType = 1
      routeTable[#routeTable].netmask, routeTable[#routeTable].fwdcondition = getIPv4AddressAndSubnet(route.src_ip)
    elseif route.dest_ip ~= "" then
      routeTable[#routeTable].type = typeListTable[2]
      routeTable[#routeTable].selectedType = 2
      routeTable[#routeTable].netmask, routeTable[#routeTable].fwdcondition = getIPv4AddressAndSubnet(route.dest_ip)
    elseif route["proto.@1.value"] ~= "" then
      routeTable[#routeTable].type = typeListTable[3]
      routeTable[#routeTable].selectedType = 3
      routeTable[#routeTable].fwdcondition = upper(route["proto.@1.value"])
    elseif route.mark ~= "" then
      routeTable[#routeTable].type = typeListTable[4]
      routeTable[#routeTable].selectedType = 4
      routeTable[#routeTable].fwdcondition = route.mark
    end
    routeTable[#routeTable].index   = route.paramindex
    routeTable[#routeTable].enabled = (route.enabled == "" or route.enabled == "1") and "1" or "0"
    routeTable[#routeTable].wanIntf = upper(route.dest)
  end
end

-- Sorting the routeTable table based on index
  table.sort(routeTable, function(route1,route2)
    return tonumber(route1.index) < tonumber(route2.index)
  end)


local typeOfRoute = {
  {"0", T"Source Interface"},
  {"1", T"Source IP"},
  {"2", T"Destination IP"},
  {"3", T"Protocol Type"},
  {"4", T"DSCP"},
}

local protocolList = {
  {"TCP", "TCP"},
  {"UDP", "UDP"},
  {"ICMP", "ICMP"},
  {"HTTP", "HTTP"},
  {"SIP", "SIP"},
}

-- According to Openwrt IPv4 route specification,255.255.255.255 is assumed which makes target a host address
local SubnetMask = {{"255.255.255.255"}}

---Gets IPv4 address and Netmask prefix. Based on the Netmask prefix, the IPv4 address is calculated
-- @function getIPv4AddressAndMaskPrefix
-- @param ip IPv4 address
-- @param ip netmask subnet mask (eg:255.255.255.0)
-- @return calculated IPv4 address and subnet prefix(eg: 32, 24 etc)
local function getIPv4AddressAndMaskPrefix(ip, netmask)
  netmask = netmask == "" and "255.255.255.255" or netmask
  if netmask ~= "255.255.255.255" then
    if validateIP(ip) and validateIP(netmask) then
      local maskprefix = 0
      for num in gmatch(netmask, "(%d+).?") do
        num = tonumber(num)
        local shifts = 0
        if num > 0 then
          while bit.band(num, 1) == 0 do
            shifts = shifts + 1
            num = bit.rshift(num,1)
          end
          maskprefix = maskprefix + 8 - shifts
        else
          break
        end
      end
      if maskprefix then
        local subnet = netMaskToMask(tonumber(maskprefix))
        ip = bit.band(post_helper.ipv42num(ip),post_helper.ipv42num(subnet))
        ip = numToIPv4(ip)
      end
      netmask = maskprefix
    end
  else
    netmask = 32  -- returns 32 as netmask prefix if subnet mask is 255.255.255.255
  end
  return ip, netmask
end

-- Validate Policy route data provided
-- Also checks if duplicate rules are created
-- @function validatePolicyRouteDetails
-- @param policyRoutes All Policy Route details coming from each rows in GUI
-- @return #boolean  - true if everything is valid, nil if anything fails
local function validatePolicyRouteDetails(policyRoutes)
  local policyRouteType = policyRoutes.typeofOperation
  local policyRouteData = {
    fwdCondition   = policyRoutes.fwdcondition,
    dest           = policyRoutes.waninterface,
    state          = policyRoutes.status,
  }
  local policyRouteValid = {
    fwdCondition   = validateString,
    dest           = validateString,
    state          = booleanValid,
  }
  if policyRouteType == "1" or policyRouteType == "2" then
    policyRouteValid["fwdCondition"] = validateIP
    policyRouteData["netmask"] = policyRoutes.netmask
    policyRouteValid["netmask"] = getOrValidation(validateNetmask, getValInEnum(SubnetMask))
  elseif policyRouteType == "4" then
    policyRouteValid["fwdCondition"] = getValidateNumberInRange(0, 63)
  end
  local valid = content_helper.validateObject(policyRouteData, policyRouteValid)
  if not valid then
    return nil
  end
  local fwdCondition2 = policyRoutes.fwdcondition
  local dest2 = policyRoutes.waninterface
  local type2 = tonumber(policyRoutes.typeofOperation)
  local status2 = policyRoutes.status

  for i = 1, #routeTable do
    local fwdCondition1 = routeTable[i].fwdcondition
    local dest1 = routeTable[i].wanIntf
    local type1 = routeTable[i].selectedType
    local status1 = routeTable[i].enabled

    --Check for duplicate policy routes
    if fwdCondition1 == fwdCondition2 and dest1 == dest2 and type1 == type2 and status1 == status2 then
      return nil
    end
  end
  return true
end

local function initializeData(data)
 local wanIntfname = lower(data.waninterface)
 local fwdcondition = data.fwdcondition
 local policyRouteType = data.typeofOperation
 local paramMap = {
    state   = "enabled",
    dest    = "dest",
    target  = "target",
    src_dip = "src_dip",
  }
  local policyRouteTableData = {
    state   = data.status,
    dest    = wanIntfname,
    target  = "SNAT",
    src_dip = "0.0.0.0",
  }
  if policyRouteType == "1" or policyRouteType == "2" then
    local ip, NetmaskPrefix = getIPv4AddressAndMaskPrefix(data.fwdcondition, data.netmask)
    if NetmaskPrefix ~= 32 then
      fwdcondition = format("%s/%d", ip, NetmaskPrefix)
    end
  end
  if policyRouteType == "0" then
    paramMap["src"] = "src"
    policyRouteTableData["src"] = lower(fwdcondition)
  elseif policyRouteType == "1" then
    paramMap["srcip"] = "src_ip"
    policyRouteTableData["srcip"] = fwdcondition
  elseif policyRouteType == "2" then
    paramMap["destip"] = "dest_ip"
    policyRouteTableData["destip"] = fwdcondition
  elseif policyRouteType == "3" then
    paramMap["proto.@1.value"] = "proto.@1.value"
    policyRouteTableData["proto.@1.value"] = lower(fwdcondition)
  elseif policyRouteType == "4" then
    paramMap["mark"] = "mark"
    policyRouteTableData["mark"] = fwdcondition
  end
  return paramMap, policyRouteTableData
end

local function updateRoutes(data, paramMap, policyRouteData)
  local setParamEmpty = {}
  local routeIndex = data.index
  setParamEmpty[format("%s%d.src", getPath, routeIndex)] = ""
  setParamEmpty[format("%s%d.src_ip", getPath, routeIndex)] = ""
  setParamEmpty[format("%s%d.dest_ip", getPath, routeIndex)] = ""
  setParamEmpty[format("%s%d.proto.@1.value", getPath, routeIndex)] = ""
  setParamEmpty[format("%s%d.mark", getPath, routeIndex)] = ""
  proxy.set(setParamEmpty)
  local validRoute = content_helper.setObject(policyRouteData, paramMap, format("%s%d.", getPath, routeIndex))
  if not validRoute then
    return nil
  end
  return true
end

local function addRoutes(data, paramMap, policyRouteData)
  local paramIndex = content_helper.addNewObject(format("%s", getPath), policyRouteData, paramMap)
  if policyRouteData["proto.@1.value"] then
    proxy.set({[format("%s%d.proto.@1.value", getPath, paramIndex)] = policyRouteData["proto.@1.value"]})
  else
    proxy.add(format("%s%d.proto.", getPath, paramIndex))
  end
end

-- Function to handle all post action.
local function handlePostData(addList, updateList, deleteList)

  -- validation for updating route entries
  for _, data in ipairs(updateList) do
    if not validatePolicyRouteDetails(data) then
       return nil
    end
  end

  -- validation for adding route entries
  for _, data in ipairs(addList) do
    if not validatePolicyRouteDetails(data) then
       return nil
    end
  end

   -- Delete route entry
  for _,j in ipairs(deleteList) do
    proxy.del(format(format("%s%d.", getPath, j.index)))
  end

   --Update route entry
  for _, data in ipairs(updateList) do
    local table1, table2 = initializeData(data)
    if not updateRoutes(data, table1, table2) then
      return nil
    end
  end

  --Add route entry
  for _, data in ipairs(addList) do
    local table1, table2 = initializeData(data)
    addRoutes(data, table1, table2)
  end
  proxy.apply()
  return true
end

if ngx.req.get_method() == "POST" then
  ngx.header.content_type = "application/json"
  local postargs = ngx.req.get_post_args()
  local tableList = json.decode(string.untaint(postargs.policyRouteTable), 1, nil)
  local deleteList = tableList.DELETE
  local addList = tableList.ADD
  local updateList = tableList.UPDATE
  local postResult = handlePostData(addList, updateList, deleteList)
  if not postResult then
    ngx.print('{ "status":"error" }')
  else
    ngx.print('{ "status":"success" }')
  end
  ngx.exit(ngx.HTTP_OK)
end
  ngx.print('\
<script src="js/global.js"></script>\
<script>\
  $(function() {\
    $(\'select\').chosen({\
        disable_search_threshold: 100000,\
        allow_single_deselect: true\
    });\
  });\
</script>\
<h1>');  ngx.print(T"Policy Routing"); ngx.print('</h1>\
<h2>&nbsp;</h2>\
<div class="h3-content h3-content-mobile">\
<form id="policyroute-form" class="form-horizontal" method="post" action="modals/policy-routing.lp">\
<input type="hidden" value="');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('" id="CSRFtoken">\
    <div class="table-responsive">\
        <div class="table policy-routing policy-routing-table no-margin-bottom" id ="policy-routing-table">\
            <div class="table-row table-row-head">\
                <div class="table-col">\
                    <span>');  ngx.print(T"Type"); ngx.print('</span> </div>\
                <div class="table-col">\
                    <span>');  ngx.print(T"Forward Condition"); ngx.print('</span> </div>\
                <div class="table-col">\
                    <span>');  ngx.print(T"WAN Interface"); ngx.print('</span> </div>\
                <div class="table-col">\
                    &nbsp;\
                </div>\
                <div class="table-col">\
                    &nbsp;\
                </div>\
                <div class="table-col">\
                    &nbsp;\
                </div>\
            </div>\
            ');  for i=1, #routeTable do
              local policyRouteclass = (routeTable[i].enabled == "1" or routeTable[i].enabled == "") and "routeRow" or "routeRow op40"
                ngx.print('\
            <div class="table-row">\
              <div class="table-col ');  ngx.print(policyRouteclass); ngx.print(' type" value="');  ngx.print(routeTable[i].selectedType); ngx.print('">');  ngx.print(routeTable[i].type); ngx.print('</div>\
              <div class="table-col ');  ngx.print(policyRouteclass); ngx.print(' fwdcondition">');  ngx.print(routeTable[i].fwdcondition); ngx.print('</div>\
              <div class="table-col ');  ngx.print(policyRouteclass); ngx.print(' wanintf">');  ngx.print(routeTable[i].wanIntf); ngx.print('</div>\
              <div class="table-col ');  ngx.print(policyRouteclass); ngx.print('"><input class="button button-edit editbutton" type="button" data-toggle="modal" data-target="#policyrouting-edit-modal"></div>\
              <div class="table-col ');  ngx.print(policyRouteclass); ngx.print('"><input class="button button-delete deletebutton" type="button"></div>\
              <div class="table-col fR tR">\
                <div id="policy-routing-btn-onoff-');  ngx.print(i); ngx.print('" class="button toggle-row-enable ');  if routeTable[i].enabled == "1" or routeTable[i].enabled == "" then  ngx.print(' button-on ');  else  ngx.print(' button-off ');  end  ngx.print(' pull-right">\
                  <input type="hidden" class="RouteIndex" value="');  ngx.print(routeTable[i].index); ngx.print('"/>\
                  ');  if routeTable[i].selectedType == 1 or routeTable[i].selectedType == 2 then  ngx.print('\
                    <input type="hidden" class="subnet" value="');  ngx.print(routeTable[i].netmask); ngx.print('"/>\
                  ');  else  ngx.print('\
                    <input type="hidden" class="subnet" value=""/>\
                  ');  end  ngx.print('\
                  <input type="hidden" class="status" value="');  ngx.print(routeTable[i].enabled and 1 or 0); ngx.print('"/>\
                </div>\
              </div>\
            </div>\
            ');  end  ngx.print('\
            <div class="table-row" id="policyRoute-row-last">\
              ');  for i=1, 5 do  ngx.print('\
                <div class="table-col">\
                    &nbsp;\
                </div>\
              ');  end  ngx.print('\
              <div class="table-col fR tR">\
                  <input id="policy-routing-btn-add-row" class="button button-add" type="button" data-toggle="modal" data-target="#policyrouting-add-modal">\
              </div>\
            </div>\
        </div>\
    </div>\
  </form>\
</div>\
');  
  local lp = require("web.lp")
  lp.setpath("/www/docroot/")
  lp.include("apply-cancel.lp")
  ngx.print('\
\
<!--Edit Popup Modal -->\
<div class="modal fade" id="policyrouting-edit-modal" role="dialog" data-backdrop="static">\
    <div class="modal-dialog">\
        Modal content\
        <div class="modal-content change-password-content">\
            <div class="modal-header hidden-sm hidden-md hidden-lg">\
                <button type="button" class="close" data-dismiss="modal">&times;</button>\
            </div>\
            <div class="modal-body no-padding">\
                <form class="form-horizontal">\
                    <div class="form-group">\
                        <div class="col-sm-12">\
                            <p class="title tL">\
                                ');  ngx.print(T"Edit Policy Route"); ngx.print('\
                            </p>\
                        </div>\
                    </div>\
                    <div class="vdf-table">\
                        <div class="vdf-row">\
                            <div class="left">\
                                <span>');  ngx.print(T"Type"); ngx.print('</span> </div>\
			    <div class="right">\
                            <div id="top-info-mode" class="rel">\
                                <select class="type-select" id="edit-type-select" style="display: none;" onchange = "changeType(\'Editing\')">\
                                  ');  for _,typeName in ipairs(typeOfRoute) do
                                    ngx.print(format("<option value='%s'>%s</option>", typeName[1], typeName[2]))
                                  end  ngx.print('\
                                </select>\
                            </div>\
			  </div>\
                        </div>\
                        <div class="vdf-row source-interface changable-row" id="editSourceInterface">\
                            <div class="left">\
                                <span>');  ngx.print(T"Source Interface"); ngx.print('</span> </div>\
                            <div class="right">\
			      <div id="top-info-mode" class="rel">\
                                <select id="edit-select-lan" style="display: none;">\
                                    ');  for _,v in ipairs(interfaces) do
                                      if v.lanName then
                                        ngx.print(format("<option value='%s'>%s</option>", v.lanName, v.lanName))
                                      end
                                    end  ngx.print('\
                                </select>\
                            </div>\
			  </div>\
                        </div>\
                        <div class="vdf-row source-ip changable-row" style="display:none;" id="editsourceIP">\
                            <div class="left">\
                                <span>');  ngx.print(T"Source IP"); ngx.print('</span> </div>\
                            <div class="right">\
                                <input id="policy-route-txt-editSrcIP" type="text">\
                            </div>\
                        </div>\
                        <div class="vdf-row destination-ip changable-row" style="display:none;" id="editdestinationIP">\
                            <div class="left">\
                                <span>');  ngx.print(T"Destination IP"); ngx.print('</span> </div>\
                            <div class="right">\
                                <input id="policy-route-txt-editDestIP" type="text">\
                            </div>\
                        </div>\
                        <div class="vdf-row source-ip changable-row" style="display:none;" id="editmskdest">\
                            <div class="left">\
                                <span>');  ngx.print(T"Network Mask"); ngx.print('</span> </div>\
                            <div class="right">\
                                <input id="policy-route-txt-editNetmaskDest" type="text">\
                            </div>\
                        </div>\
                        <div class="vdf-row destination-ip changable-row editNetmask" id="editmsksource">\
                            <div class="left">\
                                <span>');  ngx.print(T"Network Mask"); ngx.print('</span> </div>\
                            <div class="right">\
                                <input id="policy-route-txt-editNetmaskSource" type="text">\
                            </div>\
                        </div>\
                        <div class="vdf-row protocol-type changable-row" style="display:none;" id="editProtocol">\
                            <div class="left">\
                                <span>');  ngx.print(T"Protocol Type"); ngx.print('</span> </div>\
                            <div class="right">\
							<div id="top-info-mode" class="rel">\
                                <select id="edit-select-protocol" style="display: none;">\
                                  ');  for _, protocol in ipairs(protocolList) do
                                    ngx.print(format("<option value='%s'>%s</option>", protocol[1], protocol[2]))
                                  end  ngx.print('\
                                </select>\
                            </div>\
			  </div>\
                        </div>\
                        <div class="vdf-row dscp changable-row" style="display:none;" id="editcp">\
                            <div class="left">\
                                <span>');  ngx.print(T"DSCP"); ngx.print('</span> </div>\
                            <div class="right">\
                                <input id="policy-route-txt-editDSCP" type="text">\
                            </div>\
                        </div>\
                        <div class="vdf-row">\
                            <div class="left">\
                                <span>');  ngx.print(T"WAN Interface"); ngx.print('</span> </div>\
                            <div class="right">\
							<div id="top-info-mode" class="rel">\
                                <select id="edit-select-wan" style="display: none;">\
                                    ');  for _,v in ipairs(interfaces) do
                                        if v.wanName and v.wanName == "WAN" then
                                          ngx.print(format("<option value='%s'>%s</option>", v.wanName, v.wanName))
                                        end
                                    end  ngx.print('\
                                </select>\
                            </div>\
			  </div>\
                        </div>\
                    </div>\
                    <div class="form-group">\
                        <div class="col-sm-12">\
                            <div class="modal-footer">\
                                <input class="button button-apply save mob-button-width" data-dismiss="modal" value="');  ngx.print(T"Save"); ngx.print('" type="button" id="policy-routing-btn-editSave-row" />\
                                <input class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" data-dismiss="modal" value="');  ngx.print(T"Cancel"); ngx.print('" type="button" id="policy-routing-btn-editCancel-row" />\
                            </div>\
                        </div>\
                    </div>\
                </form>\
            </div>\
        </div>\
    </div>\
</div>\
\
<!-- ADD Popup Modal-->\
<div class="modal fade" id="policyrouting-add-modal" role="dialog" data-backdrop="static">\
    <div class="modal-dialog">\
        <!-- Modal content-->\
        <div class="modal-content change-password-content">\
            <div class="modal-header hidden-sm hidden-md hidden-lg">\
                <button type="button" class="close" data-dismiss="modal">&times;</button>\
            </div>\
            <div class="modal-body no-padding">\
                <form class="form-horizontal">\
                    <div class="form-group">\
                        <div class="col-sm-12">\
                            <p class="title tL">\
                              ');  ngx.print(T"Add Policy Route"); ngx.print('\
                            </p>\
                        </div>\
                    </div>\
                    <div class="vdf-table">\
                        <div class="vdf-row">\
                            <div class="left">\
                                <span>');  ngx.print(T"Type"); ngx.print('</span> </div>\
                            <div class="right">\
			      <div id="top-info-mode" class="rel">\
                                <select id="type-select" class="type-select SelectAdd" style="display: none;" onchange ="changeType(\'Adding\')">\
                                  ');  for _,typeName in ipairs(typeOfRoute) do
                                    ngx.print(format("<option value='%s'>%s</option>", typeName[1], typeName[2]))
                                  end  ngx.print('\
                                </select>\
                            </div>\
			  </div>\
                        </div>\
                        <div class="vdf-row source-interface changable-row" id="SourceInterface">\
                            <div class="left">\
                                <span>');  ngx.print(T"Source Interface"); ngx.print('</span> </div>\
                            <div class="right">\
			      <div id="top-info-mode" class="rel">\
                                <select id="select-lan" class="SelectAdd" style="display: none;">\
                                    ');  for _,v in ipairs(interfaces) do
                                      if v.lanName then
                                        ngx.print(format("<option value='%s'>%s</option>", v.lanName, v.lanName))
                                      end
                                    end  ngx.print('\
                                </select>\
                            </div>\
			  </div>\
                        </div>\
                        <div class="vdf-row source-ip changable-row" style="display:none;" id="sourceIP">\
                            <div class="left">\
                                <span>');  ngx.print(T"Source IP"); ngx.print('</span> </div>\
                            <div class="right">\
                                <input id="policy-routing-txt-addSrcIP" type="text">\
                            </div>\
                        </div>\
                        <div class="vdf-row destination-ip changable-row" style="display:none;" id="destinationIP">\
                            <div class="left">\
                                <span>');  ngx.print(T"Destination IP"); ngx.print('</span> </div>\
                            <div class="right">\
                                <input id="policy-routing-txt-addDestIP" type="text">\
                            </div>\
                        </div>\
                        <div class="vdf-row source-ip changable-row" style="display:none;" id="addmskdest">\
                            <div class="left">\
                                <span>');  ngx.print(T"Network Mask"); ngx.print('</span> </div>\
                            <div class="right">\
                                <input id="policy-routing-txt-addNetmaskDest" type="text">\
                            </div>\
                        </div>\
                        <div class="vdf-row destination-ip changable-row" style="display:none;" id="addmsksource">\
                            <div class="left">\
                                <span>');  ngx.print(T"Network Mask"); ngx.print('</span> </div>\
                            <div class="right">\
                                <input id="policy-routing-txt-addNetmaskSource" type="text">\
                            </div>\
                        </div>\
                        <div class="vdf-row protocol-type changable-row" style="display:none;" id="Protocol">\
                            <div class="left">\
                                <span>');  ngx.print(T"Protocol Type"); ngx.print('</span> </div>\
                            <div class="right">\
			      <div id="top-info-mode" class="rel">\
                                <select id="select-proto" class="SelectAdd">\
                                  ');  for _, protocol in ipairs(protocolList) do
                                    ngx.print(format("<option value='%s'>%s</option>", protocol[1], protocol[2]))
                                  end  ngx.print('\
                                </select>\
                            </div>\
			  </div>\
                        </div>\
                        <div class="vdf-row dscp changable-row" style="display:none;" id="DiffServ">\
                            <div class="left">\
                                <span>');  ngx.print(T"DSCP"); ngx.print('</span> </div>\
                            <div class="right">\
                                <input id="policy-routing-txt-addDSCP" type="text">\
                            </div>\
                        </div>\
                        <div class="vdf-row">\
                            <div class="left">\
                                <span>');  ngx.print(T"WAN Interface"); ngx.print('</span> </div>\
                            <div class="right">\
			      <div id="top-info-mode" class="rel">\
                                <select id="select-wan" class="SelectAdd">\
                                    ');  for _,v in ipairs(interfaces) do
                                      if v.wanName and v.wanName == "WAN" then
                                        ngx.print(format("<option value='%s'>%s</option>", v.wanName, v.wanName))
                                      end
                                    end  ngx.print('\
                                </select>\
                            </div>\
			  </div>\
                        </div>\
                    </div>\
                    <div class="form-group">\
                        <div class="col-sm-12">\
                            <div class="modal-footer">\
                                <input class="button button-apply save mob-button-width" value="');  ngx.print(T"Save"); ngx.print('" type="button" id="policyrouting-btn-addSave-row" data-dismiss="modal"/>\
                                <input class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" data-dismiss="modal" value="');  ngx.print(T"Cancel"); ngx.print('" type="button" data-dismiss="modal"/>\
                            </div>\
                        </div>\
                    </div>\
                </form>\
            </div>\
        </div>\
    </div>\
</div>\
<script src="/js/policy-routing.js"></script>\
'); 