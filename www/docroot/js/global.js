function noRuleMessage(id){
  var rowLength = $("#"+id).find("tr").length;
  if (rowLength == 3 ){
    $("#des-no-rule").css("display","");
    $("#mob-no-rule").css("display","");
  }else {
    $("#des-no-rule").css("display","none");
    $("#mob-no-rule").css("display","none");
  }
}

function formatTime(time){
  if (!(/^\d+:\d+$/).test(time)) return time;
    var regExp = /^\d+|\d+$/g;
    function padZero(value) {
      return ("0" + value).slice(-2);
    }
    return time.replace(regExp, padZero);
}

function btn_on_off($this){
  $this.toggleClass('button-on button-off');
}

/**
 * Function to validate values of GUI elements.
 * Also it will add red border around all invalid values
 * @param {object} elements - contains element's Jquery selector
 *                            If selectors return multiple elements, validation happens for all the elements it returns
 * @param {object} validations - contains validations for each elements
                                 Validation can be either a function or a regular expression
 * @returns {boolean} true if everything is valid, false if anything is invalid
 */
function validateElements(elements, validations) {
  var isValid = true;
  $.each(elements, function(key, selector) {
    selector = $(selector);
    $.each(selector, function() {
      var validation = validations[key];
      if ($.type(validation) == "function" && !validation($(this).val()) ||
            $.type(validation) == "regexp" && !validation.test($(this).val())) {
        isValid = false;
        $(this).addClass('input-error');
      } else $(this).removeClass('input-error');
    });
  });
  $(".input-error:first").focus();
  return isValid;
}

$(function() {
  $('#home-btn-session').click(function() {
    $('#session-popup-time').modal('hide');
    window.location.href = '/login.lp';
    return false;
  });
  $("#mobile-btn-pinenb, #wifiset-btn-lowchnsel, #wifiset-btn-highchnsel, #wifiset-btn-highdfs").click(function() {
    btn_on_off($(this));
  });
  $("#mobile-btn-status").click(function() {
    btn_on_off($(this));
  });
  $("#mobile-btn-connect").click(function() {
    btn_on_off($(this));
  });
  $("#mobile-btn-autofailover").click(function() {
    btn_on_off($(this));
    var autofailover = $(this).hasClass("button-on")? 1 : 0;
    if (autofailover == "0") {
      $("#mobile-section-connect").removeClass("hide").addClass("show");
    } else {
      $("#mobile-section-connect").removeClass("show").addClass("hide");
    }
  });
  $('div.pin-enable, .toggle-content-button, div.button-change').click(function() {
    btn_on_off($(this));
  });
  $(".button-cancel").click(function() {
    if (typeof(Storage) !== "undefined") {
      // Save data to sessionStorage
      sessionStorage.setItem('apply_changes', "Y");
    } else {
      console.log("Sorry! No Web Storage support..");
    }
    $(".articlediv").removeClass("show").addClass("hide");
  });
  $(".inputKeyPress").keyup(function() {
    var passwordVal = $(this).val();
    passwordCheck(passwordVal);
  });
  //Auto Complete off for IE
  $('input').attr('autocomplete','off');
});

// Exclude these ids from page change detection
var inputExcludeIDs = ["oviewmodal-txt-name", "diagUtility-txt-host"];
var selectExcludeIDs = ["home-sel-mode", "home-sel-mobmode", "call-log-select-logtype", "client-sel-devices"];

$('#modal-content').on('shown.bs.modal', function() {
    $("body.modal-open").removeAttr("style");
});
$('.menubar-close').click(function() {
    $("html, body").animate( {
        scrollTop: 0
    }, "slow");
});

