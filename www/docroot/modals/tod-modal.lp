<%
-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
--local tprint = require("tch.tableprint")
local match = string.match

local tod = require("parental_helper").getTod()
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
--tprint(tod_data)
tod_mac_to_hostname(tod_data)


local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. uri:match("/([^/]+)%.lp") }
%>

<%=ui_helper.createHeader(T"Time of Day", true, false, nil, help_link) %>
<%=ui_helper.createMessages(message_helper.popMessages()) %>

<div class="modal-body update">
  <form class="form-horizontal" method="post" action="/modals/tod-modal.lp">
    <legend><%= T"Time of day access control" %></legend>
    <%=
      ui_helper.createTable(tod_columns, tod_data, tod_options, nil, tod_helpmsg)
    %>
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
