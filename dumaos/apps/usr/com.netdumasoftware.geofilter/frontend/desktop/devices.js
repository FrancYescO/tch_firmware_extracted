/*
 * (C) 2016 NETDUMA Software
 * Kian Cross
 * Luke Meppem
*/

(function (context) {

var devicesLoaderDialog = $("#devices-loader-dialog", context);

function generateToggle(device, enabled, id, allowFiltering) {
  return $("<paper-toggle-button aria-label='<%= i18n.ariaFilterModeSwitch %>'><%= i18n.filteringMode %></paper-toggle-button>")
    .on("checked-changed", function () {
      var p = geoFilter.getPackageId();
      var f = "capture_toggle";
      var a = [1, device.id, id, JSON.stringify(this.checked)];
      var promise = long_rpc_promise( p, f, a);
      geoFilter.showLoaderDialog(devicesLoaderDialog, promise);
      promise.done();
    })
    .prop("checked", enabled ? true : null).prop("disabled",!allowFiltering).addClass("filter-toggle");
}

function refreshAddDeviceDisabled(){
  var count = $("#geofilter-devices", context).children().length;
  $("#add-device",context).attr("disabled",count >= 4 ? true : null);
}

function delete_device(device, id,callback){
  var promise = long_rpc_promise(
    geoFilter.getPackageId(), "del_capture", 
    [ 1, device.id, id ]
  );
  geoFilter.showLoaderDialog(devicesLoaderDialog, promise);
  promise.done(function () {
    if(callback) callback();
  });
}

function do_add_service( device, id, name, enabled, allowFiltering ) {
  var aria = "<%= i18n.ariaDeviceRegion %>".format(device.name,name);
  var geodevice = $("<div role='region' aria-label='" + aria + "'></div>")
    .addClass("geo-device")
      .append($("<div class='delete-box'></div>")
      .append(
          $('<paper-button aria-label="<%= i18n.ariaDeleteButton %>"><%= i18n.delete %></paper-button>').click(
          (function( device, id ){
            return function () {
              $("#geofilter-duma-alert", context)[0].show(
                "<%= i18n.deleteConfirm %>",
                [
                  { text: "<%= i18n.cancel %>", action: "dismiss" },
                  { text: "<%= i18n.delete %>", action: "confirm", callback: function(){
                    delete_device(device,id,function(){ $(geodevice).remove(); refreshAddDeviceDisabled(); });
                  }}
                ]
              )
            }
          })( device, id )
        )
      )
    )
    .append($("<div class='device-name'></div>").text(device.name))
    .append($("<div class='service'></div>").text(name))
    .append(generateToggle(device, enabled, id, allowFiltering));

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
  refreshAddDeviceDisabled();
}

function add_services( device, service, filter_mode, devices, onError){
  var services = service.services;

  var promise = long_rpc_promise(geoFilter.getPackageId(), "add_capture", [
    1, device.id, service.name,
    JSON.stringify(services),
    JSON.stringify(service.tags)
  ]).fail(onError);

  geoFilter.showLoaderDialog(devicesLoaderDialog, promise);

  var after = function (id ) {
    var card = do_add_service(
      devices[device.id],
      id[0],
      service.name,
      filter_mode,
      service.tags.indexOf("geofilter") > -1
    );

    refreshAddDeviceDisabled();
  }
  if(filter_mode === true || filter_mode === false){
    promise.done(function(id){
      long_rpc_promise(geoFilter.getPackageId(), "capture_toggle", [1, device.id, id[0], JSON.stringify(filter_mode)]).catch(onError).done(function(){
        after(id);
      });
    });
  }else{
    promise.done(after);
  }
}

function on_add_device( ){
  get_devices().done(function ( d ){
    function add_device_callback( device, service, filter, onError){
      add_services( device, service, filter, d, onError);
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
