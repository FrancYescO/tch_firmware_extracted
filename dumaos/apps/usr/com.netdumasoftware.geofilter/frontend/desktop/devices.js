/*
 * (C) 2016 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
*/

(function (context) {

var devicesLoaderDialog = $("#devices-loader-dialog", context);

function generateRadioButtons(device, enabled, id, allowFiltering) {
  var group = $("<paper-radio-group></paper-radio-group>")
    .on("iron-select", function () {
      var p = geoFilter.getPackageId();
      var f = "capture_toggle";
      var a = [1, device.id, id, JSON.stringify(this.selected === "filtering")];
      var promise = long_rpc_promise( p, f, a);
      geoFilter.showLoaderDialog(devicesLoaderDialog, promise);
      promise.done();
    })
    .prop("selected", enabled ? "filtering" : "spectating");

  Polymer.dom(group[0]).appendChild(
    $("<paper-radio-button><%= i18n.filteringMode %></paper-radio-button>")
      .attr("name", "filtering")
      .prop("disabled", !allowFiltering)[0]
  );

  Polymer.dom(group[0]).appendChild(
    $("<paper-radio-button><%= i18n.spectatingMode %></paper-radio-button>")
      .attr("name", "spectating")[0]
  );

  return group;
}

function do_add_service( device, id, name, enabled, allowFiltering ) {
  var geodevice = $("<div></div>")
    .addClass("geo-device")
    .append($("<div class='device'></div>").text(device.name))
    .append($("<div class='service'></div>").text(name))
    .append(generateRadioButtons(device, enabled, id, allowFiltering))
    .append($("<paper-button background><%= i18n.delete %></paper-button>").click((
    function( device, id ){
      return function () {
        var promise = long_rpc_promise(
          geoFilter.getPackageId(), "del_capture", 
          [ 1, device.id, id ]
        );
        geoFilter.showLoaderDialog(devicesLoaderDialog, promise);
        promise.done(function () {
          $(geodevice).remove();
        });
      }
    })( device, id ) ) );

  $("#geofilter-devices", context).append( geodevice );

  return geodevice;
}

function loadGeoFilterDevices(devices, geoFilterDevices) {
  geoFilterDevices = geoFilterDevices.device;

  for (var id in geoFilterDevices) {
    var multi_services = geoFilterDevices[id];
    if ( multi_services ) {
      var device = devices[id]
      if (!device)
        throw "Unmatched device";     

      for( var i = 0; i < multi_services.length; i++ ){
        var service = multi_services[i];
        do_add_service(
          device, service.id, service.name,
          service.enabled, is_undefined( service.tags ) || service.tags.indexOf("geofilter") > -1
        );
      }
    }
  }
}

function add_services( device, service, devices){
  var services = service.services;

  var promise = long_rpc_promise(geoFilter.getPackageId(), "add_capture", [
    1, device.id, service.name,
    JSON.stringify(services),
    JSON.stringify(service.tags)
  ]);

  geoFilter.showLoaderDialog(devicesLoaderDialog, promise);

  promise.done(function (id ) {
    var card = do_add_service(
      devices[device.id],
      id[0],
      service.name,
      service.tags.indexOf("console") > -1,
      service.tags.indexOf("geofilter") > -1
    );

    if (service.tags.indexOf("geofilter") > -1 && service.tags.indexOf("pc") > -1) {
      $("duma-alert", context)[0].show(
        "<%= i18n.addedPcMessage %>",

        [{ text: "<%= i18n.gotIt %>", action: "confirm" }]
      );

    } else if (service.tags.indexOf("pc") > -1) {
      $("#spectating-success", context)[0].show( 
        null,
        [{ text: "<%= i18n.gotIt %>", action: "confirm" }]
      );

    } else if (service.tags.indexOf("console") > -1) {
      $("#filtering-success", context)[0].show(
        null,
        [{ text: "<%= i18n.gotIt %>", action: "confirm" }]
      );
    }
  });
}

function on_add_device( ){
  get_devices().done(function ( d ){
    function add_device_callback( device, service){
      add_services( device, service, d);
    }

    $("geofilter-device-selector", context)[0].open(add_device_callback);
  });
}

Q.spread([
  get_devices(),
  long_rpc_promise(geoFilter.getPackageId(), "get_all", [])
], function (devices, geoFilters) {
  geoFilters = JSON.parse( geoFilters );
  loadGeoFilterDevices(devices, geoFilters[1]);
  $("#add-device",context).click( function(){ 
    on_add_device( devices );
  });
  
  $("duma-panel", context).prop("loaded", true);
}).done();

})(this);

//# sourceURL=devices.js
