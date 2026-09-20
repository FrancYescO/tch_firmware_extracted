--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local ngx, pairs, string, table, tonumber = ngx, pairs, string, table, tonumber
local validateStringIsMAC = post_helper.validateStringIsMAC
local validateLength = post_helper.getValidateStringLengthInRange(1,63)
local json = require("dkjson")
local match, format, untaint, upper, lower, ipairs = string.match, string.format, string.untaint, string.upper, string.lower, ipairs
local whiteList24, blackList24, whiteList5, blackList5 = {}, {}, {}, {}
local isvalidName, isError, success, content
local ap_paths={}
local curAccPoint24ghz, curAccPoint5ghz = "", ""
for i,v in ipairs(proxy.getPN("rpc.wireless.ap.", true)) do
  ap_paths[i] = v.path.."ssid"
end
local wl_list = proxy.get(unpack(ap_paths))
for i,v in ipairs(wl_list) do
  if(v.value == "wl1") then
    curAccPoint5ghz = match(v.path, "rpc%.wireless%.ap%.@([^%.]+)%.")
  end
  if(v.value == "wl0") then
    curAccPoint24ghz = match(v.path, "rpc%.wireless%.ap%.@([^%.]+)%.")
  end
end


local function getWifiACLLists()
  whiteList24 = content_helper.convertResultToObject("uci.wireless.wifi-ap.@" ..curAccPoint24ghz ..".acl_accept_list.", proxy.get("uci.wireless.wifi-ap.@" ..curAccPoint24ghz..".acl_accept_list."))
  blackList24 = content_helper.convertResultToObject("uci.wireless.wifi-ap.@" ..curAccPoint24ghz ..".acl_deny_list.", proxy.get("uci.wireless.wifi-ap.@"..curAccPoint24ghz..".acl_deny_list."))
  whiteList5  = content_helper.convertResultToObject("uci.wireless.wifi-ap.@" ..curAccPoint5ghz ..".acl_accept_list.", proxy.get("uci.wireless.wifi-ap.@" ..curAccPoint5ghz..".acl_accept_list."))
  blackList5  = content_helper.convertResultToObject("uci.wireless.wifi-ap.@" ..curAccPoint5ghz ..".acl_deny_list.", proxy.get("uci.wireless.wifi-ap.@" ..curAccPoint5ghz..".acl_deny_list."))
end

getWifiACLLists()

local function addACL(macAddr, name, paramMap, basePath)
  local found
  isvalidName = validateLength(name)
  if isvalidName then
    content={
    ["macaddr"] = macAddr}
    success = content_helper.addNewObject(basePath, content, paramMap, nil)
    if success then
      local getHosts = content_helper.convertResultToObject("uci.user_friendly_name.name.", proxy.get("uci.user_friendly_name.name."))
      for _,mac in pairs(getHosts) do
        local entry = tonumber(mac.paramindex)
        if macAddr == mac.mac or upper(macAddr) == mac.mac or lower(macAddr) == mac.mac then
          proxy.set({["uci.user_friendly_name.name."..entry..".name"] = name })
          proxy.apply()
          found = true
        end
      end
      if not found then
        local deviceInstance = proxy.add("uci.user_friendly_name.name.")
        local namePath = {["uci.user_friendly_name.name."..deviceInstance..".name"] = name, ["uci.user_friendly_name.name."..deviceInstance..".mac"] = macAddr}
        local setSuccess = proxy.set(namePath)
        if setSuccess then
          proxy.apply()
        end
      end
    end
  else
    isError = true
  end
end

local function deleteACL(deleteInstances, listName, curAccessPoint, otherListName)
  local deletedAllowMac, otherListPath
  table.sort(deleteInstances, function (k1, k2) return k1 > k2 end)
  for i = 1, #deleteInstances do
    local path = format("uci.wireless.wifi-ap.@%s.%s.@%d.", curAccessPoint, listName, deleteInstances[i])
    deletedAllowMac = proxy.get(path)
    success = proxy.del(path)
    for _, mac in pairs(otherListName) do
       if (mac.value == deletedAllowMac[1]["value"]) then
          local instance = match(mac.paramindex, '%d')
          otherListPath =  format("uci.wireless.wifi-ap.@" ..curAccPoint5ghz..".%s.@%d.", listName, instance)
       end
       proxy.del(otherListPath)
     end
  end
