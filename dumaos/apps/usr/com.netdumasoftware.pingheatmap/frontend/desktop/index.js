/*
 * (C) 2018 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
*/

(function () {

var packageId = "com.netdumasoftware.pingheatmap";

function getFilePath(file) {
  return "/apps/" + packageId + "/desktop/" + file;
}

browserSetup.onReady(function () {
  $(document).ready(function () {
    var panels = $("duma-panels")[0];

    panels.add(getFilePath("ping-map.html"), packageId, null, {
      x: 0, y: 0, width: 12, height: 9
    });
  });
});

})();
