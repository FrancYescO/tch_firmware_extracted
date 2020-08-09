/*
 * (C) 2016 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
*/

(function (context) {

var processor;
var nm;

var secondLevelBreakdownPanel = $("#second-level-breakdown-panel", context)[0];

function secondLevelBreakdownGraph(deviceId, download, marks, category) {
  var maximumVisibleConnections = nm.getMaximumVisibleConnections(); 

  var applications = {};
  var applicationTotals = {};

  function processor(newConnection, oldConnection, deviceMap) {
    
    var connectionClass = (newConnection.class & marks.mask) >> marks.shift;
    var service = $("duma-device-selector", context)[0].getServiceById(connectionClass);
    var connectionCategory = service ? service.category : "null";
    var connectionApplication = service ? service.application : "null";

    var device = deviceMap[newConnection.sip4 || newConnection.sip6];

    if (device) {
      
      if (
        (device.id == deviceId || deviceId === "<%= i18n.totalUsage %>") &&
        category === connectionCategory
      ) {

        var processedConnection = nm.processConnection(
          newConnection,
          oldConnection
        );

        if (!applicationTotals[connectionApplication]) {
          applicationTotals[connectionApplication] = 0;
        }

        if (download) {
          applicationTotals[connectionApplication] += processedConnection.received;
        } else {
          applicationTotals[connectionApplication] += processedConnection.transmitted;
        }
      }
    } else {
      throw "Device not found";
    }
  }

  function callback(duration) {
    for (var application in applicationTotals) {
      if (applicationTotals.hasOwnProperty(application)) {
        if (!applications[application]) {
          applications[application] = sampler_create(maximumVisibleConnections);
        }
        sampler_add(applications[application], applicationTotals[application]);
      }
    }
    applicationTotals = {};

    plot();
  }

  function plot() {
    var graph = {
      labels: [],
      meta: {
        map: [],
        download: download
      },
      datasets: [
        {
          data: [],
		      backgroundColor: [],
		      borderWidth: 0
        }
      ]
    };
    
    var colourGenerator = getColourGenerator();

    for (var applicaton in applications) {
      if (applications.hasOwnProperty(applicaton)) {

        graph.meta.map.push(applicaton);
        graph.labels.push(applicaton === "null" ? "<%= i18n.unknown %>" : applicaton);

        graph.datasets[0].data.push(
          nm.convertToCorrectUnit(sampler_moving_average(
            applications[applicaton]
          ))
        );
        
        graph.datasets[0].backgroundColor.push(colourGenerator());
      }
    }

    $("#second-level-breakdown-graph", context).prop("data", nm.roundGraph(graph, 1));
    secondLevelBreakdownPanel.loaded = true;
  }
  
  function getMissingConnections() {
    connectionProcessor.processConnectionSets(
      nm.getConnectionHistory(),
      processor,
      callback
    );
  }
  
  var p = connectionProcessor.add(processor, callback);
  getMissingConnections();
  return p;
}

function panelClose() {
  if (processor) {
    connectionProcessor.remove(processor);
  }
}

function initialise() {
  nm = networkMonitor();

  var data = secondLevelBreakdownPanel.data;

  Q.spread([
    nm.getCmarkMask(),
    $("duma-device-selector", context)[0].getServices()
  ], function (marks) {
    processor = secondLevelBreakdownGraph(
      data.deviceId,
      data.download,
      marks,
      data.classificationId
    );
  }).done();
  
  get_devices().done(function (devices) {
    nm.setChartTitle(
      devices,
      data.deviceId,
      $("#second-level-breakdown-graph", context),
      data.download
    );
  });
}

secondLevelBreakdownPanel.destructorCallback = function () {
  if (processor) {
    connectionProcessor.remove(processor);
  }
};

initialise();

})(this);

//# sourceURL=second-level-breakdown.js
