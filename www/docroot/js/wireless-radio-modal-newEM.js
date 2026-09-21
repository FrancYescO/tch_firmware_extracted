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
    $("a[id^='wifianalyzer_']").addClass("hide");
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

$("#Hide_Advanced_id , #Show_Advanced_id").click(function(){
  var _id = this.id == "Show_Advanced_id" ? true : false ;
  sessionStorage.setItem("showAdvancedMode", _id);
});

$("#channelwidth160, #standard").change(function() {
  if ($("#standard").val() == "anacax") {
    if ((channelWithNo160MHz == "false") && ($("#channelwidth160").val() == "auto")) {
      $("#channel160alert").removeClass("hide").addClass("show");
    } else {
      $("#channel160alert").removeClass("show").addClass("hide");
    }
  } else {
    $("#channel160alert").removeClass("show").addClass("hide");
  }
});

if (($("#standard").val() == "anacax") && (channelWithNo160MHz == "false") && ($("#channelwidth160").val() == "auto" )) {
  $("#channel160alert").removeClass("hide").addClass("show");
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


function standardChange(){
  if(($("#standard").val() == "anac") && (channelWidth == "20&#47;40MHz" || channelWidth == "20&#47;40"))
    $("#channelwidth80").val("20/40").trigger("chosen:updated");
  else if(($("#standard").val() == "anacax") && (channelWidth == "20&#47;40MHz" || channelWidth == "20&#47;40"))
    $("#channelwidth160").val("20/40").trigger("chosen:updated");

  if ((channelWidth == "20&#47;40&#47;80MHz" || channelWidth == "20&#47;40&#47;80" || channelWidth == "auto")){
    if (channelWithNo160MHz == "true"){
      if ($("#standard").val() == "anac")
        $("#channelwidth80").val("20/40/80").trigger("chosen:updated");
      else
        $("#channelwidth160").val("20/40/80").trigger("chosen:updated");
    }
    else{
      if ($("#standard").val() == "anacax")
        $("#channelwidth160").val("20/40/80").trigger("chosen:updated");
    }
  }
  if ((channelWidth == "20&#47;40&#47;80&#47;160MHz" || channelWidth == "20&#47;40&#47;80&#47;160") || channelWidth == "auto"){
    if (channelWithNo160MHz == "false"){
      if ($("#standard").val() == "anac")
        $("#channelwidth80").val("auto").trigger("chosen:updated");
      else
        $("#channelwidth160").val("auto").trigger("chosen:updated");
    }
  }
}

stdSpecificCustomisation($("#standard").val());
standardChange();

$("#standard").change(function() {
  stdSpecificCustomisation($(this).val());
  standardChange();
});
