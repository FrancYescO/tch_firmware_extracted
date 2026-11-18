<%
-- Localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local message_helper = require("web.uimessage_helper")
local post_helper = require("web.post_helper")
local type, setmetatable, random = type, setmetatable, math.random
local table, ipairs, istainted, format = table, ipairs, string.istainted, string.format

local logdata = proxy.get("sys.log.devicelog")
logdata = logdata[1].value

local log_columns = {
    {
        header = T"Date",
        name = "date",
        param = "date",
        type = "text",
        attr = { input = {  class="span1" } },
    },
    {
        header = T"Facility",
        name = "facility",
        param = "facility",
        type = "text",
        attr = { input = { class="span1" } },
    },
    {
        header = T"Process",
        name = "process",
        param = "process",
        type = "text",
        attr = { select = { class="span1" } },
    },
    {
        header = T"Message",
        name = "message",
        param = "message",
        type = "text",
        attr = { select = { class="span6" } },
    },
}

local log_options = {
    tableid = "logviewer",
    basepath = "sys.log.",
    canAdd = false,
    canEdit = false,
    canDelete = false,
}

local getargs = ngx.req.get_uri_args()
local current_process = getargs["process"]
if current_process == "" then
    current_process = nil
end

local log_array = {}
local processes_list = {}
local pattern = "([^%s]+%s+%d+ %d+:%d+:%d+) [^%s]+ ([^%s]+) ([^%s]+): ([^\n]+)"

logdata:gsub(pattern, function(date, facility, process, message)
    local p = string.match(process, "[^%[]+")
    if not current_process or p == current_process then
        log_array[#log_array+1] = { date, facility, process, message }
    end
    if p then
        processes_list[p] = true
    end
end)

-- Reverse table to show most recent first
local size = #log_array
local t = {}
for i,v in ipairs(log_array) do
    t[size-i] = v
end
log_array = t

local processes_select = {}
for k in pairs(processes_list) do
    processes_select[#processes_select+1] = { k, k }
end

table.sort(processes_select, function(a,b)
    return a[1] < b[1]
end)

table.insert(processes_select, 1, {"", T"Everything"})

%>

<% ngx.print(ui_helper.createHeader(T"Management", false, true, 5)) %>

<div class="modal-body update no-save">

<%
local tabs = {
    {
        desc = T"User Manager",
        target = "modals/usermgr-modal.lp",
    },
    {
        desc = T"Log Viewer",
        active = "active",
        target = "modals/logviewer-modal.lp",
    },
}
ngx.print(ui_helper.createModalTabs(tabs))
%>

<form class="form-horizontal" method="post" action="<%= ngx.var.request_uri %>">
<%

ngx.print(ui_helper.createInputSelect(T"Filter", "process", processes_select, current_process or "", nil, nil))
ngx.print(ui_helper.createMessages(message_helper.popMessages()))
%>

<fieldset>

<%
ngx.print(ui_helper.createTable(log_columns, log_array, log_options, nil, nil))
%>

</fieldset>
</form>
</div>
<div class="modal-footer">
    <div id="modal-no-change">
        <div class="btn btn-primary btn-large" data-dismiss="modal"><%= T"Close" %></div>
    </div>
</div>
<script type="text/javascript">
    $('select[name="process"]').on("change", function() {
        var process = $(this).val()
        tch.loadModal("/modals/logviewer-modal.lp?process=" + process)
    });
</script>
