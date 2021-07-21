var acl_modeVal = [];
for(var ap in ap_list) {
  var apVal = ap_list[ap]
  $("#aclmode"+apVal).change(function(){
   var aclmode = $(this).val();
     if(aclmode == "register"){
       $("#acl_whitelist"+apVal).attr("id","acl_register"+apVal);
     }else{
       $("#acl_register"+apVal).attr("id","acl_whitelist"+apVal);
     }
  });
  if (current_acl_mode[apVal] != acl_mode["acl_mode"+apVal]) {
    $('#modal-no-change').hide();
    $('#modal-changes').show();
  }
}

$("#securityap1, #securityap0, #securityap2, #securityap3").change(function(){
  if ($(this).val() == "wpa3-psk" || $(this).val() == "wpa2-wpa3-psk") {
    var id = $(this).attr("id")
    $(".monitor-wpa2-psk .monitor-"+id).css("display", "none");
    $(".monitor-wpa3-psk .monitor-"+id).css("display", "block");
  } else if ($(this.val) == "wpa2-psk") {
    $(".monitor-wpa2-psk .monitor-"+id).css("display", "block");
    $(".monitor-wpa3-psk .monitor-"+id).css("display", "none");
  }
});

var aplist = aplists
if( multiap_enabled == "true") {
  aplist = cred_list;
}

function showHidePassword() {
  var showPassword = {}
  var passwordValue = {}
  for(var ap in aplist) {
    var apVal = aplist[ap];
    showPassword[apVal] = 1;
    if (showWirelessPassword) {
      passwordValue[apVal] = $("#wirelessPassword"+apVal).text();
      $("#wpa_psk"+apVal).attr("type", "password");
      $("#wep_key"+apVal).attr("type", "password");
      $("#wpa3"+apVal).attr("type", "password");
      $("#wirelessPassword"+apVal).html("********");
      if (multiap_enabled == "true") {
        $("#password"+apVal).attr("type", "password");
      }
    }
    $('#showpass'+apVal).change(function() {
      var id = $(this).attr("id");
      var curap = id.substr(id.length - 3);
      if (multiap_enabled == "true") {
        curap = id.substr(id.length - 5);
      }
      var password = $("wirelessPassword"+curap).text();
      if (showPassword[curap] == 1) {
        $("#wpa_psk"+curap).attr("type", "text");
        $("#wpa3"+curap).attr("type", "text");
        $("#wep_key"+curap).attr("type", "text");
        $("#wirelessPassword"+curap).html(passwordValue[curap]);
        if (multiap_enabled == "true") {
          $("#password"+curap).attr("type", "text");
        }
        showPassword[curap] = 0;
      }
      else {
        $("#wpa_psk"+curap).attr("type", "password");
        $("#wpa3"+curap).attr("type", "password");
        $("#wep_key"+curap).attr("type", "password");
        $("#wirelessPassword"+curap).html("********");
        if (multiap_enabled == "true") {
          $("#password"+curap).attr("type", "password");
        }
        showPassword[curap] = 1;
      }
    });
  }
}

showHidePassword();

for(var ap in aplists) {
  var curap = aplists[ap];
  $(".multiapstateClass"+curap).hide();
  $(".broadcast_ssid"+curap).hide();
  $(".bandsteer_support").hide();
  $(".acl_list"+curap).hide();
  $(".qrcode").hide();
}

$("#Hide_Advanced_id , #Show_Advanced_id").click(function(){
  var _id = this.id == "Show_Advanced_id" ? true : false ;
  sessionStorage.setItem("showAdvancedMode", _id);
  for(var ap in aplists) {
    var curap = aplists[ap];
    $(".multiapstateClass"+curap).css({"display":_id ? "inline" : "none"});
    $(".broadcast_ssid"+curap).css({"display":_id ? "inline" : "none"});
    $(".bandsteer_support").css({"display":_id ? "inline" : "none"});
    $(".acl_list"+curap).css({"display":_id ? "inline" : "none"});
  }
});

function showSlider(newVal){
  document.getElementById("Slider_ID").innerHTML=newVal+"dBm";
  $("#modal-no-change").hide();
  $("#modal-changes").show();
}

