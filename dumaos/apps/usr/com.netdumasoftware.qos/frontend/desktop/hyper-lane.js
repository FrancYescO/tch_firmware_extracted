/*
 * (C) 2017 NETDUMA Software
 * Kian Cross
*/

<%
require "libos"
local platform = os.platform_information()
local showUpload = platform.vendor ~= "TELSTRA"

local static_rows = {
  {
    name = "hyperlane",
    servicesHelp = "gaming, hyperlane",
    json = true,
    disabledWarning = i18n.autoHyperlaneDisableWarning
  }
}
%>

  <%
    table.insert(static_rows,
    {
      name = "cloud_gaming",
      servicesHelp = "Cloud Gaming",
      json = false,
      disabledWarning = i18n.autoCloudGamingDisableWarning
    })
  %>

  <%
    table.insert(static_rows,
    {
      name = "wfh",
      servicesHelp = "WorkAtHome",
      json = false,
      disabledWarning = i18n.autoWorkDisableWarning
    })
  %>



(function (context) {

var packageId = "com.netdumasoftware.qos";
var dumaAlert = $("#hyperlane-duma-alert", context)[0];
var dumaDeviceSelector = $("duma-device-selector", context)[0];
var loaderDialog = $("#hyperlane-loader-dialog", context)[0];
var wirelessTypeDialog = $("#wireless-type-dialog", context);

/** wme 802.11e standard: http://wiki.internal.netduma.com//books/networking/page/aggregate-traffic-qos */
var wirelessTypes = {
  ["0"]: "<%= i18n.wirelessTypeNormal %>",
  ["4"]: "<%= i18n.wirelessTypeVideo %>",
  ["6"]: "<%= i18n.wirelessTypeGame %>",
}

/** ported from dumaweb */
var categoryToWirelessType = {
  // normal
  "Chat & Messaging": 0,
  "Email": 0,
  "File Sharing": 0,
  "Internet Maintenance": 0,
  "Printers": 0,
  "Remote Access": 0,
  "Social Media": 0,
  "Uncategorised": 0,
  "Uncategorized": 0,
  "VPN": 0,
  "Web (General)": 0,

  // video
  "Cloud Gaming": 4,
  "Livestream": 4,
  "Media": 4,
  "WorkAtHome": 4,

  // voice
  "VoIP": 6,
  "Gaming": 6,
}

function GetWirelessTypeForApplicationCategory(category) {
  return categoryToWirelessType[category] || 0;
}

function addDevice(device, id, name, enabled, wirelessType, applyWAN) {
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
      && !((
      <% for k,v in pairs(static_rows) do %>
        (id === "_AUTO_<%= v.name %>" && index === <%= k-1 %>) ||
      <% end %>
      false ) && index <= <%= #static_rows %>)) return;
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

function apply_stats(stats <% for k,v in pairs(static_rows) do %>, auto_<%= v.name %> <% end %> ){
  
  <% for k,v in pairs(static_rows) do %>
  setRowInformation("_AUTO_<%= v.name %>", "-1", auto_<%= v.name %>.rx_packets, auto_<%= v.name %>.tx_packets, auto_<%= v.name %>.active);
  <% end %>

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
  if(!wirelessType){
    var apps = dumaDeviceSelector._services;
    wirelessType = 0
    for(var i = 0; i < apps.length; i++){
      var app = apps[i];
      if(app.application == name){
        wirelessType = app.wirelessType || GetWirelessTypeForApplicationCategory(app.category);
        break;
      }
    }
  }
  if(!doWAN)
    doWAN = false;
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
    <% for k,v in pairs(static_rows) do %>long_rpc_promise(packageId, "auto_<%= v.name %>", []),
    <% end %>
    <% if platform.vendor == "TELSTRA" then %>
      long_rpc_promise(packageId, "get_acceleration", []),
      long_rpc_promise(packageId, "get_bandwidth", []),
      long_rpc_promise(packageId, "show_welcome", []),
    <% end %>
  ], function (devices, hyperlaneServices <% for k,v in pairs(static_rows) do %>, auto_<%= v.name %> <% end %> , acceleration, bandwidth, welcome) {
    loadHyperlaneServices(devices, JSON.parse( hyperlaneServices[0] ) );

    <% if platform.vendor == "TELSTRA" then %>
      $("#isp-download-speed-input", context).prop("value", bandwidth[1] / (1000 * 1000));
      $("#isp-upload-speed-input", context).prop("value", bandwidth[0] / (1000 * 1000));
      $(".download-speed-display .speed-show span", context).text(bandwidth[1] / (1000 * 1000));
      $(".upload-speed-display .speed-show span", context).text(bandwidth[0] / (1000 * 1000));
    <% end %>

    <% for k,v in pairs(static_rows) do %>

    <% if v.json then %>
    auto_<%= v.name %> = JSON.parse( auto_<%= v.name %>[0] );
    <% else %>
    auto_<%= v.name %> = auto_<%= v.name %>[0];
    <% end %>


    $("#auto-<%= v.name %>", context).prop("checked", auto_<%= v.name %> );
    $("#auto-<%= v.name %>", context).click(function () {

      <% if v.json then %>
      var is = JSON.stringify( $("#auto-<%= v.name %>", context).prop("checked") );
      <% else %>
      var is = $("#auto-<%= v.name %>", context).prop("checked");
      <% end %>
      

      var promise = long_rpc_promise(packageId, "auto_<%= v.name %>", [ is ]);
      qos.showLoaderDialog(loaderDialog, promise);

      promise.done(function () {
        if (!$("#auto-<%= v.name %>", context).prop("checked")) {
          dumaAlert.show(
            "<%= v.disabledWarning %>",

            [{ text: "<%= i18n.gotIt %>", action: "confirm" }],
            
            {
              enabled: true,
              packageId: qos.getPackageId(),
              id: "qos-auto-<%= v.name %>-boost-warning"
            }
          );
        }
      });
    });

    <% end %>

    // $("#auto-work", context).prop("checked", auto_wfh[0] );
    // $("#auto-work", context).click(function () {
    //   var is = $("#auto-work", context).prop("checked");

    //   var promise = long_rpc_promise(packageId, "auto_wfh", [ is ]);
    //   qos.showLoaderDialog(loaderDialog, promise);

    //   promise.done(function () {
    //     if (!$("#auto-work", context).prop("checked")) {
    //       dumaAlert.show(
    //         "<%= i18n.autoWorkDisableWarning %>",

    //         [{ text: "<%= i18n.gotIt %>", action: "confirm" }],
            
    //         {
    //           enabled: true,
    //           packageId: qos.getPackageId(),
    //           id: "qos-auto-work-boost-warning"
    //         }
    //       );
    //     }
    //   });
    // });
    
    start_cycle(function () {
      return [
        long_rpc_promise(packageId, "stats", []),
        <% for k,v in pairs(static_rows) do %>long_rpc_promise(packageId, "auto_<%= v.name %>_stats", []),
        <% end %>
      ];
    }, function ( stats <% for k,v in pairs(static_rows) do %>, auto_<%= v.name %> <% end %> ) {
      apply_stats(stats[0] || [] <% for k,v in pairs(static_rows) do %>, auto_<%= v.name %>[0] || [] <% end %> );
    }, 2000);

    <% if platform.vendor == "TELSTRA" then %>
      var bandwidthToggle = bindAcceleration(acceleration[0]);
      if(!welcome[0] || welcome[0] === ""){
        if(acceleration[0]) add_panels();
        bindWelcomeDialogClicks(bandwidthToggle,bandwidth);
      }
      bindAccelerationDialog();
    <% end %>

  
    <% for k,v in pairs(static_rows) do %>$("#<%= v.name %>-help", context).on("click", function (e) {
      var services = $(top.document).find("#services-info")[0];
      if(services) services.open("<%= v.servicesHelp %>");
    });
    <% end %>
  
    $("duma-panel", context).prop("loaded", true);
  }).done();
}

function onAddDevice() {
  $(dumaDeviceSelector)[0].open(
    ["Playstation", "Xbox", "Computer", "Laptop"], null, ["hyperlane"], on_add_lanes, null, open_wireless_type
  );
}

onInit();

})(this);

//# sourceURL=hyper-lane.js
