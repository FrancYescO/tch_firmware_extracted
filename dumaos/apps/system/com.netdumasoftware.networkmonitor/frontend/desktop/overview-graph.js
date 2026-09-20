/*
 * (C) 2016 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
*/

(function (context) {

var nm;

function overviewGraph () {
  var maximumVisibleConnections = nm.getMaximumVisibleConnections();
  
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
    
    $("#overview-graph", context).prop("data", {
      labels: new Array(maximumVisibleConnections).fill(""),
      datasets: [
        {
          label: "<%= i18n.download %>",
          data: nm.roundArray(received, 1),
          pointBackgroundColor: "<%= theme.PRIMARY_BACKGROUND_COLOR %>",
          pointBorderWidth: "3",
          lineTension: 0.1,
		      borderColor: "<%= theme.PRIMARY_COLOR %>"
        }, {
          label: "<%= i18n.upload %>",
          data: nm.roundArray(transmitted, 1),
          pointBackgroundColor: "<%= theme.PRIMARY_BACKGROUND_COLOR %>",
          pointBorderWidth: "3",
          lineTension: 0.1,
		      borderColor: "<%= theme.ACCENT_COLOR %>"
        }
      ]
    });

    $("duma-panel", context).prop("loaded", true);
  }

  connectionProcessor.add(processor, callback);
}

if (typeof nm != "function") {
  nm = networkMonitor();
}

$("#overview-graph", context).prop("options", {
  animation: {
    duration: 0
  },
  scales: {
    yAxes: [{
      ticks: {
        beginAtZero: true
      },
      scaleLabel: {
        display: true,
        labelString: "<%= i18n.yAxisLabel %>"
      }
    }],
    "xAxes": [{
      "display": false
    }]
  }
});

overviewGraph();

})(this);

//# sourceURL=overview-graph.js
