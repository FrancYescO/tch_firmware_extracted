  $(function() {
	var bullets = "&bull;";
    $('select').chosen({
      disable_search_threshold: 100000,
      allow_single_deselect: true
    });
    $("#resetButtonsShort").click(function(){
      $("#resetButtonsShort").hide()
      $("#resetBar").slideDown("fast");
    });
    $("#resetR,#cancelR").click(function(){
      $("#resetButtonsShort").show();
      $("#resetBar").slideUp("fast");
    });
    $("#resetWrapMobile .resetButtons").click(function(){
      $("#main-contnet").hide();
      $("#mobile-popup").show();
      $(".menubar-overlay").hide();
      $("#page-rhombus-wrap").hide();
      $("#mobile-popup").slideDown("fast");
    });
    $(".mobile-reset #resetR").click(function(){
      $("#main-contnet").show();
      $("#mobile-popup").hide();
      $(".menubar-overlay").show();
      $("#page-rhombus-wrap").show();
      $("#mobile-popup").slideUp("fast");
    });

    if((passwordDefault == password24wpa) && ($("#wifiGen_sel_mode24_chosen span").html() != "off")){
      $("#wifiGen-info-defPwd").removeClass('hide').addClass('show').text(T["default_password_24GHz"]);
    }
    if((passwordDefault == password5wpa) && ($("#wifiGen_sel_mode5_chosen span").html() != "off")){
      $("#wifiGen-info-defPwd").removeClass('hide').addClass('show').text(T["default_password_5GHz"]);
    }
    if((passwordDefault == password24wpa) && (passwordDefault == password5wpa)){
      if(($("#wifiGen_sel_mode24_chosen span").html() != "off") && ($("#wifiGen_sel_mode5_chosen span").html() != "off")){
        $("#wifiGen-info-defPwd").removeClass('hide').addClass('show').text(T["default_password_24GHz_and_5GHz"]);
      }
    }

    if(wifi_stat24 == "0") {
      $("#wifiGen-btn-edit24").addClass("button-off");
      $("#wifiGen-btn-edit24").removeClass("button-on");
      $("#wifiGen-info24").removeClass('show').addClass('hide');
    } else {
      $("#wifiGen-btn-edit24").addClass("button-on");
      $("#wifiGen-btn-edit24").removeClass("button-off");
      $("#wifiGen-info24").addClass('show').removeClass('hide');
    }
    if(wifi_stat5 == "0") {
      $("#wifiGen-btn-edit5").addClass("button-off");
      $("#wifiGen-btn-edit5").removeClass("button-on");
      $("#wifiGen-info5").removeClass('show').addClass('hide');
    } else {
      $("#wifiGen-btn-edit5").addClass("button-on");
      $("#wifiGen-btn-edit5").removeClass("button-off");
      $("#wifiGen-info5").addClass('show').removeClass('hide');
    }
    if(broadcast_ssid24 == "0") {
      $("#wifiGen-btn-bssid24").addClass("button-off");
      $("#wifiGen-btn-bssid24").removeClass("button-on");
    } else {
      $("#wifiGen-btn-bssid24").addClass("button-on");
      $("#wifiGen-btn-bssid24").removeClass("button-off");
    }
    if(broadcast_ssid5 == "0") {
      $("#wifiGen-btn-bssid5").addClass("button-off");
      $("#wifiGen-btn-bssid5").removeClass("button-on");
    } else {
      $("#wifiGen-btn-bssid5").addClass("button-on");
      $("#wifiGen-btn-bssid5").removeClass("button-off");
    }
    if(wifi24ModeSelectIndex == "0") {
      $("#wifi24password").addClass('hide'); $("#password-div-2ghz").removeClass("status-border-top");
    } else {
      $("#wifi24password").removeClass('hide'); $("#password-div-2ghz").addClass("status-border-top");
    }
    if(wifi5ModeSelectIndex == "0") {
      $("#wifi5password").addClass('hide'); $("#password-div-5ghz").removeClass("status-border-top");
    } else {
      $("#wifi5password").removeClass('hide'); $("#password-div-5ghz").addClass("status-border-top");
    }
    if(wifi24ChannelSelectIndex == "0") {
      $("#wifi24channel").addClass('show');
      $("#wifi24channel").removeClass('hide');
    } else {
      $("#wifi24channel").addClass('hide');
      $("#wifi24channel").removeClass('show');
    }
    if(wifi5ChannelSelectIndex == "0") {
      $("#wifi5channel").addClass('show');
      $("#wifi5channel").removeClass('hide');
    } else {
      $("#wifi5channel").addClass('hide');
      $("#wifi5channel").removeClass('show');
    }

    $("#wifiGen-sel-channel24, #wifiGen-sel-channel5").change(function(){
      var selectIndex = $(this)[0].selectedIndex;
      if($(this).hasClass("wifiGen-sel-channel24")){
        if(selectIndex == "0") {
          $("#wifi24channel").removeClass('hide').addClass('show');
        } else {
          $("#wifi24channel").addClass('hide').removeClass('show');
        }
      }
      if($(this).hasClass("wifiGen-sel-channel5")){
        if(selectIndex == "0") {
          $("#wifi5channel").removeClass('hide').addClass('show');
        } else {
          $("#wifi5channel").addClass('hide').removeClass('show');
        }
      }
    });
    $("#wifiGen-sel-mode24, #wifiGen-sel-mode5").change(function(){
      var selectIndex = $(this)[0].selectedIndex;
      selectIndex == "0" ? $("#protectionOff").show() : $("#protectionOff").hide();
      $("#SSIDProtectionChange").addClass('show').removeClass('hide');
      if($(this).hasClass("wifiGen-sel-mode24")){
        if(selectIndex == "0"){
          $("#wifi24password").addClass('hide'); $("#password-div-2ghz").removeClass("status-border-top");
        } else {
          $("#wifi24password").removeClass('hide');  $("#password-div-2ghz").addClass("status-border-top");
        }
      }
      if($(this).hasClass("wifiGen-sel-mode5")){
        if(selectIndex == "0"){
          $("#wifi5password").addClass('hide'); $("#password-div-5ghz").removeClass("status-border-top");
        } else {
          $("#wifi5password").removeClass('hide'); $("#password-div-5ghz").addClass("status-border-top")
        }
      }
    });
    $("#wifiGen-btn-bssid24, #wifiGen-btn-bssid5").click(function(){
      if($(this).hasClass('button-on')){
        $(this).removeClass('button-on');
        $(this).addClass('button-off');
      } else {
        $(this).removeClass('button-off');
        $(this).addClass('button-on');
      }
    });
    $("#wifiGen-sel-channel5").change(function(){
      var channel5gh = $("#wifiGen-sel-channel5").val();
      if (isRadardetectionAvoidanceChannel(channel5gh)){
        $("#radar_chn_sel_5GHZ").addClass('show').removeClass('hide');
      } else {
        $("#radar_chn_sel_5GHZ").addClass('hide').removeClass('show');
      }
    });
    $("#wifiGen-btn-edit24").click(function(){
      if($(this).hasClass('button-on')){
        $(this).removeClass('button-on');
        $(this).addClass('button-off');
        $("#wifiGen-info24").addClass('hide').removeClass('show');
      } else {
        $(this).removeClass('button-off');
        $(this).addClass('button-on');
        $("#wifiGen-info24").removeClass('hide').addClass('show');
      }
    });
    $("#wifiGen-btn-edit5").click(function(){
      if($(this).hasClass('button-on')){
        $(this).removeClass('button-on');
        $(this).addClass('button-off');
        $("#wifiGen-info5").addClass('hide').removeClass('show');
      } else {
        $(this).removeClass('button-off');
        $(this).addClass('button-on');
        $("#wifiGen-info5").removeClass('hide').addClass('show');
      }
    });

    var wifiGenTextLabel = $("#wifiGen-textLabel-pwd24").text();
    $("#wifiGen-textLabel-pwd24").text("");
    for (i=0; i<wifiGenTextLabel.length; i++){
      $("#wifiGen-textLabel-pwd24").append("\u2022");
    }
    $("#wifiGen-chk-pwd24").click(function(){
      var passwordTxt = $("#wifiGen-txt-pwd24").val();
      if (this.checked){
        $("#wifiGen-textLabel-pwd24").text(passwordTxt);
        $("#wifiGen-textLabel-pwd24").removeClass("wifiGen-textBullet");
        $("#wifiGen-txt-pwd24").removeAttr("type","password");
        $("#wifiGen-txt-pwd24").attr("type","text");
      } else {
        $("#wifiGen-textLabel-pwd24").text("");
        for (i=0; i<passwordTxt.length; i++){
          $("#wifiGen-textLabel-pwd24").append("\u2022");
        }
        $("#wifiGen-textLabel-pwd24").addClass("wifiGen-textBullet");
        $("#wifiGen-txt-pwd24").removeAttr("type","text");
        $("#wifiGen-txt-pwd24").attr("type","password");
      }
    });

    var wifiGenTextLabel5 = $("#wifiGen-textLabel-pwd5").text();
    $("#wifiGen-textLabel-pwd5").text("");
    for (i=0; i<wifiGenTextLabel5.length; i++){
      $("#wifiGen-textLabel-pwd5").append("\u2022");
    }
    $("#wifiGen-chk-pwd5").click(function(){
      var passwordTxt5 = $("#wifiGen-txt-pwd5").val();
      if (this.checked){
        $("#wifiGen-textLabel-pwd5").text(passwordTxt5);
        $("#wifiGen-textLabel-pwd5").removeClass("wifiGen-textBullet");
        $("#wifiGen-txt-pwd5").removeAttr("type","password");
        $("#wifiGen-txt-pwd5").attr("type","text");
      } else {
        $("#wifiGen-textLabel-pwd5").text("");
        for (i=0; i<passwordTxt5.length; i++){
          $("#wifiGen-textLabel-pwd5").append("\u2022");
        }
        $("#wifiGen-textLabel-pwd5").addClass("wifiGen-textBullet");
        $("#wifiGen-txt-pwd5").removeAttr("type","text");
        $("#wifiGen-txt-pwd5").attr("type","password");
      }
    });
    function response(res){
      $("#passwordModal").modal('hide');
    }
    var wifiType = "24G";
    $("#wifiGen-btn-cpwd5 , #wifiGen-btn-cpwd24").click(function(){
      $("#wifiGen-info-pwd2").val("");
      $("#wifiGen-info-pwd").val("");
      $("#passStrength").removeClass();
      $(".not-similar").css("display", "none");
      $(".weak-password").css("display", "none");
      $("#passStrength").addClass("passwordStrength strength1");
      $("#password-span-strwk").removeClass("hide").addClass("show");
      $("#password-span-strgd,#password-span-strsg").removeClass("show").addClass("hide");
    });
    $("#wifiGen-btn-cpwd5").click(function(){
      wifiType = "5G";
    });
    $("#wifiGen-btn-cpwd24").click(function(){
      wifiType = "24G";
    });
    $("#password_apply").click(function() {
      var target = "/modals/wifi/general.lp";
      var params = [];
      var newPassword = $('input[name="new_pwd"]').val();
      var retypePassword = $('input[name="cnf_pwd"]').val();
      var securityMode24= $("#wifiGen-sel-mode24").val();
      var securityMode5= $("#wifiGen-sel-mode5").val();
        if (wifiType  == "24G") {
          document.getElementById("wifiGen-txt-pwd24").value = newPassword;
          if($("#wifiGen-chk-pwd24").prop("checked")){
            $("#wifiGen-textLabel-pwd24").text(newPassword);
          }else{
            $("#wifiGen-textLabel-pwd24").text("");
            for (i=0; i<newPassword.length; i++){
              $("#wifiGen-textLabel-pwd24").append("\u2022");
            }
          }
        } else {
          document.getElementById("wifiGen-txt-pwd5").value = newPassword;
		  if($("#wifiGen-chk-pwd5").prop("checked")){
		    $("#wifiGen-textLabel-pwd5").text(newPassword);
		  }else{
                  for(var i = 0; i < newPassword.length; i++) { bullets += this; }
                  return bullets;
                  $("#wifiGen-textLabel-pwd5").html(bullets.replace(newPassword.length));
		  }
         }
    })

  $("#global-apply, #modal-apply").click(function() {
    var iserr, iserr1;
    var target = "/modals/wifi/general.lp";
    var form = $("#wifigeneral_form");
    var params = form.serializeArray();
    var wifi_stat24 = $("#wifiGen-btn-edit24").hasClass("button-on") ? 1 : 0;
    var wifi_stat5 = $("#wifiGen-btn-edit5").hasClass("button-on") ? 1 : 0;
    var broadcast_ssid24 = $("#wifiGen-btn-bssid24").hasClass("button-on") ? 1 : 0;
    var broadcast_ssid5 = $("#wifiGen-btn-bssid5").hasClass("button-on") ? 1 : 0;
    var channel24 = $("#wifiGen-sel-channel24").val();
    var channel5 = $("#wifiGen-sel-channel5").val();
    var securityMode24= $("#wifiGen-sel-mode24").val();
    var wifi_ssid24 = $("#wifiGen-txt-ssid24").val();
    var password24 = $("#wifiGen-txt-pwd24").val();
    var password5;
    function isASCII(str) {
      return /^[\x00-\x7F]*$/.test(str);
    }
    var isAscii = isASCII(wifi_ssid24);
    var length24 = wifi_ssid24.length;
    if((isAscii == false) || (length24 <= 0) || (length24 > 32)){
      iserr = 1;
    }
    // If bandSteerValue !== "bs0" means bandSteer is disabled ssid, security mode, password are taken from 5 GHZ during post
    if (bandSteerValue !== "bs0")
    {
      var wifi_ssid5 = $("#wifiGen-txt-ssid5").val();
      var securityMode5 = $("#wifiGen-sel-mode5").val();
      password5 = $("#wifiGen-txt-pwd5").val();
      var isAscii5 = isASCII(wifi_ssid5);
      var length5 = wifi_ssid5.length;
      if ((isAscii5 === false) || (length5 <= 0) || (length5 > 32))
      {
        iserr1 = 1;
      }
    }
    // If bandSteer is enabled 5 GHZ will be read only, at this time values of 2.4 GHZ will be sent in post for 5GHZ
    else
    {
      var wifi_ssid5 = $("#wifiGen-txt-ssid24").val();
      var securityMode5 = $("#wifiGen-sel-mode24").val();
      password5 = $("#wifiGen-txt-pwd24").val();
      params.push({
        name : "wifi_ssid5",
        value : wifi_ssid5
      });
    }
    if ( wifi_stat24 == 1 && wifi_stat5 == 1){
      if((iserr == 1) && (iserr1 == 1)){
        $("#wifiGen-txt-ssid24").addClass("input-length");
        $("#wifiGen-txt-ssid5").addClass("input-length");
        return;
      } else {
        $("#wifiGen-txt-ssid24").removeClass("input-length");
        $("#wifiGen-txt-ssid5").removeClass("input-length");
      }
    }
    if ( wifi_stat24 == 1 && wifi_stat5 == 1){
      if(iserr == 1) {
        $("#wifiGen-txt-ssid24").addClass("input-length");
        return;
      } else {
        $("#wifiGen-txt-ssid24").removeClass("input-length");
      }
      if(iserr1 == 1){
        $("#wifiGen-txt-ssid5").addClass("input-length");
        return;
        } else {
          $("#wifiGen-txt-ssid5").removeClass("input-length");
        }
      }
      params.push({
        name : "wifi_stat24",
        value : wifi_stat24
      },{
        name : "broadcast_ssid24",
        value : broadcast_ssid24
      },{
        name : "channel24",
        value : channel24
      },{
        name : "securityMode24",
        value : securityMode24
      },{
        name : "securityMode5",
        value : securityMode5
      },{
        name : "channel5",
        value : channel5
      },{
        name : "broadcast_ssid5",
        value : broadcast_ssid5
      },{
        name : "wifi_stat5",
        value : wifi_stat5
      },{
        name : "password24" ,
        value : password24
      },{
        name : "password5" ,
        value : password5
      });
      postHandler(target, params);
    });
  });
  $("#global-cancel").click(function() {
    $("#content").load("/modals/wifi/general.lp"); });
  function CloseModal(){
    $("#wifiGen-info-pwd2").val("");
    $("#wifiGen-info-pwd").val("");
    $("#passStrength").removeClass();
    $("#passStrength").addClass("passwordStrength strength1");
    $("#password-span-strwk").removeClass("hide").addClass("show");
    $("#password-span-strgd,#password-span-strsg").removeClass("show").addClass("hide");
    $(".not-similiar").css("display", "none");
    $(".weak-password").css("display", "none");
    $("#wifiGen2-info-pwd64,#wifiGen-info-char").addClass("hide");
    $("#password_apply").addClass("op40");
    $("#passwordModal").modal('hide');
  }

