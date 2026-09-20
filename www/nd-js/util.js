/*
* (C) Iain Fraser - NetDuma
* Utility functions.
*/

function svg_2d( fn, x , y ){
  var out = fn + "(" + x;
  if( is_defined( y ) )
          out += "," + y;
  out += ")";
  return out;
}


function svg_translate( x, y ){
  return svg_2d( "translate", x, y );
}

function svg_scale( x, y ){
  return svg_2d( "scale", x, y ); 
}


/* Binary prefix's */
function binary_format( x ){
  // we remade this further down, so just use that one instead
  return format_binary(x);
}

function SI_suffix_format( x, suffix ){
  var prefix = d3.formatPrefix( x );

  if( prefix.symbol.length > 0 )
    return prefix.scale(x).toFixed(1) + " " + prefix.symbol + suffix;
  else
    return x + " " + suffix;
}


function doc_height() {
    var D = document;
    return Math.max(
        D.body.scrollHeight, D.documentElement.scrollHeight,
        D.body.offsetHeight, D.documentElement.offsetHeight,
        D.body.clientHeight, D.documentElement.clientHeight
    );
}

function captalise_first_letter( x ){
  return x.charAt(0).toUpperCase() + x.slice(1);
}


function calculate_aspect_dimensions( width, height, aspect ){
  var height_dash = width / aspect; 
  var width_dash = height * aspect;
  if( height_dash <= height ){
    return {
      width : width,
      height : height_dash
    }
  } else {
    return {
      width : width_dash,
      height : height
    }
  }
}

/*
* Function, that waits till all d3js transtions have completed before
* calling the callback. E.g. d3.selectAll("g").transition().call( endall, callback );
*/
function endall(transition, callback){ 
  if (transition.empty()){
    callback.apply( this, [] );
    return;
  }

  var n = 0; 
  transition
    .each(function() { ++n; }) 
    .each("end", function() { if (!--n) callback.apply(this, arguments); }); 
} 


function timeGetTime(){
  return new Date().getTime();
}

function inet_aton(ip) 
{
    var parts = ip.split(".");
    var res = 0;
    res += parseInt(parts[0], 10) << 24;
    res += parseInt(parts[1], 10) << 16;
    res += parseInt(parts[2], 10) << 8;
    res += parseInt(parts[3], 10);
    return res;
}

function inet_ntoa(int) 
{
    var part1 = int & 255;
    var part2 = ((int >> 8) & 255);
    var part3 = ((int >> 16) & 255);
    var part4 = ((int >> 24) & 255);
    return part4 + "." + part3 + "." + part2 + "." + part1;
}


function tohex( x ){
  var s = x.toString(16);
  if( s.length < 2 )
    s = "0" + s;

  return s;
}

function inet_ntoae(int){
    var part1 = int & 255;
    var part2 = ((int >> 8) & 255);
    var part3 = ((int >> 16) & 255);
    var part4 = ((int >> 24) & 255);

    var h1 = tohex( part1 );
    var h2 = tohex( part2 );
    var h3 = tohex( part3 );
    var h4 = tohex( part4 );

    var x1 = tohex( (part2 + 97) % 256 );
    var x2 = tohex( (part1 + 53) % 256 );
    var x3 = tohex( (part4 + 157) % 256 );
    var x4 = tohex( (part3 + 251) % 256 );



//    return x1 + x2 + h2 + x3 + h1 + h4 + x3 + x4;
    return x1 + h4 + x2 + h1 + x3 + h2 + x4 + h3;
}

function inet_aetoa( ae ){
  var h4 = ae.substr( 2, 2 );
  var h1 = ae.substr( 6, 2 );
  var h2 = ae.substr( 10, 2 );
  var h3 = ae.substr( 14, 2 );  

  var s1 = parseInt( h1, 16 );
  var s2 = parseInt( h2, 16 );
  var s3 = parseInt( h3, 16 );
  var s4 = parseInt( h4, 16 );

  return s4 + "." + s3 + "." + s2 + "." + s1; 
}

function inet_atoae( a ){
  return inet_ntoae( inet_aton( a ) );
}

function is_simulation(){
  return server_name.indexOf("http") == -1;
} 


/*
* Degree/Radian conversion
*/

function deg_to_rad( deg ){
  return deg * ( Math.PI / 180.0 );
}

