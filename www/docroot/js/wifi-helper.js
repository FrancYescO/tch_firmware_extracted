// Function for validate password when keyboard key is released
var passCheck;
$(".inputKeyPressed").keyup(function() {
  var passwordVal = $(this).val();
  passwordValidateStrength(passwordVal);
  passValidateCheck();
});

$("#wifiGen-info-pwd2").keyup(function() {
  passValidateCheck();
  passEqualCheck();
});

function passEqualCheck() {
  var newPassword = $('input[name="new_pwd"]').val();
  var retypePassword = $('input[name="cnf_pwd"]').val();
  if (newPassword == "" || retypePassword == "") {
    $(".not-similar").css("display", "none");
    return;
  }
  if (newPassword != retypePassword) {
    $(".not-similar").css("display", "block");
    return;
  } else if (asciiLevel <= 2) {
    $(".not-similar").css("display", "none");
    $("#password_apply").addClass("op40");
    return;
  } else if ((newPassword.length > 64) || (retypePassword.length > 64)) {
    $("#password_apply").addClass("op40");
    return;
  } else {
    $(".not-similar").css("display", "none");
    $("#password_apply").removeClass("op40");
  }
}

function passValidateCheck() {
  var newPassword = $('input[name="new_pwd"]').val();
  var retypePassword = $('input[name="cnf_pwd"]').val();
  var securityMode24 = $("#wifiGen-sel-mode24").val();
  var securityMode5 = $("#wifiGen-sel-mode5").val();
  if (newPassword == "") {
    $(".not-similar").css("display", "none");
    $(".weak-password").css("display", "none");
    $("#wifiGen2-info-pwd64").addClass("hide");
    $("#wifiGen-info-char").addClass("hide");
    $("#password_apply").addClass("op40");
    return false;
  }
  if ((newPassword.length < 8) && (asciiLevel < 3)) {
    $(".weak-password").css("display", "none");
  }
  if ((newPassword.length > 64) || (retypePassword.length > 64)) {
    $("#wifiGen2-info-pwd64").removeClass("hide");
    $(".apply-cancel").attr("style","padding-bottom:40px !important; margin-bottom:50px !important");
    $("#password_apply").addClass("op40");
    return false;
  } else {
    $("#wifiGen2-info-pwd64").addClass("hide");
    $(".apply-cancel").attr("style","padding-bottom:0px !important; margin-bottom:0px !important");
    $("#password_apply").removeClass("op40");
  }
  if ((newPassword.length == 64) && (hexLevel < 3)) {
    $("#wifiGen-info-char").removeClass("hide");
    $("#password_apply").addClass("op40");
    return false;
  } else {
    $("#wifiGen-info-char").addClass("hide");
    $("#password_apply").addClass("op40");
  }
  //if password matches with the list of invalid keys then return false and display error message
  if ($.inArray(newPassword, invalidKeys) >= 0) {
    $(".weak-password").css("display", "block");
    return false;
  } else if (newPassword.length < 8 || newPassword.length > 64) {
    return false;
  } else if (asciiLevel == 1 && hexLevel != 3) {
    $(".weak-password").css("display", "block");
    return false;
  } else if (!(newPassword.match(/^[\x20-\xFE]+$/))) {
    $("#password_apply").addClass("op40");
    return false;
  } else if (newPassword == "") {
    $(".not-similar, .weak-password").css("display", "none");
    $("#password_apply").addClass("op40");
    return false;
  } else {
    return true;
  }
}

