var timerajax;
var config = {
  type: "line",
  data: {
    labels: [],
    datasets: [{
      label: "ALL Cores",
      backgroundColor: "#000000",
      borderColor: "#000000",
      data: "",
      fill: false
    },
    {
      label: "Router Core 1",
      backgroundColor: "#00FF00",
      borderColor: "#00FF00",
      data: "",
      fill: false
    },
    {
     label: "Router Core 2",
      backgroundColor: "#0000FF",
      borderColor: "#0000FF",
      data: "",
      fill: false
    }]
  },
  options: {
    responsive: true,
    legend: {
      position: "right"
    },
    title: {
      display: true,
      text: "CPU"
    },
    tooltips: {
      mode: "index",
      intersect: false
    },
    hover: {
      mode: "nearest",
      intersect: true
    },
    scales: {
      xAxes: [{
        display: true,
        scaleLabel: {
          display: true,
 labelString: "Time (seconds)"
        }
      }],
      yAxes: [{
        display: true,
        scaleLabel: {
          display: true,
          labelString: "CPU Load (%)"
        },
        ticks: {
          max: 100,
          min: 0,
          stepSize: 10
        }
      }]
    }
  }
};

for (count = 0; count < 30; count++) {
  config.data.labels.push(((count)).toString());
}

var dataCreation = true
function getInfo() {
  if (($(".chartjs-render-monitor").length != 0) && ($("#GraphChoice").val() == "System")) {
    var url = "/modals/diagnostics-graphs-modal.lp";
    var checktimer = "3000";
    var gets = {}
    gets.ajaxreq = "1";
    gets.graph = "System";
    $.getJSON(url, gets).done(function(data) {
      var dataLength = Object.getOwnPropertyNames(data).length;
      if (dataLength > 3 && dataCreation) {
        config.data.datasets.push({label: "Accelerator Core", backgroundColor: "#FF0000", borderColor: "#FF0000", data: "", fill: false });
        dataCreation = false
      }
      if (data) {
        if(data[1]) {
          var cpu = data[1];
          var label = cpu.substring(0,cpu.indexOf(' '));
          regexp_sys = /(\d+.\d+)\%\s+sys/i;
          regexp_nic = /(\d+.\d+)\%\s+nic/i;
          regexp_usr = /(\d+.\d+)\%\s+usr/i;
          regexp_idle = /(\d+.\d+)\%\s+idle/i;
          var sys = regexp_sys.exec(cpu);
          var nic = regexp_nic.exec(cpu);
          var usr = regexp_usr.exec(cpu);
          var idle = regexp_idle.exec(cpu);
          if (idle !== null) {
            var used = 100 - idle[1];
            config.data.datasets[0].data.unshift(used);
            if (config.data.datasets[0].data.length > 30) config.data.datasets[0].data.pop();
            config.options.scales.yAxes[0].ticks.max = 100;
            window.myLine.update();
          }
        }
        if(data[2]) {
          var cpu = data[2];
          regexp_sys = /(\d+.\d+)\%\s+sys/i;
          regexp_nic = /(\d+.\d+)\%\s+nic/i;
          regexp_usr = /(\d+.\d+)\%\s+usr/i;
          regexp_idle = /(\d+.\d+)\%\s+idle/i;
          var sys = regexp_sys.exec(cpu);
          var nic = regexp_nic.exec(cpu);
          var usr = regexp_usr.exec(cpu);
          var idle = regexp_idle.exec(cpu);
          if (idle !== null) {
            var used = 100 - idle[1];
            config.data.datasets[1].data.unshift(used);
            if (config.data.datasets[1].data.length > 30) config.data.datasets[1].data.pop();
            config.options.scales.yAxes[0].ticks.max = 100;
            window.myLine.update();
          }
        }
        if(data[3]) {
          var cpu = data[3];
          regexp_sys = /(\d+.\d+)\%\s+sys/i;
          regexp_nic = /(\d+.\d+)\%\s+nic/i;
          regexp_usr = /(\d+.\d+)\%\s+usr/i;
          regexp_idle = /(\d+.\d+)\%\s+idle/i;
          var sys = regexp_sys.exec(cpu);
          var nic = regexp_nic.exec(cpu);
          var usr = regexp_usr.exec(cpu);
          var idle = regexp_idle.exec(cpu);
          if (idle !== null) {
            var used = 100 - idle[1];
            config.data.datasets[2].data.unshift(used);
            if (config.data.datasets[2].data.length > 30) config.data.datasets[2].data.pop();
            config.options.scales.yAxes[0].ticks.max = 100;
            window.myLine.update();
          }
        }
        if(data[4]) {
          var cpu = data[4];
          regexp_sys = /(\d+.\d+)\%\s+sys/i;
          regexp_nic = /(\d+.\d+)\%\s+nic/i;
          regexp_usr = /(\d+.\d+)\%\s+usr/i;
          regexp_idle = /(\d+.\d+)\%\s+idle/i;
          var sys = regexp_sys.exec(cpu);
          var nic = regexp_nic.exec(cpu);
          var usr = regexp_usr.exec(cpu);
          var idle = regexp_idle.exec(cpu);
          if (usr !== null && sys !== null && nic !== null && idle !== null) {
            var used = 100 - idle[1];
            config.data.datasets[3].data.unshift(used);
            if (config.data.datasets[3].data.length > 30) config.data.datasets[3].data.pop();
            config.options.scales.yAxes[0].ticks.max = 100;
            window.myLine.update();
          }
        }
      }
}).error(function() {});

    clearTimeout(timerajax);
    timerajax = window.setTimeout(function() {
      getInfo();
    }, checktimer);
  } else {
    clearTimeout(timerajax);
  }
}

$(document).ready(function() {
  var ctx = document.getElementById("canvas").getContext("2d");
  window.myLine = new Chart(ctx, config);
  getInfo();
});
