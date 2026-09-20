--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local session = ngx.ctx.session
local proxy = require("datamodel")
local username = session:getusername()
local content_helper = require("web.content_helper")
local post_helper = require("web.post_helper")
local CSRFtoken = ngx.ctx.session:getCSRFtoken()
local format = string.format
local loginrole = session:getrole()
local scp = require("transformer.shared.setClashPassword")
local ui_helper = require("vdf_ui_helper")
local vdf_helper = require("vodafone_helper")
local assistance = require("web.assistance")
local assistant = assistance.getAssistant('remote')

local gatewayName = vdf_helper.productName()

local get_from_transformer = {
  ["firmware-version"] = "rpc.system.SoftwareVersion",
}

content_helper.getExactContent(get_from_transformer)

local timeout = {
  {"5", T"5 Minutes"},
  {"10", T"10 Minutes"},
  {"15", T"15 Minutes"},
  {"30", T"30 Minutes"},
  {"35000", T"Never"} -- Maximum allowable time for session timeout, Above this value nginx will not respond
}
local selectedUserRole
local assistant_username
if assistant then
  assistant_username = assistant:username()
end
local usernames = {}
local usernameslist = content_helper.convertResultToObject("uci.web.user.", proxy.get("uci.web.user."))
for _,v in ipairs(usernameslist) do
  if not (assistant_username and v.name == assistant_username) then
    usernames[#usernames + 1] = {v.name}
  end
end
local mapParam = {
  sessiontime = "uci.web.sessionmgr.@default.timeout"
}
local mapValid = {
  sessiontime = post_helper.getValidateInEnumSelect(timeout)
}
local content, errmsg = post_helper.handleQuery(mapParam,mapValid)
if ngx.req.get_method() == "POST" then
  ngx.header.content_type = "application/json"
  local postcontent = ngx.req.get_post_args()
  local selectedUser = postcontent.resetpassword
  for _,v in ipairs(usernameslist) do
    if selectedUser == v.name then
      selectedUserRole = v.role
    end
  end
  if postcontent["action"] == "reset" then
    proxy.set(format("rpc.user.@%s.reset_password", selectedUser), "1")
    proxy.apply()

    --After setting the value to 1, reloadusers is needed to reset the password
    require("web.sessioncontrol").reloadUsers()
    if loginrole == selectedUserRole then
      --Logging out the admin user if the login password has been reset for admin
      session:logout()
      ngx.print('{ "status":"success" }')
    end
    ngx.exit(ngx.HTTP_OK)
  elseif postcontent["action"] == "SAVE" and postcontent["sessiontime"] then
    if not next(errmsg) then
      ngx.print('{ "status":"success" }')
    else
      ngx.print('{ "status":"error" }')
    end
    ngx.exit(ngx.HTTP_OK)
  else
  -- This section deals with changing the password
    username = postcontent["user_name"] or username
    local path = content_helper.getMatchedContent("uci.web.user.", {name = username})
    if path and #path > 0 then
      path = path[1].path
      if (postcontent["srp_salt"] and postcontent["srp_verifier"]) then
        local srp_table = {}
        srp_table[path.. "srp_salt"] = postcontent["srp_salt"]
        srp_table[path.. "srp_verifier"] = postcontent["srp_verifier"]
        username = string.untaint(username)
        local userPath = format("rpc.user.@%s.pwcrypt", username)
        --Will check the rpc param is exist for current user, If yes then set value for pwcrypt.
        if proxy.getPN(userPath, false) and postcontent["cryptpw"] and scp.isClashUser(username) then
          srp_table[userPath] = postcontent.cryptpw
        end
        local success = proxy.set(srp_table)
        if success then
          proxy.set(path.."password_reminder", "0")
          proxy.apply()
          session:logout()
          ngx.print('{ "status":"success" }')
        else
          ngx.print('{ "status":"error" }')
        end
      end
    end
    ngx.exit(ngx.HTTP_OK)
  end
end
  ngx.print('\
  ');  if vdf_helper.getVariant() == "VF-UK" then   ngx.print('\
  <h1>');  ngx.print(("Vodafone Broadband Router password")); ngx.print('\
  ');  else   ngx.print('\
  <h1>\
    ');  ngx.print(T"Password" ); ngx.print('\
  </h1>\
  ');  end   ngx.print('\
  ');  if vdf_helper.getVariant() == "VF-UK" then   ngx.print('\
  <h2>');  ngx.print(("Change your password on your " ..gatewayName .. " to enhance your router's security.")); ngx.print('</h2>\
  ');  else   ngx.print('\
  <h2>\
    ');  ngx.print(T("Set a password for your " .. gatewayName .. ".")); ngx.print('\
  </h2>\
  ');  end   ngx.print('\
  ');  if vdf_helper.getVariant() ~= "VF-UK" then   ngx.print('\
  <h3>\
    ');  ngx.print(T"Login Account"); ngx.print('\
  </h3>\
  ');  end   ngx.print('\
  ');  
  local row = {
    {
      label = "Username",
      element = ui_helper.createDropDown({
        class="dropdown",
        id="password-sel-username",
        name="user_name"
      }, usernames),
      rowId = "password-div-userselect",
      colRightClass = "rel",
      colRightId = "top-info-mode"
    },
    {
      label = "",
      element = ui_helper.createClickButton({
        id="password_btn_chpass",
        ["data-toggle"] = "modal",
        ["data-target"] = "#passwordModal",
        class="button button-blank change-pw mobile-full",
        type="button",
        value=T"Change Password"
      }),
      colLeftClass = "left empty-spacing",
      colRightClass = "right",
      colRightId ="no-border"
    },
    {
      label = "",
      element = ui_helper.createClickButton({
        id="reset-pw-btn",
        ["data-toggle"] = "modal",
        ["data-target"] = "#resetPasswordModal",
        class="button button-blank",
        type="button",
        value=T"Reset Password"
      }),
      colLeftClass = "left empty-spacing",
      rowId = "password-div-reset",
    }
  }
  ngx.print(ui_helper.createTable(row, "", "h3-content no-padding-bottom vdf-table set-password content-password"))
  ngx.print('\
\
    ');  if vdf_helper.getVariant() ~= "VF-UK" then   ngx.print('\
      <h3>\
        ');  ngx.print(T"Account Security"); ngx.print('\
      </h3>\
      <form method="POST" action="');  ngx.print( ngx.var.request_uri ); ngx.print('" id="automatic-logout">\
        <input type="hidden" name="CSRFtoken" value="');  ngx.print(CSRFtoken); ngx.print('" />\
        <input type="hidden" name="action" value="SAVE" />\
        <div class="h3-content no-padding-bottom vdf-table set-password content-password">\
          <div class="vdf-row">\
            <div class="left">\
              <h4><span>');  ngx.print(T"Automatic Logout"); ngx.print('</span></h4>\
            </div>\
            <div class="right mobile-full">\
              <div id="top-info-mode" class="rel">\
                <select id="session-time-sel" name="session-time">\
                  ');  for i,v in ipairs(timeout) do  ngx.print('\
                    <option ');  if content.sessiontime == v[1] then  ngx.print(' selected ');  end  ngx.print('  value = "');  ngx.print(v[1]); ngx.print('">');  ngx.print(v[2]); ngx.print('</option>\
                  ');  end  ngx.print('\
                </select>\
              </div>\
            </div>\
          </div>\
        </div>\
      </form>\
      ');  local lp = require("web.lp")
      lp.setpath("/www/docroot/")
      lp.include("apply-cancel.lp")  ngx.print('\
    ');  end  ngx.print('\
\
    <!-- Change Password Popup Modal-->\
    <div class="modal fade" id="passwordModal" role="dialog" tabindex="-1" aria-hidden="true" data-keyboard="false" data-backdrop="static">\
      <div class="modal-dialog">\
        <!-- Modal content-->\
        <div class="modal-content change-password-content">\
          <div class="modal-header hidden-md hidden-sm hidden-lg">\
            <div class="mobile-cancel-popup button-cancel" data-dismiss="modal">\
            </div>\
          </div>\
          <div class="modal-body no-padding mobile-modal-padding-top">\
            <form method="post" action="');  ngx.print( ngx.var.request_uri ); ngx.print('" id="profile_form" class="form-horizontal">\
              <input type="hidden" name="CSRFtoken" id="CSRFtoken" value="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\
              </input>\
              <input type="hidden" name="action" id="action" value="SAVE">\
              </input>\
              <input type="hidden" name="srp_salt" id="srp_salt" value="">\
              </input>\
              <input type="hidden" name="srp_verifier" id="srp_verifier" value="">\
              </input>\
              <p class="title tL" style="line-height:35px;">\
                ');  if vdf_helper.getVariant() == "VF-UK" then  ngx.print('\
                  ');  ngx.print(T("Enter your new Vodafone Broadband router password")); ngx.print('\
                ');  else  ngx.print('\
                      ');  ngx.print(T("Enter a password for your " .. gatewayName)); ngx.print('\
                 ');  end  ngx.print('\
              </p>\
              <div class="h3-content no-padding-bottom">\
                ');  if vdf_helper.getVariant() == "NZ" then  ngx.print('\
                  <div class="vdf-row">\
                    <div class="left">\
                      <label for="loginaccount" class="password-modal-label">');  ngx.print(T"Login Account"); ngx.print('</label>\
                    </div>\
                    <div class="right">\
                      <div id="loginuser" class="passwordStrength">\
                        <span id="login-span"></span>\
                      </div>\
                    </div>\
                ');  end  ngx.print('\
                </div>\
                ');  if vdf_helper.getVariant() == "VF-UK" then
                  row = {
                  label = format('<label for="password-txt-oldpwd" class="password-modal-label">%s</label>', T"Current password"),
                  element = ui_helper.createTextField({name = "old_pwd", id = "password-txt-oldpwd", type = "password", placeholder = T"Current password"}),
                  colLeftClass = "left pad-top-bottom-10",
                  colRightClass = "right pad-top-bottom-10"
                  }
                  ngx.print(ui_helper.createRow(row))
                  end  ngx.print('\
                  <!-- End of if for vdf_helper.getVariant() == "VF-UK"-->\
                  ');  
                  row = {
                  label = format('<label for="password-txt-inpwd" class="password-modal-label">%s</label>', T"Password"),
                  element = ui_helper.createTextField({name = "new_pwd", id = "password-txt-inpwd", class = "inputKeyPress", type = "password", placeholder = T"Password"}),
                  colLeftClass = "left pad-top-bottom-10",
                  colRightClass = "right pad-top-bottom-10"
                  }
                  ngx.print(ui_helper.createRow(row))
                  row = {
                  label = format('<label for="password-txt-repwd" class="password-modal-label">%s</label>', T"Re-enter Password"),
                  element = ui_helper.createTextField({name = "cnf_pwd", id="password-txt-repwd", type="password", placeholder = T"Password"}),
                  colLeftClass = "left pad-top-bottom-10",
                  colRightClass = "right pad-top-bottom-10"
                  }
                  ngx.print(ui_helper.createRow(row))
                    ngx.print('\
\
                  <div class="vdf-row">\
                    <div class="left width-65">\
                      <label for="inputPassword3" class="password-modal-label2">');  ngx.print(T"Password Strength"); ngx.print('</label>\
                    </div>\
                    <div class="right width-35">\
                      <div id="passStrength" class="passwordStrength strength0">\
                        <span id="password-span-strwk" class="show">');  ngx.print(T"Weak"); ngx.print('\
                        </span>\
                        <span id="password-span-strgd" class="hide">');  ngx.print(T"Good"); ngx.print('\
                        </span>\
                        <span id="password-span-strsg" class="hide">');  ngx.print(T"Strong"); ngx.print('\
                        </span>\
                      </div>\
                         <span id="password-span-defaultwk" class = "show" style="text-align: left;">');  ngx.print(T"Weak passwords are not accepted"); ngx.print('\
                         </span>\
                    </div>\
                  </div>\
                  <div class="table-wrapper">\
                    ');  if vdf_helper.getVariant() == "NZ" then  ngx.print('\
		      <div class="message message-info message-error not-12-characters" id="password-msg-infopwdstd" style="display: block;">\
		        ');  ngx.print( T"The password must contain at least 12 alphanumeric characters including both upper and lower case letters, at least one number"); ngx.print('\
		      </div>\
                    ');  else   ngx.print('\
                     <div class="message message-info message-error not-8-characterss" id="password-msg-infopwdstd" style="display: block;">\
		      ');  ngx.print( T"The password must be at least 8 characters and must contain at least three of the four following character sets: lower case letter, upper case letter, number or symbol"); ngx.print('\
		      </div>\
                    ');  end  ngx.print('\
                    <div class="message message-info message-error not-similiar" id="password-msg-errpwdmatch" style="display: none;">\
                      ');  ngx.print(T"The passwords you entered do not match."); ngx.print('\
                    </div>\
                    <div class="message message-info message-error weak-password" id="password-msg-errpwdminsec" style="display: none;">\
                      ');  ngx.print(T"The password you have entered doesn't meet the minimum security requirements."); ngx.print('\
                    </div>\
                    ');  if vdf_helper.getVariant() == "VF-UK" then  ngx.print('\
                      <div class="message message-info message-error old-not-password" id="password-msg-erroldpwdmatch" style="display: none;">\
                        ');  ngx.print(T"The current password you entered does not match"); ngx.print('\
                      </div>\
                      <div class="message message-info message-error old-new-password" id="password-msg-erroldpwdmatch" style="display: none;">\
                        ');  ngx.print(T"This current password is same as your new password"); ngx.print('\
                      </div>\
                    ');  end  ngx.print('\
                  </div>\
                  <div class="apply-cancel" style="margin-top: 0px !important;padding-top: 10px !important;">\
                    <input class="button button-apply save mob-button-width op40" value="');  ngx.print(T" Save "); ngx.print('" id="password-btn-save" " type="button" />\
                    <input class="button button-cancel close-password-popup mob-apply-cancel mob-button-width " id="password-btn-cancel " data-dismiss="modal " value="');  ngx.print(T "Cancel"); ngx.print('" type="button" onClick="CloseModal()" />\
                  </div>\
            </form>\
            </div>\
          </div>\
        </div>\
      </div>\
    </div>\
    <!-- End -->\
    <!--Confirmation Password Popup  Modal -->\
    <div class="modal fade" id="pass-modal" data-backdrop="static" data-keyboard="false" role="dialog">\
      <div class="modal-dialog">\
        <!-- Modal content-->\
        <div class="modal-content">\
          <div class="modal-header hidden-sm hidden-md hidden-lg">\
            <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"></div>\
          </div>\
          <div class="modal-body no-padding">\
            <form class="form-horizontal">\
              <div class="form-group no-margin-bottom">\
                <div class="col-sm-12">\
                   <div class="col-sm-12 col-md-12 col-lg-12 text-center">\
                     <img src="/img/look_4/icons/icon-thinking.gif" />\
                   </div>\
                  <p>\
                    ');  ngx.print(T"Password changed successfully."); ngx.print('\
                  </p>\
                </div>\
              </div>\
            </form>\
          </div>\
        </div>\
      </div>\
    </div>\
    <!-- End -->\
    <!-- Reset Password Popup Modal-->\
    <div class="modal fade" id="resetPasswordModal" role="dialog" tabindex="-1" aria-hidden="true" data-keyboard="false" data-backdrop="static">\
      <div class="modal-dialog">\
        <!-- Modal content-->\
        <div class="modal-content change-password-content">\
          <div class="modal-header hidden-md hidden-sm hidden-lg">\
            <div class="mobile-cancel-popup button-cancel" data-dismiss="modal"> </div>\
          </div>\
          <form method="post" action="');  ngx.print( ngx.var.request_uri ); ngx.print('" id="profile_form_reset" class="form-horizontal">\
            <input type="hidden" name="CSRFtoken" id="CSRFtoken" value="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\
            </input>\
            <input type="hidden" name="action_reset" id="action_reset" value="reset">\
            </input>\
            <div class="modal-body no-padding mobile-modal-padding-top">\
              <p class="title tL">\
                ');  ngx.print(T"Reset Password"); ngx.print('\
              </p>\
              <div class="h3-content no-padding-left no-padding-bottom vdf-table">\
                <div class="vdf-row">\
                  <div class="left mobile-margin-bottom-20">\
                    <span>');  ngx.print(T"Are you sure you want to reset the password?"); ngx.print('</span>\
                  </div>\
                </div>\
              </div>\
              <div class="apply-cancel">\
                <input class="button button-apply no-mobile-margin-top mob-button-width" value="Confirm" id="password-btn-confirm" type="button" data-dismiss="modal">\
                <input class="button button-cancel mob-apply-cancel mob-button-width" value="Cancel" type="button" data-dismiss="modal">\
              </div>\
          </form>\
            </div>\
        </div>\
      </div>\
    </div>\
    <!-- End -->\
<script src="/js/srp-min.js?'); ngx.print(get_from_transformer['firmware-version']); ngx.print('"></script>\
<script src="/js/global-min.js?'); ngx.print(get_from_transformer['firmware-version']); ngx.print('"></script>\
<script>\
var variant = "');  ngx.print(vdf_helper.getVariant()); ngx.print('";\
$(function() {\
  bindChosen();\
  $(".pad-top-bottom-10").attr(\'style\',  \'padding-top: 8px !important;padding-bottom: 8px !important;border-bottom: 1px solid #e6e6e6;\');\
  $(".width-65").attr(\'style\',  \'padding-top: 8px !important;padding-bottom: 8px !important;width:65%;\');\
  $("#password-msg-infopwdstd , .width-35").attr(\'style\',  \'padding-top: 8px !important;padding-bottom: 8px !important;\');\
  $("#no-border").attr(\'style\',  \'border-top: 0 none;\');\
  $("input[type=\'password\']").val(\'\');\
  $(\'#show-hide-guest-pw\').click(function() {\
    if (!$(this).is(\':checked\')) {\
      $(\'input#pw1\').removeAttr("type");\
      $(\'input#pw1\').attr(\'type\', \'password\');\
    } else {\
      $(\'input#pw1\').removeAttr("type");\
      $(\'input#pw1\').attr(\'type\', \'text\');\
    }\
  });\
});\
\
$("#password_btn_chpass").click(function() {\
  $("#profile_form [type=password]").removeClass(\'input-error\');\
  $("#password-btn-save").addClass("op40");\
});\
$("#passwordModal" ).on(\'shown.bs.modal\', function (e) {\
    $(".modal-dialog").attr(\'style\',  \'margin-top: 0 !important;\');\
    $(".change-password-content").attr(\'style\',  \'padding-top: 0 !important;\');\
    var user_name = "');  ngx.print(T(username)); ngx.print('";\
    user_name = $("#password-sel-username").val();\
    $("#login-span").text(user_name);\
});\
\
var elements = {\
  password: "[id$=pwd]"\
}\
var validations = {\
  password: notAnEmptyString\
}\
\
$("#password-btn-save").click(function() {\
  if (!validateElements(elements, validations)) return false;\
  var user = "');  ngx.print(username); ngx.print('";\
  if ($("#home-sel-mode").val() == "35" || $("#home-sel-mobmode").val() == "35") {\
    user = $("#password-sel-username").val();\
  }\
  var password = $(\'input[name="new_pwd"]\').val();\
  var password2 = $(\'input[name="cnf_pwd"]\').val();\
  var salt = $(\'input[name="srp_salt"]\').val();\
  var verifier = $(\'input[name="srp_verifier"]\').val();\
  $(".not-similiar").css("display", "none");\
  $(".short-password").css("display", "none");\
  $(".weak-password").css("display", "none");\
  $(".old-not-password").css("display", "none");\
  if (password != password2) {\
    $("#password-txt-inpwd, #password-txt-repwd").addClass(\'input-error\');\
    $(".not-similiar").css("display", "block");\
    $(".old-not-password").css("display", "none");\
    return;\
  } else if (level < 2) {\
    $("#password-txt-inpwd, #password-txt-repwd").addClass(\'input-error\');\
    $(".weak-password").css("display", "block");\
    return;\
  } else {\
    if (srpError == false)\
    {\
      $("#password-txt-inpwd, #password-txt-repwd").removeClass(\'input-error\');\
      $("#passwordModal").modal("hide");\
    }\
  }\
\
  var srp = new SRP();\
  // Generates srp salt and verifier for new given password\
  function generateSaltAndVerifier() {\
    srp.generateSaltAndVerifierTheCallback(user, password, function(salt, verifier, cryptpw) {\
      $(\'input[name="srp_salt"]\').val(salt);\
      $(\'input[name="srp_verifier"]\').val(verifier);\
      $(\'input[name="password"]\').val("");\
      $(\'input[name="password2"]\').val("");\
      $(".hasPlaceholder").each(function() {\
        $(this).val(\'\');\
      });\
      var target = $("#profile_form").attr("action");\
      var params = $("#profile_form").serializeArray();\
      if ($("#home-sel-mode").val() == "35" || $("#home-sel-mobmode").val() == "35") {\
        params.push({\
          name: "cryptpw",\
          value: cryptpw\
        }, {\
          name: "user_name",\
          value: $("#password-sel-username").val()\
        });\
      } else {\
        params.push({\
          name: "cryptpw",\
          value: cryptpw\
        });\
      }\
      $.post(target, params, function(response) {\
        if (response.status == "success") {\
          $("#passwordModal").modal("hide");\
          $("#pass-modal").modal("show");\
          setTimeout(function() {\
            window.location = "/";\
          }, 5000);\
        } else {\
          $(".articlediv").removeClass("hide").addClass("show");\
          setTimeout(function() {\
            $(".articlediv").removeClass("show").addClass("hide");\
          }, 3000);\
        }\
      });\
    });\
  }\
  var srpError = false;\
  if (variant == "VF-UK") {\
    var oldpassword = $(\'input[name="old_pwd"]\').val();\
    srp.success = generateSaltAndVerifier;\
    srp.error_message = function(response) {\
      srpError = true;\
      $("#passwordModal").modal("show");\
      $("password-txt-oldpwd").addClass(\'input-error\');\
      $(".old-not-password").css("display", "block");\
    }\
    srp.identify("/password", user, oldpassword);\
  } else {\
    generateSaltAndVerifier();\
  }\
});\
\
function CloseModal() {\
  sessionStorage.setItem(\'apply_changes\', "Y");\
  $("#password-txt-oldpwd").val("");\
  $("#password-txt-inpwd").val("");\
  $("#password-txt-repwd").val("");\
  $("#passStrength").removeClass();\
  $("#passStrength").addClass("passwordStrength strength0");\
  $("#password-span-strwk").removeClass("hide").addClass("show");\
  $("#password-span-strgd,#password-span-strsg").removeClass("show").addClass("hide");\
  $(".not-similiar").css("display", "none");\
  $(".short-password").css("display", "none");\
  $(".weak-password").css("display", "none");\
  $("#passwordModal").modal(\'hide\');\
  $(".old-not-password").css("display", "none");\
  $(".old-new-password").css("display", "none");\
  $(".apply-cancel").attr("style","padding-bottom:0px !important; margin-bottom:0px !important");\
}\
if ($("#home-sel-mode").val() == "33" || $("#home-sel-mobmode").val() == "33") {\
  $("#password-div-userselect").hide();\
  $("#password-div-reset").hide();\
  $("#password-div-changepwd").addClass("border-top-none");\
  $("#password-div-left").addClass("border-top-none");\
}\
if ($("#home-sel-mode").val() == "34" || $("#home-sel-mobmode").val() == "34") {\
  $("#password-div-userselect").hide();\
  $("#password-div-reset").hide();\
  $("#password-div-changepwd").addClass("border-top-none");\
  $("#password-div-left").addClass("border-top-none");\
}\
if ($("#home-sel-mode").val() == "35" || $("#home-sel-mobmode").val() == "35") {\
  $("#password-div-userselect").show();\
  $("#password-div-reset").show();\
}\
\
$("#password-btn-confirm").click(function() {\
  var resetParams = {\
    "resetpassword": $("#password-sel-username").val(),\
    "CSRFtoken": $("meta[name=CSRFtoken]").attr("content"),\
    "action": "reset"\
  }\
  $.post("modals/settings/password.lp", resetParams, function(response) {\
    if (response.status == "success")\
      window.location = "/";\
  });\
});\
\
$("#global-apply, #modal-apply").click(function(response) {\
  $(response.target).prop("disabled", true).addClass(\'table-button-faded\');\
  var sessionTime = $("#session-time-sel").val();\
  var params = [];\
  params.push({\
    name: "CSRFtoken",\
    value: "');  ngx.print(CSRFtoken); ngx.print('"\
  }, {\
    name: "sessiontime",\
    value: sessionTime\
  }, {\
    name: "action",\
    value: "SAVE"\
  })\
  $.post("/modals/settings/password.lp", params, function(data) {\
    if (data.status === "success") {\
      // nginx will be restarted to apply the new session timout value\
      // so, wait for a second and then redirect lo login page\
      setTimeout(function() {\
        window.location = "/";\
      }, 1000);\
    } else {\
      // show error message\
      $(".articlediv > .message-arrowbox-applied, .articlediv > .msg-warning").removeClass("show").addClass("hide");\
      $(".articlediv, .articlediv > .msg-error").removeClass("hide").addClass("show");\
      setTimeout(function() {\
        $(".articlediv").removeClass("show").addClass("hide");\
        $(response.target).prop("disabled", false).removeClass(\'table-button-faded\');\
      }, 3000);\
    }\
  });\
  applyCancelPopupHide();\
});\
$("#global-cancel").click(function() {\
  $("#content").load("/modals/settings/password.lp")\
});\
</script>\
'); 