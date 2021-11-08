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

if (gettype != "guest" && securitynone && multiap_enabled == "true") {
  for(var cred in cred_list) {
    var credVal = cred_list[cred]
    $("#security"+credVal).change(function(){
      if(this.value == "none"){
        confirmationDialogue("Security for the wireless network will be <br> disabled and anyone will be able to connect <br> or listen, please confirm to continue?", "Security Mode", "", "Continue");
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
        confirmationDialogue("Security for the wireless network will be <br> disabled and anyone will be able to connect <br> or listen, please confirm to continue?", "Security Mode", "", "Continue");
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

function get_status_acl(curap) {
  $("#btn_acl"+curap).attr('disabled', true);
  setTimeout(function(){
    $.get("modals/wireless-ap-modal.lp?action=get_reg_status&curap="+curap+"", function(res){
      if (res != "register"){
        get_status_acl(curap);
      }
      else{
         $("#btn_acl"+curap).removeAttr('disabled', false);
      }
      $("#btn_acl"+curap).html(res);
    });
  }, 5000);
}

for(var ap in ap_list) {
  var curap = ap_list[ap]
  $("#btn_acl"+curap).click(function() {
    if($("#btn_acl"+curap).attr("disabled")!= undefined ) return false;
    $.post("modals/wireless-ap-modal.lp",{ action: "set_reg", curap: curap, CSRFtoken: $("meta[name=CSRFtoken]").attr("content")},
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
    $.post("modals/wireless-ap-modal.lp",params);
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
  $(document).ready(function() {

    $('#wpa_psk').parent().after('<div class="controls"><div id="Strength"></div></div>');
    $('#wpa3').parent().after('<div class="controls"><div id="Strength1"></div></div>');
  });

  $('#wpa_psk, #wpa3').keyup(function() {
    var level = passwordCheck(this.value);
    $('#Strength, #Strength1').removeClass().addClass("strength" + level);
    $('#Strength, #Strength1').css("width", 54*level);
  });
}

