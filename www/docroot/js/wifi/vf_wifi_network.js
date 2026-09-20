$(function () {
  $('select').chosen({
    disable_search_threshold: 100000,
    allow_single_deselect: true
  });

  $("#home-sel-mode, #home-sel-mobmode").change(function() {
    ($("#wifiStatus").val() == "1" && $(this).val() === "35") ? $("#hide-page").show() : $("#hide-page").hide();
  });

  $("[type=radio]:not(:checked)").closest(".vdf-row").find("[type=text]").prop("disabled", true).addClass("op40 op50");

  $("[type=radio]").click(function() {
    $("[type=radio]:checked").closest(".vdf-row").find("[type=text]").prop("disabled", false).removeClass("op40 op50");
    $("[type=radio]:not(:checked)").closest(".vdf-row").find("[type=text]").prop("disabled", true).addClass("op40 op50").removeClass("input-error").val("0");
  });

  $(".keypressvalue").keyup(function() {
    $("#vf-wifi-btn-server-add").removeClass("faded").prop("disabled", false);
  });

  $("#server-table").on("click", ".button-delete", function() {
    $(this).closest(".vdf-row").remove();
    $("[id^=vf-wifi-info-server]").each(function(index) {
      $(this).attr('id', "vf-wifi-info-server"+(index+1));
    });
    $("[id^=vf-wifi-btn-server-del]").each(function(index) {
      $(this).attr('id', "vf-wifi-btn-server-del"+(index+1));
    });
    $(".maxRow").show();
  });

  var target = "/modals/wifi/vf_wifi_network.lp";
  var params = [];


  $("#vf-wifi-btn-server-add").click(function() {
    var IPAddress = $("#vf-wifi-txt-server").val();
    //Calling validIPv4 Method and validate the IPv4
    if(validIPv4(IPAddress) && (IPAddress != "255.255.255.255")){
    //If IPv4 is valid then allow to add the row else add red border for textbox
      var infoID = $(".server").length + 1;
      var addIPRow = $('<div class="vdf-row server" style="font-weight:bold;line-height:24px;">\
                        <div class="left" id="vf-wifi-info-server' + infoID + '">' + IPAddress + '</div>\
                        <div class="right"><input type="button" class="button button-delete" id="vf-wifi-btn-server-del' + infoID + '"></div>\
                        </div>');
      addIPRow.insertBefore('.maxRow');
      $("#vf-wifi-txt-server").val("").removeClass("input-error");
    }
    else{
      $("#vf-wifi-txt-server").addClass("input-error").focus();
    }
    var rowCount = $(".server").length;
    hideElement(rowCount);
    $("#vf-wifi-btn-server-add").addClass("faded").prop("disabled", true);
  });

  if ($(window).width() > 767 && $("#home-sel-mode").val() == "34" ||
      $(window).width() < 767 && $("#home-sel-mobmode").val() == "34") {
    $("#hide-page").hide();
  }

  $("#vf-wifi-btn-onoff").click(function(){
    if ($(window).width() > 767 && $("#home-sel-mode").val() == "35" || $(window).width() < 767 && $("#home-sel-mobmode").val() == "35") {
      $(this).toggleClass('button-on button-off');
      $("#hide-page").slideToggle();
    } else $(this).toggleClass("button-on button-off");
  });

  $("#vf-wifi-btn-userselect").click(function(){
    $(this).toggleClass('edited notedited');
    $(this).toggleClass('button-on button-off');
  });

  var elements = {
      AuthPort : "#vf-wifi-txt-AuthPort",
      AccountingPort : "#vf-wifi-txt-AccPort",
      VLANOpenSSID : "#vf-wifi-txt-openSSID",
      VLANEAPSSID : "#vf-wifi-txt-EAPSSID",
      EAPSecret : "#vf-wifi-txt-EAPSecret",
      Maxassocusers : "#vf-wifi-txt-maxUser",
      MaxassocusersOpenSSID : "#vf-wifi-txt-maxUserOpen",
      MaxassocusersEAPSSID : "#vf-wifi-txt-maxUserEAP",
      MinimumSyncSpeed : "#vf-wifi-txt-syncSpeed",
      bandWidth : "#vf-wifi-txt-BWpercent:not(op40)",
      MaxBW : "#vf-wifi-txt-BWkbps:not(op40)",
      EAPServers : "#vf-wifi-txt-EAPServer",
      Server : "#vf-wifi-txt-server"
    }

    var validations = {
      AuthPort : validateNumberRange(0, 65535),
      AccountingPort : validateNumberRange(0, 65535),
      VLANOpenSSID : validateNumberRange(1, 4095),
      VLANEAPSSID : validateNumberRange(1, 4095),
      EAPSecret : validateStringLength(1, 63),
      Maxassocusers : validateNumberRange(0, 125),
      MaxassocusersOpenSSID : validateNumberRange(0, 125),
      MaxassocusersEAPSSID : validateNumberRange(0, 125),
      MinimumSyncSpeed : validateNumberRange(0, 2147483647),
      bandWidth : validateNumberRange(0, 100),
      MaxBW : validateNumberRange(0, 2147483647),
      EAPServers : IPRegExp,
      Server : function(ip) { return ip == "" || IPRegExp.test(ip); }
    }

  $("#global-apply").click(function() {
    var VodafoneWiFi = $("#vf-wifi-btn-onoff").hasClass("button-on") ? 1 : 0;
    var CSRFtoken = $("#vf-wifi-network_form #CSRFtoken").val();
    params = [];
    params.push({
      name  : "VodafoneWiFi",
      value :  VodafoneWiFi
    });

    if ($(window).width() > 767 && $("#home-sel-mode").val() == "35" || $(window).width() < 767 && $("#home-sel-mobmode").val() == "35") {
      if (!validateElements(elements, validations)) {
        return false;
      }
      var SelectUser            = $("#vf-wifi-btn-userselect").hasClass("button-on") ? 1 : 0;
      var AuthPort              = $("#vf-wifi-txt-AuthPort").val();
      var AccountingPort        = $("#vf-wifi-txt-AccPort").val();
      var VLANOpenSSID          = $("#vf-wifi-txt-openSSID").val();
      var VLANEAPSSID           = $("#vf-wifi-txt-EAPSSID").val();
      var EAPSecret             = $("#vf-wifi-txt-EAPSecret").val();
      var Maxassocusers         = $("#vf-wifi-txt-maxUser").val();
      var MaxassocusersOpenSSID = $("#vf-wifi-txt-maxUserOpen").val();
      var MaxassocusersEAPSSID  = $("#vf-wifi-txt-maxUserEAP").val();
      var MinimumSyncSpeed      = $("#vf-wifi-txt-syncSpeed").val();
      var bandWidth             = $("#percentBw:checked").closest(".vdf-row").find("#vf-wifi-txt-BWpercent").val() || "0";
      var MaxBW                 = $("#maxBw:checked").closest(".vdf-row").find("#vf-wifi-txt-BWkbps").val() || "0";
      var EAPServers            = $("#vf-wifi-txt-EAPServer").val();

      var Servers = [];
      $(".server").each(function() {
       Servers.push($(this).find('div:first').text());
     });
      Servers.join(",");

      params.push({
       name  : "SelectUser",
       value :  SelectUser
     }, {
       name  : "Servers",
       value :  Servers
     }, {
       name  : "EAPServers",
       value :  EAPServers
     }, {
       name  : "AuthPort",
       value :  AuthPort
     }, {
       name  : "AccountingPort",
       value :  AccountingPort
     }, {
       name  : "VLANOpenSSID",
       value :  VLANOpenSSID
     }, {
       name  : "VLANEAPSSID",
       value :  VLANEAPSSID
     }, {
       name  : "EAPSecret",
       value :  EAPSecret
     }, {
       name  : "Maxassocusers",
       value :  Maxassocusers
     }, {
       name  : "MaxassocusersOpenSSID",
       value :  MaxassocusersOpenSSID
     }, {
       name  : "MaxassocusersEAPSSID",
       value :  MaxassocusersEAPSSID
     }, {
       name  : "MinimumSyncSpeed",
       value :  MinimumSyncSpeed
     }, {
       name  : "bandWidth",
       value :  bandWidth
     }, {
       name  : "MaxBW",
       value :  MaxBW
     });
    }
    params.push({
      name  : "CSRFtoken",
      value :  CSRFtoken
    }, {
      name  : "action",
      value :  "SAVE"
    });
    if($("#vf-wifi-btn-userselect").hasClass("edited")) {
      $('#vf-wifi-network-modal-popup').modal();
    } else {
      postHandler(target, params);
    }
  });

  $("#global-cancel").click(function() {
    $("#content").load("/modals/wifi/vf_wifi_network.lp");
  });

  $("#vf-wifi-network-btn-apply").click(function() {
    $.post(target, params, function() {
      window.location = "/";
    });
  });
  if ($(".server").length >= 4) {
    $(".maxRow").hide();
  }
});

