function clearErrorPassword()
{
  var upass = $('.modal input[name="password"],.modal input[name="password2"],.modal input[name="oldpassword"]');
  upass.removeClass("tooltip-on error");
  upass.closest(".control-group").removeClass("error");
  upass.next().remove();
}

function displayErrorPassword(msg)
{
  var upass = $('.modal input[name="password"],.modal input[name="password2"]');
  upass.addClass("error");
  upass.closest(".control-group").addClass("error");
  upass.first().after('<span class="help-inline">' + msg + '</span>');
}

function displayErrorMessage(msg)
{
  var upass = $('.modal input[name="password"]');
  upass.addClass("error");
  upass.closest(".control-group").addClass("error");
  upass.first().after('<span class="help-inline">' + msg + '</span>');
}

function clearErrorUser()
{
  var uinput = $('.modal input[name="name"]');
  uinput.removeClass("tooltip-on error");
  uinput.closest(".control-group").removeClass("error");
}

function displayErrorUser()
{
  var uinput = $('.modal input[name="name"]');
  uinput.addClass("tooltip-on error");
  uinput.attr("placement", "top");
  uinput.attr("data-original-title", userNameCheckMessage);
  uinput.closest(".control-group").addClass("error");
  $('.tooltip-on').tooltip();
}

// "Disable" the existing handler by removing the class it matches on (tried to use the off() method of jquery to no avail)
$(".modal .btn-table-modify").removeClass("btn-table-modify").addClass("btn-table-modify-custom");
$(".modal .btn-table-add").removeClass("btn-table-add").addClass("btn-table-add-custom");
$(".modal .btn-table-modify-custom,.modal .btn-table-add-custom").on("click", function () {
  clearErrorUser();
  clearErrorPassword();

  var self = this;
  var user = $('input[name="name"]').val();
  var password = $('input[name="password"]').val();
  var password2 = $('input[name="password2"]').val();
  if(user == "") {
    displayErrorUser();
    return;
  }

  if((password.length < passwordlength) || (passwordCheck(password)) < 5) {
    if(password.length == 0) {
      displayErrorMessage(passCheckErrMessage);
    }
    else {
      displayErrorMessage(passValidationErrMessage);
    }
    return;
  }

  if(password !== password2) {
    displayErrorPassword(passMatchErrMessage);
    return;
  }

  function sendData(salt, verifier, cryptpw)
  {
    var target = $(".modal form").attr("action");
    var table = $(self).closest("table");
    var id = table.attr("id");
    var line = $(self).closest("tr");
    var index = line.index();
    var action;
    var params = table.find(".line-edit :input").serializeArray();

    if($(self).hasClass("btn-table-add-custom")) {
      action = "TABLE-ADD";
    } else {
        action = "TABLE-MODIFY";
        index  = index - 2;
    }
    var add_params = table.find(".additional-edit :input").serializeArray();
    params = params.concat(add_params);
    params.push({
      name : "tableid",
      value : id
    });
    params.push({
      name : "stateid",
      value : table.attr("data-stateid")
    });
    params.push({
      name : "action",
      value : action
    });
    params.push({
      name : "cryptpw",
      value : cryptpw
    });
    params.push({
      name : "srp_salt",
      value : salt
    });
    params.push({
      name : "srp_verifier",
      value : verifier
    });
    params.push({
      name : "index",
      value : index + 1
    });
    params.push(tch.elementCSRFtoken());
    tch.loadModal(target, params, function() {
      tch.scrollRowIntoView(id, index);
    });
  }

  var srp = new SRP();
  function generateSaltAndVerifier() {
    srp.generateSaltAndVerifierTheCallback(user, password, function(salt, verifier, cryptpw) {
      $('input[name="password"]').val(""); // clean that up no need to send it over the air
      $('input[name="password2"]').val("");
      $('input[name="oldpassword"]').val("");
      sendData(salt, verifier, cryptpw);
    });
  }
  srp.success = generateSaltAndVerifier;
  srp.error_message = function() {
    clearErrorPassword();
    var upass = $('.modal input[name="oldpassword"]');
    upass.addClass("error");
    upass.closest(".control-group").addClass("error");
    upass.first().after('<span class="help-inline">'+oldPassIncorrectErrMessage+'</span>');
  }
  var oldpassword = $('input[name="oldpassword"]').val();
  if(oldpassword != undefined) {
    //Start for legacy migration: GUI username/password [NG-48489]
    var legacySalts = legacySaltsValue;
    var userNames = userNamesValue;
    var index = -1;
    var userNameArray = userNames.split(",")
    var legacySaltArray = legacySalts.split(",")
    for (var i = 0; i < userNameArray.length - 1; i ++){
      if (oldusername == userNameArray[i]){
        index = i;
      }
    }

    if (index >= 0){
      var hashObj = new jsSHA((legacySaltArray[index]+tch.stringToHex(oldpassword)), "HEX");
      oldpassword = hashObj.getHash("SHA-1", "HEX");
    }
    //End for legacy migration: GUI username/password [NG-48489]

    srp.identify("/modals/usermgr-modal.lp", oldusername, oldpassword);
  }
  else {
    generateSaltAndVerifier();
  }
});

$('#usrmodal_password').parent().after('<div class = "controls"><div id="Strength"></div></div>')
$('#repeat_pass').parent().css("padding-top" , "5px")

function passwordCheck(password)
{
  var level = 0;

  //if password bigger than 6 give 1 point
  if (password.length >= 6) level++;

  //if password has both lower and uppercase characters give 1 point
  if ( ( password.match(/[a-z]/) ) && ( password.match(/[A-Z]/) ) ) level++;

  //if password has at least one number give 1 point
  if (password.match(/\d+/)) level++;

  //if password has at least one special caracther give 1 point
  if ( password.match(/[!,@,#,$,%,^,&,*,?,_,~,\-,(,),:,;,',",},{,.,[,\]]/) )  level++;

  //if password bigger than minimum length give another 1 point
  if (password.length >= passwordlength) level++;

  $('#Strength').removeClass().addClass("strength" + level);
    return level;
}
