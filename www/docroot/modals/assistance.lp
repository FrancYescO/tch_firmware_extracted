<%
-- Enable localization
gettext.textdomain('webui-core')

local ui_helper = require("web.ui_helper")
local assistance = require("web.assistance")
local assistant = assistance.getAssistant('remote')
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local state = assistant:enabled() and "1" or "0"
local error

if ngx.var.request_method == "POST" then
  local content = ngx.req.get_post_args()
  if content["action"]=="SAVE" then
    local newstate = content["assistanceenabled"] or state
    local ok, err = assistant:enable(newstate=="1")
    state = assistant:enabled() and "1" or "0"
    if not ok then%>
     <input type="hidden" id="post_status" value="error">
    <%else%>
     <input type="hidden" id="post_status" value="success">
    <%end
  end
end
%>

<form id="assistance-form" class="form-horizontal" method="post" action="modals/assistance.lp">
  <input type="hidden" name="CSRFtoken" id="CSRFtoken" value="<%=CSRFtoken%>"></input>
  <input type="hidden" name="action" id="action" value="SAVE"></input>
  <h1><span><%=T"Assistance"%></span></h1>
  <div class="h3-content vdf-table mobile-padding-bottom-lg">
    <div class="vdf-row">
      <div class="left">
        <span><%=T"Remote Assistance"%></span> </div>
      <div class="right">
        <input type="hidden" name= "assistanceenabled" id="assistanceenabled" value = "<%=state%>">
        </input>
        <div class="button pin-enable pull-right <%if state == "0" then%>button-off<%else%>button-on<%end%>" id="assistance-btn-enable"> </div>
      </div>
    </div>
    <div class="vdf-row assitance-content">
      <div class="left"><span><%=T"URL"%></span>
      </div>
      <div class="right">
        <span id="assistance-lbl-url"><%=assistant:URL() or "Not connected to the Internet"%></span>
      </div>
    </div>
    <div class="vdf-row assitance-content">
      <div class="left"><span><%=T"Username"%></span>
      </div>
      <div class="right">
        <span id="assistance-lbl-username"><%=assistant:username()%></span>
      </div>
    </div>
    <div class="vdf-row assitance-content">
      <div class="left"><span><%=T"Password"%></span>
      </div>
      <div class="right">
        <span id="assistance-lbl-password"><%=assistant:password()%></span>
      </div>
    </div>
  </div>
</form>
<%
local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("apply-cancel.lp")
%>
<script src="/js/global.js"> </script>
<script>
$(document).ready(function(){
  $("#assistance-btn-enable").val("<%=state%>");
  if("<%=state%>" == "0") {
    $(".assitance-content").hide();
  } else {
    $(".assitance-content").css("display","table-row");
  }
  $("#assistance-btn-enable").click(function() {
    if ($('#assistance-btn-enable').hasClass('button-off')) {
      $("#assistanceenabled").val("0");
    } else {
      $("#assistanceenabled").val("1");
    }
  });
  $("#global-apply").click(function() {
    var assistanceenabled = $("#assistance-btn-enable").hasClass("button-on") ? 1 : 0;
    $("#assistanceenabled").val(assistanceenabled);
    postHandler("/modals/assistance.lp", $("#assistance-form").serializeArray());
  });
  $("#global-cancel").click(function() {
    $("#content").load("/modals/assistance.lp");
  });
});

</script>
