--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local ngx = ngx
local session = ngx.ctx.session
local proxy = require("datamodel")
local username = string.untaint(session:getusername())
local content_helper = require("web.content_helper")

if ngx.req.get_method() == "POST" then
  local postcontent = ngx.req.get_post_args()
  if postcontent["action"] == "SAVE" then
    local path = content_helper.getMatchedContent("uci.web.user.", {name = username})
    if path and #path > 0 then
      path = path[1].path
      if (postcontent["srp_salt"] and postcontent["srp_verifier"]) then
        local srp_table = {}
        srp_table[path.. "srp_salt"] = postcontent["srp_salt"]
        srp_table[path.. "srp_verifier"] = postcontent["srp_verifier"]
        --Will check the rpc param is exist for current user, If yes then set value for pwcrypt.
       if proxy.getPN("rpc.user.@" .. username .. ".pwcrypt", false) and postcontent["cryptpw"] then
        srp_table["rpc.user.@" .. username .. ".pwcrypt"] = postcontent["cryptpw"]
       end
        local success, msg = proxy.set(srp_table)
        if success then
          proxy.apply()
          session:logout()
          ngx.print("success")
        else
          ngx.print("error")
        end
      end
    end
    ngx.exit(ngx.HTTP_OK)
  end
end
  ngx.print('\
  <h1>');  ngx.print(T"Password" ); ngx.print('</h1>\
  <h2>');  ngx.print(T"Set a password for your Vodafone Ultra Hub."); ngx.print('</h2>\
   <h3>');  ngx.print(T"Login Account"); ngx.print('</h3>\
   <div class="h3-content no-padding-bottom set-password content-password">\
    <div class="row not-flex-row">\
    <div class="col-md-12 padding-top-bottom-20" style="text-align: right;">\
       <input type="button" class="button button-blank change-pw mobile-full" value="');  ngx.print(T"Change Password "); ngx.print('" id = "password_btn_chpass" data-toggle="modal" data-target="#passwordModal" />\
    </div>\
  </div>\
   </div>\
  <!-- Password Popup Modal-->\
  <div class="modal fade" id="passwordModal" role="dialog" tabindex="-1" aria-hidden="true" data-keyboard="false" data-backdrop="static">\
    <div class="modal-dialog">\
      <!-- Modal content-->\
      <div class="modal-content change-password-content">\
        <div class="modal-header hidden-md hidden-sm hidden-lg">\
          <div class="mobile-cancel-popup button-cancel" data-dismiss="modal">\
          </div>\
        </div>\
        <div class="modal-body no-padding mobile-modal-padding-top">\
          <form method="post" action="');  ngx.print( ngx.var.request_uri ); ngx.print('"  id="profile_form" class="form-horizontal">\
            <input type="hidden" name="CSRFtoken" id="CSRFtoken" value="');  ngx.print( ngx.ctx.session:getCSRFtoken() ); ngx.print('">\
            </input>\
          <input type="hidden" name= "action" id="action" value="SAVE">\
          </input>\
        <input type="hidden" name= "srp_salt" id="srp_salt" value = "" >\
        </input>\
      <input type="hidden" name= "srp_verifier" id="srp_verifier" value = "">\
      </input>\
        <p class="title tL">\
          ');  ngx.print(T"Enter a password for your Vodafone Ultra Hub"); ngx.print('\
        </p>\
		<div class="h3-content no-padding-bottom">\
          ');  ngx.print(T"Login Account: ".. username); ngx.print('\
        </div>\
		<div  class="vdf-row">\
		<div class="left">\
		 <label for="password-txt-inpwd" class="password-modal-label">');  ngx.print(T"Password" ); ngx.print('\
        </label>\
		</div>\
		<div class="right">\
		<input type="password" class="inputKeyPress" id="password-txt-inpwd" name="new_pwd" placeholder="');  ngx.print(T"Password"); ngx.print('"/>\
		</div>\
		</div>\
		<div class="vdf-row">\
		<div class="left">\
		<label for="password-txt-repwd" class="password-modal-label">');  ngx.print(T"Re-enter Password"); ngx.print('</label>\
		</div>\
		<div class="right">\
		<input type="password"  name= "cnf_pwd" id="password-txt-repwd" placeholder="');  ngx.print(T"Password"); ngx.print('" />\
		</div>\
		</div>\
		<div class="vdf-row">\
		<div class="left" style="width:65%">\
		<label for="inputPassword3" class="password-modal-label2">');  ngx.print(T"Password Strength"); ngx.print('</label>\
		</div>\
		<div class="right">\
		<div id="passStrength" class="passwordStrength strength0">\
          <span id="password-span-strwk" class="show"  >');  ngx.print(T"Weak"); ngx.print('\
          </span>\
		  <span id="password-span-strgd" class="hide">');  ngx.print(T"Good"); ngx.print('\
          </span>\
		  <span id="password-span-strsg" class="hide">');  ngx.print(T"Strong"); ngx.print('\
          </span>\
        </div>\
      </div>\
	  </div>\
	  <div class="table-wrapper">\
          <div class="message message-info message-error not-8-characterss"  id = "password-msg-infopwdstd" style="display: block;">\
            ');  ngx.print( T"Password must contain at least 12 alphanumeric characters including both upper and lower case letters, at least one number"); ngx.print('\
          </div>\
          <div class="message message-info message-error not-similiar" id ="password-msg-errpwdmatch" style="display: none;">\
            ');  ngx.print(T"The passwords you entered do not match."); ngx.print('\
          </div>\
          <div class="message message-info message-error weak-password" id ="password-msg-errpwdminsec" style="display: none;">\
            ');  ngx.print(T"The password you have entered doesn't meet the minimum security requirements."); ngx.print('\
          </div>\
        </div>\
		<div class="apply-cancel">\
		  <input class="button button-apply save mob-button-width" value="');  ngx.print(T"Save"); ngx.print('"  id="password-btn-save" " type="button"  />\
            <input class="button button-cancel close-password-popup mob-apply-cancel mob-button-width" id="password-btn-cancel" data-dismiss="modal" value="');  ngx.print(T"Cancel"); ngx.print('" type="button" onClick="CloseModal()" />\
		  </div>\
    </form>\
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
              <p>\
                ');  ngx.print(T"Password changed successfully."); ngx.print('\
              </p>\
            </div>\
          </div>\
          <div class="form-group no-margin-bottom">\
            <div class="col-sm-12">\
              <div class="modal-footer">\
               <input value="');  ngx.print(T"OK"); ngx.print('" class="button button-apply mob-button-width" id="pass-apply" type="button" data-dismiss="modal"> \
              </div>\
            </div>\
          </div>\
        </form>\
      </div>\
    </div>\
  </div>\
</div>\
<!-- End -->\
<script src="/js/srp-min.js" >\
</script>\
<script src="/js/global.js" >\
</script>\
<script>\
  $(function(){\
    $(\'#show-hide-guest-pw\').click(function() {\
      if (!$(this).is(\':checked\')) {\
        $(\'input#pw1\').removeAttr("type");\
        $(\'input#pw1\').attr(\'type\', \'password\');\
      }\
      else{\
        $(\'input#pw1\').removeAttr("type");\
        $(\'input#pw1\').attr(\'type\', \'text\');\
      }\
    });\
  });\
\
  $("#password_btn_chpass").click(function() {\
    $("#profile_form [type=password]").removeClass(\'input-error\');\
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
    if(!validateElements(elements, validations)) return false;\
    var user = "');  ngx.print(username); ngx.print('";\
    var password = $(\'input[name="new_pwd"]\').val();\
    var password2 = $(\'input[name="cnf_pwd"]\').val();\
    $(".not-similiar").css("display", "none");\
    $(".short-password").css("display", "none");\
    $(".weak-password").css("display", "none");\
    $(".wrong-password").css("display", "none");\
    if (password != password2) {\
      $("#password-txt-inpwd, #password-txt-repwd").addClass(\'input-error\');\
      $(".not-similiar").css("display", "block");\
      $(".wrong-password").css("display", "none");\
      return;\
    } else if (level < 4 ) {\
      $("#password-txt-inpwd, #password-txt-repwd").addClass(\'input-error\');\
      $(".weak-password").css("display", "block");\
      return;\
    } else {\
      $("#password-txt-inpwd, #password-txt-repwd").removeClass(\'input-error\');\
      $("#passwordModal").modal("hide");\
      $("#pass-modal").modal("show");\
    }\
   });\
\
   $("#pass-apply").click(function(){\
    var user = "');  ngx.print(username); ngx.print('";\
    var password = $(\'input[name="new_pwd"]\').val();\
    var password2 = $(\'input[name="cnf_pwd"]\').val();\
    var salt = $(\'input[name="srp_salt"]\').val();\
    var verifier = $(\'input[name="srp_verifier"]\').val();\
    var srp = new SRP();\
    // Generates srp salt and verifier for new given password\
    function generateSaltAndVerifier(){\
    srp.generateSaltAndVerifierTheCallback(user, password, function(salt, verifier, cryptpw) {\
      $(\'input[name="srp_salt"]\').val(salt);\
      $(\'input[name="srp_verifier"]\').val(verifier);\
      $(\'input[name="password"]\').val("");\
      $(\'input[name="password2"]\').val("");\
      $(".hasPlaceholder").each(function(){\
        $(this).val(\'\');\
      });\
      var target = $("#profile_form").attr("action");\
      var params = $("#profile_form").serializeArray();\
      params.push({\
        name : "cryptpw",\
        value : cryptpw\
      });\
        $.post(target, params, function(response){\
        if(response == "success"){\
          sessionStorage.setItem(\'apply_changes\', "Y");\
          window.location = "/";\
          }\
          else{\
          $(".articlediv").removeClass("hide").addClass("show");\
          setTimeout(function() {\
            $(".articlediv").removeClass("show").addClass("hide");\
          }, 3000);\
        }\
      });\
    });\
  }\
  generateSaltAndVerifier();\
  });\
\
  function CloseModal(){\
    sessionStorage.setItem(\'apply_changes\', "Y");\
    $("#password-txt-inpwd").val("");\
    $("#password-txt-repwd").val("");\
    $("#passStrength").removeClass();\
    $("#passStrength").addClass("passwordStrength strength0");\
    $("#password-span-strwk").removeClass("hide").addClass("show");\
    $("#password-span-strgd,#password-span-strsg").removeClass("show").addClass("hide");\
    $(".not-similiar").css("display", "none");\
    $(".short-password").css("display", "none");\
    $(".weak-password").css("display", "none");\
    $(".wrong-password").css("display", "none");\
    $("#passwordModal").modal(\'hide\');\
  }\
</script>\
'); 