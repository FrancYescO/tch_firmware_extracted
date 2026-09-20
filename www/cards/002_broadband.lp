<%
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local floor = math.floor
local tonumber = tonumber
local ui_helper = require("web.ui_helper")
local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")

-- xdsl data
local xdsl_data = {
  dsl_status = "sys.class.xdsl.@line0.Status",
  dsl_linerate_up = "sys.class.xdsl.@line0.UpstreamCurrRate",
  dsl_linerate_down = "sys.class.xdsl.@line0.DownstreamCurrRate",
}
content_helper.getExactContent(xdsl_data)

-- eth data
local eth_data = {
  ethwan_status = "sys.eth.port.@eth4.status",
}
content_helper.getExactContent(eth_data)

local session = ngx.ctx.session

local modalPath

if session:hasAccess("/modals/broadband-modal.lp") then
    modalPath = "modals/broadband-modal.lp"
end

%>

<div class="span3">
  <div class="smallcard">

    <%= ui_helper.createCardHeaderNoIcon(T"Broadband", modalPath, nil, nil, nil) %>
    <div class="content">
    <%
      local iconUp = "<i class=\"icon-upload icon-small gray\"></i> "
      local iconDown = " <i class=\"icon-download icon-small gray\"></i> "

      if xdsl_data["dsl_status"] == "Up" then
        ngx.print(
          "<div class=\"light green\"></div><p>",
          T"DSL connected",
          "</p>"
        )
        -- After disabling broadband the page immediately refreshes. At this time the state is still up but the line
        -- rate is already cleared.
        local rate_up = tonumber(xdsl_data["dsl_linerate_up"])
        local rate_down = tonumber(xdsl_data["dsl_linerate_down"])
        if rate_up and rate_down then
          rate_up = floor(rate_up / 10) / 100
          rate_down = floor(rate_down / 10) / 100
          ngx.print(
            "<p class=\"subinfos\">&emsp; ",
            iconUp,
            format("%.2f Mbps", rate_up),
            "</p>",
            "<p class=\"subinfos\">&emsp; ",
            iconDown,
            format('%.2f Mbps', rate_down),
            "</p>"
          )
        end
      elseif xdsl_data["dsl_status"] == "NoSignal" then
        ngx.print(
          "<div class=\"light red\"></div><p>",
          T"DSL disconnected",
          "</p>"
        )
      else
        ngx.print(
          "<div class=\"light orange\"></div><p>",
          T"DSL connecting",
          ": ",
          T(xdsl_data["dsl_status"]), --this does not work !!!!
          "...</p>"
        )
      end
    if eth_data["ethwan_status"] == "up" then
        ngx.print(
          "<div class=\"light green\"></div><p>",
          T"Ethernet connected",
          "</p>"
        )
      else
        ngx.print(
          "<div class=\"light red\"></div><p>",
          T"Ethernet disconnected",
          "</p>"
        )
      end 
    %>

    </div>
  </div>
</div>
