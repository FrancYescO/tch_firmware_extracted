$(document).ready(function() {
  $("#ra_enabled").val() == 0 ? $("#mode").attr("disabled", true) : $("#mode").attr("disabled", false);
  $('#password').parent().after('<div class = "controls"><div id="Strength"></div></div>');
});
function randomPasswordCheck()
{
  var passwordVal = $("#random_psw").is(':checked') ? "checked" : "no";
  if (passwordVal == "checked"){
    $("#password").hide();
    clearErrorPassword();
  }
  else{
    $("#password").show();
  }
}
$("#random_psw").on("click",function(){
  randomPasswordCheck();
});

randomPasswordCheck();
$('#password').keyup(function() {
  var level = passwordCheck(this.value);
  $('#Strength').removeClass().addClass("strength" + level);
  $("#Strength").css("width", 54*level);
});

$("#ra_enabled").change(function() {
  $("#mode").attr("disabled", $("#ra_enabled").val() == 0 ? true : false);
});

function displayErrorMessage(msg)
{
  var upass = $('.modal input[name="password"]');
  upass.addClass("error");
  upass.closest(".control-group").addClass("error");
  upass.first().after('<span class="help-inline">' + msg + '</span>');
}

function clearErrorPassword()
{
  var upass = $('.modal input[name="password"]');
  upass.removeClass("tooltip-on error");
  upass.closest(".control-group").removeClass("error");
  upass.next().remove();
}

$("#save-assistance-config").click(function () {
  function sendData() {
    var form = $(".modal form");
    var params = form.serializeArray();
    params.push({
      name : "action",
      value : "SAVE"
    }, tch.elementCSRFtoken());
    tch.loadModal(form.attr("action"), params, function () {
      var error = $('.error');
      if (error.length > 0) {
        // We are in an error case
        // Show the save/close buttons since nothing has been saved
        $('#modal-no-change').hide();
        $('#modal-changes').show();
      }
      $('.error input:not([type = "hidden"])').first().focus();
    });
    tch.removeProgress();
  };

  clearErrorPassword();
  var password = $('input[name = "password"]').val();

  if (!$("#random_psw").prop("checked")) {
    if(password != "" && password != undefined && ((password.length < 12) || (passwordCheck(password)) < 4)) {
      displayErrorMessage(password.length == 0 ? passErrMsg : passCondMsg );
    return false;
    }
  }
  if(password != "" && password != undefined) {
    var srp = new SRP();
    srp.generateSaltAndVerifierTheCallback(user, password, function(salt, verifier) {
      $('input[name = "salt"]').val(salt);
      $('input[name = "verifier"]').val(verifier);
      $('input[name = "password"]').val("");
      sendData();
      return;
    });
  }
  else {
    sendData();
    return;
  }
});

function passwordCheck(password)
{
  var level = 0;

  //if password has both lower and uppercase characters give 1 point
  if ( ( password.match(/[a-z]/) ) && ( password.match(/[A-Z]/) ) ) level++;

  //if password has at least one number give 1 point
  if (password.match(/\d+/)) level++;

  //if password has at least one special caracther give 1 point
  if ( password.match(/[!,@,#,$,%,^,&,*,?,_,~,-,(,)]/) )  level++;

  //if password length is greater than or equal to 12 give 1 point
  if ( password.length >= 12 ) level++;

  //if password length is greater than 12 and passwordCheck level is equal to 4 give 1 point
  if (( password.length > 12 ) && (level == 4)) level++;

  return level;
}
