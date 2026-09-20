/*
 * (C) 2016 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
*/

(function (context) {

var packageId = "com.netdumasoftware.devicemanager";
var devicePanel = $("#device-panel", context)[0];
var deviceTreePanel = $("#device-tree-panel")[0];
var deviceAlert = $("#device-manager-device-alert", context)[0];

function getDeviceTypeDropdown() {
  return Polymer.dom($("#device-types", context)[0])
    .querySelector(".dropdown-content");
}

function loadDevice(device, deviceTypes) {
  $("#device-name", context).prop("value", device.name);
  getDeviceTypeDropdown().selected = deviceTypes.findIndex(function (e) {
    return e.value.toUpperCase() == device.type.toUpperCase();
  });

  if (device.blocked) {
    $("#block", context).text("<%= i18n.unblock %>");
    $("#block", context).prop("blocked", true);
  } else {
    $("#block", context).text("<%= i18n.block %>");
    $("#block", context).prop("blocked", false);
  }

  for (var i = 0; i < device.interfaces.length; i++) {
    var deviceInterface = device.interfaces[i];
    var interfaceIpsLength = Math.max(deviceInterface.ips.length, 1);
    var row = $("<tr></tr>")
      .append($("<td></td>")  
        .attr("rowspan", interfaceIpsLength)
        .text(deviceInterface.mac.toUpperCase()))
      .append($("<td class='tdip'></td>")  
        .text(deviceInterface.ips[0] ? deviceInterface.ips[0] : ""))
      .append($("<td></td>")  
        .attr("rowspan", interfaceIpsLength)
        .text(deviceInterface.wifi ? "<%= i18n.wireless %>" : "<%= i18n.wired %>"));
    
    $("#device-interfaces", context).append(row);

    for (var p = 1; p < deviceInterface.ips.length; p++) {
      var ipRow = $("<tr></tr>")

      ipRow.append($("<td class='tdip'></td>")
          .text(deviceInterface.ips[p]));
      
      $("#device-interfaces", context).append(ipRow);
    }
  }
}

function loadDeviceTypes(types) {
  var regex = new RegExp("_","g");

  for (var i = 0; i < types.length; i++) {
    Polymer.dom(getDeviceTypeDropdown()).appendChild(
      $("<paper-item value='" + types[i].value + "'>" + types[i].name.replace(regex," ") + "</paper-item>")[0]
    );
  }
}

function updateDevice(deviceId) {
  if (
    !$("#device-name", context)[0].validate() ||
    !$("#device-types", context)[0].validate()
  ) {
    return;
  }

  var deviceName = $("#device-name", context).prop("value");
  var deviceType = getDeviceTypeDropdown().selectedItem.getAttribute("value").toLowerCase();

  Q.spread([
    long_rpc_promise(packageId, "set_device_name", [deviceId, deviceName]),
    long_rpc_promise(packageId, "set_device_type", [deviceId, deviceType])
  ], function () {
    flush_devices_cache();
    $(deviceTreePanel).trigger("device-update", {
      id: deviceId,
      name: deviceName,
      type: deviceType
    });
  });
}

function blockDevice(deviceId) {
  var block = !$("#block", context).prop("blocked");

  long_rpc_promise(
    packageId, "block_device", 
    [deviceId, JSON.stringify(block)]
  ).done(function () {
    flush_devices_cache();

    $("#block", context)
      .text(block ? "Unblock" : "Block")
      .prop("blocked", block);

    $(deviceTreePanel).trigger("device-update", {
      id: deviceId,
      blocked: block
    });

    if (block) {
      deviceAlert.show(
        "<%= i18n.deviceBlockedWarning %>",

        [{ text: "<%= i18n.gotIt %>", action: "confirm" }], 

        {
          enabled: true,
          packageId: packageId,
          id: "devicemanager-device-block-warning"
        } 
      );
    }
  });
}

function deleteDevice(deviceId) {
  long_rpc_promise(packageId, "delete_device", [deviceId])
    .done(function (success) {
      flush_devices_cache();

      if (success)  {
        devicePanel.close();

        $(deviceTreePanel).trigger("device-update", {
          id: deviceId,
          delete: true
        });

      } else {
        deviceAlert.show("<%= i18n.deviceRemovalError %>");
      }
    });
}

function bindButtonClicks(deviceId, deviceTypes) {
  $("#update", context).click(function () {
    updateDevice(deviceId);
  });

  $("#block", context).click(function () {
    blockDevice(deviceId);
  });

  $("#delete", context).click(function () {
    deleteDevice(deviceId);
  });
}

function validateDeviceName() {
  return false;
}

function initialise() {
  var data = devicePanel.data;

  $("#delete", context).prop("hidden", devicePanel.desktop);

  Q.spread([
    get_devices(),
    long_rpc_promise(packageId, "get_types", [])
  ], function (devices, types) {
    var device = devices[data.deviceId];
    var processedTypes = [];
    for (var k in types[0]) {
      if (types[0].hasOwnProperty(k)) {
        processedTypes.push({
          name: types[0][k],
          value: k
        });
      }
    }

    processedTypes.sort(function(lhs,rhs) { 
      if (lhs.name < rhs.name) {
        return -1;
      } else if (lhs.name > rhs.name) {
        return 1;
      } else {
        return 0;
      }
    });

    loadDeviceTypes(processedTypes);
    if (device) {
      loadDevice(device, processedTypes);
      bindButtonClicks(data.deviceId, processedTypes);
    } else {
      devicePanel.unpin();
      devicePanel.close();
    }
   
    $(devicePanel).prop("loaded", true);
  }).done();
}

initialise();

})(this);

//# sourceURL=device.js
