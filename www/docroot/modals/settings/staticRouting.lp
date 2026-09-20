--pretranslated: do not change this file
 
--Enable localization
gettext.textdomain('webui-core')

local bit = require("bit")
local json = require("dkjson")
local proxy = require("datamodel")
local vdf_helper = require("vodafone_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local numToIPv4 = post_helper.num2ipv4
local netMaskToMask = post_helper.cidr2mask
local validateIP = post_helper.validateStringIsIP
local reservedIP = post_helper.reservedIPValidation
local getOrValidation = post_helper.getOrValidation
local getAndValidation = post_helper.getAndValidation
local validateNetmask = post_helper.validateIPv4Netmask
local getValInEnum = post_helper.getValidateInEnumSelect
local validateQTNIP = post_helper.validateQTN
local ngx, string, next, table = ngx, string, next, table
local match, format, find = string.match, string.format, string.find
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local ipairs, tonumber = ipairs, tonumber
local metricMaxRange = 2147483647

local lanDetails = {
  gwIP = "uci.network.interface.@lan.ipaddr",
}
content_helper.getExactContent(lanDetails)

local interfaceList = {
  {"Select an Option"},
  {"wan"},
  {"wwan"},
  {"ull_voice"},
  {"ull_video"},
  {"vdsl_ull_voice"},
  {"vdsl_ull_video"},
  {"FTTH_TIVO"}
}
if vdf_helper.getVariant() == "NZ" then
  interfaceList = {
    {"Select an Option"},
    {"wan"},
    {"wwan"},
  }
end

-- According to Openwrt IPv4 route specification,255.255.255.255 is assumed which makes target a host address
local SubnetMask = {{"255.255.255.255"}}

-- Validate if destination IP is Gateway IP address
-- @function isGatewayIP
-- @param ip
-- #boolean  - true if valid, nil if validation fails
local function isGatewayIP(ip)
  if ip ~= lanDetails["gwIP"] then
    return true
  end
end

-- Validate metric
-- @function validateMetric
-- @param metric
-- #boolean  - true if valid, nil if validation fails
local function validateMetric(metric)
  if metric then
    if not find(metric,"[+-]") then
      metric = tonumber(metric)
      if metric and metric >= 0 and metric <= metricMaxRange then
        return true
      end
    end
  end
end

-- Validate netmask prefix
-- @function validateNetmaskPrefix
-- @param prefix subnet mask prefix(eg:24,32,0)
-- @param subnet mask
-- #boolean  - true if valid, nil if validation fails
local function validateNetmaskPrefix(prefix,subnet)
  prefix = tonumber(prefix)
  if prefix and prefix >= 0 and prefix <= 32 and subnet == netMaskToMask(prefix) then
    return true
  end
end

---Split IP address and Netmask prefix.Based on the Netmask prefix, the IP address is calculated
-- @function SplitIPandMask
-- @param ip IP address of the form IP/Netmask prefix(eg:192.168.1.22/24)
-- @return calculated IP address and subnet prefix
local function SplitIPandMask(ip, netmask)
  local getIPaddress = {}
  for ipAddress in string.gmatch(ip, '([^/]+)') do
    --getIPaddress[1]: IPv4 address, getIPaddress[2]: netmask prefix
    getIPaddress[#getIPaddress+1] = ipAddress
  end
  if validateIP(getIPaddress[1]) then
    if not getIPaddress[2] then
      local mask=0
      for num in string.gmatch(netmask, "(%d+).?") do
        num = tonumber(num)
        local shifts = 0
        if num > 0 then
          while bit.band(num, 1) == 0 do
            shifts = shifts + 1
            num = bit.rshift(num,1)
          end
          mask = mask + 8 - shifts
        else
          break
        end
      end
      getIPaddress[2] = mask
    end
    if getIPaddress[2] and getIPaddress[2] ~= "0" then --Check if IP contains subnet prefix(eg:/24,/0,/32)
      local subnet = netMaskToMask(tonumber(getIPaddress[2]))
      ip = bit.band(post_helper.ipv42num(getIPaddress[1]),post_helper.ipv42num(subnet))
      ip = numToIPv4(ip)
    else
      if getIPaddress[1] == "0.0.0.0" then
        getIPaddress[2] = "0"
      end
      ip = getIPaddress[1]
    end
    return ip, getIPaddress[2]
  end
end

-- Validate Static route data provided
-- Also checks if duplicate rules are created
-- @function validateStaticRouteDetails
-- @param StaticRoutes All StaticRoute details coming from each rows in GUI
-- @return #boolean  - true if everything is valid, nil if anything fails
local function validateStaticRouteDetails(StaticRoutes)
  for i = 1, #StaticRoutes do
    local targetIP, targetNetmaskPrefix
    if StaticRoutes[i].index and not match(StaticRoutes[i].index, "del.+") then
      targetIP, targetNetmaskPrefix = SplitIPandMask(StaticRoutes[i].target, StaticRoutes[i].netmask)
      targetIP = targetIP or ""
      local staticRouteData = {
        target    = targetIP,
        mask      = StaticRoutes[i].netmask,
        gwip      = StaticRoutes[i].gwip,
        interface = StaticRoutes[i].interface,
        metric    = StaticRoutes[i].metric
      }
      local staticRouteValid = {
        target    = getAndValidation(getAndValidation(validateQTNIP, validateIP), getAndValidation(isGatewayIP, reservedIP)),
        mask      = getOrValidation(validateNetmask, getValInEnum(SubnetMask)),
        gwip      = getAndValidation(getAndValidation(reservedIP, validateQTNIP), validateIP),
        interface = post_helper.getOptionalValidation(getValInEnum(interfaceList)),
        metric    = validateMetric
      }
      local valid = content_helper.validateObject(staticRouteData, staticRouteValid) and validateNetmaskPrefix(targetNetmaskPrefix, StaticRoutes[i].netmask)
      if not valid then
        return nil
      end
      StaticRoutes[i].target = targetIP
    end
  end
  for i = 1, #StaticRoutes do
    if StaticRoutes[i].index and not match(StaticRoutes[i].index, "del.+") then
      local target1 = StaticRoutes[i].target
      local netmask1 = StaticRoutes[i].netmask
      local gwip1 = StaticRoutes[i].gwip
      local interface1 = StaticRoutes[i].interface
      local metric1    = StaticRoutes[i].metric
      for j = i+1, #StaticRoutes do
        if not match(StaticRoutes[j].index, "del.+") then
          local target2 = StaticRoutes[j].target
          local netmask2 = StaticRoutes[j].netmask
          local gwip2 = StaticRoutes[j].gwip
          local interface2 = StaticRoutes[j].interface
          local metric2    = StaticRoutes[j].metric

          --Check for duplicate static routes
          if target1 == target2 and netmask1 == netmask2 and gwip1 == gwip2 and interface1 == interface2 and metric1 == metric2 then
            return nil
          end
        end
      end
    end
  end
  return true
end

if ngx.req.get_method() == "POST" then
  ngx.header.content_type = "application/json"
  local postargs = ngx.req.get_post_args()
  local staticRouteTable = json.decode(string.untaint(postargs.staticRouteTable))
  local rows = tonumber(postargs.rows)
  local validRoute = validateStaticRouteDetails(staticRouteTable)
  local uniqueKey = post_helper.getRandomKey()
  if validRoute then
    local paramMap = {
      dest      = "target",
      mask      = "netmask",
      gwip      = "gateway",
      interface = "interface",
      metric    = "metric",
    }
    for i = 1, rows do
      local routeIndex = staticRouteTable[i].index
      local routeEnabled = staticRouteTable[i].enabled
      local index

      -- If index contains del followed by number, Delete the entry having that index
      index = match(routeIndex, "del(@%S+)")
      if index then
        if routeEnabled then
          proxy.del(format("uci.network.route.%s.", index))
        else
          proxy.del(format("uci.network.disabled_route.%s.", index))
        end
      end
      local staticRouteTableData = {
        dest      = staticRouteTable[i].target,
        mask      = staticRouteTable[i].netmask,
        gwip      = staticRouteTable[i].gwip,
        interface = staticRouteTable[i].interface == "" and "SET_BY_SCRIPT" or staticRouteTable[i].interface,
        metric    = staticRouteTable[i].metric,
      }
      local edited = tonumber(staticRouteTable[i].EditRow)

      --Add Static route rules
      --If index is new add a new static route
      if routeIndex == "new" then
        if edited == 1 then
          content_helper.addNewObject("uci.network.route.@.", staticRouteTableData, paramMap, nil, uniqueKey)
        elseif edited == 0 then
          content_helper.addNewObject("uci.network.disabled_route.@.", staticRouteTableData, paramMap, nil, uniqueKey)
        end
      end

      --Editing Static route table
      --If index is a number, then the entry having this index needs to be updated
      if find(routeIndex, "^(@%S+)$") then
        local setKey = {}
        if not routeEnabled and edited == 1 then
          index = content_helper.addNewObject("uci.network.route.@.", staticRouteTableData, paramMap, nil, uniqueKey)
          setKey[format("uci.network.route.%s._key", index)] = proxy.get(format("uci.network.disabled_route.%s._key", routeIndex))[1].value
          proxy.set(setKey)
          proxy.del(format("uci.network.disabled_route.%s.", routeIndex))
        else
          if routeEnabled and edited == 0 then
            index = content_helper.addNewObject("uci.network.disabled_route.@.", staticRouteTableData, paramMap, nil, uniqueKey)
            setKey[format("uci.network.disabled_route.%s._key", index)] = proxy.get(format("uci.network.route.%s._key", routeIndex))[1].value
            proxy.set(setKey)
            proxy.del(format("uci.network.route.%s.", routeIndex))
          elseif routeEnabled and edited == 1 then
            validRoute = content_helper.setObject(staticRouteTableData, paramMap, format("uci.network.route.%s.", routeIndex))
          end
        end
      end
      if not validRoute then
        break
      end
    end
  end

  if not validRoute then
    ngx.print('{ "status":"error" }')
  else
    ngx.print('{ "status":"success" }')
    proxy.apply()
  end
  ngx.exit(ngx.HTTP_OK)
end

local staticRoutePath = content_helper.convertResultToObject("uci.network.route.",proxy.get("uci.network.route."))
local staticRouteDetails = {}
if next(staticRoutePath) then
  for _,value in ipairs(staticRoutePath) do
    staticRouteDetails[#staticRouteDetails+1] = {}
    staticRouteDetails[#staticRouteDetails].target = value.target
    staticRouteDetails[#staticRouteDetails].netmask = value.netmask
    if value.gateway == "" then
      staticRouteDetails[#staticRouteDetails].gateway = "0.0.0.0" -- Default Gateway IP address
    else
      staticRouteDetails[#staticRouteDetails].gateway = value.gateway
    end
    staticRouteDetails[#staticRouteDetails].interface = value.interface
    if value.metric == "" then
      staticRouteDetails[#staticRouteDetails].metric = "0" -- Default metric is zero if not set
    else
      staticRouteDetails[#staticRouteDetails].metric = value.metric
    end
    staticRouteDetails[#staticRouteDetails].index = value.paramindex
    staticRouteDetails[#staticRouteDetails].enabled = true
  end

  -- Sorting the staticRouteDetails table based on index
  table.sort(staticRouteDetails, function(route1,route2)
    return route1.index < route2.index
  end)
end

local staticDisabledRoutePath = content_helper.convertResultToObject("uci.network.disabled_route.",proxy.get("uci.network.disabled_route."))
local disabledRoutesData = {}

if next(staticDisabledRoutePath) then
  for _,value in ipairs(staticDisabledRoutePath) do
    disabledRoutesData[#disabledRoutesData+1] = {}
    disabledRoutesData[#disabledRoutesData].target = value.target
    disabledRoutesData[#disabledRoutesData].netmask = value.netmask
    if value.gateway == "" then
      disabledRoutesData[#disabledRoutesData].gateway = "0.0.0.0" -- Default Gateway IP address
    else
      disabledRoutesData[#disabledRoutesData].gateway = value.gateway
    end
    disabledRoutesData[#disabledRoutesData].interface = value.interface
    if value.metric == "" then
      disabledRoutesData[#disabledRoutesData].metric = "0" -- Default metric is zero if not set
    else
      disabledRoutesData[#disabledRoutesData].metric = value.metric
    end
    disabledRoutesData[#disabledRoutesData].index    = value.paramindex
    disabledRoutesData[#disabledRoutesData].enabled = false
  end
  table.sort(disabledRoutesData, function(route1,route2)
  return (route1.index) < (route2.index)
  end)
end
for _,v in ipairs(disabledRoutesData) do
  table.insert(staticRouteDetails, v)
end

local ftthRoutes = {}
local getCustomRoutes = {
  ftthRoutes = "uci.network.interface.@FTTH_TIVO.customroutes"
}
content_helper.getExactContent(getCustomRoutes)

if next(getCustomRoutes) then
  for ip in getCustomRoutes["ftthRoutes"]:gmatch("%S+") do
    ftthRoutes[#ftthRoutes+1] = {}
    local targetIP, prefix = SplitIPandMask(ip)
    local getSubnet = netMaskToMask(prefix)
    ftthRoutes[#ftthRoutes].target = targetIP
    ftthRoutes[#ftthRoutes].subnet = getSubnet
    ftthRoutes[#ftthRoutes].interface = "FTTH_TIVO"
  end
end
  ngx.print('\
\
<script src="js/global-min.js"></script><script>\
  $(function () {\
    $(\'select\').chosen({\
      disable_search_threshold: 100000,\
      allow_single_deselect: true\
    });\
  });\
</script>\
\
<div class="row no-margin-right">\
  <div class="col-xs-12 col-md-12 col-sm-12">\
    <h1>');  ngx.print(T"Static Routing"); ngx.print('</h1>\
    <h2>&nbsp;</h2>\
  </div>\
</div>\
<div class="h3-content">\
  <form id="staticroute-form" class="form-horizontal" method="post" action="modals/settings/staticRouting.lp">\
    <div class = "table-responsive">\
      <div class="table static-routing  static-routing-table"  id ="static-routing-table" style="font-size: 14px;">\
        <div class="table-row table-row-head">\
          <div class="table-col">\
            <span>');  ngx.print(T"Destination"); ngx.print('</span>\
          </div>\
          <div class="table-col">\
            <span>');  ngx.print(T"Mask"); ngx.print('</span>\
          </div>\
          <div class="table-col">\
            <span>');  ngx.print(T"Gateway"); ngx.print('</span>\
          </div>\
          <div class="table-col">\
            <span>');  ngx.print(T"Interface"); ngx.print('</span>\
          </div>\
          <div class="table-col">\
            <span>');  ngx.print(T"Metric"); ngx.print('</span>\
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
        </div>\
        ');  for k=1,#ftthRoutes do   ngx.print('\
        <div class="table-row ffthRoutes">\
          <div class="table-col">\
            ');  ngx.print(ftthRoutes[k].target); ngx.print('\
          </div>\
          <div class="table-col">\
            ');  ngx.print(ftthRoutes[k].subnet); ngx.print('\
          </div>\
          <div class="table-col">\
          </div>\
          <div class="table-col">\
            ');  ngx.print(ftthRoutes[k].interface); ngx.print('\
          </div>\
          <div class="table-col">\
          </div>\
        </div>\
        ');  end   ngx.print('\
        ');  for i=1,#staticRouteDetails do   ngx.print('\
        ');  local StaticRowclass = staticRouteDetails[i].enabled  and "staticrow" or "staticrow op40"   ngx.print('\
        <div class="table-row">\
          <div class="table-col ');  ngx.print(StaticRowclass); ngx.print(' target">\
            ');  ngx.print(staticRouteDetails[i].target); ngx.print('\
          </div>\
          <div class="table-col ');  ngx.print(StaticRowclass); ngx.print(' netmask">\
            ');  ngx.print(staticRouteDetails[i].netmask); ngx.print('\
          </div>\
          <div class="table-col ');  ngx.print(StaticRowclass); ngx.print(' gateway">\
            ');  ngx.print(staticRouteDetails[i].gateway); ngx.print('\
          </div>\
          <div class="table-col ');  ngx.print(StaticRowclass); ngx.print(' interface">\
            ');  ngx.print(staticRouteDetails[i].interface == "SET_BY_SCRIPT" and "" or staticRouteDetails[i].interface); ngx.print('\
          </div>\
          <div class="table-col ');  ngx.print(StaticRowclass); ngx.print(' metric">\
            ');  ngx.print(staticRouteDetails[i].metric); ngx.print('\
          </div>\
          <div class="table-col ');  ngx.print(StaticRowclass); ngx.print('">\
            <input class="button button-edit editbutton" id = "static-routing-btn-edit_');  ngx.print(i); ngx.print('" type="button" data-toggle="modal" data-target="#editAccessControlModal">\
          </div>\
          <div class="table-col ');  ngx.print(StaticRowclass); ngx.print('">\
            <input class="button button-delete deletebutton" id = "static-routing-btn-delete_');  ngx.print(i); ngx.print('" type="button">\
          </div>\
          <div class="table-col fR tR">\
            <div class="button toggle-row-enable ');  if staticRouteDetails[i].enabled then   ngx.print('button-on');  else  ngx.print('button-off');  end  ngx.print('" id="static-routing-btn-enable_');  ngx.print(i); ngx.print('" >\
              <input type="hidden" class="RouteIndex" value="');  ngx.print(staticRouteDetails[i].index); ngx.print('"/>\
              <input type="hidden" class="enabled" value="');  ngx.print(staticRouteDetails[i].enabled and 1 or 0); ngx.print('"/>\
              <input type="hidden" class="EditRow" value=""/>\
            </div>\
          </div>\
        </div>\
        ');  end   ngx.print('\
        <div class="table-row" id="staticRoute-row-last">\
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
          <div class="table-col">\
            &nbsp;\
          </div>\
          <div class="table-col fR tR">\
            <input class="button button-add"  id="static-routing-btn-add" type="button" data-toggle="modal" data-target="#addAccessControlModal">\
          </div>\
        </div>\
      </div>\
    </div>\
  </form>\
</div>\
\
');  
  local lp = require("web.lp")
  lp.setpath("/www/docroot/")
  lp.include("apply-cancel.lp")
  ngx.print('\
\
<!-- Edit Popup Modal -->\
<div class="modal fade static-modal" id="editAccessControlModal" data-backdrop="static" role="dialog">\
  <div class="modal-dialog">\
    <div class="modal-content change-password-content">\
      <div class="modal-header hidden-sm hidden-md hidden-lg">\
        <div class="mobile-cancel-popup button-cancel"></div>\
      </div>\
      <div class="modal-body no-padding">\
        <div class="mobile-cancel-popup button-cancel"></div>\
        <p class="title">\
          ');  ngx.print(T"Edit Static Route"); ngx.print('\
        </p>\
        <div class="table">\
          <div class="vdf-row">\
            <div class="left">\
              <span>');  ngx.print(T"Destination"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <input value=""  id="staticRoute-txt-editDestIP" type="text">\
            </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <span>');  ngx.print(T"Mask"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <input value="" id="staticRoute-txt-editMask" type="text">\
            </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <span>');  ngx.print(T"Gateway"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <input value=""  id="staticRoute-txt-editGWIP" type="text">\
            </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <span>');  ngx.print(T"Interface"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <div id="top-info-mode" class="rel">\
                <select id="interfaceSelectEdit" style="width: 100%">\
                  ');  for _, intf in ipairs(interfaceList) do
                    if intf[1] == "Select an Option" then
                      local option = T"Select an Option"
                      ngx.print(format("<option value='%s'>%s</option>", intf[1], option))
                    else
                      ngx.print(format("<option value='%s'>%s</option>", intf[1], intf[1]))
                    end
                  end  ngx.print('\
                </select>\
              </div>\
            </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <span>');  ngx.print(T"Metric"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <input value=""  id="staticRoute-txt-editMetric" type="text">\
            </div>\
          </div>\
        </div>\
        <div class="apply-cancel">\
          <input id="staticRoute-btn-editSave" class="button button-apply save "  data-dismiss="modal" value="');  ngx.print(T"Save"); ngx.print('" type="button">\
          <input  id="staticRoute-btn-editCancel" class="button button-cancel close-password-popup" data-dismiss="modal" value="');  ngx.print(T"Cancel"); ngx.print('" type="button">\
        </div>\
      </div>\
    </div>\
  </div>\
</div>\
\
<!-- ADD Popup Modal  -->\
<div class="modal fade static-modal" id="addAccessControlModal" data-backdrop="static" role="dialog">\
  <div class="modal-dialog">\
    <!-- Modal content -->\
    <div class="modal-content change-password-content">\
      <div class="modal-header hidden-sm hidden-md hidden-lg">\
        <div class="mobile-cancel-popup button-cancel"></div>\
      </div>\
      <div class="modal-body no-padding">\
        <div class="mobile-cancel-popup button-cancel"></div>\
        <p class="title">\
          ');  ngx.print(T"Add Static Route"); ngx.print('\
        </p>\
        <div class="table">\
          <div class="vdf-row">\
            <div class="left">\
              <span>');  ngx.print(T"Destination"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <input value="" id="staticRoute-txt-addDestIP" type="text">\
            </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <span>');  ngx.print(T"Mask"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <input value="" id="staticRoute-txt-addMask" type="text">\
            </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <span>');  ngx.print(T"Gateway"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <input value="" id="staticRoute-txt-addGWIP" type="text">\
            </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <span>');  ngx.print(T"Interface"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <div id="top-info-mode" class="rel">\
                <select id="interfaceSelectAdd" style="width: 100%">\
                  ');  for _, intf in ipairs(interfaceList) do
                    if intf[1] == "Select an Option" then
                      local option = T"Select an Option"
                      ngx.print(format("<option value='%s'>%s</option>", intf[1], option))
                    else
                      ngx.print(format("<option value='%s'>%s</option>", intf[1], intf[1]))
                    end
                  end  ngx.print('\
                </select>\
              </div>\
            </div>\
          </div>\
          <div class="vdf-row">\
            <div class="left">\
              <span>');  ngx.print(T"Metric"); ngx.print('</span>\
            </div>\
            <div class="right">\
              <input value=""  id="staticRoute-txt-addMetric" type="text">\
            </div>\
          </div>\
        </div>\
        <div class="apply-cancel">\
          <input id="staticRoute-btn-addSave" class="button button-apply save "  data-dismiss="modal" value="');  ngx.print(T"Save"); ngx.print('" type="button">\
          <input  id="staticRoute-btn-addCancel" class="button button-cancel close-password-popup" data-dismiss="modal" value="');  ngx.print(T"Cancel"); ngx.print('" type="button">\
        </div>\
      </div>\
    </div>\
  </div>\
</div>\
\
<script>\
var elements = {\
  destination : ".modal.in [id$=DestIP]",\
  mask        : ".modal.in [id$=Mask]",\
  gateway     : ".modal.in [id$=GWIP]",\
  metric      : ".modal.in [id$=Metric]"\
}\
var validations = {\
  destination : IPRegExp,\
  mask        : IPRegExp,\
  gateway     : IPRegExp,\
  metric      : validateNumberRange(0, ');  ngx.print(metricMaxRange); ngx.print(')\
}\
\
var editedRow;\
var getNoOfFTTHrules = "');  ngx.print(#ftthRoutes); ngx.print('";\
$(function() {\
  var totalRows = 0;\
  sessionStorage.setItem(\'apply_changes\', "Y");\
  $("#staticRoute-btn-editSave").click(function() {\
    if (!validateElements(elements, validations)) return false;\
\
    //Default values for metric, gateway ip and subnet mask if input fields are empty after save\
    if ($("#staticRoute-txt-editGWIP").val().length === 0) {\
      $("#staticRoute-txt-editGWIP").val("0.0.0.0");\
    }\
    if ($("#staticRoute-txt-editMask").val().length === 0) {\
      $("#staticRoute-txt-editMask").val("255.255.255.255");\
    }\
    if ($("#staticRoute-txt-editMetric").val().length === 0) {\
      $("#staticRoute-txt-editMetric").val("0");\
    }\
    editedRow.find(".target").text($("#staticRoute-txt-editDestIP").val());\
    editedRow.find(".netmask").text($("#staticRoute-txt-editMask").val());\
    editedRow.find(".gateway").text($("#staticRoute-txt-editGWIP").val());\
    if ($("#interfaceSelectEdit").val() === "Select an Option") {\
      editedRow.find(".interface").text("");\
    } else {\
      editedRow.find(".interface").text($("#interfaceSelectEdit").val() === null ? "" : $("#interfaceSelectEdit").val());\
    }\
    editedRow.find(".metric").text($("#staticRoute-txt-editMetric").val());\
    editedRow.find(".EditRow").val("1");\
  });\
  $(".mobile-cancel-popup").click(function() {\
    $(".modal").modal(\'hide\');\
  });\
  $("#staticRoute-btn-addSave").click(function() {\
    if (!validateElements(elements, validations)) return false;\
    var addTarget = $("#staticRoute-txt-addDestIP").val();\
    var addNetmask = $("#staticRoute-txt-addMask").val();\
    var addGateway = $("#staticRoute-txt-addGWIP").val();\
    var addInterfaceType = $("#interfaceSelectAdd").val();\
    var addMetric = $("#staticRoute-txt-addMetric").val();\
    if (addInterfaceType === "Select an Option") {\
      addInterfaceType = "";\
    }\
    var rows = $(".table-row:not(:first):not(:last):visible").length + 1;\
\
    //Default values for metric, gateway ip and subnet mask if input fields are empty after save\
    if (addMetric.length === 0) {\
      addMetric = "0";\
    }\
    if (addGateway.length === 0) {\
      addGateway = "0.0.0.0";\
    }\
    if (addNetmask.length === 0) {\
      addNetmask = "255.255.255.255";\
    }\
    $(\'<div class="table-row">\\\
      <div class="table-col target">\'+addTarget+\' </div>\\\
      <div class="table-col netmask">\'+addNetmask+\'</div>\\\
      <div class="table-col  gateway">\'+addGateway+\'</div>\\\
      <div class="table-col  interface">\'+addInterfaceType+\'</div>\\\
      <div class="table-col  metric">\'+addMetric+\'</div>\\\
      <div class="table-col"><input class="button button-edit editbutton" id="static-routing-btn-edit_\'+ rows +\'" type="button" data-toggle="modal" data-target="#editAccessControlModal"></div>\\\
      <div class="table-col ">\\<input class="button button-delete deletebutton" id="static-routing-btn-delete_\'+ rows +\'" type="button"></div>\\\
      <div class="table-col fR tR">\\\
        <div class="button toggle-row-enable button-on" id="static-routing-btn-enable_\'+ rows +\'" >\\\
          <input type="hidden" class="RouteIndex" value="new"/>\\\
          <input type="hidden" class="enabled" value="1"/>\\\
          <input type="hidden" class="EditRow" value="1"/>\\\
        </div>\\\
      </div>\\\
    </div>\').insertBefore("#staticRoute-row-last");\
  });\
\
  $(".static-routing-table").on("click", ".button-edit", function() {\
    sessionStorage.setItem(\'apply_changes\', "Y");\
    editedRow = $(this).closest("div").parent();\
    var editTarget = $.trim(editedRow.find(".target").text());\
    var editNetmask =$.trim(editedRow.find(".netmask").text());\
    var editGateway = $.trim(editedRow.find(".gateway").text());\
    var editInterfaceType = $.trim(editedRow.find(".interface").text());\
    var editMetric = $.trim(editedRow.find(".metric").text()) ;\
    var rowEditIndex = editedRow.find(".RouteIndex");\
    if (rowEditIndex.val() == "new" && vdfVariant == "NZ") {\
      // Used to restrict page navigation on selecting Cancel within a new rule that is edited\
      sessionStorage.setItem("newRule_edit", "true");\
    }\
    if (editInterfaceType === "") {\
      editInterfaceType = "Select an Option";\
    }\
    $("#interfaceSelectEdit").val(editInterfaceType).trigger("chosen:updated");\
    $("#interfaceSelectEdit").trigger("chosen:updated");\
    $("#staticRoute-txt-editDestIP").val(editTarget);\
    $("#staticRoute-txt-editMask").val(editNetmask);\
    $("#staticRoute-txt-editGWIP").val(editGateway);\
    $("#staticRoute-txt-editMetric").val(editMetric);\
    $("[role=dialog] .input-error").removeClass("input-error");\
  });\
\
  $(".static-routing-table").on("click", ".button-add", function() {\
    $("#addAccessControlModal input[type=text]").each(function(){$(this).val("")})\
    $("#interfaceSelectAdd option:first").attr(\'selected\',\'selected\');\
    $("[role=dialog] .input-error").removeClass("input-error");\
  });\
\
  $(".static-routing-table").on("click", ".button-delete", function() {\
    var deleteRow = $(this).closest("div").parent();\
    var index = $( ".button-delete" ).index(this);\
    var rowIndex = deleteRow.find(".RouteIndex");\
    if (rowIndex.val() == "new" && vdfVariant == "NZ") {\
      // To avoid navigation restriction when new unsaved rule is deleted\
      sessionStorage.setItem("delete_bypass", "true");\
    }\
    rowIndex.val("del"+rowIndex.val());\
    deleteRow.hide();\
  });\
\
  $("#static-routing-table").on("click", ".toggle-row-enable", function() {\
    if ($(this).hasClass(\'button-off\')) {\
      $(this).closest("div").parent().parent().find(".staticrow").removeClass("op40").addClass("op60");\
      $(this).find(".EditRow").val("1");\
      $(this).removeClass(\'button-off\').addClass(\'button-on\');\
    } else {\
      $(this).closest("div").parent().parent().find(".staticrow").removeClass("op60").addClass("op40");\
      $(this).find(".EditRow").val("0");\
      $(this).removeClass(\'button-on\').addClass(\'button-off\');\
    }\
    var editedRow = $(this).closest("div").parent();\
    var editedRowIndex = editedRow.find(".RouteIndex");\
    if ((vdfVariant == "NZ") && (editedRowIndex.val() !== "new")) {\
      detectToggleChanges($(this));\
    }\
  });\
\
  $("#global-apply, #modal-apply").click(function() {\
    var totalRows = 0;\
    if (vdfVariant == "NZ" && typeof(Storage) !== "undefined") {\
      sessionStorage.setItem("user_interacted", "pristine");\
    } else {\
      sessionStorage.setItem(\'apply_changes\', "Y");\
    }\
    var target = $("#staticroute-form").attr("action");\
    var staticrouteObj = [];\
    $(\'.static-routing-table\').find(".table-row:gt(" + getNoOfFTTHrules + "):not(:last)").each(function(index){\
      totalRows++;\
      staticrouteObj.push({\
        index : $.trim($(this).find(".RouteIndex").val()),\
        target : $.trim($(this).find(".target").text()),\
        netmask :$.trim($(this).find(".netmask").text()),\
        gwip : $.trim($(this).find(".gateway").text()),\
        interface :$.trim($(this).find(".interface").text()),\
        metric : $.trim($(this).find(".metric").text()),\
        enabled : $.trim($(this).find(".enabled").val()) === "1",\
        EditRow: $.trim($(this).find(".EditRow").val()),\
      });\
    });\
    var postObj = [];\
    postObj.push({ name : "staticRouteTable", value : JSON.stringify(staticrouteObj) });\
    postObj.push({ name : "CSRFtoken", value : "');  ngx.print(CSRFtoken); ngx.print('" });\
    postObj.push({ name : "rows", value : totalRows });\
    postHandle(target, postObj);\
  });\
\
  function postHandle(target, params) {\
    applyCancelPopupHide();\
    if (typeof(Storage) !== "undefined") {\
      // Save data to sessionStorage\
      sessionStorage.setItem(\'apply_changes\', "Y");\
    } else {\
      console.log("Sorry! No Web Storage support..");\
    }\
    $.post(target, params, function(responseText, status) {\
      $("#static-routing-btn-add").prop("disabled",true);\
      $(".editbutton").prop("disabled",true);\
      $(".deletebutton").prop("disabled",true);\
      $(\'.toggle-row-enable\').prop(\'disabled\', true);\
      if (responseText.status === "success") {\
        $(".articlediv > .msg-error").removeClass("show").addClass("hide");\
        $(".articlediv > .msg-warning").removeClass("show").addClass("hide");\
        $(".articlediv > .message-arrowbox-applied").removeClass("hide").addClass("show");\
      } else if(responseText.status === "error") {\
        $(".articlediv > .msg-error").removeClass("hide").addClass("show");\
        $(".articlediv > .msg-warning").removeClass("show").addClass("hide");\
        $(".articlediv > .message-arrowbox-applied").removeClass("show").addClass("hide");\
      }\
      $(".articlediv").removeClass("hide").addClass("show");\
      setTimeout(function(){ $(".articlediv").removeClass("show").addClass("hide")}, 3000);\
      if (responseText.status === "success") {\
        setTimeout(function() {\
          $("#content").load("/modals/settings/staticRouting.lp");\
        }, 3000);\
      } else {\
        $("#static-routing-btn-add").prop("disabled",false);\
        $(".editbutton").prop("disabled",false);\
        $(".deletebutton").prop("disabled",false);\
        $(\'.toggle-row-enable\').prop(\'disabled\', false);\
      }\
    });\
  }\
\
  $("#global-cancel").click(function() {\
    $("#content").load("/modals/settings/staticRouting.lp");\
  });\
});\
</script>\
'); 