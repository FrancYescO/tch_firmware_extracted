format = string.format
local content_helper = require("web.content_helper")
local proxy = require("datamodel")

local bits = {
    ISP = "uci.env.custovar.ISP",
    prod_name = "uci.env.var.prod_name",
    prod_number = "uci.env.var.prod_number",
}
content_helper.getExactContent(bits)
local router, isp = format("%s%s", bits.prod_name, bits.prod_number), bits.ISP:untaint()


local redirected_URL = "<span id=\"redirect_URL\"></span>"


return {
   WS={
        img = "/img/httpierror1.jpg",
        WS = T"Auto WAN Active",
        Help_Title = T"Auto Sensing",
        text = {
            { format("<p>%s</p>",T"Your router is in automatic set-up mode.")},
            { format("<p>%s %s %s %s %s</p>",T"Please follow the set-up guide provided by", isp, T"to connect the", router , T"to your Broadband service!")},
            { "<br/>"},
            { format("<div class=\"httpi_button\"><div  class=\"btn btn-primary\" id=\"retry\" >%s</div></div><br/>",T"Try Again")},
            { "<br/>"},
            { format("<p>%s %s %s</p>",T"If you continue to see this screen please contact", isp, T"for assistance.")},  
        },
    },
    xDSL_E1={
        img = "/img/httpierror1Init.jpg",
        Help_Title = T"DSL Issue",
        text = {
            { format("<p>%s</p>",T"The status of your connection is shown by the Broadband light.")},
            { format("<div><div class='httpi_main_left'><strong>%s</strong></div>:  %s</div>",T"OFF", T"No phone line / Broadband detected" )},
            { format("<div><div class='httpi_main_left'><strong>%s</strong></div>:  %s</div>",T"GREEN FLASHING", T"Trying to connect") },
            { format("<div><div class='httpi_main_left'><strong>%s</strong></div>:  %s</div>",T"SOLID GREEN", T"Broadband ready" ) },
            { "<br/>"},
            { format("<p>%s</p>", T"Please check the following, it will help determine the problem with your connection and possibly avoid the cost of an engineer visit." )},
            { "<ol>"},
            { format("<li>%s %s %s %s %s</li>", T"If this is the first time you have set up your", router , T"please check that your Broadband service has been activated.", isp:gsub("^%l", string.upper), T"will have sent you the date on which your Broadband service will be ready." )},
            { format("<li>%s</li>", T"If your Broadband service has been activated, next check that you  have connected your router correctly as shown in the supplied set up guide." )},
            { format("<li>%s</li>", T"If the Broadband light is still not solid green check the troubleshooting section of the set up guide." )}, 
            { "</ol>"},
            { format("<p>%s</p>",T"Once the Broadband light is SOLID GREEN press the button below.")},
            { format("<div class=\"httpi_button\"><div  class=\"btn btn-primary\" id=\"retry\" >%s</div></div><br/>",T"Try Again")}, 
            { format("<p>%s</p>",T"If the Broadband light continues to flash there may be a problem with your home wiring. In this case disconnect all telephone extensions and connect your router to the master socket using one of the supplied DSL Filters.")},
        },
    },
   ETH_E1={
        img = "/img/httpierror1Eth.jpg",
        Help_Title = T"Ethernet Issue",
        text = {
            { format("<p>%s</p>",T"The status of your connection is shown by the Broadband light.")},
            { format("<div><div class='httpi_main_left'><strong>%s</strong></div>:  %s</div>",T"OFF", T"No phone line / Broadband detected" )},
            { format("<div><div class='httpi_main_left'><strong>%s</strong></div>:  %s</div>",T"SOLID GREEN", T"Broadband ready" ) },
            { "<br/>"},
            { format("<p>%s</p>",T"Please check the following, it will help determine the problem with your connection and possibly avoid the cost of an engineer visit.")},
            { format("<p><strong>%s:</strong><br/> %s %s %s</p>",T"FTTC",T"Check that you have correctly connected the red port on your", router , T"to socket LAN1 on the BT termination unit.")},
            { format("<p><strong>%s:</strong><br/> %s %s %s</p>",T"Other Ethernet Services",T"Check that you have correctly connected the red port on your", router , T"to the provided termination unit.")},
            
            { format("<p>%s</p>",T"Once the light is SOLID GREEN press the button below.")},
            { format("<div class=\"httpi_button\"><div  class=\"btn btn-primary\" id=\"retry\" >%s</div></div><br/>",T"Try Again")}, 
            
        },
    },
    PPPAuth={
        img = "/img/httpierror2.jpg",
        Help_Title = T"PPP Authentication Failure",
       text = {

            { format("<p>%s</p>",T"The status of your connection is shown by the Internet light.")},
            { format("<div><div class='httpi_main_left'><strong>%s</strong></div>:  %s</div>",T"OFF", T"No Internet connection" )},
            { format("<div><div class='httpi_main_left'><strong>%s</strong></div>:  %s</div>",T"RED", T"Failed to establish Internet connection" ) },
            { format("<div><div class='httpi_main_left'><strong>%s</strong></div>:  %s</div>",T"SOLID GREEN", T"Internet connected, no activity" ) },
            { format("<div><div class='httpi_main_left'><strong>%s</strong></div>:  %s</div>",T"FLASHING GREEN", T"Internet connected, sending/receiving data" ) },
            { "<br/>"},
            { format("<p>%s %s %s.</p>", T"Your", router , T"is trying to connect to the Internet but is reporting your username and password are incorrect:" )},
            { format("<div class=\"httpi_button\"><div  class=\"btn btn-primary\" id=\"reenterppp\" >%s</div></div><br/>",T"Change Internet Details")},
            { format("<div class=\"httpi_button\"><div  class=\"btn btn-primary\" id=\"resetreboot\" >%s</div></div><br/>",T"Restart or Reset")},
            { format("<div class=\"httpi_button\"><div  class=\"btn btn-primary\" id=\"main\" >%s</div></div><br/>",T"Main User Interface")},
            { format("<p>%s %s %s</p>",T"If you continue to see this page please contact", isp, T"for assistance.")},
            
        },
    },
    Connecting={
        img = "/img/httpierrornetwork.jpg",
        Help_Title = T"PPP Trying to Connect",
        text = {

            { format("<p>%s</p>",T"The status of your connection is shown by the Internet light.")},
            { format("<div><div class='httpi_main_left'><strong>%s</strong></div>:  %s</div>",T"OFF", T"No Internet connection" )},
            { format("<div><div class='httpi_main_left'><strong>%s</strong></div>:  %s</div>",T"RED", T"Failed to establish Internet connection" ) },
            { format("<div><div class='httpi_main_left'><strong>%s</strong></div>:  %s</div>",T"SOLID GREEN", T"Internet connected, no activity" ) },
            { format("<div><div class='httpi_main_left'><strong>%s</strong></div>:  %s</div>",T"FLASHING GREEN", T"Internet connected, sending/receiving data" ) },
            { "<br/>"},
            { format("<p>%s %s %s.</p>", T"Your", router , T"is trying to connect to the Internet but is reporting the remote system is not available" )},
            { format("<p>%s %s</p>", T"Please wait a few seconds then click the try again button below, it may be necessary to restart or reset your", router )},
            { format("<div class=\"httpi_button\"><div  class=\"btn btn-primary\" id=\"reconnect\" >%s</div></div><br/>",T"Try again")},
            { format("<div class=\"httpi_button\"><div  class=\"btn btn-primary\" id=\"resetreboot\" >%s</div></div><br/>",T"Restart or Reset")},
            { format("<p>%s %s.</p>",T"If you continue to see this page there is an issue located between your router and the equipment of", isp)},
            
        },
    },
    Error={
        img = "/img/httpierrornetwork.jpg",
        Help_Title = T"Unknown Error",
        text = {
            { format("<p>%s</p>",T"The status of your connection is shown by the Internet light.")},
            { format("<div><div class='httpi_main_left'><strong>%s</strong></div>:  %s</div>",T"OFF", T"No Internet connection" )},
            { format("<div><div class='httpi_main_left'><strong>%s</strong></div>:  %s</div>",T"RED", T"Failed to establish Internet connection" ) },
            { format("<div><div class='httpi_main_left'><strong>%s</strong></div>:  %s</div>",T"SOLID GREEN", T"Internet connected, no activity" ) },
            { format("<div><div class='httpi_main_left'><strong>%s</strong></div>:  %s</div>",T"FLASHING GREEN", T"Internet connected, sending/receiving data" ) },
            { "<br/>"},
            { format("<p>%s</p>", T"Please check the following, it will help determine the problem with your connection and possibly avoid the cost of an engineer visit." )},
            { "<ol>"},
            { format("<li>%s %s %s %s %s</li>", T"If this is the first time you have set up your", router , T"please check that your Broadband service has been activated.", isp:gsub("^%l", string.upper), T"will have sent you the date on which your Broadband service will be ready." )},
            { format("<li>%s %s</li>", T"Try rebooting the", router )},
            { format("<li>%s %s</li>", T"Try factory resetting the", router )}, 
            { "</ol>"},
            { format("<p>%s %s</p>",T"Once the Internet light is SOLID GREEN press the button below, it may be necessary to restart or reset your", router)},
            { format("<div class=\"httpi_button\"><div  class=\"btn btn-primary\" id=\"retry\" >%s</div></div><br/>",T"Try Again")},
            { format("<div class=\"httpi_button\"><div  class=\"btn btn-primary\" id=\"resetreboot\" >%s</div></div><br/>",T"Restart or Reset")},
            { format("<p>%s</p>",T"If the Broadband light continues to flash there may be a problem with your home wiring. In this case disconnect all telephone extensions and connect your router to the master socket using one of the supplied DSL Filters.")},
       
            
        },
    },
    LocalDis={
        img = "/img/httpierror2.jpg",
        Help_Title = T"Not Connected",
        text = {
            { format("<p>%s</p>",T"The status of your connection is shown by the Internet light.")},
            { format("<div><div class='httpi_main_left'><strong>%s</strong></div>:  %s</div>",T"OFF", T"No Internet connection" )},
            { format("<div><div class='httpi_main_left'><strong>%s</strong></div>:  %s</div>",T"RED", T"Failed to establish Internet connection" ) },
            { format("<div><div class='httpi_main_left'><strong>%s</strong></div>:  %s</div>",T"SOLID GREEN", T"Internet connected, no activity" ) },
            { format("<div><div class='httpi_main_left'><strong>%s</strong></div>:  %s</div>",T"FLASHING GREEN", T"Internet connected, sending/receiving data" ) },
            { "<br/>"},
            { format("<p>%s %s %s</p>", T"Your", router, T"is not connected." )},
            { format("<p>%s</p>", T"Please check the following, it will help determine the problem with your connection and possibly avoid the cost of an engineer visit." )},
            { format("<div class=\"httpi_button\"><div  class=\"btn btn-primary\" id=\"reconnect\" >%s</div></div><br/>",T"Try to Reconnect")},
            { format("<div class=\"httpi_button\"><div  class=\"btn btn-primary\" id=\"resetreboot\" >%s</div></div><br/>",T"Restart or Reset")},
            { format("<p>%s %s %s</p>",T"If you continue to experience connection problems contact", isp, T"for assistance.")},
            
            
        },
    },
    NotCon={
        img = "/img/gateway.png",
        Help_Title = T"PPP Not Configured", 
        text = nil,
    },
    OK={
        img = "/img/httpierrornetwork.jpg",
        Help_Title = T"Internet Connected",
        text = {
            { format("%s",T"You are connected to the Internet.")},
            { format("<p>%s (%s).</p></br>", T"Please click the button below to attempt to reconnect to the originally requested web site", redirected_URL )},
            { format("<div class=\"httpi_button\"><div  class=\"btn btn-primary\" id=\"retry\" >%s</div></div><br/><br/>",T"Try to Reload")},
            { format("<p>%s</p>",T"If you continue to see this page please first try to close your browser and reopen a new one as the browser can remember details that stop this reload from working.")},
            { format("<p>%s %s %s</p>",T"If this fails contact", isp, T"for assistance.")},
            { format("<p>%s %s %s</p>",T"For the main", router, T"interface click below:")},
            { format("<div class=\"httpi_button\"><div  class=\"btn btn-primary\" id=\"main\" >%s</div></div><br/>",T"Main User Interface")},
            
        },
    },
}


             