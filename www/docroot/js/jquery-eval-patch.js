jQuery.globalEval = function( code ) {
  var script;
  code = jQuery.trim( code );
  if ( code ) {
    // execute code by injecting a
    // script tag into the document.
    script = document.createElement( "script" );
    script.text = code;
    document.head.appendChild( script ).parentNode.removeChild( script );
  }
}