function passwordCheck(password) {
    level = 0;
    //if password bigger than 6 give 1 point
    if (password.length >= 6) {
        level++;
    }
    //if password has both lower and uppercase characters give 1 point
    if ((password.match(/[a-z]/)) && (password.match(/[A-Z]/))) {
        level++;
    }
    //if password has at least one number give 1 point
    if (password.match(/\d+/)) {
        level++;
    }
    //if password has at least one special caracther give 1/2 point
    if (password.match(/[!@#$%^&*?_~\-()]/)) {
        level+=0.5;
    }
    //if password bigger than 12 give another 1 point
    if (password.length >= 12) {
        level++;
    }
    if (level <= "1") {
        $('#passStrength').removeClass();
        $('#passStrength').addClass("passwordStrength strength" + level);
        $("#password-span-strgd").removeClass("show").addClass("hide");
        $("#password-span-strsg").removeClass("show").addClass("hide");
        $("#password-span-strwk").removeClass("hide").addClass("show");
    } else if (level <= "3" && level > "1") {
        $('#passStrength').removeClass();
        $('#passStrength').addClass("passwordStrength strength" + level);
        $("#password-span-strgd").removeClass("hide").addClass("show");
        $("#password-span-strsg").removeClass("show").addClass("hide");
        $("#password-span-strwk").removeClass("show").addClass("hide");
    } else if (level >= "4") {
        $('#passStrength').removeClass();
        $('#passStrength').addClass("passwordStrength strength" + level);
        $("#password-span-strgd").removeClass("show").addClass("hide");
        $("#password-span-strsg").removeClass("hide").addClass("show");
        $("#password-span-strwk").removeClass("show").addClass("hide");
    }
    return level;
}

function validateNumericKeys(e) {
  if( e.keyCode == 8 ||                                           // Allow Backspace
      e.keyCode == 9 ||                                           // Allow Tab
      e.keyCode == 46 ||                                          // Allow Delete
      (e.keyCode >= 37 && e.keyCode <= 40) ||                     // Allow Arrow keys
      (!e.shiftKey && e.keyCode >= 48 && e.keyCode <= 57) ||      // Allow Number keys when Shift Key is not pressed
      (e.keyCode >= 96 && e.keyCode <= 105))                      // Allow Numpad Number keys
        return true;
  else {                                                          // Don't allow other keys
      return false;
  }
}

$(document).on("keydown", ".num-only", function(e) {
  if (validateNumericKeys(e)) return true;
  else {
   e.preventDefault();
   return false;
  }
});

$(document).on("keydown", ".max3", function(e) {
  if (validateNumericKeys(e) && $(this).val().length < 3) {
    return true;
  } else if (e.keyCode == 8 || e.keyCode == 9 || e.keyCode == 46 || (e.keyCode >= 37 && e.keyCode <= 40)) {
    return true;
  } else {
   e.preventDefault();
   return false;
  }
});

$(document).on("keydown", ".alphanum", function(e) {
  if (validateNumericKeys(e) || (e.keyCode >= 65 && e.keyCode <= 70 ||e.keyCode == 229 )) { // Allow Alphabetic Keys
    return true;
  } else {
    e.preventDefault();
    return false;
  }
});

/**
 * Function that handle post action when user clicks Apply button in GUI
 * @param {string} target
 * @param {object} post parameters
 * @param {boolean} [optional] if true, function uses $.post, otherwise uses .load method
 */
function postHandler(target, params, post) {
    $('#global-apply').prop("disabled", true).addClass('table-button-faded');
    var expertParams = [];
    var pageMode = $("#subnavigation").find(".active a").attr("page-mode");
    if (pageMode == "34"){
        expertParams.push({name: "expert", value: true},{name: "CSRFtoken", value : $("[name=CSRFtoken]").val() });
        $.post("/home.lp", expertParams, function(reponseTxt, status, XHR){
          var elementValue = $("#expert").html();
          if (reponseTxt.status == "success"){
            $("#expert").html(elementValue+'<span>Some Expert Mode settings in use</span>')
          }else{
            $("#expert").html(elementValue);
          }
        });
    }
    var scrollTop = $(document).scrollTop();
    var callback = function(response, status, XHR) {
      response = post ? response.status : $("#post_status").val();
      if (response == "success") {
        $(".articlediv > .msg-error, .articlediv > .msg-warning").removeClass("show").addClass("hide");
        $(".articlediv, .articlediv > .message-arrowbox-applied").removeClass("hide").addClass("show");
        if (typeof(Storage) !== "undefined") {
          // Save data to sessionStorage
          sessionStorage.setItem('apply_changes', "Y");
        } else {
          console.log("Sorry! No Web Storage support..");
        }
        // If POST succeeds, load the page
        $("#content").load(target, function() {
          $(".articlediv > .msg-error, .articlediv > .msg-warning").removeClass("show").addClass("hide");
          $(".articlediv, .articlediv > .message-arrowbox-applied").removeClass("hide").addClass("show");
          setTimeout(function() {
            $(".articlediv").removeClass("show").addClass("hide");
          }, 3000);
        });
      } else {
        $(".articlediv > .message-arrowbox-applied, .articlediv > .msg-warning").removeClass("show").addClass("hide");
        $(".articlediv, .articlediv > .msg-error").removeClass("hide").addClass("show");
        setTimeout(function() {
          $(".articlediv").removeClass("show").addClass("hide");
          $('#global-apply').prop("disabled", false).removeClass('table-button-faded');
        }, 3000);
      }
      $(document).scrollTop(scrollTop);
    }
    post ? $.post(target, params, callback) : $("#content").load(target, params, callback);
}

/**
 * Function to validate a host name
 * valid host name must contain only alphanumeric characters/dash/dot
 * @param {string} hostName
 * @returns true if valid; false if not
 */
function validateHostName(hostName) {
  if (validateStringLength(1, 63)(hostName)) {
    return !/[^\w\.\-]/.test(hostName) && !/^[\.\-]*$/.test(hostName);
  } else {
    return false;
  }
}

/**
 * Function to validate whether a given value is empty/null/undefined
 * @param {string} value
 * @returns true if valid string; false if not
 */
function notAnEmptyString(value) {
  return !!value;
}

/**
 * Return a function that can be used to validate if the input is a number between min and max (inclusive)
 * @param {number} minimum number
 * @param {number} maximum number
 */
function validateNumberRange(min, max) {
  return function validateNumber(value) {
    if (parseInt(value) != value) return false;
    return !isNaN(value) && min <= value && value <= max;
  }
}

/**
 * Return a function used to validate a string having length inbetween min and max (inclusive)
 * @param {number} minimum string length
 * @param {number} maximum string length
 */
function validateStringLength(min, max) {
  return function validateString(value) {
    if ($.type(value) !== "string") return false;
    return !!($.trim(value)) && min <= value.length && value.length <= max;
  }
}

/**
 * Function to validate domain name
 * Check whether the received 'domain' has the syntax of a domain name [RFC 1123]
 * @param {string} domain
 * @returns true if valid; false if invalid
 */
function validateDomain(domain) {
  if (!domain || domain.length == 0 || domain.length > 255 ) return false;
  var i = 0, j = 0;
  do {
    j = (domain.indexOf(".", i) != -1) ? domain.indexOf(".", i) + 1 : domain.length + 1;
    var label = domain.substring(i, j);
    var strippedLabel = label.match(/[^\.]*/)+[];
    if (typeof strippedLabel != "undefined") {
      if (strippedLabel.length == 0 || strippedLabel.length > 63) return false;
      var correctLabel = strippedLabel.match(/[\w][\w\\-]*[a-zA-Z0-9]/)+[];
      if (strippedLabel.length == 1) {
        if (!strippedLabel.match(/[a-zA-Z0-9]/)) return false;
      } else if (strippedLabel != correctLabel) return false;
    }
    i = j;
  } while (j <= domain.length);
  return true;
}

/**
 * Function that can be used to download a file when the target path and params are provided (inclusive)
 * @param {string} target
 * @param {object} params
 */
function downloadFile(target, params) {
  $.fileDownload(target, {
    httpMethod: "POST",
    data: params,
    failCallback: function() { window.location("/"); }
  });
}

// Global Regular expressions
var MACOctetRegExp = /^[0-9a-f]{2}$/i;
var timeRegExp = /^([0-9]|0[0-9]|1?[0-9]|2[0-3]):[0-5]?[0-9]$/;
var IPRegExp = /^([0-9]{1,3}\.){3}[0-9]{1,3}(\/([0-9]|[1-2][0-9]|3[0-2]))?$/;
var DSCPRegExp = /^[0-9a-f]{1,2}$/i;
var MACRegExp = /^([A-Fa-f0-9]{2}[:]){5}[A-Fa-f0-9]{2}$/

//modal Alignment
$( window ).load(function() {
    "use strict";
    var winWidth =  $(window).width();
    function modalCenter() {
        $(this).css('display', 'block');
        var $dialog  = $(this).find(".modal-dialog");
        var dHeight = $dialog.height();
        if (dHeight < 100){
             var offset = ($(window).height()/2 - $dialog.height()) / 2;
        }
        else {
           var offset = ($(window).height() - $dialog.height()) / 2;
        }
       $dialog.css("margin-top", offset);
    }
    if (winWidth > 767){
        $(document).on('show.bs.modal', '.modal', modalCenter);
    }
});
