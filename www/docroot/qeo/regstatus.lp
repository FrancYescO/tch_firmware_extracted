<%
-- Enable localization
gettext.textdomain('webui-qeo')

local dm = require("datamodel")
local registered = (dm.get("rpc.qeo.status")[1].value == "Registered")
local started = false

if not registered and ngx.var.request_method == "POST" then
  local post_data = ngx.req.get_post_args()
  if post_data.action == "startreg" then
    ngx.log(ngx.ERR, "starting Qeo registration")
    dm.set("rpc.qeo.rr_reset", "1")
    dm.apply()
    started = true
  end
end
%>
<!DOCTYPE HTML>
<%= string.format('<html lang="%s">', gettext.language()) %>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta charset="UTF-8">
    <meta name="CSRFtoken" content="<%= ngx.ctx.session:getCSRFtoken() %>">
    <meta name="regstatus" content="<%= registered and 'registered' or 'waiting' %>">
    <link href="/css/gw.css" rel="stylesheet">
    <link href="/css/responsive.css" rel="stylesheet">
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->
    <script src="/js/main-min.js" ></script>
    <title><%= T"Qeo" %></title>
</head>
<body>
<div class="row offset4 span4">
<% if registered then %>
  <p>Device is already registered.</p>
<% elseif started then %>
  <p>Registration started.</p>
<% else %>
  <form id="start-reg-form" method="post" action="regstatus">
    <input type="hidden" name="action" value="startreg">
    <div id="start-reg" class="btn hidden">Start</button>
  </form>
<script>
$(document).ready(function() {
  var CSRFtoken = tch.elementCSRFtoken();
  var token = $("<input>", {
    "name" : CSRFtoken.name,
    "value" : CSRFtoken.value,
    "type" : "hidden"
  })
  $("#start-reg-form").prepend(token).submit();
})
</script>
<% end %>
</div>
</body>
</html>