--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local proxy = require("datamodel")
local args = ngx.req.get_uri_args()

local html = {}
--AJAX Part
local function AJAX()
  local values = proxy.get("sys.graph.cpu", "sys.graph.mem")
  html[#html+1] = "{"
  for k, v in pairs(values) do
    html[#html+1]=string.format("\"%s\":\"%s\"", k, v.value)
    html[#html+1] = ","
  end
  html[#html] = "}"
  ngx.print(html)
end

if args.ajaxreq == "1" then
  AJAX()
  ngx.exit(ngx.HTTP_OK)
end
--AJAX End

html = {}
html[#html + 1] = [[<fieldset>]]
html[#html + 1] = [[<div style="width:900px;">]]
html[#html + 1] = [[<canvas id="canvas"></canvas>]]
html[#html + 1] = [[</div>]]
html[#html + 1] = [[</fieldset>]]
ngx.print(html)
  ngx.print('\
\
<script>\
var timerajax;\
var config = {\
  type: "line",\
  data: {\
    labels: [],\
    datasets: [{\
      label: "CPU Total",\
      backgroundColor: "#FF0000",\
      borderColor: "#FF5000",\
      data: "",\
      fill: false\
    },\
    {\
      label: "usr",\
      backgroundColor: "#00FF00",\
      borderColor: "#05FF00",\
      data: "",\
      fill: false\
    },\
    {\
      label: "sys",\
      backgroundColor: "#0000FF",\
      borderColor: "#0005FF",\
      data: "",\
      fill: false\
    },\
    {\
      label: "nic",\
      backgroundColor: "#FF00FF",\
      borderColor: "#FF50FF",\
      data: "",\
      fill: false\
    }]\
  },\
  options: {\
    responsive: true,\
    legend: {\
      position: "right"\
    },\
    title: {\
      display: true,\
      text: "CPU"\
    },\
    tooltips: {\
      mode: "index",\
      intersect: false\
    },\
    hover: {\
      mode: "nearest",\
      intersect: true\
    },\
    scales: {\
      xAxes: [{\
        display: true,\
        scaleLabel: {\
          display: true,\
          labelString: "Time (seconds)"\
        }\
      }],\
      yAxes: [{\
        display: true,\
        scaleLabel: {\
          display: true,\
          labelString: "CPU Load (%)"\
        },\
        ticks: {\
          max: 100,\
          min: 0,\
          stepSize: 10\
        }\
      }]\
    }\
  }\
};\
\
for (count = 0; count < 30; count++) {\
  config.data.labels.push(((count)).toString());\
}\
\
function getInfo() {\
  if (($(".chartjs-render-monitor").length != 0) && ($("#GraphChoice").val() == "System")) {\
    var url = "/modals/diagnostics-graphs-modal.lp";\
    var checktimer = "1000";\
    var gets = {}\
    gets.ajaxreq = "1";\
    gets.graph = "System";\
    $.getJSON(url, gets).done(function(data) {\
      if (data) {\
        var cpu = data[1];\
        regexp_idle = /(\\d+)\\%\\s+idle/i;\
        regexp_sys = /(\\d+)\\%\\s+sys/i;\
        regexp_nic = /(\\d+)\\%\\s+nic/i;\
        regexp_usr = /(\\d+)\\%\\s+usr/i;\
        var idle = regexp_idle.exec(cpu);\
        var sys = regexp_sys.exec(cpu);\
        var nic = regexp_nic.exec(cpu);\
        var usr = regexp_usr.exec(cpu);\
        if (usr !== null && sys !== null && nic !== null) {\
          config.data.datasets[0].data.unshift(parseInt(usr[1]) + parseInt(sys[1]) + parseInt(nic[1]));\
          if (config.data.datasets[0].data.length > 30) config.data.datasets[0].data.pop();\
          config.data.datasets[1].data.unshift(usr[1]);\
          if (config.data.datasets[1].data.length > 30) config.data.datasets[1].data.pop();\
          config.data.datasets[2].data.unshift(sys[1]);\
          if (config.data.datasets[2].data.length > 30) config.data.datasets[2].data.pop();\
          config.data.datasets[3].data.unshift(nic[1]);\
          if (config.data.datasets[3].data.length > 30) config.data.datasets[3].data.pop();\
          config.options.scales.yAxes[0].ticks.max = 100;\
          window.myLine.update();\
        }\
      }\
    }).error(function() {});\
\
    clearTimeout(timerajax);\
    timerajax = window.setTimeout(function() {\
      getInfo();\
    }, checktimer);\
  } else {\
    clearTimeout(timerajax);\
  }\
}\
\
$(document).ready(function() {\
  var ctx = document.getElementById("canvas").getContext("2d");\
  window.myLine = new Chart(ctx, config);\
  getInfo();\
});\
</script>\
'); 