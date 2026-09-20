/*
 * (C) 2017 NETDUMA Software
 * Iain Fraser <iainf@netduma.com>
 * Kian Cross
*/

(function (context) {

function updateStats( info, suffix ) {
  var szenable = info.NewEnable == "1" ? "<%= i18n.enabled %>" : "<%= i18n.disabled %>";
  $("#enable" + suffix, context).text( szenable );
  $("#ssid" + suffix, context).text(info.NewSSID);
  $("#pw" + suffix, context).text(info.NewPassphrase);
  $("#security" + suffix, context).text(info.NewBasicEncryptionModes);
  $("#channel" + suffix, context).text(info.NewChannel);
}

Q.spread([
  serial_netgear_soap_rpc("WLANConfiguration", "GetGuestDashboardInfo" ),
  serial_netgear_soap_rpc("WLANConfiguration", "Get5GGuestDashboardInfo" )
], function ( wifi2, wifi5 ) {
  if( wifi2.code == "000" )
    updateStats( wifi2.response, "2" );
  if( wifi5.code == "000" )
    updateStats( wifi5.response, "5" );
  $("duma-panel", context).prop("loaded", true);
});

})(this);

//@ sourceURL=guest-wireless-status.js
