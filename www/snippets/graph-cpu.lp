<%
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local proxy = require("datamodel")
local args = ngx.req.get_uri_args()

local html = {}
--AJAX Part
local function AJAX()
  local values = proxy.get("sys.graph.cpu.")
  html[#html+1] = "{"
  for k, v in pairs(values) do
    html[#html+1]=string.format("\"%s\":\"%s\"", k, v.value)
    html[#html+1] = ","
  end
  html[#html] = "}"
  ngx.print(html)
end

if args.ajaxreq == "1" then
  AJAX()
  ngx.exit(ngx.HTTP_OK)
end
--AJAX End

html = {}
html[#html + 1] = [[<fieldset>]]
html[#html + 1] = [[<div style="width:900px;">]]
html[#html + 1] = [[<canvas id="canvas"></canvas>]]
html[#html + 1] = [[</div>]]
html[#html + 1] = [[</fieldset>]]
ngx.print(html)
%>

<script src="/js/graph-cpu.js"></script>

