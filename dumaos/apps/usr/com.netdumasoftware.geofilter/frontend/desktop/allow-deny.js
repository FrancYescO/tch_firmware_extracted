/*
 * (C) 2017 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
*/

(function (context) {

var packageId = "com.netdumasoftware.geofilter";
var allowDenyPanel = $("#allow-deny-panel", context);
var loaderDialog = $("#allow-deny-loader-dialog", context)[0];

function onDeleteClick(row, ip) {
  var promise = long_rpc_promise(packageId, "remove_host", [ip]);
  geoFilter.showLoaderDialog(loaderDialog, promise);
  promise.done(function () {
    $(row).remove();
  });
}

function addHostToTable(allowed, name, ip, isdedi ) {
  var row = $("<tr></tr>");

  row.append($("<td></td>")
    .text(name));
  
  row.append($("<td></td>")
    .text(inet_atoae(ip))
    .addClass("host-ip"));
  
  row.append($("<td></td>")
    .text(allowed ? "<%= i18n.allowed %>" : "<%= i18n.denied %>"));

  row.append($("<td></td>")
    .text(isdedi ? "Dedicated" : "Peer"));

  row.append($("<td></td>")
    .append($("<paper-icon-button></paper-icon-button>")
      .prop("icon", "editor:show-chart")
      .on("click", function () {
        if (allowDenyPanel.desktop) {
          return;
        }

        if($(allowDenyPanel).prop("desktop")) {
          $("#geofilter-duma-alert", context)[0].show(
            "<%= i18n.dashboardPingError %>",
            [{ text: "<%= i18n.gotIt %>", action: "confirm" }]
          );

          return;
        } else if( JSON.parse( duma.storage(geoFilter.getPackageId(), "autoping" ) ) ){
          $("#geofilter-duma-alert", context)[0].show(
            "<%= i18n.autoPingPingError %>",
            [{ text: "<%= i18n.gotIt %>", action: "confirm" }]
          );

          return;
        }

        geoFilter.addPingGraph({
          key: ip,
          class: isdedi ? geoFilter.constants.GEO_CSTATE_HOST_DEDI
            << geoFilter.constants.TYPE_SHIFT : 0
        });
      })));
  
  row.append($("<td></td>")
    .append($("<paper-icon-button></paper-icon-button>")
      .prop("icon", "delete-forever")
      .on("click", function () {
        onDeleteClick(row, ip);
      })));

  $("#allow-deny", context).append(row);
}

function removeRowWithIp(ip) {
  $("#allow-deny tr", context).each(function () {
    var rowIp = inet_aetoa( $(this).find(".host-ip").text() );
    if (ip == rowIp) {
      $(this).remove();
    }
  });
}

function onInit() {

  Q.spread([
    long_rpc_promise(packageId, "get_all_hosts", []),
    geoFilter.initialisationPromise,
  ], function (hosts) {
    hosts = hosts[0];
    for (var ip in hosts) {
      if (hosts.hasOwnProperty(ip)) {
        var host = hosts[ip];
        addHostToTable(host.allow, host.name, ip, host.isdedi);
      }
    }

    $(allowDenyPanel).prop("loaded", true);
  })

  $(allowDenyPanel).on("allow-deny-host", function (e, data) {
    removeRowWithIp(data.ip);
    addHostToTable(data.allowed, data.name, data.ip, data.isdedi);
  });
}

onInit();

})(this);

//# sourceURL=allow-deny.js
