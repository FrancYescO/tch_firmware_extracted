/*
 * (C) 2016 NETDUMA Software
 * Kian Cross
*/

<%
require "libos"
local platform_information = os.platform_information()
%>

(function (context) {

var deviceManagerPackageId = "com.netdumasoftware.devicemanager";
var deviceTreePanel = $("#device-tree-panel", context)[0];
var deviceEdit = $("#device-edit", context)[0];

var exportContent = "";

function setDeviceClipboardExport(devices){
  exportContent = "";
  for(var i = 0; i < devices.length; i++){
    var device = devices[i];
    var toAdd = "{0} {1}\n".format(device.mac, device.name || "unnamed device");
    exportContent += toAdd;
  }
}

function isDeviceOnline(device,matches) {

  var activeWirelessInterface = device.interfaces.find(function(v) {
    var match = matches && matches[v.mac.toUpperCase()];
    return typeof v.ssid === "string" || (match && match.online);
  });

  /* A device can have an IP address even though its offline.
  This allows a device to go offline even though it still has an "online" interface.
  A device can be online, but forced into an "offline" display by matches check above ^^^.
  Solution to this was filtering out connections to the modem in matches, leaving only extender matches.
  */
  var onlineInterface = getOnlineInterface(device);
  if (onlineInterface && onlineInterface.wifi && !activeWirelessInterface) {
    return false;
  }

  for (var i = 0; i < device.interfaces.length; i++) {
    if (device.interfaces[i].ips.length > 0) {
      return true;
    }
  }
  return false;
}

function getOnlineInterface(device) {
  for (var i = 0; i < device.interfaces.length; i++) {
    if (device.interfaces[i].ips.length > 0) {
      return device.interfaces[i];
    }
  }
}

function findExtender(interfaces,extenders,matches){
  for(var m = 0; m < interfaces.length && extenders && extenders.length; m++){
    var devmac = interfaces[m].mac.toUpperCase();
    if(matches[devmac]){
      var extmac = matches[devmac].ext;
      for(var i = 0; i < extenders.length; i++){
        if(extenders[i].mac === extmac){
          return [extenders[i], matches[devmac]];
        }
      }
    }
  }
  return null;
}

function extenderIcon(extender){
  // return "duma-icons:" + extender.brand + "_extender"
  return "duma-icons:other_extender"
}

function processDevicesForTree(devices, extenders, matches) {
  var icons = duma.devices.type_to_device_icons_array;
  
  var wired = {
    name: "<%= i18n.lan %>",
    id: "wired",
    img: duma.devices.get_devices_icon('wired'),
    active: true,
    children: [],
    type: "wired"
  };

  var wan = {
    name: "<%= i18n.wan %>",
    id: "wan",
    img: duma.devices.get_devices_icon('wired'),
    active: true,
    children: [
<% if platform_information.vendor ~= "TELSTRA" then %>
      {
      name: "<%= i18n.modem %>", 
      img: duma.devices.get_devices_icon('modem'),
      id: "modem",
      active: true
    }
<% end %>
    ],
    type: "wan"
  };

  var wireless = {
    name: "<%= i18n.wifi %>",
    id: "wireless",
    img:  duma.devices.get_devices_icon('wireless'),
    active: true,
    children: []
  };

  var mul_wireless = [];

  var offline = {
    name: "<%= i18n.offline %>",
    id: "offline",
    img: duma.devices.get_devices_icon('offline'),
    active: true,
    children: [],
    type: "offline"
  };

  var ext_nodes = [];

  if(extenders && extenders.length){
    for(var i = 0; i < extenders.length; i++){
      var ext = extenders[i];
      var tree_node = {
        name: ext.name,
        id: "extender-" + i.toString(),
        img: extenderIcon(ext),
        active: true,
        children: [],
        type: ext.type,
        isclickable: false
      }
      ext.tree_node = tree_node;
      ext_nodes.push(tree_node);
    }
  }

  for (var id in devices) {
    if (devices.hasOwnProperty(id)) {
      if (id == 0 && devices[id].type == "null") {
        continue;
      }

      var device = devices[id];
      var p;
      var connect_type;
      if (isDeviceOnline(device,matches)) {
        var extinfo = findExtender(device.interfaces,extenders,matches)
        if(extinfo && extinfo.length){
          p = extinfo[0].tree_node;
          connect_type = (extinfo[1].connect_type == "Ether" || extinfo[1].connect_type == "wired") ? "wired" : "wireless";
        }else if (getOnlineInterface(device).wifi) {
          var inf = device.interfaces.find( function( v ){ 
            return typeof v.ssid === 'string';
          });

          if( inf ){
            var freq_prefix = "";
            if( typeof inf.freq === 'string' ) 
              freq_prefix = "(" + inf.freq + "GHz) "
            var inf_name = freq_prefix + inf.ssid;
            var inf_id = "wireless-" + freq_prefix + inf.ssid;

            
            p = mul_wireless.find( function( v ){ 
              return v.name == inf_name; 
            });
            

            if( !p ){

              p = {
                name: inf_name,
                id: inf_id,
                img:  duma.devices.get_devices_icon('wireless'),
                active: true,
                children: []
              };
              mul_wireless.push( p );
            }
            connect_type = "wireless";
          } else {
            p = offline;    // p = wireless; stainfo d/c fast
            connect_type = "offline";
          }
        } else {
          p = wired;
          connect_type = "wired";
        }
      } else {
        p = offline;
        connect_type = "offline";
      }
    }

    device.type = typeof device.type === "string" ? device.type : "";

    p.children.push({
      id: device.id,
      name: device.name,
      img: duma.devices.get_devices_icon(device.type.toLowerCase()),
      active: !device.blocked,
      isclickable: true,
      type: connect_type
    });
  }

  var data = {
<% if platform_information.vendor == "TELSTRA" then %>
    name: "<%= i18n.modem %>",
    id: "modem",
    img: "/apps/com.netdumasoftware.ngportal/shared/settings.svg",
    active: true,
    children: []
<% else %>
    name: "<%= i18n.router %>",
    id: "router",
    img: duma.devices.get_devices_icon('router'),
    active: true,
    children: []
<% end %>
  }
  
  ext_nodes.forEach( function( v ){
    //Add different 5Ghz and 2.4 Ghz here?
    if(v.type === "offline")
      offline.children.push( v )
    else if(v.type === "wireless")
      wireless.children.push( v );
    else if(v.type === "wired")
      wired.children.push( v );
    else
      data.children.push( v );
  });
  if (wired.children.length > 0) data.children.push(wired);
  if (wan.children.length > 0) data.children.push(wan);
  if (wireless.children.length > 0) data.children.push(wireless);
  if (offline.children.length > 0) data.children.push(offline);
  mul_wireless.forEach( function( v ){
    if( v.children.length > 0 ) data.children.push( v );
  });

  return data;

}

function modifyNodeOnTree(tree, id, data) {
  if (tree.id == id) {
    if (data.img) {
      tree.img = data.img;
      return true;
    }
    if (data.name) {
      tree.name = data.name;
      return true;
    }
    if( typeof( data.blocked ) === "boolean" ){
      tree.active = !data.blocked;
      return true;
    }
  } else if (tree.children) {
    for (var i = 0; i < tree.children.length; i++) {
      if (modifyNodeOnTree(tree.children[i], id, data)) {
        return true;
      }
    }
  }
}

function deleteNodeOnTree( tree, id ){
  if( !tree.children )
    return false;

  for( var i = 0; i < tree.children.length; i++ ){
    var child = tree.children[i];

    if( child.id == id ){
      tree.children.splice( i, 1 );
      return true;
    } else if( deleteNodeOnTree( child, id ) ) {
      if( child.children && !child.children.length )
        tree.children.splice( i, 1 );
      return true;
    }
  }
  return false;
}

function deleteAllOffline() {
  long_rpc_promise(deviceManagerPackageId,"delete_all_offline",[]).done();
}

function checkIfInternalDevice(id) {
  var sid = id.toString();
  return id == "wan" || id == "wired" || sid.startsWith( "wireless" )
         || id == "offline" || id == "router" || id == "modem";
}

function showDeviceView(mode) {
  switch(mode) {
    case "tree":
      $("#table-wrapper", context).hide();
      $("#device-tree", context).show();
      break;

    case "table":
      $("#device-tree", context).hide();
      $("#table-wrapper", context).show();

      break;
  }
}

function setupViewModeToggle() {
  $("#mode-selector", context).on("iron-select", function () {
    showDeviceView(this.selected);
    duma.storage(deviceManagerPackageId, "deviceViewMode", this.selected);
  });

  var viewMode = duma.storage(deviceManagerPackageId, "deviceViewMode");
  viewMode = viewMode ? viewMode : "tree";
  $("#mode-selector", context).prop("selected", viewMode);
  showDeviceView(viewMode);
}

function getDuplexTitle(fullDuplex) {
  if (typeof fullDuplex !== "undefined") {
    return fullDuplex === true ? "<%= i18n.fullDuplex %>" : "<%= i18n.halfDuplex %>";
  }
}

function getLinkSpeedTitle(speed) {
  if (typeof speed !== "undefined") {
    return speed + "Mbits";
  }
}

function setProcessedDeviceIndexes(processedDevice) {
  processedDevice.nameIndex = processedDevice.name.toLowerCase();
  processedDevice.typeIndex = processedDevice.type.toLowerCase();
  processedDevice.connectionTypeIndex = processedDevice.connectionType.toLowerCase();
  processedDevice.ssidIndex = processedDevice.ssid.toLowerCase();
  processedDevice.connectionStatusIndex = processedDevice.connectionStatus.toLowerCase();
  processedDevice.duplexIndex = processedDevice.duplex.toLowerCase();
}

function get_ipv4(ips){
  for(var i = 0; i < ips.length; i++){
    var ip = ips[i];
    if(ip.indexOf(".") > -1){
      return ip;
    }
  }
}

function processDevicesForTable(devices, portStates, arlTable) {
  var processedDevices = [];

  for (var deviceId in devices) {
    if (devices.hasOwnProperty(deviceId)) {
      var device = devices[deviceId];
      var interface = device.interfaces[0];
      
      if (device.id === 0) {
        continue;
      }

      var processedDevice = {
        deviceId: device.id,
        name: device.name,
        type: device.type.replace(new RegExp("_","g")," "),
        connectionType: interface.wifi ? "<%= i18n.wireless %>" : "<%= i18n.wired %>",
        ssid: interface.ssid ? interface.ssid : "<%= i18n.notAplicable %>",
        mac: interface.mac.toUpperCase(),
        //we just want to display the ipv4 here, not all ips.
        ips: isDeviceOnline(device) ? get_ipv4(interface.ips) : "<%= i18n.notAplicable %>",
        frequency: interface.freq ? interface.freq + "GHz" : "<%= i18n.notAplicable %>",
        signalStrength: interface.signal ? interface.signal + "dBm" : "<%= i18n.notAplicable %>",
        connectionStatus: isDeviceOnline(device) ? "<%= i18n.online %>" : "<%= i18n.offline %>",
        portNumber: "<%= i18n.notAplicable %>",
        duplex: "<%= i18n.notAplicable %>",
        speed: "<%= i18n.notAplicable %>"
      };

      setProcessedDeviceIndexes(processedDevice);
      
      if (arlTable && !interface.wifi) {
        var port = arlTable[interface.mac];
        var portState = portStates[port];

        if (isDeviceOnline(device) && portState) {
          var duplex = getDuplexTitle(portState.full_duplex);
          var speed = getLinkSpeedTitle(portState.speed);

          processedDevice.portNumber = portState.label;
          processedDevice.duplex = duplex ? duplex : "<%= i18n.notAplicable %>";
          processedDevice.speed = speed ? speed : "<%= i18n.notAplicable %>";
        }
      }

      processedDevices.push(processedDevice);
    }
  }

  setDeviceClipboardExport(processedDevices);

  return processedDevices;
}

function processPortsForTable(portStates) {
  var processedPorts = [];

  for (var portNumber in portStates) {
    if (portStates.hasOwnProperty(portNumber)) {

      var portState = portStates[portNumber];

      if (portState) {

        var duplex = getDuplexTitle(portState.full_duplex);
        var speed = getLinkSpeedTitle(portState.speed);

        var processedPort = {
          portNumber: portState.label,
          duplex: duplex ? duplex : "<%= i18n.notAplicable %>",
          speed: speed ? speed : "<%= i18n.notAplicable %>",
          connectionStatus: portState.up ? "<%= i18n.connected %>" : "<%= i18n.disconnected %>"
        };

        processedPort.duplexIndex = processedPort.duplex.toLowerCase();

        processedPorts.push(processedPort);
      }
    }
  }

  return processedPorts;
}

function bindOnDeviceClicks() {

  $("#device-tree", context).on("iconclick", function (e, id) {
    deviceEdit.open(id);
  });
  
  $("#devices-table", context).on("selecting-item", function (event) {
    deviceEdit.open(event.detail.item.deviceId);
  });

  $("#offline-delete",context).on("click",function(){
    $("#delete-offline-alert")[0].open("",[
      {text:"<%= i18n.cancelDeleteOffline %>",default:false,action:"dismiss"},
      {text:"<%= i18n.continueDeleteOffline %>",default:true,action:"confirm",callback: function(){
        deleteAllOffline();
      }.bind(this)},
    ]);
  });
}

function processDeviceUpdateForTree(properties) {
  var treeData = $("#device-tree", context)[0].data;

  if (properties.name) {
    modifyNodeOnTree(treeData, properties.id, {
      name: properties.name
    });
  }

  if (properties.type) {
    modifyNodeOnTree(treeData, properties.id, {
      img: duma.devices.get_devices_icon(properties.type)
    });
  }

  if (properties.delete) {
    deleteNodeOnTree(treeData, properties.id);
  }

  if (typeof(properties.blocked) === "boolean") {
    modifyNodeOnTree(treeData, properties.id, {
      blocked: properties.blocked
    });
  }

  var tree = $("#device-tree", context)[0];
  tree.data = treeData;
  tree.invalidateData();
}

function processDeviceUpdateForTable(properties) {
  var binder = $("#table-binder", context)[0];
  var devicesTable = binder.devices.slice(0);

  var deviceIndex = devicesTable.findIndex(function (entry) {
    return entry.deviceId === properties.id;
  });

  var device = devicesTable[deviceIndex];

  if (properties.name) {
    device.name = properties.name;
  }

  if (properties.type) {
    device.type = properties.type;
  }
  
  if (properties.blocked) {
    device.locked = properties.blocked;
  }

  if (properties.delete) {
    devicesTable.splice(deviceIndex, 1);
  }

  setProcessedDeviceIndexes(device);

  updatePolymerTableArray(binder, "devices", devicesTable, "deviceId");
}

function bindOnDeviceUpdate() {
  $(deviceTreePanel).add(document).on("device-update", function (e, properties) {
    processDeviceUpdateForTree(properties);
    processDeviceUpdateForTable(properties);
  });
}

function removeUnmatchedEntriesFromPolymerArray(element, basePath, mask, id) {
  var base = element.get(basePath);

  for (var i = 0; i < base.length; i++) {

    var baseEntry = base[i];
    var maskEntry = mask.find(function (entry) {
      return baseEntry[id] === entry[id];
    });

    if (!maskEntry) {
      element.splice(basePath, i, 1);
    }
  }
}

function maskPolymerArrays(element, basePath, currentEntryIndex, newEntry) {
  var currentEntry = element.get([basePath, currentEntryIndex]);

  for (var key in currentEntry) {
    if (currentEntry.hasOwnProperty(key)) {
      currentEntry[key] = newEntry[key];
      element.notifyPath(basePath + "." + currentEntryIndex + "." + key);
    }
  }

  for (var key in newEntry) {
    if (newEntry.hasOwnProperty(key)) {
      currentEntry[key] = newEntry[key];
      element.notifyPath(basePath + "." + currentEntryIndex + "." + key);
    }
  }
}

function updatePolymerTableArray(element, basePath, newTable, id) {

  for (var i = 0; i < newTable.length; i++) {
    var newEntry = newTable[i];
    var currentEntryIndex = element.get(basePath).findIndex(function (entry) {
      return entry[id] === newEntry[id];
    });

    if (currentEntryIndex > -1) {
      maskPolymerArrays(element, basePath, currentEntryIndex, newEntry) ;   
    } else {
      element.push(basePath, newEntry);
    }
  }

  removeUnmatchedEntriesFromPolymerArray(element, basePath, newTable, id);
}

function processExtenders(extenders){
  if(extenders.length == 1) extenders = extenders[0];
  if(!extenders || !extenders.length) return [];
  var new_exts = new Array(extenders.length);
  for(var i = 0; i < extenders.length; i++){
    var extender = extenders[i];
    var append = {
      name: extender.name || "Unknown Extender",
      mac: extender.mac,
      brand: extender.brand,
      type: "offline"
    }
    if(extender.owl){
      append.type = extender.owl.connect_type == "Ether" ? "wired" : "wireless";
      append.name = extender.owl.device_name;
    }else if(extender.agent){
      if(extender.agent.NoOfRadios !== "")
      append.type = extender.agent.NoOfRadios == "" ? "offline" : "wireless";
      append.name = extender.agent.Alias;
    }
    new_exts[i] = append;
  }
  return new_exts
}
function filterMatches(extenders,matches){
  var filtered = {};
  if(matches && extenders && extenders.length){
    matches = matches[0];
    for(var k in matches){
      var m = matches[k];
      for(var i = 0; i < extenders.length; i++){
        if(extenders[i].mac.toUpperCase() === m.ext.toUpperCase()){
          filtered[k] = m;
        }
      }
    }
  }
  return filtered;
}

function updateDeviceTree(devices, extenders, matches) {
  var tree = $("#device-tree", context)[0];

  if (!tree) {
    return;
  }
  var extens = processExtenders(extenders);
  var treeData = processDevicesForTree(devices,extens,filterMatches(extens, matches));
  tree.data = treeData;
  tree.invalidateData();
  flush_devices_cache();
}

function updateDeviceTable(devices, portStates, arlTable) {

  var binder = $("#table-binder", context)[0];

  var newDevicesTable = processDevicesForTable(devices, portStates, arlTable);

  if (!binder._attachedPending) {
    updatePolymerTableArray(binder, "devices", newDevicesTable, "deviceId");
  }

  binder.arlTableAvailable = typeof arlTable !== "undefined";
}

function updatePortsTable(portStates) {
  var binder = $("#table-binder", context)[0];
 
  var newPortsTable = processPortsForTable(portStates);
  
  if (!binder._attachedPending) {
    updatePolymerTableArray(binder, "ports", newPortsTable, "portNumber");
  }
}

var validMACRegex = /^[A-Fa-f0-9]{2}:[A-Fa-f0-9]{2}:[A-Fa-f0-9]{2}:[A-Fa-f0-9]{2}:[A-Fa-f0-9]{2}:[A-Fa-f0-9]{2}$/gm;
function isValidMAC(str){
  return str.match(validMACRegex);
}
var validDevName = /^.{1,35}$/g;
function isValidName(str){
  return str.match(validDevName);
}

var _importExportDeviceMap = {};
function updateImportExportMap(devices){
  _importExportDeviceMap = {};

  for(var devID in devices){
    var dev = devices[devID];
    if(dev.interfaces && dev.interfaces[0] && dev.interfaces[0].mac){
      _importExportDeviceMap[dev.interfaces[0].mac] = dev.id;
    }
  }
}

function bulkImportNames(content,dialogJElem,confirmJElem){
  var rows = content.split("\n");

  var error = "";
  var promises = [];

  for(var i = 0; i < rows.length; i++){
    var row = rows[i];
    if(!row) continue;
    var split = row.split(/\s+?/g);
    if(!split[1]){
      error += "<%= i18n.errorImport_no_name %> ".format(i);
      continue;
    };
    var mac = split.splice(0,1)[0];
    if(!isValidMAC(mac)){
      error += "<%= i18n.errorImport_invalid_mac %> ".format(i);
      continue;
    }
    var devID = _importExportDeviceMap[mac.toLowerCase()];
    if(!devID && devID !== 0){
      error += "<%= i18n.errorImport_no_dev %> ".format(mac);
      continue;
    }
    var name = split.join(" ");
    if(!isValidName(name)){
      error += "<%= i18n.errorImport_invalid_name %> ".format(i);
      continue;
    }
    promises.push(long_rpc_promise(deviceManagerPackageId,"set_device_name",[devID,name]));
  }
  Q.all(promises).then(function(){
    if(!error){
      dialogJElem[0].close();
    }
    confirmJElem.prop("disabled",false);
  });
  return error;
}

function bindImportExport(){
  var importButton = $("#import-names-button");
  var importDialog = $("#import-names-dialog");
  var importTextArea = importDialog.find("#import-textarea");
  var importConfirm = importDialog.find("#import-confirm");

  importButton.on('click',function(){
    importDialog[0].open();
    importTextArea.prop("value","");
    importTextArea[0].errorMessage = "";
    importTextArea[0].invalid = false;
  });

  importConfirm.on('click',function(){
    importConfirm.prop("disabled",true);
    var error = bulkImportNames(importTextArea.prop("value"),importDialog,importConfirm);
    importTextArea[0].errorMessage = error;
    importTextArea[0].invalid = !!error;
  });

  importTextArea.on('value-changed',function(){
    importDialog[0].notifyResize();
  });

  var exportButton = $("#export-names-button");
  exportButton[0].getText = function(){
    return exportContent;
  }
}

function startDeviceCycle(interval, callback) {
  
  $("#table-binder", context)[0].devices = [];
  $("#table-binder", context)[0].ports = [];

  start_cycle(function() {
    return [
      get_devices(),
      long_rpc_promise(deviceManagerPackageId, "get_arl_table", []),
      long_rpc_promise(deviceManagerPackageId, "get_switch_port_states", []),
      long_rpc_promise(deviceManagerPackageId, "get_extenders", []),
      long_rpc_promise(deviceManagerPackageId, "get_matches", []),
    ];
  }, function(devices, arlTable, portStates,extenders,matches) {
    
    arlTable = arlTable[0];
    portStates = JSON.parse(portStates[0]);

    updateDeviceTree(devices, extenders, matches);
    updateDeviceTable(devices, portStates, arlTable);
    updatePortsTable(portStates);
    updateImportExportMap(devices);
    
    callback();
  }, interval);
}

function bind_flush_cloud(){
  var flushCloudButton = $("#flush-cloud",context);
  flushCloudButton.on("click",function(){
    flushCloudButton.prop("disabled",true);
    long_rpc_promise(deviceManagerPackageId,"flush_cloud",[]).done(function(){
      flushCloudButton.prop("disabled",false);
    });
  });
}

function initialise() {

  bindOnDeviceClicks();
  setupViewModeToggle();

  bindOnDeviceUpdate();
  flush_devices_cache();

  bind_flush_cloud();

  bindImportExport();

  var executed = false;
  startDeviceCycle(1000 * 5, function () {
    if (!executed) {
      $(deviceTreePanel).prop("loaded", true);
      executed = true;
    }
  });
}

initialise();

})(this);

//# sourceURL=device-tree.js
