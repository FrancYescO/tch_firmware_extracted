(function (context)
{
  // Enums for graphs
  const graphTargets = 
  {
    Download: 0,
    Upload: 1,
    Ping: 2,
    Jitter: 3,
    PacketLoss: 4,
    BloatDownload: 5,
    BloatUpload: 6,
    BloatIdle: 7,
    SetDownload: 8,
    SetUpload: 9,
  }

  var forceHide_ForceTooltips = false;
  var otherTooltip_HideForceTooltips = false;
  var canShow_ForceTooltips = [false,false,false];

  function show_forceTooltip_speedGraph(position,sector,info,datasets){
    if(forceHide_ForceTooltips || otherTooltip_HideForceTooltips || !canShow_ForceTooltips[0]) return false;
    var length = datasets[info.datasetIndex].data.length;
    return (position === "first" && info.index === 0)
      || (position === "last" && info.index + 1 === length);
  }

  function show_forceTooltip_minMax(sector,info,datasets){
    var data = datasets[info.datasetIndex].data[info.index];
    return !forceHide_ForceTooltips && !otherTooltip_HideForceTooltips && canShow_ForceTooltips[1] && !!data.minMax;
  }

  function ariaValuBytesFormat(val){
    var value = val && typeof val.y !== "undefined" ? val.y : val;
    return value && FormatBytes(value);
  }
  function ariaValueMsFormat(val){
    var value = val && typeof val.y !== "undefined" ? val.y : val;
    return value && "<%= i18n.msFormat %>".format(value);
  }

  // Config to reduce work to add new graphs
  const graphConfigs = 
  [
    // Speed
    {
      title: "<%= i18n.speedTest %>",
      domTag: "#speed-dom-graph",
      ratingTag: "#speed-rating",

      summaryInfo:
      [
        {
          label: "<%= i18n.download %>",
          result: "-",
          colour: "FFFFFF",
          visible: true,
          bgColour: "",
        },
        {
          label: "<%= i18n.upload %>",
          result: "-",
          colour: "FFFFFF",
          visible: true,
          bgColour: "",
        },
        {
          label: "<%= i18n.netflixSpeed %>",
          result: "-",
          colour: "FFFFFF",
          visible: false,
          bgColour: "",
          disableClick: true,
        }
      ],

      startIndex: 0,
      htmlTag: '#speed-graph',

      YAxisLabel: "<%= i18n.speed_yAxisLabel %>",
      YAxisAddUnit: true,
      XAxisLabel: "<%= i18n.ariaChartSpeed %>",

      YAxisTickFormat: (graphMan, val) => Math.round(val / (1000 ** graphMan.maxBase[0])),

      LabelFormat: (tooltipItem, data) => data.datasets[tooltipItem.datasetIndex].label + ": " + FormatBytes(tooltipItem.yLabel, 1000),

      EnableRightAxis: false,

      config:
      [
        // Download
        {
          Label: '<%= i18n.download %>',
          ColourIndex: 0,
          Fill: false,
          DataIndex: graphTargets.Download,
          Type: `line`,
          Axis: `left`,
          ariaValueFormatter: ariaValuBytesFormat,
        },

        // Upload
        {
          Label: '<%= i18n.upload %>',
          ColourIndex: 1,
          Fill: false,
          DataIndex: graphTargets.Upload,
          Type: `line`,
          Axis: `left`,
          ariaValueFormatter: ariaValuBytesFormat,
        },
        // Download
        {
          Label: '<%= i18n.setDownload %>',
          ColourIndex: 0,
          Fill: false,
          DataIndex: graphTargets.SetDownload,
          Type: `line`,
          Axis: `left`,
          LineDash: [10,10],
          ariaValueFormatter: ariaValuBytesFormat,
          forceTooltips: show_forceTooltip_speedGraph.bind(this,'first')
        },
        
        // Upload
        {
          Label: '<%= i18n.setUpload %>',
          ColourIndex: 1,
          Fill: false,
          DataIndex: graphTargets.SetUpload,
          Type: `line`,
          Axis: `left`,
          LineDash: [10,10,10],
          ariaValueFormatter: ariaValuBytesFormat,
          forceTooltips: show_forceTooltip_speedGraph.bind(this,'last')
        },
      ],
    },

    // Ping
    {
      title: "<%= i18n.pingTest %>",
      domTag: "#ping-dom-graph",
      ratingTag: "#ping-rating",

      summaryInfo:
      [
        {
          label: "<%= i18n.averagePing %>",
          result: "-",
          colour: "FFFFFF",
          visible: true,
          bgColour: ""
        },
        {
          label: "<%= i18n.jitter %>",
          result: "-",
          colour: "FFFFFF",
          visible: true,
          bgColour: "",
        },
        {
          label: "<%= i18n.packetLoss %>",
          result: "-",
          colour: "FFFFFF",
          visible: true,
          bgColour: "FFFFFF",
        }
      ],

      startIndex: 2,
      htmlTag: '#ping-graph',

      YAxisLabel: "<%= i18n.ping_yAxisLabel %>",
      YAxisAddUnit: false,
      XAxisLabel: "<%= i18n.ariaChartPing %>",

      YAxisTickFormat: null,

      LabelFormat: function(tooltipItem, data) {
        var label = data.datasets[tooltipItem.datasetIndex].label;
        var pointData = data.datasets[tooltipItem.datasetIndex].data[tooltipItem.index];
        if(pointData.minMax === "min") label = "<%= i18n.lowestPing %>";
        if(pointData.minMax === "max") label = "<%= i18n.highestPing %>";
        return `${label} : ${tooltipItem.yLabel.toFixed(2)}ms`
      },
      EnableRightAxis: true,


      config:
      [
        // Ping
        {
          Label: '<%= i18n.ping %>',
          ColourIndex: 0,
          Fill: false,
          DataIndex: graphTargets.Ping,
          Type: `line`,
          Axis: `left`,
          minMax: {
            radius: 6,
            pointStyle: 'circle'
          },
          ariaValueFormatter: ariaValueMsFormat,
          forceTooltips: show_forceTooltip_minMax
        },

        // Jitter
        {
          Label: '<%= i18n.jitter %>',
          ColourIndex: 1,
          Fill: false,
          DataIndex: graphTargets.Jitter,
          Type: `line`,
          Axis: `left`,
          ariaValueFormatter: ariaValueMsFormat,
        },

        // Packet Loss
        {
          Label: '<%= i18n.packetLoss %>',
          ColourIndex: 2,
          Fill: true,
          DataIndex: graphTargets.PacketLoss,
          Type: `bar`,
          Axis: `right`,
          ariaIgnoreDataset: true
        },
      ],
    },

    // Bloat
    {
      title: "<%= i18n.bufferTest %>",
      domTag: "#bloat-dom-graph",
      ratingTag: "#bloat-rating",

      summaryInfo:
      [
        {
          label: "<%= i18n.download %>",
          result: "-",
          colour: "FFFFFF",
          visible: true,
          bgColour: "",
        },
        {
          label: "<%= i18n.upload %>",
          result: "-",
          colour: "FFFFFF",
          visible: true,
          bgColour: "",
        },
        {
          label: "<%= i18n.idle %>",
          result: "-",
          colour: "FFFFFF",
          visible: true,
          bgColour: "",
        }
      ],

      startIndex: 5,
      htmlTag: '#bloat-graph',

      YAxisLabel: "<%= i18n.buffer_yAxisLabel %>",
      YAxisAddUnit: false,
      XAxisLabel: "<%= i18n.ariaChartBuffer %>",

      YAxisTickFormat: null,

      LabelFormat: (tooltipItem, data) => `${data.datasets[tooltipItem.datasetIndex].label}: ${tooltipItem.yLabel.toFixed(2)}ms`,
      EnableRightAxis: false,

      config:
      [
        // Download
        {
          Label: '<%= i18n.download %>',
          ColourIndex: 0,
          Fill: false,
          DataIndex: graphTargets.BloatDownload,
          Type: `line`,
          Axis: `left`,
          ariaValueFormatter: ariaValueMsFormat,
        },

        // Upload
        {
          Label: '<%= i18n.upload %>',
          ColourIndex: 1,
          Fill: false,
          DataIndex: graphTargets.BloatUpload,
          Type: `line`,
          Axis: `left`,
          ariaValueFormatter: ariaValueMsFormat,
        },

        // Idle
        {
          Label: '<%= i18n.idle %>',
          ColourIndex: 2,
          Fill: false,
          DataIndex: graphTargets.BloatIdle,
          Type: `line`,
          Axis: `left`,
          ariaValueFormatter: ariaValueMsFormat,
        },
      ],
    },
  ]

  class TestProcessor
  {
    constructor(graphMan)
    {
      this.graphMan = graphMan;
      this.testTimeInterval = null;
      this.graphUpdateRate = 30; // 30 fps
      this.lastUpdate = -1;
      this.testStartTime = -1;
      this.currentTest = 0;
      this.minMaxTimes = [-1,-1];
      this.downloadCounter = 0;
      this.upDiff = 0;
      this.preDownTime = 0;
      this.lowSpeedToast = true;
    }

    StartTest()
    {
      $("#runTestDialogButton", context)[0].disabled = true;
      $("#testRunningSpinnerWrapper", context).show();
      $("#speed-test-dialog", context)[0].close();

      this.ClearGraphs();
      this.UpdateGraph();

      this.websocket = newWebSocket(8081, "benchmark");
      this.websocket.addEventListener(`open`, this.SocketOpen.bind(this));
      this.websocket.addEventListener(`close`, this.SocketClose.bind(this));
      this.websocket.addEventListener(`error`, this.SocketError.bind(this));
      this.websocket.addEventListener(`message`, this.SocketRecieveMessage.bind(this));
    }

    SocketOpen(event)
    {
      var speedQoS = $("#qos-speed-checkbox", context)[0].checked;
      var pingQoS = $("#qos-ping-checkbox", context)[0].checked;
      var bloatQoS = $("#qos-bloat-checkbox", context)[0].checked;
      
      //TODO QOS temp removal
      var qosOptions =  "false-false-false"; // speedQoS + "-" + pingQoS + "-" + bloatQoS;

      $(graphConfigs[0].domTag, context)[0].setQoS(speedQoS);
      $(graphConfigs[1].domTag, context)[0].setQoS(pingQoS);
      $(graphConfigs[2].domTag, context)[0].setQoS(bloatQoS);

      this.websocket.send(qosOptions);
    }

    SocketClose(event)
    {
      // console.log("Close: ", event);
      $("#benchmarkHistory", context)[0].ReloadHistory();
      $("#runTestDialogButton", context)[0].disabled = false;
      $("#testRunningSpinnerWrapper", context).hide();
    }

    SocketError(event)
    {
      console.log("Error: ", event);
    }

    SocketRecieveMessage(event)
    {
      this.AllowLowSpeedToast(true);
      var graphUpdated = this.SendResult(event.data);
      var time = new Date().getTime();

      if (graphUpdated[1] || (this.lastUpdate == -1) || ((time - this.lastUpdate) > this.graphUpdateRate))
      {
        this.UpdateGraph(graphUpdated[0]);
        this.lastUpdate = time;
      }
    }

    SendResult(message)
    {
      var stringData = message.split("-");
      var data = stringData.map(Number);

      switch (data[0])
      {
        // Speed Test
        case 0:
          switch (data[1])
          {
            // Upload data
            case 0:
              this.graphMan.PushResult(data[3], data[2] * 1000, graphTargets.Upload, 0);
              var timeIndex = this.minMaxTimes[0] === -1 ? 0 : 1;
              this.minMaxTimes[timeIndex] = data[3];
              this.graphMan.PushResult(this.minMaxTimes[timeIndex], this.uploadSpeed * 1000, graphTargets.SetUpload, 0);
              return [0, false];
            
            // Average upload
            case 1:
              var cleanResultText = Math.round((data[2] / 100) / 10) + " / " + FormatBytes(this.uploadSpeed * 1000,1000);
              $(graphConfigs[0].domTag, context)[0].setResult(1, cleanResultText);
              $(graphConfigs[0].ratingTag, context)[0].upload = data[2];
              $(graphConfigs[0].ratingTag, context)[0].expectedUpload = this.uploadSpeed;
              $(graphConfigs[0].ratingTag, context)[0].tooltip.line1 = cleanResultText;
              return [0, true];

            // Download data
            case 2:
              this.graphMan.PushResult(data[3], data[2] * 1000, graphTargets.Download, 0);
              var useTime = this.preDownTime;
              if(this.downloadCounter === 0){
                this.upDiff = this.minMaxTimes[1] - this.minMaxTimes[0];
                useTime = data[3];
              }else if(this.downloadCounter === 1){
                useTime = this.graphMan.startTimes[0] + this.upDiff;
              }
              this.graphMan.PushResult(useTime, this.downloadSpeed * 1000, graphTargets.SetDownload, 0, undefined, undefined, this.downloadCounter > 1 ? this.downloadCounter - 1 : null);
              this.downloadCounter++;
              this.preDownTime = data[3];
              return [0, false];

            // Average download
            case 3:
              canShow_ForceTooltips[0] = true;

              var cleanResultText = Math.round((data[2] / 100) / 10) + " / " + FormatBytes(this.downloadSpeed * 1000,1000);
              $(graphConfigs[0].domTag, context)[0].setResult(0, cleanResultText);
              var rating = $(graphConfigs[0].ratingTag, context)[0];
              rating.download = data[2];
              rating.expectedDownload = this.downloadSpeed;

             var netflixRating = GetNetflixRating(data[2]);

              $(graphConfigs[0].domTag, context)[0].setResult(2, netflixRating);

              return [0, true];
          }
          break;

        // Ping Test
        case 1:
          switch (data[1])
          {
            // Ping/Jitter data
            case 0:
              this.graphMan.PushResult(data[4], data[2], graphTargets.Ping, 1);
              this.graphMan.PushResult(data[4], data[3], graphTargets.Jitter, 1);
              return [1, false];
            
            // Average ping
            case 1:
              $(graphConfigs[1].domTag, context)[0].setResult(0, data[2].toFixed(2) + "ms");
              $(graphConfigs[1].ratingTag, context)[0].ping = data[2];
              canShow_ForceTooltips[1] = true;
              return [1, true];

            // Average jitter
            case 2:
              $(graphConfigs[1].domTag, context)[0].setResult(1, data[2].toFixed(2) + "ms");
              $(graphConfigs[1].ratingTag, context)[0].jitter = data[2];
              return [1, true];

            // Packet Loss
            case 3:
              $(graphConfigs[1].domTag, context)[0].setResult(2, data[2].toFixed(2) + "%");

              var rating = $(graphConfigs[1].ratingTag, context)[0];
              rating.droppedPercent = data[2];

              return [1, true];

            // Lost packets
            case 4:
              this.graphMan.PushResult(data[3], 100, graphTargets.PacketLoss, 1, false, graphTargets.Ping);
              return [1, true];
          }
          break;
        
        // Bloat Test
        case 2:
          switch(data[1])
          {
            // Bloat idle data
            case 0:
              this.graphMan.PushResult(data[4], data[2], graphTargets.BloatIdle, 2);
              return [2, false];

            // Average bloat idle
            case 1:
              $(graphConfigs[2].domTag, context)[0].setResult(2, data[2].toFixed(2) + "ms");
              $(graphConfigs[2].ratingTag, context)[0].idle = data[2];
              return [2, true];

            // Average bloat idle jitter
            case 2:
              // console.log("Average bloat idle jitter: ", data[2]);
              break;

            // Bloat upload data
            case 3:
              this.graphMan.PushResult(data[4], data[2], graphTargets.BloatUpload, 2);
              return [2, false];

            // Average bloat upload
            case 4:
              $(graphConfigs[2].domTag, context)[0].setResult(1, data[2].toFixed(2) + "ms");
              $(graphConfigs[2].ratingTag, context)[0].up = data[2];
              return [2, true];

            // Average bloat upload jitter
            case 5:
              // console.log("Average bloat upload jitter: ", data[2]);
              break;

            // Bloat download data
            case 6:
              this.graphMan.PushResult(data[4], data[2], graphTargets.BloatDownload, 2);
              return [2, false];

            // Average bloat download
            case 7:
              $(graphConfigs[2].domTag, context)[0].setResult(0, data[2].toFixed(2) + "ms");
              var rating = $(graphConfigs[2].ratingTag, context)[0];
              rating.down = data[2];
              return [2, true];

            // Average bloat download jitter
            case 8:
              // console.log("Average bloat download jitter: ", data[2]);
              break;
          }
          break;

        // Version
        case 8:
          if (stringData[1] != "1.1.0")
            return [-1, false];
        
        // QoS status
        case 9:
          $(graphConfigs[0].domTag, context)[0].setQoS(stringData[1] == "true");
          $(graphConfigs[1].domTag, context)[0].setQoS(stringData[2] == "true");
          $(graphConfigs[2].domTag, context)[0].setQoS(stringData[3] == "true");
          break;

        // Time span and start time
        case 10:
          $(graphConfigs[0].htmlTag, context)[0].chart.config.options.scales.xAxes[0].ticks.max = data[1] * 1000;
          $(graphConfigs[1].htmlTag, context)[0].chart.config.options.scales.xAxes[0].ticks.max = data[2] * 1000;
          $(graphConfigs[2].htmlTag, context)[0].chart.config.options.scales.xAxes[0].ticks.max = data[3] * 1000;
          this.testStartTime = data[4];

          var dateTime = new Date(this.testStartTime * 1000);
          $("#benchmarkTime", context)[0].testTime = dateTime.toLocaleDateString([], {day: '2-digit', month: 'short', year: '2-digit'}) + " - " +
                                                     dateTime.toLocaleTimeString([], {hour12: false, hour: '2-digit', minute:'2-digit'});
          break;

        // Test end
        case 999:
          if(this.currentTest == 0 && this.lowSpeedToast) openLowSpeedsToastIfSpeedScoreLow();
          if (this.currentTest == 3)
          {
            var testLength = data[1] - this.testStartTime;

            $("#benchmarkTime", context)[0].completionTime = "<%= i18n.completionTime %>".format(Math.floor(testLength / 60), testLength % 60);
          }
          else
          {
            this.UpdateGraph(this.currentTest);
            $(graphConfigs[this.currentTest].domTag, context)[0].setLoading(false);
            this.currentTest++;
          }
          break;
      }

      return -1;
    }

    UpdateGraph(graphIndex = -2)
    {
      graphMan.UpdateGraph(graphIndex);
    }

    ClearGraphs()
    {
      this.lastUpdate = -1;
      this.currentTest = 0;
      this.testStartTime = 0;
      this.minMaxTimes.fill(-1);
      this.downloadCounter = 0;
      this.upDiff = 0;
      this.preDownTime = 0;
      canShow_ForceTooltips.fill(false);

      $("#benchmarkTime", context)[0].completionTime = "";
      $("#benchmarkTime", context)[0].testTime = "";

      $(graphConfigs[0].ratingTag, context)[0].reset();
      $(graphConfigs[1].ratingTag, context)[0].reset();
      $(graphConfigs[2].ratingTag, context)[0].reset();

      graphMan.ClearGraphs();
    }

    SetLoading(value)
    {
      $("#runTestDialogButton", context)[0].disabled = value;
      for (var i = 0; i < graphConfigs.length; i++)
        $(graphConfigs[i].domTag, context)[0].setLoading(value);
    }

    AllowLowSpeedToast(state){
      this.lowSpeedToast = state;
    }
  }

  class GraphManager
  {
    constructor()
    {
      // Init arrays to track data
      var targetCount = Object.keys(graphTargets).length;
      this.dataArrays = new Array(targetCount);
      this.bufferedDataArrays = new Array(targetCount);
      this.startTimes = new Array(targetCount);
      this.maxBase    = new Array(graphConfigs.length);
      
      for (var i = 0; i < targetCount; i++)
      {
        this.dataArrays[i] = [];
        this.bufferedDataArrays[i] = [];
        this.startTimes[i] = -1;
        if (i < graphConfigs.length)
          this.maxBase[i] = 0;
      }

      // Get user colour themes
      let cgen = getColourGenerator();
      let colours = [cgen(), cgen(), cgen()];

      // Inititalise each graph from config
      for (var i = 0; i < graphConfigs.length; i++)
        this.SetupConfig(graphConfigs[i], colours);
    }

    SetupConfig(config, colours)
    {
      var dom = $(config.domTag, context);
      dom.prop(
      {
        graphTitle:  config.title,
        summaryInfo: config.summaryInfo,
      });

      var graph = $(config.htmlTag, context);      
      
      var yAxis =
      [
        {
          id: `left`,
          ticks:
          {
            beginAtZero: true,
            callback: (val) => (config.YAxisTickFormat == null) ? val : config.YAxisTickFormat(this, val),
            maxTicksLimit: 5,
            suggestedMin: 0,
            suggestedMax: 20,
          },
          scaleLabel:
          {
            display: true,
            labelString: config.YAxisLabel,
          },
        }
      ];

      if (config.EnableRightAxis)
        yAxis.push(
        {
          id: `right`,
          position: `right`,
          ticks:
          {
            display: false,
            beginAtZero: true,
            min: 0,
            max: 100,
            maxTicksLimit: 3,
            callback: (val) => `${val.toFixed(2)}%`,
          },
          scaleLabel:
          {
            display: false,
          },
        });

      graph.prop("options",
      {
        tooltips:
        {
          custom: function( tooltip ) {
            otherTooltip_HideForceTooltips = tooltip.opacity > 0;
          },
          callbacks:
          {
            label: config.LabelFormat,
            title: function() {} //(tooltipItem, data) => (tooltipItem[0].xLabel / 1000).toFixed(2) + 's',
          },
        },
        legend:
        {
          display: false,
        },
        scales:
        {
          xAxes:
          [
            {
              type: 'time',
              offset: false,
              display: false,
              distribution: 'linear',
              ticks:
              {
                source: "labels",
              },
              bounds: "ticks",
              scaleLabel:
              {
                display: false,
                labelString: config.XAxisLabel,
              },
            },
          ],

          yAxes: yAxis,
        },
          
        elements:
        {
          line:
          {
            tension: 0.1,
            fill: false,
          },
        },
      });

      var lineCount = config.config.length;
      var dataSets = new Array(lineCount);

      for (var i = 0; i < lineCount; i++)
      {
        var line = config.config[i];

        dataSets[i] =
        {
          borderColor: colours[line.ColourIndex],
          pointBackgroundColor: colours[line.ColourIndex],
          pointRadius: 0,
          pointHitRadius: 5,
          label: line.Label,
          data: this.dataArrays[line.DataIndex],
          type: line.Type,
          yAxisID: line.Axis,
          forceTooltipsOptions: {
            displayColors: false
          },
          barThickness: 1,
          maxBarThickness: 1,
        }
        if(line.LineDash) dataSets[i].borderDash = line.LineDash;
        if(line.forceTooltips) dataSets[i].forceTooltips = line.forceTooltips;
        if(line.minMax) dataSets[i].minMax = line.minMax;
        if(line.ariaValueFormatter) dataSets[i].ariaValueFormatter = line.ariaValueFormatter;
        if(line.ariaIgnoreDataset) dataSets[i].ariaIgnoreDataset = line.ariaIgnoreDataset;

        dom[0].setColour(i, colours[line.ColourIndex]);

        if (line.Fill)
          dataSets[i].backgroundColor = colours[line.ColourIndex]
      }

      graph.prop("data", 
      {
        labels: [],
        datasets: dataSets,
      });

      dom.prop("summaryInfo", config.summaryInfo);

      return graph;
    }

    // Push data into a graph and updates any dependant properties
    PushResult(time, value, dataIndex, graphIndex, updateAxisScale = true, startTimeRef = null, insertOverride = null)
    {
      var graphRef = $(graphConfigs[graphIndex].htmlTag, context)[0];

      if (startTimeRef == null)
        startTimeRef = dataIndex;

      if (this.startTimes[startTimeRef] == -1)
        this.startTimes[startTimeRef] = time;

      time -= this.startTimes[startTimeRef];

      if (updateAxisScale)
      {
        var base = GetUnits(value)[1];
        if (this.maxBase[graphIndex] < base)
        {
          this.maxBase[graphIndex] = base;
          if (graphConfigs[graphIndex].YAxisAddUnit)
          {
            graphRef.options.scales.yAxes[0].scaleLabel.labelString = `${graphConfigs[graphIndex].YAxisLabel} (${unitsPS[base]})`;
            graphRef._updateOptions(); // Must forcibly update the options
          }
        }
      }

      var dataPoint = {t: time * 1000, y: value}
      if(insertOverride || insertOverride === 0){
        dataPoint.insert = insertOverride;
      }
      this.bufferedDataArrays[dataIndex].push(dataPoint);
    }

    UpdateGraph(index = -2)
    {
      for (var i = 0; i < this.dataArrays.length; i++)
      {
        var arr = this.dataArrays[i];
        var buff = this.bufferedDataArrays[i];
        for(var b = 0; b < buff.length; b++){
          var val = buff[b];
          if(val.insert || val.insert === 0) arr.splice(val.insert,0,val);
          else arr.push(val);
        }
        buff.length = 0;
      }

      if (index == -2)
      {
        $(graphConfigs[0].htmlTag, context)[0].update();
        $(graphConfigs[1].htmlTag, context)[0].update();
        $(graphConfigs[2].htmlTag, context)[0].update();
      }
      else if (index >= 0)
        $(graphConfigs[index].htmlTag, context)[0].update();
    }

    ClearGraphs()
    {
      for (var i = 0; i < this.startTimes.length; i++)
        this.startTimes[i] = -1;

      for (var i = 0; i < this.dataArrays.length; i++)
      {
        this.dataArrays[i].length = 0;
        this.bufferedDataArrays[i].length = 0;
      }

      for (var i = 0; i < graphConfigs.length; i++)
        for (var ii = 0; ii < 3; ii++)
          $(graphConfigs[i].domTag, context)[0].setResult(ii, "-");
    }
  }

  function setBandwidthSpeeds(upload,download){
    upload = upload * 1000;
    download = download * 1000;
    $("#benchmarkHistory", context)[0].SetSpeeds(upload,download);
    this.downloadSpeed = download || this.downloadSpeed;
    this.uploadSpeed = upload || this.uploadSpeed;
  }

  var packageId = "com.netdumasoftware.benchmark";

  function set_tooltips_show_state(state){
    state = (state === true || state === "true") ? true : false;
    forceHide_ForceTooltips = !state;
    var checkbox = $("#showTooltips",context);
    checkbox.prop("checked", state);
    duma.storage(packageId,"show_tooltips",state);
    testProcessor.UpdateGraph();
  }
  function init_tooltips_show(){
    var init = duma.storage(packageId,"show_tooltips");
    if(!init || init === ""){
      init = "true";
    }
    set_tooltips_show_state(init === "true");
    $("#showTooltips",context).on("checked-changed",function(event){
      set_tooltips_show_state(event.detail.value);
    });
  }

  function openLowSpeedsToastIfSpeedScoreLow(){
    var rating = $("#speed-dom-graph duma-rating",context);
    if(rating[0]){
      var lowestRating = rating[0].thresholds.limits[0];
      if(rating[0].value < lowestRating.limit){
        openLowSpeedsToast();
      }
    }
  }

  function openLowSpeedsToast(){
    $("#low-speeds-toast",context)[0].open();
  }

  function InitTesting()
  {
    graphMan = new GraphManager();
    testProcessor = new TestProcessor(graphMan);

    $("#benchmarkHistory", context).prop("testProcessor", testProcessor);

    //clicking the button in the toast should open the network speeds dialog
    $("#openSpeeds", context).click(() => {
      $(top.document).find("#network-speeds")[0].open();
      $("#low-speeds-toast",context)[0].close();
    });

    // Bind start test button
    //TODO QOS temp removal
    $("#runTestButton", context).on("tap", testProcessor.StartTest.bind(testProcessor));
    $("#runTestDialogButton", context).on("tap", testProcessor.StartTest.bind(testProcessor));//$("#speed-test-dialog", context)[0].open());
    $("#cancelTestButton", context).on("tap", () => $("#speed-test-dialog", context)[0].close());

    // Delete tests buttons
    deleteAllTestsButton = $("#deleteAllTestsButton", context);
    deleteAllTestsButton.on("tap", () =>
    {
      deleteAllTestsButton.disabled = true;
      long_rpc_promise("com.netdumasoftware.benchmark","delete_all_tests",[]).done((result) =>
      {
        deleteAllTestsButton.disabled = false;
        $("#benchmarkHistory", context)[0].ReloadHistory();
      });
    });

    deleteFailedTestsButton = $("#deleteFailedTestsButton", context);
    deleteFailedTestsButton.on("tap", () =>
    {
      deleteFailedTestsButton.disabled = true;
      long_rpc_promise("com.netdumasoftware.benchmark","delete_all_failed_tests",[]).done((result) =>
      {
        deleteFailedTestsButton.disabled = false;
        $("#benchmarkHistory", context)[0].ReloadHistory();
      });
    });

    Q.spread([
      long_rpc_promise("com.netdumasoftware.config","isp_upload_speed",[]),
      long_rpc_promise("com.netdumasoftware.config","isp_download_speed",[]),
      long_rpc_promise("com.netdumasoftware.benchmark","get_scheduling_state",[]),
      $("#benchmarkHistory", context)[0].Init()
    ],function(upload,download,scheduleState){
      upload = parseInt(upload[0]);
      download = parseInt(download[0]);
      setBandwidthSpeeds.call(testProcessor,upload,download);
      
      var scheduleToggle = $("#schedule-toggle",context);
      scheduleToggle.prop("checked",scheduleState[0]);
      scheduleToggle.on("checked-changed",function(e){
        long_rpc_promise("com.netdumasoftware.benchmark","set_scheduling_state",[e.detail.value]).done()
      });

      $("duma-panel", context).prop("loaded", true);
    });

    $("html").on("network-speeds-changed",function(e){
      setBandwidthSpeeds.call(testProcessor,e.detail.up,e.detail.down);
    });

    var tabsContainer = $("#tab-switcher",context);
    var pages = tabsContainer.find("iron-pages")[0];
    tabsContainer.find("paper-tabs").on("selected-changed",function(e){
      pages.selected = e.detail.value;
    }).prop("selected",0);

    init_tooltips_show();
  }

  var panels = $("duma-panels", context)[0];

  function updatePanels()
  {
    InitTesting();

  }

  updatePanels();
})(this);

//# sourceURL=overview.js
