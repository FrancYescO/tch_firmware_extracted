--pretranslated: do not change this file
 
    local telstra_helper = require("telstra_helper")
    local symbolv1 = telstra_helper.symbolnamev1
  ngx.print('\
<!DOCTYPE HTML>\
');  ngx.print( string.format('<html lang="%s">', gettext.language()) ); ngx.print('\
    <head>\
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">\
    <meta charset="UTF-8">\
    <meta name="CSRFtoken" content="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\
    <link href="/css/gw-telstra.css" rel="stylesheet">\
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->\
    <script src="/js/main-telstra-min.js" ></script>\
    <title>');  ngx.print( T("Telstra " .. symbolv1) ); ngx.print('</title>\
    </head>\
    <body>\
'); 