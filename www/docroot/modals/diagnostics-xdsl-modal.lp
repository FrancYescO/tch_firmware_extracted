<%
-- Enable localization
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local table = table

local xdsl_BitLoading = "sys.class.xdsl.@line0.BitLoading"

local columns ={}

for i=1, 16 do
    columns[i]={}
end
-- first will be overwritten

columns[1][1] = "sys.class.xdsl.@line0.UpstreamFECTotal"
columns[2][1] = "sys.class.xdsl.@line0.DownstreamFECTotal"
columns[3][1] = "sys.class.xdsl.@line0.UpstreamCRCTotal"
columns[4][1] = "sys.class.xdsl.@line0.DownstreamCRCTotal"
columns[5][1] = "sys.class.xdsl.@line0.UpstreamESTotal"
columns[6][1] = "sys.class.xdsl.@line0.DownstreamESTotal"
columns[7][1] = "sys.class.xdsl.@line0.UpstreamSESTotal"
columns[8][1] = "sys.class.xdsl.@line0.DownstreamSESTotal"
columns[9][1] = "sys.class.xdsl.@line0.UpstreamUASTotal"
columns[10][1] = "sys.class.xdsl.@line0.DownstreamUASTotal"
columns[11][1] = "sys.class.xdsl.@line0.UpstreamLOSTotal"
columns[12][1] = "sys.class.xdsl.@line0.DownstreamLOSTotal"
columns[13][1] = "sys.class.xdsl.@line0.UpstreamLOFTotal"
columns[14][1] = "sys.class.xdsl.@line0.DownstreamLOFTotal"
columns[15][1] = "sys.class.xdsl.@line0.UpstreamLOMTotal"
columns[16][1] = "sys.class.xdsl.@line0.DownstreamLOMTotal"

columns[1][2] = "sys.class.xdsl.@line0.UpstreamFECTotal"
columns[2][2] = "sys.class.xdsl.@line0.DownstreamFECTotal"
columns[3][2] = "sys.class.xdsl.@line0.UpstreamCRCTotal"
columns[4][2] = "sys.class.xdsl.@line0.DownstreamCRCTotal"
columns[5][2] = "sys.class.xdsl.@line0.UpstreamESTotal"
columns[6][2] = "sys.class.xdsl.@line0.DownstreamESTotal"
columns[7][2] = "sys.class.xdsl.@line0.UpstreamSESTotal"
columns[8][2] = "sys.class.xdsl.@line0.DownstreamSESTotal"
columns[9][2] = "sys.class.xdsl.@line0.UpstreamUASTotal"
columns[10][2] = "sys.class.xdsl.@line0.DownstreamUASTotal"
columns[11][2] = "sys.class.xdsl.@line0.UpstreamLOSTotal"
columns[12][2] = "sys.class.xdsl.@line0.DownstreamLOSTotal"
columns[13][2] = "sys.class.xdsl.@line0.UpstreamLOFTotal"
columns[14][2] = "sys.class.xdsl.@line0.DownstreamLOFTotal"
columns[15][2] = "sys.class.xdsl.@line0.UpstreamLOMTotal"
columns[16][2] = "sys.class.xdsl.@line0.DownstreamLOMTotal"

columns[1][3] = "sys.class.xdsl.@line0.UpstreamFECCurrentQuarter"
columns[2][3] = "sys.class.xdsl.@line0.DownstreamFECCurrentQuarter"
columns[3][3] = "sys.class.xdsl.@line0.UpstreamCRCCurrentQuarter"
columns[4][3] = "sys.class.xdsl.@line0.DownstreamCRCCurrentQuarter"
columns[5][3] = "sys.class.xdsl.@line0.UpstreamESCurrentQuarter"
columns[6][3] = "sys.class.xdsl.@line0.DownstreamESCurrentQuarter"
columns[7][3] = "sys.class.xdsl.@line0.UpstreamSESCurrentQuarter"
columns[8][3] = "sys.class.xdsl.@line0.DownstreamSESCurrentQuarter"
columns[9][3] = "sys.class.xdsl.@line0.UpstreamUASCurrentQuarter"
columns[10][3] = "sys.class.xdsl.@line0.DownstreamUASCurrentQuarter"
columns[11][3] = "sys.class.xdsl.@line0.UpstreamLOSCurrentQuarter"
columns[12][3] = "sys.class.xdsl.@line0.DownstreamLOSCurrentQuarter"
columns[13][3] = "sys.class.xdsl.@line0.UpstreamLOFCurrentQuarter"
columns[14][3] = "sys.class.xdsl.@line0.DownstreamLOFCurrentQuarter"
columns[15][3] = "sys.class.xdsl.@line0.UpstreamLOMCurrentQuarter"
columns[16][3] = "sys.class.xdsl.@line0.DownstreamLOMCurrentQuarter"