function loadShowHideButton(){
  for(var ap in aplists) {
    var curap = aplists[ap]
    var apSecVal = $("#security"+curap).val()
    if (apSecVal == "none") {
      $(".wirelessPwd"+curap).hide();
    }
    else {
      $(".wirelessPwd"+curap).show();
    }
    if ($("#Hide_Advanced_id").hasClass("hide") && sessionStorage.getItem("showAdvancedMode") == "false") {
      $(".multiapstateClass"+curap).hide();
      $(".broadcast_ssid"+curap).hide();
      $(".bandsteer_support").hide();
      $(".acl_list"+curap).hide();
      $(".qrcode").hide();
    }
    else {
      $(".multiapstateClass"+curap).show();
      $(".broadcast_ssid"+curap).show();
      $(".bandsteer_support").show();
      $(".acl_list"+curap).show();
      $(".qrcode").hide();
    }
  }
  for(var cred in cred_list) {
    var credVal = cred_list[cred]
    var credSecVal = $("#security"+credVal).val()
    if (credSecVal == "none") {
      $(".wirelessPwd"+credVal).hide();
    }
    else {
      $(".wirelessPwd"+credVal).show();
    }
  }
}
$("#split_ssid").change(function(){
  $("#save-config").attr("style", "opacity:0.4;pointer-events:none");
  $.get("modals/wireless-ap-modal-newEM.lp?action=split_ssid&splitssid="+this.value, function(data){
    document.getElementById("wirelessDivPage").innerHTML = data;
    loadShowHideButton();
    showHidePassword();
    securityModeWarning();
    loadBroadCastWarning();
    passwordChange();
    passwordIndicationBar();
    $("#save-config").removeAttr("style");
  });
  var flag = false;
  if (this.value == "1") {
    if ($("#band_steer_enabled").val() == "1" && suffix != "") {
      flag = true;
      $("#bandsteer_warning").show();
    } else {
      $("#bandsteer_warning").hide();
    }
    setTimeout(function(){
      if ($("#securityap0").val() == "wpa3-psk" || ($("#securityap0").val()) == "wpa2-wpa3-psk" || $("#securityap2").val() == "wpa3-psk" || ($("#securityap2").val()) == "wpa2-wpa3-psk") {
        if (! flag) {
          $(".monitor-wpa2-psk").css("display", "none");
          $(".monitor-wpa3-psk").css("display", "block");
        }
      }
    }, 5000);
  } else {
    $("#bandsteer_warning").hide();
  }
});

loadShowHideButton();
function securityModeWarning(){
  if (gettype != "guest" && securitynone && multiap_enabled == "true") {
    for(var cred in cred_list) {
      var credVal = cred_list[cred]
      $("#security"+credVal).change(function(){
        if(this.value == "none"){
          confirmationDialogue(confirmationMsg, confirmationTitle, "", confirmationContinue);
        }
      });

      $(document).on("click", "#ok", function() {
        tch.removeProgress();
      });

      $(document).on("click", "#cancel", function() {
        var target = $(".modal form").attr("action");
        var scrolltop = $(".modal-body").scrollTop();
        tch.loadModal(target, function () {
          $(".modal-body").scrollTop(scrolltop);
        });
        tch.removeProgress();
      });
    }
  }

  if (securitynone && multiap_enabled == "false" || gettype == "guest") {
    for(var ap in ap_list) {
      var apVal = ap_list[ap]
      $("#security"+apVal).change(function(){
        if(this.value == "none"){
          confirmationDialogue(confirmationMsg, confirmationTitle, "", confirmationContinue);
        }
      });

      $(document).on("click", "#ok", function() {
        tch.removeProgress();
      });

      $(document).on("click", "#cancel", function() {
        var target = $(".modal form").attr("action");
        var scrolltop = $(".modal-body").scrollTop();
        tch.loadModal(target, function () {
          $(".modal-body").scrollTop(scrolltop);
        });
        tch.removeProgress();
      });
    }
  }
}
securityModeWarning();
function get_status_acl(curap) {
  $("#btn_acl"+curap).attr('disabled', true);
  setTimeout(function(){
    $.get("modals/wireless-ap-modal-newEM.lp?action=get_reg_status&curap="+curap+"", function(res){
      if (res != "Register"){
        get_status_acl(curap);
      }
      else{
         $("#btn_acl"+curap).removeAttr('disabled', false);
      }
      $("#btn_acl"+curap).html(res);
    });
  }, 5000);
}

for(var ap in aplists) {
  var curap = aplists[ap]
  $("#btn_acl"+curap).click(function() {
    var id = $(this).attr("id");
    curap = id.substr(id.length - 3);
    if($("#btn_acl"+curap).attr("disabled")!= undefined ) return false;
    $.post("modals/wireless-ap-modal-newEM.lp",{ action: "set_reg", curap: curap, CSRFtoken: $("meta[name=CSRFtoken]").attr("content")},
    get_status_acl(curap));
  });
}

var bschecked = $('input[id="band_steer_enabled"]').val();
var flag;
$(document).ready(function() {
  if (bschecked == "1") {
    $('option[value="wep"]').hide();
    $('option[value="wpa-wpa2"]').hide();
    $('option[value="wpa2"]').hide();
    $('option[value="wpa"]').hide();
  }
});

