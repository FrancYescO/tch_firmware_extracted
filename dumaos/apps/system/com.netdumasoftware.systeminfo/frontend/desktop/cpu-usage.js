/*
 * (C) 2017 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
*/

(function (context) {

var cpuSamplers = {};
var prevCpuUsages;

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
      cpuSamplers[cpuUsage.name] = sampler_create(5);
    }

    sampler_add(
      cpuSamplers[cpuUsage.name],
      Math.round(((totald - idled) / totald) * 100 * 10) / 10
    );
  }

  var graphData = {
    labels: ["", "", "", "", ""],
    datasets: []
  };

  var colourGenerator = getColourGenerator();

  for (var id in cpuSamplers) {
    if (cpuSamplers.hasOwnProperty(id)) {
      var data = sampler_get(cpuSamplers[id]);
      if( data.length < 5 ){
        while( data.unshift(0) < 5);
      }

      graphData.datasets.push({
        data: data,
        label: id,
        borderColor: colourGenerator(),
        pointBackgroundColor: "<%= theme.PRIMARY_BACKGROUND_COLOR %>",
        pointBorderWidth: "3",
        lineTension: 0.1,
      });
    }
  }

  prevCpuUsages = cpuUsages;
  $("#cpu-usage-graph", context).prop("data", graphData);

  $("duma-panel", context).prop("loaded", true);
}

$("#cpu-usage-graph", context)[0].options = {  
  "animation": {
    "duration": 0
  },
  "scales": {
    "yAxes": [{
      "ticks": {
        "beginAtZero": true,
        "suggestedMax": 100
      },
      scaleLabel: {
        display: true,
        labelString: "Usage (%)"
      }   
    }],
    "xAxes": [{
      "display": false
    }]    
  }
};

var wait = start_cycle(function () {
  return [
    long_rpc_promise("com.netdumasoftware.systeminfo", "get_cpu_info", [])
  ];
}, function (cpu) {
  updateCpuUsage(cpu[0]);
}, 1000 * 2);

})(this);

//@ sourceURL=cpu-usage.js
