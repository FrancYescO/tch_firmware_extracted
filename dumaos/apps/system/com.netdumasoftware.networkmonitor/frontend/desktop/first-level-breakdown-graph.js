/*
 * (C) 2016 NETDUMA Software
 * Kian Cross
*/

(function (context) {

var legendElem = $("duma-legend",context);
var chartElem = $("#first-level-breakdown-graph",context);
chartElem[0].ariaValueFormatter = function(val){
  return format_bps(val * 1000 * 1000,1,1000);
}

var processor;
var nm;

var packageId = "com.netdumasoftware.networkmonitor";
var firstLevelBreakdownPanel = $("#first-level-breakdown-panel", context)[0];
var secondLevelBreakdownPanel = null;
var overviewPanel = $("#overview-graph-panel")[0];

function firstLevelBreakdownGraph(deviceId, download, marks) {
  var maximumVisibleConnections = nm.getMaximumVisibleConnections(); 

  var categories = {};

  var categoryTotals = {};
  function processor(newConnection, oldConnection, deviceMap) {

    var connectionClass = (newConnection.class & marks.mask) >> marks.shift;
    var service = $("duma-device-selector", context)[0].getServiceById(connectionClass);
    var category = service ? service.category : "null";

    var device = deviceMap[newConnection.sip4 || newConnection.sip6];
    if (device) {
      if (device.id == deviceId || deviceId === "<%= i18n.totalUsage %>") {
        var processedConnection = nm.processConnection(
          newConnection,
          oldConnection
        );

        if (!categoryTotals[category]) {
          categoryTotals[category] = 0;
        }

        if (download) {
          categoryTotals[category] += processedConnection.received;
        } else {
          categoryTotals[category] += processedConnection.transmitted;
        }
      }
    } else {
      throw "Device not found";
    }
  }

  function callback(duration) {
    for (var category in categoryTotals) {
      if (categoryTotals.hasOwnProperty(category)) {
        if (!categories[category]) {
          categories[category] = sampler_create(maximumVisibleConnections);
        }
        sampler_add(categories[category], categoryTotals[category]);
      }
    }
    categoryTotals = {};

    plot();
  }

  function plot() {
    var legend = [];
    var graph = {
      labels: [],
      meta: {
        map: [],
        download: download,
        deviceId: deviceId
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

    for (var category in categories) {
      if (categories.hasOwnProperty(category)) {
        var label = category === "null" ? "<%= i18n.unknown %>" : category;
        var colour = colourGenerator();
        graph.meta.map.push(category);
        graph.labels.push(label);
        
        graph.datasets[0].data.push(
          nm.convertToCorrectUnit(sampler_moving_average(
            categories[category]
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
    firstLevelBreakdownPanel.loaded = true;
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

function getFilePath(file) {
  return "/apps/" + packageId + "/desktop/" + file;
}

function initilisation() {
  var data = firstLevelBreakdownPanel.data;

  if (typeof nm != "function") {
    nm = networkMonitor();
  }

  Q.spread([
    nm.getCmarkMask(),
    $("duma-device-selector", context)[0].getServices()
  ], function (marks) {
    processor = firstLevelBreakdownGraph(
      data.deviceId,
      data.download,
      marks
    );
  }).done();

  get_devices().done(function (devices) {
    nm.setChartTitle(
      devices,
      data.deviceId,
      chartElem,
      data.download,
      ["<%= i18n.appCategory %>", "<%= i18n.bandwidthPerSecond %>"]
    );
  });

  legendElem[0].bindToChart(chartElem[0]);
}

// so it's just spaces to listen to multiple events, no commas :P
chartElem.on("chartClick labelClick", function (e) {
  if (
    secondLevelBreakdownPanel === true ||
    firstLevelBreakdownPanel.desktop === true
  ) {
    return;
  }

  var panels = $("duma-panels")[0];
  if (secondLevelBreakdownPanel) {
    panels.remove(secondLevelBreakdownPanel);
  }

  if ($("#second-level-breakdown-panel")[0]) {
    panels.remove($("#second-level-breakdown-panel")[0]);
  }

  secondLevelBreakdownPanel = true;

  panels.update(overviewPanel, { width: 8 });

  var graphMetaData = chartElem.prop("data").meta;

  panels.add(
    getFilePath("second-level-breakdown-graph.html"), packageId, {
      deviceId: graphMetaData.deviceId, download: graphMetaData.download,
      classificationId: graphMetaData.map[e.detail.index]
    }, {
      width: 4, height: 6, x: 8, y: 6,
      initialisationCallback: function (panel) {
        secondLevelBreakdownPanel = panel;

        $(panel).find("duma-panel").one("closeClick", function () {
          secondLevelBreakdownPanel = null;
          panels.update(overviewPanel, { width: 12 });
        });
      }
    }
  );
});


firstLevelBreakdownPanel.destructorCallback = function () {
  if (processor) {
    connectionProcessor.remove(processor);
  }
}

initilisation();

})(this);

//# sourceURL=first-level-breakdown-graph.js
