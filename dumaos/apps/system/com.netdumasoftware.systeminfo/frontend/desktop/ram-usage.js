/*
 * (C) 2017 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
*/

(function (context) {

function capitaliseFirstLetter(text) {
  if (text.length === 0) {
    return;
  }

  return text[0].toUpperCase() + text.substring(1);
}

function updateRamUsage( ram, total ) {
  var labels = [];
  var data = [];

  var generateColour = getColourGenerator();
  var backgroundColours = [];

  var total = 0;
  for( var i = 0; i < ram.length; i++) total += ram[i].size;

  for( var i = 0; i < ram.length; i++ ){
    // var size = ram[i].size / ( 1024 * 1024 );
    var size = (ram[i].size / total) * 100;
    size = Math.round( size * 10 ) / 10;

    labels.push( capitaliseFirstLetter(ram[i].name ));
    data.push( size );
    backgroundColours.push(generateColour());
  }



  var graphData = {
    labels: labels,
    datasets: [{
      data: data,
      backgroundColor: backgroundColours,
      borderWidth: 0
    }]
  };

  $("#ram-usage-graph", context).prop("data", graphData);
  
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

$("#ram-usage-graph", context).prop("options", {
  tooltips: {
    callbacks: {
      label: function(tx, ctx){
        return ctx.datasets[tx.datasetIndex].data[tx.index].toString() + "%";
      }
    }
  }
});

})(this);

//# sourceURL=ram-usage.js
