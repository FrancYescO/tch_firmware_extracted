/*
 * (C) 2017 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
*/

browserSetup.onReady(function () {
  $(document).ready(function () {

    geoFilter.addPanel("devices.html", [], {
      x: 0, y: 0, width: 12, height: 7
    });

    geoFilter.addPanel("geo-map.html", [], {
      width: 12, height: 18, x: 0, y: 7
    });
    
    geoFilter.addPanel("allow-deny.html", [], {
      width: 6, height: 15, x: 0, y: 25
    });
  });
});
