<%
-- Enable localization
gettext.textdomain('webui-core')

local triesbeforemsg = 3
local ui_helper = require("web.ui_helper")
%>

<%= ui_helper.createHeader(T"Guided View") %>

<div class="modal-body update">
  <form class="form-horizontal" method="post" action="modals/device-modal.lp">
    <div class="span4">
      <%
       local lp = require("web.lp")
       lp.setpath("/www/snippets/")
       lp.include("nav-basicview-actions.lp")
     %>
    </div>
    <div class="span7">
    <fieldset>
      <legend><%= T"Change myrouter password (Access Key)" %></legend>
        <%
          local infoclass = {
            alert = {
              class = "alert-info",
            }
          }
        %>
        <% = ui_helper.createAlertBlock(T"You can change the password to access your router user interface", infoclass) %>
        <div class="alert alert-error hide">
          <p><%= T"Invalid password" %></p>
        </div>
        <div class="alert alert-success hide">
          <p><%= T"Password changed successfully" %></p>
        </div>
        <%
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
        %>
        <div class="pull-left">
          <a href="/home.lp" class="btn btn-large"><%= T"Cancel" %></a>
          &nbsp;
          <div id="change-my-pass" class="btn btn-primary btn-large"><%= T"Change password" %></div>
        </div>
    </fieldset>
    </div>
  </form>
</div>

<script src="/js/srp-min.js" ></script>
<script>
$(document).ready(
  function() {
    var triesbeforemsg = <%= triesbeforemsg %>;
    var tries = 0;

    function display_error_input(id, msg)
    {
        $("#change-my-pass").text('<%= T"Change password" %>');
        $(".alert-error").show();
        var upass = $('.modal input[name='+id+']');
        upass.addClass("error");
        upass.closest(".control-group").addClass("error");
        upass.first().after('<span class="help-inline">' + msg + '</span>');
    }

    function clear_error_input(id)
    {
        var upass = $('.modal input[name='+id+']');
        upass.removeClass("tooltip-on error");
        upass.closest(".control-group").removeClass("error");
        upass.first().next().remove();
    }

    function display_success()
    {
        $("#change-my-pass").text('<%= T"Change password" %>');
        $(".alert-error").hide();
        $(".alert-success").show();
    }

    // Handle press of enter. Could be handled by adding a hidden input submit but
    // this requires a lot of css tweaking to get it right since display:none does
    // not work on every browser. So go for the js way
    $('form input').keydown(function(e) {
        if(e.which == 13 || e.which == 10) {
            e.preventDefault();
            $("#change-my-pass").click();
        }
    });

    $("#change-my-pass").on("click", function () {
      clear_error_input("srp_password");
      clear_error_input("srp_password_new_1");
      clear_error_input("srp_password_new_2");
      if ($("input[name=srp_password_new_1]").val() === "") {
        display_error_input("srp_password_new_1", "Please input a new password");
        return false;
      }
      if ($("input[name=srp_password_new_1]").val() != $("input[name=srp_password_new_2]").val()) {
        display_error_input("srp_password_new_2", "The new passwords do not match");
        return false;
      }
      $(this).text('<%= T"Updating" %>');
      var srp = new SRP();
      srp.success = function() {
        srp.generateSaltAndVerifier("/password", '<%= ngx.ctx.session:getusername() %>', $("input[name=srp_password_new_1]").val())
      }
      srp.passwordchanged = function() {
        display_success();
      }
      srp.error_message = function() {
        display_error_input("srp_password", "Invalid access key");
        tries++;
        if(triesbeforemsg > 0 && tries >= triesbeforemsg) {
            $("#defaultpassword").show();
        }
      }
      srp.identify("/password", '<%= ngx.ctx.session:getusername() %>', $("input[name=srp_password]").val());
    });
  })
</script>
