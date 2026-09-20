--pretranslated: do not change this file
 
gettext.textdomain('webui-core')

local proxy = require("datamodel")
local content_helper = require("web.content_helper")
local ngx, string = ngx, string
local format = string.format
local getargs = ngx.req.get_uri_args()
local getradio = getargs.radio
local getWifiAnalyzer = getargs.isWifiAnalyzer

-- Return the acs data for selected radio to generate Analyzer graph
local function getAcsData(cradio, delay)
  local json = require("dkjson")
  local bsslistData = proxy.get("rpc.wireless.bssid.@" .. cradio .. ".bsslist.")
    --Timeout of 30 secs Delay is introduced to get values from bsslistData when the rescan button is clicked
  if delay then
    local step = 0
    while step <= 10 do
      bsslistData = proxy.get("rpc.wireless.bssid.@" .. cradio .. ".bsslist.")
      if next(bsslistData) then
        break
      end
      ngx.sleep(3)
      step = step + 1
    end
  end
  bsslistData = content_helper.convertResultToObject("rpc.wireless.bssid.@" .. cradio .. ".bsslist.",bsslistData)
  table.sort(bsslistData, function(a,b) return a.rssi < b.rssi end)
  local buffer = {}
  local success = json.encode (bsslistData, { indent = false, buffer = buffer})
  if success then
    ngx.header.content_type = "application/json"
    ngx.print(buffer)
    ngx.exit(ngx.HTTP_OK)
  end
end

if ngx.req.get_method() == "POST" and  ngx.req.get_post_args().action =="rescan" then
  local cradio = ngx.req.get_post_args().curradio
  local rescanVal = format ('rpc.wireless.radio.@%s.acs.rescan', cradio)
  proxy.set(rescanVal, "1")
  getAcsData(cradio, true)
elseif getWifiAnalyzer and getargs.getAcsData then
  getAcsData(getradio)
