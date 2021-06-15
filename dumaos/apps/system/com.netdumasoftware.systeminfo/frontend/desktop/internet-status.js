(function (context) {

start_cycle(function () {
  return [
    serial_netgear_soap_rpc("WANEthernetLinkConfig", "GetDashboardInternetStatus" ),
  ];
}, function ( is ) {
  if( is.code == "000" ){
    is = is.response;
    $("#conn-type", context).text(is.NewConnectionType);
    $("#wan-ip", context).text(is.NewIPAddress);
    $("#conn-status", context).text(is.NewConnectionStatus);
  }
  $("duma-panel", context).prop("loaded", true);
}, 1000 * 30);

})(this);

//@ sourceURL=internet-status.js
