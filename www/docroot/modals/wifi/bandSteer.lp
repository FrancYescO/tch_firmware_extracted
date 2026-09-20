--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx             =  ngx
local content_helper  =  require("web.content_helper")
local proxy           =  require("datamodel")
local lp              =  require("web.lp")
local CSRFtoken       =  ngx.ctx.session:getCSRFtoken()
local vodafone_helper =  require("vodafone_helper")
local bandSteerParams = {
  bandSteer24  = "uci.wireless.wifi-ap.@ap0.bandsteer_id",
  bandSteer5   = "uci.wireless.wifi-ap.@ap1.bandsteer_id",
}
if ngx.req.get_method() == "POST" and ngx.req.get_post_args().action == "SAVE" then
  local postargs = ngx.req.get_post_args()
  local bandSteerDataSet = vodafone_helper.handleBandsteer(postargs.bandSteerEnable,"-5G")
  if bandSteerDataSet then
    proxy.apply()
    ngx.print('<input type="hidden" id="post_status" value="success">')
  end
else
  ngx.print('<input type="hidden" id="post_status" value="error">')
end
content_helper.getExactContent(bandSteerParams)
lp.setpath("/www/docroot/")
  ngx.print('\
<form id="bandSteerform" class="form-horizontal" method="post" action="/modals/wifi/bandSteer.lp" autocomplete="off">\
  <input type="hidden" name= "CSRFtoken" id= "CSRFtoken" value = "');  ngx.print(CSRFtoken); ngx.print('"></input>\
  <input type="hidden" name= "action" id= "action" value = "SAVE"></input>\
  <div id="content" class="content-band_steering">\
    <h1>\
      <span>');  ngx.print(T"Band Steering"); ngx.print('</span>\
    </h1>\
    <h2>\
      <span>');  ngx.print(T"Band steering is a feature that steers clients that support 5Ghz wifi network to that frequency and leaves the more crowded 2.4 GHz band available for legacy clients"); ngx.print('</span>\
    </h2>\
    <div class="h3-content no-padding-bottom mobile-no-float vdf-table">\
      <div class="vdf-row">\
        <div class="left">\
          <span>');  ngx.print(T"Band Steering"); ngx.print('</span>\
        </div>\
        <div class="right">\
          <div id="globalEnabled" name="globalEnabled" class="button ');  if bandSteerParams["bandSteer24"] == "bs0" and bandSteerParams["bandSteer5"] == "bs0" then  ngx.print('button-on ');  else  ngx.print(' button-off ');  end  ngx.print(' toggle-content-button">\
          </div>\
        </div>\
      </div>\
    </div>\
  </div>\
</form>\
');  
  lp.include("apply-cancel.lp")
  ngx.print('\
<script src="/js/global-min.js" ></script>\
<script>\
$("#global-apply").click(function() {\
  var bandSteerEnable   =  $("#globalEnabled").hasClass("button-on") ? "bs0" : "off" ;\
  var form              =  $("#bandSteerform");\
  var target            =  form.attr("action");\
  var params            =  form.serializeArray();\
  params.push({\
    name  : "bandSteerEnable",\
    value :  bandSteerEnable\
  });\
  postHandler(target, params);\
});\
</script>\
\
'); 