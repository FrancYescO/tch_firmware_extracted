--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local format = string.format
local floor = math.floor
local tonumber = tonumber
local ui_helper = require("web.ui_helper")

local post_helper = require("web.post_helper")
local content_helper = require("web.content_helper")
local rate_up, rate_down = "", ""
local iconUp = "<i class=\"icon-upload icon-small gray\"></i> "
local iconDown = " <i class=\"icon-download icon-small gray\"></i> "


-- xdsl data
local xdsl_data = {
  dsl_status = "sys.class.xdsl.@line0.Status",
  dsl_linerate_up = "sys.class.xdsl.@line0.UpstreamCurrRate",
  dsl_linerate_down = "sys.class.xdsl.@line0.DownstreamCurrRate",
}
content_helper.getExactContent(xdsl_data)

local other_line_xdsl_data = {
  dsl_status = "sys.class.xdsl.@line1.Status",
  dsl_linerate_up = "sys.class.xdsl.@line1.UpstreamCurrRate",
  dsl_linerate_down = "sys.class.xdsl.@line1.DownstreamCurrRate",
}
content_helper.getExactContent(other_line_xdsl_data)



local session = ngx.ctx.session

local switchName, switchinfo
local modalPath = "modals/broadband-modal.lp"

local dsl_state_map = {
  Up = "Connected",
  Initializing = "Connecting",
  NoSignal = "Disconnected",
  Unknown = "Connecting",
}

local dsl_light_map = {
  Up = "green",
  NoSignal = "red",
  Unknown = "orange",
  Initializing = "orange",
}
local dsl_state = ""


  if (xdsl_data["dsl_status"] == "Up") or (other_line_xdsl_data["dsl_status"] == "Up") then

    dsl_state = "Up"
    -- After disabling broadband the page immediately refreshes. At this time the state is still up but the line
    -- rate is already cleared.
    rate_up = tonumber(xdsl_data["dsl_linerate_up"])
    rate_down = tonumber(xdsl_data["dsl_linerate_down"])
    local other_line_rate_up = tonumber(other_line_xdsl_data["dsl_linerate_up"])
    local other_line_rate_down = tonumber(other_line_xdsl_data["dsl_linerate_down"])
    
    if (rate_up and rate_down) or (other_line_rate_up and other_line_rate_down) then
      if rate_up and rate_down then
        rate_up = floor(rate_up / 10) / 100
        rate_down = floor(rate_down / 10) / 100
      else
        rate_up = 0
        rate_down = 0
      end
      if other_line_rate_up and other_line_rate_down then
        rate_up = rate_up + (floor(other_line_rate_up / 10) / 100)
        rate_down = rate_down + (floor(other_line_rate_down / 10) / 100)
      end
    end
  elseif xdsl_data["dsl_status"] == "NoSignal" and other_line_xdsl_data["dsl_status"] == "NoSignal" then
    dsl_state = "NoSignal"
  else
    dsl_state = "Unknown"
  end
  
 
ngx.print(ui_helper.createCardHeader(T"Broadband", modalPath, false, false), '\
<div class="content card_bg" data-bg-text="&#xf0b2;">\
      <div class="divtable">\
      <div id="L2light">', ui_helper.createSimpleLight(nil, dsl_state_map[dsl_state] or T"Connecting", { light = { class = dsl_light_map[dsl_state] or "orange" , id = "Broadband_LED" }, span = {id = "Broadband_Status_Id"} }), '</div>\
        <p class="subinfos" id="dslup">');
           if (dsl_state == "Up") or (other_line_xdsl_data["dsl_status"] == "Up") then
                  ngx.print(format("%s %.2f Mbps",iconUp, rate_up))
           end
ngx.print('\
        </p>\
        <p class="subinfos" id="dsldown">');
           if (dsl_state == "Up") or (other_line_xdsl_data["dsl_status"] == "Up") then
                  ngx.print(format("%s %.2f Mbps",iconDown, rate_down))
           end
ngx.print('\
        </p>\
   </div>\
</div>\
<script type=\'text/javascript\'>\
var dsl_state_map = {')
for k,v in pairs(dsl_state_map) do
     ngx.print(k, ' : "', v,'",');
end

ngx.print('};\
var dsl_light_map = {');
for k,v in pairs(dsl_light_map) do
     ngx.print(k, ' : "', v,'",');
end
ngx.print('\
}\
function dsl_ajax(x)\
{\
  var url = \'/check.lp\';\
  var checktimer = ' ,TIMERJS, ';\
  $.getJSON(url,  {dsl: "1",old_dsl:x})\
   .done(function( data ) {\
      var dsl_status = data.DSL;\
      x = dsl_status;\
      //if (data.OLD_DSL != dsl_status){\
         if (dsl_status == "Up"){\
         var rate_up = (Math.floor(data.UP / 10)/100);\
         var rate_down = (Math.floor(data.DOWN / 10)/100);\
         }\
      $("#L2light").html("<span class=\\"simple-desc\\"><div class=\\"light "+dsl_light_map[dsl_status]+"\\"></div>"+dsl_state_map[dsl_status]+"</span>");\
      var DSLHTMLUP = ""\
      var DSLHTMLDOWN = ""\
      if (dsl_status == "Up"){\
          DSLHTMLDOWN = \'', iconDown, ' \'+rate_down+\' Mbps\';\
          DSLHTMLUP = \'', iconUp,' \'+rate_up+\' Mbps\';\
      }\
      $("#dsldown").html(DSLHTMLDOWN);\
      $("#dslup").html(DSLHTMLUP);\
   })\
   .always(function() {\
          clearTimeout(L2_check);\
          L2_check = window.setTimeout(function () {dsl_ajax(x);}, checktimer);\
    });\
}\
$(function() {\
    dsl_ajax("', xdsl_data["dsl_status"], '");\
});\
</script>');
