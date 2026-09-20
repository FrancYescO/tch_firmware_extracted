<!DOCTYPE HTML>
<%= string.format('<html lang="%s">', gettext.language()) %>
    <head>
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">
    <meta charset="UTF-8">
    <meta name="CSRFtoken" content="<%= ngx.ctx.session:getCSRFtoken() %>">
    <link href="/css/gw-telstra.css" rel="stylesheet">
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->
    <script src="/js/main-telstra-min.js" ></script>
    <title><%= T"Telstra Gateway" %></title>
    </head>
    <body>