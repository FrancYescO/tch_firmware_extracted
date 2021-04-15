--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-parental')

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local ipairs = ipairs
local uinetwork = require("web.uinetwork_helper")
local hosts_ac = uinetwork.getAutocompleteHostsList()
local match, format, gsub  = string.match, string.format, string.gsub
local tonumber = tonumber
local session = ngx.ctx.session
local uniqueKey = post_helper.getRandomKey()
local proxy = require("datamodel")
local role = session:getrole()
local json = require("dkjson")
-- Shortcuts to validation helpers to make lines shorter
local validateURL = post_helper.validateURL
local validateBoolean = post_helper.validateBoolean
local validateStringMAC = post_helper.validateStringIsMAC
local validateStringLenInRange = post_helper.getValidateStringLengthInRange
local validateLXC = post_helper.validateLXC
local validateQTN = post_helper.validateQTN
local smartWifi = proxy.get("rpc.wireless.SmartWiFi.Active")
local smartWifiPhase = proxy.get("rpc.wireless.SmartWiFi.Phase")
local site = ""
local keywordsData, keywordsHelpmsg
local keywordsColumns, keywordsOptions, keywordsValid = {}, {}, {}
local smartWifiAlert = T"Your Smart Wi-Fi service is active and managing your existing Wi-Fi and Parental Control settings. You can override your Wi-Fi and Parental settings in the Smart Wi-Fi App."

function getURLDomain(site)
  --extract only domain part in URL
  site = site:match("[%w]+://([^/ ]*)") or site:match("([^/ ]*)") or site
  -- check if the site starts with www then remove it from URL.
  return site:match("^www%.(%S+)") or site
end

local function isAcceptableURL(value)
  if not value or value == "" then
    return nil, T"Invalid URL"
  end
  return validateURL(getURLDomain(value))
end

-- In UCI
-- config 'URLfilter'
--        option 'site' 'xxx.com'
--        option 'device' 'IPaddr (or "All")'

-- In Transformer
-- uci.parental.general.enable
-- uci.parental.general.exclude
-- uci.parental.@URLfilter[i].site
-- uci.parental.@URLfilter[i].device

