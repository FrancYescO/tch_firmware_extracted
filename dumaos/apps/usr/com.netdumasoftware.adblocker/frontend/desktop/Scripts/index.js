/*
 * (C) 2019 NETDUMA Software
 * Andy Adshead
*/

function getFilePath(file, packageId)
{
  return "/apps/" + packageId + "/desktop/" + file;
}

(function ()
{
  var packageId = "com.netdumasoftware.adblocker";

  browserSetup.onReady(function ()
  {
    $(document).ready(function ()
    {
      var panels = $("duma-panels")[0];

      panels.add(getFilePath("status.html", packageId), packageId, null, { x: 0, y: 0, width: 3, height: 4 });
      panels.add(getFilePath("dayview.html", packageId), packageId, null, { x: 3, y: 0, width: 9, height: 4 });
      panels.add(getFilePath("overview.html", packageId), packageId, null, { x: 0, y: 4, width: 12, height: 8 });
      panels.add(getFilePath("lists.html", packageId), packageId, null, { x: 0, y: 12, width: 6, height: 6 });
      panels.add(getFilePath("top_blocked.html", packageId), packageId, null, { x: 6, y: 12, width: 6, height: 6 });
    });
  });
})();
