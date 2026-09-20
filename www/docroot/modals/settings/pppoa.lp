--pretranslated: do not change this file
 ngx.print(' ');  
-- Enable localization
gettext.textdomain('webui-core')
local proxy = require("datamodel")
local ngx                 = ngx
local postHelper          = require("web.post_helper")
local session             = ngx.ctx.session
local contentHelper       = require("web.content_helper")
local isStringLengthValid = postHelper.getValidateStringLengthInRange
local format = string.format

-- Function validation for wanPassword
-- @param value of password field
-- @param object contains all object arguments
-- @param key represent to which field is happening
-- @return boolean
local function wanpasswordValidation(value, object, key)
  local isValid = true
  if not (session:retrieve("wanPassword") ~= "" and object.wanPassword == "") or (session:retrieve("wanUserName") ~= object.wanUserName) then
    local lengthrange = isStringLengthValid(1, 63)
    isValid = lengthrange(object.wanPassword)
  end
  if isValid then
    object["wanPassword"] = object["wanPassword"] == "" and session:retrieve("wanPassword") or object.wanPassword
  else
    return nil, "Invalid Password was entered"
  end
  return true
end

local paramMap = {
   wanUserName = "uci.network.interface.@adsl.username",
   wanPassword = "uci.network.interface.@adsl.password",
}

local validationMap = {
  wanUserName = isStringLengthValid(1,63),
  wanPassword = wanpasswordValidation,
}
local wanData, wanErrorMsg =  postHelper.handleQuery(paramMap, validationMap)
session:store("wanPassword", wanData["wanPassword"])
session:store("wanUserName", wanData["wanUserName"])

if ngx.req.get_method() == "POST" and not next(wanErrorMsg) then
  local postArgs = ngx.req.get_post_args()
  local interfaceTable = {}
  local setTable = {}
  -- Get to list all pppoe interface names
  local interfaceNameList = contentHelper.convertResultToObject("uci.network.interface.",proxy.get("uci.network.interface."))
  for _, param in ipairs(interfaceNameList) do
    if ( param["proto"] == "pppoe" or param["proto"] == "pppoa") and not interfaceTable[param.paramindex] then
      -- All other pppoe and pppoa interface path populated in setTable
      setTable[format("uci.network.interface.%s.username",param.paramindex)] = postArgs.wanUserName
      setTable[format("uci.network.interface.%s.password",param.paramindex)] = postArgs.wanPassword == "" and session:retrieve("wanPassword") or postArgs.wanPassword
      interfaceTable[param.paramindex] = true
    end
  end
  proxy.set(setTable)
  proxy.apply()
end

if not next(wanErrorMsg) then
   ngx.print('<input type="hidden" id="post_status" value="success">')
else
   ngx.print('<input type="hidden" id="post_status" value="error">')
end

  ngx.print('\
\
<div class="row no-margin-right">\
    <div class="col-md-12 col-sm-12">\
        <h1><span>');  ngx.print(T"ADSL Configuration"); ngx.print('</span></h1>\
        <h2>');  ngx.print(T"Configuration for ADSL"); ngx.print('</h2>\
    </div>\
</div>\
<h3>');  ngx.print(T"ADSL Configuration"); ngx.print('</h3>\
\
<div class="h3-content">\
  <form id="pppoa_form" method="post" action="modals/settings/pppoa.lp">\
    <div class="row padding-top-bottom-20 no-margin-left-right">\
        <div class="col-xs-12 col-md-6 col-sm-6  no-padding-left-right">\
            <span>');  ngx.print(T"PPPoA Username"); ngx.print('</span>\
        </div>\
        <div class="col-xs-12 col-md-6 col-sm-6 text-right no-padding-left-right">\
            <input id="wanUserName" value="');  ngx.print(wanData["wanUserName"] ~= "SET_BY_SCRIPT" and wanData["wanUserName"] or "" ); ngx.print('" type="text" />\
        </div>\
    </div>\
    <div class="row">\
        <div class="col-md-12">\
            <hr/>\
        </div>\
    </div>\
\
    <div class="row padding-top-bottom-20 no-margin-left-right">\
        <div class="col-xs-12 col-md-6 col-sm-6  no-padding-left-right">\
            <span>');  ngx.print(T"PPPoA Password"); ngx.print('</span>\
        </div>\
        <div class="col-xs-12 col-md-6 col-sm-6 text-right no-padding-left-right">\
            <input id="wanPassword" name = "wanPassword" value="" type = "password" placeholder="********" />\
        </div>\
    </div>\
</form>\
</div>\
\
');  
 local lp = require("web.lp")
 lp.setpath("/www/docroot/")
 lp.include("apply-cancel.lp")
  ngx.print('\
  <script type="text/javascript" src="js/global-min.js"></script>\
  <script>\
    $(function() {\
        $(\'select\').chosen({\
            disable_search_threshold: 100000,\
            allow_single_deselect: true\
        });\
\
    $(\'input,textarea\').focus(function () {\
      $(this).data(\'placeholder\', $(this).attr(\'placeholder\')).attr(\'placeholder\', \'\');\
    }).blur(function () {\
      $(this).attr(\'placeholder\', $(this).data(\'placeholder\'));\
    });\
    var oldWanUsername = "');  ngx.print(wanData["wanUserName"]); ngx.print('";\
    $("#global-apply, #modal-apply").click(function() {\
      $(".articlediv, .articlediv > .msg-error").removeClass("show").addClass("hide");\
      $("#wanUserName").removeClass("input-length");\
      $("#wanPassword").removeClass("input-length");\
      var target                = "/modals/settings/pppoa.lp";\
      var form                  = $("#pppoa_form");\
      var params                = [];\
      var wanUserName           = $("#wanUserName").val();\
      var wanPassword           = $("#wanPassword").val();\
\
      var elements = {\
        uname   : "#wanUserName",\
        passwd  : "#wanPassword"\
      }\
      var validations = {\
        passwd   : function(value) {\
          return !(((oldWanUsername != wanUserName)|| (oldWanUsername.length == 0 && wanUserName.length == 0)) && ((wanPassword.length == 0) || (wanPassword.length > 63)))\
        },\
        uname     : function(value) {\
          return !(wanUserName.length == 0 || wanUserName.length > 63)\
        }\
      }\
      if(!validateElements(elements, validations)) return false;\
      params.push({\
        name  : "wanUserName",\
        value :  wanUserName\
      }, {\
        name  : "wanPassword",\
        value :  wanPassword\
      }, {\
        name  : "CSRFtoken",\
        value : "');  ngx.print(ngx.ctx.session:getCSRFtoken()); ngx.print('"\
      }, {\
        name  : "action",\
        value : "SAVE"\
      });\
      postHandler(target, params);\
    });\
\
   $("#global-cancel").click(function() {\
      $("#content").load("/modals/settings/pppoa.lp");\
   });\
});\
\
</script>\
\
<!-- End -->\
\
\
'); 