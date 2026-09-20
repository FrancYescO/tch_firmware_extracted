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
    Count: 8,
  }

  // Config to reduce work to add new graphs
  const graphConfigs = 
  [
    // Speed
    {
      title: "Speed Score",
      domTag: "#speed-dom-graph",
      ratingTag: "#speed-rating",

      summaryInfo:
      [
        {
          label: "Download",
          result: "-",
          colour: "FFFFFF",
          visible: true,
          bgColour: "",
        },
        {
          label: "Upload",
          result: "-",
          colour: "FFFFFF",
          visible: true,
          bgColour: "",
        },
        {
          label: "Netflix Speed",
          result: "-",
          colour: "FFFFFF",
          visible: false,
          bgColour: "",
          disableClick: true,
        }
      ],

      startIndex: 0,
      htmlTag: '#speed-graph',

      YAxisLabel: "Throughput",
      YAxisAddUnit: true,

      YAxisTickFormat: (graphMan, val) => Math.round(val / (1000 ** graphMan.maxBase[0])),

      LabelFormat: (tooltipItem, data) => data.datasets[tooltipItem.datasetIndex].label + ": " + FormatBytes(tooltipItem.yLabel, 1000),

      EnableRightAxis: false,

      config:
      [
        // Download
        {
          Label: 'Download',
          ColourIndex: 0,
          Fill: false,
          DataIndex: graphTargets.Download,
          Type: `line`,
          Axis: `left`,
        },

        // Upload
        {
          Label: 'Upload',
          ColourIndex: 1,
          Fill: false,
          DataIndex: graphTargets.Upload,
          Type: `line`,
          Axis: `left`,
        },
      ],
    },

    // Ping
    {
      title: "Ping Score",
      domTag: "#ping-dom-graph",
      ratingTag: "#ping-rating",

      summaryInfo:
      [
        {
          label: "Average Ping",
          result: "-",
          colour: "FFFFFF",
          visible: true,
          bgColour: "",
        },
        {
          label: "Jitter",
          result: "-",
          colour: "FFFFFF",
          visible: true,
          bgColour: "",
        },
        {
          label: "Packet Loss",
          result: "-",
          colour: "FFFFFF",
          visible: true,
          bgColour: "FFFFFF",
        }
      ],

      startIndex: 2,
      htmlTag: '#ping-graph',

      YAxisLabel: "Ping (ms)",
      YAxisAddUnit: false,

      YAxisTickFormat: null,

      LabelFormat: (tooltipItem, data) => `${data.datasets[tooltipItem.datasetIndex].label}: ${tooltipItem.yLabel.toFixed(2)}ms`,
      EnableRightAxis: true,


      config:
      [
        // Ping
        {
          Label: 'Average Ping',
          ColourIndex: 0,
          Fill: false,
          DataIndex: graphTargets.Ping,
          Type: `line`,
          Axis: `left`,
        },

        // Jitter
        {
          Label: 'Jitter',
          ColourIndex: 1,
          Fill: false,
          DataIndex: graphTargets.Jitter,
          Type: `line`,
          Axis: `left`,
        },

        // Packet Loss
        {
          Label: 'Packet Loss',
          ColourIndex: 0,
          Fill: true,
          DataIndex: graphTargets.PacketLoss,
          Type: `bar`,
          Axis: `right`,
        },
      ],
    },

    // Bloat
    {
      title: "Ping Test (Under Load)",
      domTag: "#bloat-dom-graph",
      ratingTag: "#bloat-rating",

      summaryInfo:
      [
        {
          label: "Download",
          result: "-",
          colour: "FFFFFF",
          visible: true,
          bgColour: "",
        },
        {
          label: "Upload",
          result: "-",
          colour: "FFFFFF",
          visible: true,
          bgColour: "",
        },
        {
          label: "Idle",
          result: "-",
          colour: "FFFFFF",
          visible: true,
          bgColour: "",
        }
      ],

      startIndex: 5,
      htmlTag: '#bloat-graph',

      YAxisLabel: "Bufferbloat (ms)",
      YAxisAddUnit: false,

      YAxisTickFormat: null,

      LabelFormat: (tooltipItem, data) => `${data.datasets[tooltipItem.datasetIndex].label}: ${tooltipItem.yLabel.toFixed(2)}ms`,
      EnableRightAxis: false,

      config:
      [
        // Download
        {
          Label: 'Download',
          ColourIndex: 0,
          Fill: false,
          DataIndex: graphTargets.BloatDownload,
          Type: `line`,
          Axis: `left`,
        },

        // Upload
        {
          Label: 'Upload',
          ColourIndex: 1,
          Fill: false,
          DataIndex: graphTargets.BloatUpload,
          Type: `line`,
          Axis: `left`,
        },

        // Idle
        {
          Label: 'Idle',
          ColourIndex: 2,
          Fill: false,
          DataIndex: graphTargets.BloatIdle,
          Type: `line`,
          Axis: `left`,
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
    }

    StartTest()
    {
      $("#runTestDialogButton", context)[0].disabled = true;
      $("#testRunningSpinnerWrapper", context).show();
      $("#speed-test-dialog", context)[0].close();

      this.ClearGraphs();
      this.UpdateGraph();

      this.websocket = new WebSocket("ws://" + document.domain + ":8081", "benchmark");
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
      console.log("Close: ", event);
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
              return [0, false];
            
            // Average upload
            case 1:
              var cleanResultText = FormatBytes(data[2] * 1000, 1000);
              $(graphConfigs[0].domTag, context)[0].setResult(1, cleanResultText);
              $(graphConfigs[0].ratingTag, context)[0].uploadSpeed = data[2];
              $(graphConfigs[0].ratingTag, context)[0].tooltip.line1 = cleanResultText;
              return [0, true];

            // Download data
            case 2:
              this.graphMan.PushResult(data[3], data[2] * 1000, graphTargets.Download, 0);
              return [0, false];

            // Average download
            case 3:
              var cleanResultText = FormatBytes(data[2] * 1000, 1000);
              $(graphConfigs[0].domTag, context)[0].setResult(0, cleanResultText);
              var rating = $(graphConfigs[0].ratingTag, context)[0];
              rating.setRating(rating.uploadSpeed / this.uploadSpeed, data[2] / this.downloadSpeed)

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
              rating.setRating(rating.ping, rating.jitter, data[2]);

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
              return [2, true];

            // Average bloat idle jitter
            case 2:
              console.log("Average bloat idle jitter: ", data[2]);
              break;

            // Bloat upload data
            case 3:
              this.graphMan.PushResult(data[4], data[2], graphTargets.BloatUpload, 2);
              return [2, false];

            // Average bloat upload
            case 4:
              $(graphConfigs[2].domTag, context)[0].setResult(1, data[2].toFixed(2) + "ms");
              $(graphConfigs[2].ratingTag, context)[0].bloatUp = data[2];
              return [2, true];

            // Average bloat upload jitter
            case 5:
              console.log("Average bloat upload jitter: ", data[2]);
              break;

            // Bloat download data
            case 6:
              this.graphMan.PushResult(data[4], data[2], graphTargets.BloatDownload, 2);
              $(graphConfigs[2].ratingTag, context)[0].bloatDown = data[2];
              return [2, false];

            // Average bloat download
            case 7:
              $(graphConfigs[2].domTag, context)[0].setResult(0, data[2].toFixed(2) + "ms");
              var rating = $(graphConfigs[2].ratingTag, context)[0];
              rating.setRating(rating.bloatUp, rating.bloatDown, data[2]);
              return [2, true];

            // Average bloat download jitter
            case 8:
              console.log("Average bloat download jitter: ", data[2]);
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
          $(graphConfigs[0].htmlTag, context)[0].chart.config.options.scales.xAxes[0].time.max = data[1] * 1000;
          $(graphConfigs[1].htmlTag, context)[0].chart.config.options.scales.xAxes[0].time.max = data[2] * 1000;
          $(graphConfigs[2].htmlTag, context)[0].chart.config.options.scales.xAxes[0].time.max = data[3] * 1000;
          this.testStartTime = data[4];

          var dateTime = new Date(this.testStartTime * 1000);
          $("#benchmarkTime", context)[0].testTime = dateTime.toLocaleDateString([], {day: '2-digit', month: 'short', year: '2-digit'}) + " - " +
                                                     dateTime.toLocaleTimeString([], {hour12: false, hour: '2-digit', minute:'2-digit'});
          break;

        // Test end
        case 999:
          if (this.currentTest == 3)
          {
            var testLength = data[1] - this.testStartTime;

            $("#benchmarkTime", context)[0].completionTime = Math.floor(testLength / 60) + "m " + (testLength % 60) + "s";
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
  }

  class GraphManager
  {
    constructor()
    {
      // Init arrays to track data
      this.dataArrays = new Array(graphTargets.Count);
      this.bufferedDataArrays = new Array(graphTargets.Count);
      this.startTimes = new Array(graphTargets.Count);
      this.maxBase    = new Array(graphConfigs.length);
      
      for (var i = 0; i < graphTargets.Count; i++)
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
          callbacks:
          {
            label: config.LabelFormat,
            title: (tooltipItem, data) => (tooltipItem[0].xLabel / 1000).toFixed(2) + 's',
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
              barThickness: 1,
              maxBarThickness: 1,
              ticks:
              {
                source: "labels",
              },
              bounds: "ticks",
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
        }

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
    PushResult(time, value, dataIndex, graphIndex, updateAxisScale = true, startTimeRef = null)
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

      this.bufferedDataArrays[dataIndex].push({t: time * 1000, y: value});
    }

    UpdateGraph(index = -2)
    {
      for (var i = 0; i < this.dataArrays.length; i++)
      {
        Array.prototype.push.apply(this.dataArrays[i], this.bufferedDataArrays[i]);
        this.bufferedDataArrays[i].length = 0;
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


  var packageId = "com.netdumasoftware.benchmark";  

  function InitTesting()
  {
    graphMan = new GraphManager();
    testProcessor = new TestProcessor(graphMan);

    $("#benchmarkHistory", context).prop("testProcessor", testProcessor);

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

    long_rpc_promise("com.netdumasoftware.qos","get_bandwidth",[]).done(function (result)
    {
      $("#benchmarkHistory", context)[0].Init(result);
      this.downloadSpeed = result[0] / 1000;
      this.uploadSpeed = result[1] / 1000;
    }.bind(testProcessor));
  }

  var panels = $("duma-panels", context)[0];

  function updatePanels()
  {
    InitTesting();

    $("duma-panel", context).prop("loaded", true);
  }

  updatePanels();
})(this);

//# sourceURL=overview.js
