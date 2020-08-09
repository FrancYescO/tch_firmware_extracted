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

function updateFlashUsage(flashUsage) {
  var labels = [];
  var data = [];
  var colours = [];
  var colourGenerator = getColourGenerator();

  for( var i = 0; i < flashUsage.length; i++ ){
    var size = flashUsage[i].size / ( 1024 * 1024 );
    size = Math.round( size * 10 ) / 10;

    labels.push( capitaliseFirstLetter(flashUsage[i].name ));
    data.push( size );
    colours.push( colourGenerator() );
  }

  var graphData = {
    labels: labels,
    datasets: [{
      data: data,
      backgroundColor: colours,
      borderWidth: 0,	
    }]
  };

  $("#flash-usage-graph", context).prop("data", graphData);
  
  $("duma-panel", context).prop("loaded", true);
}

start_cycle(function () {
  return [
    long_rpc_promise("com.netdumasoftware.systeminfo", "get_flash_info", [])
  ];
}, function (flash) {
  updateFlashUsage(flash[0]);

}, 1000 * 2);

})(this);

//@ sourceURL=flash-usage.js
