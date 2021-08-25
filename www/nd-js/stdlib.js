/*
* (C) 2016 NETDUMA Software
* Iain Fraser <iainf@netduma.com>
* 
* General purpose functions exposed to LUA framework.
*/

function params_to_starlight( arr ){
  var ret = [];
  for( var i = 0; i < arr.length; i++ ){
    if( $.isArray( arr[i] ) || $.isPlainObject( arr[i] ) )
      ret.push( new starlight.runtime.T( arr[i] ) );
    else
      ret.push( arr[i] );
  }

  return ret;
}

function sync_json( url, data ){
  var result;
  var jdata = data.toObject();
  var pass;

  $.ajaxSetup( { async : false } )
  $.getJSON( url, jdata, function( data ){ 
    result = data; 
  })
  .done( function(){ pass = true; } )
  .fail( function(){ pass = false; } )

  $.ajaxSetup( { async : true } )

  var ret = [ pass ];
  if( result && $.isArray( result.result ) ){
    for( var i = 0; i < result.result.length; i++ ){
      var element = result.result[i];
      if( $.isArray( element ) || $.isPlainObject( element ) )
        ret.push( new starlight.runtime.T( element ) ); 
      else
        ret.push( element );  
    }

//    return ret.concat( result.result );
  }

  return ret;
}


function async_json( url, callback, data ){
  var jdata = data instanceof starlight.runtime.T ? data.toObject() : data;

  $.getJSON( url, jdata, function( json ){
    var pass;
    if( json && $.isArray( json.result ) )
      pass = [ true ].concat( json.result );
    else
      pass = [ false ];

    callback.apply( null, params_to_starlight( pass ) );
  })
  .fail( function(){
    callback( false );
  });
}

function bind_js_event( _selector, _event, _handler ){
  $( _selector ).off( _event )
  $( _selector ).on( _event, function(){
    var params = [];

    // start at 1 to skip jquery event object.
    for( var i = 1; i < arguments.length; i++ ){
      if( $.isArray( arguments[i] ) || $.isPlainObject( arguments[i] ) ){
        params.push( new starlight.runtime.T( arguments[i] ) ); 
      } else {
        params.push( arguments[i] );
      }
    }

    _handler.apply( null, params );
  } );
}

function bind_stdlib( env ){
  env.sync_json = sync_json;
  env.async_json = async_json;
  env.bind_js_event = bind_js_event;
}