//Checking valid IPv4
function validIPv4 (IPAddress){
  var ipSplit = IPAddress.split(".");
  //Checking IPv4 value length as four
  if(ipSplit.length === 4){
    for(var i = 0, len = ipSplit.length; i < len; i++){
      var part = ipSplit[i];
      //Checking IPv4 value is a number
      if(!/^[0-9]+$/.test(part)){
        return false;
      }
      if(part < 0 || part > 255){
        return false;
      }
    }
    return true;
  }
  return false;
}

function hideElement(rowCount) {
  rowCount >= 4 ? $(".maxRow").hide() : $(".maxRow").show();
}

$("#resetR, .resetR").click(function() {
  $("#vf-wifi-btn-onoff").val(resetVfWifi.reset_enabled);
  if (resetVfWifi.reset_enabled == "1") {
    $('#vf-wifi-btn-onoff').addClass('button-on').removeClass('button-off');
    if ($(window).width() > 767 && $("#home-sel-mode").val() == "35" ||
        $(window).width() < 767 && $("#home-sel-mobmode").val() == "35") {
      $('#hide-page').css("display", "block");
    }
  } else {
    $('#vf-wifi-btn-onoff').addClass('button-off').removeClass('button-on');
    $('#hide-page').css("display", "none");
  }
  $("#vf-wifi-btn-userselect").val(resetVfWifi.reset_user_selectable);
  if(getUserSelectState == "1") {
    $('#vf-wifi-btn-userselect').addClass('button-off').removeClass('button-on');
    $('#vf-wifi-btn-userselect').addClass('edited').removeClass('notedited');
  } else {
   $('#vf-wifi-btn-userselect').addClass('button-off').removeClass('button-on');
   $('#vf-wifi-btn-userselect').addClass('notedited').removeClass('edited');
  }
  $("#vf-wifi-txt-EAPServer").val(resetVfWifi.reset_eap_server);
  $("#vf-wifi-txt-AuthPort").val(resetVfWifi.reset_auth_port);
  $("#vf-wifi-txt-AccPort").val(resetVfWifi.reset_accounting_port);
  $("#vf-wifi-txt-openSSID").val(resetVfWifi.reset_vlan_open_ssid);
  $("#vf-wifi-txt-EAPSSID").val(resetVfWifi.reset_vlan_eap_ssid);
  $("#vf-wifi-txt-EAPSecret").val(resetVfWifi.reset_eap_secret);
  $("#vf-wifi-txt-maxUser").val(resetVfWifi.reset_qos_max_user);
  $("#vf-wifi-txt-maxUserOpen").val(resetVfWifi.reset_qos_assoc_users_open);
  $("#vf-wifi-txt-maxUserEAP").val(resetVfWifi.reset_qos_assoc_users_eap_ssid);
  $("#vf-wifi-txt-syncSpeed").val(resetVfWifi.reset_qos_min_sync_speed);
  $("#vf-wifi-txt-BWpercent").val(resetVfWifi.reset_qos_bw);

  if (resetVfWifi.reset_qos_bw != "0") {
    $("#percentBw").click();
    $("#vf-wifi-txt-BWpercent").removeClass("op40 op50").prop("disabled", false);
    $("#vf-wifi-txt-BWkbps").addClass("op40 op50").prop("disabled", true);
  } else {
    $("#maxBw").click();
    $("#vf-wifi-txt-BWkbps").removeClass("op40 op50").prop("disabled", false);
    $("#vf-wifi-txt-BWpercent").addClass("op40 op50").prop("disabled", true);
  }

  $("[id^=vf-wifi-btn-server-del]").click();
  $("#vf-wifi-txt-server").val(resetVfWifi.reset_gre_server);
  $("#vf-wifi-btn-server-add").click();
});
