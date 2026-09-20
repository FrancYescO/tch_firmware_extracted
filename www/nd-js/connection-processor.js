/*
 * (C) 2016 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
*/

var connectionProcessor = connectionProcessor || (function () {
  var networkMonitorPackageId = "com.netdumasoftware.networkmonitor";
  var ctwatchPackageId = "com.netdumasoftware.ctwatch";
  var interval = 1000;
  
  var processors = [];
  var previousConnections;
  var lastTimestamp;

  var started = false;

  function findConnection(connection, connections) {
    for (var i = 0; i < connections.length; i++) {
      if (connection.l4proto != connections[i].l4proto) continue;
      if (connection.l3proto != connections[i].l3proto) continue;
      if (connection.l3proto == 2 ){
      	if (connection.dip4 != connections[i].dip4) continue;
      	if (connection.sip4 != connections[i].sip4) continue;
      }
      if( connection.l3proto == 10 ){
        if (connection.dip6 != connections[i].dip6) continue;
        if (connection.sip6 != connections[i].sip6) continue;
      }
      if (connection.sport != connections[i].sport) continue;
      if (connection.dport != connections[i].dport) continue;

      return connections[i];
    }
  }
  
  function initiateConnectionProcessors(newConnections, previousConnections, deviceMap, processors, interval) {
    for (var i = 0; i < newConnections.length; i++) {
      var newConnection = newConnections[i];
      var oldConnection = findConnection(newConnection, previousConnections);
      
      for (var b = 0; b < processors.length; b++) {
        var processor = processors[b].processor;
        processor(newConnection, oldConnection, deviceMap);
      }
    }

    for (var i = 0; i < processors.length; i++) {
      var callback = processors[i].callback;
      callback(interval);
    }
  }

  function mapConnectionIpsToIds(connections) {
    var ips = [];
    for (var i = 0; i < connections.length; i++) {
      var ip = connections[i].sip4 || connections[i].sip6;
      
      if (ips.indexOf(ip) == -1) {
        ips.push(ip);
      }
    }
   
    return Q.spread([map_ips(ips), get_devices()], function (ids, devices) {
      var map = {};
      for (var i = 0; i < ips.length; i++) {
        map[ips[i]] = devices[ids[i]];
      }
      return map;
    });
  }

  function processConnectionSets(connectionSets, processor, callback) {
    var processorRecord = {
      processor: processor,
      callback: callback
    };

    for (var i = 1; i < connectionSets.length; i++) {
      initiateConnectionProcessors(
        connectionSets[i].connections,
        connectionSets[i - 1].connections,
        connectionSets[i].devices,
        [processorRecord],
        connectionSets[i].interval
      )
    }
  }

  function add(processor, callback) {
    var record = {
      processor: processor,
      callback: callback
    }
    processors.push(record);
    return record;
  }

  function remove(record) {
    var p = processors.indexOf(record);
    if (p > -1) {
      processors.splice(p, 1);
      return true;
    } else {
      return false;
    }
  }

  function start() {
    if (started) {
      console.log("Connection processor already started.");
      return;
    }

    started = true;

    start_cycle(function () {
      return [long_rpc_promise(ctwatchPackageId, "filter_connections", [{}])];
    }, function (snapshot) {
      snapshot = snapshot[0];
      /*
      * Some browsers (chrome) reduce script execution speed when a tab is inactive. Meaning that
      * using browser timestamps could be wildly inaccurate giving incorrect results. Simple solution
      * use timestamps from the router which will be consistent -@NETDUMA_Iain
      */
      var connections = snapshot.connections;
      var now = snapshot.timestamp;
      return mapConnectionIpsToIds(connections).then(function (deviceMap) {
        if (previousConnections) {
          var delta = now - lastTimestamp;

          initiateConnectionProcessors(
            connections,
            previousConnections,
            deviceMap,
            processors,
            delta
          );
        }
        previousConnections = connections;
        lastTimestamp = now;
      });
    }, 1000);
  }

  return {
    add: add,
    remove: remove,
    processConnectionSets: processConnectionSets,
    start: start
  };
})();
