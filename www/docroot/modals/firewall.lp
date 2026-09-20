--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')
local ngx           = ngx
local postHelper    = require("web.post_helper")
local CSRFtoken     = ngx.ctx.session:getCSRFtoken()
local contentHelper = require("web.content_helper")
local basePath = contentHelper.getMatchedContent("uci.firewall.rule.", { name = "Allow-Ping-Vodafone-wan"} )
basePath = basePath and basePath[1].path.."enabled" or ""

local paramMap = {
  pingButton  = basePath,
  fireWall    = "rpc.network.firewall.enable",
}

local validateMap = {
  pingButton      = postHelper.validateBoolean ,
  fireWall    = postHelper.validateBoolean
}

local pageInfo, errMsg = postHelper.handleQuery(paramMap, validateMap)
local resetfirewall = {
  reset_allow_ping_to_wan_interface = "uci.uci-defaults.firewall.allow_ping_to_wan_interface",
  reset_firewall = "uci.uci-defaults.firewall.firewall"
}
contentHelper.getExactContent(resetfirewall)

if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SAVE" then
   if (next(errMsg)) and (ngx.req.get_post_args().pingButton ~= "nil") then
    ngx.print('<input type="hidden" id="post_status" value="error">')
  else
    ngx.print('<input type="hidden" id="post_status" value="success">')
   end
