--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local lp = require("web.lp")
local proxy = require("datamodel")

local ngx = ngx
local args = ngx.req.get_uri_args()

local values
--AJAX Part
local function AJAX()
  values = proxy.get("sys.class.xdsl.@line0.BitLoading")
  local html = {}
  html[#html+1] = "{"
  for k, v in pairs(values) do
    html[#html+1] = string.format("\"%s\":\"%s\"", k, v.value)
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
//For dynamic data, we need to perform an ajax call in a given interval, keep fetching the data and update the graph\
//var loadingdata = [\',proxy.get("sys.class.xdsl.@line0.BitLoading")[1].value,\'];\
\
//Generating Static Data for now\
var loadingdata = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1];\
var cur_max = 0;\
var scale_max = 40;\
var config = {\
  type: "bar",\
  data: {\
    labels: [],\
    datasets: [{\
      label: "xDSL Tone Bit Loading",\
      backgroundColor: "#FF0000",\
      borderColor: "#FF5000",\
      data: loadingdata,\
      fill: true\
    }]\
  },\
  options: {\
    responsive: true,\
    legend: {\
      display: false,\
      position: "top"\
    },\
    title: {\
      display: true,\
      text: "xDSL Tone Bit Loading"\
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
          labelString: "Tone"\
        },\
        barPercentage: 1,\
        barThickness: 1\
      }],\
      yAxes: [{\
        display: true,\
        scaleLabel: {\
          display: true,\
          labelString: "Bits/Tone"\
        },\
        ticks: {\
          max: 25,\
          min: 0,\
          stepSize: 10\
        }\
      }]\
    }\
  }\
};\
\
for (counter = 0; counter < 4095; counter++) {\
  config.data.labels.push(((counter)).toString());\
  if (config.data.datasets[0].data[counter] > cur_max) cur_max = config.data.datasets[0].data[counter];\
}\
scale_max = Math.ceil(cur_max / 10) * 10;\
config.options.scales.yAxes[0].ticks.max = scale_max;\
\
$(document).ready(function() {\
  var ctx = document.getElementById("canvas").getContext("2d");\
  window.myLine = new Chart(ctx, config);\
});\
</script>\
'); 