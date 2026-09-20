/*
 * (C) 2017 NETDUMA Software
 * Iain Fraser <iainf@netduma.com>
 * Kian Cross <kian.cross@netduma.com>
*/

<%
  require "libos"
  local platform_information = os.platform_information()
%>

(function (context) {

function updateStats( info, suffix, smart ) {
  if( smart.code == "000" && smart.response.NewSmartConnectEnable == "1" ){
    $("#enable" + suffix, context).text( "<%= i18n.smartConnectEnabled %>" );
    $("#ssid" + suffix, context).text("<%= i18n.notApplicable %>");
    $("#pw" + suffix, context).text("<%= i18n.notApplicable %>");
    $("#security" + suffix, context).text("<%= i18n.notApplicable %>");
    $("#channel" + suffix, context).text(info.NewChannel);
  } else {
    var szenable = info.NewEnable == "1" ?
                   "<%= i18n.enabled %>" :
                   "<%= i18n.disabled %>";
    $("#enable" + suffix, context).text( szenable );
    $("#ssid" + suffix, context).text(info.NewSSID);
    $("#pw" + suffix, context).text(info.NewPassphrase);
    $("#security" + suffix, context).text(info.NewBasicEncryptionModes);
    $("#channel" + suffix, context).text(info.NewChannel);
  }
}

Q.all( [
  serial_netgear_soap_rpc("WLANConfiguration", "GetDashboardInfo" ),
  serial_netgear_soap_rpc("WLANConfiguration", "Get5GDashboardInfo" ),
  serial_netgear_soap_rpc("WLANConfiguration", "Get60GDashboardInfo" ),
  serial_netgear_soap_rpc("WLANConfiguration", "IsSmartConnectEnabled" )
])
.spread( function ( wifi2, wifi5, wifi60, smart ) {
  if( wifi2.code == "000" )
    updateStats( wifi2.response, "2", smart );
  if( wifi5.code == "000" )
    updateStats( wifi5.response, "5", smart );

<% if platform_information.model == "XR700" then %>
      if (wifi60.code == "000") {
        updateStats( wifi60.response, "60", { code : "404" } );
      }
<% else %>
      $("#enable60", context).text( "Router Not Capable" );
      $("#ssid60", context).text( "N/A" );
      $("#pw60", context).text( "N/A" );
      $("#security60", context).text( "N/A" );
      $("#channel60", context).text( "N/A" );
<% end %>
  
  $("duma-panel", context).prop("loaded", true);
});

})(this);


//@ sourceURL=wireless-status.js