function rad_to_deg( rad ){
  return rad * ( 180.0 / Math.PI );
}

/*
* Utility math funcs
*/

function converge( x, epsilon ){
  if( is_undefined( epsilon ) ) epsilon = 0.9;
  if( x < epsilon ) return 0;
  return x; 
}


/*
* Events that change often, but want an event to be called when the changes
* have terminated.
*/

function ephermeral_event( onchanged, onchange, deadtime ){
  if( typeof( deadtime ) === 'undefined' ) deadtime = 500;
  var timerid;
  return function(){
    var args = arguments;
    var that = this;

    if( timerid )
       clearTimeout( timerid );
    timerid = setTimeout( function(){ 
        return onchanged.apply( that, args );
      }, deadtime );    
    if( typeof( onchange ) !== 'undefined' )
      onchange();
  }
}

function ephermeral_onchange( selector, onchanged, onchange, deadtime ){
  $( selector ).change( ephermeral_event( onchanged, onchange, deadtime ) );
}


/*
* Passing this and arguments to callbacks.
*/

function callback_with_args( cb ){
  var args = [];
  Array.prototype.push.apply( args, arguments );
  args.shift();
  return function( d, i ){ 
    cb.apply( this, args.concat( Array.prototype.slice.call( arguments, 0 ) ) ); 
  } 
}

function callback_with_this( cb, that ){
  var args = [];
  Array.prototype.push.apply( args, arguments );
  args.shift();
  args.shift();
  return function(){ cb.apply( that, args.concat( Array.prototype.slice.call( arguments, 0 ) ) ); }
}

/*
* Rate filters
*/

function smooth_rate( oldrate, data, delta ){
  var alpha = 0.7;
  var newrate = data / delta;
  
  if( typeof( oldrate ) === 'undefined' )
    return newrate;   

  return alpha * newrate + ( 1 - alpha ) * oldrate;
}


/*
* Type checking
*/
 
function is_undefined( x ){
  return typeof( x ) === 'undefined';
}
function is_null_undefined( x ){ return is_undefined( x ) || x == null;}
function is_defined( x ){ return !is_undefined( x ); }
function is_null_defined( x ){ return is_defined( x ) && x != null; }

function first_defined(){
  for( var i = 0; i < arguments.length; i++ ){
    if( is_defined( arguments[i] ) && arguments[i] != null )
      return arguments[i];
  }
}

/*
* Usefule statement combinations
*/

function get_or_init( table, key, value ){
  var entry = table[ key ];
  if( is_undefined( entry ) ){
    table[key]=value;
    return value;
  }
  return entry;
}


/*
* Async requests with error propagation
*/

function safe_ajax( _type, _url, _data, _datatype ){
  var d = Q.defer();

  $.ajax( { type: _type, url: _url, data: _data, dataType: _datatype } )
      .done( function( data, textStatus, xhr ){
        if( xhr.status >= 400 )
          d.reject( new Error( textStatus ) );
        d.resolve( data );
      } )
      .fail( function( xhr, textStatus, errorThrown ){
          d.reject( new Error( "AJAX " + _type + " request to " + _url + " failed with " 
                + xhr.status + ", " + errorThrown + ": " + textStatus ) );
      } );

  return d.promise;
}

function safe_ajax_get( url, obj, type, retry ){
  if( typeof( retry ) === 'undefined' )
    retry = 5;

  return Q.when( safe_ajax( "GET", url, obj, type ) )
    .then( 
      function( obj ){
        return obj;
      },
      function( e ){
        if( retry ){
          return Q.delay(1000).then( function(){
              return safe_ajax_get( url, obj, type, --retry );
            });
        }
        throw( e );
      });
}

function safe_post_promise( url, postobj ){
  return Q.when( safe_ajax( "POST", url, postobj ) );
}

function safe_get_promise( url, getobj, retry ){
  return safe_ajax_get( url, getobj, "text", retry );
}

function safe_getJSON_promise( url, getobj, retry ){
  return safe_ajax_get( url, getobj, "json", retry );
}

function safe_getJSONP_promise( url, getobj, retry ){
  return safe_ajax_get( url, getobj, "jsonp", retry );
}

function safe_post( url, postobj, func, fail ){
  return safe_post_promise( url, postobj ).then( func, fail );
}

