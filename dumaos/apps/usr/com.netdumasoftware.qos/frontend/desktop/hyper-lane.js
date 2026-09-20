/*
 * (C) 2017 NETDUMA Software
 * Kian Cross
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
var wirelessTypeDialog = $("#wireless-type-dialog", context);

var wirelessTypes = {
  ["0"]: "<%= i18n.wirelessTypeNormal %>",
  ["4"]: "<%= i18n.wirelessTypeVideo %>",
  ["6"]: "<%= i18n.wirelessTypeGame %>",
}

function addDevice(device, id, name, enabled, wirelessType, applyWAN) {
  var row = $("<tr></tr>").attr("app_id",id).attr("device_id",device.id);

  var menu = $("<paper-menu-button></paper-menu-button>");
  Polymer.dom(menu[0]).appendChild($("<paper-icon-button></paper-icon-button>")
    .attr("icon", "menu")
    .addClass("dropdown-trigger")[0]
  );

  var packets_div = '<div class="packets"><granite-led></granite-led><div>0</div></div>'

  row.append($("<td></td>").append($("<paper-toggle-button></paper-toggle-button>").attr("aria-label","<%= i18n.ariaToggleEnable %>".format(name)).prop("checked",enabled ? true : null).on("checked-changed",function(e){
    long_rpc_promise(packageId,"set_hyperlane_service",[device.id, id, e.detail.value]).done()
  }.bind(this))));
  row.append($("<td></td>").text( name ));
  row.append($("<td class='max-width'></td>").text(device.name));
  row.append($("<td></td>").append( $(packets_div).addClass("download") ));
  row.append($("<td></td>").append( $(packets_div).addClass("upload") ));
  row.append($("<td></td>").append( $(document.createElement("div")).addClass("wireless-type").text(
    wirelessTypes[(wirelessType || 0).toString()]
    + (applyWAN ? " (<%= i18n.wan %>)" : "")
    )));
  row.append($("<td></td>")
    .append($("<paper-icon-button icon='delete-forever'></paper-icon-button>")
    .attr("aria-label","<%= i18n.delete %>".format(name))
    .click((function (device, id) {
      return function () {
        loaderDialog.open();
        long_rpc_promise( packageId, 
          "remove_hyperlane_service", 
          [device.id, id] )
          .done( function () {
            row.remove(); 
            loaderDialog.close();
        });
      };
    })(device, id))));

  $("#devices", context).append(row);
}

function setRowInformation(id, device, down_packets, up_packets, active){
  $("#devices tr",context).each(function(index, elem){
    elem = $(elem);
    if((elem.attr("app_id") != id || elem.attr("device_id") != device)
      && !((id === "_AUTOHYPER" && index === 0) || (id === "_AUTOWORK" && index === 1) && index <= 1)) return;
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

function apply_stats(stats,autohyper,autowork){
  setRowInformation("_AUTOHYPER", "-1", autohyper.rx_packets, autohyper.tx_packets, autohyper.active);
  setRowInformation("_AUTOWORK", "-1", autowork.rx_packets, autowork.tx_packets, autowork.active);
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

    addDevice(device, entry.id, entry.name, entry.enabled , entry.wmm, entry.apply_wan_dscp );
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

var __wirelessTypeCallback__ ;
function open_wireless_type( device, services, name, custom){
  var chooseWifiList = wirelessTypeDialog.find("#choose-wifi-type");
  var wanCheckbox = wirelessTypeDialog.find("#with-wan");
  var submitButton = wirelessTypeDialog.find("#submit-wifi-type");

  if(!__wirelessTypeCallback__) {
    submitButton.on("click",function(){
      __wirelessTypeCallback__();
      wirelessTypeDialog[0].close();
    });
  }
  __wirelessTypeCallback__ = function(){
    on_add_lanes(device, services, name, custom, chooseWifiList.prop("selected"), wanCheckbox.prop("checked"));
  }
  wanCheckbox.prop("checked", false);
  chooseWifiList.prop("selected", "0");
  wirelessTypeDialog[0].open();
}

function on_add_lanes( device, services, name, custom, wirelessType, doWAN ){
  long_rpc_promise(qos.getPackageId(), "add_hyperlane_service", [
      device.id,
      name, 
      JSON.stringify( services ),
      parseInt(wirelessType),
      doWAN
    ]).done(function ( id ){
      addDevice(device, id[0], name, true, wirelessType, doWAN);

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

function openDisableDialogIfOver(bandwidthToggle,downSpeed,upSpeed){
  if((downSpeed >= 150 || upSpeed >= 150) && bandwidthToggle[0]){
    var highSpeedDialog = $("#high-speeds-dialog",context);
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
    });
    highSpeedDialog.find("#back-to-enter-button").on("click",function(){
      highSpeedDialog[0].close();
      $("#enter-speeds-dialog",context)[0].open();
    })
  }else{
    if(bandwidthToggle[0]){
      // Disable hardware acceleration
      bandwidthToggle.prop("checked",true);
    }
    qos.reloadPanel("/apps/com.netdumasoftware.qos/desktop/sliders.html");
    long_rpc_promise(packageId, "show_welcome",[true]).done();
  }
}

function bindWelcomeDialogClicks(bandwidthToggle,origBandwidth){
  var speedDialog = $("#speeds-dialog",context);
  var enterSpeedDialog = $("#enter-speeds-dialog",context);

  speedDialog[0].open();
  speedDialog.find("#done-button").on("click",function(e){
    openDisableDialogIfOver(bandwidthToggle, origBandwidth[1] / (1000 * 1000), origBandwidth[0] / (1000 * 1000));
    speedDialog[0].close();
  });
  speedDialog.find("#enter-manual-button").on("click",function(e){
    speedDialog[0].close();
    enterSpeedDialog[0].open();
  });
  enterSpeedDialog.find("#done-button").on("click",function(e){
    var downSpeed = parseInt($("#isp-download-speed-input",context).prop("value"));
    var upSpeed = parseInt($("#isp-upload-speed-input",context).prop("value"));
    openDisableDialogIfOver(bandwidthToggle,downSpeed,upSpeed);
    long_rpc_promise(packageId, "set_bandwidth",[upSpeed * 1000 * 1000, downSpeed * 1000 * 1000]).done(function(){
      enterSpeedDialog[0].close();
    });
  });
  enterSpeedDialog.find("#back-to-welcome-button").on("click",function(e){
    enterSpeedDialog[0].close();
    speedDialog[0].open();
  });
}
<% end %>

function onInit() {
  $("#add-device",context).click(onAddDevice);

  Q.spread([
    get_devices(),
    long_rpc_promise(packageId, "get_hyperlane_services", []),
    long_rpc_promise(packageId, "auto_hyperlane", []),
    <% if platform.model ~= "XR500" and platform.model ~= "XR700" then %>long_rpc_promise(packageId, "auto_wfh", [])<% else %>[]<% end %>,
    <% if platform.vendor == "TELSTRA" then %>
      long_rpc_promise(packageId, "get_acceleration", []),
      long_rpc_promise(packageId, "get_bandwidth", []),
      long_rpc_promise(packageId, "show_welcome", []),
    <% end %>
  ], function (devices, hyperlaneServices, auto_hyperlane, auto_wfh , acceleration, bandwidth, welcome) {
    loadHyperlaneServices(devices, JSON.parse( hyperlaneServices[0] ) );

    <% if platform.vendor == "TELSTRA" then %>
      $("#isp-download-speed-input", context).prop("value", bandwidth[1] / (1000 * 1000));
      $("#isp-upload-speed-input", context).prop("value", bandwidth[0] / (1000 * 1000));
      $(".download-speed-display .speed-show span", context).text(bandwidth[1] / (1000 * 1000));
      $(".upload-speed-display .speed-show span", context).text(bandwidth[0] / (1000 * 1000));
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

    $("#auto-work", context).prop("checked", auto_wfh[0] );
    $("#auto-work", context).click(function () {
      var is = $("#auto-work", context).prop("checked");

      var promise = long_rpc_promise(packageId, "auto_wfh", [ is ]);
      qos.showLoaderDialog(loaderDialog, promise);

      promise.done(function () {
        if (!$("#auto-work", context).prop("checked")) {
          dumaAlert.show(
            "<%= i18n.autoWorkDisableWarning %>",

            [{ text: "<%= i18n.gotIt %>", action: "confirm" }],
            
            {
              enabled: true,
              packageId: qos.getPackageId(),
              id: "qos-auto-work-boost-warning"
            }
          );
        }
      });
    });
    
    start_cycle(function () {
      return [
        long_rpc_promise(packageId, "stats", []),
        long_rpc_promise(packageId, "auto_hyperlane_stats", []),
        <% if platform.model ~= "XR500" and platform.model ~= "XR700" then %>long_rpc_promise(packageId, "auto_wfh_stats", [])<% else %>[]<% end %>,
      ];
    }, function ( stats, autoHyper, autoWork ) {
      apply_stats(stats[0] || [], autoHyper[0] || [], autoWork[0] || []);
    }, 2000);

    <% if platform.vendor == "TELSTRA" then %>
      var bandwidthToggle = bindAcceleration(acceleration[0]);
      if(!welcome[0] || welcome[0] === ""){
        if(acceleration[0]) add_panels();
        bindWelcomeDialogClicks(bandwidthToggle,bandwidth);
      }
      bindAccelerationDialog();
    <% end %>

  
    $("#games-help", context).on("click", function (e) {
      var services = $(top.document).find("#services-info")[0];
      if(services) services.open("gaming, hyperlane");
    });
  
    $("#work-help", context).on("click", function (e) {
      var services = $(top.document).find("#services-info")[0];
      if(services) services.open("WorkAtHome");
    });

    $("duma-panel", context).prop("loaded", true);
  }).done();
}

function onAddDevice() {
  $(dumaDeviceSelector)[0].open(
    ["Playstation", "Xbox", "Computer", "Laptop"], null, ["hyperlane"], open_wireless_type
  );
}

onInit();

})(this);

//# sourceURL=hyper-lane.js
