/*
 * (C) 2017 NETDUMA Software
 * Luke Meppem <luke.meppem@netduma.com>
*/

(function (context) {

var packageId = "com.netdumasoftware.qos";
var colours = [];

function initChart(){
  var cgen = getColourGenerator();
  colours = [cgen(),cgen(),cgen(),cgen()];
  $("duma-chart[type=doughnut]",context).prop("options", {
    elements: {
      arc: {
        borderWidth: 0
      }
    },
    legend: {
      display: false
    },
  });

  $("duma-legend",context).on("legendItemSelect", function (event)
  {
    var chart = $("duma-chart[type=doughnut]",context)[0].chart;
    var key = Object.keys(chart.data.datasets[0]._meta)[0];
    var curr = chart.data.datasets[0]._meta[key].data[event.detail];
    curr.hidden = !curr.hidden;
    chart.update();
  }.bind(this));
}

function updateChart(values){
  var data_amounts = [];
  var legend = [];
  var labels = [];
  for(var i = 0; i < values.length; i++){
    var v = values[i];
    data_amounts.push(v[0]);
    labels.push(v[1]);
    legend.push({
      label: v[1],
      result: v[0],
      colour: colours[i],
      bgColour: colours[i],
      visible: true
    })
  }

  var data = {
    datasets: [{
      backgroundColor: colours,
      data: data_amounts
    }],
    labels: labels
  }
  $("duma-chart[type=doughnut]",context).prop("data", data);
  $("duma-legend",context).prop("legendStats", legend);
}

function onInit() {
  initChart();
  start_cycle(function () {
    return [
      long_rpc_promise(packageId, "background_stats", [])
    ];
  }, function ( stats ) {
    stats = stats[0] || {
      background:{rx_packets:0,tx_packets:0},
      hyperlane:{rx_packets:0,tx_packets:0}
    }
    updateChart([
      [stats.hyperlane.rx_packets, "<%= i18n.priorDownload %>"],
      [stats.hyperlane.tx_packets, "<%= i18n.priorUpload %>"],
      [stats.background.rx_packets, "<%= i18n.backDownload %>"],
      [stats.background.tx_packets, "<%= i18n.backUpload %>"],
    ]);

    $("duma-panel", context).prop("loaded", true);
  }, 1000);
}

onInit();

})(this);
