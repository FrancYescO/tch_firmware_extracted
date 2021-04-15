function getSmartWifiStatus(){
  $.get("/modals/parental-modal.lp?action=smartwifi", function(data){
    if (data.current_state != smartwifivalue || data.current_phase != smartwifiphasevalue && (data.current_state == "1" && data.current_phase == "2") || (curiface == "wl0_1" && data.current_state == "1")) {
      $('#rescanbtn').prop('title', smartWifiMsg);
      $("#ReScan_2").removeAttr("id");
    } else if (data.current_state == "0" || (data.current_state == "1" && data.current_phase == "1")) {
      var analyserId = (curradio == "radio_2G")?'ReScan_2':'ReScan_5';
      $("#rescanbtn").parent().attr('id', analyserId);
    }
  });
}

var smart_wifi;
if (smartwifi) {
  if (smartwifivalue == "1" && smartwifivalue != "nil"){
    $("[id^='Client Monitoring'], a[id^='wifianalyzer_']").addClass("hide");
    if (smartwifiphasevalue == "2" && smartwifiphasevalue != "nil"){
      if (currentRole == "admin") {
        $("#Wireless_Tab_2").addClass("hide");
        if($('#Wireless_Tab_4').length){
          $("#Wireless_Tab_4").addClass("hide");
        }
      }
    }
  }
  clearInterval(smart_wifi);
  smart_wifi = setInterval(getSmartWifiStatus, 3000);
}
if (!isTableLoaded) {
    $.get("/modals/wireless-modal.lp?radio="+curradio+"&iface="+curiface+"&action=GET_ACL_MAC_LIST&acl_mode="+acl_mode, function (data){
        $('#acl_list_div').replaceWith(data);
    });
}

if (securitynone) {
  $("#security").change(function(){
    if(this.value == "none"){
      confirmationDialogue("Security for the wireless network is disabled <br> anybody can connect or listen to it <br> please confirm to ok or cancel?", "Security Mode", "", "Continue");
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

function show_linkconfirming(freq,show){
  var msg_id = "linkconfirming-msg_" + freq;
  var link_id = "linkrescan-changes_" + freq;

  if (show == 1){
    $("div[id = "+ link_id +"]").show();
    $("div[id = "+ msg_id +"]").show();
  }
  else{
    $("div[id = "+ link_id +"]").hide();
    $("div[id = "+ msg_id +"]").hide();
  }
}

$("a[id^='wifianalyzer_']").click(function() {
  var iface = (this.id).split("_")[1];
  var freq = iface.split(".")[0];
  show_linkconfirming(freq, 1);
  return false;
});

$("div[id^='linkrescan-confirm_']").click(function() {
  var iface = (this.id).split("_")[1];
  var freq = iface.split(".")[0];
  show_linkconfirming(freq, 0);
});

$("div[id^='linkrescan-cancel_']").click(function() {
  var iface = (this.id).split("_")[1];
  var freq = iface.split(".")[0];
  show_linkconfirming(freq, 0);
});

$("#aclmode").change(function(){
var aclmode = $(this).val();
if(aclmode == "register"){
    $("#acl_whitelist").attr("id","acl_register");
}else{
    $("#acl_register").attr("id","acl_whitelist");
}
});
if (current_acl_mode != acl_mode) {
  $('#modal-no-change').hide();
  $('#modal-changes').show();
}

stdSpecificCustomisation($("#standard").val());
if(channelWithNo160MHz == "true")
  standardChange();

$("#standard").change(function() {
  stdSpecificCustomisation($(this).val());
  if(channelWithNo160MHz == "true")
    standardChange();
});

function get_status_acl() {
   $("#btn_acl").attr('disabled', true);
   setTimeout(function(){
   $.get("modals/wireless-modal.lp?action=get_reg_status&curap="+curap+"", function(res){
     if (res != "register"){
       get_status_acl();
     }
     else{
       $("#btn_acl").removeAttr('disabled', false);
    }
    $("#btn_acl").html(res);
    });	},5000);
}

$("#channelwidth160, #standard").change(function() {
  if ($("#standard").val() == "anacax") {
    if ((channelWithNo160MHz == "false") && ($("#channelwidth160").val() == "auto")) {
      $("#channel160alert").removeClass("hide").addClass("show")
    } else {
      $("#channel160alert").removeClass("show").addClass("hide")
    }
  } else {
    $("#channel160alert").removeClass("show").addClass("hide")
  }
});

if (($("#standard").val() == "anacax") && (channelWithNo160MHz == "false") && ($("#channelwidth160").val() == "auto" )) {
  $("#channel160alert").removeClass("hide").addClass("show")
}

$("#btn_acl").click(function() {
   if($("#btn_acl").attr("disabled")!= undefined ) return false;
   $.post("modals/wireless-modal.lp",{ action: "set_reg", curap: curap, CSRFtoken: $("meta[name=CSRFtoken]").attr("content")},
      get_status_acl);
 });

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


if (!bandsteerSupport) {
    $("#save-config").click(function(){
      var params = [];
      params.push({
        name : "ssidName",
        value : $("#ssid").val()
        },{
        name : "wep_key",
        value : $("#wep_key").val()
        },{
        name : "wpa_psk",
        value : $("#wpa_psk").val()
        },{
        name : "wpa3",
        value : $("#wpa3").val()
        },{
        name : "security",
        value : $("#security").val()
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
      $.post("modals/wireless-modal.lp",params);
      flag = true;
    });
    if (flag == true){
      if (helpmsg["length"] == 0) {
        sessionStorage.setItem("clicked", true);
      }
    }
  if (sessionStorage.getItem("clicked")){
    var time = setTimeout(removewaitTime, 15000);
    $("#save-config").attr("style", "opacity:0.4;pointer-events:none");
    if (!ssidCheck) {
       $("#wait-time-msg").removeClass('hide').addClass('show');
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
  function removewaitTime(){
    flag = false;
    $("#save-config").removeAttr("style");
    $("#wait-time-msg").removeClass('show').addClass('hide')
    sessionStorage.removeItem("clicked");
  }

function standardChange(){
  if(($("#standard").val() == "anac") && (channelWidth == "20&#47;40MHz" || channelWidth == "20&#47;40")){
    $("#channelwidth80").val("20/40").trigger("chosen:updated");
  }
  else if(($("#standard").val() == "anacax") && (channelWidth == "20&#47;40MHz" || channelWidth == "20&#47;40")){
    $("#channelwidth160").val("20/40").trigger("chosen:updated");
  }
if ($("#standard").val() == "anac" && (channelWidth == "auto" || channelWidth == "20&#47;40&#47;80MHz" || channelWidth == "20&#47;40&#47;80")){
   $("#channelwidth80").val("20/40/80").trigger("chosen:updated");
}
if ($("#standard").val() == "anacax" && (channelWidth == "auto" || channelWidth == "20&#47;40&#47;80MHz" || channelWidth == "20&#47;40&#47;80")){
   $("#channelwidth160").val("20/40/80").trigger("chosen:updated");
 }
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