// Validate password
function passwordValidateStrength(password) {
  asciiLevel = 0, hexLevel = 0;
  // valid_characters check is changed from ASCII decimal characters from 32 to 254.
  var valid_character = /^[\x20-\xFE]+$/;
  if ($.inArray(password, invalidKeys) >= 0) {
    asciiLevel = 1;
  } else {
    if (password.match(valid_character)) {
      if (password.length < 8) {
        asciiLevel = 1;
      } else if (password.length == 64) {
        if (password.match(/^[0-9]+$/)) {
          hexLevel = 5;
        } else if (password.match(/^[a-fA-F0-9]+$/)) {
          hexLevel = 3;
          asciiLevel = 3;
        }
      } else if (password.match(/^[0-9]+$/) && (password.length > 63)) {
        asciiLevel = 5;
      } else if (password.match(/^[a-fA-F0-9]+$/) && (password.length > 64)) {
        hexLevel = 4;
        asciiLevel = 0;
      } else if (password.match(/^[a-fA-F0-9]+$/) && (password.length == 64)) {
        hexLevel = 3;
        asciiLevel = 3;
      } else {
        if (password.match(/[\x20-\x2F]/) || password.match(/[\x3A-\x40]/) || password.match(/[\x5B-\x60]/) || password.match(/[\x7B-\x7E]/) || password.match(/[\x80-\xFE]/)) {
          asciiLevel++;
        }
        if (password.match(/\d+/)) {
          asciiLevel++;
        }
        if (variant == "ES") {
          //spanishSmallN variable takes "ñ" and spanishCapN takes "Ñ" characters as they are used as alphabets in spanish.
          var spanishSmallN = String.fromCharCode(241);
          var spanishCapN = String.fromCharCode(209);
          if (password.match(/[a-z]/) || password.match(spanishSmallN)) {
            asciiLevel++;
          }
          if (password.match(/[A-Z]/) || password.match(spanishCapN)) {
            asciiLevel++;
          }
        }
        else {
          if (password.match(/[a-z]/)) {
            asciiLevel++;
          }
          if (password.match(/[A-Z]/)) {
            asciiLevel++;
          }
        }
      }
    }
  }
  if (asciiLevel <= 2 && hexLevel < 1) {
    $('#passStrength').removeClass();
    $('#passStrength').addClass("passwordStrength strength1");
    $("#password-span-strwk, #password-span-defaultwk").removeClass("hide").addClass("show");
    if (variant == "NZ" && asciiLevel == 2 ) {
      $("#password_apply").removeClass("op40");
    }
    else {
      $("#password_apply").addClass("op40");
    }
    $("#password-span-strgd, #password-span-strsg").removeClass("show").addClass("hide");
    $(".weak-password").css("display", "block");
  } else if ((asciiLevel == 3) || (hexLevel == 3)) {
    $('#passStrength').removeClass();
    $('#passStrength').addClass("passwordStrength strength2");
    $("#password-span-strgd").removeClass("hide").addClass("show");
    $("#password_apply").removeClass("op40");
    $("#password-span-strsg, #password-span-strwk,#password-span-defaultwk").removeClass("show").addClass("hide");
    $(".weak-password").css("display", "none");
  } else if ((asciiLevel == 4) || (hexLevel == 5 && asciiLevel == 0)) {
    $('#passStrength').removeClass();
    if (password.length >= 12) {
      $('#passStrength').addClass("passwordStrength strength4");
      $("#password-span-strsg").removeClass("hide").addClass("show");
      $("#password-span-strgd").removeClass("show").addClass("hide");
    }
    else {
      $('#passStrength').addClass("passwordStrength strength3");
      $("#password-span-strgd").removeClass("hide").addClass("show");
      $("#password-span-strsg").removeClass("show").addClass("hide");
    }
    $("#password_apply").removeClass("op40");
    $("#password-span-strwk, #password-span-defaultwk").removeClass("show").addClass("hide");
    $(".weak-password").css("display", "none");
  } else if ((hexLevel == 4 && asciiLevel == 0) || (asciiLevel == 5)) {
    $('#passStrength').removeClass();
    $('#passStrength').addClass("passwordStrength strength1");
    $("#password-span-strwk, #password-span-defaultwk").removeClass("hide").addClass("show");
    $("#password_apply").addClass("op40");
    $("#password-span-strsg, #password-span-strgd").removeClass("show").addClass("hide");
  }
}
