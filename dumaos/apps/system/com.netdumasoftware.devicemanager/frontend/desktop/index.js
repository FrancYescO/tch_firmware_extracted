/*
 * (C) 2016 NETDUMA Software
 * Kian Cross
*/

(function () {

var deviceManagerPackageId = "com.netdumasoftware.devicemanager";

browserSetup.onReady(function () {
  $(document).ready(function () {
    var panels = $("duma-panels")[0];

    panels.add(
      "/apps/" + deviceManagerPackageId + "/desktop/device-tree.html", 
      deviceManagerPackageId, null, {
        width: 12, height: 12, x: 0, y: 0
      }
    );
  });
});

})();
