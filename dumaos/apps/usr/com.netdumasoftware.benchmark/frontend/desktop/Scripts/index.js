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
  var packageId = "com.netdumasoftware.benchmark";

  browserSetup.onReady(function ()
  {
    $(document).ready(function ()
    {
      var panels = $("duma-panels")[0];

      panels.add(getFilePath("overview.html", packageId), packageId, null, { x: 0, y: 0, width: 12, height: 12 });
    });
  });
})();