local hostsMac = {}
for friendlyName, _ in pairs(hosts_ac) do
  local mac = match(friendlyName, "%[(.*)%]")
  hostsMac[#hostsMac + 1] = {mac, mac}
end
-- To add single device custom option is used
hostsMac[#hostsMac + 1] = {"custom", T"custom"}

local uciParentalpath = "uci.parental.URLfilter.@."
local parentalColumns = {
  {
    header = T"MAC Address",
    name = "devicesMac",
    param = "mac",
    type = "select",
    values = hostsMac,
    attr = { input = { class = "span2", maxlength="17", id="leaseMac"}, autocomplete=hostsMac }
  },
  {
    header = T"Site",
    name = "site",
    param = "site",
    type = "text",
    attr = { input = { class="span2" } }
  },
  {
    header = T"Device",
    name = "device",
    param = "device",
    type = "select",
    default = "All",
    values = {
      {"all", "All"},
      {"single", "Single"},
    },
    attr = { select = { class= "span2" } }
  },
}

local parentalOptions = {
  tableid         = "URLfilter",
  basepath        = uciParentalpath,
  createMsg       = T"Add New Site",
  canAdd          = true,
  canDelete       = true,
  canApply        = true,
  canEdit         = true,
  objectName	  = uniqueKey,
  addNamedObject  = true
}

local function validateMAC(macValue, object, key)
  -- To skip the MAC validation check if device is "All"
  if object.device ~= "all" then
    local isMac, errInMac = post_helper.getAndValidation(validateStringMAC, validateQTN, validateLXC)(macValue, object, key)
    if not isMac then
      return nil, errInMac
    end
  end
  return true
end

local entriesValid = {
  ["site"] = isAcceptableURL,
  ["devicesMac"] = validateMAC
}

local parentalFilter = function(data)
  local site = data.site
  --removes extra space
  site = gsub(site, " ", "")
  --extract only domain part in URL
  if site:match("://") then
    site = site:match("//([^/]+)")
  end
  -- check that the site has www, then remove trailing path information from URL.
  if site:match("www") then
    site = site:match("%.(%S+)")
  end
  -- if site contains '/' then remove trailing path information from URL.
  site = site:match("([^/]+)")
  data.site = site
  return true
end

if ngx.var.request_method == "GET" and ngx.req.get_uri_args().action == "smartwifi" then
  ngx.header.content_type = "application/json"
  local smart_wifi = proxy.get("rpc.wireless.SmartWiFi.Active")
  smart_wifi = smart_wifi and smart_wifi[1].value or ""
  local smart_wifi_phase = proxy.get("rpc.wireless.SmartWiFi.Phase")
  smart_wifi_phase = smart_wifi_phase and smart_wifi_phase[1].value or ""
  ngx.print(json.encode({current_state = smart_wifi,current_phase = smart_wifi_phase}))
  ngx.exit(ngx.OK)

end

local qryParams = {
  sitesEnabled = "uci.parental.general.enable"
}

local qryValid = {
  sitesEnabled = validateBoolean
}
if post_helper.isFeatureEnabled("keywordFilter", role) then
  qryParams.filterEnabled = "uci.parental.general.keywordfilter_enable"
  qryValid.filterEnabled = validateBoolean
end

local qryData, qryHelpmsg = post_helper.handleQuery(qryParams, qryValid)

local parentalData, parentalHelpmsg = post_helper.handleTableQuery(parentalColumns, parentalOptions, parentalFilter, nil, entriesValid)
-- session variable parental_site contains all the Rules
session:store("parental_site", parentalData)

if post_helper.isFeatureEnabled("keywordFilter", role) then
  --keywords table
  local keywordsPath = "uci.parental.filterkeyword.@."
  keywordsColumns = {
    {
      header = T"Keywords",
      name = "keywords",
      param = "keyword",
      type = "text",
      attr = { input = { class="span2",maxlength="19" } }
    },
  }

  keywordsOptions = {
    tableid         = "keywfilter",
    basepath        = keywordsPath,
    createMsg       = T"Add New Keywords",
    canAdd          = true,
    canDelete       = true,
    canApply        = true,
    canEdit         = true,
    maxEntries      = 25,
    objectName	    = uniqueKey,
    addNamedObject  = true
  }

  keywordsValid = {
    ["keywords"] = validateStringLenInRange(1,19),
  }

  keywordsData, keywordsHelpmsg = post_helper.handleTableQuery(keywordsColumns, keywordsOptions, nil, nil, keywordsValid)
end

local exportingAlert = {
  alert = {
    class = "alert-info",
    id = "exporting-msg"
  }
}

local textMac
if ngx.var.request_method == "POST" then
  local postData = ngx.req.get_post_args()
  local textMacIndex = tonumber(postData.index)
  if (postData.tableid == "URLfilter") and (postData.action == "TABLE-MODIFY" or postData.action == "TABLE-EDIT" or postData.action == "TABLE-ADD") then
    textMac = postData.action == "TABLE-ADD" and postData.devicesMac or (parentalData[textMacIndex] and parentalData[textMacIndex][1])
    local isDuplicate = session:retrieve("duplicateCheck")
    for _, mac in ipairs(hostsMac) do
      if textMac == mac[1] or isDuplicate == "true" and postData.device ~= "all" then
        isDuplicate = false
        break
      end
    end
    if isDuplicate then
      parentalColumns[1] = {
        header = T"MAC address",
        name = "devicesMac",
        param = "mac",
        type = "text",
        attr = { input = { class="span2", maxlength="17", id= "leaseMac", value = textMac }}
      }
    end
  end
  local function getContentname(parentalOptions)
    local objectname = parentalOptions.objectName
    if postData.action == "TABLE-MODIFY" then
      objectname = parentalOptions.changesessionindex
    end
    return objectname
  end
  if postData.device == "all" then
    proxy.set({ ["uci.parental.URLfilter.@" .. getContentname(parentalOptions) .. ".mac"] = ""})
    if postData.action ~= "TABLE-ADD" and #parentalData >= textMacIndex then
      parentalData[textMacIndex][1] = ""
    end
  else
    local custom = true
    for _, mac in pairs(hostsMac) do
      if textMac == mac[1] then
        custom = false
      end
    end
    if custom then
      if (textMac ~= nil) and (textMac ~= "") then
        hostsMac[#hostsMac][1] = textMac:untaint()
        hostsMac[#hostsMac][2] = textMac:untaint()
        hostsMac[#hostsMac + 1] = {"custom", T"custom"}
      end
    end
  end
  if postData.site and postData.site ~= "" then
    local url = postData.site:match("^(.*)/$") or postData.site
    url = getURLDomain(url)
    proxy.set({ ["uci.parental.URLfilter.@" .. getContentname(parentalOptions) .. ".site"] = url})
  end
  proxy.apply()
end
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Parental Controls", false, false, nil) ); ngx.print('\
\
<div class="modal-body update">\
');  
  local lp = require("web.lp")
  lp.setpath("/www/snippets/")
  lp.include("tabs-tod.lp")
  gettext.textdomain('webui-parental')
  ngx.print('\
');  ngx.print(ui_helper.createMessages(message_helper.popMessages()) ); ngx.print('\
  <form class="form-horizontal" method="post" action="modals/parental-modal.lp">\
  <div class="siteblock" id = "siteblock">\
  <legend>');  ngx.print( T"Site Blocking" ); ngx.print('</legend>\
  ');  ngx.print(
    ui_helper.createSwitch(T"Enabled", "sitesEnabled", qryData.sitesEnabled, nil, qryHelpmsg.sitesEnabled),
    ui_helper.createAlertBlock(T"Note:Parental control url filter will block all the webpages related to the given domain name.", exportingAlert),
    ui_helper.createTable(parentalColumns, parentalData, parentalOptions, nil, parentalHelpmsg)
  ); ngx.print('\
   </div>\
    ');  if post_helper.isFeatureEnabled("keywordFilter", role) then   ngx.print('\
      <legend>');  ngx.print( T"Keyword Filter" ); ngx.print('</legend>\
      ');  ngx.print(
        ui_helper.createSwitch(T"Enabled", "filterEnabled", qryData.filterEnabled, nil, qryHelpmsg.filterEnabled),
        ui_helper.createTable(keywordsColumns, keywordsData, keywordsOptions, nil, keywordsHelpmsg)
      ); ngx.print('\
    ');  end  ngx.print('\
  ');  if post_helper.isFeatureEnabled("smartwifi") then  ngx.print('\
      <div id="smartwifiinfo"  class="alert hide">');  ngx.print(smartWifiAlert); ngx.print('</div>\
  ');  end  ngx.print('\
  </form>\
</div>\
\
<script type=\'text/javascript\'>\
var smartwifivalue = "');  ngx.print(smartWifi and smartWifi[1].value); ngx.print('";\
var smartwifiphasevalue = "');  ngx.print(smartWifiPhase and smartWifiPhase[1].value); ngx.print('";\
var smartWifiMsg = \'');  ngx.print(smartWifiAlert); ngx.print('\';\
if($("#device").val() == "all")\
   $(\'#devicesMac\').attr(\'disabled\', true);\
$("[name =\'devicesMac\']").change(function () {\
  if ((this.value) == "custom") {\
    $(this).replaceWith($(\'<input/>\',{\'type\':\'text\', \'id\':\'devicesMac\', \'name\':\'devicesMac\'}));\
  }\
});\
\
function sitesEnabled() {\
  if ($("#sitesEnabled").val() == 0) {\
    $(\'#URLfilter\').hide();\
    $("[id=\'Add New Site\']").hide();\
  } else {\
    $(\'#URLfilter\').show();\
    $("[id=\'Add New Site\']").show();\
  }\
}\
\
$(\'.switch\').change(function(){\
  if ($("#sitesEnabled").val() == 0) {\
    sitesEnabled();\
  }\
});\
\
sitesEnabled();\
\
$("[name =\'device\']").change(function () {\
  if($("#device").val() == "all"){\
    $(\'#devicesMac, #leaseMac\').attr(\'disabled\', true).attr(\'readonly\');\
  }\
  else\
    $(\'#devicesMac, #leaseMac\').attr(\'disabled\', false).removeAttr(\'readonly\');\
});\
var textMac = "');  ngx.print( textMac ); ngx.print('";\
if ($("[name =\'devicesMac\']").hasClass("error")){\
 $("[name =\'devicesMac\']").prepend(new Option(textMac, textMac, true, true));\
};\
\
function getSmartWifiStatus(){\
$.get("/modals/parental-modal.lp?action=smartwifi",function(data){\
  if (data.current_state == "1" && data.current_phase == "2"){\
     $("#siteblock").addClass("hide");\
     $("#smartwifiinfo").removeClass("hide");\
     $("#save-config").prop("disabled",true);\
     $(\'#save-config\').prop(\'title\', smartWifiMsg);\
  }\
  if (data.current_state == "0" || (data.current_state == "1" && data.current_phase == "1")){\
     $("#siteblock").removeClass("hide");\
     $("#smartwifiinfo").addClass("hide");\
  }\
});\
}\
\
');  if post_helper.isFeatureEnabled("smartwifi") then   ngx.print('\
 if (smartwifivalue == "1" && smartwifivalue != "nil" && smartwifiphasevalue == "2" && smartwifiphasevalue != "nil"){\
 $("#siteblock").addClass("hide");\
 $("#smartwifiinfo").removeClass("hide");\
 }\
 setInterval(getSmartWifiStatus, 3000);\
');  end  ngx.print('\
\
</script>\
\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 