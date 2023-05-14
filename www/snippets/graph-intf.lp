<%
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local proxy = require("datamodel")

local args = ngx.req.get_uri_args()
local format = string.format

--AJAX Part
local function AJAX()
  local raw = format("%s", proxy.get("sys.graph.ifstat")[1].value)
  local cleaned = raw:gsub("n&#47;a", "0.00")
  ngx.print(format("{ \"intf\":\"%s\" }", cleaned))
end

if args.ajaxreq == "1" then
 AJAX()
 ngx.exit(ngx.HTTP_OK)
end

--AJAX End

local html = {}
html[#html + 1] = [[<fieldset>]]
html[#html + 1] = [[<div style="width:900px;">]]
html[#html + 1] = [[<canvas id="canvas"></canvas>]]
html[#html + 1] = [[</div>]]
html[#html + 1] = [[</fieldset>]]
ngx.print(html)
%>

<script src="/js/graph-intf.js"></script>
