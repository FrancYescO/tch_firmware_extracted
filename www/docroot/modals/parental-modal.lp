--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-parental')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local table, ipairs = table, ipairs
local uinetwork = require("web.uinetwork_helper")
local hosts_ac, hosts_ac_v6 = uinetwork.getAutocompleteHostsList()
local match, format, gsub  = string.match, string.format, string.gsub
local tonumber, tostring = tonumber, tostring
local validateURL = post_helper.validateURL
local session = ngx.ctx.session
local uniqueKey = post_helper.getRandomKey()
local proxy = require("datamodel")

-- Shortcuts to validation helpers to make lines shorter
local vB = post_helper.validateBoolean
local vSII = post_helper.getAndValidation(post_helper.validateStringIsIP, post_helper.validateLXC)
local vSIM = post_helper.getAndValidation(post_helper.validateStringIsMAC, post_helper.validateLXC)
local gVSLIR = post_helper.getValidateStringLengthInRange

local site = ""

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

local hostlist = {}
local hosts_mac = {}
for k, v in pairs(hosts_ac) do
  local mac = match(k, "%[(.*)%]")
  hosts_mac[#hosts_mac+1] = {mac, mac}
end
hosts_mac[#hosts_mac+1] = {"custom",T"custom"}

local qry_params = {
    sites_enabled = "uci.parental.general.enable",
    --sites_exclude = "uci.parental.general.exclude",
    filter_enabled = "uci.parental.general.keywordfilter_enable",-- The keyword filter
}

local qry_valid = {
    sites_enabled = vB,
    filter_enabled = vB,-- The keyword filter
}

local qry_data, qry_helpmsg = post_helper.handleQuery(qry_params, qry_valid)

local uci_parental_path = "uci.parental.URLfilter.@."
local parental_columns = {
 {
        header = T"MAC Address",
        name = "devices_mac",
        param = "mac",
        type = "select",
        values = hosts_mac,
        attr = { input = { class = "span2",maxlength="17",id="lease_mac"}, autocomplete=hosts_mac },
    },
    {
        header = T"Site",
        name = "site",
        param = "site",
        type = "text",
        attr = { input = { class="span2" } },
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
        attr = { select = { class= "span2" } },
    },
}

local parental_options = {
    tableid         = "URLfilter",
    basepath        = uci_parental_path,
    createMsg       = T"Add New Site",
    canAdd          = true,
    canDelete       = true,
    canApply        = true,
    canEdit         = true,
    objectName	    = uniqueKey,
    addNamedObject   = true,
}

local function validateMAC(value, object, key)
    -- To skip the MAC validation check if device is "All"
    if  object.device ~= "all" then
        local valid, error = vSIM(value,object,key)
        if valid then
           return true
        else
           return nil, error
        end
    else
       return true
    end
end

local entries_valid = {
    ["site"] = isAcceptableURL,
    ["devices_mac"] = validateMAC,
}

local parental_filter = function(data)
  local site = data["site"]
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
  data["site"] = site
  return true
end

--keywords table
local keywords_path = "uci.parental.filterkeyword.@."
local keywords_columns = {
    {
        header = T"Keywords",
        name = "keywords",
        param = "keyword",
        type = "text",
        attr = { input = { class="span2",maxlength="19" } },
    },
}
local keywords_options = {
    tableid         = "keywfilter",
    basepath        = keywords_path,
    createMsg       = T"Add New Keywords",
    canAdd          = true,
    canDelete       = true,
    canApply        = true,
    canEdit         = true,
    maxEntries      = 25,
    objectName	    = uniqueKey,
    addNamedObject  = true,
}

local keywords_valid = {
    ["keywords"] = gVSLIR(1,19),
}

local parental_data, parental_helpmsg = post_helper.handleTableQuery(parental_columns, parental_options, parental_filter, nil, entries_valid)
-- session variable parental_site contains all the Rules
session:store("parental_site", parental_data)
local keywords_data, keywords_helpmsg = post_helper.handleTableQuery(keywords_columns, keywords_options, nil, nil, keywords_valid)
local exporting_alert = {
        alert = {
          class = "alert-info",
          id = "exporting-msg"
        }
      }
local text_mac
if ngx.var.request_method == "POST" then
  post_data = ngx.req.get_post_args()
  if (post_data.tableid == "URLfilter") and ( post_data.action == "TABLE-MODIFY" or  post_data.action == "TABLE-EDIT"  or  post_data.action == "TABLE-ADD") then
    local text_mac_index = tonumber(post_data.index)
    if  post_data.action == "TABLE-ADD" then
      text_mac = post_data["devices_mac"]
    else
      text_mac = parental_data[text_mac_index][1]
    end
    local isDuplicate = session:retrieve("duplicateCheck")
    for _, mac in ipairs(hosts_mac) do
      if text_mac == mac[1] or isDuplicate == "true" and post_data.device ~= "all" then
        parental_columns[1] = {
        header = T"MAC address",
        name = "devices_mac",
        param = "mac",
        type = "text",
        attr = { input = { class="span2", maxlength="17", id= "lease_mac", value = text_mac }},
      }
        break
      end
    end
  end
  local function get_content_name(parental_options)
    local objectname = parental_options.objectName
    if post_data.action == "TABLE-MODIFY" then
       objectname = parental_options.changesessionindex
    end
    return objectname
  end
  if post_data.device == "all" then
    proxy.set({ ["uci.parental.URLfilter.@" .. get_content_name(parental_options) .. ".mac"] = ""})
    proxy.apply()
  end
  if post_data.site and post_data.site ~= "" then
    local url = post_data.site:match("^(.*)/$") or post_data.site
    url = getURLDomain(url)
    proxy.set({ ["uci.parental.URLfilter.@" .. get_content_name(parental_options) .. ".site"] = url})
    proxy.apply()
  end
end

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. uri:match("/([^/]+)%.lp") }
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
    <legend>');  ngx.print( T"Site Blocking" ); ngx.print('</legend>\
');  ngx.print(
        ui_helper.createSwitch(T"Enabled", "sites_enabled", qry_data["sites_enabled"], nil, qry_helpmsg["sites_enabled"]),
        --ui_helper.createSwitch(T"Exclude Mode", "sites_exclude", qry_data["sites_exclude"], nil, qry_helpmsg["sites_exclude"]),
        ui_helper.createAlertBlock(T"Note:Parental control url filter will block all the webpages related to the given domain name.",exporting_alert),
        ui_helper.createTable(parental_columns, parental_data, parental_options, nil, parental_helpmsg)
); ngx.print('\
    <legend>');  ngx.print( T"Keyword Filter" ); ngx.print('</legend>\
');  ngx.print(
        ui_helper.createSwitch(T"Enabled", "filter_enabled", qry_data["filter_enabled"], nil, qry_helpmsg["filter_enabled"]),
        ui_helper.createTable(keywords_columns, keywords_data, keywords_options, nil, keywords_helpmsg)
); ngx.print('\
  </form>\
</div>\
<script type=\'text/javascript\'>\
if($("#device").val() == "all")\
   $(\'#devices_mac\').attr(\'disabled\', true);\
$("[name =\'devices_mac\']").change(function () {\
    if ((this.value) == "custom") {\
          $(this).replaceWith($(\'<input/>\',{\'type\':\'text\', \'id\':\'devices_mac\', \'name\':\'devices_mac\'}));\
    }\
});\
\
function sitesEnabled() {\
  if ($("#sites_enabled").val() == 0) {\
    $(\'#URLfilter\').hide();\
    $("[id=\'Add New Site\']").hide();\
  } else {\
    $(\'#URLfilter\').show();\
    $("[id=\'Add New Site\']").show();\
  }\
}\
\
$(\'.switch\').change(function(){\
  if ($("#sites_enabled").val() == 0) {\
    sitesEnabled();\
  }\
});\
\
sitesEnabled();\
\
$("[name =\'device\']").change(function () {\
    if($("#device").val() == "all"){\
        $("[name =\'devices_mac\']").replaceWith($(\'<input/>\',{\'type\':\'text\', \'id\':\'devices_mac\', \'name\':\'devices_mac\'}));\
        $(\'#devices_mac, #lease_mac\').attr(\'readonly\',\'readonly\');\
        $(\'#lease_mac, #devices_mac\').attr(\'value\', "");\
    }\
    else\
        $(\'#devices_mac, #lease_mac\').attr(\'disabled\', false).removeAttr(\'readonly\');\
});\
var text_mac = "');  ngx.print( text_mac ); ngx.print('";\
$(".btn-table-edit").click(function() {\
  setTimeout(function() {\
    $("[name =\'devices_mac\']").prepend(new Option(text_mac, text_mac, true, true));\
  },200);\
});\
if ($("[name =\'devices_mac\']").hasClass("error")){\
 $("[name =\'devices_mac\']").prepend(new Option(text_mac, text_mac, true, true));\
};\
</script>\
\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
'); 