if (!bandsteerSupport && multiap_enabled == "false") {
  $("#save-config").click(function(){
    var params = [];
    params.push({
      name : "ssidName",
      value : $("#ssid"+curap).val()
    },{
      name : "wep_key",
      value : $("#wep_key"+curap).val()
    },{
      name : "wpa_psk",
      value : $("#wpa_psk"+curap).val()
    },{
      name : "wpa3",
      value : $("#wpa3"+curap).val()
    },{
      name : "security",
      value : $("#security"+curap).val()
    },{
      name : "apName",
      value : curap
    },{
      name : "CSRFtoken",
      value :$("meta[name=CSRFtoken]").attr("content")
    },{
      name : "action",
      value: "bs_check"
    });
    if (bandsteerDisabled) {
      params.push({
        name : "admin_state",
        value : $("#admin_state").val()
      });
    }
    $.post("modals/wireless-ap-modal-newEM.lp",params);
    flag = true;
  });
  if (flag == true){
    if (helpmsg["length"] == 0) {
      sessionStorage.setItem("clicked", true);
     }
  }
}

$('input[id="band_steer_enabled"]').click(function(){
  if (bschecked == "1") {
    $('option[value="wep"]').hide();
    $('option[value="wpa-wpa2"]').hide();
    $('option[value="wpa2"]').hide();
    $('option[value="wpa"]').hide();
  }
});

function passwordChange() {
  $(".password_class_input").click(function() {
    var pwd_id = $(this).attr("id");
    if (multiap_enabled == "false" || gettype == "guest") {
      var apVal = pwd_id.substr(pwd_id.length - 3);
      var wpapsk = "Strength"+apVal;
      var wpa3 = "Strength1"+apVal;
      var wep = "Strength2"+apVal;
      var wpapsk_id_exists = $("#"+wpapsk)
      var wpa3_id_exists = $("#"+wpa3)
      var wep_id_exists = $("#"+wep)
      if(wpapsk_id_exists.val() != ""){
        $("#wpa_psk"+apVal).parent().after('<div class="controls"><div id=' + wpapsk + '></div></div>');
      }
      if(wpa3_id_exists.val() != ""){
        $("#wpa3"+apVal).parent().after('<div class="controls"><div id=' + wpa3 + '></div></div>');
      }
      if(wep_id_exists.val() != ""){
        $("#wep_key"+apVal).parent().after('<div class="controls"><div id=' + wep + '></div></div>');
      }
    } else {
      var credVal = pwd_id.substr(pwd_id.length - 5);
      var credPwd = "Strength"+credVal;
      var credPwd_id_exists =$("#"+credPwd)
      if(credPwd_id_exists.val() != ""){
        $("#password"+credVal).parent().after('<div class="controls"><div id=' + credPwd + '></div></div>');
      }
    }
  });
}

//function used to indicate the password strength level based on inputs provided
function passwordIndicationBar() {
  $(".password_class_input").keyup(function(){
    var password_id = $(this).attr("id");
    if (multiap_enabled == "true" && gettype == "main") {
      var credVal = password_id.substr(password_id.length - 5);
      var credPwd = "#Strength"+credVal;
      var level = passwordCheck(this.value);
      $(credPwd).removeClass().addClass("strength" + level);
      $(credPwd).css("width", 54*level);

    } else {
      var apVal = password_id.substr(password_id.length - 3);
      var wpapsk = "#Strength"+apVal;
      var wpa3 = "#Strength1"+apVal;
      var wep = "#Strength2"+apVal;
      var level = passwordCheck(this.value);
      if(password_id.substring(0,4) == "wpa_"){
        $(wpapsk).removeClass().addClass("strength" + level);
        $(wpapsk).css("width", 54*level);
      }
      else{
        $(wep).removeClass().addClass("strength" + level);
        $(wep).css("width", 54*level);
        $(wpa3).removeClass().addClass("strength" + level);
        $(wpa3).css("width", 54*level);
      }
    }
  });
}

if (passwordStrength) {
  function passwordCheck(password)
  {
    var level = 0;

    //if password longer than 6 give 1 point
    if (password.length >= 6) level++;

    //if password has both lower and uppercase characters give 1 point
    if ( ( password.match(/[a-z]/) ) && ( password.match(/[A-Z]/) ) ) level++;

    //if password has at least one number give 1 point
    if (password.match(/\d+/)) level++;

    //if password has at least one special character give 1 point
    if ( password.match(/[!,@,#,$,%,^,&,*,?,_,~,-,(,)]/) )  level++;

    //if password bigger than 8 give another 1 point
    if (password.length >= 8) level++;

    return level;
  }
  passwordChange();
  passwordIndicationBar();
}

function loadBroadCastWarning(){
  $('.broadcast_switch_class').click(function() {
    var apVal= this.id.substr(this.id.length - 3)
    var value = $( "#ap_broadcast_ssid"+apVal ).val();
    if(value == "0"){
      $(".broadcast_ssid_warning"+apVal).removeClass("show").addClass("hide")
    }
    else{
      $(".broadcast_ssid_warning"+apVal).removeClass("hide").addClass("show")
    }
  });
}
loadBroadCastWarning();
