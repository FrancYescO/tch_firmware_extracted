--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local proxy = require("datamodel")

local args = ngx.req.get_uri_args()
local format = string.format

--AJAX Part
local function AJAX()
  local raw = format("%s", proxy.get("sys.graph.ifstat")[1].value)
  local cleaned = raw:gsub("n&#47;a", "0.00")
  ngx.print(format("{ \"intf\":\"%s\" }", cleaned))
end

if args.ajaxreq == "1" then
 AJAX()
 ngx.exit(ngx.HTTP_OK)
end

--AJAX End

local html = {}
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
var scale_max = 1000;\
var config = {\
  type: "line",\
  data: {\
    labels: [],\
    datasets: [{\
        label: "ATM0 Rx",\
        backgroundColor: "#008AFF",\
        borderColor: "#008AFF",\
        data: "",\
        fill: false\
      },\
      {\
        label: "ATM0 Tx",\
        backgroundColor: "#7EC4FF",\
        borderColor: "#7EC4FF",\
        data: "",\
        fill: false\
      },\
      {\
        label: "PTM0 Rx",\
        backgroundColor: "#0000FF",\
        borderColor: "#0000FF",\
        data: "",\
        fill: false\
      },\
      {\
        label: "PTM0 Tx",\
        backgroundColor: "#7E7EFF",\
        borderColor: "#7E7EFF",\
        data: "",\
        fill: false\
      },\
      {\
        label: "ETH WAN Rx",\
        backgroundColor: "#00FFFF",\
        borderColor: "#00FFFF",\
        data: "",\
        fill: false\
      },\
      {\
        label: "ETH WAN Tx",\
        backgroundColor: "#A8FFFF",\
        borderColor: "#A8FFFF",\
        data: "",\
        fill: false\
      },\
      {\
        label: "LAN 1 Rx",\
        backgroundColor: "#FF0000",\
        borderColor: "#FF0000",\
        data: "",\
        fill: false\
      },\
      {\
        label: "LAN 1 Tx",\
        backgroundColor: "#FF6767",\
        borderColor: "#FF6767",\
        data: "",\
        fill: false\
      },\
      {\
        label: "LAN 2 Rx",\
        backgroundColor: "#FF7C00",\
        borderColor: "#FF7C00",\
        data: "",\
        fill: false\
      },\
      {\
        label: "LAN 2 Tx",\
        backgroundColor: "#FFAE61",\
        borderColor: "#FFAE61",\
        data: "",\
        fill: false\
      },\
      {\
        label: "LAN 3 Rx",\
        backgroundColor: "#FFE000",\
        borderColor: "#FFE000",\
        data: "",\
        fill: false\
      },\
      {\
        label: "LAN 3 Tx",\
        backgroundColor: "#FFED69",\
        borderColor: "#FFED69",\
        data: "",\
        fill: false\
      },\
      {\
        label: "LAN 4 Rx",\
        backgroundColor: "#FBFF00",\
        borderColor: "#FBFF00",\
        data: "",\
        fill: false\
      },\
      {\
        label: "LAN 4 Tx",\
        backgroundColor: "#FDFF95",\
        borderColor: "#FDFF95",\
        data: "",\
        fill: false\
      },\
      {\
        label: "WLAN (2.4GHz) Rx",\
        backgroundColor: "#00A700",\
        borderColor: "#00A700",\
        data: "",\
        fill: false\
      },\
      {\
        label: "WLAN (2.4GHz) Tx",\
        backgroundColor: "#6EAA6E",\
        borderColor: "#6EAA6E",\
        data: "",\
        fill: false\
      },\
      {\
        label: "WLAN (5GHz) Rx",\
        backgroundColor: "#00FF00",\
        borderColor: "#00FF00",\
        data: "",\
        fill: false\
      },\
      {\
        label: "WLAN (5GHz) Tx",\
        backgroundColor: "#92FF92",\
        borderColor: "#92FF92",\
        data: "",\
        fill: false\
      },\
      {\
        label: "Total Rx",\
        backgroundColor: "#000000",\
        borderColor: "#000000",\
        data: "",\
        fill: false\
      },\
      {\
        label: "Total Tx",\
        backgroundColor: "#FFFFFF",\
        borderColor: "#000000",\
        data: "",\
        fill: false\
      },\
    ]\
  },\
  options: {\
    responsive: true,\
    legend: {\
      position: "right"\
    },\
    title: {\
      display: true,\
      text: "Interface Activity"\
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
          labelString: "Speed (Mbps)"\
        },\
        ticks: {\
          max: 1000,\
          min: 0,\
          stepSize: 100\
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
  if (($(".chartjs-render-monitor").length != 0) && ($("#GraphChoice").val() == "Interface")) {\
    var url = "/modals/diagnostics-graphs-modal.lp";\
    var checktimer = "1000";\
    var gets = {};\
    gets.ajaxreq = "1";\
    gets.graph = "Interface";\
    $.getJSON(url, gets).done(function(data) {\
        if (data) {\
          //atm0,ptm0,eth4,eth0,eth1,eth2,eth3,wl0,wl1,wl0_1,wl1_1\
          var intf = data.intf;\
          var splitdata = intf.match(/(\\S+)/g);\
          if (splitdata !== null) {\
            for (count = 0; count <= 17; count++) {\
              config.data.datasets[count].data.unshift(splitdata[count] / 1000);\
              if (config.data.datasets[count].data.length > 30) config.data.datasets[count].data.pop();\
            }\
            config.data.datasets[18].data.unshift(splitdata[22] / 1000);\
            if (config.data.datasets[18].data.length > 30) config.data.datasets[18].data.pop();\
            config.data.datasets[19].data.unshift(splitdata[23] / 1000);\
            if (config.data.datasets[19].data.length > 30) config.data.datasets[19].data.pop();\
          }\
          var cur_max = 0;\
          for (countX = 0; countX <= 30; countX++) {\
            for (countY = 0; countY <= 19; countY++) {\
              if (config.data.datasets[countY].data[countX] > cur_max) cur_max = config.data.datasets[countY].data[countX];\
            }\
          }\
          if (cur_max > 1000) {\
            scale_max = cur_max\
          } else if (cur_max > 500) {\
            scale_max = 1000\
          } else if (cur_max > 350) {\
            scale_max = 500\
          } else if (cur_max > 100) {\
            scale_max = 350\
          } else if (cur_max > 25) {\
            scale_max = 100\
          } else {\
            scale_max = 25\
          }\
          config.options.scales.yAxes[0].ticks.max = scale_max;\
          window.myLine.update();\
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