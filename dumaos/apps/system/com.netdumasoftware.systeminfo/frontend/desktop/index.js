/*
 * (C) 2016 NETDUMA Software
 * Kian Cross
*/

<%
require "libos"
local platform = os.platform_information()
%>

(function () {

var packageId = "com.netdumasoftware.systeminfo";

function getPath(file) {
  return "/apps/" + packageId + "/desktop/" + file;
}

browserSetup.onReady(function () {
  $(document).ready(function () {
    <% if platform.model == "RASPI3B" then %>
    $("duma-panels")[0].add(getPath("cpu-usage.html"), packageId, null, {
      x: 0, y: 0, width: 8, height: 6
    });

    $("duma-panels")[0].add(getPath("ram-usage.html"), packageId, null, {
      x: 8, y: 0, width: 4, height: 6
    });
    <% else %>
    $("duma-panels")[0].add(getPath("cpu-usage.html"), packageId, null, {
      x: 0, y: 0, width: 6, height: 4
    });

    $("duma-panels")[0].add(getPath("ram-usage.html"), packageId, null, {
      x: 6, y: 0, width: 3, height: 4
    });

    $("duma-panels")[0].add(getPath("flash-usage.html"), packageId, null, {
      x: 9, y: 0, width: 3, height: 4
    });
    <% end %>

    $("duma-panels")[0].add(getPath("system-information.html"), packageId, null, {
      x: 0, y: 6, width: 4, height: 4
    });

    $("duma-panels")[0].add(getPath("network-status.html"), packageId, null, {
      x: 4, y: 6, width: 4, height: 4
    });

    $("duma-panels")[0].add(getPath("installed-apps.html"), packageId, null, {
      x: 8, y: 6, width: 4, height: 4
    });

    <% if os.implements_netgear_specification() then %>
      $("duma-panels")[0].add(getPath("internet-status.html"), packageId, null, {
        x: 0, y: 8, width: 3, height: 4
      });

      $("duma-panels")[0].add(getPath("wireless-status.html"), packageId, null, {
        x: 3, y: 8, width: 5, height: 4
      });

      $("duma-panels")[0].add(getPath("guest-wireless-status.html"), packageId, null, {
        x: 8, y: 8, width: 4, height: 4
      });
    <% end %>

    $("duma-panels")[0].add(getPath("logs.html"), packageId, null, {
      x: 0, y: 12, width: 12, height: 8
    });
  });
});

})();

//@ sourceURL=index.js
