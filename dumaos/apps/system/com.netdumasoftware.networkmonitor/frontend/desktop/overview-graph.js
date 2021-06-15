/*
 * (C) 2016 NETDUMA Software
 * Kian Cross
*/

(function (context) {

var legendElem = $("duma-legend",context);
var chartElem = $("#overview-graph",context);
chartElem[0].ariaValueFormatter = function(val){
  return format_bps(val * 1000 * 1000,1,1000);
}

var nm;

function overviewGraph () {
  // the rest of network monitor works off a basis of a 10-second timespan (nm.getMaximumVisibleConnections()).
  // However, the line-overview graph can handle more, and it would be more useful if it did
  // So it's increased to 60 seconds for better use
  var maximumVisibleConnections = 60;
  
  var totals = {
    transmitted: sampler_create(maximumVisibleConnections),
    received: sampler_create(maximumVisibleConnections)
  };

  var transmitted = 0;
  var received = 0;

  function processor(newConnection, oldConnection, deviceMap) {
    var processedConnection = nm.processConnection(newConnection, oldConnection);
    transmitted += processedConnection.transmitted;
    received += processedConnection.received;
  }

  function callback(duration) {
    sampler_add(totals.transmitted, transmitted / (duration / 1000));
    sampler_add(totals.received, received / (duration / 1000));
    transmitted = 0;
    received = 0;
    plot(sampler_get(totals.transmitted), sampler_get(totals.received));
  }

  function plot(transmitted, received) {
    if (transmitted.length != received.length) throw Error();

    for (var i = 0; i < transmitted.length; i++) {
      transmitted[i] = nm.convertToCorrectUnit(transmitted[i]);
      received[i] = nm.convertToCorrectUnit(received[i]);
    }

    while (transmitted.length < maximumVisibleConnections) {
      transmitted.unshift(0);
      received.unshift(0);
    }
    var legend = [
      {
        label: "<%= i18n.download %>",
        result: 0,
        colour: "<%= theme.PRIMARY_COLOR %>",
        colour: "<%= theme.PRIMARY_COLOR %>",
        visible: true
      },{
        label: "<%= i18n.upload %>",
        result: 0,
        colour: "<%= theme.ACCENT_COLOR %>",
        visible: true
      }
    ];
    
    chartElem.prop("data", {
      labels: new Array(maximumVisibleConnections).fill(""),
      datasets: [
        {
          label: "<%= i18n.download %>",
          data: nm.roundArray(received, 1),
          pointBackgroundColor: "<%= theme.PRIMARY_COLOR %>",
          pointBorderWidth: "3",
          lineTension: 0.1,
		      borderColor: "<%= theme.PRIMARY_COLOR %>"
        }, {
          label: "<%= i18n.upload %>",
          data: nm.roundArray(transmitted, 1),
          pointBackgroundColor: "<%= theme.ACCENT_COLOR %>",
          pointBorderWidth: "3",
          lineTension: 0.1,
		      borderColor: "<%= theme.ACCENT_COLOR %>"
        }
      ]
    });
    legendElem.prop("legendStats", legend);

    $("duma-panel", context).prop("loaded", true);
  }

  connectionProcessor.add(processor, callback);
}

if (typeof nm != "function") {
  nm = networkMonitor();
}

chartElem.prop("options", {
  animation: {
    duration: 0
  },
  scales: {
    yAxes: [{
      ticks: {
        beginAtZero: true,
        suggestedMax: 0.1
      },
      scaleLabel: {
        display: true,
        labelString: "<%= i18n.bandwidthPerSecond %>"
      }
    }],
    xAxes: [{
      display: false,
      scaleLabel: {
        display: false,
        // remains here for accessibility mode
        labelString: "<%= i18n.downloadUpload %>"
      }
    }]
  },
  elements: {
    point: {
      radius: 0,
      hitRadius: 5,
      hoverRadius: 5
    }
  },
  legend: {
    display: false
  },
  tooltips: {
    callbacks: {
      label: function(tx, ctx){
        return ctx.datasets[tx.datasetIndex].label + ": " + format_bps(ctx.datasets[tx.datasetIndex].data[tx.index] * 1000 * 1000,1,1000);
      }
    }
  },
});

overviewGraph();

legendElem[0].bindToChart(chartElem[0]);
})(this);

//# sourceURL=overview-graph.js
