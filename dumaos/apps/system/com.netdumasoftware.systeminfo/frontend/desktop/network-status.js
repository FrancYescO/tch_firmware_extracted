/*
 * (C) 2017 NETDUMA Software
 * Kian Cross
*/

<%
require "libos"
local json = require "json"
local platform_information = os.platform_information()
%>

(function (context) {

var publicIpHide = $("duma-hidden",context);
var routerPublicIP;

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
    long_rpc_promise("com.netdumasoftware.systeminfo", "get_wan_ip", []),
    long_rpc_promise("com.netdumasoftware.config", "get", ["DumaOS_Public_IP"]),
    <% end %>
  ];
}, function (networkStatistics, wanIp, publicIp) {
  updateNetworkStatistics(networkStatistics[0])
  
  <% if platform_information.vendor ~= "NETGEAR" then %>
  $("#wan-ip", context).text(wanIp[0] ? wanIp[0] : "<%= i18n.disconnected %>");
  routerPublicIP = publicIp[0] ? publicIp[1] : "<%= i18n.disconnected %>";
  $("#hidden-public-ip", context).text(publicIp[0] ? new Array(routerPublicIP.length).fill("●").join("") : "<%= i18n.disconnected %>");
  $("#public-ip", context).text(routerPublicIP);
  <% end %>
  
  $("duma-panel", context).prop("loaded", true);
}, 1000 * 2);

// handle tap from show/hide button
publicIpHide.on("visible-tap",() => {
  publicIpHide[0].visible = !publicIpHide[0].visible;
  // wait for template stamp
  Polymer.RenderStatus.afterNextRender(this,() => {
    $("#public-ip", context).text(routerPublicIP);
  });
});

})(this);
