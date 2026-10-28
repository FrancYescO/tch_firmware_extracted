<%
-- Localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local match, format = string.match, string.format
local tod = require("parental_helper").getTod()
local tod_columns, tod_default, tod_valid, tod_sort_func, tod_mac_to_hostname =
      tod.columns, tod.default, tod.valid, tod.sort_func, tod.mac_to_hostname

local tableEquals = content_helper.tableEquals
--Returns nil if duplicate, otherwise true
local function hasNoDuplicates(contents)
local result
  for index = 1, #contents - 1 do
    local content = contents[index]
    for comp_index = index+1, #contents do
      if tableEquals(content, contents[comp_index]) then
        message_helper.pushMessage(T"Duplicate contents are not allowed", "error")
        return
      end
    end
  end
  return true
end
-- validateContent will provide contents table which consists of Host Name, Start time ,Stop time and Days of weeks
local function validateContent(data)
  local contents = {}
  for _,v in ipairs(data) do
    -- mac, start, stop and days will be stored in a table
    contents[#contents+1] = {v[2],v[3],v[4],v[6]}
  end
  return hasNoDuplicates(contents)
end

local tod_options = {
    tableid     = "tod",
    basepath    = "uci.tod.host.",
    createMsg   = T"Add New Rule",
    canAdd      = true,
    canDelete   = true,
    canApply    = true,
    canEdit     = true,
    sorted      = tod_sort_func,
    valid       = validateContent,
}

local tod_data, tod_helpmsg = post_helper.handleTableQuery(tod_columns, tod_options, nil, tod_default, tod_valid)
tod_mac_to_hostname(tod_data)
%>

<%=ui_helper.createHeader(T"Time of Day") %>
<%=ui_helper.createMessages(message_helper.popMessages()) %>

<div class="modal-body update">

<%
    local lp = require("web.lp")
    lp.setpath("/www/snippets/")
    lp.include("tabs-tod.lp")
%>

  <form class="form-horizontal" method="post" action="/modals/tod-modal.lp">
    <legend><%= T"Time of day access control" %></legend>
    <%=
      ui_helper.createTable(tod_columns, tod_data, tod_options, nil, tod_helpmsg)
    %>
    <%if ngx.var.request_method == "POST" and (ngx.req.get_post_args().action == "TABLE-NEW" or ngx.req.get_post_args().action == "TABLE-EDIT") then%>
      <script type="text/javascript">
        var warning = '<div class="control-group"><div style="padding-top: 12px;" class="controls"><span class="alert">'
                      +'The DUT will block/allow all the time if none of the days are selected</span></div></div>';
        $('#stoptime').parent().parent().after(warning);
      </script>
    <%end%>
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
