/*
 * (C) 2017 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
*/

<%
require "libos"
local platform = os.platform_information()
local showUpload = platform.vendor ~= "TELSTRA"
%>

(function (context) {

var packageId = "com.netdumasoftware.qos";
var dumaAlert = $("#hyperlane-duma-alert", context)[0];
var dumaDeviceSelector = $("duma-device-selector", context)[0];
var loaderDialog = $("#hyperlane-loader-dialog", context)[0];

function addDevice(device, id, name, enabled) {
  var row = $("<tr></tr>").attr("app_id",id).attr("device_id",device.id);

  var menu = $("<paper-menu-button></paper-menu-button>");
  Polymer.dom(menu[0]).appendChild($("<paper-icon-button></paper-icon-button>")
    .attr("icon", "menu")
    .addClass("dropdown-trigger")[0]
  );

  var packets_div = '<div class="packets"><granite-led></granite-led><div>0</div></div>'

  row.append($("<td></td>").append($("<paper-toggle-button></paper-toggle-button>").prop("checked",enabled ? true : null).on("checked-changed",function(e){
    long_rpc_promise(packageId,"set_hyperlane_service",[device.id, id, e.detail.value]).done()
  }.bind(this))));
  row.append($("<td></td>").text(device.name));
  row.append($("<td></td>").text( name ));
  row.append($("<td></td>").append( $(packets_div).addClass("download") ));
  row.append($("<td></td>").append( $(packets_div).addClass("upload") ));
  row.append($("<td></td>")
    .append($("<paper-icon-button icon='delete-forever'></paper-icon-button>")
    .click((function (device, id) {
      return function () {
        long_rpc_promise( packageId, 
                          "remove_hyperlane_service", 
                          [device.id, id] )
        .done( function () {
            row.remove(); 
        });
      };
    })(device, id))));

  $("#devices", context).append(row);
}

function setRowInformation(id, device, down_packets, up_packets, active){
  $("#devices tr",context).each(function(index, elem){
    elem = $(elem);
    if((elem.attr("app_id") != id || elem.attr("device_id") != device) && !(id === "AUTO" && device === "-1" && index === 0)) return;
    var downDiv = elem.find(".download > div")
    var preDown = downDiv.text()
    downDiv.text(down_packets);
    var upDiv = elem.find(".upload > div");
    var preUp = upDiv.text()
    upDiv.text(up_packets);
    elem.find(".download > granite-led").prop("powered",typeof(active) === "boolean" ? active : preDown != down_packets);
    elem.find(".upload > granite-led").prop("powered",typeof(active) === "boolean" ? active : preUp != up_packets);
  });
}

function apply_stats(stats,auto){
  setRowInformation("AUTO", "-1", auto.rx_packets, auto.tx_packets, auto.active)
  for(var i = 0; i < stats.length; i ++){
    var r_stats = stats[i];
    setRowInformation(r_stats.id,r_stats.device, r_stats.query.rx_packets, r_stats.query.tx_packets, r_stats.query.active);
  }
}

function loadHyperlaneServices(devices, hyperlaneServices) {
  for (var i = 0; i < hyperlaneServices.length; i++) {
    var entry = hyperlaneServices[i];
    var device = devices[entry.device];

    if (!device) {
      throw Error("<%= i18n.deviceNotFoundError %>");
    }

    addDevice(device, entry.id, entry.name, entry.enabled );
  }
}

function on_add_lane( device, service ){
  long_rpc_promise(packageId, "add_hyperlane_service", [
    device.id, 
    JSON.stringify( service )
  ]).done(function (){
    addDevice(device, service); 
  });
}

var panel_slider_file = "/apps/com.netdumasoftware.qos/desktop/sliders.html";
var panel_flower_file = "/apps/com.netdumasoftware.qos/desktop/flower.html";
function add_panels(){
  var thispanel = $("duma-panel",context)[0];
  var panels = $("duma-panels")[0];
  var panelsList = panels.list();
  if(!thispanel.desktop){
    var sliderExists = false;
    var flowerExists = false;
    for(var p = 0; p < panelsList.length; p++){
      var panel = $(panelsList[p].element).find("duma-panel")[0];
      if(panel && panel._file === panel_slider_file)
        sliderExists = true;
      if(panel && panel._file === panel_flower_file)
        flowerExists = true;
    }
    function qosAddPanel(file, data, options) {
      panels.add(
        "/apps/" + packageId + "/desktop/" + file,
        packageId,
        data,
        options
      );
    }
    if(!sliderExists)
      qosAddPanel("sliders.html", [], {
        x: 0, y: 0, width: 12, height: 7
      });
    if(!flowerExists)
      qosAddPanel("flower.html", [], {
        x: 0, y: 7, width: 12, height: 20
      });
  }
}
var panel_hyper_file = "/apps/com.netdumasoftware.qos/desktop/hyper-lane.html";
var panel_info_file = "/apps/com.netdumasoftware.qos/desktop/lane-information.html";
function remove_panels(){
  var panels = $("duma-panels")[0];
  var panelsList = panels.list();
  for(var p = 0; p < panelsList.length; p++){
    var panel = $(panelsList[p].element).find("duma-panel")[0];
    if(panel && panel._file !== panel_hyper_file && panel._file !== panel_info_file){
      panels.remove(panel);
    }
  }
}

function on_add_lanes( device, services, name, custom ){
  long_rpc_promise(packageId, "add_hyperlane_service", [
      device.id,
      name, 
      JSON.stringify( services )
    ]).done(function ( id ){
      addDevice(device, id[0], name, true);

      if (custom) {
        $("#hyperlane-duma-alert", context)[0].open(
          "<%= i18n.manualPortRangeAddedWarning %>",

          [{ text: "<%= i18n.gotIt %>", action: "confirm" }],

          {
            enabled: true,
            packageId: qos.getPackageId(),
            id: "qos-hyperlane-service-added"
          }
        );
      } else {
        $("#hyperlane-duma-alert", context)[0].open(
          "<%= i18n.manualServiceAddedWarning %>",

          [{ text: "<%= i18n.gotIt %>", action: "confirm" }],

          {
            enabled: true,
            packageId: qos.getPackageId(),
            id: "qos-hyperlane-service-added"
          }
        );
      
      }
    });

/*  for( var i = 0; i < services.length; i++ ){
    on_add_lane( device, services[i] );
  } */
}

<% if platform.vendor == "TELSTRA" then %>
function setAcceleration(acc){
  var fullToggle = $("#hardware-acc-toggle",context);
  var spinner = $("#harware-acc-spinner",context);
  fullToggle.prop("disabled",true);
  spinner.attr("hidden",null).attr("active",true);
  long_rpc_promise(packageId, "set_acceleration",[acc]).done(function(){
    fullToggle.prop("disabled",null);
    spinner.attr("hidden",true).attr("active",false);
  });
  if(acc){
    remove_panels();
  }else{
    add_panels();
  }
}
function openAccelerationDialog(acc){
  if(acc){
    //enabled hardware - disable full qos
    $("#full-qos-dialog",context)[0].open();
  }else{
    setAcceleration(acc);
  }
}
function bindAccelerationDialog(){
  var accToggle = $("#hardware-acc-toggle",context);
  var diag = $("#full-qos-dialog",context);
  diag.find("#cancel").on("click",function(){
    diag[0].close();
    accToggle.prop("checked",true);
  });
  diag.find("#confirm").on("click",function(){
    diag[0].close();
    setAcceleration(true);
  });
}
var skipDialog = false;
function bindAcceleration(acc){
  var accToggle = $("#hardware-acc-toggle",context);
  accToggle.prop("checked",!acc);
  accToggle.on("checked-changed",function(e){
    if(e.detail){
      if(skipDialog){
        setAcceleration(!e.detail.value);
        skipDialog = false;
      }else{
        openAccelerationDialog(!e.detail.value);
      }
    }
  });
  return accToggle;
}
<% end %>

function onInit() {
  $("#add-device",context).click(onAddDevice);

  Q.spread([
    get_devices(),
    long_rpc_promise(packageId, "get_hyperlane_services", []),
    long_rpc_promise(packageId, "auto_hyperlane", []),
    <% if platform.vendor == "TELSTRA" then %>
      long_rpc_promise(packageId, "get_acceleration", []),
      long_rpc_promise(packageId, "get_bandwidth", []),
      long_rpc_promise(packageId, "show_welcome", []),
    <% end %>
  ], function (devices, hyperlaneServices, auto_hyperlane , acceleration, bandwidth, welcome) {
    loadHyperlaneServices(devices, JSON.parse( hyperlaneServices[0] ) );

    <% if platform.vendor == "TELSTRA" then %>
      $("#isp-download-speed-input", context).prop("value", bandwidth[1] / (1000 * 1000));
      $("#isp-upload-speed-input", context).prop("value", bandwidth[0] / (1000 * 1000));
    <% end %>

    auto_hyperlane = JSON.parse( auto_hyperlane[0] );
    $("#auto-hyperlane", context).prop("checked", auto_hyperlane );
    $("#auto-hyperlane", context).click(function () {
      var is = JSON.stringify( $("#auto-hyperlane", context).prop("checked") );

      var promise = long_rpc_promise(packageId, "auto_hyperlane", [ is ]);
      qos.showLoaderDialog(loaderDialog, promise);

      promise.done(function () {
        if (!$("#auto-hyperlane", context).prop("checked")) {
          dumaAlert.show(
            "<%= i18n.autoHyperlaneDisableWarning %>",

            [{ text: "<%= i18n.gotIt %>", action: "confirm" }],
            
            {
              enabled: true,
              packageId: qos.getPackageId(),
              id: "qos-auto-stream-boost-warning"
            }
          );
        }
      });
    });
    
    start_cycle(function () {
      return [
        long_rpc_promise(packageId, "stats", []),
        long_rpc_promise(packageId, "auto_hyperlane_stats", []),
      ];
    }, function ( stats, auto ) {
      apply_stats(stats[0] || [], auto[0] || [])
    }, 2000);

    <% if platform.vendor == "TELSTRA" then %>
      var bandwidthToggle = bindAcceleration(acceleration[0]);
      if(!welcome[0] || welcome[0] === ""){
        if(acceleration[0]) add_panels();
        var speedDialog = $("#speeds-dialog",context);
        var highSpeedDialog = $("#high-speeds-dialog",context);
        speedDialog[0].open();
        speedDialog.find("#done-button").on("click",function(e){
          var downSpeed = parseInt($("#isp-download-speed-input",context).prop("value"));
          var upSpeed = parseInt($("#isp-upload-speed-input",context).prop("value"));
          if((downSpeed >= 150 || upSpeed >= 150) && bandwidthToggle[0]){
            highSpeedDialog[0].open();
            highSpeedDialog.find("#done-button").on("click",function(e){
              var radio = highSpeedDialog.find("#hardware-radio");
              var fullQoS = radio.prop("selected") === "off";
              if( fullQoS !== bandwidthToggle.prop("checked") ){
                // Set hardware acceleration
                skipDialog = true;
                bandwidthToggle.prop("checked",fullQoS);
                skipDialog = false;
              }else{
                if(!fullQoS){
                  remove_panels();
                }else{
                  qos.reloadPanel("/apps/com.netdumasoftware.qos/desktop/sliders.html");
                }
              }
              long_rpc_promise(packageId, "show_welcome",[true]).done();
              highSpeedDialog[0].close();
            })
          }else{
            if(bandwidthToggle[0]){
              // Disable hardware acceleration
              bandwidthToggle.prop("checked",true);
            }
            qos.reloadPanel("/apps/com.netdumasoftware.qos/desktop/sliders.html");
            long_rpc_promise(packageId, "show_welcome",[true]).done();
          }
          long_rpc_promise(packageId, "set_bandwidth",[upSpeed * 1000 * 1000, downSpeed * 1000 * 1000]).done(function(){
            speedDialog[0].close();
          });
        });
      }
      bindAccelerationDialog();
    <% end %>

    $("duma-panel", context).prop("loaded", true);
  }).done();
}

function onAddDevice() {
  $(dumaDeviceSelector)[0].open(
    ["Playstation", "Xbox", "Computer", "Laptop"], null, ["hyperlane"], on_add_lanes
  );
}

onInit();

})(this);

//# sourceURL=hyper-lane.js
