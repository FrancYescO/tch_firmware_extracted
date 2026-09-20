/*
* (c) 2016 netduma software
* iain fraser <iainf@netduma.com>
*
* DumaOS http rpc api
*/
var g_rpc_id = 0

function generate_url( packid ){
  return "/apps/" + packid + "/rpc/"
}
class APRPCError extends Error {
  constructor(message){
    super(message);
    this.name = "AP RPC Error"
  }
}

function do_long_rpc_promise( packid, method, params, timeout, deferred, retry ){
  if(window.apMode){
    var apdef = Q.defer();
    var apError = new APRPCError("Router is in AP Mode. RPC is disabled.");
    apdef.reject( apError );
    return apdef.promise;
  }
  deferred = deferred || Q.defer();
  retry = retry || 0;
  var url = generate_url( packid );
  var id = ++g_rpc_id;  

  if( ! $.isArray( params ) )
    throw new TypeError("RPC params is not an array");

  var postobj = {
    "jsonrpc" : "2.0",
    "method" : method,
    "id" : id,
    "params" : params,
    "clienttype": "web",
    "timeout": timeout
  }



  function confirm_request( rid ){
    if( typeof( rid ) !== 'undefined' ){
      if( rid != id ){
        deferred.reject( new Error("Respond to wrong request") ); 
        return false;
      }
    }

    return true;
  }

  function error_handler( data ){
    /* Some platforms require redirect on teapot status */
    if( data.status == 418 ){
      top.location="/multi_login.html";
      return;
    }
    if( data.status == 419 ){
      top.location="/multi_guestlogin.html";
      return;
    }

    /*
    * On some platforms the server resets based on extraneous
    * events. A request may be unlucky and try connect to a 
    * closed socket and recieve reset. Just retry till the server
    * hopefully comes up. 
    */
    if( data.readyState < 4 && ( retry++ ) < 15  ){
      console.log("Retrying rpc call " + packid + "::" + method )
      setTimeout( 
        function(){
          long_rpc_promise( packid, method, params, timeout, deferred, retry );
        }, 1000 );
      return;
    }

    if( typeof( data.responseJSON ) === 'undefined' || data.responseJSON == null ){
      if( ( retry++ ) < 4 ){
        setTimeout( 
          function(){
            long_rpc_promise( packid, method, params, timeout, deferred, retry );
          }, 1000 );
      } else {
        deferred.reject( new Error("Missing JSON response.") );
      }
      return;
    }

    var s = data.status;
    var d = data.responseJSON;
    if( !confirm_request( d.id ) )
      return;

    
    // TODO: id may not exist for some requests
    // TODO: 403 not authenticated, 400 syntax error instead of 500
    var e;
    switch( s ){
      case 404: 
        e = new Error("rpc method does not exist");
        break;
      case 400:
        e = new Error("invalid rpc request");
        break;
      case 403:
        e = new Error("Forbidden access");
        break;
      case 500:
        switch( d.error ){
          case -32700:    // 400 instead
            e = new SyntaxError("rpc parse error");
            break;
          case -32602:
            e = new TypeError("invalid rpc parameters");
            break;
          case -32604:
            e = new Error("Forbidden access");
            break;
          case -32000:
            var prefix 
            switch( d.eid ){
              case "ERROR_WARNING":
                prefix = "";
                break;
              case "ERROR_UBUS":
                if( d.msg == "Ubus error: 4" || d.msg == "Ubus error: 10" ){
                  if( ( retry++ ) < 5 ){
                    console.log("Retrying rpc assume reboot: " + packid + "::" + method )
                    setTimeout( 
                      function(){
                        long_rpc_promise( packid, method, params, timeout, deferred, retry );
                      }, 6000 );
                    return;
                  }

                  d.msg = "<%= i18n.appNotLoaded %>";
                  prefix = "";
                } else if ( d.msg == "Ubus error: 7" ){
                  d.msg = "<%= i18n.operationTakingLongerThanExpected %>";
                  prefix = "";
                }
                break;
              default:
                prefix = "RPC error '" + d.eid + "': ";
                break;
            }
            e = new Error( prefix + d.msg );
            break;
        }
        break;
    }

    if( !e ){
      if( s && d )
        e = new Error( d.message );
      else
        e = new Error("Unknown RPC error");
    }

    deferred.reject( e );
  }

  var jqxhr = $.ajax({
    type: "POST",
    url: generate_url( packid ),
    data: JSON.stringify( postobj ),
    contentType: "application/json-rpc",
    dataType: "json"
  })
  .done( function( data ){
    if( !confirm_request( data.id ) )
      return;
    else if( data.eid )
      error_handler( {
        "status" : 500,
        "readyState" : 5,      
        "responseJSON" : data
      } );
    else
      deferred.resolve( data.result );
  })
  .fail( error_handler );

  return deferred.promise;
}

