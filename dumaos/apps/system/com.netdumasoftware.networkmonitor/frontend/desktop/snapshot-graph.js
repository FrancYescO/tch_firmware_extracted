/*
 * (C) 2016 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
*/

(function (context) {

var nm;
var packageId = "com.netdumasoftware.networkmonitor";
var snapshotPanel = $("#snapshot-graph-panel", context)[0];

function snapshotGraph() {
  var maximumVisibleConnections = nm.getMaximumVisibleConnections();
  
  var devices = {};

  var deviceTotals = {};
  function processor(newConnection, oldConnection, deviceMap) {
    var device = deviceMap[newConnection.sip4 || newConnection.sip6];

    /* ignore the null device */
    if( device.id == 0 )
      return;

    if (device) {
      if (!deviceTotals[device.id]) {
        deviceTotals[device.id] = {
          transmitted: 0,
          received: 0,
          device: device
        };
      }
      
      var processedConnection = nm.processConnection(
        newConnection,
        oldConnection
      );

      deviceTotals[device.id].transmitted += processedConnection.transmitted;
      deviceTotals[device.id].received += processedConnection.received;
    } else {
      throw "Device not found.";
    }
  }

  function callback(duration) {
    for (var id in deviceTotals) {
      if (deviceTotals.hasOwnProperty(id)) {
        if (!devices[id]) {
          devices[id] = {
            transmitted: sampler_create(nm.getMaximumVisibleConnections()),
            received: sampler_create(nm.getMaximumVisibleConnections())
          };
        }

        devices[id].device = deviceTotals[id].device;

        sampler_add(
          devices[id].transmitted,
          deviceTotals[id].transmitted / (duration / 1000)
        );
        
        sampler_add(
          devices[id].received,
          deviceTotals[id].received / (duration / 1000)
        );
      }
    }
    deviceTotals = {};

    plot(devices);
  }

  function plot(devices) {
    var graph = {
      labels: ["<%= i18n.totalUsage %>"],
      meta: {
        map: ["Total Usage"]
      },
      datasets: [
        {
          label: "<%= i18n.download %>",
          data: [0],
			    backgroundColor: "<%= theme.PRIMARY_COLOR %>",
		      borderWidth: 0,
        }, {
          label: "<%= i18n.upload %>",
          data: [0],
		      backgroundColor: "<%= theme.ACCENT_COLOR %>",
		      borderWidth: 0, 
        }
      ]
    };

    devices = Object.values(devices);
    devices.sort(function (a, b) {
      var aTotal = sampler_moving_average(a.received) +
                   sampler_moving_average(a.transmitted);

      var bTotal = sampler_moving_average(b.received) +
                   sampler_moving_average(b.transmitted);

      if (aTotal < bTotal) {
        return 1;

      } else if (aTotal > bTotal) {
        return -1;
      }

      return 0;
    });

    for (var i = 0; i < devices.length; i++) {

      var id = devices[i].device.id;

      if (sampler_get(devices[i].received).length > 0) {

        if (i < 5) {

          graph.meta.map.push(id);
          var p = graph.labels.push(devices[i].device.name) - 1;
          graph.datasets[0].data.push(0);
          graph.datasets[1].data.push(0);
    
          graph.datasets[0].data[p] += nm.convertToCorrectUnit(
            sampler_moving_average(devices[i].received)
          );

          graph.datasets[1].data[p] += nm.convertToCorrectUnit(
            sampler_moving_average(devices[i].transmitted)
          );
        }

        graph.datasets[0].data[0] += nm.convertToCorrectUnit(
          sampler_moving_average(devices[i].received)
        );

        graph.datasets[1].data[0] += nm.convertToCorrectUnit(
          sampler_moving_average(devices[i].transmitted)
        );

      }
    }

    $("#snapshot-graph").prop("data", nm.roundGraph(graph, 1));
    snapshotPanel.loaded = true;
  }
  
  connectionProcessor.add(processor, callback);
}

function getFilePath(file) {
  return "/apps/" + packageId + "/desktop/" + file;
}

if (typeof nm != "function") {
  nm = networkMonitor();
}

$("#snapshot-graph", context).prop("options", {
  scales: {
    xAxes: [{
      ticks: {
        beginAtZero: true
      },
      scaleLabel: {
        display: true,
        labelString: "<%= i18n.xAxisLabel %>"
      }
    }]
  }
});

var firstLevelBreakdownPanel = null;

$("#snapshot-graph", context).on("chartClick", function (e) {
  if (
    firstLevelBreakdownPanel === true ||
    snapshotPanel.desktop === true
  ) {
    return;
  }

  var panels = $("duma-panels")[0];

  if (firstLevelBreakdownPanel) {
    panels.remove(firstLevelBreakdownPanel);
  }

  firstLevelBreakdownPanel = true;

  panels.update(snapshotPanel, { width: 8 });

  panels.add(
    getFilePath("first-level-breakdown-graph.html"), packageId, {
      deviceId: $("#snapshot-graph").prop("data").meta.map[e.detail.index],
      download: e.detail.datasetIndex === 0
    }, {
      width: 4, height: 6, x: 8, y: 0,
      initialisationCallback: function (panel) {
        firstLevelBreakdownPanel = panel;

        $(panel).find("duma-panel").one("closeClick", function () {
          firstLevelBreakdownPanel = null;
          panels.update(snapshotPanel, { width: 12 });
        });
      }
    }
  );
});

snapshotGraph();

})(this);

//# sourceURL=snapshot-graph.js
