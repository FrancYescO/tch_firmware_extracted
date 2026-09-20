$(function () {
  $('select').chosen({
    disable_search_threshold: 100000,
    allow_single_deselect: true
  });
});

// Function to validate domain name
function isValidDomain(str) {
  var regUrl = /^((" ")?([\w]+:)?\/\/)?(([\d\w]|%[a-fA-f\d]{2,2})+(:([\d\w]|%[a-fA-f\d]{2,2})+))?([\d\w][\d\w]{0,253}[\d\w]([\.\-]\w+)*\.)+[\w]{2,4}(:[\d]+)?(\/([-+_~.\d\w]|%[a-fA-f\d]{2,2})*)*(\?(&?([-+_~.\d\w]|%[a-fA-f\d]{2,2})=?)*)?(#([-+_~.\d\w]|%[a-fA-f\d]{2,2})*)?$/;
  var ipUrl = /^((" ")?([\w]+:)?\/\/)?((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])(\/.*)?$/;
  var invalidIpUrl = /^((" ")?([\w]+:)?\/\/)?(\d+\.\d+\.\d+\.\d+)(.*)?$/;
  if(ipUrl.test(str) == true) {
    return true;
  } else {
    if(invalidIpUrl.test(str) == true) {
      return false;
    } else {
      if(regUrl.test(str) == false) {
        return false;
      } else {
        return true;
      }
    }
  }
}

function isAlphaNumeric(str) {
  var regExpression=/^[0-9a-zA-Z+]*$/;
  return regExpression.test(str);
}

// Function to validate ingress & egress gain
function gainValidation(value) {
  if((isNaN(value)) || (Number(value) < -15) || (Number(value) > 3)) {
    return false;
  } else {
    return true;
  }
}

// Function to validate port range
function portValidation(value) {
  var regExForPort = /^[0-9]+$/;
  var portRange = 65535;
  if((regExForPort.test(value) == false) || (Number(value) < 0) || (Number(value) > portRange)) {
    return false;
  } else {
    return true;
  }
}

function errorPopover(id,text) {
  $(id).addClass("error-tooltip");
    $(id).each(function() {
      var $this = $(this);
      $this.popover({
        trigger: 'hover',
        placement: 'bottom',
        html: true,
        content:text
      });
    });
}

var params = [];
var userName = [];
var passWord = [];
var uri = [];
var dscpArray = ["ef", "af11", "af12", "af13", "af21", "af22", "af23", "af31", "af32", "af33", "af41", "af42", "af43", "cs0", "cs1", "cs2", "cs3", "cs4", "cs5", "cs6", "cs7"];

$(".phone-settings-profile").each(function(index) {
  var i = index;
  userName.push($("#phnset_uname_txt"+i+"").val());
  passWord.push($("#phnset_pwd_txt"+i+"").val());
  uri.push($("#phnset_num_txt"+i+"").val());
});

$("#global-apply, #modal-apply").click(function() {
  var userNameSelect   =   [];
  var passWordSelect   =   [];
  var uriSelect        =   [];
  var target           =   "/modals/phone/settings.lp";
  var form             =   $("#phoneSettings-form");
  params               =   form.serializeArray();
  var imgCodec         =   $("#phnset_btn_imgcodec").hasClass("button-on") ? 1 : 0 ;
  var faxTransport     =   $("#phnset_btn_faxtransport").hasClass("button-on") ? 1 : 0 ;
  var echoCancellation =   $("#phnset_btn_echocancel").hasClass("button-on") ? 1 :0 ;
  var vad              =   $("#phnset_btn_vad").hasClass("button-on") ? 1 :0 ;
  var location         =   $("#phnset_chk_loc").val();
  var intfName         =   $("#phnset_sel_intfname").val();
  var preferredCodec1  =   $("#phnset_sel_codec1").val();
  var preferredCodec2  =   $("#phnset_sel_codec2").val();
  var packetization1   =   $("#phnset_sel_packet1").val();
  var packetization2   =   $("#phnset_sel_packet2").val();
  var state1           =   $("#phnset_btn_codecstat1").hasClass("button-on") ? 1 : 0 ;
  var state2           =   $("#phnset_btn_codecstat2").hasClass("button-on") ? 1 : 0 ;
  var prack            =   $("#phnset_btn_prack").hasClass("button-on") ? 1 : 0 ;
  var domain           =   $("#phnset_domain_txt").val();
  var primreg          =   $("#phnset_txt_preg").val();
  var primRegPort      =   $("#phnset_txt_pregport").val();
  var primProxy        =   $("#phnset_txt_pproxy").val();
  var secReg           =   $("#phnset_txt_sreg").val();
  var secProxy         =   $("#phnset_txt_sproxy").val();
  var primProxyPort    =   $("#phnset_txt_pproxyport").val();
  var secRegPort       =   $("#phnset_txt_sregport").val();
  var secProxyPort     =   $("#phnset_txt_sproxyport").val();
  var dialTimeout      =   $("#phnset_txt_dtimeout").val();
  var minHookFlash     =   $("#phnset_txt_minhook").val();
  var maxHookFlash     =   $("#phnset_txt_maxhook").val();
  var rtcpPacket       =   $("#phnset_btn_rtcpPacket").val();
  var digitTimeOut     =   $("#phnset_txt_digittimeout").val();
  var rtpMin           =   $("#phnset_btn_rtpmin").val();
  var rtpMax           =   $("#phnset_btn_rtpmax").val();
  var regExpire        =   $("#phnset_btn_regexptimeout").val();
  var regInterval      =   $("#phnset_btn_regretryintrevel").val();
  var sesTimer         =   $("#phnset_btn_sessiontimerexp").val();
  var sesTimerMin      =   $("#phnset_btn_sessiontimermin").val();
  var dtmfMode         =   $("#phnset_btn_dtmfmode").val()
  var primProxyRetryIntr = $("#phnset_btn_primProxyRetryIntr").val();
  var dscpRtp          =   $("#phnset_btn_dscprtp").val();
  var signalDscp       =   $("#phnset_btn_sigdscp").val();
  var ingressGain      =   $("#phnset_txt_igain").val();
  var egressGain       =   $("#phnset_txt_egain").val();
  var classCheck, isError
  var regExpTimeoutMin = 60;
  var regExpTimeoutMax = 86400;
  var portRange        = 65535;
  var serLength        = 257;
  var regExForPort     = /^[0-9]+$/;

  if((regExForPort.test(regExpire) == false) || (Number(regExpire) < regExpTimeoutMin) || (Number(regExpire) > regExpTimeoutMax)) {
    classCheck = 1;
    $("#phnset_btn_regexptimeout").addClass("input-error");
  } else {
    $("#phnset_btn_regexptimeout").removeClass("input-error");
  }
  var elements = {
    primProxyRetryIntr: "#phnset_btn_primProxyRetryIntr",
    rtcpPacket: "#phnset_btn_rtcpPacket",
    ingressGain: "#phnset_txt_igain",
    egressGain: "#phnset_txt_egain",
    regInterval: "#phnset_btn_regretryintrevel",
  }

  var validations = {
    primProxyRetryIntr: portValidation,
    rtcpPacket: portValidation,
    ingressGain: gainValidation,
    egressGain: gainValidation,
    regInterval: portValidation,
  }

  if(!validateElements(elements, validations)) {
    return false;
  }
  if((regExForPort.test(sesTimer) == false) || (Number(sesTimer) < 90) || (Number(sesTimer) > portRange)) {
    classCheck = 1;
    $("#phnset_btn_sessiontimerexp").addClass("input-error");
  } else {
    $("#phnset_btn_sessiontimerexp").removeClass("input-error");
  }
  if((regExForPort.test(sesTimerMin) == false) || (Number(sesTimerMin) < 90) || (Number(sesTimerMin) > portRange) || (Number(sesTimerMin) > Number(sesTimer))) {
    classCheck = 1;
    $("#phnset_btn_sessiontimermin").addClass("input-error");
  } else {
    $("#phnset_btn_sessiontimermin").removeClass("input-error");
  }
  if((regExForPort.test(dialTimeout) == false) || (Number(dialTimeout) < 1000) || (Number(dialTimeout) > 60000)) {
    classCheck = 1;
    $("#phnset_txt_dtimeout").addClass("input-error");
  } else {
    $("#phnset_txt_dtimeout").removeClass("input-error");
  }
  if ((regExForPort.test(minHookFlash) == false) || (Number(minHookFlash) < 0) || (Number(minHookFlash) > portRange ) || (Number(minHookFlash) >= Number(maxHookFlash))) {
    classCheck = 1;
    $("#phnset_txt_minhook").addClass("input-error");
  } else {
    $("#phnset_txt_minhook").removeClass("input-error");
  }
  if ((regExForPort.test(maxHookFlash) == false) || (Number(maxHookFlash) < 0) || (Number(maxHookFlash) > portRange ) || (Number(minHookFlash) >= Number(maxHookFlash))) {
    classCheck = 1;
    $("#phnset_txt_maxhook").addClass("input-error");
  } else {
    $("#phnset_txt_maxhook").removeClass("input-error");
  }
  if((regExForPort.test(digitTimeOut) == false) || (Number(digitTimeOut) < 1000) || (Number(digitTimeOut) > 60000)) {
    classCheck = 1;
    $("#phnset_txt_digittimeout").addClass("input-error");
  } else {
    $("#phnset_txt_digittimeout").removeClass("input-error");
  }
  if ((regExForPort.test(rtpMin) == false) || (Number(rtpMin) < 1024) || (Number(rtpMin) > portRange ) || (Number(rtpMin) >= Number(rtpMax))) {
    classCheck = 1;
    $("#phnset_btn_rtpmin").addClass("input-error");
  } else {
    $("#phnset_btn_rtpmin").removeClass("input-error");
  }
  if ((regExForPort.test(rtpMax) == false) || (Number(rtpMax) < 1024) || (Number(rtpMax) > portRange ) || (Number(rtpMax) <= Number(rtpMin))) {
    classCheck = 1;
    $("#phnset_btn_rtpmax").addClass("input-error");
  } else {
    $("#phnset_btn_rtpmax").removeClass("input-error");
  }
  if ((dscpRtp == "") || ((regExForPort.test(dscpRtp) == false) && (dscpArray.indexOf(dscpRtp) == -1))) {
    classCheck = 1;
    $("#phnset_btn_dscprtp").addClass("input-error");
  } else {
    $("#phnset_btn_dscprtp").removeClass("input-error");
  }
  if ((regExForPort.test(signalDscp) == false) && (dscpArray.indexOf(signalDscp) == -1)) {
    classCheck = 1;
    $("#phnset_btn_sigdscp").addClass("input-error");
  } else {
    $("#phnset_btn_sigdscp").removeClass("input-error");
  }
  if (primreg.length > serLength) {
    classCheck = 1;
    $("#phnset_txt_preg").addClass("input-error");
  } else {
    $("#phnset_txt_preg").removeClass("input-error");
  }
  if((domain == "") && (primreg == "")) {
    classCheck = 1;
    $("#phnset_txt_preg").addClass("input-error");
    $("#phnset_domain_txt").addClass("input-error");
  } else {
    $("#phnset_txt_preg").removeClass("input-error");
    $("#phnset_domain_txt").removeClass("input-error");
  }
  if (primProxy.length > serLength) {
    classCheck = 1;
    $("#phnset_txt_pproxy").addClass("input-error");
  } else {
    $("#phnset_txt_pproxy").removeClass("input-error");
  }
  if((domain == "") && (primProxy == "")) {
    classCheck = 1;
    $("#phnset_txt_pproxy").addClass("input-error");
    $("#phnset_domain_txt").addClass("input-error");
  } else {
    $("#phnset_txt_pproxy").removeClass("input-error");
    $("#phnset_domain_txt").removeClass("input-error");
  }
  if (secReg.length > serLength) {
    classCheck = 1;
    $("#phnset_txt_sreg").addClass("input-error");
  } else {
    $("#phnset_txt_sreg").removeClass("input-error");
  }
  if (secProxy.length > serLength) {
    classCheck = 1;
    $("#phnset_txt_sproxy").addClass("input-error");
  } else {
    $("#phnset_txt_sproxy").removeClass("input-error");
  }
  /*if ((regExForPort.test(primRegPort) == false) || (Number(primRegPort) < 0) || (Number(primRegPort) > portRange )) {
    classCheck = 1;
    $("#phnset_txt_pregport").addClass("input-error");
  } else {
    $("#phnset_txt_pregport").removeClass("input-error");
  }*/
  /*if ((regExForPort.test(primProxyPort) == false) || (Number(primProxyPort) < 0) || (Number(primProxyPort) > portRange )) {
    classCheck = 1;
    $("#phnset_txt_pproxyport").addClass("input-error");
  } else {
    $("#phnset_txt_pproxyport").removeClass("input-error");
  }*/
  /*if ((regExForPort.test(secRegPort) == false) || (Number(secRegPort) < 0 ) || (Number(secRegPort) > portRange )) {
    classCheck = 1;
    $("#phnset_txt_sregport").addClass("input-error");
  } else {
    $("#phnset_txt_sregport").removeClass("input-error");
  }*/
  /*if ((regExForPort.test(secProxyPort) == false) || (Number(secProxyPort) < 0) || (Number(secProxyPort) > portRange )) {
    classCheck = 1;
    $("#phnset_txt_sproxyport").addClass("input-error");
  } else {
    $("#phnset_txt_sproxyport").removeClass("input-error");
  }*/
  /*if(isValidDomain(domain) == false) {
    $("#phnset_domain_txt").addClass("input-error");
    classCheck = 1;
  } else {
    $("#phnset_domain_txt").removeClass("input-error");
  }*/

  $(".phone-settings-profile").each(function(index) {
    var i = index;
    userNameSelect.push($("#phnset_uname_txt"+i+"").val());
    passWordSelect.push($("#phnset_pwd_txt"+i+"").val());
    if ((userName[i] != userNameSelect[i]) && (userNameSelect[i].length == 0) || (userNameSelect[i].length > 64) || (userNameSelect[i].indexOf(' ') >= 0)) {
      classCheck = 1;
      $("#phnset_uname_txt"+i+"").addClass("input-error");
    } else {
      $("#phnset_uname_txt"+i+"").removeClass("input-error");
    }
    if (passWordSelect[i].length > 64 ) {
      classCheck = 1;
      errorPopover("#phnset_pwd_txt"+i+"","The length of Password cannot exceed 64 characters");
    }
    if ((userNameSelect[i].length != 0) && (userName[i] != userNameSelect[i]) && (passWordSelect[i].length == 0) || (passWordSelect[i].length > 64) || (passWordSelect[i].indexOf(' ') >= 0)) {
      classCheck = 1;
      $("#phnset_pwd_txt"+i+"").addClass("input-error");
    } else {
      $("#phnset_pwd_txt"+i+"").removeClass("input-error");
    }
  });
  $(".phone-settings-profile").each(function(index) {
    var i = index;
    uriSelect.push($("#phnset_num_txt"+i+"").val());
    if (uriSelect[i] != uri[i]) {
      for (j = 0; j < uri.length; j++) {
        if (i != j) {
          uriSelect.push($("#phnset_num_txt"+j+"").val());
          if (uriSelect[i] == uriSelect[j]) {
            classCheck = 1;
            $("#phnset_num_txt"+i+"").addClass("input-error");
          } else {
            $("#phnset_num_txt"+i+"").removeClass("input-error");
          }
        }
      }
    }
  });
  if (classCheck == "1") {
    $(".input-error:first").focus();
    return true;
  }

  $(".phone-settings-profile").each(function(index) {
    var i = index+1;
    var uname = $("#phnset_uname_txt" + index).val();
    var pwd = $("#phnset_pwd_txt" + index).val();
    if((pwd.length > 0) || ((uname.length == 0) && (pwd.length == 0))) {
      params.push({
        name  : "pwd"+i,
        value :  pwd
      });
    }
  });

  $(".phone-settings-profile").each(function(index) {
    var profileState = $(".phone-settings-profile #phnset_line_txt"+index+"").hasClass("button-on") ? 1 : 0;
    var indexValue = $(this).find("input:eq(0)").val();
    var IDName = $(this).find("input:eq(1)").val();
    var phnno = $(this).find("input:eq(2)").val();
    var uname = $(this).find("input:eq(3)").val();
    if (IDName.length > 63) {
      classCheck = 1;
      $(this).find("input:eq(1)").addClass("input-error");
    } else {
      $(this).find("input:eq(1)").removeClass("input-error");
    }
    if ((isAlphaNumeric(phnno) == false) || (phnno.length > 390) || (phnno.length == 0)) {
      classCheck = 1;
      $(this).find("input:eq(2)").addClass("input-error");
    } else {
      $(this).find("input:eq(2)").removeClass("input-error");
    }
    if ((uname.length < 0 )|| (uname.length > 64)) {
      classCheck = 1;
      $(this).find("input:eq(3)").addClass("input-error");
    } else {
      $(this).find("input:eq(3)").removeClass("input-error");
    }
    if(classCheck == "1") {
      isError  = 1;
      return false;
    }
    var i = index+1;
    params.push({
      name  : "index"+i,
      value : indexValue
    }, {
      name  : "idName"+i,
      value :  IDName
    }, {
      name  : "phnNo"+i,
      value :  phnno
    }, {
      name  : "uname"+i,
      value :  uname
    }, {
      name  : "profileState"+i,
      value :  profileState
    });
  });

  params.push({
    name  : "rows",
    value : $(".phone-settings-profile").length
  }, {
    name  : "imgCodec",
    value :  imgCodec
  }, {
    name  : "faxTransport",
    value :  faxTransport
  }, {
    name  : "echoCancellation",
    value :  echoCancellation
  }, {
    name  : "vad",
    value :  vad
  }, {
    name  : "preferredCodec1",
    value :  preferredCodec1
  }, {
    name  : "preferredCodec2",
    value :  preferredCodec2
  }, {
    name  : "packetization1",
    value :  packetization1
  }, {
    name  : "packetization2",
    value :  packetization2
  }, {
    name  : "state1",
    value :  state1
  }, {
    name  : "state2",
    value :  state2
  }, {
    name  : "location",
    value :  location
  }, {
    name  : "intfName",
    value :  intfName
  }, {
    name  : "prack",
    value :  prack
  }, {
    name  : "dtmfMode",
    value :  dtmfMode
  });
  if (isError == 1) {
    $(".input-error:first").focus();
    return true;
  }
  postHandler(target, params);
});

$("#global-cancel").click(function() {
  $("#content").load("/modals/phone/settings.lp");
});

$("#resetR, .resetR").click(function() {
  $("#phnset_txt_preg").val(resetPhonesettings.reset_primary_reg_address);
  $("#phnset_txt_pregport").val(resetPhonesettings.reset_primary_reg_address_port);
  $("#phnset_txt_pproxy").val(resetPhonesettings.reset_primary_proxy_server_address);
  $("#phnset_txt_pproxyport").val(resetPhonesettings.reset_primary_proxy_server_address_port);
  $("#phnset_txt_sreg").val(resetPhonesettings.reset_secondary_reg_address);
  $("#phnset_txt_sregport").val(resetPhonesettings.reset_secondary_reg_address_port);
  $("#phnset_txt_sproxy").val(resetPhonesettings.reset_secondary_proxy_server_address);
  $("#phnset_txt_sproxyport").val(resetPhonesettings.reset_secondary_proxy_server_address_port);
  $("#phnset_domain_txt").val(resetPhonesettings.reset_user_agent_domain);
  $("#phnset_name_txt0").val(resetPhonesettings.reset_caller_id_name_1);
  $("#phnset_num_txt0").val(resetPhonesettings.reset_phone_no_1);
  $("#phnset_uname_txt0").val(resetPhonesettings.reset_username1);
  $("#phnset_pwd_txt0").val(resetPhonesettings.reset_password1);
  $("#phnset_name_txt1").val(resetPhonesettings.reset_caller_id_name_2);
  $("#phnset_num_txt1").val(resetPhonesettings.reset_phone_no_2);
  $("#phnset_uname_txt1").val(resetPhonesettings.reset_username2);
  $("#phnset_pwd_txt1").val(resetPhonesettings.reset_password2);
  $("#phnset_txt_dtimeout").val(resetPhonesettings.reset_voip_dial_timeout);
  $("#phnset_sel_codec1").val(resetPhonesettings.reset_preferred_codec_1).trigger("chosen:updated");
  $("#phnset_sel_packet1").val(resetPhonesettings.reset_packetization_1).trigger("chosen:updated");
  $("#phnset_sel_codec2").val(resetPhonesettings.reset_preferred_codec_2).trigger("chosen:updated");
  $("#phnset_sel_packet2").val(resetPhonesettings.reset_packetization_2).trigger("chosen:updated");
  $("#phnset_chk_loc").val(resetPhonesettings.reset_location).trigger("chosen:updated");
  $("#phnset_btn_rtpmax").val(resetPhonesettings.reset_local_rtp_max_port);
  $("#phnset_btn_rtpmin").val(resetPhonesettings.reset_local_rtp_min_port);
  $("#phnset_btn_dtmfmode").val(resetPhonesettings.reset_dtmf_mode).trigger("chosen:updated");
  $("#phnset_btn_regexptimeout").val(resetPhonesettings.reset_reg_exp_timeout);
  $("#phnset_btn_regretryintrevel").val(resetPhonesettings.reset_reg_retry_interval);
  $("#phnset_btn_sessiontimerexp").val(resetPhonesettings.reset_session_timer_exp);
  $("#phnset_btn_sessiontimermin").val(resetPhonesettings.reset_session_timer_minse);
  $("#phnset_sel_intfname").val(resetPhonesettings.reset_interface_name).trigger("chosen:updated");
  $("#phnset_btn_rtcpPacket").val(resetPhonesettings.reset_rtcpPacket).trigger("chosen:updated");
  $("#phnset_txt_minhook").val(resetPhonesettings.reset_minHookFlash).trigger("chosen:updated");
  $("#phnset_txt_maxhook").val(resetPhonesettings.reset_maxHookFlash).trigger("chosen:updated");
  $("#phnset_btn_dscprtp").val(resetPhonesettings.reset_dscpRtp).trigger("chosen:updated");
  $("#phnset_btn_sigdscp").val(resetPhonesettings.reset_signalDscp).trigger("chosen:updated");
  $("#phnset_txt_igain").val(resetPhonesettings.reset_ingressGain).trigger("chosen:updated");
  $("#phnset_txt_egain").val(resetPhonesettings.reset_egressGain).trigger("chosen:updated");
  $("#phnset_btn_primProxyRetryIntr").val(resetPhonesettings.reset_primProxyRetryIntr).trigger("chosen:updated");
  $("#phnset_txt_digittimeout").val(resetPhonesettings.reset_digitTimeOut).trigger("chosen:updated");

  changeButton("#phnset_line_txt0", resetPhonesettings.reset_line1);
  changeButton("#phnset_line_txt1", resetPhonesettings.reset_line2);
  changeButton("#phnset_btn_codecstat1", resetPhonesettings.reset_state_1);
  changeButton("#phnset_btn_codecstat2", resetPhonesettings.reset_state_2);
  changeButton("#phnset_btn_imgcodec", resetPhonesettings.reset_t38);
  changeButton("#phnset_btn_echocancel", resetPhonesettings.reset_echo_cancellation);
  changeButton("#phnset_btn_vad", resetPhonesettings.reset_VAD_support);
  changeButton("#phnset_btn_faxtransport", resetPhonesettings.reset_fax_detection);
  changeButton("#phnset_btn_prack", resetPhonesettings.reset_prack);
});
