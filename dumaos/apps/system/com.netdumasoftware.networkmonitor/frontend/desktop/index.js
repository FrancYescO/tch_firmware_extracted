/*
 * (C) 2016 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
*/

(function () {

var packageId = "com.netdumasoftware.networkmonitor";

function getFilePath(file) {
  return "/apps/" + packageId + "/desktop/" + file;
}

browserSetup.onReady(function () {
  $(document).ready(function () {
    var panels = $("duma-panels")[0];

    panels.add(getFilePath("snapshot-graph.html"), packageId, null, {
      x: 0, y: 0, width: 12, height: 6
    });
    
    panels.add(getFilePath("overview-graph.html"), packageId, null, {
      x: 0, y: 6, width: 12, height: 6
    });
  });
});

})();