end

  ngx.print('\
\
<div class="row no-margin-right">\
    <div class="col-xs-12 col-md-12 col-sm-12">\
        <h1 class="analyser-info-header">');  ngx.print(T"WiFi Analyser 2.4GHz"); ngx.print('</h1>\
        <h2>');  ngx.print(T"The below chart shows the results of the latest scan of your local area from your gateway."); ngx.print('</h2>\
    </div>\
</div>\
<div class="h3-content h3-content-mobile">\
    <div id = "analyzerGraph">\
      <canvas id="wrapper" width="720px" height="400px" style="border:1px solid #c3c3c3;">\
      </canvas>\
      <div class="row no-margin-right">\
        <div class="col-md-12 col-sm-12 col-xs-12 no-padding-right padding-top-bottom-20 text-right">\
            <input class="button button-apply mob-button-width" id="analyser-btn-rescan" value="');  ngx.print(T"Re-scan"); ngx.print('" type="button" data-toggle="modal" data-target="#rescanModal">\
        </div>\
      </div>\
    </div>\
</div>\
<div class="h3-content h3-content-mobile">\
    <div>\
        <table class="desktop analyser-table"><thead id="keyHeader">\
        </thead>\
 <tbody id="key"></tbody></table>\
</div>\
<!-- Add Modal-->\
<div class="modal fade" id="rescanModal" role="dialog" data-backdrop="static">\
  <div class="modal-dialog" style="margin-top: 106.5px;">\
    <!-- Modal content-->\
    <div class="modal-content">\
    <div class="modal-header hidden-sm hidden-md hidden-lg">\
        <div class="mobile-cancel-popup button-cancel"></div>\
      </div>\
      <div class="modal-body no-padding">\
      </div>\
    <div class="message" id="rescanWaitMessage">');  ngx.print(T"This page will take some time to update the graph and access point list after re-scan."); ngx.print('</div>\
  </div>\
</div>\
</div>\
\
<script>\
var activePage = $(".sub-sub-navigation .active a").attr("id");\
var analyserPage = $(".sub-navigation #analyser").attr("id");\
var radio, wifiAnalyser;\
if (activePage == "analyser24"){\
  radio = "radio_2G";\
  wifiAnalyser = "wl0";\
}\
else if(activePage == "analyser5"){\
  radio = "radio_5G";\
  wifiAnalyser = "wl1";\
  document.getElementsByClassName("analyser-info-header")[0].innerHTML = "');  ngx.print(T"WiFi Analyser 5GHz"); ngx.print('";\
}\
else if(analyserPage == "analyser"){\
  radio = "radio_2G";\
  wifiAnalyser = "wl0";\
  $("a#analyser24").closest("li").addClass(\'active\');\
}\
\
function get_random_color() {\
  var letters = \'0123456789ABCDEF\'.split(\'\');\
  var color = \'#\';\
  for (var i = 0; i < 6; i++ ) {\
    color += letters[Math.round(Math.random() * 15)];\
  }\
  return color;\
}\
function get_y_from_sig(max, min, range, sig) {\
  return ((sig-max)/((min-max)/range))+30;\
}\
function get_curve_y_from_sig(max, min, range, sig) {\
  var line = 350 - get_y_from_sig(max, min, range, sig);\
  var line = 350 - (line *2);\
  return line;\
}\
var maximum= -20;\
var minimum= -105;\
var range = 320;\
var bittarget40 = 10;\
var bittarget80 = 16;\
var c = document.getElementById("wrapper");\
var ctx = c.getContext("2d");\
function initializeAnalyzer() {\
  ctx.lineStyle="#FF0000";\
    //Y Axis\
  ctx.moveTo(30,30);\
  ctx.lineTo(30,350);\
  ctx.stroke();\
    //Power Marks\
  var line10 = get_y_from_sig(maximum, minimum, range, -10);\
  ctx.moveTo(30,line10);\
  ctx.lineTo(25,line10);\
  ctx.stroke();\
  ctx.font="9px Arial";\
  ctx.fillText("-10",7,line10 + 3);\
  var line30 = get_y_from_sig(maximum, minimum, range, -30);\
  ctx.moveTo(30,line30);\
  ctx.lineTo(25,line30);\
  ctx.stroke();\
  ctx.font="9px Arial";\
  ctx.fillText("-30",7,line30 + 3);\
\
    //60\
  var line60 = get_y_from_sig(maximum, minimum, range, -60);\
  ctx.moveTo(30,line60);\
  ctx.lineTo(25,line60);\
  ctx.stroke();\
  ctx.font="9px Arial";\
  ctx.fillText("-60",7,line60 + 3);\
     //90\
  var line90 = get_y_from_sig(maximum, minimum, range, -90);\
  ctx.moveTo(30,line90);\
  ctx.lineTo(25,line90);\
  ctx.stroke();\
  ctx.font="9px Arial";\
  ctx.fillText("-90",7,line90 + 3);\
    //X Axis\
  ctx.moveTo(30,350);\
  ctx.lineTo(690,350);\
  ctx.stroke();\
    //Titles\
  ctx.font="9px Arial";\
  ctx.fillText("');  ngx.print(T"Channel"); ngx.print('",310,390);\
  ctx.save();\
  ctx.translate(0, 0);\
    //ctx.rotate(Math.PI/2);\
  ctx.textAlign = "center";\
  ctx.fillText("');  ngx.print(T"Signal Strength (-dBm)"); ngx.print('", 60, 25);\
  ctx.restore();\
  $("#keyHeader").empty();\
  var offset = 30;\
  var startcolor = parseInt("00000F",16 );\
  var color = startcolor;\
\
    //Channel Marks\
  if(radio == "radio_2G"){\
    ctx.moveTo(120,350);\
    ctx.lineTo(120,355);\
    ctx.stroke();\
    ctx.font="9px Arial";\
    ctx.fillText("1",117,370);\
    ctx.moveTo(320,350);\
    ctx.lineTo(320,355);\
    ctx.stroke();\
    ctx.font="9px Arial";\
    ctx.fillText("6",317,370);\
    ctx.moveTo(520,350);\
    ctx.lineTo(520,355);\
    ctx.stroke();\
    ctx.font="9px Arial";\
    ctx.fillText("11",517,370);\
  } else {\
    //Channel Marks\
    var chn_diff = 24;\
    var chnl = 0;\
    for (i = 0; i <= 7; i++) {\
      ctx.moveTo(60+(chn_diff*i),350);\
      ctx.lineTo(60+(chn_diff*i),355);\
      ctx.stroke();\
      ctx.font="9px Arial";\
      chnl = 36+(i*4);\
      ctx.fillText(chnl.toString(),60+(chn_diff*i)-4,370);\
    }\
\
    for (i = 10; i <= 21; i++) {\
      ctx.moveTo(60+(chn_diff*i),350);\
      ctx.lineTo(60+(chn_diff*i),355);\
      ctx.stroke();\
      ctx.font="9px Arial";\
      chnl = 60+(i*4);\
      ctx.fillText(chnl.toString(),60+(chn_diff*i)-6,370);\
    }\
    for (i = 22.25; i <= 26.25; i++) {\
      ctx.moveTo(60+(chn_diff*i),350);\
      ctx.lineTo(60+(chn_diff*i),355);\
      ctx.stroke();\
      ctx.font="9px Arial";\
      chnl = 60+(i*4);\
      ctx.fillText(chnl.toString(),60+(chn_diff*i)-6,370);\
    }\
  }\
  // add table header\
  var header = $("<tr>");\
  header.append(\
    $("<th>"),\
    $("<th>").append("<span>").text(\'');  ngx.print(T"Network Name (SSID)"); ngx.print('\'),\
    $("<th>").append("<span>").text(\'');  ngx.print(T"Channel"); ngx.print('\'),\
    $("<th>").append("<span>").text(\'');  ngx.print(T"Signal Strength (RSSI)"); ngx.print('\')\
  );\
  $("#keyHeader").append(header);\
}\
\
function generateGraph(ssid,channel,rssi,cap){\
  color =  get_random_color();\
  var Mhz = 1;\
  var cap = parseInt(cap,16).toString(2);\
  while (cap.length <= 16)\
    {\
      cap = "0"+cap;\
    }\
  if (cap.charAt(cap.length-bittarget40) == "1") {\
    Mhz = 2;\
  }\
  if(radio == "radio_2G") {\
    var xcoord = 80+(channel*40);\
    var sig = rssi;\
    if (sig > maximum) {\
	  sig = maximum\
    } else if (sig < minimum) {\
	  sig = minimum\
	}\
    ctx.beginPath();\
    color =  get_random_color();\
    ctx.strokeStyle = color;\
    ctx.moveTo(xcoord-(80*Mhz), 350);\
    ctx.quadraticCurveTo(xcoord, get_curve_y_from_sig(maximum, minimum, range, sig), xcoord+(80*(Mhz)), 350);\
    ctx.stroke();\
  } else {\
    //5GH\
    var chlist40 = [38,46,54,62,102,110,118,126,134,142]\
    var chlist80 = [42,58,106,122,138]\
    for (i = 0; i <= chlist40.length; i++) {\
      if (chlist40[i] == channel){\
        Mhz = 2;\
      }\
    }\
    for (i = 0; i <= chlist80.length; i++) {\
      if (chlist80[i] == channel){\
        Mhz = 4;\
      }\
    }\
    var xcoord = 0\
    if  (channel <= 64) {\
       xcoord = 60+((channel-36)*6);\
    } else {\
       xcoord = 300+((channel-100)*6);\
    }\
\
    var sig = rssi;\
    if (sig > maximum) {\
      sig = maximum\
    } else if (sig < minimum) {\
      sig = minimum\
    }\
    ctx.beginPath();\
    color =  get_random_color();\
    ctx.strokeStyle = color;\
    ctx.moveTo(xcoord-(12*Mhz), 350);\
    ctx.quadraticCurveTo(xcoord, get_curve_y_from_sig(maximum, minimum, range, sig) , xcoord+(12*Mhz), 350);\
    ctx.stroke();\
  }\
\
  // Add new row\
  var newRow = $("<tr>");\
  newRow.append(\
    $("<td>").append($("<div>").addClass("bullet").css("background-color", color)),\
    $("<td>").text(ssid),\
    $("<td>").addClass(\'tC\').text(channel),\
    $("<td>").addClass(\'tC\').text(rssi)\
  );\
  $("#keyHeader").append(newRow);\
}\
\
$(document).ready(function(){\
  $("#analyser-btn-rescan").on("click",function(a){\
    var params = [];\
    params.push({\
      name : "action",\
      value : "rescan"\
      },{\
      name : "curradio",\
      value : radio\
      },{\
      name : "CSRFtoken",\
      value : "');  ngx.print( ngx.ctx.session:getCSRFtoken()); ngx.print('"\
      });\
      $.post("/modals/analyser.lp", params, function(acsData){\
        ctx.clearRect(0, 0, 720, 400);\
        $("#keyHeader").empty();\
        initializeAnalyzer();\
        if ( acsData.length > 0 ) {\
          $("#rescanModal").modal(\'hide\');\
          $.each(acsData, function(i, data){\
            generateGraph(data.ssid,data.channel,data.rssi,data.cap);\
          });\
        }\
      });\
  });\
  initializeAnalyzer();\
  $.get("/modals/analyser.lp?isWifiAnalyzer="+wifiAnalyser+"&getAcsData=true&radio="+radio+"",function(acsData){\
      $.each(acsData, function(i, data) {\
        generateGraph(data.ssid,data.channel,data.rssi,data.cap);\
      });\
    });\
 });\
</script>\
'); 