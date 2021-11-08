$("#showPassword").prop('checked', false);
function showPass() {
  var pass_show = document.getElementById("srp_password");
  if (pass_show.type === "password") {
    pass_show.type = "text";
  } else {
    pass_show.type = "password";
  }
}

function hex_to_ascii(str) {
  var hex  = str.toString();
  var str = '';
  for (var n = 0; n < hex.length; n += 2) {
    str += String.fromCharCode(parseInt(hex.substr(n, 2), 16));
  }
  return str;
}

var timeSecond;
$(document).ready(
  function() {
    var password = "";
    var tries = 0;
    window.sessionStorage.removeItem("current_role");

    // Set the focus on the first input field
    $('form:first *:input[type!=hidden]:first').focus();
    // Handle press of enter. Could be handled by adding a hidden input submit but
    // this requires a lot of css tweaking to get it right since display:none does
    // not work on every browser. So go for the js way
    $('form input').keydown(function(e) {
        if(e.which == 13 || e.which == 10) {
            e.preventDefault();
            $("#sign-me-in").click();
        }
    });

    $("#sign-me-in").on("click", function () {
      $(this).text(verifying);
      if(loginFailureAttempt){
        password = $("#srp_password")[0].value;
        //If the user has option legacy_salt, do migration
        var inputUsername = $("#srp_username")[0].value;
        var index = -1;
        var userNameArray = userNames.split(",")
        var legacySaltArray = legacySalts.split(",")
        var timesecond;
        var tries = 0;
        if(forgotPassword){
          if (inputUsername == "forgotpassword")
          {
            $("#sign-me-in").text(signIn);
            $("#erroruserpass").show();
            $(".control-group").addClass("error");
            return;
          }
        }
        for (var i = 0; i < userNameArray.length - 1; i ++)
        {
          if ( inputUsername == userNameArray[i] )
          {
            index = i;
          }
        }
        if (index >= 0)
        {
          var hashObj = new jsSHA((legacySaltArray[index]+tch.stringToHex(password)), "HEX");
          password = hashObj.getHash("SHA-1", "HEX");
        }
      }

      var srp = new SRP();
      srp.success = function() {
        // If we showed the login page using an internal redirect (detected
        // by checking if the URL ends with "/login.lp") then we simply
        // have to reload the page to get the actual page content now that
        // we're logged in.
        // Otherwise we explicitly go back to the main page.
        var key = srp.key();
        key = hex_to_ascii(key)
        window.sessionStorage.setItem("session_key", key);
        if(lastAccess){
          $.get("login.lp", {action:"lastaccess"}, function (data){
             pathLoad();
          });
        }
        else{
          pathLoad();
        }
      }
      function pathLoad() {
        if (window.location.pathname.search(/\/login\.lp$/) == -1){
          var curl = window.location.href
          window.location.href = curl.substring(0,curl.indexOf("#"));
        }else
          window.location = "/";
      }
      srp.error_message = function(err) {
      if(err == 403){
        $.get("login.lp", function (data){
        var token = $(data).filter('meta[name="CSRFtoken"]').attr('content');
        $('meta[name=CSRFtoken]').attr('content', token);
        //if(!loginFailureAttempt){
        //    srp.identify("/authenticate", $("#srp_username")[0].value, password);
        //}
        // else {
            if (!$("#loginfailure").is(":visible")) {
              srp.identify("/authenticate", $("#srp_username")[0].value, password);
            }
        // }
        });
      }else{
        $("#sign-me-in").text(signIn);
        $("#erroruserpass").show();
        $(".control-group").addClass("error");
      }
      if(loginFailureAttempt){
        timeSecond = err.waitTime;
        tries = err.wrongCount;
        if (timeSecond > 0 ) {
          $("#timerSec").text(timeSecond);
          $("#pwdCount").text(tries);
          $('#loginfailure').modal('show');
          $("#loginfailure .popUp").css({"left":(($(document.body).width()/2)-($("#loginfailure .popUp").width()/2)) +"px","margin-left":"0px"});
          $("#loginfailure").css({"right":"0px"});
        }
        updateWaitingTime();
      }
      else{
        tries++;
      }

        if(triesbeforemsg > 0 && tries >= triesbeforemsg) {
            $("#defaultpassword").show();
        }
      }
      function updateWaitingTime() {
        var timeInterval = setInterval(function() {
          $("#timerSec").text(--timeSecond);
          if (timeSecond <= 0) {
            clearInterval(timeInterval);
            $('#loginfailure').modal('hide');
            $("#sign-me-in").removeAttr("disabled");
          };
        }, 1000);
      }
      if(loginFailureAttempt){
        if (!$("#loginfailure").is(":visible")) {
          srp.identify("/authenticate", $("#srp_username")[0].value, password);
        }
      }
      else{
        srp.identify("/authenticate", $("#srp_username")[0].value, $("#srp_password")[0].value);
      }
    });
    if(forgotPassword){
      $("#forgot-login-password").on("click", "a", function(){
        $("#login").hide();
        $("#forgot-login").show();
        $(".control-group").removeClass("error");
      });
      $("#verify-password").click(function(){
        var srp = new SRP();
        srp.success = function() {
          window.location = "/password-reset.lp";
          $("#login").hide();
          $("#forgot-login").hide();
        }
        srp.error_message = function(err) {
          $("#verify-password").text(verify);
          $("#erroruserpass1").show();
          $(".control-group").addClass("error");
        }
        if (this.id == "verify-password")
        {
         password = $("#srp_password1").val();
        }
        srp.identify("/authenticate", "forgotpassword", password);
      });
    }
  })
