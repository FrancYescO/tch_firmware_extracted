<%
-- Localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local table, ipairs = table, ipairs
local uinetwork = require("web.uinetwork_helper")
local hosts_ac = require("parental_helper").get_hosts_ac()
--local tprint = require("tch.tableprint")
local match = string.match

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

local uci_parental_path = "uci.parental.URLfilter."
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
          { "ACCEPT", T"Allow"},
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

local parental_options = {
    tableid         = "URLfilter",
    basepath        = uci_parental_path,
    createMsg       = T"Add New Site",
    canAdd          = true,
    canDelete       = true,
    canApply        = true,
    canEdit         = true,
    sorted          = sort_func,
}

local all_sites = T"All sites"
local function validateSite(value, object, key)
  -- block all sites, uci value should be empty
  if value:lower() == all_sites:lower() then
     object["site"] = ""
  end
  -- we currently no restriction for site
  return true
end

local urlfilter_valid = {
    ["site"] = validateSite,
    ["device"] = vSIM,
}

local parental_data, parental_helpmsg = post_helper.handleTableQuery(parental_columns, parental_options, nil, nil, urlfilter_valid)
-- mangle output, when a host was blocked to access all sites, do not display empty in the site column
for _,v in ipairs(parental_data) do
   if v[1] == "" then
      v[1] = all_sites
   end
end

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. uri:match("/([^/]+)%.lp") }
%>

<% =ui_helper.createHeader(T"Parental Controls", true, false, nil, help_link) %>
<% =ui_helper.createMessages(message_helper.popMessages()) %>

<div class="modal-body update">
  <form class="form-horizontal" method="post" action="modals/parental-modal.lp">
    <legend><%= T"Site Blocking" %></legend>
<%=
        ui_helper.createSwitch(T"Enabled", "sites_enabled", qry_data["sites_enabled"], nil, qry_helpmsg["sites_enabled"]),
        ui_helper.createTable(parental_columns, parental_data, parental_options, nil, parental_helpmsg)
%>
  </form>
</div>

<%= ui_helper.createFooter() %>