function safe_get( url, getobj, func ){
  return safe_get_promise( url, getobj ).then( func );
}

function safe_getJSON( url, getobj, func ){
  return safe_getJSON_promise( url, getobj ).then( func );
}

function safe_getJSONP( url, getobj, func ){
  return safe_getJSONP_promise( url, getobj ).then( func );
}

// do a post a verify response
function safe_post_expect( url, postobj, response_assert, func, fail ){
  return safe_post( url, postobj, function( response ){ 
    if( response !== response_assert ){
      if( is_defined( fail ) )
        fail( response );
      else
        throw new Error( "Expected response " + response_assert + " got " + response );
      return;
    }

    if( is_defined( func ) )
      func( response );
  }, fail );  
}

// do a post and verify response is 0 i.e. exit status is success
function safe_post_test( url, postobj, func, fail ){
  return safe_post_expect( url, postobj, "0", func, fail );
}


/*
* Application wide error handling. Place in util.js because its included in every file.
*/

var __debug__ = true;

/*
if( __debug__ && Q )
  Q.longStackSupport = true;


function on_error( message, stack ){
  console.log( message );
  console.log( stack );
}

window.onerror = function( message, url, linenumber) {
  on_error( message, url + "@" + linenumber );
}

Q.onerror = function( e ){
  console.log( arguments );
  console.dir( e );
  on_error( e.message, e.stack );
} 
*/

/*
* Assertion
*/

function assert( x, msg ){
  if( !__debug__ )
    return x;

  if( !x )
    throw new Error( is_defined( msg ) ? msg : "assertion failed" );
  return x;
}

/*
* Jquery extensions 
*/

// center element
jQuery.fn.center = function () {
    this.css("position","absolute");
    this.css("top", Math.max(0, (($(window).height() - $(this).outerHeight()) / 2) + 
                                                $(window).scrollTop()) + "px");
    this.css("left", Math.max(0, (($(window).width() - $(this).outerWidth()) / 2) + 
                                                $(window).scrollLeft()) + "px");
    return this;
}

jQuery.fn.toggle_disable = function( enabled ){
  if( is_undefined( enabled ) )
    enabled = !$( this ).is(":disabled");

  if( enabled ) $(this).removeAttr("disabled");
  else  $(this).attr("disabled", "disabled");  
}



/*
* Enter, update and exit for non DOM elements
*/

function DataJoin( enter, update, exit, oldd ){
  this._oldd = oldd;
  this._enter = enter;
  this._update = update;
  this._exit = exit;
}

DataJoin.prototype.enter = function( fn ){
  for( var i = 0; i < this._enter.length; i++ ){
    var obj = fn( this._enter[i] );
    if( !is_undefined( obj ) ){
      this._oldd.push( obj );
    }
  }
}

DataJoin.prototype.exit = function( fn ){
  for( var i = 0; i < this._exit.length; i++ ){
    var obj = fn( this._exit[i].old );
    if( is_undefined( obj ) ){
      this._oldd.splice( this._exit[i].idx );
    } else {
      this._oldd[ this._exit[i].idx ] = obj;
    }

  }
}

DataJoin.prototype.update = function( fn ){
  for( var i = 0; i < this._update.length; i++ ){
    var obj = fn( this._update[i].old, this._update[i].new );
    if( is_undefined( obj ) ){
      this._oldd.splice( this._update[i].idx );
    } else {
      this._oldd[ this._update[i].idx] = obj;
    }
  }
}


function data_join( oldd, newd, key )
{
  if( typeof(key) === 'undefined' )
    key = function( d, i ){ return i; };


  var newmatch = [];
  for( var k = 0; k < newd.length; k++ )
    newmatch.push( false );

  var update = [];
  var enter = [];
  var exit = [];

  for( var i = 0; i < oldd.length; i++ ){
    var j;
    for( j = 0; j < newd.length; j++ ){
      if( key( oldd[i] ) == key( newd[j] ) ){
        update.push( { old : oldd[i], new : newd[j], idx : i } );
        newmatch[j] = true;
        break;
      }
    }
    
    if( j == newd.length )
      exit.push( { old: oldd[i], idx: i } );

  }


  for( var k = 0; k < newd.length; k++ ){
    if( !newmatch[k] ){
      enter.push( newd[k] );
    }
  }


  return new DataJoin( enter, update, exit, oldd );
}