columns[1][4] = "sys.class.xdsl.@line0.UpstreamFECPreviousQuarter"
columns[2][4] = "sys.class.xdsl.@line0.DownstreamFECPreviousQuarter"
columns[3][4] = "sys.class.xdsl.@line0.UpstreamCRCPreviousQuarter"
columns[4][4] = "sys.class.xdsl.@line0.DownstreamCRCPreviousQuarter"
columns[5][4] = "sys.class.xdsl.@line0.UpstreamESPreviousQuarter"
columns[6][4] = "sys.class.xdsl.@line0.DownstreamESPreviousQuarter"
columns[7][4] = "sys.class.xdsl.@line0.UpstreamSESPreviousQuarter"
columns[8][4] = "sys.class.xdsl.@line0.DownstreamSESPreviousQuarter"
columns[9][4] = "sys.class.xdsl.@line0.UpstreamUASPreviousQuarter"
columns[10][4] = "sys.class.xdsl.@line0.DownstreamUASPreviousQuarter"
columns[11][4] = "sys.class.xdsl.@line0.UpstreamLOSPreviousQuarter"
columns[12][4] = "sys.class.xdsl.@line0.DownstreamLOSPreviousQuarter"
columns[13][4] = "sys.class.xdsl.@line0.UpstreamLOFPreviousQuarter"
columns[14][4] = "sys.class.xdsl.@line0.DownstreamLOFPreviousQuarter"
columns[15][4] = "sys.class.xdsl.@line0.UpstreamLOMPreviousQuarter"
columns[16][4] = "sys.class.xdsl.@line0.DownstreamLOMPreviousQuarter"

columns[1][5] = "sys.class.xdsl.@line0.UpstreamFECCurrentDay"
columns[2][5] = "sys.class.xdsl.@line0.DownstreamFECCurrentDay"
columns[3][5] = "sys.class.xdsl.@line0.UpstreamCRCCurrentDay"
columns[4][5] = "sys.class.xdsl.@line0.DownstreamCRCCurrentDay"
columns[5][5] = "sys.class.xdsl.@line0.UpstreamESCurrentDay"
columns[6][5] = "sys.class.xdsl.@line0.DownstreamESCurrentDay"
columns[7][5] = "sys.class.xdsl.@line0.UpstreamSESCurrentDay"
columns[8][5] = "sys.class.xdsl.@line0.DownstreamSESCurrentDay"
columns[9][5] = "sys.class.xdsl.@line0.UpstreamUASCurrentDay"
columns[10][5] = "sys.class.xdsl.@line0.DownstreamUASCurrentDay"
columns[11][5] = "sys.class.xdsl.@line0.UpstreamLOSCurrentDay"
columns[12][5] = "sys.class.xdsl.@line0.DownstreamLOSCurrentDay"
columns[13][5] = "sys.class.xdsl.@line0.UpstreamLOFCurrentDay"
columns[14][5] = "sys.class.xdsl.@line0.DownstreamLOFCurrentDay"
columns[15][5] = "sys.class.xdsl.@line0.UpstreamLOMCurrentDay"
columns[16][5] = "sys.class.xdsl.@line0.DownstreamLOMCurrentDay"

columns[1][6] = "sys.class.xdsl.@line0.UpstreamFECPreviousDay"
columns[2][6] = "sys.class.xdsl.@line0.DownstreamFECPreviousDay"
columns[3][6] = "sys.class.xdsl.@line0.UpstreamCRCPreviousDay"
columns[4][6] = "sys.class.xdsl.@line0.DownstreamCRCPreviousDay"
columns[5][6] = "sys.class.xdsl.@line0.UpstreamESPreviousDay"
columns[6][6] = "sys.class.xdsl.@line0.DownstreamESPreviousDay"
columns[7][6] = "sys.class.xdsl.@line0.UpstreamSESPreviousDay"
columns[8][6] = "sys.class.xdsl.@line0.DownstreamSESPreviousDay"
columns[9][6] = "sys.class.xdsl.@line0.UpstreamUASPreviousDay"
columns[10][6] = "sys.class.xdsl.@line0.DownstreamUASPreviousDay"
columns[11][6] = "sys.class.xdsl.@line0.UpstreamLOSPreviousDay"
columns[12][6] = "sys.class.xdsl.@line0.DownstreamLOSPreviousDay"
columns[13][6] = "sys.class.xdsl.@line0.UpstreamLOFPreviousDay"
columns[14][6] = "sys.class.xdsl.@line0.DownstreamLOFPreviousDay"
columns[15][6] = "sys.class.xdsl.@line0.UpstreamLOMPreviousDay"
columns[16][6] = "sys.class.xdsl.@line0.DownstreamLOMPreviousDay"

