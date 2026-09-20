/*
 * (C) 2017 NETDUMA Software
 * Kian Cross
*/

(function (context) {

  var legendElem = $("duma-legend",context);
  var chartElem = $("#flash-usage-graph",context);

function capitaliseFirstLetter(text) {
  if (!text || text.length === 0) {
    return;
  }

  return text[0].toUpperCase() + text.substring(1);
}

function updateFlashUsage(flashUsage) {
  var labels = [];
  var data = [];
  var legend = [];

  var cgen = getColourGenerator();
  var colours = [];

  for( var i = 0; i < flashUsage.length; i++ ){
    var label = capitaliseFirstLetter(flashUsage[i].name )
    var colour = cgen();
    var size = flashUsage[i].size / ( 1024 * 1024 );
    size = Math.round( size * 10 ) / 10;

    labels.push(label );
    data.push( size );
    colours.push( colour );
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
      borderWidth: 0,	
    }]
  };

  chartElem.prop("data", graphData);
  legendElem.prop("legendStats", legend);
  
  $("duma-panel", context).prop("loaded", true);
}

start_cycle(function () {
  return [
    long_rpc_promise("com.netdumasoftware.systeminfo", "get_flash_info", [])
  ];
}, function (flash) {
  updateFlashUsage(flash[0]);

}, 1000 * 2);

chartElem[0].ariaValueFormatter = function(val){
  return "<%= i18n.valueFormat %>".format(val);
};
chartElem.prop("options", {
  ariaHeaders: ["<%= i18n.flashType %>", "<%= i18n.memory %>"],
  tooltips: {
    callbacks: {
      label: function(tx, ctx){
        return format_bytes(ctx.datasets[tx.datasetIndex].data[tx.index] * 1024 * 1024,1);
      }
    }
  },
  legend: {
    display: false
  },
});

legendElem[0].bindToChart(chartElem[0]);
})(this);

//@ sourceURL=flash-usage.js