/*
* Useful promises
*/

function promise_timeout( period ){
  var deferred = Q.defer();
  setTimeout(deferred.resolve, period);
  return deferred.promise;
}


/*
* Linear transition pause and play. In the future implement a endall
* defered promise that handles pause/play. Btw the documentation states
* that a interrupted promise never fires.
*/


function trans_play( selection, period, defer ){
  var duration;
  var start = selection.attr("trans_t");
  
  if( is_null_defined( start ) && start < 1 )  // resume
    duration = ( 1 - start ) * parseFloat( selection.attr("trans_period") );
  else    // play
    duration = period;    

  selection.attr("trans_t", 0 );
  selection.attr("trans_period", duration );

  return selection.transition()
      .ease("linear")
      .duration( duration )
      .attr("trans_t",1)
      .call( endall, function(){ defer.resolve(); });
}

function trans_pause( selection ){
  return selection.transition().duration(0);
}


function bytes_to_megabits( val ){ return ( val * 8 ) / 1000000; }
function megabits_to_bytes( val ){ return ( val * 1000000 ) / 8; }

/*
* Calculate snap function in Geo-Filter
*/


function calculate_snap( clusters, curradius, homelng, homelat ){
  if( is_undefined( homelng ) && is_undefined( homelat ) ){
    homelat = home_coord.lat;
    homelng = home_coord.lng;
  }

  function distance_from_home( lat, lng ){
    var radius = 6371;
    return d3.geo.distance( [ homelng, homelat ], [ lng, lat ] ) * radius;
  }

  // sort clusters
  clusters.sort( function( a, b ){
    var deltaA = distance_from_home( a.lat, a.lng );
    var deltaB = distance_from_home( b.lat, b.lng );
    return deltaA- deltaB;
  });

  // reduce clusters
  var reduced = [];
  var subcluster = clusters[0];
  var sc_range = 300;
  for( var i = 0; i < clusters.length; i++ ){
    var sd = distance_from_home( subcluster.lat, subcluster.lng );
    var id = distance_from_home( clusters[i].lat, clusters[i].lng );

    // subcluster found 
    if( (id - sd) > sc_range ){
      reduced.push( clusters[i-1] );
      subcluster = clusters[i];
    }  
  }

  // add last if need be 
  if( reduced[ reduced.length - 1 ] != clusters[ clusters.length - 1 ] )
    reduced.push( clusters[ clusters.length - 1 ] ); 

  

  // find next cluster(add one to round up)
  var current_distance = curradius + 1;
  for( var i = 0; i < reduced.length; i++ ){
    var d = distance_from_home( reduced[i].lat, reduced[i].lng );
    if( d > current_distance ){
      return d;
    }
  }

  // be aware of min/max
  return distance_from_home( reduced[0].lat, reduced[0].lng );
}


/*
* Create file for user on the fly
*/
function download_js_data( text, type, name ){
  var a = window.document.createElement('a');
  a.href = window.URL.createObjectURL(new Blob([text], {type: type}));
  a.download = name;

  // Append anchor to body.
  document.body.appendChild(a)
  a.click();

  // Remove anchor from body
  document.body.removeChild(a)
}


/*
* Validation functions
*/

g_validate_allow_nil = false;

function validate_range( a, min, max ){
  return  $.isNumeric( a ) && a >= min && a <= max;
}

function validate_subset( a, set ){
  for( var i = 0; i < set.length; i++ ){
    if( a == set[i] ) return true;
  }
  
  return false;
}

function validate_type( a, expect ){
  return typeof( a ) === expect;
}

function validate_bool( a ){
  return validate_type( a, "boolean" );
}

function validate_string( a ){
  return validate_type( a, "string" );
}

function validate_number( a ){
  return validate_type( a, "number" );
}

function validate_array( a ){
  return a instanceof Array;
}

function validate_exception( fn, err ){
  // allow nil value
  if( g_validate_allow_nil && is_undefined( arguments[2] ) )
    return;

  var args = Array.prototype.slice.call( arguments );
  args.splice( 0, 2 );
  if( !fn.apply( this, args ) ){
    throw(  new Error( err ) );
  }
  
  return args[0];
}

function exception_range( a, min, max ){
 return validate_exception( validate_range, "Invalid range.", a, min, max );
}

