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
local tod = require("parental_helper").getTod()

-- For DNS
local bit = require("bit")
local proxy = require("datamodel")
local pairs, table = pairs, table
local content, helpmsg
local match, format  = string.match, string.format


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


local tod_columns, tod_default, tod_valid, tod_sort_func, tod_mac_to_hostname =
      tod.columns, tod.default, tod.valid, tod.sort_func, tod.mac_to_hostname

local tod_options = {
    tableid     = "tod",
    basepath    = "uci.tod.host.",
    createMsg   = T"Add New Rule",
    canAdd      = true,
    canDelete   = true,
    canApply    = true,
    canEdit     = true,
    sorted      = tod_sort_func,
}
local tod_data, tod_helpmsg = post_helper.handleTableQuery(tod_columns, tod_options, nil, tod_default, tod_valid)
tod_mac_to_hostname(tod_data)
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
-- DNS server part--------------------
local getargs = ngx.req.get_uri_args()
local getintf = getargs.intf

local curintf = "lan"
-- Get all the LAN interfaces
local net_intfs_path = "rpc.network.interface."
local all_intfs = content_helper.convertResultToObject(net_intfs_path .. "@.", proxy.get(net_intfs_path))
local lan_intfs = {}
for k,v in ipairs(all_intfs) do
    if v.type == "lan" then
        lan_intfs[#lan_intfs + 1] = v.paramindex
    end
    if v.paramindex == getintf then
        curintf = v.paramindex
    end
end

local syshosts_data = proxy.get("sys.hosts.host.")

local cur_dhcp_intf = "lan"
local dhcp_intfs_path = "uci.dhcp.dhcp."
local all_dhcp_intfs = content_helper.convertResultToObject(dhcp_intfs_path .. "@.", proxy.get(dhcp_intfs_path))
local lan_dhcp_intfs = {}

for k,v in ipairs(all_dhcp_intfs) do
    if v.interface == curintf then
        cur_dhcp_intf = v.paramindex
        break
    end
end
-- Standard parameters
local mapParams = {
    dhcpStart = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".start",
    dhcpLimit = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".limit",
    dhcpState = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".ignore",
    leaseTime = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".leasetime",
    localdevIP = "uci.network.interface.@" .. curintf .. ".ipaddr",
    localdevmask = "uci.network.interface.@" .. curintf .. ".netmask",
    localIPv6 = "uci.network.interface.@" .. curintf .. ".ipv6",
    localIP6assign = "uci.network.interface.@" .. curintf .. ".ip6assign",
}

local dnsIndex
local dhcp = {}
local baseDHCPOptions = "uci.dhcp.dhcp.@" .. cur_dhcp_intf .. ".dhcp_option."
local dnsServer = ""
local dnsRemoved = false

-- Check if there is a custom DNS server, if so, then retrieve its index
-- we'll update the parameters list to include it for retrieval
content_helper.addListContent(dhcp, { options = baseDHCPOptions } )
dnsIndex = #dhcp.options + 1 -- by default index is end of list

for i,v in ipairs(dhcp.options) do
    if v:find("^6,") == 1 then
        dnsServer = v:sub(3)
        dnsIndex = #dhcp.options
    end
end

local function validateDNS(value, object, key)
    -- If there is no value, then we want to delete the dhcp_option if it exists
    -- Otherwise, we want to check the value is an IP
    if value == "" then
        -- if the key does not exist, no harm done
        proxy.del(mapParams[key]:sub(1,-6))
        -- remove the value, there is nothing to set
        object[key] = nil
        dnsRemoved = true
        return true
    else
        local dnsservers = {}
        local Index = 0
        local lastIndex = 0
        local dns = {}
        for word in string.gmatch(value, '([^,]+)') do
          dns[#dns + 1] = word
          local valid, helpmsg = post_helper.validateStringIsIP(word, object, key)
          if not valid then
            return valid, helpmsg
          end
        end
        if #dns > 3 then
            return nil, nil
        end
        object[key] = "6," .. value -- DHCP option for DNS server is option 6
        return true
    end
end

local mapValid = {
    dnsServer = validateDNS,
}

if (dnsIndex < #dhcp.options +1) or ( (ngx.var.request_method == "POST") and (ngx.req.get_post_args().action == "SAVE") ) then
    mapParams["dnsServer"] = baseDHCPOptions .. "@" .. dnsIndex .. ".value"
end
if (dnsIndex == #dhcp.options + 1) and (ngx.var.request_method == "POST") and (ngx.req.get_post_args().action == "SAVE") then
    proxy.add(baseDHCPOptions)
end
content, helpmsg = post_helper.handleQuery(mapParams, mapValid)

-- post_helper restores values that have been removed during validation
if dnsRemoved then
    content["dnsServer"] = ""
end
if content["dnsServer"] == nil then
    local localIP = proxy.get("uci.network.interface.@" .. curintf .. ".ipaddr")[1].value
    content["dnsServer"] = localIP
else
    if content["dnsServer"]:find("^6,") == 1 then
      content["dnsServer"] = (content["dnsServer"] or ""):sub(3) -- the dhcp option will contain "6," at the start
    end
end
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. uri:match("/([^/]+)%.lp") }
%>

<% =ui_helper.createHeader(T"Parental Controls", false, false, nil) %>

<div class="modal-body update">
<% =ui_helper.createMessages(message_helper.popMessages()) %>
  <form class="form-horizontal" method="post" action="modals/parental-modal.lp">
<!-- Field for DNS change -->	 
 <legend><%= T"DNS Server Filtering" %></legend>
  <%= 
  ui_helper.createInputText(T"DNS server", "dnsServer", content["dnsServer"], helpmsg["dnsServer"])
  %>
  
    <legend><%= T"Site Blocking" %></legend>
	<%=

        ui_helper.createSwitch(T"Enabled", "sites_enabled", qry_data["sites_enabled"], nil, qry_helpmsg["sites_enabled"]),
        --ui_helper.createSwitch(T"Exclude Mode", "sites_exclude", qry_data["sites_exclude"], nil, qry_helpmsg["sites_exclude"]),
        ui_helper.createTable(parental_columns, parental_data, parental_options, nil, parental_helpmsg)

%>
    <legend><%= T"Time of Day Access Control" %></legend>
<%= ui_helper.createTable(tod_columns, tod_data, tod_options, nil, tod_helpmsg) %>
  </form>
</div>

<script type="text/javascript">
    $(function () {
        var opt = {
            theme: 'android-ics light',
            display: 'bubble',
            mode: 'scroller',
            headerText: false,
            timeFormat: 'HH:ii',
            stepMinute: 15
        };
        $("#starttime").mobiscroll().time(opt);
        $("#stoptime").mobiscroll().time(opt);
    });
</script>
<%= ui_helper.createFooter() %>

