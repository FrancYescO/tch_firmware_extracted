/*
 * (C) 2017 NETDUMA Software
 * Kian Cross
*/

(function (context) {

var packageId = "com.netdumasoftware.systeminfo";

long_rpc(packageId, "get_system_info", [], function (systemInfo) {
  $("#up-time", context).text(systemInfo.uptime);
  $("#router-time", context).text(systemInfo.date);
  $("#router-time-zone", context).text(systemInfo.tz);
  $("duma-panel", context).prop("loaded", true);
  var clickswitch = $("#click-switch", context);
  var preTouch = 0;
  clickswitch.click(function(){
    var now = Date.now();
    if(now - preTouch < 500){
      clickswitch.attr("switch",clickswitch.attr("switch") ? null : true);
      preTouch = 0;
    }else{
      preTouch = now;
    }
  })
});

})(this);
