(function (context) {
  var panel = $("duma-panel", context)[0];
  var chart = $("duma-chart", context)[0];
  var history_range = $("ping-history-range", context)[0];
  var thisCategory = null;
  var thisServer = null;
  var last = Date.now();

  var icon = new Image(64,64);
  icon.src = "http://"+document.domain+"/desktop/dumaos.svg";

  var triangle = (function(){
    var c = document.createElement("canvas");
    c.width = 20;
    c.height = 10;
    var ctx = c.getContext("2d");
    var path = new Path2D();
    path.moveTo(c.width,c.height);
    path.lineTo(c.width,0);
    //path.lineTo(c.width*0.7,c.height/2);
    path.lineTo(0,c.height/2);
    /*
    path.moveTo(c.width,0);
    path.lineTo(c.width*0.7,c.height/2);
    path.lineTo(0,c.height/2);*/
    ctx.fillStyle = "<%= theme.PRIMARY_TEXT_COLOR %>";
    ctx.fill(path);
    return c;
  })();

  var do_icons = false;
  var history_data = [];
  var preTimes = [0,0];

  var currentPing = null;
  var currentInterval = null;

  var ip_element = $("#ipAddress",context);
  function setIPText(IP){
    ip_element.text(IP);
  }
  var current_ping = $("#currentPing",context);
  function setCurrent(current){
    current_ping.text(current.y + "ms");
    Object.assign(currentPing,current);

    var colours = chart.chart.data.datasets[0].pointBorderColor;
    colours[colours.length-1] = scoreUtil.getPingColour(current.y);

    chart.chart.update();
  }

  function current_loop(start=true){
    if(currentInterval) { clearInterval(currentInterval); }
    forCurrent();
    if(start) { currentInterval = setInterval(forCurrent,2500); }
  }
  function forCurrent(){
    long_rpc_promise(packageId,"constant_ping_nonsaving",[thisServer]).done(function(result){
      if(result[0]){
        result = Math.ceil(JSON.parse(result[0])[thisServer.ip] * 1000);
        var new_current = {
          t: preTimes[1] || last,
          y: result,
          unix: preTimes[1] || last,
          now: true
        };
        if(!currentPing){
          currentPing = new_current;
          refresh();
        }
        setCurrent(new_current);
      }
    });
  }

  function refresh(){
    OnHistoryChange(preTimes[0],preTimes[1]);
  }
  function OnHistoryChange(begin,end){
    $("#pages-selection",context).prop("selected",history_data.length > 0)
    preTimes = [begin,end];
    end = end || last;
    var colours = [];
    var styles = [];
    var ticksBounds = [null, 0];
    var min_date = new Date(begin);
    var max_date = new Date(end);

    var average = [0,0];
    var pingData = [];

    function rand(){
      return Math.max(0,Math.min(255,Math.round(Math.random()*255)));
    }
    for(var i = 0; i < history_data.length; i ++){
      var d = history_data[i];
      pingData.push(d);
      styles.push(do_icons ? icon : "circle");
      colours.push(/*do_icons ? ( "rgb("+[rand(),rand(),rand()].join(',')+")" ) :*/ scoreUtil.getPingColour(d.y));
      if(begin <= d.unix && d.unix <= end){
        average[0] += d.y;
        average[1] ++;
        if(ticksBounds[0] === null || d.y < ticksBounds[0]){
          ticksBounds[0] = d.y;
        }
        if(d.y > ticksBounds[1]){
          ticksBounds[1] = d.y;
        }
      }
    }

    // code to enable the moving arrow showing the current ping
    // the arrow would move up and down the right side
    // left here in case functionality wants to be added in future
    // also, because this is a GOOD FEATURE JACK WHY WOULD WE WANT IT REMOVED
    // if(currentPing){
    //   currentPing.t = new Date(end);
    //   pingData.push(currentPing);
    //   styles.push(triangle);
    //   colours.push(scoreUtil.getPingColour(currentPing.y));
    //   // if(currentPing.y < ticksBounds[0]){
    //   //   ticksBounds[0] = currentPing.y;
    //   // }
    //   // if(currentPing.y > ticksBounds[1]){
    //   //   ticksBounds[1] = currentPing.y;
    //   // }
    // }
    average = (average[0] / average[1]).toFixed(2);
    var padding = 5;
    ticksBounds[0] = Math.max(0,ticksBounds[0] - padding); //padding
    ticksBounds[1] = Math.max(ticksBounds[1] + padding, ticksBounds[0] + 20); //padding || bottom bound + 20
    var datasets = [
      {
        ariaModeTableEveryLine: true,
        data: pingData,
        pointStyle: styles,
        pointBorderColor: colours,
        pointBackgroundColor: colours,
        pointHoverBorderColor: colours,
        pointHoverBackgroundColor: colours,
        showLine: false
      },
      {
        ariaIgnoreDataset: true,
        data: [{t:min_date,y:average},{t:max_date,y:average}],
        fill: false,
        borderColor: scoreUtil.getPingColour(average),
        pointBorderColor: "rgba(0,0,0,0)",
        pointBackgroundColor: "rgba(0,0,0,0)",
        forceTooltips: [true,false]
      }
    ];
    chart.chart.config.options.scales.xAxes[0].ticks.min = min_date;
    chart.chart.config.options.scales.xAxes[0].ticks.max = max_date;
    chart.chart.config.options.scales.yAxes[0].ticks.min = ticksBounds[0];
    chart.chart.config.options.scales.yAxes[0].ticks.max = ticksBounds[1];

    chart.data = {
      labels: [],
      datasets: datasets
    };
  }

  function format_history(timeData){
    history = [];

    forObject(timeData,function(k,v,i){
      var snapTime = parseInt(k) * 1000;
      history_data.push({
        t: new Date(snapTime),
        y: Math.ceil(v),
        unix: snapTime,
        sort_key: snapTime
      });
    });
    history_data.sort(function(a,b) {return a.unix - b.unix});
    history_range._callback = function(start,end){
      last = Date.now();
      OnHistoryChange(start,end);
    }.bind(this);
    history_range._sliderChange(history_range.sliderVal.min,history_range.sliderVal.max);
  }

  function init(category, servers){
    thisServer = servers[panel.data.server];
    if(!thisServer){
      console.error("Server not found " + panel.data.server);
      return;
    }
    thisCategory = category;
    if(!thisCategory){
      console.error("Category not found " + panel.data.category);
    }
    setIPText(thisServer.ip);
    var timeDisplayFormat = "DD MMM";
    chart.options = {
      live: true,
      animation: false,
      tooltips: {
        displayColors: false,
        callbacks: {
          title: function(tooltipItems, data) {
            if(data.datasets[tooltipItems[0].datasetIndex].data[tooltipItems[0].index].now) return "<%= i18n.currentPing %>: " + tooltipItems[0].yLabel + "ms";
            if(tooltipItems[0].datasetIndex === 1) return "<%= i18n.averagePing %>: " + tooltipItems[0].yLabel + "ms";
            var tdate = new Date(tooltipItems[0].xLabel);
            return tdate.toLocaleDateString([], {day:'numeric', month: 'numeric'}) + " " + tdate.toLocaleTimeString([], {hour12: false, hour: '2-digit', minute:'2-digit'})
          },
          label: function(tooltipItem, data) {
            if(tooltipItem.datasetIndex === 1 || data.datasets[tooltipItem.datasetIndex].data[tooltipItem.index].now) return;
            return tooltipItem.yLabel + "ms";
          }
        },
      },
      time: {
        tooltipFormat: timeDisplayFormat
      },
      scales: {
        xAxes: [{
          type: 'time',
          display: true,
          distribution: 'linear',
          time: {
            displayFormats: {
              'millisecond': timeDisplayFormat,
              'second': timeDisplayFormat,
              'minute': timeDisplayFormat + " HH:MM",
              'hour': timeDisplayFormat + " HH:00",
              'day': timeDisplayFormat,
              'week': timeDisplayFormat,
              'month': timeDisplayFormat,
              'quarter': timeDisplayFormat,
              'year': timeDisplayFormat,
            },
            minUnit: 'hour'
          },
          ticks: {
            min: new Date(Date.now() - 86400000),
            max: new Date(Date.now()),
            autoSkip: true,
            maxTicksLimit: 12,
            maxRotation: 0,
          },
          bounds: 'ticks',
          scaleLabel: {
            display: false,
            labelString: "<%= i18n.dateAndTime %>"
          }
        }],
        yAxes: [{
          ticks: {
            min: 0,
            max: 100
          },
          scaleLabel: {
            display: true,
            labelString: "<%= i18n.pingMS %>"
          }
        }]
      },
      elements: {
        point:{
          pointStyle: "circle",
          radius: 5,
          hitRadius: 10
        },
        line: {
          borderColor: "#888888ff",
          borderDash: [10,10]
        }
      },
      legend: {
        display: false
      }
    };
    current_loop();
  }

  function OnClickAddToList(){
    $("add-to-list",context)[0].open(thisServer);
  }

  function setHeader(){
    var headers = [];
    if(thisCategory) headers.push(thisCategory.display);
    if(thisServer.name) headers.push(titleCase(thisServer.name));
    if(thisServer.display) headers.push(thisServer.display);
    if(!thisServer.display) headers.push(thisServer.ip);
    panel.header = headers.join(" - ");
  }
  
  Q.spread([
    long_rpc_promise(packageId,"get_category",[panel.data.category]),
    long_rpc_promise(packageId,"get_history_server",[panel.data.serverIP])
  ], function(categoryAndServers, history){
    var category = JSON.parse(categoryAndServers[0]);
    var servers = JSON.parse(categoryAndServers[1]).servers;
    history = history.length ? JSON.parse(history) : {};
    forObject(servers,function(key,serv){
      serv.identifier = key;
    });
    delete history.references;
    init(category, servers);
    format_history(history);
    var wi = duma.type.OnWord("dumaos is the best",function(){do_icons = !do_icons;refresh();}.bind(this));
    panel.destructorCallback = function(){ current_loop(false);duma.type.OffWord(wi);};
    $("#AddToList",context).on("click", OnClickAddToList);
    setHeader();
    $("duma-panel", context).prop("loaded", true);
  }).done();

})(this);

//# sourceURL=ping-map.js
