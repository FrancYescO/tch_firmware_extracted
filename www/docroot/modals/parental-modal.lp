<%
-- Localization
gettext.textdomain('webui-parental')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local table, ipairs = table, ipairs
local uinetwork = require("web.uinetwork_helper")
local hosts_ac = uinetwork.getAutocompleteHostsListIPv4()

-- Shortcuts to validation helpers to make lines shorter
local vB = post_helper.validateBoolean
local vNES = post_helper.validateNonEmptyString
local vSII = post_helper.validateStringIsIP

local device = "All"
local site = ""
if ngx.var.request_method == "POST" then
    local content = ngx.req.get_post_args()

    -- os.execute("/etc/init.d/urlfilterd-tch stop")
    -- os.execute("/etc/init.d/urlfilterd-tch start")
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

--
local qry_params = {
    sites_enabled = "uci.parental.general.enable",
    --sites_exclude = "uci.parental.general.exclude",
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
        name = "device",
        param = "device",
        type = "text",
        default = "All",
        attr = { input = { class="span2", maxlength="15"}, autocomplete=hosts_ac },
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
}

local function validateDevice(value, object, key)
    -- confirm the entered value is a valid IP address or the special "All" entry
    if vSII(value) or (value == "All") then
        return true
    end

    -- the entry is not valid, mark it and return the help string
    return nil, T"Invalid device, entry must be either a valid IP or \"All\""
end

local entries_valid = {
    ["site"] = vNES,
    ["device"] = validateDevice,
}

local parental_data, parental_helpmsg = post_helper.handleTableQuery(parental_columns, parental_options, nil, nil, entries_valid)

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. uri:match("/([^/]+)%.lp") }
%>

<% =ui_helper.createHeader(T"Parental Controls", false, false, nil) %>

<div class="modal-body update">
<% =ui_helper.createMessages(message_helper.popMessages()) %>
  <form class="form-horizontal" method="post" action="modals/parental-modal.lp">
    <legend><%= T"Site Blocking" %></legend>
<%=
        ui_helper.createSwitch(T"Enabled", "sites_enabled", qry_data["sites_enabled"], nil, qry_helpmsg["sites_enabled"]),
        --ui_helper.createSwitch(T"Exclude Mode", "sites_exclude", qry_data["sites_exclude"], nil, qry_helpmsg["sites_exclude"]),
        ui_helper.createTable(parental_columns, parental_data, parental_options, nil, parental_helpmsg)
%>
  </form>
</div>

<%= ui_helper.createFooter() %>

