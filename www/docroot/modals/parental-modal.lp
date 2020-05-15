--pretranslated: do not change this file
 
-- Localization
gettext.textdomain('webui-parental')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local table, ipairs = table, ipairs
local uinetwork = require("web.uinetwork_helper")
local hosts_ac = require("parental_helper").get_hosts_ac()
hosts_ac["All Devices"] = "All"
local match, format = string.match, string.format
local uniqueKey = post_helper.getRandomKey()
local validateURL = post_helper.validateURL

-- Shortcuts to validation helpers to make lines shorter
local vB = post_helper.validateBoolean
local vNES = post_helper.validateNonEmptyString
local vSIM = post_helper.validateStringIsMAC

-- In UCI
-- config 'URLfilter'
--        option 'site' 'xxx.com'
--        option 'device' 'IPaddr (or "All")'

-- In Transformer
-- uci.parental.general.enable
-- uci.parental.general.exclude
-- uci.parental.@URLfilter[i].site
-- uci.parental.@URLfilter[i].device

local qry_params = {
    sites_enabled = "uci.parental.general.enable",
}

local qry_valid = {
    sites_enabled = vB,
}

local qry_data, qry_helpmsg = post_helper.handleQuery(qry_params, qry_valid)

local uci_parental_path = "uci.parental.URLfilter.@."
local parental_columns = {
    {
        header = T"Site",
        name = "site",
        param = "site",
        type = "text",
        attr = { input = { class="span2" } },
    },
    {
        header = T"Device",
        name = "mac",
        param = "mac",
        type = "text",
        attr = { input = { class="span2", maxlength="17"}, autocomplete=hosts_ac },
    },
    {
        header = T"Action",
        name = "act",
        param = "action",
        type = "select",
        values = {
          { "DROP", T"Block"},
        },
        attr = { input = { class="span2" } },
    },
}

local function sort_func(a, b)
  -- associated with parental_columns,
  -- 1) When MAC are different, sort by MAC
  -- 2) when MAC are the same, sort by site
  if a["mac"] == b["mac"] then
     return a["site"] < b["site"]
  else
     return a["mac"] < b["mac"]
  end
end

--[[
   The following function used to validate the duplicate entries while adding or editing on parental table.
   We will throw the duplicate error if any rows containing all 2 values below are duplicated
   Sample:- Site                  Mac
            www.baidu.com         fc:75:16:e1:c5:f9
            www.google.com        fc:75:16:e1:c5:f9
            www.baidu.com         fc:75:16:e1:c5:f9
   In above example the 1st and 3rd rows are exactly duplicated. In this case we throw the error message as duplicated.
   If anyone of the value of row is different then we dont consider as duplicated row.
]]

local function rulesDuplicateCheck(data)
  local postdata = ngx.req.get_post_args()
  local action = postdata.action
  local index
  if action == "TABLE-ADD" then
    index = #data
  elseif action == "TABLE-MODIFY" then
    index = tonumber(postdata.index)
  end

  if index and data[index] then
    local site, client = data[index][1], data[index][2]
    for i,v in ipairs(data) do
      if v[1] == site and v[2] == client and i ~= index then
        return nil, { site = "Conflict rule exists" }
      end
    end
  end
  return true
end
local function parental_filter(data)
  if data.action == "ACCEPT" then
    return {
      canDelete = true,
      canEdit = false
    }
  end
  return true
end

local parental_options = {
    tableid         = "URLfilter",
    basepath        = uci_parental_path,
    createMsg       = T"Add New Site",
    canAdd          = true,
    canDelete       = true,
    canApply        = true,
    canEdit         = true,
    sorted          = sort_func,
    valid           = rulesDuplicateCheck,
    objectName      = uniqueKey,
    addNamedObject  = true,
}

local function validateSite(value, object, key)
  if not value or value == "" then
     return nil , T"InvalidURL"
   end
    return validateURL(getURLDomain(value))
end

function getURLDomain(site)
  site = site:match("[%w]+://([^/ ]*)") or site:match("([^/ ]*)") or site
  -- check if the site starts with www then remove it from URL.
    return site:match("^www%.(%S+)") or site
end

function validateStringIsMAC(value, object, key)
    -- confirm the entered value is a valid MAC address or the special "All" entry
    local valid, msg = vSIM(value)
    if valid then
        return true
    end
    if value == "All" then
        object["mac"] = ""
        return true
    end
    return nil, msg .. " or \"All\""
end

local urlfilter_valid = {
    ["site"] = validateSite,
    ["mac"] = validateStringIsMAC,
}

local parental_data, parental_helpmsg = post_helper.handleTableQuery(parental_columns, parental_options, parental_filter, nil, urlfilter_valid)

for _,v in ipairs(parental_data) do
  if v[3] == "ACCEPT" then
    v[3] = "Allow"
  end
end
-- mangle output, when a host was blocked to access all sites, do not display empty in the site column
for _,v in ipairs(parental_data) do
   if v[1] == "" then
      v[1] = all_sites
   end
   if v[2] == "" then
      v[2] = T"All"
   end
end

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. format("%s", uri:match("/([^/]+)%.lp")) }
  ngx.print('\
\
');  ngx.print(ui_helper.createHeader(T"Parental Controls", true, false, nil, help_link) ); ngx.print('\
');  ngx.print(ui_helper.createMessages(message_helper.popMessages()) ); ngx.print('\
\
<div class="modal-body update">\
  <form class="form-horizontal" method="post" action="modals/parental-modal.lp">\
    <legend>');  ngx.print( T"Site Blocking" ); ngx.print('</legend>\
');  ngx.print(
        ui_helper.createSwitch(T"Enabled", "sites_enabled", qry_data["sites_enabled"], nil, qry_helpmsg["sites_enabled"]),
        ui_helper.createTable(parental_columns, parental_data, parental_options, nil, parental_helpmsg)
); ngx.print('\
  </form>\
</div>\
<script>\
 var poperrorMsg = \'');  ngx.print(T"Same site cannot be added for multiple times"); ngx.print('\';\
 var errorMsg = \'');  ngx.print(T"Please enter the valid URL"); ngx.print('\';\
</script>\
');  ngx.print( ui_helper.createFooter() ); ngx.print('\
\
'); 