/*
 * (C) 2017 NETDUMA Software
 * Kian Cross
*/

(function (context) {

var legendElem = $("duma-legend",context);
var chartElem = $("#ram-usage-graph",context);

function capitaliseFirstLetter(text) {
  if (!text || text.length === 0) {
    return;
  }

  return text[0].toUpperCase() + text.substring(1);
}

function updateRamUsage( ram, total ) {
  var labels = [];
  var data = [];
  var legend = [];

  var cgen = getColourGenerator();
  var colours = [];

  var total = 0;
  for( var i = 0; i < ram.length; i++) total += ram[i].size;

  for( var i = 0; i < ram.length; i++ ){
    var colour = cgen();
    var label = capitaliseFirstLetter(ram[i].name );
    // var size = ram[i].size / ( 1024 * 1024 );
    var size = (ram[i].size / total) * 100;
    size = Math.round( size * 10 ) / 10;

    labels.push( label );
    data.push( size );
    colours.push(colour);
    legend.push({
      label: label,
      result: size,
      colour: colour,
      bgColour: colour,
      visible: true
    });
  }



  var graphData = {
    labels: labels,
    datasets: [{
      data: data,
      backgroundColor: colours,
      borderWidth: 0
    }]
  };

  chartElem.prop("data", graphData);
  legendElem.prop("legendStats", legend);
  
  $("duma-panel", context).prop("loaded", true);
}

start_cycle(function () {
  var packageId = "com.netdumasoftware.systeminfo";
  return [
    long_rpc_promise(packageId, "get_ram_info", []),
  ];
}, function (ram) {
  updateRamUsage(ram[0]);
}, 1000 * 2);

chartElem[0].ariaValueFormatter = function(val){
  return "<%= i18n.valueFormat %>".format(val);
};
chartElem.prop("options", {
  ariaHeaders: ["<%= i18n.ramType %>", "<%= i18n.memory %>"],
  tooltips: {
    callbacks: {
      label: function(tx, ctx){
        return "<%= i18n.valueFormat %>".format(ctx.datasets[tx.datasetIndex].data[tx.index]);
      }
    }
  },
  legend: {
    display: false
  },
});

legendElem[0].bindToChart(chartElem[0]);

})(this);

//# sourceURL=ram-usage.js