/*
function long_rpc_promise( packid, method, params ){
  var serial_defer = Q.defer();
  var rpc_defer = Q.defer();
  var y = ++x;
  g_deferred.promise.done( function(){
    rpc_defer.promise.finally( function(){ 
      serial_defer.resolve() 
    } );

    do_long_rpc_promise( packid, method, params, rpc_defer );
 
  });

  g_deferred = serial_defer; 
  return rpc_defer.promise;
}
*/
long_rpc_promise = do_long_rpc_promise;




function long_rpc( packid, method, params, callback ){
  long_rpc_promise( packid, method, params ).
    done( function( result ){
      callback.apply( null, result );
    })
}




function rpc( method, param, callback ){
  long_rpc( __duma.package_id, param, callback );
}



function create_rate_limit_long_rpc_promise( packid, method, period ){
  if( !period )
    period = 1000;

  var tid = null;
  var deferred_queue = [];
  return function( params ){

    function perform_rpc(){
      tid = null;
      var promise = long_rpc_promise( packid, method, params )
      for( var i = 0; i < deferred_queue.length; i++ ){
        var d = deferred_queue[i];
        d.resolve( promise );
      }
      deferred_queue = [];
    }

    if( tid != null )
      window.clearTimeout( tid );
    tid = window.setTimeout( perform_rpc, period );

    var deferred = Q.defer();
    deferred_queue.push( deferred );
    return deferred.promise;
  }
}


/*
function long_rpc(package_id, method, parameters, callback) {
  var url = "/cgi-bin/url-routing.lua?action=rpc&package=" + package_id + "&proc=" + method
  var url - generate_url( 


  $.getJSON(url, {args: parameters}, function( json ) {
    var pass;
    if( json && $.isArray( json.result ) )
      pass = [ true ].concat( json.result );
    else
      pass = [ false ];

    callback.apply( null, pass);
  })
  .fail( function(){
    callback( false );
  });
}

function rpc (method, parameter, callback) {
  long_rpc(__duma.package_id, method, parameters, callback)
}
*/

/*
* Basic conversion of object to SOAP parameters. Does work with arrays.
*/
function obj_to_xml( obj ){
  var out = "";

  for( var key in obj ){
    val = obj[key];
    out += '<' + key + '>';
    if( val instanceof Object ){
      out += obj_to_xml( val );
    } else {
      out += val.toString();
    } 
    out += '</' + key + '>';
  }

  return out;
}

/*
* Basic conversion of SOAP response obj to data. Assumes all non composite
* variables are strings and all composite objects are maps.
*/
function xml_to_obj( sel ){
  out = {};

  sel.children().each( function(){
    var cur = $(this);
    var name = cur.prop("tagName");
    if( cur.children().length > 0 ) {
      var subtree = xml_to_obj( cur );
      out[name] = subtree;
    } else {
      out[name] = cur.text();
    }

  });

  return out;
}