end

local function handlingLists(table1, table2, curAccessPoint, listName)
  local addBasePath = format("uci.wireless.wifi-ap.@%s.%s.", curAccessPoint, listName)
  local addInstance, setMac
  for _, mac1 in pairs(table1) do
    local found
    for _, mac2 in pairs(table2) do
      if (mac1.value == mac2.value) then
        found = true
        break
      end
    end
    if not found then
        addInstance = proxy.add(addBasePath)
        setMac = {[format("uci.wireless.wifi-ap.@%s.%s.@%s.value", curAccessPoint, listName, addInstance)] = mac1.value }
    end
  local setSuccess = proxy.set(setMac)
  if setSuccess then
    proxy.apply()
  end
  end
end

handlingLists(whiteList24, whiteList5, curAccPoint5ghz, "acl_accept_list")
handlingLists(whiteList5, whiteList24, curAccPoint24ghz, "acl_accept_list")
handlingLists(blackList24, blackList5, curAccPoint5ghz, "acl_deny_list")
handlingLists(blackList5, blackList24, curAccPoint24ghz, "acl_deny_list")
getWifiACLLists()
local deleteInstances, chosenList24, chosenList5  = {}, {}, {}
local deleteCount, listName, addCount, postargs

if ngx.var.request_method == "POST" then
  if ngx.req.get_post_args().action == "Reset" then
    proxy.set("uci.wireless.wifi-ap.@ap0.acl_mode", "unlock")
    proxy.set("uci.wireless.wifi-ap.@ap1.acl_mode", "lock")
    proxy.del("uci.wireless.wifi-ap.@ap0.acl_accept_list.")
    proxy.del("uci.wireless.wifi-ap.@ap1.acl_accept_list.")
    proxy.del("uci.wireless.wifi-ap.@ap0.acl_deny_list.")
    proxy.del("uci.wireless.wifi-ap.@ap1.acl_deny_list.")
    proxy.apply()
    ngx.header.content_type = "application/json"
    ngx.print('{ "status":"success" }')
    ngx.exit(ngx.HTTP_OK)
  end
  postargs = ngx.req.get_post_args()
  addCount = tonumber(postargs["addRowCount"])
  deleteCount = 0
  if postargs["aclMode24"] == "lock" then
    listName = "acl_accept_list"
    deleteCount = tonumber(postargs["allowDeleteCount"])
    chosenList24 = whiteList24
    chosenList5 = whiteList5
  elseif postargs["aclMode24"] == "unlock" then
    listName = "acl_deny_list"
    deleteCount = tonumber(postargs["blockDeleteCount"])
    chosenList24 = blackList24
    chosenList5 = blackList5
  end

  -- Add New Mac Address to list
  if addCount > 1 then
    for i = 1, addCount do
      for j = i + 1, addCount do
        if (postargs["newAddMacAddr"..i] == postargs["newAddMacAddr"..j] or upper(postargs["newAddMacAddr"..i]) == postargs["newAddMacAddr"..j] or lower(postargs["newAddMacAddr"..i]) == postargs["newAddMacAddr"..j]) then
          isError = true
        end
      end
    end
  end
  if not isError then
    if addCount > 0 then
      local basepath = format("uci.wireless.wifi-ap.@%s.%s.@.", curAccPoint24ghz, listName)
      local paramMap = {
        ["macaddr"] = "value"}

    -- Duplicate Validation
      for j=1, addCount do
        for _,p in pairs(chosenList24) do
          if ((p["value"] == postargs["newAddMacAddr"..j]) or (upper(p["value"]) == postargs["newAddMacAddr"..j]) or (lower(p["value"]) == postargs["newAddMacAddr"..j])) then
            isError = true
          end
        end
        if isError then
          break
        end
        end

    -- Check for valid mac address
      for i=1, addCount do
        local mac = untaint(postargs["newAddMacAddr"..i])
        local reply = validateStringIsMAC(mac)
        if not reply then
          isError = true
        end
      end
      if not isError then
        for i=1, addCount do
          if postargs["newAddMacAddr"..i] then
            if not isError then
              addACL(postargs["newAddMacAddr"..i], postargs["newAddMacName"..i], paramMap, basepath)
            end
          end
        end
      end
    end
  end

 --Delete Mac Address from list
  if (deleteCount > 0) then
    for i=1, deleteCount do
      if postargs["aclMode24"] == "lock" then
        if postargs["allowDeleteInstance"..i] and postargs["allowDeleteInstance"..i] ~="" then
          local index = tonumber(postargs["allowDeleteInstance"..i])
          deleteInstances[#deleteInstances + 1] = index
        end
      elseif postargs["aclMode24"] == "unlock" then
       if postargs["denyDeleteInstance"..i] and postargs["denyDeleteInstance"..i] ~="" then
          local index = tonumber(postargs["denyDeleteInstance"..i])
         deleteInstances[#deleteInstances + 1] = index
        end
      end
    end
    if not isError then
      deleteACL(deleteInstances, listName, curAccPoint24ghz, chosenList5)
    end
  end
end

local resetmacfilter = {
  reset_mac_filter_enable = "uci.uci-defaults.macfilter.mac_filter_enable",
  reset_mac_filter_access = "uci.uci-defaults.macfilter.mac_filter_access"
}
content_helper.getExactContent(resetmacfilter)

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SAVE" then
  ngx.header.content_type = "application/json"
  local modePath
  if not isError then
    local macControlMode24 = ngx.req.get_post_args().aclMode24
    modePath = {["uci.wireless.wifi-ap.@"..curAccPoint24ghz..".acl_mode"] = macControlMode24, ["uci.wireless.wifi-ap.@" ..curAccPoint5ghz..".acl_mode"] = macControlMode24 }
    local setSuccess = proxy.set(modePath)
    if setSuccess then
      proxy.apply()
    end
      ngx.print('{ "status":"success" }')
  else
     ngx.print('{ "status":"error" }')
  end
  ngx.exit(ngx.HTTP_OK)
end

local macMode = {
  aclMode24  = "uci.wireless.wifi-ap.@" ..curAccPoint24ghz..".acl_mode",
  aclMode5   = "uci.wireless.wifi-ap.@" ..curAccPoint5ghz..".acl_mode",
  wifi24stat = "uci.wireless.wifi-ap.@"..curAccPoint24ghz..".state",
  wifi5stat  = "uci.wireless.wifi-ap.@"..curAccPoint5ghz..".state",
}
content_helper.getExactContent(macMode)
getWifiACLLists()
handlingLists(whiteList24, whiteList5, curAccPoint5ghz, "acl_accept_list")
handlingLists(whiteList5, whiteList24, curAccPoint24ghz, "acl_accept_list")
handlingLists(blackList24, blackList5, curAccPoint5ghz, "acl_deny_list")
handlingLists(blackList5, blackList24, curAccPoint24ghz, "acl_deny_list")

local allowList = content_helper.convertResultToObject("uci.wireless.wifi-ap.@"..curAccPoint24ghz..".acl_accept_list.", proxy.get("uci.wireless.wifi-ap.@"..curAccPoint24ghz..".acl_accept_list."))
local denyList = content_helper.convertResultToObject("uci.wireless.wifi-ap.@"..curAccPoint24ghz..".acl_deny_list.", proxy.get("uci.wireless.wifi-ap.@"..curAccPoint24ghz..".acl_deny_list."))
table.sort(allowList, function(a,b)
  return tonumber(match(a.paramindex, "%d+")) < tonumber(match(b.paramindex, "%d+"))
end)
table.sort(denyList, function(a,b)
  return tonumber(match(a.paramindex, "%d+")) < tonumber(match(b.paramindex, "%d+"))
end)
local macList, hostTable = {}, {}

 --Lists in rpc.hosts.hosts
local hostsList = content_helper.convertResultToObject("rpc.hosts.host.", proxy.get("rpc.hosts.host."))
local savedHosts = content_helper.convertResultToObject("uci.user_friendly_name.name.", proxy.get("uci.user_friendly_name.name."))
local lowerIntfFor24Ghz  = "wl0"
local lowerIntfForFiveGhz = "wl1"
for _,host in pairs(hostsList) do
  if ((host["L2Interface"] == lowerIntfFor24Ghz) or (host["L2Interface"] == lowerIntfForFiveGhz)) then
    macList[#macList + 1]={}
    macList[#macList].FriendlyName= (host["FriendlyName"] ~= "") and host["FriendlyName"] or (host["HostName"] ~= "") and host.HostName  or ("unknown-" .. host.MACAddress)
    macList[#macList].macAddr= host["MACAddress"]
    hostTable[(host["MACAddress"])] = (host["FriendlyName"] ~= "") and host["FriendlyName"] or (host["HostName"] ~= "") and host.HostName or  ("unknown-" .. host.MACAddress)
  end
end
for _,host in pairs(savedHosts) do
  if (hostTable[host["mac"]] ~= "" ) then
    hostTable[host["mac"]] = host["name"]
    hostTable[upper(host["mac"])] = host["name"]
    hostTable[lower(host["mac"])] = host["name"]
  end
end
local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")

  ngx.print('\
<script src="js/global.js"></script>\
<h1>');  ngx.print(T"MAC Filter"); ngx.print('</h1>\
<h2>');  ngx.print(T"To make your wireless network more secure, you can specify which devices are allowed to connect. The devices are identified by their MAC address. You can manage up to 32 devices."); ngx.print('\
</h2>\
<form id="macFilter-form" class="form-horizontal" method="post" action="/modals/mac-filter.lp">\
  <h3>');  ngx.print(T"Main Wi-Fi"); ngx.print('</h3>\
\
<!--   <div class="row">\
    <div class="col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20 macfilter-mobile-line-height-30">\
      <span class="font-bold">');  ngx.print(T"MAC Filtering"); ngx.print('</span>\
    </div>\
    <div class="col-md-6 col-sm-6 col-xs-6 padding-top-bottom-20">\
      <div class=" pull-right">\
        <div id="macfilter-btn-mode" class="button ');  if (macMode["aclMode24"] == "disabled") and (macMode["aclMode5"] == "disabled") then   ngx.print(' button-off ');  else  ngx.print(' button-on ');  end  ngx.print(' aclmode24"></div>\
      </div>\
    </div>\
  </div> -->\
  <div class="h3-content no-padding-bottom">\
  ');  if macMode["wifi24stat"] == "0" and macMode["wifi5stat"] == "0" then  ngx.print('\
    <div class="message message-info">\
        <span id="macfilter-footerwifioff-info" class="font-normal">');  ngx.print(T"Your Wi-Fi is currently disabled, so your changes will not take effect. To enable the Wi-Fi, go to General settings."); ngx.print('</span>\
    </div>\
  ');  end  ngx.print('\
  </div>\
  <div class="h3-content no-padding-bottom vdf-table">\
	<div class="vdf-row">\
        <div class="left">\
            <span class="font-bold">');  ngx.print(T"MAC Filtering"); ngx.print('</span>       </div>\
        <div class="right">\
            <div id="macfilter-btn-mode" class="button ');  if (macMode["aclMode24"] == "disabled") and (macMode["aclMode5"] == "disabled") then   ngx.print(' button-off ');  else  ngx.print(' button-on ');  end  ngx.print(' aclmode24"></div>\
        </div>\
    </div>\
</div>\
  <div id="macfilter-hide" class=" ');  if(macMode["aclMode24"] == "disabled") then   ngx.print(' hide ');  end  ngx.print(' level-3">\
<div class="h3-content no-padding-bottom h3-content-mobile vdf-table">\
	<div class="vdf-row">\
		<div class="left">\
			<span class="font-bold">');  ngx.print(T"Access for listed devices"); ngx.print('</span>           </div>\
		<div class="right">\
        <input class="radio radio-checked" name="macfilter-rad-allow" ');  if macMode["aclMode24"] == "lock" then  ngx.print(' checked="checked" ');  end  ngx.print(' id="macfilter-rad-allow" value="" type="radio">\
        <label for="macfilter-rad-allow" style="margin-right: 15px;"></label>\
        <span> ');  ngx.print(T"Allow"); ngx.print('</span>\
      </div>\
		<div class="right">\
			<span style="display:inline-block;">\
        <input class="radio radio-checked"  name="macfilter-rad-deny"');  if ((macMode["aclMode24"] == "disabled") or (macMode["aclMode24"] == "unlock")) then  ngx.print(' checked="checked" ');  end  ngx.print(' id="macfilter-rad-deny" value="" type="radio">\
        <label for="macfilter-rad-deny" style="margin-right: 15px;"></label>\
        <span>');  ngx.print(T"Deny"); ngx.print('</span>\
      </span>           </div>\
	</div>\
\
\
</div>\
\
<div class="h3-table-content desktop">\
 <div class="row no-margin-left hidden-xs macfilter-padding-40">\
    <div class="col-md-4 col-sm-4 col-xs-6 padding-top-bottom-20 macfilter-column-2">\
      <span>');  ngx.print(T"Name"); ngx.print('</span>\
    </div>\
    <div class="col-md-7 col-sm-7 col-xs-6 padding-top-bottom-20">\
      <span>');  ngx.print(T"MAC Address"); ngx.print('</span>\
    </div>\
  </div>\
  <div class="row no-margin-left no-mac-rule-parent macfilter-padding-40">\
\
\
      <div class="col-md-6 col-sm-6 hidden-xs macfilter-column-2 padding-top-bottom-20">&nbsp;\
      </div>\
      <div class="col-md-6 col-sm-6 col-xs-12 mobile-mac-filter-msg-center padding-top-bottom-20 mobile-padding-top-bottom-none macfilter-margin-top-17">\
	   <div class="no-mac-rule no-mac-rule-home" style="font-weight: normal; font-style: italic;">\
        <span style="font-weight: normal; font-style: italic;">');  ngx.print(T"No device added"); ngx.print('</span>\
      </div>\
    </div>\
  </div>\
</div>  <div id="mac-list-allow-main" data-mode="allow">\
  </div>\
  <div id="mac-list-deny-main" data-mode="deny">\
  </div>\
  <div class="row padding-top-bottom-20 no-margin-left mobile-padding-bottom-none">\
    <div class="col-md-12 col-xs-12">\
      <p class="mobile-mac-filter-msg-right mobile-padding-bottom-none macfilter-margin-bottom-30">\
        <input id="macfilter-btn-add" class="button button-add macfilter-btn-add" value="" type="button">\
      </p>\
    </div>\
  </div>\
<div class="col-md-12 col-sm-12 hidden-xs line-height-24">&nbsp;\
</div>\
  <div class="row no-margin-left macfilter-padding-40 macfilter-padding-bottom-50">\
    <div class="col-md-8 col-sm-8 col-xs-12 padding-top-bottom-20 mobile-mac-filter-msg-center">\
      <p class = "macfilter-deviceadd line-height-30">');  ngx.print(T"Add all known devices to the MAC Filtering list"); ngx.print('</p>\
    </div>\
    <div class="col-md-4 col-sm-4 padding-top-bottom-20 macfilter-mobile-padding-bottom-50 ">\
      <p class="mobile-mac-filter-msg-right">\
        <input id="macfilter-btn-hostadd24" class="button button-add macfilter-mobile-margin-top-10" value="" type="button" data-toggle="modal" data-target="#addModal">\
      </p>\
    </div>\
  </div>\
</div>\
</div>\
</div>\
</div>\
</form>\
<div class="row no-margin-right">\
  <div class="col-md-12 col-sm-12 col-xs-12 no-padding-right">\
   <!-- <div class="articlediv hide">\
      <div class="message-arrowbox-applied">\
        <div class="message-arrowbox-applied-right">\
          <p class="success-info">\
          </p>\
        </div>\
      </div>\
    </div> -->\
    ');  
    lp.include("apply-cancel.lp")
    lp.include("reset-wrap-mobile.lp")
    ngx.print('\
  </div>\
</div>\
\
<!-- Password Popup Modal-->\
\
<div class="modal fade" id="addModal" role="dialog" data-backdrop = "static">\
  <div class="modal-dialog">\
    <div class="modal-content change-password-content">\
	  <div class="modal-header hidden-sm hidden-md hidden-lg">\
        <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
      </div>\
      <div class="modal-body no-padding mobile-modal-padding-top">\
        <form class="form-horizontal">\
        <div class="form-group no-margin-bottom">\
            <div class="col-sm-12">\
              <p class="title tL">\
                ');  ngx.print(T"Select the devices you want to add to the MAC Filtering list"); ngx.print('\
              </p>\
            </div>\
        </div>\
          ');  for i,host in pairs(macList) do   ngx.print('\
          <div class="form-group no-margin">\
            <div class="col-md-6 col-sm-6 col-lg-6 padding-top-bottom-20 modal-padding-lrt-none macfilter-mobile-no-padding-bottom">\
              <input id="ch');  ngx.print(i); ngx.print('" class="checkbox checkbox-unchecked ch1 device01" type="checkbox">\
              <label class="macfilter-mobile-padding-right-5" for="ch');  ngx.print(i); ngx.print('">\
              </label>\
              <label class="checkbox-label mac-filtering-list text-overflow" for="ch');  ngx.print(i); ngx.print('"><span>');  ngx.print(host["FriendlyName"]); ngx.print('</span></label>\
            </div>\
            <div class="col-md-6 col-sm-6 col-lg-6 padding-top-bottom-20 modal-padding-lrt-none mobile-mac-filter-modal-text macfilter-mobile-padding-top-10 macfilter-mobile-padding-left-25">\
              <span class="checkbox-mac">');  ngx.print(host["macAddr"]); ngx.print('</span>\
            </div>\
          </div>\
         ');  end  ngx.print('\
          <div class="form-group no-margin-bottom no-margin-right">\
            <div class="col-sm-12">\
              <div class="modal-footer">\
                <input id="macfilter-btn-addmac" class="button button-apply save mob-button-width" value="');  ngx.print(T"Add"); ngx.print('"  type="button">\
                <input id="macfilter-btn-cancelmac" class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" data-dismiss="modal" value="');  ngx.print(T"Cancel"); ngx.print('" type="button">\
              </div>\
            </div>\
          </div>\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
<script>\
    var hostTable = ');  ngx.print(json.encode(hostTable)); ngx.print('\
    var allowList = ');  ngx.print(json.encode(allowList)); ngx.print('\
    var denyList  = ');  ngx.print(json.encode(denyList)); ngx.print('\
    var macMode_aclMode24 = "');  ngx.print(macMode["aclMode24"]); ngx.print('"\
    var resetmacfilter_enable = "');  ngx.print(resetmacfilter["reset_mac_filter_enable"]); ngx.print('"\
    var resetmacfilter_access = "');  ngx.print(resetmacfilter["reset_mac_filter_access"]); ngx.print('"\
    var T = {\
     "Name" : "');  ngx.print(T"Name"); ngx.print('",\
     "MAC Address" : "');  ngx.print(T"MAC Address"); ngx.print('"\
    }\
</script>\
<script src="js/mac-filter.js"></script>\
'); 