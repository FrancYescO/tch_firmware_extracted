--pretranslated: do not change this file
 

gettext.textdomain('webui-core')
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local proxy = require("datamodel")
local ipairs, pairs, ngx, string, tonumber = ipairs, pairs, ngx, string, tonumber
local match = string.match
local usbInfo = content_helper.convertResultToObject("sys.usb.device.", proxy.get("sys.usb.device."))
local deviceContent, error
local printerIndex

local deviceInfo = {
  shareAll      =  "uci.samba.samba.filesharing",
  printerShare  = "uci.samba.sambashare.@printers.enabled",
}
local deviceValid = {
  shareAll     = post_helper.validateBoolean,
  printerShare = post_helper.validateBoolean,
}
deviceContent, error = post_helper.handleQuery(deviceInfo, deviceValid)

if ngx.req.get_method() == "POST" then
 if not next(error) then
    ngx.print('<input type="hidden" id="post_status" value="success">')
  else
    ngx.print('<input type="hidden" id="post_status" value="error">')
  end
end
local gatewayIP = {
  IPAddress = "uci.network.interface.@lan.ipaddr",
}
content_helper.getExactContent(gatewayIP)
  ngx.print('\
\
<div id="content-reset-wrap" class="content-sharing"><h1>\
<span>');  ngx.print(T"Sharing"); ngx.print('</span></h1>\
<h2>\
<span>');  ngx.print(T"Here you can set your device sharing"); ngx.print('</span></h2>\
\
<div class="h3-wrapper-content">\
  <div class="h3-inside-content">\
    <div class="h3-content">\
	  <div class="vdf-row">\
		<div class="left">\
		  <h3>\
		  <span>');  ngx.print(T"Hard Drives"); ngx.print('</span>\
          </h3>\
		</div>\
	  </div>\
	  <div class="vdf-row">\
		<div class="left">\
		  <span>');  ngx.print(T"Share All"); ngx.print('</span>				</div>\
		  <div class="right">\
		    <div id="hdButton" class="button ');  if deviceContent["shareAll"] == "1" or deviceContent["shareAll"] == "" then   ngx.print(' button-on ');  else  ngx.print(' button-off ');  end  ngx.print('"></div>\
		</div>\
	  </div>\
       ');  for _, data in ipairs(usbInfo) do
	        for key in pairs(data) do
              local interfaceIndex = match(key , "^interface%.(%d)%.bInterfaceClass$")
                if interfaceIndex and data["interface."..interfaceIndex..".bInterfaceClass"] == "08" then
             ngx.print('\
			      <div class="vdf-row">\
			        <div class="left">\
				      <span class="mouse-pointer hddArrow smallArrow">');  ngx.print(data["product"]); ngx.print('</span>\
			        </div>\
			      </div>\
			      <div class="hdd-partions hidden">\
                  ');  local partitionTable = content_helper.convertResultToObject("sys.usb.device."..data["paramindex"]..".partition.", proxy.get("sys.usb.device."..data["paramindex"]..".partition."))
                  for _, partition in ipairs(partitionTable) do  ngx.print('\
				    <div class="vdf-row no-border-bottom">\
				      <div class="left left-arrow-indentation openSharePopup">\
				        ');  ngx.print("\\\\"..gatewayIP["IPAddress"].."\\"..partition["Share"]); ngx.print('\
				      </div>\
				    </div>\
                  ');  end  ngx.print('\
			      </div>\
                ');  end
            end
            end  ngx.print('\
    </div>\
  </div>\
  <div class="h3-inside-content leftmargin mobile-no-leftmargin">\
	<div class="h3-content">\
	  <div class="vdf-row">\
		<div class="left">\
		  <h3>\
		    <span>');  ngx.print(T"Printer"); ngx.print('</span></h3>\
		</div>\
	  </div>\
	  <div class="vdf-row">\
		<div class="left">\
		  <span>');  ngx.print(T"Share"); ngx.print('</span></div>\
		  <div class="right">\
		    <div id="sharing-btn-printer" class="button ');  if deviceContent["printerShare"] == "1" then   ngx.print(' button-on ');  else  ngx.print(' button-off ');  end  ngx.print('"></div>\
		  </div>\
	  </div>\
      ');  for _, data in ipairs(usbInfo) do
           for key in pairs(data) do
             local interfaceIndex = match(key , "^interface%.(%d)%.bInterfaceClass$")
               if interfaceIndex and data["interface."..interfaceIndex..".bInterfaceClass"] == "07" then
                 printerIndex = true
                 break
               end
           end
           if printerIndex then   ngx.print('\
	         <div class="vdf-row">\
			   <div class="left static-printer-device printerDevice1" >\
					');  ngx.print(data["product"]); ngx.print('\
			   </div>\
			   <div class="left edit-printer-device printerDevice2 hidden" >\
			     <span class="printerArrow smallArrow"></span><input type="hidden" name="printerindex" value="');  ngx.print(data["paramindex"]); ngx.print('"> <input type="text" name="printername" value="');  ngx.print(data["product"]); ngx.print('">\
			   </div>\
			 </div>\
            ');  end
            end   ngx.print('\
		</div>\
	</div>\
</div>\
\
');  local lp = require("web.lp")
    lp.setpath("/www/docroot/")
    lp.include("apply-cancel.lp")   ngx.print('\
\
<div class="blackBackground" style="display:none;">&nbsp;</div></div>\
<script>\
  $(function () {\
    var target = "modals/sharing.lp";\
    $(".hddArrow").click(function() {\
	  if ($(this).hasClass( "smallArrow" )) {\
	    $(this).removeClass("smallArrow").addClass("smallArrowDown");\
        $(this).closest(".vdf-row").next(".hdd-partions").removeClass("hidden");\
	  }\
	  else {\
	   $(this).addClass("smallArrow").removeClass("smallArrowDown");\
       $(this).closest(".vdf-row").next(".hdd-partions").addClass("hidden");\
	  }\
    });\
	 $("#hdButton").click(function() {\
	   $(this).toggleClass(\'button-on button-off\');\
	 });\
\
	 $("#sharing-btn-printer").click(function() {\
	   $(this).toggleClass(\'button-on button-off\');\
	 });\
\
    $("#global-apply").click(function(){\
      var params = [];\
      var shareAll = $("#hdButton").hasClass("button-on") ? 1 : 0;\
      var printerShare = $("#sharing-btn-printer").hasClass("button-on") ? 1 : 0;\
      params.push({\
        name: "shareAll",\
        value: shareAll\
        },{\
        name : "printerShare",\
        value : printerShare\
        },{\
        name : "CSRFtoken",\
        value : "');  ngx.print( ngx.ctx.session:getCSRFtoken()); ngx.print('"\
         },{\
        name : "action",\
        value : "SAVE"\
      });\
      postHandler(target,params);\
	})\
  $("#global-cancel").click(function() {\
    $("#content").load("/modals/sharing.lp"); });\
});\
</script>\
\
'); 