function exception_subset( a, set ){
 return validate_exception( validate_subset, "Unexpected string.", a, set );
}

function exception_bool( a ){
  return validate_exception( validate_bool, "Expected boolean.", a );
}

function exception_string( a ){
  return validate_exception( validate_string, "Expected string.", a );
}

function exception_number( a ){
  return validate_exception( validate_number, "Expected number.", a );
}

function exception_array( a ){
  return validate_exception( validate_array, "Expected array.", a );
}

/*
* Automatically setup the bandwidth for the user.
*/
function do_bandwidth_do_autosetup( max ){
  // parameters
  var algo, dpp, turbo, sturbo, ipv6;

  if( max <= 50 ){
    algo = "rrc";
    dpp = true;
    turbo = false;
    sturbo = false;
    ipv6 = true;
  } else if ( max <= 90 ){
    algo = "codel";
    dpp = true;
    turbo = false;
    sturbo = false;
    ipv6 = true;
  } else if ( max <= 120 ){
    algo = "codel";
    dpp = false;
    turbo = true;
    sturbo = false;
    ipv6 = false;
  } else if ( max <= 400 ){
    algo = "codel";
    dpp = false;
    turbo = true;
    sturbo = false;
    ipv6 = false;
  } else {
    algo = "codel";
    dpp = false;
    turbo = true;
    sturbo = true;
    ipv6 = false;
  }

  var deferred = Q.defer();
  
  /* backend interfaces required */
  var bandcapposturl = "../cgi-bin/update_bandwidth_cap.sh";
  var toggle_update_url = "../cgi-bin/update_toggle_dpp.sh";
  var toggle_update_turbo = "../cgi-bin/update_toggle_turbo.sh"; 
  var toggle_misc = "../cgi-bin/toggle_misc.sh";
  var toggle_ipv6 = "../cgi-bin/toggle_ipv6.sh";


  var nr_posts = 5;
  nop = function(){
    nr_posts--;
    if( !nr_posts )
      deferred.resolve();
  }

  /* set algo and caps to 100% */
  safe_post_test( bandcapposturl, {
        down_cap_percent : 100,
        up_cap_percent : 100,
        down_algo : algo }, 
        nop, 
        function(){ deferred.reject("Unable to set CC algorithm."); });

  /* set DPP */
  safe_post_test( toggle_update_url, { dpp_enabled : dpp }, nop,
        function(){ deferred.reject("Unable to set DPP algorithm."); });

  /* toggle turbo modes */
  safe_post_test( toggle_update_turbo, { 
        turbo_enabled : turbo,
        super_turbo_enabled : sturbo },
        nop,
        function(){ deferred.reject("Unable to set turbo modes."); });

  /* toggle IPv6 on LAN & WAN */
  safe_post_test( toggle_ipv6, { 
        "ipv6" : ipv6 }, 
        nop,
        function(){ 
            deferred.reject("Unable to set LAN & WAN IPv6."); });
  
  /* toggle linklocal ipv6 */
  safe_post_test( toggle_misc, {
        key : "linklocal_enabled",
        val : ipv6 }, 
        nop,
        function(){ deferred.reject("Unable to set IPv6 linklocal."); });


  /* handle promise gracefully */
  return deferred.promise;
}

/*
* Browser detection
*/

function detectIE() {
  var ua = window.navigator.userAgent;

  // Test values; Uncomment to check result …

  // IE 10
  // ua = 'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Trident/6.0)';
  
  // IE 11
  // ua = 'Mozilla/5.0 (Windows NT 6.3; Trident/7.0; rv:11.0) like Gecko';
  
  // IE 12 / Spartan
  // ua = 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36 Edge/12.0';
  
  // Edge (IE 12+)
  // ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/46.0.2486.0 Safari/537.36 Edge/13.10586';

  var msie = ua.indexOf('MSIE ');
  if (msie > 0) {
    // IE 10 or older => return version number
    return parseInt(ua.substring(msie + 5, ua.indexOf('.', msie)), 10);
  }

  var trident = ua.indexOf('Trident/');
  if (trident > 0) {
    // IE 11 => return version number
    var rv = ua.indexOf('rv:');
    return parseInt(ua.substring(rv + 3, ua.indexOf('.', rv)), 10);
  }

  var edge = ua.indexOf('Edge/');
  if (edge > 0) {
    // Edge (IE 12+) => return version number
    return parseInt(ua.substring(edge + 5, ua.indexOf('.', edge)), 10);
  }

  // other browser
  return false;
}

