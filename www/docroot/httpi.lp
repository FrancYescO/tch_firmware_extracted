--pretranslated: do not change this file

--[[
   HTTP Page 
   A:David Relf
   E:david.relf@technicolor.com
   
   Page is to control the redirect after a WAN down event
   
   V1.0 - Initial version with Change control
]]
local format, match, sub= string.format, string.match, string.sub
local print= ngx.print
local TIMERJS = 5000
-- Enable localization
gettext.textdomain('webui-core')
local proxy = require("datamodel")
local session = ngx.ctx.session
local ui_helper = require("web.ui_helper")
local content_helper = require("web.content_helper")
local httpilua = require("httpi_info_data")
local post_helper = require("web.post_helper")
local message_helper = require("web.uimessage_helper")
--Check for logo change
local lfs = require("lfs")
local imgpath = "/img/"
if lfs.attributes("/www/docroot/img/custom/logo.gif", "mode") == "file" then
  imgpath = "/img/custom/"
end

function split(x, sep)
        local sep, fields = sep or ":", {}
        local pattern = format("([^%s]+)", sep)
        x:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end

local cui = {
	version = "uci.version.version.@version[0].version",
	timestamp = "uci.version.version.@version[0].timestamp",
}
content_helper.getExactContent(cui)

local year= cui.timestamp
local current_year = (string.sub(year,1,4))

local version = ""
local tmpsplit = split(cui.version, "-")
if #tmpsplit > 1 then
   version = format("%s-%s",tmpsplit[1],tmpsplit[2])
end

