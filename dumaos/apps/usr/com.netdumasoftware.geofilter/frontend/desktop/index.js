/*
 * (C) 2017 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
 * Luke Meppem <luke.meppem@netduma.com>
*/

browserSetup.onReady(function () {
  $(document).ready(function () {

    geoFilter.addPanel("geo-map.html", [], {
      width: 12, height: 24, x: 0, y: 0
    });
    
    geoFilter.addPanel("allow-deny.html", [], {
      width: 6, height: 15, x: 0, y: 25
    });
  });
});