columns[1][7] = "sys.class.xdsl.@line0.UpstreamFECSinceSync"
columns[2][7] = "sys.class.xdsl.@line0.DownstreamFECSinceSync"
columns[3][7] = "sys.class.xdsl.@line0.UpstreamCRCSinceSync"
columns[4][7] = "sys.class.xdsl.@line0.DownstreamCRCSinceSync"
columns[5][7] = "sys.class.xdsl.@line0.UpstreamESSinceSync"
columns[6][7] = "sys.class.xdsl.@line0.DownstreamESSinceSync"
columns[7][7] = "sys.class.xdsl.@line0.UpstreamSESSinceSync"
columns[8][7] = "sys.class.xdsl.@line0.DownstreamSESSinceSync"
columns[9][7] = "sys.class.xdsl.@line0.UpstreamUASSinceSync"
columns[10][7] = "sys.class.xdsl.@line0.DownstreamUASSinceSync"
columns[11][7] = "sys.class.xdsl.@line0.UpstreamLOSSinceSync"
columns[12][7] = "sys.class.xdsl.@line0.DownstreamLOSSinceSync"
columns[13][7] = "sys.class.xdsl.@line0.UpstreamLOFSinceSync"
columns[14][7] = "sys.class.xdsl.@line0.DownstreamLOFSinceSync"
columns[15][7] = "sys.class.xdsl.@line0.UpstreamLOMSinceSync"
columns[16][7] = "sys.class.xdsl.@line0.DownstreamLOMSinceSync"

local result = proxy.get("sys.class.xdsl.@line0.") or {}
local temp = {}
for _,v in ipairs(result) do
    temp[v.path..v.param] = v.value
end
for k = 1,#columns[1] do
  for ke = 1,#columns do
     columns[ke][k] = temp [columns[ke][k]] or ""
  end
end
xdsl_BitLoading = temp[xdsl_BitLoading]

columns[1][1] = T"Upstream FEC"
columns[2][1] = T"Downstream FEC"
columns[3][1] = T"Upstream CRC"
columns[4][1] = T"Downstream CRC"
columns[5][1] = T"Upstream ES"
columns[6][1] = T"Downstream ES"
columns[7][1] = T"Upstream SES"
columns[8][1] = T"Downstream SES"
columns[9][1] = T"Upstream UAS"
columns[10][1] = T"Downstream UAS"
columns[11][1] = T"Upstream LOS"
columns[12][1] = T"Downstream LOS"
columns[13][1] = T"Upstream LOF"
columns[14][1] = T"Downstream LOF"
columns[15][1] = T"Upstream LOM"
columns[16][1] = T"Downstream LOM"


-- Datarows Names
local datarows ={}
for i=1, 7 do
    datarows[i]={}
end

datarows[1]["header"] = T"Parameters"
datarows[2]["header"] = T"Total"
datarows[3]["header"] = T"Current Quarter"
datarows[4]["header"] = T"Previous Quarter"
datarows[5]["header"] = T"Current Day"
datarows[6]["header"] = T"Previous Day"
datarows[7]["header"] = T"Since Sync"

local uri = ngx.var.uri
local help_link = { href="/help/index.html?anchor=" .. uri:match("/([^/]+)%.lp") }
if ngx.req.get_uri_args().entry == "bb" then
    help_link.href = help_link.href .. "-bb"
end
%>

<%=ui_helper.createHeader("Diagnostics DSL", false, true, nil, help_link) %>

<div class="modal-body update">
<%
    local html = {}
    if ngx.req.get_uri_args().entry == "bb" then
    local tabs = {
            {
                desc = T"DSL link status",
                target = "modals/broadband-modal.lp",
            },
            {
                desc = T"Ethernet link status",
                target = "modals/broadband-eth-modal.lp",
            },
            {
                desc = T"DSL Diagnostics",
                active = "active",
                target = "modals/diagnostics-xdsl-modal.lp?entry=bb",
            },
        }
        table.insert (html, ui_helper.createModalTabs(tabs))
        ngx.print (html)
    else
        local lp = require("web.lp")
        lp.setpath("/www/snippets/")
        lp.include("tabs-diagnostics.lp")
    end
%>

    <%
        -- dummy form so that refresh button knows which page to reload, keep it
    %>
    <form class="form-horizontal" method="post" action="modals/diagnostics-xdsl-modal.lp">
    </form>

    <fieldset id="diagnostics-xdsl-tab">
      <legend>DSL stats</legend>
      <%
        local options = { tableid = "xdslstats", canEdit = false, editing = false, minEntries =7 , maxEntries =17, createMsg = "Create new", canAdd = false, canDelete = false, newList = true, errmsg = nil}
        -- table that shows the Statistics data
        ngx.print(ui_helper.createTable(datarows, columns, options))
      %>
    </fieldset>
    <fieldset>
      <legend>DSL Bit Loading</legend>
      <div style="max-width:880px;overflow-x:auto;">
        <small>
          <%
            ngx.print( ui_helper.createBitLoadHistogram(xdsl_BitLoading) )
          %>
        </small>
      </div>
  </fieldset>
</div>

<% ngx.print(ui_helper.createFooter()) %>
