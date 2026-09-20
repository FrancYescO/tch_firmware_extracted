/*
 * (C) 2017 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
*/

(function (context) {

var packageId = "com.netdumasoftware.systeminfo";

long_rpc(packageId, "get_system_info", [], function (systemInfo) {
  $("#up-time", context).text(systemInfo.uptime);
  $("#router-time", context).text(systemInfo.date);
  
  $("duma-panel", context).prop("loaded", true);
});

})(this);