//Validate whether the selected channel belongs to Radar detection Avoidance – Channel range (52-144 but not 68 to 96) for Vodafone New Zealand
function isRadardetectionAvoidanceChannel(value) {
  return (variant == "VF-NZ" && (!isNaN(value)) && ((value >= 52 && value <= 67) || (value >= 97 && value <= 144)))
}

$("#resetR, .resetR").click(function(){
  $("#wifiGen-txt-ssid24").val(resetWifi.reset_wifi_low_ssid);
  $("#wifiGen-sel-channel24").val(resetWifi.reset_wifi_low_channel).trigger("chosen:updated");
  $("#wifiGen-sel-mode24").val(resetWifi.reset_wifi_low_protection_mode).trigger("chosen:updated");
  $("#wifi24password").addClass("show").removeClass("hide");
  $("#wifiGen-txt-pwd24").val(resetWifi.reset_wifi_low_password);
  $("#wifiGen-sel-channel24").val(resetWifi.reset_wifi_low_channel);
  $("#wifiGen-txt-ssid5").val(resetWifi.reset_wifi_high_ssid);
  $("#wifiGen-sel-channel5").val(resetWifi.reset_wifi_high_channel).trigger("chosen:updated");
  $("#wifiGen-sel-mode5").val(resetWifi.reset_wifi_high_protection_mode).trigger("chosen:updated");
  $("#wifi5password").addClass("show").removeClass("hide");
  $("#wifiGen-txt-pwd5").val(resetWifi.reset_wifi_high_password);
  $("#wifiGen-sel-channel5").val(resetWifi.reset_wifi_high_channel);

  changeButton("#wifiGen-btn-edit24", resetWifi.reset_wifi_low_enable, "#wifiGen-info24");
  changeButton("#wifiGen-btn-bssid24", resetWifi.reset_wifi_low_broadcast);
  changeButton("#wifiGen-btn-edit5", resetWifi.reset_wifi_high_enable, "#wifiGen-info5");
  changeButton("#wifiGen-btn-bssid5", resetWifi.reset_wifi_high_broadcast);

});
