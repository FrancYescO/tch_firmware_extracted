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
var ssid = $("#ssid").val();
$("#ssid_uci").val(ssid);
$("#bspifacessid_uci").val(ssid);
if (!isTableLoaded) {
    $.get("/modals/wireless-modal.lp?radio="+curradio+"&iface="+curiface+"&action=GET_ACL_MAC_LIST&acl_mode="+acl_mode, function (data){
        $('#acl_list_div').replaceWith(data);
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

var flag;
  function removewaitTime(){
    flag = false;
    $("#save-config").removeAttr("style");
    $("#wait-time-msg").removeClass('show').addClass('hide')
    sessionStorage.removeItem("clicked");
  }

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
});

 $('#wpa_psk').keyup(function() {
   var level = passwordCheck(this.value);
   $('#Strength').removeClass().addClass("strength" + level);
   $("#Strength").css("width", 54*level);
});