function internet_edge_sucks_xml_find( data, tag ){
  for( var i = 0; i < data.childNodes.length; i++ ){
    var x = data.childNodes[i];
    if( x.tagName == tag ){
      return x;
    } else {
      var y = internet_edge_sucks_xml_find( x, tag );
      if( y )
        return y;
    }
  }
}

/*
* NETGEAR RPC call implementation. Parameters:
* service - compulsory (string) service to invoke
* method - compulsory (string) method to invoke
* params - optional (object) method parameters, cannot contain array. 
* deferred - internal argument do not pass anything
* retry - internal argument do not pass anything
*/
function netgear_soap_rpc( service, method, params, deferred, retry ){
  params = (typeof params !== 'undefined') ?  params : [];
  deferred = deferred || Q.defer();
  retry = retry || 0;
  
  var urn =  "urn:NETGEAR-ROUTER:service:" + service + ":1";

  var data = '<?xml version="1.0" encoding="UTF-8" standalone="no"?><SOAP-ENV:Envelope SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/1999/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/1999/XMLSchema"><SOAP-ENV:Body>';

  data += '<method:' + method + 'xmlns:method="' + urn + '">';
 /* params.forEach( function( v ){
    data += '<' + v.name + '>' + v.value + '</' + v.name + '>';
  }); */
  data += obj_to_xml( params );

  data += '</method:' + method + '></SOAP-ENV:Body></SOAP-ENV:Envelope>';



  jqxhr = $.ajax({
    type: "POST",
    url: " /soap/server_sa/",
    dataType: "xml",
    data: data,
    contentType: "text/xml; charset=\"utf-8\"",
    beforeSend: function(xhr){
      xhr.setRequestHeader('SOAPAction', urn + "#" + method );
    },
  })
  jqxhr
  .done( function(data){ 
    var pattern = "m\\:" + method + "Response";
    var sel = $(data).find( pattern );
    if( !sel.length && data )  // #$%! Edge
        sel = $( internet_edge_sucks_xml_find( data, "m:" + method + "Response" ) );

    var out = {
      response : xml_to_obj( sel ),
      code : $(data).find("ResponseCode").text()
    }

    /*if( out.code == 401 ){
      top.location = "/ndindex.html";
      return;
    }*/

    deferred.resolve( out );
  })
  .fail( function(data){
    /* Some platforms require redirect on teapot status */
    if( data.status == 418 ){
      top.location="/multi_login.html";
      return;
    }
    if( data.status == 419 ){
      top.location="/multi_guestlogin.html";
      return;
    }
    /*if( data.status == 401 ){
      top.location = "/ndindex.html";
      return;	    
    }*/	    

    /*
    * On some platforms the server resets based on extraneous
    * events. A request may be unlucky and try connect to a 
    * closed socket and recieve reset. Just retry till the server
    * hopefully comes up. 
    */
    if( data.readyState < 4 && ( retry++ ) < 15  ){
      console.log("Retrying NETGEAR SOAP call call " + service + "::" + method )
      setTimeout( 
        function(){
          netgear_soap_rpc( service, method, params, deferred, retry );
        }, 1000 );
      return;
    }
    deferred.reject( new Error("NETGEAR SOAP RPC called failed") );
  });
  
  
  return deferred.promise;
}

/*
* Slow SOAP APIs can hog up all browser sockets meaning entire UI
* has to wait. Instead run SOAP requests in sequence.
*/

var g_deferred = Q.defer();
g_deferred.resolve();
var x = 0;
function serial_netgear_soap_rpc( service, method, params ){
  var serial_defer = Q.defer();
  var soap_defer = Q.defer();
  var y = ++x;
  g_deferred.promise.done( function(){
    /* no matter outcome of SOAP request move down chain */
    soap_defer.promise.finally( function(){ 
      serial_defer.resolve() 
    } );

    /* do request and update callers promise */
    netgear_soap_rpc( service, method, params, soap_defer );
 
  });

  g_deferred = serial_defer; 
  return soap_defer.promise;
}

