/*
 * (C) 2017 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
*/

<%
require "libos"
local json = require "json"
local platform_information = os.platform_information()
%>

(function (context) {

function updateNetworkStatistics(networkStatisics) {
  $("#transmitted-bytes", context).text(networkStatisics.transmitted.bytes);
  $("#transmitted-packets", context).text(networkStatisics.transmitted.packets);
  $("#transmitted-dropped-packets", context).text(networkStatisics.transmitted.dropped);

  $("#received-bytes", context).text(networkStatisics.received.bytes);
  $("#received-packets", context).text(networkStatisics.received.packets);
  $("#received-dropped-packets", context).text(networkStatisics.received.dropped);
}

start_cycle(function () {
  return [
    long_rpc_promise("com.netdumasoftware.systeminfo", "get_network_statistics", [])
    <% if platform_information.vendor ~= "NETGEAR" then %>,
      long_rpc_promise("com.netdumasoftware.systeminfo", "get_wan_ip", [])
    <% end %>
  ];
}, function (networkStatistics, wanIp) {

  updateNetworkStatistics(networkStatistics[0])

    
  <% if platform_information.vendor ~= "NETGEAR" then %>
    $("#wan-ip", context).text(wanIp[0] ? wanIp[0] : "Disconnected");
  <% end %>
  
  $("duma-panel", context).prop("loaded", true);
}, 1000 * 2);

})(this);
