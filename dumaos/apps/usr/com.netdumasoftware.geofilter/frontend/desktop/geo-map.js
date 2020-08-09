/*
 * (C) 2016 NETDUMA Software
 * Kian Cross <kian.cross@netduma.com>
 * Iain Fraser <iainf@netduma.com>
*/

(function (context) {

var geoMapLoaderDialog = $("#geo-map-loader-dialog", context)[0];

var idleTime = 1000 * 60 * 2; // milliseconds
var milesInKm = 0.621371;
var g_conntrack_alive;
var g_clusters;
var hosts = {};

/* Icon mappings */
var dedi_icons = [];
var peer_icons = [];

dedi_icons[geoFilter.constants.GEO_CSTATE_VERDICT_NO] = "server";
dedi_icons[geoFilter.constants.GEO_CSTATE_VERDICT_WDIST] = "server";
dedi_icons[geoFilter.constants.GEO_CSTATE_VERDICT_BDIST] = "server-blocked";
dedi_icons[geoFilter.constants.GEO_CSTATE_VERDICT_RTT] = "server-ping-assist";
dedi_icons[geoFilter.constants.GEO_CSTATE_VERDICT_WHITELIST] = "server-whitelisted";
dedi_icons[geoFilter.constants.GEO_CSTATE_VERDICT_BAN] = "server-blacklisted";
dedi_icons[geoFilter.constants.GEO_CSTATE_VERDICT_ALLOW] = "server-whitelisted";

peer_icons[geoFilter.constants.GEO_CSTATE_VERDICT_NO] = "peer";
peer_icons[geoFilter.constants.GEO_CSTATE_VERDICT_WDIST] = "peer";
peer_icons[geoFilter.constants.GEO_CSTATE_VERDICT_BDIST] = "peer-blocked";
peer_icons[geoFilter.constants.GEO_CSTATE_VERDICT_RTT] = "peer-ping-assist";
peer_icons[geoFilter.constants.GEO_CSTATE_VERDICT_USER_ALLOW] = "peer-whitelisted";
peer_icons[geoFilter.constants.GEO_CSTATE_VERDICT_USER_DENY] = "peer-blacklisted";

var host_icons = [ peer_icons, dedi_icons ];

function category_key( type, verdict ){
  return "host_" + type + "_" + verdict;
}

function class_to_key( c ){
  var t = ( c >> geoFilter.constants.TYPE_SHIFT ) & 0x1;
  var c = ( c >> geoFilter.constants.VERDICT_SHIFT ) & 0x7;
  return category_key( t, c );
}

function displayHosts() {

  var geo = $("duma-map", context)[0];
  geo.beginScene();
  for (var ip in hosts) {
    var coord = hosts[ip].coord;
    var sampler = hosts[ip].sampler;    // sampler should have size and also accumlate data
    var rate = hosts[ip].rate;
    var n = sampler_circular_array_size( sampler );
    var mag

    if( typeof( rate ) !== 'undefined'){
      mag = rate;
    } else if( n > 1 ){
      mag = sampler_moving_average( sampler );
    }
    
    if( typeof( mag ) !== 'undefined'  && typeof( coord ) == "object" ){
      var key = class_to_key( hosts[ip].class );
      geo.touchPoint( key, ip, coord.lat, coord.lng, mag );
    }
  }
  geo.endScene();
}

function cycle_end(processedHosts) {
  hosts = processedHosts;

  var is_dash = $("duma-panel",context).prop("desktop");

  displayHosts();
}


function startConnectionProcessing() {
  geoFilter.startConnectionProcessor(cycle_end);
}


function save_cookie( x, y ){
  /* TODO: move to api */
}


var zoomfactor = 2.5;
var is_zoomed = false;

function do_more_zoom( x, y, k, width, height ){
  var dims = $("duma-map",context)[0].__getDims();
  var t = svg_translate( dims[0], dims[1] ) + svg_scale( k )  + svg_translate( -x, -y ); 

   d3.select(context).select("#zoomg").transition()
      .duration(750)
      .attr("transform",t);

/*  doing_zoom = true;
  d3.selectAll(".hostobj").transition()
    .duration(750)
    .attr("transform", world_host_zoom_transform )
    .call( endall, function(){
      doing_zoom = false; 
    }); */
  
}


function do_zoom( mx, my, projection, width, height, dont_set_cursor  ){
  var scalefactor = zoomfactor;
  var dm = $("duma-map", context)[0];

  duma.storage(geoFilter.getPackageId(), "zoomx", mx / width );
  duma.storage(geoFilter.getPackageId(), "zoomy", my / height );
  duma.storage(geoFilter.getPackageId(), "zoomon", !is_zoomed );
  var dims = dm.__getDims();
  var x,y, k;
  if( is_zoomed ){
    x = dims[0];
    y = dims[1];
    k = 1;
    if(!dont_set_cursor)
      removeMapClass("zoomed-cursor");
  } else {
    /* bound check */
    var l = projection.invert( [mx,my] );
    var lng = l[0];
    var lat = l[1];

    if( lat < -90 || lat > 90 ) return;
    if( lng < -180 || lng > 180 ) return;

    x = mx;
    y = my;
    zoom_x = mx;
    zoom_y = my;
    k = scalefactor;
    if(!dont_set_cursor)
      setMapClass("zoomed-cursor");
  }
  is_zoomed = !is_zoomed;
  dm.zoomfactor = k;
  dm.zoomx = x;
  dm.zoomy = y;
  do_more_zoom( x, y, k, width, height );
}

function clampto(input,minMax){
  return Math.max(0-minMax,Math.min(minMax, input));
}

function map_to_lat_long(x,y,projection,width,height){
  var scalefactor = zoomfactor;
  
  loc = projection.invert( [x,y] );
  
  var lng = loc[0];
  var lat = loc[1];

  var flng = clampto(Math.round( lng ), 180);
  var flat = clampto(Math.round( lat ), 90);

  return [flat,flng];
}
function lat_long_to_map(lat,lng,projection){
  var scalefactor = zoomfactor;

  loc = projection( [lng,lat] );

  return loc;
}

function set_home( mx, my, projection, width, height ){
  var dm = $("duma-map", context)[0];

  var f = map_to_lat_long(mx,my,projection,width,height);
  var flat = f[0];
  var flng = f[1];

  if( flat < -90 || flat > 90 ) return;
  if( flng < -180 || flng > 180 ) return;


  var promise = long_rpc_promise(geoFilter.getPackageId(), "home", [1, flat, flng ]);
  geoFilter.showLoaderDialog(geoMapLoaderDialog, promise);
  promise.done(function () {
    dm.home[0] = flat; 
    dm.home[1] = flng;
    dm._distance_change();    // force redraw
  });
}

function addPolygon(open) {
  var map = $("duma-map", context)[0];

  if (open) {
    map.startDrawingPolygons();
  } else {
    map.stopDrawingPolygons();
  }
}

function save_polygons(){
  console.log("Saving polygons");
  var map = $("duma-map", context)[0];
  var projection = map.__makeProjection();
  var polygons_raw = $(map).find("#polygons polygon");
  var all_polygons = {
    n_polygons: 0,
    polygons: []
  };
  polygons_raw.each(function(index,element) {
    var polygon = {
      n_points: 0,
      points: []
    };
    var points_raw = $(element).prop("points");
    if(points_raw !== undefined && points_raw !== null && points_raw.length > 0){
      all_polygons.n_polygons++;
      for(var i = 0; i < points_raw.length; i ++ ){
        var point = points_raw[i];
        var f = map_to_lat_long(point.x,point.y,projection,map.width,map.height);

        polygon.n_points++;
        polygon.points.push({
          lng: f[0],
          lat: f[1]
        });
      }
      all_polygons.polygons.push(polygon);
    }
  });
  long_rpc_promise("com.netdumasoftware.geofilter","save_polygons",[1,"polygon",all_polygons]).done(function(filename){ 
    console.log("Saved")
  });
  updatePolygonCount();
}

function updatePolygonCount(){
  var map = $("duma-map", context)[0];
  var counter = $("#polygon-count",context);
  var textCounter = $("#polygon-text-count",context);
  if(counter[0] && textCounter[0]){
    var max = 50;
    var count = 0;
    var polygons_raw = $(map).find("#polygons .points");
    polygons_raw.each(function(index,element) {
      count += element.childNodes.length;
    });
    counter[0].max = max;
    counter[0].value = count;
    map.polygonMax = max;
    map.polygonCount = count;
    textCounter.text(max - count);
  }
}

function deletePolygon(open) {
  var map = $("duma-map", context)[0];

  if (open) {
    map.startDeletingPolygons();
  } else {
    map.stopDeletingPolygons();
  }
}

/*
* Map click state machine
*/


var g_map_buttons = {
  "#zoom" : {
    "icon" : "zoom-in",
    "handler" : do_zoom,
    "autoclose" : false,
    "class" : "zoom-cursor"
  },
  "#home" : {
    "icon" : "maps:person-pin-circle",
    "handler" : set_home,
    "autoclose" : true,
    "class" : "home-cursor"
  },
  "#add-polygon" : {
    "icon" : "editor:mode-edit",
    "onClick" : addPolygon,
    "autoclose" : false,
    "class" : "add-polygon-cursor"
  },
  "#delete-polygon" : {
    "icon" : "icons:delete-forever",
    "onClick" : deletePolygon,
    "autoclose" : false,
    "class" : "delete-polygon-cursor"
  }
};

function resetMapClass() {
  for (var icon in g_map_buttons) {
    if (g_map_buttons.hasOwnProperty(icon)) {
      removeMapClass(g_map_buttons[icon].class);
    }
  }
  removeMapClass("zoomed-cursor");
}

function setMapClass(mapClass) {
  $("duma-map", context).addClass(mapClass);
}
function removeMapClass(mapClass) {
  $("duma-map", context).removeClass(mapClass);
}


function mapclick_get_selected(){
  for( var id in g_map_buttons ){
    if( $(id, context).prop("icon") == "close" )
      return g_map_buttons[id];
  }
  return false;
}

function mapclick_get_handler(){
  var e = mapclick_get_selected()
  var nop = function(){} 

  if (e && typeof e.handler === "function") {
    return e.handler;
  } else {
    return nop;
  }
}

function mapclick_auto_cancel(force=false){
  var e = mapclick_get_selected();
  if(!force && e && !e.autoclose ) return;

  for( var id in g_map_buttons ){
    $(id, context).prop("disabled", false );
    $(id, context).prop("icon", g_map_buttons[id].icon );
  }

  resetMapClass();
}

function mapclick_init(){
  for( var id in g_map_buttons ){
    var entry = g_map_buttons[id];

    function create_closure( id, entry ){
      return function(){
        for( var fid in g_map_buttons ){
          if( id == fid ) continue;
          var other = $(fid);
          var otherEntry = g_map_buttons[fid];
          // $( fid ).prop("disabled", is_open_state );
          var other_open_state = other.prop("icon") == otherEntry.icon;
          if(!other_open_state){
            if(typeof otherEntry.onClick === "function"){
              otherEntry.onClick(other_open_state);
            }
            other.prop("icon",otherEntry.icon);
            resetMapClass();
          }
        }
        var is_open_state = $(this).prop("icon") == entry.icon 
        $(this).prop("icon", is_open_state ? "close" : entry.icon ); 
        
        if( is_open_state ){
          if( id === "#zoom" && is_zoomed)
            setMapClass("zoomed-cursor")
          setMapClass( entry.class );
        }else
          resetMapClass();
        
        if (typeof entry.onClick === "function") {
          entry.onClick(is_open_state);
        }
        
      }
    }

    $(id).click( create_closure( id, entry ) );
  }
}

function setDistance(value) {
  if ($("#distance-unit", context).prop("selected") == "miles") {
    value = value * milesInKm;
    duma.storage(geoFilter.getPackageId(), "distanceUnit", "miles");
  } else {
    duma.storage(geoFilter.getPackageId(), "distanceUnit", "km");
  }

  $("#distance-slider", context).prop("value", Math.round(value));
}

function getDistance() {
  var value = $("#distance-slider", context).prop("immediateValue");
  if (duma.storage(geoFilter.getPackageId(), "distanceUnit") === "miles") {
    value = value * (1 / milesInKm);
  }

  return Math.round(value);
}

function changeDistanceUnit(miles) {
  var min = 111;
  var max = 20037;
  var value = $("#distance-slider", context).prop("value");

  if (miles) {
    min = min * milesInKm;
    max = max * milesInKm;

    if (duma.storage(geoFilter.getPackageId(), "distanceUnit") === "km") {
      value = value * milesInKm;
    }

    duma.storage(geoFilter.getPackageId(), "distanceUnit", "miles");
    $("#geo-unit", context).text("<%= i18n.milesUnit %>");

  } else {
    if (duma.storage(geoFilter.getPackageId(), "distanceUnit") === "miles") {
      value = value * (1 / milesInKm);
    }
    
    duma.storage(geoFilter.getPackageId(), "distanceUnit", "km");
    $("#geo-unit", context).text("<%= i18n.kmUnit %>");
  }

  if (value < min) {
    value = min;
  }

  if (value > max) {
    value = max;
  }

  $("#distance-slider", context).prop("max", Math.round(max));
  $("#distance-slider", context).prop("value", Math.round(value));
  $("#distance-slider", context).prop("min", Math.round(min));
}

function pollCloudReady() {
  long_rpc_promise(geoFilter.getPackageId(), "cloud_ready", [])
    .then(function (ready) {
      if (JSON.parse(ready)) {
        $("paper-toast", context)[0].close();
      } else {
        $("paper-toast", context)[0].open();
      }
    }).done();
}

function getZoomDropdown() {
  return Polymer.dom($("#zoomf", context)[0]).querySelector(".dropdown-content");
}

function setZoomDropdownValue( val ){
  var zdp = getZoomDropdown();
  zdp.selected = 0; 
  for( var i = 0; i < zdp.items.length; i++ ){
    var itemVal = Number( zdp.items[i].getAttribute("value") );
    if( itemVal == zoomfactor ){
      zdp.selected = i;
      break;
    }
  }
}

function onAutoPingPanelClose() {
  $("#auto-ping", context).prop("checked", false);
  duma.storage(
    geoFilter.getPackageId(), "autoping",
    false
  );
}

function onAutoPingChange() {
  duma.storage(
    geoFilter.getPackageId(), "autoping",
    $("#auto-ping", context).prop("checked")
  );

  if (!$("duma-panel", context).prop("desktop")) {
    if ($("#auto-ping", context).prop("checked")) {
      geoFilter.addPingGraph(null, onAutoPingPanelClose);
    } else {
      geoFilter.removePingGraph();
    }
  }
}

function loadSavedValues() {
  var distanceUnit = duma.storage(geoFilter.getPackageId(), "distanceUnit");
  distanceUnit = distanceUnit ? distanceUnit : "km";

  var autoping = duma.storage(geoFilter.getPackageId(), "autoping" );
  if( autoping ){
    autoping = JSON.parse( autoping );
  } else {
    autoping = true;
    duma.storage(geoFilter.getPackageId(), "autoping", true );
  }

  $("#distance-unit", context).prop("selected", distanceUnit);
  $("#auto-ping", context).prop("checked", autoping );

  $("#auto-ping", context).on("change", onAutoPingChange);
  onAutoPingChange();

  zoomfactor = duma.storage(geoFilter.getPackageId(), "zoomfactor" );
  zoomfactor = zoomfactor ? JSON.parse( zoomfactor ) : 2.5;
  setZoomDropdownValue( zoomfactor );
  $("#zoomf", context).on("iron-select", function(){ 
    zoomfactor = Number( $("#zoomf", context ).val() );
    duma.storage(geoFilter.getPackageId(), "zoomfactor", zoomfactor );
  } );

  var rx = duma.storage(geoFilter.getPackageId(), "zoomx" );
  var ry = duma.storage(geoFilter.getPackageId(), "zoomy" );
  var zoomon = duma.storage(geoFilter.getPackageId(), "zoomon" );
  zoomon = zoomon ? JSON.parse( zoomon ) : false;
  if( zoomon ){
    var details = $("duma-map",context)[0].get_zoom_info();
    var mx = parseFloat( rx ) * details.width;
    var my = parseFloat( ry ) * details.height;
    do_zoom( mx, my, details.projection, details.width, details.height , true); 
  }

}

function on_profile_click(){
  $("geofilter-device-selector", context)[0].open(function (device, service, profile) {
    var profile = service.profile;
    var distance;
    var strict;
    var geo = $("duma-map", context)[0]; 

    if( !profile ){   // unsupported game
      profile = {
        distance : 20037
      };
    }

    if( profile.hasOwnProperty('distance') ){
      distance = profile.distance;
    }

    if( profile.hasOwnProperty('snap') ){
      var home = geo.home;
      var lat = home[0];
      var lng = home[1];
      var distance = 111;    
      for( var i = 0; i < profile.snap; i++ )
        distance = calculate_snap( g_clusters, distance, lng, lat );
    }
    
    if( profile.hasOwnProperty('strict') ){
      strict = profile.strict;
    }

    var promises = [];
    if( distance !== null ){
      distance = Math.round( distance );
      promises.push( 
        long_rpc_promise(geoFilter.getPackageId(), "distance", [1,distance]) );
    }
    
    if( strict !== null ){
      promises.push( 
        long_rpc_promise(geoFilter.getPackageId(), "strict", [1, JSON.stringify( strict )]) );
    }

    if( promises.length > 0 ){
      var p = Q.all( promises ).spread( function(){
        if( distance !== null ){
          setDistance( distance );
          geo.distance = distance;
        }
        
        if( strict !== null ){
          $("#strict-mode", context).prop("checked", strict);
        }
      });

      geoFilter.showLoaderDialog(geoMapLoaderDialog, p);
    } 
  });

  $("geofilter-device-selector", context)[0]._selectedPageIndex = 1;
  $("geofilter-device-selector", context)[0].tags = [ "gfprofile" ];
  $("geofilter-device-selector", context)[0].header = "<%= i18n.profileSelector %>";
}
function changeFilteringMode(circle) {
  var map = $("duma-map", context)[0]
  if (circle) {
    $("#home",context).show();
    $("#add-polygon",context).hide();
    $("#delete-polygon",context).hide();
    $("#zoomg > #radial",context).show();
    $("#zoomg > #polygons",context).hide();
    console.log("Changing mode to Radius");
    long_rpc_promise(geoFilter.getPackageId(), "mode", [1, 0]);
    map.stopDrawingPolygons();
    map.stopDeletingPolygons();
    mapclick_auto_cancel(true);
  } else {
    $("#home",context).hide();
    $("#add-polygon",context).show();
    $("#delete-polygon",context).show();
    $("#zoomg > #radial",context).hide();
    $("#zoomg > #polygons",context).show();
    console.log("Changing mode to polygon filtering");
    long_rpc_promise(geoFilter.getPackageId(), "mode", [1, 1]);
    load_polygons();
  }
  $(".template-when-polygon",context).each(function(index,elem){elem.if = !circle;})
  $(".template-when-circle",context).each(function(index,elem){elem.if = !!circle;})
}


function load_polygons(filename="polygon.json"){
  long_rpc_promise(geoFilter.getPackageId(), "get_polygons",[filename]).done(function(raw){
    var data = JSON.parse(raw);
    reload_polygons(data);
  });
}
function reload_polygons(data){
  var map = $("duma-map", context)[0];
  var polygons = $("duma-map #polygons",context);
  polygons.empty();
  var projection = map.__makeProjection();
  for(var i = 0; data.polygons && i < data.polygons.length; i ++){
    var poly = data.polygons[i];
    var group = map._createPolygonGroup()
    map._setInProgressFixed(group);
    var svg_points = [];
    //var polys = $(group).find(".points");
    for(var p = 0; p < poly.points.length; p ++){
      var point = poly.points[p];
      var coords = lat_long_to_map(point.lng,point.lat,projection);
      svg_points.push( {x: coords[0], y: coords[1] });
    }
    for(var s = 0; s < svg_points.length; s ++){
      var start = svg_points[s];
      var end = svg_points[s + 1 < svg_points.length ? s + 1 : 0];
      map._drawPoint(group,start);
      map._drawLine(group, start, end);
    }
    map._showFill(group, svg_points);
  }
  if(!data.polygons || data.polygons.length === 0){
    $("#geofilter-duma-alert",context)[0].open("All designated traffic will be blocked until a shape is drawn. Please draw a shape to begin.");
  }
  updatePolygonCount();
}

/*
* Initalization and cleanup
*/

function initialise(e, data) {
  var is_dash = $("duma-panel", context).prop("desktop");
  var rpc_dist = create_rate_limit_long_rpc_promise( 
                                      geoFilter.getPackageId(), "distance", 1000 );
  
  var pingAssistRpc = create_rate_limit_long_rpc_promise( 
    geoFilter.getPackageId(), "pingass", 1000
  );

  loadSavedValues();

  $("#flush-cloud", context).prop("hidden", is_dash );
  $("#auto-ping", context).prop("disabled", is_dash );

  Q.spread([
    long_rpc_promise(geoFilter.getPackageId(), "get_all", []),
    long_rpc_promise(geoFilter.getPackageId(), "conntrack_alive", []),
    safe_getJSON_promise( "/json/clusters.json?cache=0" ),
    long_rpc_promise(geoFilter.getPackageId(), "mode", [1,null]),
    geoFilter.initialisationPromise,
  ], function (geoFilters, conntrack_alive, clusters, mode ) {

    geoFilters = JSON.parse( geoFilters[0] );
    g_conntrack_alive = JSON.parse( conntrack_alive );
    g_clusters = clusters;
    var filter = geoFilters[1];
    changeDistanceUnit($("#distance-unit", context).prop("selected") == "miles");
    setDistance(filter.radius);
    $("#strict-mode", context).prop("checked", filter.strict);
    $("#allow-false-positives", context).prop("checked", filter.rwd);
    $("#ping-assist", context).prop("value", filter.rtt);

    var geo = $("duma-map", context)[0]; 

    geo.home = [ filter.lat, filter.lng ];
    geo.distance = filter.radius;

    
    /* add categories */
    for( var i = 0; i < host_icons.length; i++ ){
      var hicons = host_icons[i];
      for( var j = 0; j < hicons.length; j++ ){
        var key = category_key( i, j );
        var imgpath = hicons[j];

        // js only has function scoping 
        function create_closure( path ){
          return function( s ){
            var svg = duma.svg.fromIconset("duma-icons:" + path);
            s.html(svg ? svg.innerHTML : "");
            s.attr("width", 20);
            s.attr("height", 20);
            s.select("g").classed("icon-content",true).attr("type", path);;
          }
        }

        var extra = { "width" : 20, "height" : 20 };        
        geo.addCategory( key, 5000, "g", create_closure( imgpath ), extra );
      }
    }

    $("#distance-slider", context).on("immediate-value-change change", function () {
      $("duma-map",context).prop("distance", getDistance());
    }).on("change", function () {

      var distance = getDistance();
      var promise = rpc_dist([1, distance]);
      geoFilter.showLoaderDialog(geoMapLoaderDialog, promise);
      promise.done(function () {
        if (distance > 3000 || distance < 500)  {
          $("#geofilter-duma-alert", context)[0].show(

            "<%= i18n.outsideRecommendedRangeWarning %>",

            [{ text: "<%= i18n.gotIt %>", action: "confirm" }],
            {
              enabled: true,
              packageId: geoFilter.getPackageId(),
              id: "geofilter-distance-warning"
            } 
          )
        }
      });
    });

    $("#distance-unit", context).on("iron-select", function () {
      changeDistanceUnit($(this).prop("selected") === "miles");
    });

    var filtering = $("#filtering-mode", context);
    var real_mode = JSON.parse(mode[0]).mode === 0 ? "circle" : "polygon";
    var real_bool = real_mode === "polygon";
    filtering.prop("checked",real_bool);
    changeFilteringMode(!real_bool);

    $("#filtering-mode", context).on("checked-changed", function () {
      changeFilteringMode(!this.checked);
    });
    $("duma-map", context).on('polygon-complete',function(group){
      save_polygons();
      updatePolygonCount();
    }.bind(this));
    $("duma-map", context).on('polygon-point-click',function(group){
      updatePolygonCount();
    }.bind(this));
    $("duma-map", context).on('polygon-cancel',function(group){
      updatePolygonCount();
    }.bind(this));
    $("duma-map", context).on('polygon-remove',function(group){
      save_polygons();
      updatePolygonCount();
    }.bind(this));

    $("#strict-mode", context).on("change", function () {
      var promise = long_rpc_promise(geoFilter.getPackageId(), "strict", [
        1, JSON.stringify( $(this).prop("checked") )
      ]);

      geoFilter.showLoaderDialog(geoMapLoaderDialog, promise);
      promise.done();
    });
    
    $("#ping-assist", context).on("change", function () {

      var value = $("#ping-assist",context).prop("value");
      var promise = pingAssistRpc([1, value]);

      geoFilter.showLoaderDialog(geoMapLoaderDialog, promise);

      promise.done(function () {
        if (value > 200)  {
          $("#geofilter-duma-alert", context)[0].show(

            "<%= i18n.pingAssistWarning %>",

            [{ text: "<%= i18n.gotIt %>", action: "confirm" }],
            {
              enabled: true,
              packageId: geoFilter.getPackageId(),
              id: "geofilter-ping-assist-warning"
            } 
          )
        }
      });
    });

    $("#allow-false-positives", context).on("change", function () {
      var promise = long_rpc_promise(geoFilter.getPackageId(), "rwd", [
        1, JSON.stringify($(this).prop("checked"))
      ]);

      geoFilter.showLoaderDialog(geoMapLoaderDialog, promise);
      promise.done();
    });

    /*
    * If not in mapclick mode e.g. zoom, homeset, etc then allow host 
    * selection.
    */
    var pingFrame;
    $("duma-map", context).on("hostclick", function( e, data ){
      var dialog_msg;

      if( $("duma-panel", context).prop("desktop") ){
        dialog_msg = "<%= i18n.dashboardPingError %>";
      }
      else if( JSON.parse( duma.storage(geoFilter.getPackageId(), "autoping" ) ) ){
        dialog_msg = "<%= i18n.autoPingPingError %>";
      }

      if( dialog_msg ){
        $("#geofilter-duma-alert", context)[0].show(
          dialog_msg, 
          [ { text : "<%= i18n.gotIt %>", action :"confirm" } ]
        );
        return;
      }

      if( !mapclick_get_selected()) {

        var host = hosts[data.key];

        geoFilter.addPingGraph({
          key: host.key,
          class: host.class
        });
      }
    });

    /*
    * Init mapclick state machine.
    */
    mapclick_init();
    $("duma-map", context).on("mapclick", function( jq ){
      var mx = jq.detail.mx;
      var my = jq.detail.my;
      var projection = jq.detail.projection;
      var width = this.width;
      var height = this.height;
      mapclick_get_handler()( mx, my, projection, width, height );
      mapclick_auto_cancel();
    });

    $("#flush-cloud", context).click(function () {
      /* this may take a while so pause engine or you'll get timeout errors */
      geoFilter.stopConnectionProcessor();

      var promise = long_rpc_promise(geoFilter.getPackageId(), "cloud_flush", []);
      geoFilter.showLoaderDialog(geoMapLoaderDialog, promise);
      promise.done( function(){
        startConnectionProcessing();
      });
    });

    $("#profiles", context).click( on_profile_click ); 

    pollCloudReady();
    setInterval(pollCloudReady, 1000 * 15);
    
    startConnectionProcessing();
      
    $("duma-panel", context).prop("loaded", true);
  }).done();
}

initialise();

})(this);

//# sourceURL=geo-map.js