end
local lp = require("web.lp")
lp.setpath("/www/docroot/")
lp.include("reset-wrap.lp")
  ngx.print('\
\
<script src="js/global.js"></script>\
<div class="row no-margin-right">\
  <div class="col-xs-12 col-md-8 col-sm-8">\
    <h1>');  ngx.print(T"Firewall"); ngx.print('</h1>\
  </div>\
</div>\
<h2>');  ngx.print(T"Your router provides extensive firewall functionality which protects against common attacks. Vodafone recommends not to turn off firewall."); ngx.print('\
</h2>\
\
 <form id="firewall_form" class="form-horizontal" method="post" action="modals/firewall.lp">\
    <input type="hidden" name= "pingButton" id= "pingStatus"  value = "');  ngx.print(pageInfo.pingButton ~= "" and pageInfo.pingButton or 1); ngx.print('"></input>\
    <input type="hidden" name= "fireWall" id= "firewallStatus" value = "');  ngx.print(pageInfo.fireWall); ngx.print('"></input>\
    <input type="hidden" name= "CSRFtoken" id="CSRFtoken" value = "');  ngx.print(CSRFtoken); ngx.print('"></input>\
    <input type="hidden" name= "action" id="action" value = "SAVE"></input>\
\
<!--<div class="h3-content h3-content-mobile">\
  <div class="row padding-top-20 current-password padding-top-bottom-20">\
    <div class="col-xs-10 col-sm-6 col-md-6 no-padding-right mobile-firewall-line-height">\
      <span>');  ngx.print(T"Allow Ping to WAN interface"); ngx.print('</span>\
    </div>\
    <div class="col-xs-2 col-md-6 col-sm-6 pull-right no-padding-left">\
    <div id="ping-btn-onoff" class="pull-right button ');  if (pageInfo.pingButton == "1") or (pageInfo.pingButton == "") then  ngx.print(' button-on  ');  else  ngx.print(' button-off ');  end  ngx.print(' ping-btn-onoff"></div>\
    </div>\
  </div>\
  <div class="row no-margin-right">\
    <div class="col-md-12">\
      <hr/>\
    </div>\
  </div>\
  <div class="row padding-top-bottom-20">\
    <div class="col-xs-6 col-md-6 col-sm-6 mobile-firewall-line-height">\
      <span>');  ngx.print(T"Firewall"); ngx.print('</span>\
    </div>\
    <div class="col-xs-6 col-md-6 col-sm-6 pull-right">\
      <div id="firewall-btn-onoff" class="pull-right button ');  if (pageInfo.fireWall == "1") then  ngx.print(' button-on  ');  else  ngx.print(' button-off ');  end  ngx.print(' firewall-btn-onoff"></div>\
      </div>\
    </div>\
  </div> -->\
  <div class="h3-content-firewall">\
  <div class="vdf-row">\
    <div class="left">\
      <span>');  ngx.print(T"Allow Ping to WAN interface"); ngx.print('</span>\
    </div>\
    <div class="right">\
      <div id="ping-btn-onoff" class="pull-right button ');  if (pageInfo.pingButton == "1") or (pageInfo.pingButton == "") then  ngx.print(' button-on  ');  else  ngx.print(' button-off ');  end  ngx.print(' ping-btn-onoff"></div>\
    </div>\
  </div>\
  <div class="vdf-row">\
    <div class="left">\
       <span>');  ngx.print(T"Firewall"); ngx.print('</span>\
	   </div>\
    <div class="right">\
      <div id="firewall-btn-onoff" class="pull-right button ');  if (pageInfo.fireWall == "1") then  ngx.print(' button-on  ');  else  ngx.print(' button-off ');  end  ngx.print(' firewall-btn-onoff"></div>\
    </div>\
  </div>\
</div>\
</form>\
</div>\
\
<!-- <div class="row apply-cancel-hr no-margin-right">\
  <div class="col-md-12 col-sm-12 col-xs-12 no-padding-right">\
    <div class="articlediv hide">\
      <div class="message-arrowbox-applied">\
        <div class="message-arrowbox-applied-right">\
          <p>\
          </p>\
        </div>\
      </div>\
    </div>\
    <input class="button button-apply mob-button-width" value="Apply" type="button">\
    <input class="button button-cancel mob-button-width mob-apply-cancel" value="Cancel" type="button">\
  </div>\
</div>\
<div class="row no-margin-right">\
  <div class="col-xs-12 visibile-xs hidden-sm hidden-md hidden-lg padding-top-bottom-20">\
    <div id="resetWrapMobile">\
      <div class="resetButtons resetButtonsShort">\
        Reset to default Settings\
      </div>\
    </div>\
  </div>\
</div>-->\
\
');  
 lp.include("apply-cancel.lp")
 lp.include("reset-wrap-mobile.lp")
  ngx.print('\
\
<script>\
  $(function() {\
\
   $("#ping-btn-onoff, #firewall-btn-onoff").click(function(){\
      var id = $(this).attr("id");\
      if($(this).hasClass(\'button-on\')){\
        if (id == "ping-btn-onoff") {\
          $("#pingStatus").val("0");\
        }\
        if (id == "firewall-btn-onoff") {\
          $("#firewallStatus").val("0");\
        }\
        $(this).removeClass(\'button-on\').addClass(\'button-off\');\
      }\
      else{\
        if (id == "ping-btn-onoff"){\
          $("#pingStatus").val("1");\
        }\
        if (id == "firewall-btn-onoff") {\
          $("#firewallStatus").val("1");\
        }\
        $(this).removeClass(\'button-off\').addClass(\'button-on\');\
      }\
   });\
\
  $("#global-apply").click(function() {\
    postHandler("/modals/firewall.lp", $("#firewall_form").serializeArray());\
  });\
\
  $("#global-cancel").click(function() {\
    $("#content").load("/modals/firewall.lp");\
  });\
});\
\
  $("#resetR, .resetR").click(function(){\
\
    function changeButton(id, value, hiddenClass) {\
    $(id).val(value);\
    if (value == "1") {\
      $(id).addClass(\'button-on\').removeClass(\'button-off\');\
      $(hiddenClass).val("1");\
      } else {\
      $(id).addClass(\'button-off\').removeClass(\'button-on\');\
      $(hiddenClass).val("0");\
      }\
    }\
    changeButton("#ping-btn-onoff", ');  ngx.print(resetfirewall["reset_allow_ping_to_wan_interface"]); ngx.print(', "#pingStatus");\
    changeButton("#firewall-btn-onoff", ');  ngx.print(resetfirewall["reset_firewall"]); ngx.print(', "#firewallStatus");\
  });\
</script>\
\
'); 