--pretranslated: do not change this file
 
-- Enable localization
gettext.textdomain('webui-core')

local triesbeforemsg = 3
local ui_helper = require("web.ui_helper")
  ngx.print('\
\
');  ngx.print( ui_helper.createHeader(T"Guided View") ); ngx.print('\
\
<div class="modal-body update">\
  <form class="form-horizontal" method="post" action="modals/device-modal.lp">\
    <div class="span4">\
      ');  
       local lp = require("web.lp")
       lp.setpath("/www/snippets/")
       lp.include("nav-basicview-actions.lp")
       ngx.print('\
    </div>\
    <div class="span7">\
    <fieldset>\
      <legend>');  ngx.print( T"Change myrouter password (Access Key)" ); ngx.print('</legend>\
        ');  
          local infoclass = {
            alert = {
              class = "alert-info",
            }
          }
          ngx.print('\
        ');  ngx.print( ui_helper.createAlertBlock(T"You can change the password to access your router user interface", infoclass) ); ngx.print('\
        <div class="alert alert-error hide">\
          <p>');  ngx.print( T"Invalid password" ); ngx.print('</p>\
        </div>\
        <div class="alert alert-success hide">\
          <p>');  ngx.print( T"Password changed successfully" ); ngx.print('</p>\
        </div>\
        ');  
          local inputclass = {
            label = {
              class = "long"
            },
            controls = {
              class = "long"
            },
            input = {
              class= "span4",
            }
          }
          html = {}
          html[#html + 1] = ui_helper.createInputPassword(T"Current access key", "srp_password", "", inputclass)
          html[#html + 1] = ui_helper.createInputPassword(T"New access key", "srp_password_new_1", "", inputclass)
          html[#html + 1] = ui_helper.createInputPassword(T"Confirm access key", "srp_password_new_2", "", inputclass)
          ngx.print(html)
          ngx.print('\
        <div class="pull-left">\
          <a href="/home.lp" class="btn btn-large">');  ngx.print( T"Cancel" ); ngx.print('</a>\
          &nbsp;\
          <div id="change-my-pass" class="btn btn-primary btn-large">');  ngx.print( T"Change password" ); ngx.print('</div>\
        </div>\
    </fieldset>\
    </div>\
  </form>\
</div>\
\
<script src="/js/srp-min.js" ></script>\
<script>\
$(document).ready(\
  function() {\
    var triesbeforemsg = ');  ngx.print( triesbeforemsg ); ngx.print(';\
    var tries = 0;\
\
    function display_error_input(id, msg)\
    {\
        $("#change-my-pass").text(\'');  ngx.print( T"Change password" ); ngx.print('\');\
        $(".alert-error").show();\
        var upass = $(\'.modal input[name=\'+id+\']\');\
        upass.addClass("error");\
        upass.closest(".control-group").addClass("error");\
        upass.first().after(\'<span class="help-inline">\' + msg + \'</span>\');\
    }\
\
    function clear_error_input(id)\
    {\
        var upass = $(\'.modal input[name=\'+id+\']\');\
        upass.removeClass("tooltip-on error");\
        upass.closest(".control-group").removeClass("error");\
        upass.first().next().remove();\
    }\
\
    function display_success()\
    {\
        $("#change-my-pass").text(\'');  ngx.print( T"Change password" ); ngx.print('\');\
        $(".alert-error").hide();\
        $(".alert-success").show();\
    }\
\
    // Handle press of enter. Could be handled by adding a hidden input submit but\
    // this requires a lot of css tweaking to get it right since display:none does\
    // not work on every browser. So go for the js way\
    $(\'form input\').keydown(function(e) {\
        if(e.which == 13 || e.which == 10) {\
            e.preventDefault();\
            $("#change-my-pass").click();\
        }\
    });\
\
    $("#change-my-pass").on("click", function () {\
      clear_error_input("srp_password");\
      clear_error_input("srp_password_new_1");\
      clear_error_input("srp_password_new_2");\
      if ($("input[name=srp_password_new_1]").val() === "") {\
        display_error_input("srp_password_new_1", "Please input a new password");\
        return false;\
      }\
      if ($("input[name=srp_password_new_1]").val() != $("input[name=srp_password_new_2]").val()) {\
        display_error_input("srp_password_new_2", "The new passwords do not match");\
        return false;\
      }\
      $(this).text(\'');  ngx.print( T"Updating" ); ngx.print('\');\
      var srp = new SRP();\
      srp.success = function() {\
        srp.generateSaltAndVerifier("/password", \'');  ngx.print( ngx.ctx.session:getusername() ); ngx.print('\', $("input[name=srp_password_new_1]").val())\
      }\
      srp.passwordchanged = function() {\
        display_success();\
      }\
      srp.error_message = function() {\
        display_error_input("srp_password", "Invalid access key");\
        tries++;\
        if(triesbeforemsg > 0 && tries >= triesbeforemsg) {\
            $("#defaultpassword").show();\
        }\
      }\
      srp.identify("/password", \'');  ngx.print( ngx.ctx.session:getusername() ); ngx.print('\', $("input[name=srp_password]").val());\
    });\
  })\
</script>\
'); 