function AJAX(x)
   local L2, L2_status= "Error", ""
   local L3, L3_Type, L3_Status = "Error", "", ""
   local ppp_state_map = {
      disabled = T"Disabled",
      disconnecting = T"Disconnecting",
      connected = T"Connected",
      connecting = T"Connecting",
      disconnected = T"Connecting",
      authenticating = T"Connecting",
      error = T"Error",
      AUTH_TOPEER_FAILED = T"Auth Failed",
      NEGOTIATION_FAILED = T"Neg Failed",
      FATAL_ERROR = T"Error",
      USER_REQUEST = T"Disconnected"
   }
   local ajaxcontent = {
     eth4 = "sys.eth4.Link",
     xdsl_enabled = "sys.class.xdsl.@line0.Enable",
     xdsl_status = "sys.class.xdsl.@line0.Status",
     xdsl_type = "sys.class.xdsl.@line0.ModulationType",
     wan_ppp_status = "rpc.network.interface.@wan.ppp.state",
     wan_ppp_error = "rpc.network.interface.@wan.ppp.error",
     wan_ip = "rpc.network.interface.@wan.ipaddr",
     wan_enabled = "rpc.network.interface.@wan.up",
     wan_lower = "rpc.network.interface.@wan.ppp.ll_intf",
     wan_proto = "uci.network.interface.@wan.proto",
     wan_auto = "uci.network.interface.@wan.auto",
     wan_sensing = "uci.env.custovar.WS",
     wan_iface = "uci.network.interface.@wan.ifname",
     vlan_ifname = "uci.network.device.@vlan_wan.ifname",
     ppp = "rpc.network.interface.@wan.ppp.ll_intf",
   }
   content_helper.getExactContent(ajaxcontent)
   
   local pppParams = {
      uci_wan_auto = "uci.network.interface.@wan.auto",
      uci_wan_username = "uci.network.interface.@wan.username",
      uci_wan_password = "uci.network.interface.@wan.password",
  }
  content_helper.getExactContent(pppParams)
   --L2 Start
   local DSL = T"Disconnected"
   if     ajaxcontent.xdsl_enabled   == "0" then DSL = T"Disabled" 
   elseif ajaxcontent.xdsl_status    == "Initializing" then DSL = T"Synchronising" 
   elseif ajaxcontent.xdsl_status    == "Up" then DSL = T"Connected"
   else DSL = T"Disconnected"
   end
   local ETH = ajaxcontent.eth4 or "0"
   if ETH == "1" then
      ETH = T"Connected"
   else
      ETH = T"Disconnected"
   end 
   local L2_Types = {
      ptm0 = DSL,
      atm0 = DSL,
      eth4 = ETH,
   }
   
  -- if ajaxcontent.wan_lower ~= "" then L2 = L2_Types[ajaxcontent.wan_lower:untaint()] end
  
  
  local iface = ajaxcontent.wan_iface
  local ppp = ajaxcontent.ppp
  if iface == "wan_vlan" then
      iface = ajaxcontent.vlan_ifname
  elseif iface == "pppoe-wan" or iface == "pppoa-wan" then
      iface = ppp
      
  end
  
  local L2 = DSL
  if  iface == "eth4" then 
      L2 = ETH
  end
  
  
  
   --L2 Finish
   --L3 Start
   local L3_Protos = {
      pppoe = "PPP",
      pppoa = "PPP",
      dhcp = "IP",
      static = "IP",
   }
   if ajaxcontent.wan_proto ~= "" then L3_Type = L3_Protos[ajaxcontent.wan_proto:untaint()] end
   if ajaxcontent.wan_enabled == "0" or ajaxcontent.wan_auto == "0" then
      L3 = T"Disabled"
   elseif L3_Type == "PPP" then
       local ppp_status = ajaxcontent.wan_ppp_status:untaint()
        
       local ppp_error = ajaxcontent.wan_ppp_error:untaint()
        ppp_status = ppp_state_map[ppp_status]   
        if ppp_state_map[ppp_error] and ppp_status ~= T"Disconnected" then
             ppp_status = ppp_state_map[ppp_error]
        end
        if pppParams.uci_wan_username == "" then 
            PPP_Status = T"Not Configured"
        end
        L3 = ppp_status
   elseif L3_Type == "IP" then 
        L3 = T"Disconnected"
        ngx.log(ngx.ERR, format("L2 : %s",L2))  
        ngx.log(ngx.ERR, format("IP : %s",ajaxcontent.wan_ip))
        
        if ajaxcontent.wan_ip:len() > 7  then
         L3 = T"Connected"
        end
        
   end
    --ngx.log(ngx.ERR, format("ppp_error= %s",ppp_error))
    if tonumber(ajaxcontent.wan_sensing) < 1 then
      L3 = T"Auto WAN Active"
    end
 --ngx.log(ngx.ERR, format("L3= %s",L3))
  local html = {}
  html[#html+1]="{"
  html[#html+1]=format("\"L3\":\"%s\"",L3 or T"Error")
  html[#html+1]=","
  html[#html+1]=format("\"L2\":\"%s\"",L2 or T"Error")
  html[#html+1]=","
  html[#html+1]=format("\"L3_Type\":\"%s\"",L3_Type or T"Error")
  html[#html+1]=","
  html[#html+1]=format("\"WS\":\"%s\"",ajaxcontent.wan_sensing)
  html[#html+1]="}"
  print(html)
   
end


local info = {
    uci_URL = "uci.env.custovar.URL",
    
}
content_helper.getExactContent(info)
local redirected_URL = "www.technicolor.com"
if info.uci_URL and info.uci_URL ~= "" then redirected_URL = info.uci_URL end
if redirected_URL == "dsldevice.lan" then redirected_URL = "www.technicolor.com" end

local args = ngx.req.get_uri_args()
for key, val in pairs(args) do
  if key=="relf"  then
   AJAX(val)
   ngx.exit(ngx.HTTP_OK)
   
  elseif key == "url" then
       redirected_URL = format("%s",val)
       
  end
end



local clock = os.clock
function sleep(n)  -- seconds
  local t0 = clock()
  while clock() - t0 <= n do end
end
local mapParams = {
    uci_wan_auto = "uci.network.interface.@wan.auto",
    uci_wan_username = "uci.network.interface.@wan.username",
    uci_wan_password = "uci.network.interface.@wan.password",
}

-- Shortcuts to validation helpers to make lines shorter
local gVIPIL = post_helper.getValidationIfPropInList
local gCV = post_helper.getConditionalValidation
local gVIES = post_helper.getValidateInEnumSelect
local vB = post_helper.validateBoolean
local vNES = post_helper.validateNonEmptyString
local vSII = post_helper.validateStringIsIP
local vSIP = post_helper.validateStringIsPort
local gVP = post_helper.getValidationPassword
local gOV = post_helper.getOptionalValidation

local function validateUsername (value, postdata)
  local err,msg = vNES(value)
  if not err then
    return err,msg
  end

  local content_uci = {
    wan_domain = "uci.network.interface.@wan.domain",
  }
  content_helper.getExactContent(content_uci)

  if content_uci["wan_domain"] ~= "" then
    if string.find(value, "@") then
      return nil, T"Invalid username, domain locked"
    end
    postdata["uci_wan_username"] = format('%s@%s', value, content_uci["wan_domain"])
  end

  return true
end

local function isWanEnabled(value, object, key)
    return object["uci_wan_auto"] ~= "0"
end
      

-- Validation allows empty values if wan access disabled but will stil check for validity if the parameter is set
-- if wan is enabled then it checks for validaty anyway
local mapValid = {
    uci_wan_auto = vB,
    uci_wan_username = gCV(isWanEnabled, validateUsername, gOV(validateUsername)),
    uci_wan_password = gCV(isWanEnabled, gVP(vNES), gVP()),
}

local content, helpmsg = post_helper.handleQuery(mapParams, mapValid)
-- End POST process



if ngx.req.get_method() == "POST" then
  local post_args = ngx.req.get_post_args()
  if post_args.do_signout then
    ngx.ctx.session:logout()
    -- Now we redirect to / until we find a better solution
    -- Otherwise, the current page might be rendered while the default user is not allowed to see it
    -- since the access was checked for the user "before" logging out
    -- TODO: find a more elegant solution, in session module?
    ngx.redirect("/");
  end
  
  if post_args.PPPREDIRECT == "1" then
      session:store("modal2load","internet-modal.lp")
      session:store("URL",post_args.URL)
      ngx.redirect("/httpi_redirect.lp")

  end
  if post_args.RESETREDIRECT == "1" then
      session:store("modal2load","reset-reboot-modal.lp")
      session:store("URL",post_args.URL)
      ngx.redirect("/httpi_redirect.lp")

  end
  if post_args.RETRY == "1" or post_args.RECONNECT == "1"  then
      dsl_state = format("%s", proxy.get("sys.class.xdsl.@line0.Enable")[1].value) -- remove tainting
      if dsl_state == "0" then
         proxy.set("sys.class.xdsl.@line0.Enable", "1")
      end
      proxy.set("uci.network.interface.@wan.auto", "1")
      proxy.apply()
      local wan_state_loop = format("%s", proxy.get("rpc.network.interface.@wan.up")[1].value)
      for i=1,10,1 do
         ngx.log(ngx.ERR, format("%s - Loop: %s",i,wan_state_loop))
         if wan_state_loop == "1" then 
            ngx.log(ngx.ERR, T"Redirecting in 15 seconds")
            sleep(15)
            
            ngx.redirect(format("http://%s", redirected_URL)) 
         end
         sleep(1)
         wan_state_loop = format("%s", proxy.get("rpc.network.interface.@wan.up")[1].value)
      end
      
      
  end
   if post_args.action == "SAVE" then
      sleep(15)
      ngx.redirect(format("http://%s", redirected_URL))
   end
  
  
end





local cui = {
    nsplink = "uci.web.uiconfig.@uidefault.nsplink",
    advanced = "uci.web.uiconfig.@uidefault.alwaysadvanced",
}
content_helper.getExactContent(cui)

local content_uci = {
  wan_proto = "uci.network.interface.@wan.proto",
  wan_domain = "uci.network.interface.@wan.domain",
}
content_helper.getExactContent(content_uci)


local staticcontent = {
   version = "uci.version.version.@version[0].version",
   product = "uci.version.version.@version[0].product",
   eth4 = "sys.eth4.Link",
   xdsl_enabled = "sys.class.xdsl.@line0.Enable",
   xdsl_modulation = "sys.class.xdsl.@line0.ModulationType",
   xdsl_status = "sys.class.xdsl.@line0.Status",
   wan_mode = "uci.network.interface.@wan.proto",
   wan_enabled = "uci.network.interface.@wan.auto",
   wan_lower = "rpc.network.interface.@wan.ppp.ll_intf",
   wan_status = "rpc.network.interface.@wan.ppp.state",
   wan_error = "rpc.network.interface.@wan.ppp.error",
   wan_rpc_ip = "rpc.network.interface.@wan.ipaddr",
   wan_rpc_enabled = "rpc.network.interface.@wan.up",
   wan_sensing = "uci.env.custovar.WS",
}

content_helper.getExactContent(staticcontent)




local version = ""
local tmpsplit = split(staticcontent.version, "-")
if #tmpsplit > 1 then
   version = format("%s-%s",tmpsplit[1],tmpsplit[2])
end

local wan_type_map = {
    pppoa = T"PPPoA",
    pppoe = T"PPPoE",
    dhcp = T"DHCP",
    static = T"Static",
}

if  wan_type_map[staticcontent.wan_mode:untaint()] then
   staticcontent.wan_mode = wan_type_map[staticcontent.wan_mode:untaint()]
else
   staticcontent.wan_mode = T"Error: Unknown WAN Type"
end
local ppp_state_map = {
    disabled = T"Disabled",
    disconnecting = T"Disconnecting",
    connected = T"Connected",
    connecting = T"Connecting",
    disconnected = T"Connecting",
    error = T"Error",
    network = T"Network Error",
    AUTH_TOPEER_FAILED = T"Auth Failed",
    NEGOTIATION_FAILED = T"Neg Failed",
    FATAL_ERROR = T"Error"
}


local int_status, int_error = "", ""
if staticcontent.wan_enabled ~= "0" then
  int_status = staticcontent.wan_status:untaint()
  int_error = staticcontent.wan_error:untaint()
  if staticcontent.wan_mode == T"PPPoA" or staticcontent.wan_mode == T"PPPoE" then

    if int_status == "" or int_status == "authenticating" or int_status == "connecting" then
      int_status = T"Connecting"
    else
      int_status = ppp_state_map[int_status]  
      
    end  
    if ppp_state_map[int_error] and int_status ~= T"Disabled" then
         int_status = ppp_state_map[int_error]
    end
  
  end     
  
  
  
else
  -- WAN disabled
  int_status = T"Disabled"
end



local dslmode =sub(staticcontent.xdsl_modulation, 1, 4)
local conf_phy = ""

if staticcontent.wan_lower == "atm0" then
   conf_phy = "xDSL"
   staticcontent.wan_status = staticcontent.xdsl_status
elseif staticcontent.wan_lower == "ptm0" then
   conf_phy = "xDSL"
   staticcontent.wan_status = staticcontent.xdsl_status
elseif staticcontent.wan_lower == "eth4" then
   conf_phy = "ETH"
   staticcontent.wan_status = staticcontent.eth4
else
   conf_phy = "BRIDGE"
end

--[[
if staticcontent.wan_status == "" or not staticcontent.wan_status then 
   staticcontent.wan_status = "Unknown"
end

if staticcontent.wan_error == "" then 
   staticcontent.wan_error = "None"
end
]]



local html = {}
local tmpstr = T"Down"
if staticcontent.eth4 == "1" then
 tmpstr = T"Up"
else
  -- check if xDSL is up
local dsl_tmpstr = staticcontent.xdsl_status:untaint()
   if  dsl_tmpstr == "Up" then tmpstr = T"Up" end
end
--TEST Triggers
--tmpstr = T"Down" -- Force WAN Down
--conf_phy = "ETH" -- ETH or xDSL
--
--[[
html[#html + 1] = format(T"Current L2 Mode: %s",tmpstr)
html[#html + 1] = "<BR/>"
html[#html + 1] = format(T"Configured L2 Mode: %s",conf_phy)
html[#html + 1] = "<BR/>"
html[#html + 1] = format(T"Current L3 Type: %s",staticcontent.wan_mode)
html[#html + 1] = "<BR/>"
html[#html + 1] = format(T"Current L3 Status: %s",int_status)
html[#html + 1] = "<BR/>"
html[#html + 1] = format(T"Current L3 Error: %s",staticcontent.wan_error)
html[#html + 1] = "<BR/>"
html[#html + 1] = format(T"Current L3 Enabled: %s",staticcontent.wan_enabled)
]]
local Status_Name = "xDSL_E1"
local Help_Title = "DSL Issue 1"

if staticcontent.wan_sensing == "0"  then  
   Status_Name = "WS" 
elseif tmpstr ~= "Up" then
--L2
   if conf_phy == "ETH" then
      Status_Name = "ETH_E1"
   else
      Status_Name = "xDSL_E1"
   end 
   int_status = T"Down"
else
--L3
   if staticcontent.wan_mode == T"PPPoE" or staticcontent.wan_mode == T"PPPoA" then 
     
     if content.uci_wan_username == "" then
         Status_Name = "NotCon"
     elseif int_status == T"Connecting" then
         Status_Name = "Connecting" 
     elseif int_status == T"Disconnected" or 
          int_status == T"Disconnecting" or 
          int_status == T"Disabled" or
          staticcontent.wan_enabled == "0" then
          Status_Name = "LocalDis"
     elseif int_status == T"Auth Failed" then 
        Status_Name = "PPPAuth"
     elseif int_status == T"Neg Failed" then 
        Status_Name = "Connecting"   
        
     elseif int_status == T"Connected" then 
        --ngx.redirect(format("http://%s", redirected_URL)); 
        Status_Name = "OK" 
     else
        Status_Name = "Error"
        
     end
   elseif staticcontent.wan_mode == T"DHCP" or  staticcontent.wan_mode == T"Static" then
      if staticcontent.wan_rpc_enabled == "0" then 
         Status_Name = "LocalDis"
      elseif staticcontent.wan_rpc_ip:len() > 7 then
         Status_Name = "OK" 
      else
         Status_Name = "Error"
      end
   end
end

 --[[
html[#html + 1] = "<BR/>"
html[#html + 1] = format(T"WAN Sensing Status: %s",staticcontent.wan_sensing)


html[#html + 1] = "<BR/>"
html[#html + 1] = format(T"Status_Name: %s",Status_Name)

html[#html + 1] = "<BR/>"
html[#html + 1] = format(T"Help_Title: %s",Help_Title)

html[#html + 1] = "<BR/>"
html[#html + 1] = format(T"Version: %s",staticcontent.version)


html[#html + 1] = "<BR/>"
html[#html + 1] = redirected_URL
html[#html + 1] = "<BR/>"
     ]]
--print(html)




print('\
<!DOCTYPE HTML>',
string.format('<html lang="%s">', gettext.language()),
  '<head>\
    <meta http-equiv="X-UA-Compatible" content="IE=Edge,chrome=1">\
    <meta name="viewport" content="width=device-width, initial-scale=1.0">\
    <meta charset="UTF-8">\
    <meta name="CSRFtoken" content="', ngx.ctx.session:getCSRFtoken(), '">\
    <meta name="Advanced" content="', cui.advanced, '">\
    <link href="/css/gw.css" rel="stylesheet">\
    <link href="/css/responsive.css" rel="stylesheet">\
    <link href="/css/color.css" rel="stylesheet">\
    <link href="/css/relf.css" rel="stylesheet">\
    <link href="/css/httpi.css" rel="stylesheet">\
    <link href="/css/loader.css" rel="stylesheet">\
    <!--[if IE 7]><link rel="stylesheet" href="/css/font-awesome-ie7.css"><![endif]-->\
    <script src="/js/main-min.js" ></script>\
    <!--[if lt IE 9]> <script src="/js/media-min.js"></script> <![endif]-->\
    <title>', T"Gateway", '</title>\
  </head>\
<script type=\'text/javascript\'>\
function getInfo()\
{\
  var url = \'/httpi.lp\';\
  var checktimer = ', TIMERJS, ';\
  var L2 = $("#L2").html();\
  var L3 = $("#L3").html();\
  $.getJSON(url,  {relf: "1"})\
   .done(function( data ) {\
\
      var newL2 = data.L2;\
      $("#L2").html(data.L2);\
      var newL3 = data.L3;\
      $("#L3").html(data.L3);\
\
      if ((newL2 == "', T"Connected", '") && ( newL3  == "', T"Connected", '")) {\
         //alert("All is OK");\
      }\
   })\
   .error(function() {\
   })\
   .always(function() {\
          window.setTimeout(function () {getInfo();}, checktimer);\
    });\
}\
\
\
function Popup(x){\
        var moveLeft = 10;\
        var moveRight = -390;\
        var moveDown = -50;\
        var header = \'',ui_helper.createCardHeader(T"Processing", "", "",""), '\';\
       $("body").append(\'<div class=\"popUpBG\"></div>\');\
       $("body").append(\'<div id="popUp"  class="popUp smallcard span3">\'+header+\'<div id="Poptxt" class="content"></div>\');\
       x = x.concat(\'<br/><div id="spinner" class="spinner" align="center"><div class="spinner3"><div class="rect1"></div><div class="rect2"></div><div class="rect3"></div><div class="rect4"></div><div class="rect5"></div></div></div>\');\
       $("#Poptxt").html(x);\
       $d = $("#popUp");\
       var pagewidth = $("body").width();\
       var thiswidth = $d.width();\
       var center = (pagewidth / 2) - ((thiswidth - 20) / 2);\
       var width = window.innerWidth || document.documentElement.clientWidth;\
       $d.css({\'left\': center,  \'margin\': \'0px\'}).appendTo(\'body\');\
       $(\'html, body\').css({\'overflow\': \'hidden\',\'height\': \'100%\'});\
    }\
   $(function() {\
      $(\'#redirect_URL\').html(\'', redirected_URl,'\')\
      $("div").removeClass("tooLongTitle");\
      $(document).on("click","#retry",function(a){\
         a.preventDefault();\
         a=$("<form>",{action:"/httpi.lp?url=', redirected_URL,'",method:"post"})\
         .append($("<input>",{name:"RETRY",value:"1",type:"hidden"}))\
         .append($("<input>",{name:"URL",value:"', redirected_URL, '",type:"hidden"}))\
         .append($("<input>",{name:"CSRFtoken",value:$("meta[name=CSRFtoken]").attr("content"),type:"hidden"}));\
         $("body").append(a);\
         Popup("', T"Retrying your connection", '...",a);\
         a.submit()});\
      $(document).on("click","#reconnect",function(a){\
         a.preventDefault();\
         a=$("<form>",{action:"/httpi.lp?url=', redirected_URL, '",method:"post"})\
         .append($("<input>",{name:"RECONNECT",value:"1",type:"hidden"}))\
         .append($("<input>",{name:"CSRFtoken",value:$("meta[name=CSRFtoken]").attr("content"),type:"hidden"}));\
         $("body").append(a);\
         Popup("', T"Attempting to reconnect",' ",a);\
         a.submit()});\
       $(document).on("click","#saveform",function(a){\
         Popup("', T"Applying the new settings", '",a);\
         $("form#NoConf").submit()});\
       $(document).on("click","#main",function(){\
         Popup("', T"Redirecting to the main user interface", '");\
         location.replace("/");\
       });\
       $(document).on("click","#reenterppp",function(a){\
         a.preventDefault();\
         a=$("<form>",{action:"/httpi.lp?url=', redirected_URL, '",method:"post"})\
         .append($("<input>",{name:"PPPREDIRECT",value:"1",type:"hidden"}))\
         .append($("<input>",{name:"URL",value:"', redirected_URL, '",type:"hidden"}))\
         .append($("<input>",{name:"CSRFtoken",value:$("meta[name=CSRFtoken]").attr("content"),type:"hidden"}));\
         $("body").append(a);\
         Popup("', T"Redirecting to the Internet Configuration", '",a);\
         a.submit();\
        });\
        $(document).on("click","#resetreboot",function(a){\
         a.preventDefault();\
         a=$("<form>",{action:"/httpi.lp?url=', redirected_URL, '",method:"post"})\
         .append($("<input>",{name:"RESETREDIRECT",value:"1",type:"hidden"}))\
         .append($("<input>",{name:"URL",value:"', redirected_URL, '",type:"hidden"}))\
         .append($("<input>",{name:"CSRFtoken",value:$("meta[name=CSRFtoken]").attr("content"),type:"hidden"}));\
         $("body").append(a);\
         Popup("', T"Redirecting to the Restart / Reset Options", '",a);\
         a.submit();\
        });\
       getInfo();\
   });\
</script>\
<body>\
  <div class="feedback">\
  </div>\
    <div class="container">\
    <div class="row">\
      <div class="header span12">\
        <a href="', cui.nsplink, '" target="_blank"><img class="logo" src="', imgpath, 'logo.gif"></a>');
        local session = ngx.ctx.session
        local html = {}
        html[#html + 1] = [[<div class="pull-right">]]
        if session:isdefaultuser() then
            html[#html + 1] = '<a href="login.lp" class="btn" id="signin">'
            html[#html + 1] = T"Sign in"
            html[#html + 1] = '</a>'
        else
            html[#html + 1] = [[          <div class="btn-group" id="logged">
                    <button class="btn"> ]]
            html[#html + 1] = session:getusername()
            html[#html + 1] = [[ </button>
                    <button class="btn dropdown-toggle" data-toggle="dropdown">
                      <span class="caret"></span>
                    </button>
                    <ul class="dropdown-menu pull-right">
                      <li><a tabindex="-1" href="/password.lp" id="changepass">]]
            html[#html + 1] = T"Change my password"
            html[#html + 1] = [[ </a></li><li class="divider"></li><li><a tabindex="-1" href="/" id="usual"> ]]
            html[#html + 1] = T"User Interface"
            html[#html + 1] = [[ </a></li><li class="divider"></li><li><a tabindex="-2" href="/" id="signout"> ]]
            html[#html + 1] = T"Sign out"
            html[#html + 1] = [[</a></li></ul></div>]]
        end
        html[#html + 1] = [[</div>]]
        html[#html + 1] = [[<div class="pull-right">]]
        html[#html + 1] = ui_helper.createLanguageSelect('webui-core', gettext.language())
        html[#html + 1] = [[</div>]]
        print(html,'\
      </div>\
    </div>\
    <div class="row">\
      <div class="span4">\
        <div class="smallcard httpi_card_Status">\
          ', ui_helper.createCardHeader(T"Status", "", "",""), '\
          <div class="httpi_bg bg_small" data-bg-text=""><!--&#xf05a;-->\
            <div class="content httpi_content">');
              local spacer = "&nbsp;&nbsp;&nbsp;"
              html = {}
              html[#html + 1] = format("<div><div class='httpi_left'><strong>%s</strong></div>: ",T'Broadband')
              html[#html + 1] = format("<span id=\"L2\">%s</span>", T"Loading") 
              html[#html + 1] = "</div>"
              if Status_Name == "WS" then  
                  html[#html + 1] = format("<div><div class='httpi_left'><strong>%s</strong></div>:  %s</div>",T'Sensing', httpilua[Status_Name].WS )
              else
                  html[#html + 1] = format("<div><div class='httpi_left'><strong>%s</strong></div>: <span id=\"L3\">%s</span></div>",T'Internet', T"Loading" )
              end
              html[#html + 1] =  format("<div class=\"thumb\"><img src=\"%s\" class=\"img-rounded \"></div>",httpilua[Status_Name].img)
              print(html,'\
            </div>\
          </div>\
        </div>\
      </div>\
      <div class="span8">\
        <div class="smallcard httpi_card_large">\
          ', ui_helper.createCardHeader(format("%s - %s",T"Help", httpilua[Status_Name].Help_Title), "", "",""), '\
          <div class="httpi_bg bg_large" data-bg-text="&#xf0f9;">\
            <div class="content httpi_content">');
                        local text = httpilua[Status_Name].text
                        if text then
                           print(httpilua[Status_Name].text)
                        else
                           local bits = {
                                ISP = "uci.env.custovar.ISP",
                                prod_name = "uci.env.var.prod_name",
                                prod_number = "uci.env.var.prod_number",
                            }
                            content_helper.getExactContent(bits)
                            local router, isp = format("%s%s", bits.prod_name, bits.prod_number), bits.ISP:untaint()
                            print('<form id="NoConf" class="form-horizontal" method="post" action="/httpi.lp?url=', redirected_URL, '">\
                               <input name="CSRFtoken" value="', ngx.ctx.session:getCSRFtoken(), '" type="hidden">\
                               <input name="action" value="SAVE" type="hidden">\
                               <input name="uci_wan_auto" value="1" type="hidden">');
                           local html = {}
                           html[#html+1]=ui_helper.createMessages(message_helper.popMessages())
                           html[#html+1]=format("<p>%s %s %s</p>",T"Your", router, T"has not been configured")
                           html[#html+1]=format("<p>%s (%s %s)</p>",T"Please configure the details below", isp:gsub("^%l", string.upper), T"will have sent these to you" )
                           html[#html+1]="<div class=\"inputblock\">"
                           local class_username = {
                                  input = {
                                  maxlength= "128",
                                  class = "span6",
                                }
                              }
                           html[#html + 1] = "<div class='control-group'><label class='control-label'>" .. T"Username" .. "</label>"
                           html[#html + 1] = ui_helper.createSimpleInputText("uci_wan_username", content["uci_wan_username"], class_username, helpmsg["uci_wan_username"])
                           local class_password = class_username
                           html[#html + 1] = ui_helper.createInputPassword(T"Password", "uci_wan_password", content["uci_wan_password"], class_password , helpmsg["uci_wan_password"])
                           html[#html+1]="</div>"
                           html[#html+1] = format("<button type=\"submit\" id=\"saveform\" class=\"btn\">%s</button>",T"Submit")
                           print(html,'\
                           </form>');
                        end
                 print('\
          </div>\
        </div>\
      </div>\
    </div>\
    </div>\
    <div class="row">\
	    <div class="copyright span12">\
		    <p>&copy; Technicolor ',current_year, '</p>\
		    <p>', format(T"Software Version: %s",version), '</p>\
   	  </div>\
    </div>\
  </div>\
</body>\
</html>');
