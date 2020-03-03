<ul class="nav nav-tabs">

<%

gettext.textdomain('webui-voice')

local ipairs, string = ipairs, string
local items
if ngx.ctx.session:getrole()=="guest" then
   items = {
       {"mmpbx-info-modal.lp", T"Information"},
       {"mmpbx-global-modal.lp", T"Global"},
       {"mmpbx-contacts-modal.lp", T"Phone Book"},
       {"mmpbx-profile-modal.lp", T"Phone Numbers"},
       {"mmpbx-service-modal.lp", T"Service"},
       {"mmpbx-log-modal.lp", T"Call Log"},
       {"mmpbx-dect-modal.lp", T"DECT"},
   }
else
   items = {
       {"mmpbx-info-modal.lp", T"Information"},
       {"mmpbx-contacts-modal.lp", T"Phone Book"},
       {"mmpbx-log-modal.lp", T"Call Log"},
       {"mmpbx-dect-modal.lp", T"DECT"},
   }
end

local html = {}

local uri = ngx.var.uri
if ngx.var.args and string.len(ngx.var.args) > 0 then
    uri = uri .. "?" .. ngx.var.args
end

html[#html+1] = '<div class="loading-wrapper hide"><img src="/img/spinner.gif" /></div>'

for _,v in ipairs(items) do
    local active = ""
    if uri == ("/modals/" .. v[1]) then
        active = "active"
    end

    html[#html+1] = string.format('<li class="%s"><a href="#" class="open-modal" data-remote="/modals/%s">%s</a></li>', active, v[1], v[2])
end
ngx.print(html)

%>

</ul>

<script>
  $(function(){
    function waiting_action(self) {
        var msg_dst = $(self);
        var busy_msg = $(".loading-wrapper");

        msg_dst.after(busy_msg);
        busy_msg.removeClass("hide");
        busy_msg[0].scrollIntoView();
        $(".modal-body").scrollLeft(0);
    };
    $(document).on("click", "#save-config", function () {
        waiting_action(this);
    });

    $(document).on("click", "table [class*='btn-table-']:not(.disabled)", function () {
        waiting_action(this);
    });

    $(document).on("change", 'table .switch input[type="hidden"]', function (e) {
        var table = $(this).closest("table");
        // Check that we're not editing a line, this is only for when the line is displayed
        if (table.find(".btn-table-cancel").length === 0) {
            waiting_action(this);
        }
    });
  });
</script>
