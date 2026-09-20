--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local lp = require("web.lp")
local uiHelper = require("web.ui_helper")
local graphHelper = require("graph_helper")

local format = string.format

local html = {}
local modeData = {}
local modeOptions = {}
local modeDefault = "" -- the default mode to use
local modeActive = ""  -- the mode currently in use (modeDefault if not set)

local translate = {
  diagnostics = T"Diagnostics",
  reLoad = T"Re-Load",
  note = T"NOTE",
  note1 = T"1. This page is best viewed on larger screens.",
  note2 = T"2. Using the page will add load to the Router so CPU results will be higher then without this page in view."
}

for _, graph in ipairs(graphHelper) do
  modeOptions[#modeOptions + 1] = { graph.name, graph.description, graph.view }
  modeData[graph.name] = graph
  if graph.default == true then
    modeDefault = graph.name
  end
end

local args = ngx.req.get_uri_args()
if args.graph then
  modeActive = format("%s", args.graph) or modeDefault
end

if modeActive == "" then
  modeActive = modeDefault
end

if args.ajaxreq ~= "1" then
  local graphs = {}
  for graphName, graph in pairs(modeData) do
    table.insert(graphs, { graphName , graph.description })
  end
  table.sort(graphs, function(a, b) return a[2]<b[2] end)
  --modeData = pairsByKeys(modeData)
  local refresh = {
    button = {
      id = "btn-refresh",
      style = "margin-bottom: 10px;"
    }
  }

  html[#html + 1] = uiHelper.createHeader(translate.diagnostics, false, false)
  html[#html + 1] = [[<div class="modal-body no-save update">]]
  ngx.print(html)

  lp.setpath("/www/snippets/")
  lp.include("tabs-diagnostics.lp")

  html = {}
  html[#html + 1] = [[<fieldset>]]
  html[#html + 1] = uiHelper.createSimpleInputSelect("GraphChoice", graphs, modeActive)
  html[#html + 1] = uiHelper.createSimpleButton(translate.reLoad, "icon-refresh", refresh)
  html[#html + 1] = uiHelper.createAlertBlock(format(
    '<table><tr><td width=30>%s:</td><td>%s</td></tr><tr><td width=30>&nbsp;</td><td>%s</td></tr></table>', translate.note, translate.note1, translate.note2))
  html[#html + 1] = [[</fieldset>]]
  ngx.print(html)
end

lp.setpath("/www/snippets/")
lp.include(modeData[modeActive].graph)
  ngx.print('\
\
<script>\
  $(document).ready(function() {\
    $(document).on("change", "#GraphChoice", function() {\
      clearTimeout(timerajax);\
      $(document).off("change", "#GraphChoice");\
      tch.loadModal("/modals/diagnostics-graphs-modal.lp?graph=" + this.value);\
    });\
\
    $("#btn-refresh").click(function() {\
      $(document).off("change", "#GraphChoice");\
      tch.loadModal("/modals/diagnostics-graphs-modal.lp?graph=" + $("#GraphChoice").val());\
    });\
\
    $("#Graphing").parent().addClass("active");\
  });\
</script>\
\
');  
  html = {}
  html[#html + 1] = [[</div>]]
  html[#html + 1] = uiHelper.createFooter()
  ngx.print(html)
  ngx.print('\
'); 