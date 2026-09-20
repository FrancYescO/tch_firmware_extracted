$("#globalEnabled").click(function () {
  $("#globalEnabled").hasClass("button-on") ? ($(".dosexposed").addClass("show"), $(".dosexposed").removeClass("hide")) : ($(".dosexposed").addClass("hide"), $(".dosexposed").removeClass("show"));
});
$("[id$=Flood]").click(function (){
  $(this).hasClass("button-on") ? $('.dos'+this.id).show() : $('.dos'+this.id).hide();
});

var elements = {
  wholeICMPFloodVal  : "#wholeICMPFloodVal:visible",
  perSourceICMPFlood : "#perSourceICMPFloodVal:visible",
  tcpSyncFlood       : "#tcpSyncFloodVal:visible",
  tcpPerSyncFlood    : "#tcpPerSyncFloodVal:visible",
  udpFlood           : "#udpFloodVal:visible",
  udpPerFlood        : "#udpPerFloodVal:visible",
}
var validations = {
  wholeICMPFloodVal  : validateNumberRange(1, +icmpBurstLimit),
  perSourceICMPFlood : validateNumberRange(1, +icmpPerScriptBurst),
  tcpSyncFlood       : validateNumberRange(1, +tcpSynGlobalBurst),
  tcpPerSyncFlood    : validateNumberRange(1, +tcpSynPerScriptBurst),
  udpFlood           : validateNumberRange(1, +udpGlobalBurst),
  udpPerFlood        : validateNumberRange(1, +udpPerScriptBurst),
}
function changeButton(id, value, hiddenClass, hiddenField) {
  $(id).val(value);
  if (value == "1") {
    $(id).addClass('button-on').removeClass('button-off');
  } else {
    $(id).addClass('button-off').removeClass('button-on');
  }
}

$(function() {
  $("#global-apply").click(function() {
    var form = $("#dos-form");
    var target = form.attr("action");
    var params = form.serializeArray();
    var globalEnabled       =  $("#globalEnabled").hasClass("button-on") ? 1 : 0 ;
    var wholeIcmpFlood      =  $("#wholeIcmpFlood").hasClass("button-on") ? 1 : 0;
    var perSourceICMPFlood  =  $("#perSourceICMPFlood").hasClass("button-on") ? 1 : 0;
    var tcpSyncFlood        =  $("#tcpSyncFlood").hasClass("button-on") ? 1 : 0;
    var tcpPerSyncFlood     =  $("#tcpPerSyncFlood").hasClass("button-on") ? 1 : 0;
    var udpFlood            =  $("#udpFlood").hasClass("button-on") ? 1 : 0;
    var udpPerFlood         =  $("#udpPerFlood").hasClass("button-on") ? 1 : 0;
    var rpFilter            =  $("#rpFilter").hasClass("button-on") ? 1 : 0 ;
    var tcpSyncWithData     =  $("#tcpSyncWithData").hasClass("button-on") ? 1 : 0 ;
    var classCheck;
    if(!validateElements(elements, validations)) {
      return false;
    }

  params.push({
    name  : "globalEnabled",
    value : globalEnabled
    },{
    name  : "wholeIcmpFlood",
    value : wholeIcmpFlood
    },{
    name  : "perSourceICMPFlood",
    value : perSourceICMPFlood
    },{
    name  : "tcpSyncFlood",
    value : tcpSyncFlood
    },{
    name  : "tcpPerSyncFlood",
    value : tcpPerSyncFlood
    },{
    name  : "udpFlood",
    value : udpFlood
    },{
    name  : "udpPerFlood",
    value : udpPerFlood
    },{
    name  : "rpFilter",
    value : rpFilter
    },{
    name  : "tcpSyncWithData",
    value : tcpSyncWithData
    });
    postHandler(target, params);
  });
  $("#global-cancel").click(function() {
    $("#content").load("/modals/internet/dos.lp");
  });
  $("#resetR, .resetR").click(function() {
    $("#wholeICMPFloodVal").val(resetParams.icmpGlobal);
    $("#perSourceICMPFloodVal").val(resetParams.icmpPerScript);
    $("#tcpSyncFloodVal").val(resetParams.tcpGlobal);
    $("#tcpPerSyncFloodVal").val(resetParams.tcpPerScript);
    $("#udpFloodVal").val(resetParams.udpGlobal);
    $("#udpPerFloodVal").val(resetParams.udpPerScript);
    $("[id$=Flood]").addClass("button-on").removeClass("button-off");
    $(".dosWholeIcmpFlood,.dosperSourceIcmpFlood,.dostcpSyncFlood,.dostcpPerSyncFlood,.dosudpFlood,.dosudpPerFlood").show();
    $(".dosexposed").addClass("hide").removeClass("show");
    changeButton("#rpFilter", resetParams.IPrpfilter);
    changeButton("#tcpSyncWithData", resetParams.tcpSynWithData);
    changeButton("#globalEnabled", resetParams.dosProtect);
  });
});
