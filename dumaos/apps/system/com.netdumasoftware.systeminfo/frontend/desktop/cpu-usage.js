/*
 * (C) 2017 NETDUMA Software
 * Kian Cross
*/

(function (context) {

var legendElem = $("duma-legend",context);
var chartElem = $("#cpu-usage-graph",context);

var cpuSamplers = {};
var prevCpuUsages;
var dataPointAmount = 20;

function updateCpuUsage(cpuUsages) {
  if (!prevCpuUsages) {
    prevCpuUsages = cpuUsages;
    return;
  }

  for (var i = 0; i < cpuUsages.length; i++) {
    var prevCpuUsage = prevCpuUsages[i];
    var cpuUsage = cpuUsages[i];

    cpuUsage.name = cpuUsage.name.toUpperCase();
    
    prevIdle = prevCpuUsage.idle + prevCpuUsage.iowait;
    idle = cpuUsage.idle + cpuUsage.iowait;

    prevNonIdle = prevCpuUsage.user + prevCpuUsage.nice +
      prevCpuUsage.system + prevCpuUsage.irq + 
      prevCpuUsage.softirq + prevCpuUsage.steal;

    nonIdle = cpuUsage.user + cpuUsage.nice + cpuUsage.system +
      cpuUsage.irq + cpuUsage.softirq + cpuUsage.steal;

    prevTotal = prevIdle + prevNonIdle;
    total = idle + nonIdle

    totald = total - prevTotal
    idled = idle - prevIdle

    if (!cpuSamplers[cpuUsage.name]) {
      cpuSamplers[cpuUsage.name] = sampler_create(dataPointAmount);
    }

    sampler_add(
      cpuSamplers[cpuUsage.name],
      Math.round(((totald - idled) / totald) * 100 * 10) / 10
    );
  }

  var graphData = {
    labels: new Array(dataPointAmount).fill(""),
    datasets: []
  };
  var legend = [];

  var colourGenerator = getColourGenerator();

  for (var id in cpuSamplers) {
    if (cpuSamplers.hasOwnProperty(id)) {
      var data = sampler_get(cpuSamplers[id]);
      if( data.length < dataPointAmount ){
        while( data.unshift(0) < dataPointAmount);
      }

      var colour = colourGenerator();
      graphData.datasets.push({
        data: data,
        label: id,
        borderColor: colour,
        pointBackgroundColor: "<%= theme.PRIMARY_BACKGROUND_COLOR %>",
        pointBorderWidth: "3",
        lineTension: 0.1,
      });
      legend.push({
        label: id,
        result: data[data.length-1],
        colour: colour,
        visible: true
      });
    }
  }

  prevCpuUsages = cpuUsages;
  chartElem.prop("data", graphData);
  legendElem.prop("legendStats", legend);

  $("duma-panel", context).prop("loaded", true);
}

chartElem[0].ariaValueFormatter = function(val){
  return "<%= i18n.valueFormat %>".format(val);
};
chartElem.prop("options", {  
  animation: {
    duration: 0
  },
  tooltips: {
    callbacks: {
      label: function(tx, ctx){
        return "<%= i18n.valueFormat %>".format(ctx.datasets[tx.datasetIndex].data[tx.index]);
      }
    }
  },
  scales: {
    yAxes: [{
      ticks: {
        beginAtZero: true,
        suggestedMax: 100,
        stepSize: 20
      },
      scaleLabel: {
        display: true,
        labelString: "<%= i18n.cpuUsage %>"
      }   
    }],
    xAxes: [{
      display: false,
      scaleLabel: {
        display: false,
        labelString: "<%= i18n.cpuCore %>"
      }   
    }]
  },
  elements: {
    point: {
      radius: 0,
      hitRadius: 5,
    }
  },
  legend: {
    display: false
  },
});

var wait = start_cycle(function () {
  return [
    long_rpc_promise("com.netdumasoftware.systeminfo", "get_cpu_info", [])
  ];
}, function (cpu) {
  updateCpuUsage(cpu[0]);
}, 1000 * 2);

legendElem[0].bindToChart(chartElem[0]);
})(this);

//@ sourceURL=cpu-usage.js
