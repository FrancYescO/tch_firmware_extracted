/*
 * (C) 2016 NETDUMA Software
 * Kian Cross
*/

(function (context) {

var legendElem = $("duma-legend",context);
var chartElem = $("#second-level-breakdown-graph",context);
chartElem[0].ariaValueFormatter = function(val){
  return format_bps(val * 1000 * 1000,1,1000);
}

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
    var legend = [];
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
        var label = applicaton === "null" ? "<%= i18n.unknown %>" : applicaton;
        var colour = colourGenerator();

        graph.meta.map.push(applicaton);
        graph.labels.push(label);

        graph.datasets[0].data.push(
          nm.convertToCorrectUnit(sampler_moving_average(
            applications[applicaton]
          ))
        );
        
        graph.datasets[0].backgroundColor.push(colour);
        legend.push({
          label: label,
          result: 0,
          colour: colour,
          bgColour: colour,
          visible: true
        });
      }
    }

    chartElem.prop("data", nm.roundGraph(graph, 1));
    legendElem.prop("legendStats", legend);
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
      chartElem,
      data.download,
      ["<%= i18n.app %>", "<%= i18n.bandwidthPerSecond %>"]
    );
  });

  legendElem[0].bindToChart(chartElem[0]);
}

secondLevelBreakdownPanel.destructorCallback = function () {
  if (processor) {
    connectionProcessor.remove(processor);
  }
};

initialise();

})(this);

//# sourceURL=second-level-breakdown.js
