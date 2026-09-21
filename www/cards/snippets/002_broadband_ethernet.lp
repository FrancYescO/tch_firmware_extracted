<%
-- Enable localization
gettext.textdomain('webui-core')
local format, match = string.format, string.match
local floor = math.floor
local tonumber = tonumber

local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")


local stats = {
    link = "sys.eth4.Link",
    mode = "sys.eth4.Mode",
    speed = "sys.eth4.Speed",
}
content_helper.getExactContent(stats)
    
-- Figure out interface state
local intf_state = "Disabled"
local intf_state_map = {
    Disabled = T"Ethernet Down",
    Connected = T"Ethernet Connected",
    Disconnected = T"Ethernet Not Connected",
}

local intf_light_map = {
  Disabled = "off",
  Disconnected = "red",
  Connected = "green",
}

if stats.link == "1" then
    intf_state = "Connected"
else
    intf_state = "Disconnected"
end

local session = ngx.ctx.session
local modalPath

--if session:hasAccess("/modals/broadband-modal.lp") then
    modalPath = "modals/broadband-modal.lp"
--end
%>

<%= ui_helper.createCardHeader(T"Broadband", modalPath) %>
<div class="content card_bg" data-bg-text="&#xf0b2;">
      <div class="divtable">
      <div id="L2light"><%= ui_helper.createSimpleLight(nil, intf_state_map[intf_state], { light = { class = intf_light_map[intf_state] } }) %></div>
      <p class="subinfos" id="eth_speed">
      <% 
      if stats.link == "1" then
                  ngx.print(format("%s: %s Mbs",T"Link Speed",stats.speed))
      end
      %>
      </p>
      </div>
</div>

<script type='text/javascript'>
var eth_state_map = {
<%for k,v in pairs(intf_state_map) do %>
     <%=k%> : "<%=v%>",
<%end%>
};

var eth_light_map = {
<%for k,v in pairs(intf_light_map) do %>
     <%=k%> : "<%=v%>",
<%end%>
}

function eth_ajax(x)
{
  var url = '/check.lp';
  var checktimer = <%=TIMERJS%>;
  $.getJSON(url,  {eth: "1",old_eth:"<%=stats.link%>"})
   .done(function( data ) {
      var eth_link = data.ETH;
      x = eth_link;
      //if (data.OLD_ETH != data.ETH){
      var eth_rate = data.ETH_SPEED
      var eth_status = "Disconnected"
      if (eth_link == "1"){eth_status = "Connected"}
      $("#L2light").html("<span class=\"simple-desc\"><div class=\"light "+eth_light_map[eth_status]+"\"></div>"+eth_state_map[eth_status]+"</span>");
        var ETHHTML = ""
        if (eth_link == "1"){
            ETHHTML = '<%=T"Link Speed"%> :'+eth_rate+' Mbps';
        }
        $("#eth_speed").html(ETHHTML);     
      //} 
   })
   .always(function() {
          if (L2_check){clearTimeout(L2_check)};
          L2_check = window.setTimeout(function () {eth_ajax(x);}, checktimer);       
    }); 
}
eth_ajax("<%=stats.link%>");
</script>
