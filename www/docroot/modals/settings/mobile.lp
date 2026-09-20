--pretranslated: do not change this file
 
  --Enable localization
  gettext.textdomain('webui-core')

  local ngx = ngx
  local post_helper = require("web.post_helper")
  local CSRFtoken = ngx.ctx.session:getCSRFtoken()
  local format = string.format
  local nwselections = {
    {"auto",   T"Auto"},
    {"manual", T"Manual"}
  }

  local mapParam = {
    apn = "uci.mobiled.profile.@0.apn",
    dialString = "uci.mobiled.profile.@0.dial_string",
    nwselection = "uci.mobiled.device_defaults.network_selection",
    uname = "uci.mobiled.profile.@0.username",
    passwd = "uci.mobiled.profile.@0.password",
  }
  local mapValid = {
    apn = post_helper.getValidateStringLength(1, 63),
    dialString = post_helper.getValidateStringLength(1, 63),
    nwselection = post_helper.getValidateInEnumSelect(nwselections),
    uname = post_helper.getValidateStringLengthInRange(0, 63),
    passwd = post_helper.getValidateStringLength(0, 63),
  }
  local params, errmsg = post_helper.handleQuery(mapParam, mapValid)
  if ngx.req.get_method() == "POST" then
    if not next(errmsg) then
      ngx.print('<input type="hidden" id="post_status" value="success">')
    else
      ngx.print('<input type="hidden" id="post_status" value="error">')
    end
  end

  ngx.print('\
\
<h1><span>');  ngx.print(T"Mobile"); ngx.print('</span></h1>\
\
<h3><span>');  ngx.print(T"General Settings"); ngx.print('</span></h3>\
\
<form action="/modals/settings/mobile.lp" id="mobile-settings-form">\
  <input type="hidden" name= "CSRFtoken" id= "CSRFtoken" value = "');  ngx.print(CSRFtoken); ngx.print('"></input>\
  <input type="hidden" name= "action" value = "SAVE"></input>\
  <div class="h3-content vdf-table settings-mobile">\
      <div class="vdf-row">\
          <div class="left">\
              <span>');  ngx.print(T"APN (data)"); ngx.print('</span>\
          </div>\
          <div class="right">\
              <input value="');  ngx.print(params.apn); ngx.print('" type="text" name="apn" id="mobile-txt-apn">\
          </div>\
      </div>\
      <div class="vdf-row">\
          <div class="left">\
            <span>');  ngx.print(T"Network Selection"); ngx.print('</span>\
          </div>\
          <div class="right">\
            <div id="top-info-mode" class="rel">\
              <select name="nwselection"  id="mobile-sel-nwselection">\
                ');  for i, v in ipairs(nwselections) do
                  local selected = v[1] == params.nwselection and 'selected="selected"' or ""
                  ngx.print(format('<option %s value="%s">%s</option>', selected, v[1], v[2]))
                end  ngx.print('\
              </select>\
            </div>\
          </div>\
      </div>\
      <div class="vdf-row">\
          <div class="left">\
              <span>');  ngx.print(T"Dial Number"); ngx.print('</span>\
          </div>\
          <div class="right">\
              <input value="');  ngx.print(params.dialString); ngx.print('" type="text" name="dialString" id="mobile-txt-dialNum">\
          </div>\
      </div>\
      <div class="vdf-row">\
          <div class="left">\
              <span>');  ngx.print(T"PPP username"); ngx.print('</span> </div>\
          <div class="right">\
              <input value="');  ngx.print(params.uname); ngx.print('" type="text" name="uname" id="mobile-txt-uname">\
          </div>\
      </div>\
      <div class="vdf-row">\
          <div class="left">\
              <span>');  ngx.print(T"PPP password"); ngx.print('</span> </div>\
          <div class="right">\
              <input value="');  ngx.print(params.passwd); ngx.print('" type="text" name="passwd" id="mobile-txt-passwd">\
          </div>\
      </div>\
  </div>\
\
  <!-- TODO - No Lower layer support\
  <h3><span>');  ngx.print(T"Data backup section"); ngx.print('</span></h3>\
  <div class="h3-content vdf-table settings-mobile">\
      <div class="vdf-row">\
          <div class="left">\
              <span>');  ngx.print(T"Backup"); ngx.print('</span> </div>\
      <div class="right">\
        <div id="top-info-mode" class="rel">\
          <select name="" id="" style="display: none;">\
            <option value="">');  ngx.print(T"Manual"); ngx.print('</option>\
            <option value="">');  ngx.print(T"Auto"); ngx.print('</option>\
          </select>\
        </div>\
      </div>\
      </div>\
      <div class="vdf-row">\
          <div class="left">\
              <span>');  ngx.print(T"Idle time"); ngx.print('</span> </div>\
          <div class="right">\
              <input value="600" type="text">\
          </div>\
      </div>\
      <div class="vdf-row">\
          <div class="left">\
              <span>');  ngx.print(T"Backup Mode"); ngx.print('</span> </div>\
      <div class="right">\
        <div id="top-info-mode" class="rel">\
          <select name="" id="" style="display: none;">\
            <option value="">');  ngx.print(T"DNS"); ngx.print('</option>\
          </select>\
        </div>\
      </div>\
      </div>\
      <div class="vdf-row">\
          <div class="left">\
              <span>');  ngx.print(T"DNS timeout"); ngx.print('</span> </div>\
          <div class="right">\
              <input value="4" type="text">\
          </div>\
      </div>\
      <div class="vdf-row">\
          <div class="left">\
              <span>');  ngx.print(T"Delay before switching data from WAN to Mobile (s)"); ngx.print('</span> </div>\
          <div class="right">\
              <input value="0" type="text">\
          </div>\
      </div>\
      <div class="vdf-row">\
          <div class="left">\
              <span>');  ngx.print(T"Delay before switching from Mobile to WAN (s)"); ngx.print('</span> </div>\
          <div class="right">\
              <input value="0" type="text">\
          </div>\
      </div>\
  </div>\
  -->\
</form>\
\
');  
  local lp = require("web.lp")
  lp.setpath("/www/docroot/")
  lp.include("apply-cancel.lp")
  ngx.print('\
\
<script src= js/global-min.js></script>\
<script>\
$(\'select\').chosen({\
  disable_search_threshold: 100000,\
  allow_single_deselect: true\
});\
\
var elements = {\
  apn : "#mobile-txt-apn",\
  uname : "#mobile-txt-uname",\
  passwd : "#mobile-txt-passwd",\
  dialNum : "#mobile-txt-dialNum"\
}\
\
var validations = {\
  apn : validateStringLength(1, 63),\
  uname : validateStringLength(0, 63),\
  passwd : validateStringLength(0, 63),\
  dialNum : validateStringLength(1, 63)\
}\
\
$("#global-apply").click(function() {\
  if(!validateElements(elements, validations)) return false;\
  var form = $("#mobile-settings-form");\
  var target = form.attr("action");\
  var params = form.serializeArray();\
  postHandler(target, params);\
});\
\
$("#global-cancel").click(function() {\
  $("#content").load("/modals/settings/mobile.lp");\
});\
\
</script>'); 