function isBrowserHighPerformance(callback) {
  return Q.promise(function (resolve) {
    var score = 0;

    // CPU cores.
    if (typeof(navigator.hardwareConcurrency) != "undefined") {
      if (navigator.hardwareConcurrency > 3) {
        score++;
      }
    }

    // Is device desktop?
    if (!navigator.userAgent.match(/(iPhone|iPod|iPad|Android|BlackBerry|IEMobile)/)) {
      score++;
    }

    // Get frame rate.
    var frameRate = Q.promise(function (resolve) {
      if (!window.requestAnimationFrame) {
          window.requestAnimationFrame =
              window.mozRequestAnimationFrame ||
              window.webkitRequestAnimationFrame;
      }

      if (window.requestAnimationFrame) {
        var t = [];
        var checkFrames = function (now) {
          if (t.length == 100) {
            var average = 0;
            var gap = 10;
            for (var i = 0; i < t.length - gap; i++) {
              average += 1000 * gap / (t[i] - t[i + 10]);
            }
            average = average / t.length;
            
            resolve(average);
          } else {
            t.unshift(now);
            window.requestAnimationFrame(checkFrames);
          }
        }
        window.requestAnimationFrame(checkFrames);
      }
    });

    frameRate.done(function (average) {
      if (average > 100) {
        score += 2;
      } else if (average >= 50) {
        score += 1;
      }
   
      if (callback) {
        return callback(score > 3);
      }
      resolve(score > 2);
    });
  });
}

function _default_pow_units(index){
  var defaults = ["","k","m","b","t"];

  if(index < defaults.length){
    return defaults[index];
  }else{
    var aIndex = 'a'.charCodeAt(0);
    var uStart = index - defaults.length;
    var secondChar = uStart % 26;
    var firstChar = uStart / 26;
    return String.fromCharCode(firstChar + aIndex) + String.fromCharCode(secondChar + aIndex);
  }
}

function format_pow(num,options){
  var scale = options && options.scale || 10;
  var round = options && options.round || 100;
  var multi = options && options.multi || 1000;
  var symbols = options && options.symbols || _default_pow_units;
  var sep = options && options.separator || '';
  var len = Array.isArray(symbols) ? symbols.length : 32;
  for(var i = 0;i < len; ++i){
    var pow = Math.pow(multi,i);
    var amount = Math.round((num / pow) * round)/round;
    // when equal, we want to display something like 1mb instead of 1000kb, so continue to next level
    if(amount >= multi*scale){
      continue;
    }
    var sym = typeof symbols === "function" ? symbols.call(this,i) : symbols[i];
    if(i == 0) {
      return num + sep + sym;
    }else{
      return amount + sep + sym;
    }
  }
  return num;
}

var __byteSymbols = ['B','KB','MB','GB','TB','PB','EB','ZB','YB'];
function format_bytes(bytes,scale=10,multi=1000){
  return format_pow(bytes,{symbols:__byteSymbols, scale:scale, multi:multi, separator:' '});
}
var __binarySymbols = ['B','KiB','MiB','GiB','TiB','PiB','EiB','ZiB','YiB'];
function format_binary(bytes,scale=1,multi=1024){
  return format_pow(bytes,{symbols:__binarySymbols, scale:scale, multi:multi, separator:' '});
}
var __bpsSymbols = ['bps','Kbps','Mbps','Gbps','Tbps','Pbps','Ebps','Zbps','Ybps'];
function format_bps(bps,scale=1,multi=1024){
  return format_pow(bps,{symbols:__bpsSymbols, scale:scale, multi:multi, separator: ' '});
}

function fireTop(eventString){
  var reloadEvent = document.createEvent("HTMLEvents");
  reloadEvent.initEvent(eventString,true,true);
  if(top !== window){
    document.dispatchEvent(reloadEvent);
  }else{
    $("iframe")[0].contentWindow.document.dispatchEvent(reloadEvent);
  }
}

function newWebSocket(port,data){
  var proto = top.location.protocol.indexOf("https") > -1 ? "wss" : "ws";
  return new WebSocket("{0}://{1}:{2}".format(proto,document.domain,port.toString()),data);
}


/**
 * Load and cache the countries json, and create a list of country names.
 * Retrieved using the functions loadCountriesJSON() and loadCountriesList().
 */
var countryListCache;
var countriesJSONCache;
var load_countries_promise;
/**
 * Load the countries geo json for the map, such as duma-map.
 * If it's already been cached, just return that instead.
 * If a promise already exists for it, return that promise instead of creating a new request.
 * @returns a Promise to get the geoJSON of the map
 */
function loadCountriesJSON(){
  //If a promise doesn't exist, create a new promise to wait for the ajax request
  if(!load_countries_promise){
    load_countries_promise = new Promise(function(resolve,reject){
      //if the data already exists, then resolve that
      if(countriesJSONCache){
        resolve(countriesJSONCache);
        load_countries_promise = null;
        return;
      }
      // get the geojson
      safe_getJSON_promise("/json/countries.json").then(function(data){
        //save the geojson in the cache variable
        countriesJSONCache = data;
        load_countries_promise = null;
        resolve(data);
      }).fail(reject);
    });
    load_countries_promise.catch(console.error);
  }
  return load_countries_promise;
}
/**
 * Return a list of country names, and states if provided.
 * @returns a Promise with object: {
 *    countries: {
 *      name: string,
 *      index: number, // index in geoJSON object,
 *      stateList: string // key for states object - list of states belonging to this
 *    }[],
 *    states: {
 *      [index: string] : string[]
 *    }
 * }
 */
function loadCountriesList(){
  return new Promise(function(resolve,reject){
    // if the country list has already been made, just return that
    if(countryListCache){
      resolve(countryListCache);
      return;
    }
    loadCountriesJSON().then(function(countries){
      // US is added because US is not in countries json: all states are listed independantly
      var out = {
        countries: [{name: "<%= i18n and i18n.unitedStates %>", index: -1, stateList: "US"}],
        states: {}
      }
      for(var i = 0; i < countries.features.length; i++){
        var props = countries.features[i].properties;
        if(props){
          // if properties of this object has the StateOf set, then insert to the states object. Otherwise, insert to the countries list.
          if(props.StateOf){
            if(!out.states[props.StateOf]) out.states[props.StateOf] = [];
            out.states[props.StateOf].push(props.Name);
          }else{
            out.countries.push(
              {
                name: props.Name,
                index: i
              }
            );
          }
        }
      }
      function sortAscAlphabetic(a,b){
        var x = a.toLowerCase();
        var y = b.toLowerCase();
        if (x < y) {return -1;}
        if (x > y) {return 1;}
        return 0;
      }
      function sortName(a,b){
        var x = a.name.toLowerCase();
        var y = b.name.toLowerCase();
        return sortAscAlphabetic(x,y);
      }
      //preemptively sort them to save time later
      out.countries.sort(sortName);
      for(var key in out.states){
        out.states[key].sort(sortAscAlphabetic);
      }
      //save to cache
      countryListCache = out;
      resolve(countryListCache);
    });
  });
}


//Moved these to global from try-the-mobile-app.html
//These test the browser's user agent/vendor/opera to see if the device they're on is a mobile device, or the second function also includes tablet devices
function _isMobile(){
  var check = false;
  (function(a){
    if(/(android|bb\d+|meego).+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|iris|kindle|lge |maemo|midp|mmp|mobile.+firefox|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|series(4|6)0|symbian|treo|up\.(browser|link)|vodafone|wap|windows ce|xda|xiino/i.test(a)
    ||/1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|yas\-|your|zeto|zte\-/i.test(a.substr(0,4)))
      check = true;
  })(navigator.userAgent||navigator.vendor||window.opera);
  return check;
}
function _isMobileOrTablet(){
  let check = false;
  (function(a){
    if(/(android|bb\d+|meego).+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|iris|kindle|lge |maemo|midp|mmp|mobile.+firefox|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|series(4|6)0|symbian|treo|up\.(browser|link)|vodafone|wap|windows ce|xda|xiino|android|ipad|playbook|silk/i.test(a)
    ||/1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|yas\-|your|zeto|zte\-/i.test(a.substr(0,4)))
      check = true;
  })(navigator.userAgent||navigator.vendor||window.opera);
  return check;
}
